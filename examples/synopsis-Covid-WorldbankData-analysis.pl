#!/usr/bin/perl
use 5.006;

use strict;
use warnings;

our $VERSION = '0.23';

use Data::Dump qw/pp/;

use Statistics::Covid;
use Statistics::Covid::Datum;
use Statistics::Covid::Utils;
use Statistics::Covid::Analysis::Plot::Simple;
use Statistics::Covid::Analysis::Model::Simple;
use Statistics::Covid::WorldbankData::IO;
use Statistics::Covid::WorldbankData;

my $DEBUG = 0;

my ($covid, $objs, $newObjs, $someObjs, $df, $ret, $WBio, $WBobjs, $i, $v, $k,
    $actualdata, $N, $anIndicator, $aY, $admin0, $model, $timepoints, $t, $actualv);


my $confighash = Statistics::Covid::Utils::configfile2perl('config/config.json');

# now read some data from DB and do things with it
# this assumes a test database in t/t-data/db/covid19.sqlite
# which is already supplied with this module (60K)
# use a different config-file (or copy and modify
# the one in use here, but don't modify itself because
# tests depend on it)
$covid = Statistics::Covid->new({
	'config-hash' => $confighash,
	'debug' => 0,
}) or die "Statistics::Covid->new() failed";

# select data from DB for selected locations (in the UK)
# data will come out as an array of Datum objects sorted wrt time
# (wrt the 'datetimeUnixEpoch' field)
$objs =
  $covid->select_datums_from_db_time_ascending({
	'conditions' => {
		'admin0' => ['Spain', 'Italy', 'Belgium', 'Germany', 'Greece', 'Cyprus'],
		'admin1' => '',
		'admin2' => '',
		'admin3' => '',
		'admin4' => '',
	}
 });

   # create a dataframe
    $df = Statistics::Covid::Utils::datums2dataframe({
      'datum-objs' => $objs,
      # each unique geo-location will be a single group
      'groupby' => ['admin0'],
      # with these data in each group as an array keyed on group name
      'content' => ['confirmed', 'terminal', 'datetimeUnixEpoch'],
    }) or die;

    # discretise time-axis and insert to a new key in the dataframe
    for(sort keys %$df){
        my @copy = @{$df->{$_}->{'datetimeUnixEpoch'}->{'data'}};
        Statistics::Covid::Utils::discretise_increasing_sequence_of_seconds(
                \@copy, # << in-place modification
                3600, # unit in seconds: 3600 seconds -> 1 hour discrete steps
                0 # optional offset, (the 0 hour above)
        );
        # new key:
        $df->{$_}->{'datetimeHoursSinceOldest'} = {'data' => \@copy};
    }

# normalise confirmed cases over total population
# from the World Bank indicators
$WBio = Statistics::Covid::WorldbankData::IO->new({
      # the params, the relevant section is
      # under key 'worldbankdata'
      'config-hash' => $confighash,
      'debug' => 0,
  }) or die "failed to construct";
$WBio->db_connect() or die "failed to connect to db (while on world bank)";
$WBobjs = $WBio->db_select({
	'conditions' => {
		countryname=>['Spain', 'Italy', 'Belgium', 'Germany', 'Greece', 'Cyprus'],
		year=>2012, # for last years some are not defined yet
	},
});
#print pp($WBobjs)."\n";

my %indicators;
# population size
$indicators{'pop'} = { map { $_->get_column('countryname') => $_->get_column('SP_POP_TOTL')/1E+06 } @$WBobjs };
# GDP (current US$)
$indicators{'gdp'} = { map { $_->get_column('countryname') => $_->get_column('NY_GDP_MKTP_CD')/1E+06 } @$WBobjs };
# Current health expenditure (% of GDP)
$indicators{'health_exp'} = { map { $_->get_column('countryname') => $_->get_column('SH_XPD_CHEX_GD_ZS') } @$WBobjs };
# Hospital beds (per 1,000 people)
$indicators{'hospital_beds'} = { map { $_->get_column('countryname') => $_->get_column('SH_MED_BEDS_ZS') } @$WBobjs };
# Death rate, crude (per 1,000 people)
$indicators{'death_rate'} = { map { $_->get_column('countryname') => $_->get_column('SP_DYN_CDRT_IN') } @$WBobjs };

print pp(\%indicators);

# normalise all markers (confirmed, terminal etc) to the population size times one of the other indicators
# that's in-place for the data frame
for $admin0 (sort keys %$df){
	for $aY (sort keys %{$df->{$admin0}}){
		if( $aY =~ /date/ ){ next }
		for $anIndicator (sort keys %indicators){
			my @vals = @{$df->{$admin0}->{$aY}->{'data'}};
			if( $anIndicator eq 'pop' ){
				$_ /=
					$indicators{$anIndicator}->{$admin0}
				for @vals;
			} else {
				$_ /=
					($indicators{$anIndicator}->{$admin0}*$indicators{'pop'}->{$admin0})
				for @vals;
			}
			# add a new entry to the dataframe
			$df->{$admin0}->{$aY."-over-$anIndicator"} = {
				'data' => \@vals
			}
		}
	}
}

# fit to a polynomial of degree 3 (max power of x is 3)
$ret = Statistics::Covid::Analysis::Model::Simple::fit({
	'dataframe' => $df,
	'X' => 'datetimeHoursSinceOldest', # our X is this field from the dataframe
	'Y' => 'confirmed', # our Y is this field
	# initial values guess (here ONLY for some coefficients)
	'initial-guess' => {'c1'=>1, 'c2'=>1},
	'polynomial-fit' => 3, # max power of x is 3
	'fit-params' => {
		'maximum_iterations' => 100000
	}
});

# do an exponential fit
$ret = Statistics::Covid::Analysis::Model::Simple::fit({
	'dataframe' => $df,
	'X' => 'datetimeHoursSinceOldest', # our X is this field from the dataframe
	'Y' => 'confirmed', # our Y is this field
	'initial-guess' => {'c1'=>1, 'c2'=>1}, # initial values guess
	'exponential-fit' => 1,
	'fit-params' => {
		'maximum_iterations' => 100000
	}
});
print "Here are the fitted models, one for each group:\n".pp($ret)."\n";

# evaluate the model at every time point
# we have a model for each group of data (remember groupby)
# e.g. for Spain
$aY = 'confirmed'; # this is what we fitted against, our Y
for $k (keys %$ret){
	# k is like 'Spain'
	$model = $ret->{$k};
	my @outv;
	$actualdata = $df->{$k}->{$aY}->{'data'};
	$timepoints = $df->{$k}->{'datetimeHoursSinceOldest'}->{'data'};
	$N = scalar @$timepoints;
	for($i=0;$i<$N;$i++){
		$t = $timepoints->[$i];
		$actualv = $actualdata->[$i];
		$v = $model->evaluate($t); # << evaluates the equation at $t
		push @outv, $v;
	}
	$df->{$k}->{$aY}->{'fitted-exponential'} = \@outv;
}

# plot 'confirmed' vs 'time'
$aY = 'confirmed';
$ret = Statistics::Covid::Analysis::Plot::Simple::plot({
	'dataframe' => $df,
	'outfile' => $aY.'-over-time.png',
	'Y' => $aY,
	'X' => 'datetimeUnixEpoch', # secs since THE epoch
});

# plot 'terminal' vs 'time'
$aY = 'terminal';
$ret = Statistics::Covid::Analysis::Plot::Simple::plot({
	'dataframe' => $df,
	'outfile' => $aY.'-over-time.png',
	'Y' => $aY,
	'X' => 'datetimeUnixEpoch', # secs since THE epoch
});

for $anIndicator (sort keys %indicators){
	# plot 'confirmed' vs 'time'
	$aY = 'confirmed-over-'.$anIndicator;
	$ret = Statistics::Covid::Analysis::Plot::Simple::plot({
		'dataframe' => $df,
		'outfile' => $aY.'-over-time.png',
		'Y' => $aY,
		'X' => 'datetimeUnixEpoch', # secs since THE epoch
	}) or die;

	# plot 'terminal' vs 'time'
	$aY = 'terminal-over-'.$anIndicator;
	$ret = Statistics::Covid::Analysis::Plot::Simple::plot({
		'dataframe' => $df,
		'outfile' => $aY.'-over-time.png',
		'Y' => $aY,
		'X' => 'datetimeUnixEpoch', # secs since THE epoch
	}) or die;
}

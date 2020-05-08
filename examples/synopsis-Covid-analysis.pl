#!/usr/bin/perl
use 5.006;

use strict;
use warnings;

our $VERSION = '0.23';

use lib 'blib/lib';

use Statistics::Covid;
use Statistics::Covid::Analysis::Model::Simple;
use Math::Symbolic;
use Test::More;
use File::Basename;
use File::Spec;
use File::Temp;
use File::Path;

use Data::Dump qw/pp/;

my $delete_out_files = 1;
my $DEBUG = 0;

### nothing to change below
my $dirname = dirname(__FILE__);

my $num_tests = 0;

my $tmpdir = 'tmp';#File::Temp::tempdir(CLEANUP=>1);
ok(-d $tmpdir, "output dir exists"); $num_tests++;
my $tmpdbfile = "adb.sqlite";
my $configfile = File::Spec->catfile($dirname, 'config-for-t.json');
my $confighash = Statistics::Covid::Utils::configfile2perl($configfile);
ok(defined($confighash), "config json file parsed."); $num_tests++;

$confighash->{'fileparams'}->{'datafiles-dir'} = File::Spec->catfile($tmpdir, 'files');
$confighash->{'dbparams'}->{'dbtype'} = 'SQLite';
#$confighash->{'dbparams'}->{'dbdir'} = File::Spec->catfile($tmpdir, 'db');
#$confighash->{'dbparams'}->{'dbname'} = $tmpdbfile;
my $dbfullpath = File::Spec->catfile($confighash->{'dbparams'}->{'dbdir'}, $confighash->{'dbparams'}->{'dbname'});

ok(-f $dbfullpath, "found test db"); $num_tests++;

use Statistics::Covid;
use Statistics::Covid::Datum;
use Statistics::Covid::Utils;
use Statistics::Covid::Analysis::Plot::Simple;

my ($covid, $objs, $newObjs, $someObjs, $df, $ret);

# now read some data from DB and do things with it
# this assumes a test database in t/t-data/db/covid19.sqlite
# which is already supplied with this module (60K)
# use a different config-file (or copy and modify
# the one in use here, but don't modify itself because
# tests depend on it)
$covid = Statistics::Covid->new({
	'config-file' => 't/config-for-t.json',
	'debug' => 0,
}) or die "Statistics::Covid->new() failed";

# select data from DB for selected locations (in the UK)
# data will come out as an array of Datum objects sorted wrt time
# (wrt the 'datetimeUnixEpoch' field)
$objs =
  $covid->select_datums_from_db_time_ascending({
	'conditions' => {
		# admin3 is a local authority for the case of UK
		# similarly admin2 can be a local authority but
		# that varies between countries and data providers
		#'admin3' =>{'like' => 'Ha%'},
		#'admin3' =>['Halton', 'Havering'],
		# the admin0 (could be a wildcard) is like a country name
		'admin0' => 'United Kingdom of Great Britain and Northern Ireland',
	}
 });

# create a dataframe (see L<Statistics::Covid::Utils/datums2dataframe>)
$df = Statistics::Covid::Utils::datums2dataframe({
	# input data is an array of L<Statistics::Covid::Datum>'s
	# as fetched from providers or selected from DB (see above)
	'datum-objs' => $objs,

	# collect data from all those with same 'admin1' and same 'admin0'
	# and maybe plot this data as a single curve (or fit or whatever)
	# this will essentially create an entry for 'Hubei|China'
	# another for 'Italy|World', another for 'Hackney|United Kingdom of Great Britain and Northern Ireland'
	# etc. FOR all admin0/admin1 tuples in your
	# selected L<Statistics::Covid::Datum>'s
	'groupby' => ['admin0','admin1', 'admin2', 'admin3', 'admin4'],

	# what fields/attributes/column-names of the datum object
	# to insert into the dataframe?
	# for plotting you need at least 2, one for the role of X
	# and one for the role of Y (see plotting later)
	# if you want to plot multiple Y, then add here more dependent columns
	# e.g. ('unconfirmed', etc.).
	# here we insert the values of 3 column-names
	# it will be an array of values for each field in the same order
	# as in the input '$objs' array.
	# Which was time-ascending sorted upon the select() (see retrieving above)
	'content' => ['confirmed', 'unconfirmed', 'datetimeUnixEpoch'],
});

# plot 'confirmed' vs 'time'
$ret = Statistics::Covid::Analysis::Plot::Simple::plot({
	# the dataframe we just created
	'dataframe' => $df,

	# saves the plot image to this file:
	'outfile' => 'confirmed-over-time.png',

	# plot this column against X
	# (which is not present and default is
	# time : 'datetimeUnixEpoch'
	'Y' => 'confirmed',
	# if X is not present it is assumed to be this:
	#'X' => 'datetimeUnixEpoch',
});

# plot confirmed vs unconfirmed
# if you see in your plot just a vertical line
# it means that your data has no 'unconfirmed' variation
# most likely all 'unconfirmed' are zero because
# the data provider does not provide these values.
$ret = Statistics::Covid::Analysis::Plot::Simple::plot({
	'dataframe' => $df,
	'outfile' => 'confirmed-vs-unconfirmed.png',
	# the role of X is now this, not time as above
	'X' => 'unconfirmed',
	# plot this column with X
	'Y' => 'confirmed',
	# here we specify how to format the X (time) values,
	# i.e. seconds since the Unix epoch.
	# print them only as Months (numbers): %m
	# see Chart::Clicker::Axis::DateTime for all the options
	# if not present a default format for time will be supplied.
	'date-format-x' => {
		format => '%m', ##<<< specify timeformat for X axis, only months
		position => 'bottom',
		orientation => 'horizontal'
	},
});

$someObjs = $covid->select_datums_from_db({
	'conditions' => {
		admin0=>['Spain', 'Italy', 'Belgium'],
	}
});
# create a dataframe (see L<Statistics::Covid::Utils/datums2dataframe>)
$df = Statistics::Covid::Utils::datums2dataframe({
	'datum-objs' => $someObjs,
	'groupby' => ['admin0'],
	'content' => ['confirmed', 'unconfirmed', 'terminal', 'datetimeUnixEpoch'],
});

for(sort keys %$df){
	Statistics::Covid::Utils::discretise_increasing_sequence_of_seconds(
		$df->{$_}->{'datetimeUnixEpoch'}->{'data'}, # << in-place modification
		3600, # unit in seconds: 3600 seconds -> 1 hour discrete steps
		0 # optional offset, (the 0 hour above)
	)
}

# do an exponential fit
$ret = Statistics::Covid::Analysis::Model::Simple::fit({
	'dataframe' => $df,
	'X' => 'datetimeUnixEpoch', # our X is this field from the dataframe
	'Y' => 'confirmed', # our Y is this field
	'initial-guess' => {'c1'=>1, 'c2'=>1}, # initial values guess
	'exponential-fit' => 1,
	'fit-params' => {
		'maximum_iterations' => 100000
	}
});

# fit to a polynomial of degree 3
# (max power of x is 3 which means 4 coefficients)
$ret = Statistics::Covid::Analysis::Model::Simple::fit({
	'dataframe' => $df,
	'X' => 'datetimeUnixEpoch', # our X is this field from the dataframe
	'Y' => 'confirmed', # our Y is this field
	'polynomial-fit' => 3, # max power of x is 3
	'fit-params' => {
		'maximum_iterations' => 100000
	}
});


#####
# Fit a model to data
# i.e. find the parameters of a user-specified
# equation which can fit on all the data points
# with the least error.
# An exponential model is often used in the spread of a virus:
# c1 * c2^x (c1 and c2 are the coefficients to be found / fitted)
# 'x' is the independent variable and usually denotes time
# in L<Statistics::Covid::Datum> is the 'datetimeUnixEpoch' field
#####

use Statistics::Covid;
use Statistics::Covid::Datum;
use Statistics::Covid::Utils;
use Statistics::Covid::Analysis::Model::Simple;

# create a dataframe, as before, from some select()'ed
# L<Statistics::Covid::Datum> objects from DB or provider.
$df = Statistics::Covid::Utils::datums2dataframe({
	'datum-objs' => $objs,
	'groupby' => ['admin0','admin1', 'admin2', 'admin3', 'admin4'],
	'content' => ['confirmed', 'datetimeUnixEpoch'],
});
# we have a problem because seconds since the Unix epoch
# is a huge number and the fitter algorithm does not like it.
# actually exponential functions in a discrete computer don't like it.
# So push their oldest datapoint to 0 (hours) and all
# later datapoints to be relative to that.
# This does not affect data in DB or even in the array of
# datum objects. This affects the dataframe created above only
#print "XXxX\n".pp($df);

for(sort keys %$df){
	Statistics::Covid::Utils::discretise_increasing_sequence_of_seconds(
		$df->{$_}->{'datetimeUnixEpoch'}->{'data'}, # << in-place modification
		3600, # unit in seconds: 3600 seconds -> 1 hour discrete steps
		0 # optional offset, (the 0 hour above)
	)
}

# do an exponential fit
$ret = Statistics::Covid::Analysis::Model::Simple::fit({
	'dataframe' => $df,
	'X' => 'datetimeUnixEpoch', # our X is this field from the dataframe
	'Y' => 'confirmed', # our Y is this field
	'initial-guess' => {'c1'=>1, 'c2'=>1}, # initial values guess
	'exponential-fit' => 1,
	'fit-params' => {
		'maximum_iterations' => 100000
	}
});

# fit to a polynomial of degree 3
# (max power of x is 3 which means 4 coefficients)
$ret = Statistics::Covid::Analysis::Model::Simple::fit({
	'dataframe' => $df,
	'X' => 'datetimeUnixEpoch', # our X is this field from the dataframe
	'Y' => 'confirmed', # our Y is this field
	# initial values guess (here ONLY for some coefficients)
	'initial-guess' => {'c1'=>1, 'c2'=>1, 'c3'=>1,},
	'polynomial-fit' => 3, # max power of x is 3
	'fit-params' => {
		'maximum_iterations' => 100000
	}
});

# fit to an ad-hoc formula in 'x'
# (see L<Math::Symbolic::Operator> for supported operators)
$ret = Statistics::Covid::Analysis::Model::Simple::fit({
	'dataframe' => $df,
	'X' => 'datetimeUnixEpoch', # our X is this field from the dataframe
	'Y' => 'confirmed', # our Y is this field
	# initial values guess
	'initial-guess' => {'c1'=>1, 'c2'=>1},
	'formula' => 'c1*sin(x) + c2*cos(x)',
	'fit-params' => {
		'maximum_iterations' => 100000
	}
});

print "Fitted model:\n".pp($ret);

#print "Data frame:\n".pp($df);

done_testing($num_tests);

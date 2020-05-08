#!/usr/bin/env perl

# for more documentation use the -h flag

our $VERSION = '0.24';

use strict;
use warnings;

use utf8;
binmode STDERR, ':encoding(UTF-8)';
binmode STDOUT, ':encoding(UTF-8)';
binmode STDIN, ':encoding(UTF-8)';

use Statistics::Covid::Utils;
use Statistics::Covid::Datum;
use Statistics::Covid::Geographer;

use Getopt::Long;
use DateTime;
use Data::Dumper::AutoEncode qw/eDumper/;
use Data::Undump qw/undump/;
use Data::Roundtrip;

# there is a:
#    require Statistics::Covid;
# further down, don't place one here

my $configfile = undef;
my $DEBUG = 0;
my $outbase = undef;
my $fitmodels = undef;
# these will overwrite config-file settings
# modules also have some internal sane defaults
my $X = 'datetimeUnixEpoch'; # default independent variable 'x'
my $Y = {
	'confirmed' => 1, # default dependent variables for 'y'
	'terminal' => 1,
	'recovered' => 1,
	'peopletested' => 1, # probably we dont get this from JHU
#	'unconfirmed' => 1,
};
my $GroupBy = {
	'admin0' => 1,
};

my $GetoptParser = Getopt::Long::Parser->new;

# 1st pass of argv, we need to read the config file first
# because in the second pass we push option value into the config hash
# which is too nested for Getopt's feature of pushing to hash
# pass_through: this option ignores options for 2nd pass but removes options parsed by 1st pass
$GetoptParser->configure('pass_through');
$GetoptParser->getoptions(
	'config-file=s' => \$configfile,
); # dont check it
die usage() . "\n\nA configuration file (--config-file) is required." unless defined $configfile;

my ($search_conditions, $search_attributes, $objs);
my $confighash = Statistics::Covid::Utils::configfile2perl($configfile);
if( ! defined $confighash ){ print STDERR "$0 : config-file '$configfile' failed to read or parse.\n"; exit(1) }
if( $DEBUG > 0 ){ print "$0 : read the config file as:\n".pp($confighash)."\n" }

# 2nd pass of the ARGV (1st pass deleted some options and let others pass through)
# now we have a config-hash ready
if( ! $GetoptParser->getoptions(
	'max-rows=s' => sub {
		$search_attributes->{'rows'} = $_[1];
	},
	'outbase=s' => \$outbase,
	'X=s' => \$X,
	'Y=s' => sub { $Y->{$_[1]} = 1 },
	'no-Y=s' => sub { delete $Y->{$_[1]} },
	'group-by=s' => sub { $GroupBy->{$_[1]} = 1 },
	'no-group-by=s' => sub { delete $GroupBy->{$_[1]} },
	'fit-model=s' => sub {
		$fitmodels = {} unless defined $fitmodels;
		if( $_[1] eq 'exponential' ){
			$fitmodels->{$_[1]} = {'exponential-fit'=>1};
		} elsif( $_[1] =~ /^polynomial=([0-9]+)$/ ){
			$fitmodels->{$_[1]} = {'polynomial-fit'=>$1};
		} else {
			# a formula in 'x' with ad-hoc named coefficients, e.g. c1+c2*x+c3*x^2 as a string
			$fitmodels->{'adhoc'} = $_[1];
		}
	},
	'debug=i' => \$DEBUG,

	'plot-min-points=i' => \$confighash->{'analysis'}->{'plot'}->{'min-points'},
	'fit-min-points=i' => \$confighash->{'analysis'}->{'fit'}->{'min-points'},
	'fit-max-iterations=i' => \$confighash->{'analysis'}->{'fit'}->{'max-iterations'},
	'fit-max-mean-error=i' => \$confighash->{'analysis'}->{'fit'}->{'max-mean-error'},

) ){ die usage() . "\n\nerror in command line."; }

if( $DEBUG > 0 ){
	print "$0 : after parsing user-specified options from the command line, config is now:\n".pp($confighash)."\n"
}

$GroupBy = [sort keys %$GroupBy];
$Y = [sort keys %$Y];

##### end of parsing cmd line params
if( ! defined $outbase ){
	my $dt = DateTime->now();
	$outbase = $dt->ymd('.').'_'.$dt->hms('.');
}
# the reason is that loading this module will create schemas etc
# which is a bit of a heavy work just to exit because we do not have a config file
# so load the module after all checks OK.
require Statistics::Covid;

# create the main entry point to fetch and store data
my $covid = Statistics::Covid->new({   
	'config-hash' => $confighash,
	'debug' => $DEBUG,
}) or die "Statistics::Covid->new() failed";

my $dbparams = $covid->dbparams();
my $dbtype = $dbparams->{'dbtype'};
my $dbname = $dbtype eq 'SQLite'
	? File::Spec->catfile($dbparams->{'dbdir'}, $dbparams->{'dbname'})
	: $dbparams->{'dbname'}
;

my $ts = time;
my %outpv = ();
my ($admin0, $admin1, $admin2, $admin3, $admin4,
    $confirmed, $peopletested, $recovered,
    $coords, $terminal, $unconfirmed,
    $latest_datetimeUnixEpoch, $numobjs, $percent,
    $datetimeISO8601, $datetimeUnixEpoch, $i1,
    $confirmed_in_one_day, $recovered_in_one_day,
    $peopletested_in_one_day, $terminal_in_one_day,
    $unconfirmed_in_one_day
);

###################
# find total stats
###################
$search_conditions = {
	'admin0' => 'Cyprus',
	'type' => 'admin0',
	'admin4' => 'CY-TOTAL',
	#'datasource' => {'like'=>'CY::UCY%'}, # we have CY::UCYv1 as well
	'datasource' => 'CY::UCY'
};
$search_attributes = undef;
# select rows from db
# see L<Statistics::Covid> for examples.
$objs = $covid->select_datums_from_db_time_ascending({
	'conditions' => $search_conditions,
	'attributes' => $search_attributes,
});
if( ! defined($objs) ){ print STDERR "$0 : call to ".'select_datums_from_db_latest()'." has failed for database '$dbname'.\n"; exit(1) }
$numobjs = scalar @$objs;
if( $numobjs == 0 ){ print STDERR "conditions:\n".pp($search_conditions)."\nand attributes:\n".pp($search_attributes)."\n$0 : nothing in database '".$dbname."' for the above conditions.\n"; exit(0) }
my %latest_total = (
	'confirmed' => -1,
	'unconfirmed' => -1,
	'terminal' => -1,
	'recovered' => -1,
	'peopletested' => -1,
	'datetimeUnixEpoch' => -1,
	'datetimeISO8601' => -1,
); $latest_total{$_} = $objs->[-1]->get_column($_) for keys %latest_total;

# make the timeline from CY-TOTAL datums
my @timeline;
for my $anobj (@$objs){
	my %tmp;
	$tmp{$_} = $anobj->get_column($_) for keys %latest_total;
	$tmp{'name'} = $anobj->get_column('datetimeISO8601');
	$tmp{'dte'} = $anobj->get_column('datetimeUnixEpoch');
	$tmp{'date'} = $anobj->get_column('datetimeISO8601');
	$tmp{'active'} = $anobj->get_column('i1');
	push @timeline, \%tmp;
}

$outpv{'Cyprus'} = {
	'timeline-detailed' => \@timeline
};
#print pp(\%outpv); exit(0);

###################
# also get the timeline from CY-TIMELINE and see what's the latest
###################
$search_conditions = {
	'admin0' => 'Cyprus',
	'admin4' => 'CY-TIMELINE',
};
$search_attributes = undef;

#print "attributes are:\n".pp($search_attributes)."\n"; print "conditions are:\n".pp($search_conditions)."\n";

# select rows from db
# see L<Statistics::Covid> for examples.
$objs = $covid->select_datums_from_db_time_ascending({
	'conditions' => $search_conditions,
	'attributes' => $search_attributes,
});
if( ! defined($objs) ){ print STDERR "$0 : call to ".'select_datums_from_db_latest()'." has failed for database '$dbname'.\n"; exit(1) }
$numobjs = scalar @$objs;
if( $numobjs == 0 ){ print STDERR "conditions:\n".pp($search_conditions)."\nand attributes:\n".pp($search_attributes)."\n$0 : nothing in database '".$dbname."' for the above conditions.\n"; exit(0) }

# this will only give us confirmed-total and confirmed-in-one-day
my @timeline2;
for my $anobj (@$objs){
	$admin0 = $anobj->get_column('admin0');
	$admin1 = $anobj->get_column('admin1');
	$confirmed = $anobj->get_column('confirmed');
	$confirmed_in_one_day = $anobj->get_column('i1');
	$terminal = $anobj->get_column('terminal');
	$terminal_in_one_day = $anobj->get_column('i2');
	$peopletested = $anobj->get_column('peopletested');
	$peopletested_in_one_day = $anobj->get_column('i3');
	$recovered = $anobj->get_column('recovered');
	$recovered_in_one_day = $anobj->get_column('i4');
	$unconfirmed = $anobj->get_column('unconfirmed');
	$unconfirmed_in_one_day = $anobj->get_column('i5');
	push @timeline2, {
		'datetimeUnixEpoch'=> $anobj->get_column('datetimeUnixEpoch'),
		'datetimeISO8601'=> $anobj->get_column('datetimeISO8601'),
		'confirmed' => $confirmed,
		'confirmed-in-one-day' => $confirmed_in_one_day,
		'terminal' => $terminal,
		'terminal-in-one-day' => $terminal_in_one_day,
		'peopletested' => $peopletested,
		'peopletested-in-one-day' => $peopletested_in_one_day,
		'recovered' => $recovered,
		'recovered-in-one-day' => $recovered_in_one_day,
		'unconfirmed' => $unconfirmed,
		'unconfirmed-in-one-day' => $unconfirmed_in_one_day,
	};
}
my $last_timeline2 = $timeline2[-1];
if( $latest_total{'confirmed'} < $last_timeline2->{'confirmed'} ){
	$latest_total{'confirmed'} = $last_timeline2->{'confirmed'};
	$latest_total{'datetimeUnixEpoch'} = $last_timeline2->{'datetimeUnixEpoch'};
	$latest_total{'datetimeISO8601'} = $last_timeline2->{'datetimeISO8601'};
}
$latest_total{'confirmed-in-one-day'} = $last_timeline2->{'confirmed-in-one-day'};
$latest_total{'unconfirmed-in-one-day'} = $last_timeline2->{'unconfirmed-in-one-day'};
$latest_total{'peopletested-in-one-day'} = $last_timeline2->{'peopletested-in-one-day'};
$latest_total{'recovered-in-one-day'} = $last_timeline2->{'recovered-in-one-day'};
$outpv{'Cyprus'}->{'timeline'} = \@timeline2;
#print pp(\@timeline2); exit(0);
### end

###################
# total stats for district
###################
$search_conditions = {
	'admin0' => 'Cyprus',
	'admin4' => 'CY-EPARXIA',
};
$search_attributes = undef;

#print "attributes are:\n".pp($search_attributes)."\n"; print "conditions are:\n".pp($search_conditions)."\n";

# select rows from db
# see L<Statistics::Covid> for examples.
$objs = $covid->select_datums_from_db_latest({
	'conditions' => $search_conditions,
	'attributes' => $search_attributes,
});
if( ! defined($objs) ){ print STDERR "$0 : call to ".'select_datums_from_db_latest()'." has failed for database '$dbname'.\n"; exit(1) }
$numobjs = scalar @$objs;
if( $numobjs == 0 ){ print STDERR "conditions:\n".pp($search_conditions)."\nand attributes:\n".pp($search_attributes)."\n$0 : nothing in database '".$dbname."' for the above conditions.\n"; exit(0) }

# wants array!
#my $destpv = $outpv{'Cyprus'}->{'details'}->{'districts-total'} = {};
my $destpv = $outpv{'Cyprus'}->{'details'}->{'districts-total'} = [];

my %latest_total2 = map { $_ => 0 } keys %latest_total;
for my $anobj (@$objs){
	$admin0 = $anobj->get_column('admin0');
	$admin1 = $anobj->get_column('admin1');
	$confirmed = $anobj->get_column('confirmed');
	$terminal = $anobj->get_column('terminal');
	$peopletested = $anobj->get_column('peopletested');
	$recovered = $anobj->get_column('recovered');
	$coords = Statistics::Covid::Geographer::cylocation2coordinates($admin1);
	if( ! defined $coords ){ die "call to ".'Statistics::Covid::Geographer::cylocation2coordinates()'." has failed" }
#	$destpv->{$admin1} = {
	push @$destpv, {
		'name' => $admin1,
		'admin0' => $admin0,
		'admin1' => $admin1,
		'lat' => $coords->[0],
		'lon' => $coords->[1],
		'recovered' => $recovered,
		'confirmed' => $confirmed, # for EPARXIA, this is ACTIVE cases not total confirmed!
		'peopletested' => $peopletested,
		'terminal' => '-1',
		'tested' => $peopletested,
	};
	$latest_total2{$_} += $anobj->get_column($_) for qw/confirmed recovered peopletested/;
}
$latest_total{'active'} = $latest_total2{'confirmed'};
$latest_total{'recovered'} = $latest_total{'confirmed'} - $latest_total{'active'};
#print pp(\%latest_total); exit(0);
### end

###################
# stats for local places
###################
$search_conditions = {
	'admin0' => 'Cyprus',
	'admin4' => 'CY-ALL-LOCATIONS',
};
$search_attributes = undef;

#print "attributes are:\n".pp($search_attributes)."\n"; print "conditions are:\n".pp($search_conditions)."\n";

# select rows from db
# see L<Statistics::Covid> for examples.
$objs = $covid->select_datums_from_db_latest({
	'conditions' => $search_conditions,
	'attributes' => $search_attributes,
});
if( ! defined($objs) ){ print STDERR "$0 : call to ".'select_datums_from_db_latest()'." has failed for database '$dbname'.\n"; exit(1) }
$numobjs = scalar @$objs;
if( $numobjs == 0 ){ print STDERR "conditions:\n".pp($search_conditions)."\nand attributes:\n".pp($search_attributes)."\n$0 : nothing in database '".$dbname."' for the above conditions.\n"; exit(0) }
$latest_datetimeUnixEpoch = $objs->[0]->get_column('datetimeUnixEpoch');
#print print_objs($objs); exit(0);
$destpv = $outpv{'Cyprus'}->{'details'}->{'all-locations'} = {};
for my $anobj (@$objs){
	$admin0 = $anobj->get_column('admin0');
	$admin2 = $anobj->get_column('admin2'); #village/city/suburb!
	$confirmed = $anobj->get_column('confirmed');
	$terminal = $anobj->get_column('terminal');
	$peopletested = $anobj->get_column('peopletested');
	$coords = Statistics::Covid::Geographer::cylocation2coordinates($admin2);
	if( ! defined $coords ){ $coords = ["<na>","<na>"] }
	$destpv->{$admin2} = {
		'admin0' => $admin0,
		'admin2' => $admin2,
		'lat' => $coords->[0],
		'lon' => $coords->[1],
		'peopletested' => $peopletested,
		'terminal' => $terminal,
		'confirmed' => $confirmed,
	};
}
### end

###################
# stats for sex
###################
$search_conditions = {
	'admin0' => 'Cyprus',
	'admin4' => 'CY-SEX',
};
$search_attributes = undef;

#print "attributes are:\n".pp($search_attributes)."\n"; print "conditions are:\n".pp($search_conditions)."\n";

# select rows from db
# see L<Statistics::Covid> for examples.
$objs = $covid->select_datums_from_db_latest({
	'conditions' => $search_conditions,
	'attributes' => $search_attributes,
});
if( ! defined($objs) ){ print STDERR "$0 : call to ".'select_datums_from_db_latest()'." has failed for database '$dbname'.\n"; exit(1) }
$numobjs = scalar @$objs;
if( $numobjs == 0 ){ print STDERR "conditions:\n".pp($search_conditions)."\nand attributes:\n".pp($search_attributes)."\n$0 : nothing in database '".$dbname."' for the above conditions.\n"; exit(0) }
$latest_datetimeUnixEpoch = $objs->[0]->get_column('datetimeUnixEpoch');
#print print_objs($objs); exit(0);
$destpv = $outpv{'Cyprus'}->{'details'}->{'sex'} = {};
for my $anobj (@$objs){
	$admin0 = $anobj->get_column('admin0');
	$admin3 = $anobj->get_column('admin3');
	$confirmed = $anobj->get_column('confirmed');
	$terminal = $anobj->get_column('terminal');
	$percent = $anobj->get_column('i1');
	$peopletested = $anobj->get_column('peopletested');
#	$coords = Statistics::Covid::Geographer::cylocation2coordinates($admin1);
#	if( ! defined $coords ){ die "call to ".'Statistics::Covid::Geographer::cylocation2coordinates()'." has failed" }
	$destpv->{$admin3} = {
		'admin0' => $admin0,
		'name' => $admin3,
		'sex' => $admin3,
		'percent' => $percent,
		'peopletested' => $peopletested,
		'terminal' => $terminal,
		'confirmed' => $confirmed,
	};
}
#print pp($destpv); exit(0);
### end

###################
# stats for nationality
###################
$search_conditions = {
	'admin0' => 'Cyprus',
	'admin4' => 'CY-NATIONALITY',
};
$search_attributes = undef;

#print "attributes are:\n".pp($search_attributes)."\n"; print "conditions are:\n".pp($search_conditions)."\n";

# select rows from db
# see L<Statistics::Covid> for examples.
$objs = $covid->select_datums_from_db_latest({
	'conditions' => $search_conditions,
	'attributes' => $search_attributes,
});
if( ! defined($objs) ){ print STDERR "$0 : call to ".'select_datums_from_db_latest()'." has failed for database '$dbname'.\n"; exit(1) }
$numobjs = scalar @$objs;
if( $numobjs == 0 ){ print STDERR "conditions:\n".pp($search_conditions)."\nand attributes:\n".pp($search_attributes)."\n$0 : nothing in database '".$dbname."' for the above conditions.\n"; exit(0) }
$latest_datetimeUnixEpoch = $objs->[0]->get_column('datetimeUnixEpoch');
#print print_objs($objs); exit(0);
$destpv = $outpv{'Cyprus'}->{'details'}->{'nationality'} = {};
for my $anobj (@$objs){
	$admin0 = $anobj->get_column('admin0');
	$admin3 = $anobj->get_column('admin3');
	$confirmed = $anobj->get_column('confirmed');
	$terminal = $anobj->get_column('terminal');
	$percent = $anobj->get_column('i1');
	$peopletested = $anobj->get_column('peopletested');
#	$coords = Statistics::Covid::Geographer::cylocation2coordinates($admin1);
#	if( ! defined $coords ){ die "call to ".'Statistics::Covid::Geographer::cylocation2coordinates()'." has failed" }
	$destpv->{$admin3} = {
		'admin0' => $admin0,
		'name' => $admin3,
		'nationality' => $admin3,
		'percent' => $percent,
		'peopletested' => $peopletested,
		'terminal' => $terminal,
		'confirmed' => $confirmed,
	};
}
#print pp($destpv); exit(0);
### end

###################
# stats for AGE groups
###################
$search_conditions = {
	'admin0' => 'Cyprus',
	'admin4' => 'CY-AGE',
};
$search_attributes = undef;

#print "attributes are:\n".pp($search_attributes)."\n"; print "conditions are:\n".pp($search_conditions)."\n";

# select rows from db
# see L<Statistics::Covid> for examples.
$objs = $covid->select_datums_from_db_latest({
	'conditions' => $search_conditions,
	'attributes' => $search_attributes,
});
if( ! defined($objs) ){ print STDERR "$0 : call to ".'select_datums_from_db_latest()'." has failed for database '$dbname'.\n"; exit(1) }
$numobjs = scalar @$objs;
if( $numobjs == 0 ){ print STDERR "conditions:\n".pp($search_conditions)."\nand attributes:\n".pp($search_attributes)."\n$0 : nothing in database '".$dbname."' for the above conditions.\n"; exit(0) }
$latest_datetimeUnixEpoch = $objs->[0]->get_column('datetimeUnixEpoch');
#print print_objs($objs); exit(0);
$destpv = $outpv{'Cyprus'}->{'details'}->{'age'} = {};
%latest_total2 = map { $_ => 0 } keys %latest_total;
for my $anobj (@$objs){
	$admin0 = $anobj->get_column('admin0');
	$admin3 = $anobj->get_column('admin3');
	$confirmed = $anobj->get_column('confirmed');
	$terminal = $anobj->get_column('terminal');
	$percent = $anobj->get_column('i1');
	$peopletested = $anobj->get_column('peopletested');
#	$coords = Statistics::Covid::Geographer::cylocation2coordinates($admin1);
#	if( ! defined $coords ){ die "call to ".'Statistics::Covid::Geographer::cylocation2coordinates()'." has failed" }
	$destpv->{$admin3} = {
		'admin0' => $admin0,
		'name' => $admin3,
		'age' => $admin3,
		'peopletested' => $peopletested,
		'terminal' => $terminal,
		'confirmed' => $confirmed,
	};
	$latest_total2{$_} += $anobj->get_column($_) for qw/confirmed recovered peopletested/;
}
$latest_total{'peopletested'} = $latest_total2{'peopletested'};
#print pp($destpv); print pp(\%latest_total2); exit(0);
### end

###################
# stats for confirmed per 100,000 per district
###################
$search_conditions = {
	'admin0' => 'Cyprus',
	'admin4' => 'CY-PER-100000',
};
$search_attributes = undef;

#print "attributes are:\n".pp($search_attributes)."\n"; print "conditions are:\n".pp($search_conditions)."\n";

# select rows from db
# see L<Statistics::Covid> for examples.
$objs = $covid->select_datums_from_db_latest({
	'conditions' => $search_conditions,
	'attributes' => $search_attributes,
});
if( ! defined($objs) ){ print STDERR "$0 : call to ".'select_datums_from_db_latest()'." has failed for database '$dbname'.\n"; exit(1) }
$numobjs = scalar @$objs;
if( $numobjs == 0 ){ print STDERR "conditions:\n".pp($search_conditions)."\nand attributes:\n".pp($search_attributes)."\n$0 : nothing in database '".$dbname."' for the above conditions.\n"; exit(0) }
$latest_datetimeUnixEpoch = $objs->[0]->get_column('datetimeUnixEpoch');
#print print_objs($objs); exit(0);
$destpv = $outpv{'Cyprus'}->{'details'}->{'per-100000-per-district'} = {};
for my $anobj (@$objs){
	$admin0 = $anobj->get_column('admin0');
	$admin1 = $anobj->get_column('admin1');
	$confirmed = $anobj->get_column('confirmed');
	$terminal = $anobj->get_column('terminal');
	$peopletested = $anobj->get_column('peopletested');
	$coords = Statistics::Covid::Geographer::cylocation2coordinates($admin1);
	if( ! defined $coords ){ die "call to ".'Statistics::Covid::Geographer::cylocation2coordinates()'." has failed" }
	$destpv->{$admin1} = {
		'admin0' => $admin0,
		'name' => $admin1,
		'admin1' => $admin1,
		'lat' => $coords->[0],
		'lon' => $coords->[1],
		# that's all per 100,000
		'confirmed' => $confirmed,
		'peopletested' => $peopletested,
		'terminal' => $terminal,
	};
}
#print pp($destpv); exit(0);
### end

$outpv{'Cyprus'}->{'latest'} = [{
	%latest_total,
	'name' => 'Cyprus',
}]; # what the shit!!!!

##################
### done, save it
##################
my $datums_in_db = $covid->db_count_datums();
if( $datums_in_db < 0 ){ print STDERR "$0 : failed to get the row count of Datum records from the database.\n"; exit(1) }
#print pp(\%outpv);
$covid = undef; # disconnects

my $outfile = $outbase . '.json';
my $jsonstring = Data::Roundtrip::perl2json(\%outpv, {'pretty'=>0, 'escape-unicode'=>0});
if( ! defined $jsonstring ){ warn "error, call to ".'Data::Roundtrip::perl2json()'." has failed"; exit(1) }
if( ! Statistics::Covid::Utils::save_text_to_localfile($jsonstring, $outfile) ){ warn "error, call to ".'Statistics::Covid::Utils::save_text_to_localfile()'." has failed for file '$outfile'"; exit(1) }
if( $DEBUG > 0 ){ print "$0 : selected $numobjs rows from database '$dbname' from a total of $datums_in_db.\n" }
print "$0 : saved total to output file '$outfile'.\n";
# now break idiotically

my %broken = (
	# filename => what to save
	$outbase.'-by-age.json' => $outpv{'Cyprus'}->{'details'}->{'age'},
	$outbase.'-by-sex.json' => $outpv{'Cyprus'}->{'details'}->{'sex'},
	$outbase.'-by-nationality.json' => $outpv{'Cyprus'}->{'details'}->{'nationality'},
	$outbase.'-by-district.json' => $outpv{'Cyprus'}->{'details'}->{'districts-total'},
	$outbase.'-total.json' => $outpv{'Cyprus'}->{'latest'},
	$outbase.'-timeline.json' => $outpv{'Cyprus'}->{'timeline'},
	$outbase.'-timeline-detailed.json' => $outpv{'Cyprus'}->{'timeline-detailed'},
);
for $outfile (keys %broken){
	my $v = $broken{$outfile};
	if( ! defined $v ){ die "error, data for '$outfile' is undef" }
	$jsonstring = Data::Roundtrip::perl2json($v, {'pretty'=>0, 'escape-unicode'=>0});
	if( ! defined $jsonstring ){ warn pp($jsonstring)."\nerror, call to ".'Data::Roundtrip::perl2json()'." has failed for above data"; exit(1) }
	if( ! Statistics::Covid::Utils::save_text_to_localfile($jsonstring, $outfile) ){ warn "error, call to ".'Statistics::Covid::Utils::save_text_to_localfile()'." has failed for file '$outfile'"; exit(1) }
	print "$0 : saved partial to output file '$outfile'.\n";
}
print "$0 : success, done in ".(time-$ts)." seconds.\n";

#### end
sub pp { return Data::Roundtrip::perl2dump($_[0], {'dont-bloody-escape-unicode'=>1}) }
sub print_objs {
	my $inp = $_[0];
	my $ret = "";
	$ret .= pp($_->toHashtable())."\n" for @$inp;
	return $ret
}
sub usage {
	return "Usage : $0 <options>\n"
	. " --config-file C : specify a configuration file which contains where to save files, where is the DB, what is its type (SQLite or MySQL), and DB connection options. The example configuration at 't/example-config.json' can be used as a quick start. Make a copy if that file and do not modify that file directly as tests may fail.\n"
	. " --outdir O : specify an outdir to prefix all file writing, this can be a directory (which must exists) or a file-prefix or both.]\n"
	. "--model M : can be 'exponential', 'polynomial=<DEGREE>' (e.g. <DEGREE>=10) or any equation in 'x' with as many coefficients and any names, see Math::Symbolic::Operator for all available expressions and operators and general syntax.]\n"
	. "[--location-name N : specify a location name either as an exact string, e.g. 'Cyprus', or as a SQL::Abstract search condition, something like: '{like=>\"%abc%\"}'.]\n"
	. "[--admin0 B : specify a string for where does the required locattion belongs to, this is optional in case names need to be clarified.]\n"
	. "[--X X : specify which field name (column, attribute) should be used for the x-axis, default is time, '$X'.]\n"
	. "[--Y Y : can be used multiple times to build an array of field names to plot against, in the y-axis.]\n"
	. "[--group-by G : can be used multiple times to specify the field names to group data by. For example: --group-by 'name' will group data accordinng to their 'name' and build as many plots and models.]\n"
	. "[--debug Level : specify a debug level, anything >0 is verbose.]\n"
	. "\nNote: --Y and --group-by have defaults. To remove one, e.g. XYZ  do --no-Y XYZ and --no-group-by XYZ\n"
	. "\nExample use:\n\n  $0 --config-file 'config/config.json' --outdir 'analysis/plots' --debug 1 --location-name \"{like=>'Ha%'}\" --no-Y 'unpeopletested' --group-by 'name' --fit-model 'exponential'\n"
	. "\nProgram by Andreas Hadjiprocopis (andreashad2\@gmail.com / bliako\@cpan.org)\n"
}
1;
__END__

=pod
# end program, below is the POD

=encoding UTF-8

=head1 NAME

script/statistics-covid-fit-model.pl - simple script to plot and fit data

=head1 VERSION

Version 0.24

=head1 DESCRIPTION

This script searches the database for specified location (or all locations)
and retrieves the matching rows. Data is then plotted and also fitted on the
user-specified choice of model.

=head1 SYNOPSIS
	script/statistics-covid-fit-model.pl \
	  --config-file 'config/config.json' \
	  --outdir 'analysis/plots' \
	  --debug 1 \
	  --location-name "{like=>'Ha%'}"

will produce the image files
C<analysis/plots/unpeopletested-over-time.png>,
C<analysis/plots/peopletested-over-time.png>,
C<analysis/plots/recovered-over-time.png>,
and C<analysis/plots/terminal-over-time.png>.

=head1 CONFIGURATION FILE

For information about the format of the configuration
file read L<Statistics::Covid>.

=head1 AUTHOR

Andreas Hadjiprocopis, C<< <bliako at cpan.org> >>, C<< <andreashad2 at gmail.com> >>

=head1 BUGS

This module has been put together very quickly and under pressure.
There are must exist quite a few bugs.

Please report any bugs or feature requests to C<bug-statistics-Covid at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Statistics-Covid>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Statistics::Covid


You can also look for information at:

=over 4

=item * github L<repository|https://github.com/hadjiprocopis/statistics-covid>  which will host data and alpha releases

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Statistics-Covid>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Statistics-Covid>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Statistics-Covid>

=item * Search CPAN

L<http://search.cpan.org/dist/Statistics-Covid/>

=item * Information about the basis module DBIx::Class

L<http://search.cpan.org/dist/DBIx-Class/>

=back


=head1 DEDICATIONS

Almaz

=head1 ACKNOWLEDGEMENTS

=over 2

=item L<Perlmonks|https://www.perlmonks.org> for supporting the world with answers and programming enlightment

=item L<DBIx::Class>

=item the data providers:

=over 2

=item L<Johns Hopkins University|https://www.arcgis.com/apps/opsdashboard/index.html#/bda7594740fd40299423467b48e9ecf6>,

=item L<UK government|https://www.gov.uk/government/publications/covid-19-track-coronavirus-cases>,

=item L<https://www.bbc.co.uk> (for disseminating official results)

=back

=back

=head1 LICENSE AND COPYRIGHT

Copyright 2020 Andreas Hadjiprocopis.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
=cut


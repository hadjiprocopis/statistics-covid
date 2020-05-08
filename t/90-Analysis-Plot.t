#!/usr/bin/perl
use 5.006;

use strict;
use warnings;

our $VERSION = '0.25';

use lib 'blib/lib';

use Statistics::Covid;
use Statistics::Covid::Analysis::Plot::Simple;
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

my $tmpdir = File::Temp::tempdir(CLEANUP=>1);
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

my $covid = Statistics::Covid->new({
	'config-hash' => $confighash,
	'debug' => $DEBUG,
});
ok(defined($covid), "Statistics::Covid::Datum::IO->new() called"); $num_tests++;
ok(defined($covid->datum_io()), "connect to db: '$dbfullpath'."); $num_tests++;

ok(exists($confighash->{'analysis'}), "analysis sub-key in config hash exists") or BAIL_OUT; $num_tests++;
ok(exists($confighash->{'analysis'}->{'plot'}), "analysis/plot sub-key in config hash exists") or BAIL_OUT; $num_tests++;
ok(defined($confighash->{'analysis'}->{'plot'}), "analysis/plot sub-key in confighash defined") or BAIL_OUT; $num_tests++;

my $plotparams = $confighash->{'analysis'}->{'plot'};
$plotparams->{'debug'} = $DEBUG;

# get datum objs for specific location sorted wrt time
my $objs = $covid->select_datums_from_db_time_ascending({
	'conditions' => {
		'datasource' => 'UK::GOVUK2',
		'admin3' => {'like' => 'Hack%'},
		#or {'like' => 'Haver%'},
		'admin0' => 'United Kingdom of Great Britain and Northern Ireland'
	}
});
ok(defined($objs), "select_datums_from_db_time_ascending() called.") || BAIL_OUT("can not continue, something wrong with the test db which should have been present in t dir"); $num_tests++;
ok(scalar(@$objs)>0, "select_datums_from_db_time_ascending() returned objects.") || BAIL_OUT("can not continue, something wrong with the test db which should have been present in t dir"); $num_tests++;

my $df = Statistics::Covid::Utils::datums2dataframe({
	'datum-objs' => $objs,
	'groupby' => ['admin0', 'admin3'],
	'content' => ['confirmed','unconfirmed','datetimeUnixEpoch'],
});
ok(defined($df), "Statistics::Covid::Utils::datums2dataframe() called."); $num_tests++;

my $outfile = 'chartclicker.png'; unlink $outfile;

my $ret;

# fail because no correct formatter-x
$ret = Statistics::Covid::Analysis::Plot::Simple::plot({
	'dataframe' => $df,
	'outfile' => $outfile,
	'Y' => 'confirmed',
	'date-format-x' => 123,
	'GroupBy' => ['admin1'],
	%$plotparams
});
ok(!defined($ret), "Statistics::Covid::Analysis::Plot::Simple::plot() called to fail."); $num_tests++;
# fail because no dataframe or datum-objs
$ret = Statistics::Covid::Analysis::Plot::Simple::plot({
	'outfile' => $outfile,
	'Y' => 'confirmed',
	'date-format-x' => {
		format => '%d/%m',
		position => 'bottom',
		orientation => 'horizontal'
	},
	'GroupBy' => ['admin1'],
	%$plotparams
});
ok(!defined($ret), "Statistics::Covid::Analysis::Plot::Simple::plot() called to fail."); $num_tests++;

# fail, call with datum-objs which is no longer supported
$ret = Statistics::Covid::Analysis::Plot::Simple::plot({
	'datum-objs' => $objs,
	'outfile' => $outfile,
	'Y' => 'confirmed',
	'X' => 'datetimeUnixEpoch',
	'date-format-x' => {
		format => '%d/%m',
		position => 'bottom',
		orientation => 'horizontal'
	},
	'GroupBy' => ['admin1'],
	%$plotparams
});
ok(!defined($ret), "Statistics::Covid::Analysis::Plot::Simple::plot() called with datum-objs"); $num_tests++;

# succeed, call with dataframe, X is not time
$ret = Statistics::Covid::Analysis::Plot::Simple::plot({
	'dataframe' => $df,
	'outfile' => $outfile,
	'title' => 'test-title',
	'with-legend' => 0,
	'Y' => 'confirmed',
	'X' => 'confirmed', # because of failures in case of no variation
	%$plotparams
});
ok(defined($ret), "Statistics::Covid::Analysis::Plot::Simple::plot() called with dataframe"); $num_tests++;
ok((-f $outfile)&&(-s $outfile), "output image '$outfile'."); $num_tests++;
unlink $outfile if $delete_out_files; 

# succeed, call with dataframe instead
$ret = Statistics::Covid::Analysis::Plot::Simple::plot({
	'dataframe' => $df,
	'outfile' => $outfile,
	'Y' => 'confirmed',
	'date-format-x' => {
		format => '%d/%m',
		position => 'bottom',
		orientation => 'horizontal'
	},
	%$plotparams
});
ok(defined($ret), "Statistics::Covid::Analysis::Plot::Simple::plot() called with dataframe"); $num_tests++;
ok((-f $outfile)&&(-s $outfile), "output image '$outfile'."); $num_tests++;
unlink $outfile if $delete_out_files;

done_testing($num_tests);

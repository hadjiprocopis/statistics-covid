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

my ($covid, $objs, $newObjs, $someObjs, $df, $ret);
# create the object for downloading data, parsing, cleaning
# and storing to DB. If table is not deployed it will be deployed.
# (tested with SQLite)
$covid = Statistics::Covid->new({
	# configuration file (or hash)
	'config-file' => 't/config-for-t.json',
	#'config-hash' => {...}.,
	# known data providers
	# 'World::JHU' points to
	# https://www.arcgis.com/apps/opsdashboard/index.html#/bda7594740fd40299423467b48e9ecf6
	# it's a Johns Hopkins University site and contains world data since the
	# beginning as well as local data (states) for the US, Canada and China
	# 'World::JHUgithub' points to this:
	# https://github.com/CSSEGISandData/COVID-19
	# 'World::JHUlocaldir' is a local clone (git clone) of the above
	# because the online github has a limit on files to download
	# the best is to git-clone locally and use 'World::JHUlocaldir'
	# Then there are 2 repositories for UK statistics broken
	# into local areas.
	'providers' => [
		#'UK::BBC',
		'UK::GOVUK2',
		#'World::JHUlocaldir',
		'World::JHUgithub',
		'World::JHU'
	],
	'provider-extra-params' => {
		#'World::JHUlocaldir' => {
		#	'paths' => [File::Spec->catdir($dirname, '..', 'COVID-19'],
		#},
		# 'World::JHUgithub' => ... see L<Statistics::Covid::DataProvider::World::JHUgithub>
	},
	# save fetched data locally in its original format (json or csv)
	# and also as a perl var
	'save-to-file' => {
		'UK::BBC' => 1,
		'UK::GOVUK2' => 1,
		'World::JHUlocaldir' => 0,
		'World::JHUgithub' => 1,
		'World::JHU' => 1,
	},
	# save fetched data into the database in table Datum
	'save-to-db' => {
		'UK::BBC' => 1,
		'UK::GOVUK2' => 1,
		'World::JHUlocaldir' => 1,
		'World::JHUgithub' => 1,
		'World::JHU' => 1,
	},
	# debug level affects verbosity
	'debug' => 0, # 0, 1, ...
}) or die "Statistics::Covid->new() failed";

# Do the download:
# fetch all the data available (posibly json), process it,
# create Datum objects, store it in DB and return an array
# of the Datum objects just fetched  (and not what is already in DB).
$newObjs = $covid->fetch_and_store();

print $_->toString() for (@$newObjs);

print "Confirmed cases for ".$_->admin0()
	." on ".$_->date()
	." are: ".$_->confirmed()
	."\n"
for (@$newObjs);

$someObjs = $covid->select_datums_from_db({
	'conditions' => {
		admin0=>'United Kingdom of Great Britain and Northern Ireland',
		admin3=>'Hackney'
	}
});

print "Confirmed cases for "
        .$_->admin0().'/'.$_->admin3()
	." on ".$_->date()
	." are: ".$_->confirmed()
	."\n"
for (@$someObjs);

# or for a single place (this sub sorts results wrt publication time)
my $timelineObjs =
  $covid->select_datums_from_db_time_ascending({
	'conditions' => {
		'admin3' => 'Hackney',
		'admin0' => 'United Kingdom of Great Britain and Northern Ireland',
	}
  });

# or for a wildcard match
$timelineObjs =
  $covid->select_datums_from_db_time_ascending({
	'conditions' => {
		'admin1' => {'like'=>'Hack%'},
		'admin0' => 'United Kingdom of Great Britain and Northern Ireland',
	}
  });

# and maybe specifying max rows
$timelineObjs =
  $covid->select_datums_from_db_time_ascending({
	'conditions' => {
		'admin1' => {'like'=>'Hack%'},
		'admin0' => 'United Kingdom of Great Britain and Northern Ireland',
	},
	'attributes' => {'rows' => 10}
  });

# print those datums
for my $anobj (@$timelineObjs){
	print $anobj->toString()."\n";
}

# total count of datapoints matching the select()
print "datum rows matched: ".scalar(@$timelineObjs)."\n";

# total count of datapoints in db
print "datum rows in DB: ".$covid->db_count_datums()."\n";

done_testing($num_tests);

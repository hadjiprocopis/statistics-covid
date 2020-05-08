#!/usr/bin/perl
use 5.006;

use strict;
use warnings;

our $VERSION = '0.25';

use lib 'blib/lib';

use Statistics::Covid;
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

my $csvtestdir = $confighash->{'fileparams'}->{'datafiles-dir'};
$confighash->{'fileparams'}->{'datafiles-dir'} = File::Spec->catfile($tmpdir, 'files');
$confighash->{'dbparams'}->{'dbtype'} = 'SQLite';
#$confighash->{'dbparams'}->{'dbdir'} = File::Spec->catfile($tmpdir, 'db');
#$confighash->{'dbparams'}->{'dbname'} = $tmpdbfile;
my $dbfullpath = File::Spec->catfile($confighash->{'dbparams'}->{'dbdir'}, $confighash->{'dbparams'}->{'dbname'});

ok(-f $dbfullpath, "found test db"); $num_tests++;

my $cparams = {
	'providers' => ['World::JHUlocaldir'],
	'provider-extra-params' => {
		'World::JHUlocaldir' => {
			'paths' => [
				$csvtestdir
			],
		}
	},
	'config-hash' => $confighash,
	'debug' => $DEBUG,
};

my $covid = Statistics::Covid->new($cparams);
ok(defined($covid), "Statistics::Covid->new() called"); $num_tests++;
ok(defined($covid->datum_io()), "connect to db: '$dbfullpath'."); $num_tests++;

my $datums_in_db_before = $covid->db_count_datums();
ok($datums_in_db_before>=0, "db conencted ($datums_in_db_before rows)"); $num_tests++;
my $objs = $covid->fetch_and_store();
ok(defined($objs), "fetch_and_store() called"); $num_tests++;
ok(scalar(@$objs)>0, "fetched objects (".@$objs.")"); $num_tests++;
done_testing($num_tests);

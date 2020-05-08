#!/usr/bin/env perl

##!perl -T
use 5.006;

use strict;
use warnings;

our $VERSION = '0.25';

use lib 'blib/lib';

use Statistics::Covid::WorldbankData;
use Statistics::Covid::WorldbankData::IO;
use File::Temp;
use File::Spec;
use File::Basename;

my $dirname = dirname(__FILE__);

use Test::More;

my $num_tests = 0;

my ($ret, $count, $io, $schema, $wbObj);

my $tmpdir = File::Temp::tempdir(CLEANUP=>1);
ok(-d $tmpdir, "output dir exists"); $num_tests++;
my $tmpdbfile = "adb.sqlite";
my $configfile = File::Spec->catfile($dirname, 'config-for-t.json');
my $confighash = Statistics::Covid::Utils::configfile2perl($configfile);
ok(defined($confighash), "config json file parsed."); $num_tests++;

$confighash->{'fileparams'}->{'datafiles-dir'} = File::Spec->catfile($tmpdir, 'files');
$confighash->{'dbparams'}->{'dbtype'} = 'SQLite';
$confighash->{'dbparams'}->{'dbdir'} = File::Spec->catfile($tmpdir, 'db');
$confighash->{'dbparams'}->{'dbname'} = $tmpdbfile;
my $dbfullpath = File::Spec->catfile($confighash->{'dbparams'}->{'dbdir'}, $confighash->{'dbparams'}->{'dbname'});

$io = Statistics::Covid::WorldbankData::IO->new({
	# the params
	'config-hash' => $confighash,
	'debug' => 1,
});
ok(defined($io), "Statistics::Covid::WorldbankData::IO->new() called"); $num_tests++;
ok(-d $confighash->{'fileparams'}->{'datafiles-dir'}, "output data dir exists"); $num_tests++;
$schema = $io->db_connect();
ok(defined($schema), "connect to DB"); $num_tests++;
ok($io->db_is_connected(), "connected to DB") or BAIL_OUT; $num_tests++;
ok($io->db_is_deployed(), "db_is_deployed() called"); $num_tests++;
ok($io->db_deploy({'drop-table'=>1}), "dropped the table from db and re-created"); $num_tests++;

$wbObj = Statistics::Covid::WorldbankData->make_random_object(123);
ok(defined $wbObj, "created WorldbankData"); $num_tests++;
$wbObj->debug(1);

$count = $io->db_count();
ok($count>=0, "db_count() called."); $num_tests++;
if( $count > 0 ){
	$ret=$io->db_delete_rows();
	ok($ret>0, "erased all table rows"); $num_tests++;
	ok(0==$io->db_count(), "no rows in table exist"); $num_tests++;
}

$ret = $io->db_insert($wbObj);
ok($ret==1, "Version object inserted, 1st time"); $num_tests++;

# now read it back
my $objs = $io->db_select(); # only 1 row
ok(defined($objs), "Version table has content."); $num_tests++;
ok(1==scalar(@$objs), "Version table has exactly 1 row."); $num_tests++;
ok($objs->[0]->equals($wbObj), "exact same version objects in memory and DB."); $num_tests++;

is($io->db_disconnect(), 1, "disconnect from DB"); $num_tests++;

done_testing($num_tests);

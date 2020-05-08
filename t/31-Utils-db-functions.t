#!/usr/bin/env perl

##!perl -T
use 5.006;

use strict;
use warnings;

our $VERSION = '0.25';

use lib 'blib/lib';

use Statistics::Covid::Datum;
use Statistics::Covid::Utils;
use File::Temp;
use File::Spec;
use File::Basename;

use Data::Dump qw/pp/;

my $DEBUG = 1;

### nothing to change below
my $dirname = dirname(__FILE__);
use Test::More;

my $num_tests = 0;

my ($ret, $schema, $datumobj, $dbspecificparams, $c2f);

my $tmpdir = 'tmp';#File::Temp::tempdir(CLEANUP=>1);
ok(-d $tmpdir, "output dir exists"); $num_tests++;
my $tmpdbfile = "adb.sqlite";
my $configfile = File::Spec->catfile($dirname, 'config-for-t.json');
my $confighash = Statistics::Covid::Utils::configfile2perl($configfile);
ok(defined($confighash), "config json file parsed."); $num_tests++;

$confighash->{'fileparams'}->{'datafiles-dir'} = File::Spec->catfile($tmpdir, 'files');

my $dbfullpath = File::Spec->catfile($confighash->{'dbparams'}->{'dbdir'}, $confighash->{'dbparams'}->{'dbname'});
ok(-f $dbfullpath, "input db '$dbfullpath' exists."); $num_tests++;

my $dbh = Statistics::Covid::Utils::db_connect_using_dbi({
	'config-hash' => $confighash,
});
ok(defined $dbh, 'db_connect_using_dbi()'." : called."); $num_tests++;

ok(Statistics::Covid::Utils::table_exists_dbi($dbh, 'Datum'), 'table_exists_dbi()'." : exists."); $num_tests++;

my $tablenames = Statistics::Covid::Utils::db_table_names_using_dbi({
	'config-hash' => $confighash,
});
ok(defined($tablenames), 'db_table_names_using_dbi()'." : called."); $num_tests++;
ok(scalar(@$tablenames)>0, "has tablenames: ".join(",", @$tablenames).".") or BAIL_OUT; $num_tests++;

my $outfile = File::Spec->catfile($tmpdir, "dump.sql");
my $dparams = {
	'add-drop-table-statement' => 1,
	'outfile' => $outfile,
	'config-hash' => $confighash,
};
$ret = Statistics::Covid::Utils::db_dump($dparams);
ok(defined($ret), 'db_dump()'." : called."); $num_tests++;
ok(-f $outfile, "db_dump() : output file created ($outfile)."); $num_tests++;
ok(-s $outfile, "db_dump() : output file has content ($outfile)."); $num_tests++;

done_testing($num_tests);

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

$datumobj = Statistics::Covid::Datum->make_random_object();
ok(defined($datumobj), 'Statistics::Covid::Datum->make_random_object()'." called."); $num_tests++;

$dbspecificparams = $datumobj->_dbspecific;
ok(defined($dbspecificparams), "dbspecificparams() called."); $num_tests++;

$schema = $datumobj->_dbspecific->{'schema'};
ok(defined($schema), "'schema' exists and is defined."); $num_tests++;

done_testing($num_tests);

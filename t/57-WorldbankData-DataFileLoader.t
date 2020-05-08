#!/usr/bin/env perl

##!perl -T
use 5.006;

use strict;
use warnings;

our $VERSION = '0.25';

use lib 'blib/lib';

use Statistics::Covid::Utils;
use Statistics::Covid::WorldbankData;
use Statistics::Covid::WorldbankData::Builder;
use Statistics::Covid::WorldbankData::IO;
use File::Temp;
use File::Spec;
use File::Basename;

use Data::Dump qw/pp/;

my $DEBUG = 0;

### nothing to change below
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

my $datasetsdir = File::Spec->catfile($dirname, '..', $confighash->{'worldbankdata'}->{'datafiles-dir'});
$confighash->{'fileparams'}->{'datafiles-dir'} = File::Spec->catfile($tmpdir, 'files');
$confighash->{'dbparams'}->{'dbtype'} = 'SQLite';
$confighash->{'dbparams'}->{'dbdir'} = File::Spec->catfile($tmpdir, 'db');
$confighash->{'dbparams'}->{'dbname'} = $tmpdbfile;
my $dbfullpath = File::Spec->catfile($confighash->{'dbparams'}->{'dbdir'}, $confighash->{'dbparams'}->{'dbname'});

ok(-d $datasetsdir, "datasets dir ($datasetsdir) exists.") or BAIL_OUT; $num_tests++;

my $builder = Statistics::Covid::WorldbankData::Builder->new({
	'config-hash' => $confighash,
	'debug' => $DEBUG
});
ok(defined($builder), 'Statistics::Covid::WorldbankData::Builder->new()'." called."); $num_tests++;
$io = $builder->worldbank_io();
ok(defined($io), "Statistics::Covid::WorldbankData::IO->new() called"); $num_tests++;

$schema = $io->db_connect();
ok(defined($schema), "connect to DB"); $num_tests++;
ok($io->db_is_connected(), "connected to DB") or BAIL_OUT; $num_tests++;
$count = $io->db_count();
ok($count>=0, "db_count() called."); $num_tests++;

if( $count > 0 ){
	$ret=$io->db_delete_rows();
	ok($ret>0, "erased all table rows"); $num_tests++;
	ok(0==$io->db_count(), "no rows in table exist"); $num_tests++;
}
$ret = $builder->create_objects_from_data_from_local_csv_files();
ok(defined($ret), 'create_objects_from_data_from_local_csv_files()'." called."); $num_tests++;
ok(exists($ret->{'countries'})&&defined($ret->{'countries'})&&(ref($ret->{'countries'})eq'ARRAY'), "'countries' exist in returned value."); $num_tests++;
ok(exists($ret->{'years'})&&defined($ret->{'years'})&&(ref($ret->{'years'})eq'ARRAY'), "'years' exist in returned value."); $num_tests++;
ok(exists($ret->{'objs'})&&defined($ret->{'objs'})&&(ref($ret->{'objs'})eq'ARRAY'), "'objs' exist in returned value."); $num_tests++;

my $num_countries = scalar @{$ret->{'countries'}};
ok($num_countries>0, "number of countries returned ($num_countries)."); $num_tests++;
my $num_years = scalar @{$ret->{'years'}};
ok($num_years>0, "number of years returned ($num_years)."); $num_tests++;
my $objs = $ret->{'objs'};
my $num_objs = scalar @$objs;
ok($num_objs>0, "number of objects returned ($num_objs)."); $num_tests++;
ok(1==1, "inserting into db $num_objs objects for the first time ..."); $num_tests++;

$ret = $io->db_insert_bulk($objs);
ok(defined($ret), "db_insert_bulk() called."); $num_tests++;
my $dups = $ret->{'num-duplicates-in-input'};
ok($dups==0, "duplicates: $dups"); $num_tests++;
ok($ret->{'num-failed'}==0, "num-failed checked (".$ret->{'num-failed'}.")"); $num_tests++;
ok($ret->{'num-replaced'}==0, "num-replaced checked (".$ret->{'num-replaced'}.")"); $num_tests++;
ok($ret->{'num-not-replaced-because-ignore-was-set'}==0, "num-not-replaced-because-ignore-was-set checked (".$ret->{'num-not-replaced-because-ignore-was-set'}.")"); $num_tests++;
ok($ret->{'num-total-records'}==$num_objs, "num-total-records checked (".$ret->{'num-total-records'}.")"); $num_tests++;
is($ret->{'num-not-replaced-because-better-exists'},0, "num-not-replaced-because-better-exists checked (".$ret->{'num-not-replaced-because-better-exists'}.")"); $num_tests++;
is($ret->{'num-virgin'},$num_objs, "num-virgin checked (".$ret->{'num-virgin'}.")"); $num_tests++;
$count = $io->db_count();
ok($count>0, "db_count() called."); $num_tests++;
is($count,$num_objs, "total count in db checked ($count)"); $num_tests++;

# now try and insert those back in, nothing should go
# second time, nothing must be saved
$ret = $io->db_insert_bulk($objs);
ok($ret->{'num-failed'}==0, "num-failed checked (".$ret->{'num-failed'}.")"); $num_tests++;
ok($ret->{'num-replaced'}==0, "num-replaced checked (".$ret->{'num-replaced'}.")"); $num_tests++;
ok($ret->{'num-not-replaced-because-ignore-was-set'}==0, "num-not-replaced-because-ignore-was-set checked (".$ret->{'num-not-replaced-because-ignore-was-set'}.")"); $num_tests++;
ok($ret->{'num-total-records'}==$num_objs, "num-total-records checked (".$ret->{'num-total-records'}.")"); $num_tests++;
ok($ret->{'num-not-replaced-because-better-exists'}==$num_objs, "num-not-replaced-because-better-exists checked (".$ret->{'num-not-replaced-because-better-exists'}.")"); $num_tests++;
ok($ret->{'num-virgin'}==0, "num-virgin checked (".$ret->{'num-virgin'}.")"); $num_tests++;
$count = $io->db_count();
ok($count==$num_objs, "total count in db checked ($count)"); $num_tests++;

# retrieve the objects back
my $objs2 = $io->db_select();
ok(defined($objs2), "db_select(): called."); $num_tests++;
is(scalar(@$objs2), $num_objs, "db_select(): number of objects selected (".scalar(@$objs2).") same as those saved ($num_objs)."); $num_tests++;
# compare the objects saved and retrieved
is(Statistics::Covid::Utils::objects_equal($objs, $objs2), 1, "exact same content of objects saved to DB and selected."); $num_tests++;

ok($io->db_disconnect(), "db_disconnect() called."); $num_tests++;
ok(!$io->db_is_connected(), "db_isconnected() checked."); $num_tests++;

$builder = undef;
$io = undef;

# now use the highlevel interface
$builder = Statistics::Covid::WorldbankData::Builder->new({
	'config-hash' => $confighash,
	'debug' => $DEBUG
});
ok(defined($builder), 'Statistics::Covid::WorldbankData::Builder->new()'." called."); $num_tests++;
$ret = $builder->update();
ok(defined($ret), 'update()'." called."); $num_tests++;

ok(exists($ret->{'fetch'})&&defined($ret->{'fetch'})&&(ref($ret->{'fetch'})eq'HASH'), "'fetch' exists in returned value."); $num_tests++;
my $info_fetch = $ret->{'fetch'};

ok(exists($ret->{'create'})&&defined($ret->{'create'})&&(ref($ret->{'create'})eq'HASH'), "'create' exists in returned value."); $num_tests++;
my $info_create = $ret->{'create'};
ok(exists($info_create->{'countries'})&&defined($info_create->{'countries'})&&(ref($info_create->{'countries'})eq'ARRAY'), "'countries' exist in returned value."); $num_tests++;
ok(exists($info_create->{'years'})&&defined($info_create->{'years'})&&(ref($info_create->{'years'})eq'ARRAY'), "'years' exist in returned value."); $num_tests++;
ok(exists($info_create->{'objs'})&&defined($info_create->{'objs'})&&(ref($info_create->{'objs'})eq'ARRAY'), "'objs' exist in returned value."); $num_tests++;

ok(exists($ret->{'insert'})&&defined($ret->{'insert'})&&(ref($ret->{'insert'})eq'HASH'), "'insert' exists in returned value."); $num_tests++;
my $info_insert = $ret->{'insert'};

$objs = $info_create->{'objs'};
ok(defined($objs), "objects created."); $num_tests++;
my $num_objs2 = scalar(@$objs);
is($num_objs2, $num_objs, "created same number of objects for a second time."); $num_tests++;
my $num_skipped = $info_insert->{'num-not-replaced-because-better-exists'};
is($num_skipped, $num_objs2, "nothing inserted the second time.") or BAIL_OUT(pp($info_insert)); $num_tests++;
my $num_virgin = $info_insert->{'num-virgin'};
is($num_virgin, 0, "update() nothing inserted the second time.") or BAIL_OUT(pp($info_insert)); $num_tests++;

# and now update with overwriting
$builder = undef;
$builder = Statistics::Covid::WorldbankData::Builder->new({
	'config-hash' => $confighash,
	'debug' => $DEBUG
});
ok(defined($builder), 'Statistics::Covid::WorldbankData::Builder->new()'." called."); $num_tests++;
$ret = $builder->update({
	'overwrite-db' => 1
});
ok(exists($ret->{'fetch'})&&defined($ret->{'fetch'})&&(ref($ret->{'fetch'})eq'HASH'), "'fetch' exists in returned value."); $num_tests++;
$info_fetch = $ret->{'fetch'};

ok(exists($ret->{'create'})&&defined($ret->{'create'})&&(ref($ret->{'create'})eq'HASH'), "'create' exists in returned value."); $num_tests++;
$info_create = $ret->{'create'};
ok(exists($info_create->{'countries'})&&defined($info_create->{'countries'})&&(ref($info_create->{'countries'})eq'ARRAY'), "'countries' exist in returned value."); $num_tests++;
ok(exists($info_create->{'years'})&&defined($info_create->{'years'})&&(ref($info_create->{'years'})eq'ARRAY'), "'years' exist in returned value."); $num_tests++;
ok(exists($info_create->{'objs'})&&defined($info_create->{'objs'})&&(ref($info_create->{'objs'})eq'ARRAY'), "'objs' exist in returned value."); $num_tests++;

ok(exists($ret->{'insert'})&&defined($ret->{'insert'})&&(ref($ret->{'insert'})eq'HASH'), "'insert' exists in returned value."); $num_tests++;
$info_insert = $ret->{'insert'};

ok(exists($info_create->{'objs'})&&defined($info_create->{'objs'})&&(ref($info_create->{'objs'})eq'ARRAY'), "'insert' exists in returned value."); $num_tests++;
$objs2 = $info_create->{'objs'};
$num_objs2 = scalar @$objs;
is($num_objs, $num_objs2, "update() ALL objects inserted ($num_objs and $num_objs2)."); $num_tests++;

ok(defined($objs2), "object created."); $num_tests++;
$num_objs2 = scalar(@$objs2);
is($num_objs2, $num_objs, "created same number of objects for a third time."); $num_tests++;
$num_skipped = $info_insert->{'num-not-replaced-because-better-exists'};
is($num_skipped, 0, "all inserted the third time because overwrite.") or BAIL_OUT(pp($info_insert)); $num_tests++;
$num_virgin = $info_insert->{'num-virgin'};
is($num_virgin, 0, "update() nothing virgin the third time because all exist already.") or BAIL_OUT(pp($info_insert)); $num_tests++;
my $num_replaced = $info_insert->{'num-replaced'};
is($num_replaced, $num_objs2, "update() all inserted the third time because overwrite.") or BAIL_OUT(pp($info_insert)); $num_tests++;

done_testing($num_tests);

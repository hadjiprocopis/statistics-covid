#!/usr/bin/env perl

###!perl -T
###!/usr/bin/env perl

use 5.006;

use lib 'blib/lib';

use strict;
use warnings;

our $VERSION = '0.25';

use Statistics::Covid::DataProvider::World::JHUlocaldir;
use Statistics::Covid::Datum::IO;
use Statistics::Covid::Datum;
use Statistics::Covid::Utils;

use File::Temp;
use File::Spec;
use File::Basename;
use Data::Dump qw/pp/;

my $DEBUG = 0;

### nothing to change below
my $dirname = dirname(__FILE__);

use Test::More;

my $num_tests = 0;

my ($ret, $count, $io, $schema, $da);

my $tmpdir = File::Temp::tempdir(CLEANUP=>1);
my $tmpbasename = File::Spec->catfile($tmpdir, "afile");
ok(-d $tmpdir, "output dir exists"); $num_tests++;
my $tmpdbfile = "adb.sqlite";
my $configfile = File::Spec->catfile($dirname, 'config-for-t.json');
my $confighash = Statistics::Covid::Utils::configfile2perl($configfile);
ok(defined($confighash), "config json file parsed.") or BAIL_OUT("can not continue."); $num_tests++;

my $sample_input_data_dir = $confighash->{'fileparams'}->{'datafiles-dir'};
$confighash->{'fileparams'}->{'datafiles-dir'} = File::Spec->catfile($tmpdir, 'files');
$confighash->{'dbparams'}->{'dbtype'} = 'SQLite';
$confighash->{'dbparams'}->{'dbdir'} = File::Spec->catfile($tmpdir, 'db');
$confighash->{'dbparams'}->{'dbname'} = $tmpdbfile;
my $dbfullpath = File::Spec->catfile($confighash->{'dbparams'}->{'dbdir'}, $confighash->{'dbparams'}->{'dbname'});

my ($providerObj);
$providerObj = Statistics::Covid::DataProvider::World::JHUlocaldir->new({
	'config-hash' => $confighash,
	'debug' => $DEBUG,
	'paths' => ['abc'],
	'filenames' => ['a', 'b', 'c'],
	'file-patterns' => ['^a+$', '^b+$', '^\d{3}c+d$'],
});
ok(defined $providerObj, "Statistics::Covid::DataProvider::World::JHUlocaldir->new() called"); $num_tests++;
ok(defined($providerObj->{'repository-local'}), "'repository-local' must be defined"); $num_tests++;
ok(defined($providerObj->{'repository-local'}->[0]->{'paths'}), "'paths' must be defined"); $num_tests++;
ok(defined($providerObj->{'repository-local'}->[0]->{'file-patterns'}), "'file-patterns' must be defined"); $num_tests++;
ok(defined($providerObj->{'repository-local'}->[0]->{'filenames'}), "'filenames' must be defined"); $num_tests++;
ok($providerObj->{'repository-local'}->[0]->{'paths'}->[0] eq 'abc', "'paths' must be set"); $num_tests++;
my ($fps, $str);
$fps = $providerObj->{'repository-local'}->[0]->{'file-patterns'};
$str = 'aaaaa'; ok($str =~ $fps->[0], "file-pattern ".$fps->[0]." matched against '$str'."); $num_tests++;
$str = 'bbbbb'; ok($str =~ $fps->[1], "file-pattern ".$fps->[1]." matched against '$str'."); $num_tests++;
$str = '345ccccd'; ok($str =~ $fps->[2], "file-pattern ".$fps->[2]." matched against '$str'."); $num_tests++;
$fps = $providerObj->{'repository-local'}->[0]->{'filenames'};
$str = 'a'; ok($str eq $fps->[0], "filename matched '".$fps->[0]."' against '$str'."); $num_tests++;
$str = 'b'; ok($str eq $fps->[1], "filename matched '".$fps->[1]."' against '$str'."); $num_tests++;
$str = 'c'; ok($str eq $fps->[2], "filename matched '".$fps->[2]."' against '$str'."); $num_tests++;

# create the one to use
$providerObj = Statistics::Covid::DataProvider::World::JHUlocaldir->new({
	'config-hash' => $confighash,
	'debug' => $DEBUG,
});
ok(defined $providerObj, "Statistics::Covid::DataProvider::World::JHUlocaldir->new() called"); $num_tests++;
ok(! defined $providerObj->{'repository-local'}->[0]->{'paths'}, "'paths' must be undefined"); $num_tests++;
ok(! defined $providerObj->{'repository-local'}->[0]->{'filenames'}, "'filenames' must be undefined"); $num_tests++;
ok(  defined $providerObj->{'repository-local'}->[0]->{'file-patterns'}, "'file-patterns' must be defined"); $num_tests++;

# fetch something
$fps = [qr/03\-\d{2}\-2020.csv/i];
my $datas = $providerObj->fetch({
	'file-patterns' => $fps,
	'paths' => [$sample_input_data_dir],
});
ok(defined($datas), "fetch() data from remote data provider"); $num_tests++;
my $errors = 0;
for my $adatas (@$datas){
	my $afile = $adatas->[0];
	for my $afp (@$fps){
		if( $afile !~ $afp ){ $errors++; ok(0==1, "'filename-patterns' '$afp' matched '$afile' but it shouldn't."); $num_tests++; }
	}
	if( scalar(@$adatas)!=4 || ! defined($adatas->[3]) ){ $errors++; ok(0==1, "has data-id (size is ".@$adatas.")."); $num_tests++; }
	if( $DEBUG>0 ){ warn "read file: '$afile'\n" }
}
ok($errors==0, "data-id created for all data returned"); $num_tests++;
my $numdatas = scalar @{$datas->[0]->[2]}; # the number of items read from file

# save to local file
$ret = $providerObj->save_fetched_data_to_localfile($datas);
ok(defined($ret), "save fetched data to local disk."); $num_tests++;
is(scalar(@$ret), scalar(@$datas), "save fetched data to local disk."); $num_tests++;
$errors = 0;
my $afilename;
for my $abasename (@$ret){
	$afilename = $abasename.'.data.csv';
	if( $abasename =~ /data\.csv$/ ){ $errors++; ok(0==1, "basename contains 'data.csv'"); $num_tests++ }
	if( ! -f $afilename ){ $errors++; ok(0==1, "local file exists ($afilename)"); $num_tests++ }
	if( ! -s $afilename ){ $errors++; ok(0==1, "local file has content ($afilename)"); $num_tests++ }
}
ok($errors==0, "all local files created and exist"); $num_tests++;

# create Datum objects
my $datumObjs = $providerObj->create_Datums_from_fetched_data($datas);
ok(defined($datumObjs), "create_Datums_from_fetched_data() : called."); $num_tests++;
ok(ref($datumObjs) eq 'ARRAY', "create_Datums_from_fetched_data() : got ARRAYref back."); $num_tests++;
my $num_datumObjs = scalar @$datumObjs;
ok($num_datumObjs>0, "create_Datums_from_fetched_data() : got at least 1 datum object back (".$num_datumObjs.")."); $num_tests++;
is($num_datumObjs, $numdatas, "create_Datums_from_fetched_data() : number of items ($num_datumObjs) same as number read from files ($numdatas)."); $num_tests++;

$errors = 0;
my @totaldatas2;
for my $abasename (@$ret){
	# read data back from local file
	my $datas2 = $providerObj->load_fetched_data_from_localfile($abasename);
	ok(defined($datas2), "load_fetched_data_from_localfile() called ($abasename)."); $num_tests++;
	push @totaldatas2, $datas2->[0];
}
is(scalar(@totaldatas2), scalar(@$datas), "load_fetched_data_from_localfile() : read as many objects (".scalar(@totaldatas2).") as before (".scalar(@$datas).")."); $num_tests++;

# create Datum objects from that data
my $datumObjs2 = $providerObj->create_Datums_from_fetched_data(\@totaldatas2);
ok(defined($datumObjs2) && (ref($datumObjs2) eq 'ARRAY') && (scalar(@$datumObjs2)>0), "Convert fetched data to Datum objects."); $num_tests++;
my $num_datumObjs2 = scalar @$datumObjs2;
ok($num_datumObjs == $num_datumObjs2, "same number of datum objects read from file and fetched."); $num_tests++;
# compare the Datum objects;
is(Statistics::Covid::Utils::objects_equal($datumObjs, $datumObjs2), 1, "exact same content of datum objects read from file and fetched."); $num_tests++;

# save datums to db
$io = Statistics::Covid::Datum::IO->new({
	'config-hash' => $confighash,
	'debug' => $DEBUG
});
ok(defined($io), "Statistics::Covid::Datum::IO->new() called"); $num_tests++;
ok(-d $tmpdir, "output dir exists"); $num_tests++;
$schema = $io->db_connect();
ok(defined($schema), "connect to DB"); $num_tests++;
ok($io->db_is_connected(), "connected to DB") or BAIL_OUT; $num_tests++;

ok($io->db_clear()!=-1, "cleared db"); $num_tests++;
my $countbefore = $io->db_count();
ok($countbefore>=0, "db_count() called."); $num_tests++;

# insert for the first time
$ret = $io->db_insert_bulk($datumObjs);
ok(defined($ret), "db_insert_bulk() : called."); $num_tests++;
my $dups = $ret->{'num-duplicates-in-input'};
ok($dups>=0, "duplicates: $dups"); $num_tests++;
ok($ret->{'num-failed'}==0, "num-failed checked (".$ret->{'num-failed'}.")"); $num_tests++;
ok($ret->{'num-replaced'}==0, "num-replaced checked (".$ret->{'num-replaced'}.")"); $num_tests++;
ok($ret->{'num-not-replaced-because-ignore-was-set'}==0, "num-not-replaced-because-ignore-was-set checked (".$ret->{'num-not-replaced-because-ignore-was-set'}.")"); $num_tests++;
ok($ret->{'num-total-records'}==$num_datumObjs, "num-total-records checked (".$ret->{'num-total-records'}.")"); $num_tests++;
if( $dups == 0 ){
	is($ret->{'num-not-replaced-because-better-exists'},0, "num-not-replaced-because-better-exists checked (".$ret->{'num-not-replaced-because-better-exists'}.")"); $num_tests++;
	is($ret->{'num-virgin'},$num_datumObjs, "num-virgin checked (".$ret->{'num-virgin'}.")"); $num_tests++;
} else {
	ok($ret->{'num-not-replaced-because-better-exists'}>0, "num-not-replaced-because-better-exists checked (when duplicates exist) (".$ret->{'num-not-replaced-because-better-exists'}.">0)"); $num_tests++;
	ok($ret->{'num-virgin'}<$num_datumObjs, "num-virgin checked (when duplicates exist) (".$ret->{'num-virgin'}."<$num_datumObjs)"); $num_tests++;
}
$count = $io->db_count();
if( $dups == 0 ){
	is($count,$num_datumObjs, "total count in db checked ($count==$num_datumObjs)"); $num_tests++;
} else {
	ok($count==($num_datumObjs-$dups), "total count in db checked ($count==($num_datumObjs-$dups)) (when duplicates exist)"); $num_tests++;
}

# second time, nothing must be saved
$ret = $io->db_insert_bulk($datumObjs);
ok($ret->{'num-failed'}==0, "num-failed checked (".$ret->{'num-failed'}.")"); $num_tests++;
ok($ret->{'num-replaced'}==0, "num-replaced checked (".$ret->{'num-replaced'}.")"); $num_tests++;
ok($ret->{'num-not-replaced-because-ignore-was-set'}==0, "num-not-replaced-because-ignore-was-set checked (".$ret->{'num-not-replaced-because-ignore-was-set'}.")"); $num_tests++;
ok($ret->{'num-total-records'}==$num_datumObjs, "num-total-records checked (".$ret->{'num-total-records'}.")"); $num_tests++;
ok($ret->{'num-not-replaced-because-better-exists'}==$num_datumObjs, "num-not-replaced-because-better-exists checked (".$ret->{'num-not-replaced-because-better-exists'}.")"); $num_tests++;
ok($ret->{'num-virgin'}==0, "num-virgin checked (".$ret->{'num-virgin'}.")"); $num_tests++;
$count = $io->db_count();
if( $dups == 0 ){
	is($count,$num_datumObjs, "total count in db checked ($count==$num_datumObjs)"); $num_tests++;
} else {
	ok($count==($num_datumObjs-$dups), "total count in db checked ($count==($num_datumObjs-$dups)) (when duplicates exist)"); $num_tests++;
}

# retrieve the objects back
my $datumObjs3 = $io->db_select();
ok(defined($datumObjs3), "db_select(): called."); $num_tests++;
is(scalar(@$datumObjs3), $num_datumObjs-$dups, "db_select(): number of objects selected (".scalar(@$datumObjs3).") same as those saved ($num_datumObjs) minus the duplicates ($dups)."); $num_tests++;
# compare the Datum objects saved and retrieved
if( $dups == 0 ){
	is(Statistics::Covid::Utils::objects_equal($datumObjs, $datumObjs3), 1, "exact same content of datum objects saved to DB and selected."); $num_tests++;
}

ok($io->db_disconnect(), "db_disconnect() called."); $num_tests++;
ok(!$io->db_is_connected(), "db_isconnected() checked."); $num_tests++;

done_testing($num_tests);

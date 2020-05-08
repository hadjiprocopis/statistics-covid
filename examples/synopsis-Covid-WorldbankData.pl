#!/usr/bin/perl
use 5.006;

use strict;
use warnings;

our $VERSION = '0.23';

use lib 'blib/lib';

use Data::Dump qw/pp/;

my $delete_out_files = 1;
my $DEBUG = 0;

### nothing to change below
use File::Spec;
use File::Basename;
use Test::More;

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
use Statistics::Covid::WorldbankData;
use Statistics::Covid::WorldbankData::Builder;

my ($builder, $ret);

  $builder = Statistics::Covid::WorldbankData::Builder->new({
        'config-hash' => $confighash,
        'debug' => 1,
  }) or die "failed to construct";

  $ret = $builder->update({
  }) or die "failed to update";

  # 'create' contains the created objs in 'objs' and you do not want to print all these!
  print "Success fetching and inserting, this is some info:\n".pp($ret->{'create'}->{'countries'})."\n";
  print "Success fetching and inserting, this is some info:\n".pp($ret->{'create'}->{'years'})."\n";
  print "Success fetching and inserting, this is some info:\n".pp($ret->{'fetch'})."\n";
  print "Success fetching and inserting, this is some info:\n".pp($ret->{'insert'})."\n";

my $WBio = Statistics::Covid::WorldbankData::IO->new({
      # the params, the relevant section is
      # under key 'Worldbankdata'
      'config-hash' => $confighash,
      'debug' => 1,
  }) or die "failed to construct";
$WBio->db_connect() or die "failed to connect to db (while on world bank)";
my $WBobjs = $WBio->db_select({
	'conditions' => {
		countryname=>['Angola', 'Afghanistan'],
	},
	# see L<DBIx::Class::ResultSet#+select>
	'attributes' => {
		'group_by' => ['countrycode'],
		'+select' => {'max' => 'year'},
	},
});
print pp($_->toHashtable()) for @$WBobjs;
is(scalar(@$WBobjs), 2, "exactly two items got selected"); $num_tests++;

done_testing($num_tests);

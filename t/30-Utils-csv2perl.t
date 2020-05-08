#!/usr/bin/env perl
use 5.006;

use strict;
use warnings;

use lib 'blib/lib';

our $VERSION = '0.25';

use Statistics::Covid::Utils;
use File::Temp;
use File::Spec;
use File::Basename;
use Data::Dump qw/pp/;

my $dirname = dirname(__FILE__);

use Test::More;

my $num_tests = 0;

my ($ret, $count, $io, $schema, $da);

my $tmpdir = File::Temp::tempdir(CLEANUP=>1);
ok(-d $tmpdir, "output dir exists"); $num_tests++;
my $tmpdbfile = "adb.sqlite";
my $configfile = File::Spec->catfile($dirname, 'config-for-t.json');
my $confighash = Statistics::Covid::Utils::configfile2perl($configfile);
ok(defined($confighash), "config json file parsed.") or BAIL_OUT("can not continue."); $num_tests++;

#$confighash->{'fileparams'}->{'datafiles-dir'} = File::Spec->catfile($tmpdir, 'files');
$confighash->{'dbparams'}->{'dbtype'} = 'SQLite';
$confighash->{'dbparams'}->{'dbdir'} = File::Spec->catfile($tmpdir, 'db');
$confighash->{'dbparams'}->{'dbname'} = $tmpdbfile;
my $dbfullpath = File::Spec->catfile($confighash->{'dbparams'}->{'dbdir'}, $confighash->{'dbparams'}->{'dbname'});

my $csvfile = File::Spec->catfile($confighash->{'fileparams'}->{'datafiles-dir'}, 'JHUgithub.csv');
ok(-f $csvfile, "test csv file exists ($csvfile)") or BAIL_OUT; $num_tests++;
ok(-s $csvfile, "test csv file has content ($csvfile)") or BAIL_OUT; $num_tests++;

my $vals = Statistics::Covid::Utils::csv2perl({
	'input-filename' => $csvfile,
	'has-header-at-this-line' => 1,
});
ok(defined($vals), 'Statistics::Covid::Utils::csv2perl()'." : called"); $num_tests++;
ok(scalar(@$vals)>0, 'Statistics::Covid::Utils::csv2perl()'." : called"); $num_tests++;
my $found = 0;
for my $anentry (@$vals){
	if( ref($anentry) ne 'HASH' ){ ok(0==1, "item is not a hashref even if declared that have header, it is ".ref($anentry)); $num_tests++; }
	if( ($anentry->{'combined_key'} eq 'Zimbabwe')
	  &&($anentry->{'last_update'} eq '2020-04-01 21:58:34') ){ $found=1; last }
}
ok($found==1, "found entry in CSV file"); $num_tests++;

# now read the file and supply it as a string
my $FH;
ok(open($FH, '<:encoding(UTF-8)', $csvfile), "opened csv file manually ($csvfile)") or BAIL_OUT; $num_tests++;
my $csvstring;
{local $/ = undef; $csvstring = <$FH> } close($FH);
ok(defined($csvstring), "read CSV file into memory ($csvfile)"); $num_tests++;
my $vals2 = Statistics::Covid::Utils::csv2perl({
	'input-string' => $csvstring,
	'has-header-at-this-line' => 1,
});
ok(defined($vals2), 'Statistics::Covid::Utils::csv2perl()'." : called"); $num_tests++;
ok(scalar(@$vals2)>0, 'Statistics::Covid::Utils::csv2perl()'." : returned data"); $num_tests++;
$found = 0;
for my $anentry (@$vals2){
	if( ref($anentry) ne 'HASH' ){ ok(0==1, "item is not a hashref even if declared that has header, it is ".ref($anentry)); $num_tests++; }
	if( ($anentry->{'combined_key'} eq 'Zimbabwe')
	  &&($anentry->{'last_update'} eq '2020-04-01 21:58:34') ){ $found=1; last }
}
is($found, 1, "found entry in CSV file"); $num_tests++;

ok(scalar(@$vals)==scalar(@$vals2), "contents has the same number of items (".scalar(@$vals)." and ".scalar(@$vals2).")"); $num_tests++;
is_deeply($vals, $vals2, "contents are exactly the same"); $num_tests++;

# now read from file and remove header and check
ok(open($FH, '<:encoding(UTF-8)', $csvfile), "opened csv file manually ($csvfile)") or BAIL_OUT; $num_tests++;
<$FH>; #remove the first line which is the header
$csvstring = undef;
{local $/ = undef; $csvstring = <$FH> } close($FH);
ok(defined($csvstring), "read CSV file into memory ($csvfile)"); $num_tests++;
my $vals3 = Statistics::Covid::Utils::csv2perl({
	'input-string' => $csvstring,
	#'has-header-at-this-line' => undef, # no header
});
ok(defined($vals3), 'Statistics::Covid::Utils::csv2perl()'." : called"); $num_tests++;
ok(scalar(@$vals3)>0, 'Statistics::Covid::Utils::csv2perl()'." : returned data"); $num_tests++;
$found = 0;
for my $anentry (@$vals3){
	if( ref($anentry) ne 'ARRAY' ){ ok(0==1, "item is not an arrayref even if declared that has NO header, it is ".ref($anentry)); $num_tests++; }
	for my $a2 (@$anentry){
		if( ($a2 eq 'Zimbabwe') || ($a2 eq '2020-04-01 21:58:34') ){ $found++ }
		if( $found==2 ){ last }
	}
	if( $found==2 ){ last }
}
is($found, 2, "found entry in CSV file (without header)"); $num_tests++;

done_testing($num_tests);

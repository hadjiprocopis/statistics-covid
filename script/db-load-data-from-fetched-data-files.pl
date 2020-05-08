#!/usr/bin/env perl

use strict;
use warnings;

our $VERSION = '0.24';

use Statistics::Covid;

use Getopt::Long;
use Data::Dump qw/pp/;

my $configfile1 = undef;
my $configfile2 = undef;
my $tablename = 'Datum';
my $DEBUG = 0;
my $clear_db_before = 0;
# default values
my %providers = (
	'UK::BBC'=>0,
	'UK::GOVUK'=>0,
	'World::JHU'=>0,
	'World::JHUgithub'=>0,
	'World::JHUlocaldir'=>0,
	'CY::UCY' => 0,
);
my %do_save_to_file = map { $_ => ($_ =~ /localdir/?0:1) } keys %providers;
my %do_save_to_db = map { $_ => 1 } keys %providers;

if( ! Getopt::Long::GetOptions(
	'config-file-source=s' => \$configfile1,
	'config-file-destination=s' => \$configfile2,
	'provider=s' => sub {
		if( ! exists $providers{$_[1]} ){ print STDERR usage()."\n\n$0 : error, provider '$_[1]' does not exist (via --provider), I know of these: '".join("', '", sort keys %providers)."'.\n"; exit(1) }
		$providers{$_[1]} = 1;
		$do_save_to_file{$_[1]} = 1;
		$do_save_to_db{$_[1]} = 1;
	},
	'tablename=s' => \$tablename,
	'clear' => \$clear_db_before,
	'debug=i' => \$DEBUG,
) ){ die usage() . "\n\nerror in command line."; }

my @providers = grep { $providers{$_} == 1 } sort keys %providers;
die usage() . "\n\nA configuration file (--config-file-source) is required." unless defined $configfile1;
die usage() . "\n\nAt least one provider must be specified (--provider)." unless scalar(@providers)>0;

my $ts = time;

# does the table exist? if it does a package will be loaded (and must exist)
my $IOpackage = 'Statistics::Covid::'.$tablename.'::IO';
my $IOpackagefile = $IOpackage.'.pm'; $IOpackagefile =~ s|\:\:|/|g;
eval { require $IOpackagefile; 1; };
die "failed to load packagefile '$IOpackagefile'. Most likely table '$tablename' is unknown or was wrongly capitalised, e.g. the 'Datum' table is correct : $@"
	if $@;

my $covid = Statistics::Covid->new({
	'config-file' => $configfile1,
	'debug' => $DEBUG,
	'providers' => \@providers,
	'save-to-file' => \%do_save_to_file,
	'save-to-db' => \%do_save_to_db,
});
die "call to Statistics::Covid->new() has failed (1)."
	unless defined $covid;
# read all data files from all the datadirs of each of our loaded providers
# we get a hashref key=providerstr, value=arrayref of datum objs
my $datumObjs = $covid->read_data_from_files();
die "call to read_data_from_files() has failed."
	unless defined $datumObjs;

my $destIO;
if( defined $configfile2 ){
	# we are saving to a different data collection
	$destIO = $IOpackage->new({
		'config-file' => $configfile2,
		'debug' => $DEBUG,
	});
	die "call to $IOpackage->new() has failed (2)."
		unless defined $covid;
	if( $clear_db_before ){
		print "$0 : destination table '$tablename' cleared.\n";
		$destIO->db_clear()
	}
	if( ! $destIO->db_connect() ){ print STDERR "$0 : failed to connect to database.\n"; exit(1) }
} else { $destIO = $covid->datum_io() }

my $count1 = $destIO->db_count();
# save to db
# we get back hash of {providerstr=>$datumobjsarrayref}
my ($count2, $count3);
for my $k (@providers){
	$count2 = $destIO->db_count();
#	print "$0 : provider '$k' has ".scalar(@{$datumObjs->{$k}})." items from file.\n";
	my $ret = $destIO->db_insert_bulk($datumObjs->{$k});
	die "call to db_insert_bulk() has failed."
		unless defined $ret;
	$count3 = $destIO->db_count();
	print "$0 : success, destination database for '$k':\n" . pp($ret) . "\n";
	print "$0 : rows in '$tablename' before : $count2\n";
	print "$0 : rows in '$tablename' after  : $count3\n";
}
$count3 = $destIO->db_count();
print "$0 : rows in '$tablename' when started : $count1\n";
print "$0 : rows in '$tablename' at the end   : $count3\n";
print "$0 : succes, done in ".(time-$ts)." seconds.\n";
# db disconnects on $destIO destruction

#### end

sub usage {
	return "Usage : $0 <options>\n"
	. " --config-file-src C : specify a configuration file for doing IO with the source database.\n"
	. " --tablename T : specify the tablename for the SELECT, this corresponds to a package- name : Statistics::Covid::<tablename>::IO, so use the exact same capitalisation (e.g. 'Datum' and not 'datum').\n"
	. "[--config-file-destination C : specify a configuration file for doing IO with the destination database, if not defined them the source database will be used as the destination.]\n"
	. "[--clear : erase all contents of the destination database, if any and if it does indeed exist.]"
	. "[--debug Level : specify a debug level, anything >0 is verbose.]\n"
	. "\n\nThis program will open the source database, extract objects from specified table using the specified conditions and then write them onto the same table of the destination database.\n"
	. "\nExample usage:\n"
. <<'EXA'
db-search-and-make-new-db.pl --config-file-source config/config.json --config-file-destination config/destination.json --tablename 'Datum' --conditions "{'name'=>'Hackney'}" --attributes "{'rows'=>3}"
EXA
	. "\nProgram by Andreas Hadjiprocopis (andreashad2\@gmail.com / bliako\@cpan.org)\n"
	;
}


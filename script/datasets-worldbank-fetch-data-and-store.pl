#!/usr/bin/env perl

our $VERSION = '0.24';

use strict;
use warnings;

use Statistics::Covid::Utils;

use Getopt::Long;
use Data::Dump qw/pp/;

my $configfile = undef;
my $overwrite = 0;
my $DEBUG = 0;
my $clear_db_first = 0;

if( ! Getopt::Long::GetOptions(
	'config-file=s' => \$configfile,
	'overwrite!' => \$overwrite,
	'clear-db-first' => \$clear_db_first,
	'debug=i' => \$DEBUG,
) ){ die usage() . "\n\nerror in command line."; }

die usage() . "\n\nA configuration file (--config-file) is required." unless defined $configfile;

my $ts = time;

# the reason is that loading this module will create schemas etc
# which is a bit of a heavy work just to exit because we do not have a config file
# so load the module after all checks OK.
use Statistics::Covid::WorldbankData;
use Statistics::Covid::WorldbankData::Builder;
use Statistics::Covid::WorldbankData::IO;

my $confighash = Statistics::Covid::Utils::configfile2perl($configfile);
if( ! defined $confighash ){ print STDERR "$0 : failed to read the configuration file '$configfile'.\n"; exit(1) }

my $datafilesdir = $confighash->{'worldbankdata'}->{'datafiles-dir'};

my $builder = Statistics::Covid::WorldbankData::Builder->new({
	'config-hash' => $confighash,
	'debug' => $DEBUG
});
if( ! defined $builder ){ print STDERR pp($confighash)."\n$0 : call to ".'Statistics::Covid::WorldbankData::Builder->new()'." has failed for the above configuration.\n"; exit(1) }

my $io = $builder->worldbank_io(); # connects if not connect and returns obj
if( ! $io || ! $io->db_is_connected() ){ print STDERR pp($confighash)."\n$0 : error, failed to connect to db, call to ".'worldbank_io()'." has failed for above configuration.\n"; exit(1) }

my $params = {
	'datafiles-dir' => $datafilesdir,
	'overwrite' => $overwrite,
	'clear-db-first' => $clear_db_first,
	'debug' => $DEBUG,
};
my $ret = $builder->update($params);
if( ! defined $ret ){ print STDERR "$0 : error, call to ".'update()'." has failed.\n"; exit(1) }

my $info_fetch = $ret->{'fetch'};
my $info_create = $ret->{'create'};
my $info_insert = $ret->{'insert'};
my $num_countries = scalar @{$info_create->{'countries'}};
my $num_years = scalar @{$info_create->{'years'}};
my $objs = $info_create->{'objs'};
my $num_objs = scalar(@$objs);

for my $k (sort keys %$info_fetch){
	my $v = $info_fetch->{$k};
	my $afile = $v->{'filename'};
	if( ! (-f $afile && -s $afile) ){ print STDERR "$0 : error, file '$afile' does not exist or is empty, the url was '".$v->{'url'}."'.\n"; exit(1) }
	if( $v->{'downloaded'} == 1 ){ print "$0 : file downloaded '$afile'.\n" }
}
if( $DEBUG > 0 ){
	# don't print all the objects!!!
	delete $info_create->{'objs'};
	print pp($ret)
}
print "\n$0 : done fetched data for $num_countries countries over $num_years years in a total of $num_objs objects.\n";
print "  rows in database before: ".$ret->{'db-rows'}->{'before'}."\n";
print "  rows in database after : ".$ret->{'db-rows'}->{'after'}."\n";
print "  database cleared first : ".$ret->{'db-rows'}->{'db-cleared-first'}."\n";
print "$0: success, done in ".(time-$ts)." seconds.\n";

#### end

sub usage {
	return "Usage : $0 <options>\n"
	. " --config-file C : specify a configuration file which contains where to save files, where is the DB, what is its type (SQLite or MySQL), and DB connection options. The example configuration at 't/example-config.json' can be used as a quick start. Make a copy if that file and do not modify that file directly as tests may fail.\n"
	. "[--debug Level : specify a debug level, anything >0 is verbose.]\n"
	. "\nExample use:\n\n   script/statistics-covid-fetch-data-and-store.pl --config-file config/config.json\n"
	. "\nProgram by Andreas Hadjiprocopis (andreashad2\@gmail.com / bliako\@cpan.org)\n"
}


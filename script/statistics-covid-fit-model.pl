#!/usr/bin/env perl

# for more documentation use the -h flag
# briefly, it SELECTS rows from one db, specified table
# with optionally specifying conditions and attributes
# and write those to another db (which will be created if not exist)
# useful for creating test db's on the fly.

our $VERSION = '0.23';

use strict;
use warnings;

use Getopt::Long;

my $configfile = undef;
my $location_name = undef;
my $belongsto = '';
my $time_range = undef;
my $DEBUG = 0;

if( ! Getopt::Long::GetOptions(
	'config-file=s' => \$configfile,
	# exact name or SQL wildcard
	# or SQL::Abstract search condition (as a string)
	'location-name=s' => \$location_name,
	# optional: the 'name' belongs to this geo-entity
	# UK, China, World, USA etc.
	'belongsto=s' => \$belongsto,
	'time-range=s' => sub {
		$time_range = [$_[1], $_[2]];
	},
	'debug=i' => \$DEBUG,
) ){ die usage() . "\n\nerror in command line."; }

die usage() . "\n\nA configuration file (--config-file) is required." unless defined $configfile;

# the reason is that loading this module will create schemas etc
# which is a bit of a heavy work just to exit because we do not have a config file
# so load the module after all checks OK.
require Statistics::Covid;

# create the main entry point to fetch and store data
my $covid = Statistics::Covid->new({   
	'config-file' => $configfile,
	'debug' => $DEBUG,
}) or die "Statistics::Covid->new() failed";

my $datums_in_db_before = $covid->db_count_datums();
if( $datums_in_db_before < 0 ){ print STDERR "$0 : failed to get the row count of Datum records from the database.\n"; exit(1) }

my $confighash = $covid->dbparams();
my $dbtype = $confighash->{'dbtype'};
my $dbname = $dbtype eq 'SQLite'
	? File::Spec->catfile($confighash->{'dbdir'}, $confighash->{'dbname'})
	: $confighash->{'dbname'}
;

# select rows from db
# see L<Statistics::Covid> for examples.
my $objs =
  $covid->select_datums_from_db_for_specific_location_time_ascending(
	$location_name,
	$belongsto
  );
if( ! defined($objs) ){ print STDERR "$0 : call to ".'select_datums_from_db_for_specific_location_time_ascending()'." has failed for database '$dbname'.\n"; exit(1) }
my $numobjs = scalar @$objs;
if( $numobjs == 0 ){ print STDERR "$0 : nothing in database '".$dbname."'.\n"; exit(0) }

# fetch all the data available (posibly json), process it,
# create Datum objects, store it in DB and return an array 
# of the Datum objects just fetched  (and not what is already in DB).
my $newobjs = $covid->fetch_and_store();
if( ! defined $newobjs ){ print STDERR "$0 : call to fetch_and_store() has failed.\n"; exit(1) }

print "$0: done,\n";
print "  rows in database before: $datums_in_db_before\n";

my $datums_in_db_after = $covid->db_count_datums();
if( $datums_in_db_after < 0 ){ print STDERR "$0 : failed to get the row count of Datum records from the database.\n"; exit(1) }
print "  rows in database after : $datums_in_db_after\n";


#### end

sub usage {
	return "Usage : $0 <options>\n"
	. " --config-file C : specify a configuration file which contains where to save files, where is the DB, what is its type (SQLite or MySQL), and DB connection options. The example configuration at 't/example-config.json' can be used as a quick start. Make a copy if that file and do not modify that file directly as tests may fail.\n"
	. "[--provider P : specify a data provider, e.g. 'World::JHU' or 'UK::GOVUK' and possibly others. Multiple providers can be specified by calling this option multiple times. Default providers: '".join("', '", @providers)."'.]\n"
	. "[--debug Level : specify a debug level, anything >0 is verbose.]\n"
	. "[--(no)save-to-file : save or don't save data to files (json and pl hashtables). Default is ".($do_save_to_file?"yes":"no").".]\n"
	. "[--(no)save-to-db : save or don't save data to DB (json and pl hashtables). Default is ".($do_save_to_db?"yes":"no").".]\n"
	. "\nExample use:\n\n   script/statistics-covid-fetch-data-and-store.pl --config-file config/config.json\n"
	. "\nProgram by Andreas Hadjiprocopis (andreashad2\@gmail.com / bliako\@cpan.org)\n"
}


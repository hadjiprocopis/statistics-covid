#!/usr/bin/env perl

# for more documentation use the -h flag
# briefly, it SELECTS rows from one db, specified table
# with optionally specifying conditions and attributes
# and write those to another db (which will be created if not exist)
# useful for creating test db's on the fly.

our $VERSION = '0.24';

use strict;
use warnings;

use Getopt::Long;
use Data::Dump qw/pp/;

my %providers = (
 'World::JHUlocaldir' => 0,
 'World::JHU' => 0,
 'World::JHUgithub' => 0,
 'UK::GOVUK2' => 0,
 'UK::BBC' => 0,
 'CY::UCY' => 0,
);
#my %providers;
my $configfile = undef;
my $DEBUG = 0;
my %do_save_to_file = map { $_ => ($_ =~ /localdir/?0:1) } keys %providers;
my %do_save_to_db = map { $_ => 1 } keys %providers;
# this applies to github or local repositories
my (%provider_dirs, %provider_filenames, %provider_filepatterns, $nrows);

if( ! Getopt::Long::GetOptions(
	'provider=s' => sub {
		if( ! exists $providers{$_[1]} ){ print STDERR usage()."\n\n$0 : error, provider '$_[1]' does not exist (via --provider), I know of these: '".join("', '", sort keys %providers)."'.\n"; exit(1) }
		$providers{$_[1]} = 1
	},
	'config-file=s' => \$configfile,
	'provider-dir=s' => sub { $provider_dirs{$_[1]} = 1 },
	'provider-filename=s' => sub { $provider_filenames{$_[1]} = 1 },
	'provider-file-pattern=s' => sub { $provider_filepatterns{$_[1]} = 1 },
	'save-to-file=s' => sub {
		die "provider '$_[1]' is not known" unless exists $do_save_to_file{$_[1]};
		$do_save_to_file{$_[1]} = 1;
	},
	'no-save-to-file=s' => sub {
		die "provider '$_[1]' is not known" unless exists $do_save_to_file{$_[1]};
		$do_save_to_file{$_[1]} = 0;
	},
	'save-to-db=s' => sub {
		die "provider '$_[1]' is not known" unless exists $do_save_to_db{$_[1]};
		$do_save_to_db{$_[1]} = 1;
	},
	'no-save-to-db=s' => sub {
		die "provider '$_[1]' is not known" unless exists $do_save_to_db{$_[1]};
		$do_save_to_db{$_[1]} = 0;
	},
	'debug=i' => \$DEBUG,
) ){ die usage() . "\n\nerror in command line."; }

my @providers = grep {$providers{$_}==1} sort keys %providers;
if( scalar(@providers) == 0 ){ push @providers, 'World::JHUlocaldir', 'UK::GOVUK2', 'UK::BBC' }

die usage() . "\n\nA provider (--provider) is required." if scalar(@providers)==0;
die usage() . "\n\nA configuration file (--config-file) is required." unless defined $configfile;
die usage() . "\n\nA local provider dir (--provider-dir) is required when provider is 'World::JHUlocaldir'" if $providers{'World::JHUlocaldir'}==1 && scalar(keys %provider_dirs)==0;

my $ts = time;

# the reason is that loading this module will create schemas etc
# which is a bit of a heavy work just to exit because we do not have a config file
# so load the module after all checks OK.
require Statistics::Covid;

for(keys %providers){
	delete $do_save_to_file{$_}  unless $providers{$_} == 1;
	delete $do_save_to_db{$_}  unless $providers{$_} == 1;
}
my $cparams = {
	'config-file' => $configfile,
	'providers' => \@providers,
	'save-to-file' => \%do_save_to_file,
	'save-to-db' => \%do_save_to_db,
	'debug' => $DEBUG,
};
# add extra params for specific providers
for my $providername (@providers){
	if( $providername =~ /^World\:\:JHU(.+)$/ ){
		my $rest = $1;
		$cparams->{'provider-extra-params'}->{$providername}->{'filenames'}
			= [keys %provider_filenames] if scalar(keys %provider_filenames)>0;
		$cparams->{'provider-extra-params'}->{$providername}->{'file-patterns'}
			= [keys %provider_filepatterns] if scalar(keys %provider_filepatterns)>0;
		if( $rest eq 'localdir' ){
			$cparams->{'provider-extra-params'}->{$providername}->{'paths'}
				= [keys %provider_dirs] if scalar(keys %provider_dirs)>0;
			# default for localdir is not to save to file, so no need to set it here
		} elsif( $rest eq 'github' ){
			# for github providers default file to get is
			# today's, yersterday's, tomorrow's and day before yesterday
			#  unless otherwise specified
			# note: rate-limit on github, if you missed a lot download the repo and use
			# a '*localdir' provider
			if( scalar(keys %provider_filenames)==0 && scalar(keys %provider_filenames)==0
			&&  scalar(keys %provider_filepatterns)==0 && scalar(keys %provider_filepatterns)==0
			 ){
				my $dt = DateTime->now(time_zone => 'UTC');
				$cparams->{'provider-extra-params'}->{$providername}->{'filenames'} =
					[
						$dt->mdy().'.csv',
						$dt->add( days => 1 )->mdy().'.csv', # tomorrow and dt is incremented
						$dt->subtract( days => 2 )->mdy().'.csv', # yesterday and dt is decremented
						$dt->subtract( days => 1 )->mdy().'.csv', # day before yesterday
					];
				print "$0 : for provider '$providername', setting default filename(s) to get: '".join("', '",@{$cparams->{'provider-extra-params'}->{$providername}->{'filenames'}})."\n";
			}
		}
	}
}
if( $DEBUG > 0 ){ print pp($cparams) . "\n$0 : running with the above parameters ...\n" }

# create the main entry point to fetch and store data
my $covid = Statistics::Covid->new($cparams)
	or die pp($cparams)."\nStatistics::Covid->new() failed for the above parameters";

if( $DEBUG > 0 ){ print "$0 : using the following params:\n".pp($cparams)."\n" }

my %initial_db_counts = ();
my %apc = (
	'conditions' => {'datasource' => undef }
);
for my $aprovider (sort keys %providers){
	$apc{'conditions'}->{'datasource'} = $aprovider;
	$nrows =  $covid->db_count_datums(\%apc);
	if( $nrows == -1 ){ print STDERR pp(\%apc)."\n$0 : error, failed to get the row count for the above condition.\n"; exit(1) }
	print "$0 : datasource '$aprovider' has $nrows items on startup.\n";
	$initial_db_counts{$aprovider} = $nrows;
}
$nrows = $covid->db_count_datums(); if( $nrows < 0 ){ print STDERR "$0 : failed to get the row count of Datum records from the database.\n"; exit(1) }
$initial_db_counts{'_total'} = $nrows;


# fetch all the data available (posibly json), process it,
# create Datum objects, store it in DB and return an array 
# of the Datum objects just fetched  (and not what is already in DB).
my $newobjs = $covid->fetch_and_store();
if( ! defined $newobjs ){ print STDERR "$0 : call to fetch_and_store() has failed.\n"; exit(1) }

%apc = (
	'conditions' => {'datasource' => undef }
);
for my $aprovider (sort keys %providers){
	$apc{'conditions'}->{'datasource'} = $aprovider;
	$nrows =  $covid->db_count_datums(\%apc);
	if( $nrows == -1 ){ print STDERR pp(\%apc)."\n$0 : error, failed to get the row count for the above condition.\n"; exit(1) }
	print "  datasource '$aprovider' has $nrows items (started with ".$initial_db_counts{$aprovider}." items).\n";
}
$nrows = $covid->db_count_datums(); if( $nrows < 0 ){ print STDERR "$0 : failed to get the row count of Datum records from the database.\n"; exit(1) }
print "  rows in database before: ".$initial_db_counts{'_total'}.".\n";
print "  rows in database after : $nrows.\n";
print "$0: success, done in ".(time-$ts)." seconds.\n";

#### end

sub usage {
	return "Usage : $0 <options>\n"
	. " --config-file C : specify a configuration file which contains where to save files, where is the DB, what is its type (SQLite or MySQL), and DB connection options. The example configuration at 't/example-config.json' can be used as a quick start. Make a copy if that file and do not modify that file directly as tests may fail.\n"
	. "[--provider P : specify a data provider, e.g. 'World::JHU' or 'UK::GOVUK2' and possibly others. Multiple providers can be specified by calling this option multiple times. Default providers: '".join("', '", @providers)."'.]\n"
	. "[--provider-dir : if provider is a local dir, specify its location.]\n"
	. "[--debug Level : specify a debug level, anything >0 is verbose.]\n"
	. "[--(no)save-to-file : save or don't save data to files (json and pl hashtables). Default is ".pp(\%do_save_to_file).".]\n"
	. "[--(no)save-to-db : save or don't save data to DB (json and pl hashtables). Default is ".pp(\%do_save_to_db).".]\n"
	. "\nExample use:\n\n   script/statistics-covid-fetch-data-and-store.pl --config-file config/config.json\n"
	. "\nProgram by Andreas Hadjiprocopis (andreashad2\@gmail.com / bliako\@cpan.org)\n"
}


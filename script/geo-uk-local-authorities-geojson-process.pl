#!/usr/bin/env perl

our $VERSION = '0.24';

use strict;
use warnings;

use Getopt::Long;
use Data::Dump qw/pp/;

use Statistics::Covid::Utils;

my $configfile = undef;
my $DEBUG = 0;

if( ! Getopt::Long::GetOptions(
	'config-file=s' => \$configfile,
	'debug=i' => \$DEBUG,
) ){ die usage() . "\n\nerror in command line."; }

die usage() . "\n\nA configuration file (--config-file) is required." unless defined $configfile;

my $ts = time;

my $confighash = Statistics::Covid::Utils::configfile2perl($configfile);
if( ! defined $confighash ){ print STDERR "$0 : call to ".'Statistics::Covid::Utils::configfile2perl'." has failed for file '$configfile'.\n"; exit(1) }

my $infile = File::Spec->catfile(
	$confighash->{'uk-local-authorities-geodata'}->{'datafiles-dir'},
	$confighash->{'uk-local-authorities-geodata'}->{'districts-geojson-file'}
);
if( ! -f $infile ){ print STDERR "$0 : error, input file '$infile' does not exist.\n"; exit(1) }

my $outfile = File::Spec->catfile(
	$confighash->{'uk-local-authorities-geodata'}->{'datafiles-dir'},
	$confighash->{'uk-local-authorities-geodata'}->{'districts-coordinates-json-file'}
);

open(FH, '>:encoding(UTF-8)', $outfile) or die "failed to open file '$outfile' for writing, $!";

my $pv = Statistics::Covid::Utils::configfile2perl($infile);
if( ! defined $pv ){ print STDERR "$0 : error, failed to read input file '$infile'.\n"; close(FH); unlink($outfile) }
my $w = $pv->{'features'};

my (%pvout, $prop);
for my $aw (@$w){
	$prop = $aw->{'properties'};
	$pvout{$prop->{'lad17cd'}} = {
		lad17cd => $prop->{'lad17cd'},
		lad17nm => $prop->{'lad17nm'},
		bng_e => $prop->{'bng_e'},
		bng_n => $prop->{'bng_n'},
		lat => $prop->{'lat'},
		long => $prop->{'long'},
	};
}
print FH Statistics::Covid::Utils::perl2json(\%pvout);
close(FH);

print "input: '$infile'.\n";
print "output: '$outfile'.\n";
print "$0: success, done in ".(time-$ts)." seconds.\n";

#### end

sub usage {
	return "Usage : $0 <options>\n"
	. " --config-file C : specify a configuration file which contains where to save files, where is the DB, what is its type (SQLite or MySQL), and DB connection options. The example configuration at 't/example-config.json' can be used as a quick start. Make a copy if that file and do not modify that file directly as tests may fail.\n"
	. "[--debug Level : specify a debug level, anything >0 is verbose.]\n"
	. "\nExample use:\n\n   script/statistics-covid-fetch-data-and-store.pl --config-file config/config.json\n"
	. "\nProgram by Andreas Hadjiprocopis (andreashad2\@gmail.com / bliako\@cpan.org)\n"
}


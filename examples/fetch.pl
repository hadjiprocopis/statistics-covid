#!/usr/bin/env perl

use strict;
use warnings;

use lib 'blib/lib';

use Statistics::Covid;

# create the main entry point to fetch and store data
my $cparams = {
	'config-file' => 'config/config.json',
	'providers' => ['World::JHU', 'UK::GOVUK'],
	# shall fetched data be saved to local file?
	'save-to-file' => {
		'World::JHU' => 1,
		'UK::GOVUK' => 1,
	},
	# shall fetched data be saved to our db?
	'save-to-db' => {
		'World::JHU' => 1,
		'UK::GOVUK' => 1,
	},
	'debug' => 1,
};

# create the main entry point.
# if database is not deployed it will be
# with all the necessary tables
my $covid = Statistics::Covid->new($cparams)
	or die pp($cparams)."\nStatistics::Covid->new() failed for the above parameters";

# fetch all the data available (posibly json), process it,
# create Datum objects, store it in DB and return an array 
# of the Datum objects just fetched  (and not what is already in DB).
my $newobjs = $covid->fetch_and_store();
die "fetch_and_store() has failed" unless defined $newobjs;

# count db rows
my $nrows = $covid->db_count_datums();
die "failed to get the row count of Datum records from the database" if $nrows==-1;

# count db rows for a specific provider
$nrows = $covid->db_count_datums({
	'conditions' => {
		'datasource' => 'World::JHU'
		# 'datasource' => {'like' => 'World::%'}
	}
});
die "failed to get the row count of Datum records from the database" if $nrows==-1;

print "row count for provider is $nrows\n";

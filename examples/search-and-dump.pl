#!/usr/bin/env perl

use strict;
use warnings;

use lib 'blib/lib';

use Data::Dump qw/pp/;
use Data::Roundtrip;

use Statistics::Covid;
use Statistics::Covid::Analysis::Model::Simple;
use Statistics::Covid::Analysis::Model;
use Statistics::Covid::Analysis::Plot::Simple;

my ($objs, $covid);

# create the main entry point to fetch and store data
my $cparams = {
	'config-file' => 'config/config.json',
	# no providers because we are only searching
	'debug' => 0,
};

# set verbosity to the 2 modules which do the plot/fit
# they are not OO
$Statistics::Covid::Analysis::Plot::Simple::DEBUG = 1;
$Statistics::Covid::Analysis::Model::Simple::DEBUG = 1;

# create the main entry point.
# if database is not deployed it will be
# with all the necessary tables
$covid = Statistics::Covid->new($cparams)
	or die pp($cparams)."\nStatistics::Covid->new() failed for the above parameters";

$objs = $covid->select_datums_from_db_time_ascending({
	'conditions' => {
	      # admin0=country-name, admin4=a neighbourhood
	      # also there is the 'datasource' (the provider of data, e.g. World::JHU)
	      # and type which is 'admin0' for country-totals, 'admin1' for state-totals
	      # for example UK has type='admin0' record (for the whole country)
	      # and type='amdin1' records for all local authorities
	      'admin0' => 'Madagascar',
	},
});
die "select_datums_from_db_time_ascending() has failed" unless defined $objs;

print "selected ".scalar(@$objs)." records from database matching these conditions ...\n";
my $jsonstring = Statistics::Covid::Utils::objects_to_JSON(
	$objs,
	{
		#'pretty' => 1,
		#'escape-unicode' => 0,
	}
);
die "call to Statistics::Covid::Utils::objects_to_JSON() has failed" unless defined $jsonstring;

die "failed to save JSON to 'data.json'" unless Data::Roundtrip::write_to_file('data.json', $jsonstring);

print @$objs." database records matching conditions have been dumped to 'data.json'.\n";

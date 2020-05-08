#!/usr/bin/env perl

use strict;
use warnings;

use lib 'blib/lib';

use Data::Dump qw/pp/;

use Statistics::Covid;

# create the main entry point to fetch and store data
my $cparams = {
	'config-file' => 'config/config.json',
	# no providers because we are only searching
	'debug' => 2,
};

# create the main entry point.
# if database is not deployed it will be
# with all the necessary tables
my $covid = Statistics::Covid->new($cparams)
	or die pp($cparams)."\nStatistics::Covid->new() failed for the above parameters";

my $objs = $covid->select_datums_from_db_time_ascending({
	'conditions' => [
	  '-and' => {
	      # admin0=country-name, admin4=a neighbourhood
	      # also there is the 'datasource' (the provider of data, e.g. World::JHU)
	      # and type which is 'admin0' for country-totals, 'admin1' for state-totals
	      # for example UK has type='admin0' record (for the whole country)
	      # and type='amdin1' records for all local authorities
	      'admin0' => 'Madagascar',
	      'confirmed' => [
		'-or' =>
		  {'>=' , '10'},
		  {'<=' , '5'},
	      ]
	     }# end 'confirmed'
	], # end conditions

	# max rows to get:
	'attributes' => {'rows' => 3}
});
die "select_datums_from_db_time_ascending() has failed" unless defined $objs;

for my $anobj (@$objs){
	print "matched datum object:\n".$anobj->toString()."\n";
	print "as a hash: ".pp($anobj->toHashtable())."\n";
}

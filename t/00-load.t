#!/usr/bin/env perl


###!perl -T
use 5.006;
use strict;
use warnings;
use Test::More;

use lib 'blib/lib';

our $VERSION = '0.25';

plan tests => 25;

BEGIN {
    use_ok( 'Statistics::Covid' ) || print "Bail out!\n";
    use_ok( 'Statistics::Covid::Utils' ) || print "Bail out!\n";
    use_ok( 'Statistics::Covid::DataProvider::Base' ) || print "Bail out!\n";
    use_ok( 'Statistics::Covid::DataProvider::UK::GOVUK' ) || print "Bail out!\n";
    use_ok( 'Statistics::Covid::DataProvider::UK::BBC' ) || print "Bail out!\n";
    use_ok( 'Statistics::Covid::DataProvider::World::JHU' ) || print "Bail out!\n";
    use_ok( 'Statistics::Covid::DataProvider::World::JHUgithub' ) || print "Bail out!\n";
    use_ok( 'Statistics::Covid::DataProvider::World::JHUlocaldir' ) || print "Bail out!\n";
    use_ok( 'Statistics::Covid::Schema' ) || print "Bail out!\n";
    use_ok( 'Statistics::Covid::Version::Table' ) || print "Bail out!\n";
    use_ok( 'Statistics::Covid::Version::IO' ) || print "Bail out!\n";
    use_ok( 'Statistics::Covid::WorldbankData::Table' ) || print "Bail out!\n";
    use_ok( 'Statistics::Covid::WorldbankData::IO' ) || print "Bail out!\n";
    use_ok( 'Statistics::Covid::Datum::Table' ) || print "Bail out!\n";
    use_ok( 'Statistics::Covid::Datum::IO' ) || print "Bail out!\n";
    use_ok( 'Statistics::Covid::Schema::Result::Datum' ) || print "Bail out!\n";
    use_ok( 'Statistics::Covid::Schema::Result::Version' ) || print "Bail out!\n";
    use_ok( 'Statistics::Covid::Schema::Result::WorldbankData' ) || print "Bail out!\n";
    use_ok( 'Statistics::Covid::Version' ) || print "Bail out!\n";
    use_ok( 'Statistics::Covid::WorldbankData' ) || print "Bail out!\n";
    use_ok( 'Statistics::Covid::Analysis::Model' ) || print "Bail out!\n";
    use_ok( 'Statistics::Covid::Analysis::Plot::Simple' ) || print "Bail out!\n";
    use_ok( 'Statistics::Covid::Analysis::Model::Simple' ) || print "Bail out!\n";
    use_ok( 'Statistics::Covid::IO::DualBase' ) || print "Bail out!\n";
    use_ok( 'Statistics::Covid::IO::Base' ) || print "Bail out!\n";
}

diag( "Testing Statistics::Covid $Statistics::Covid::VERSION, Perl $], $^X" );
diag( "Testing Statistics::Covid::Utils $Statistics::Covid::Utils::VERSION, Perl $], $^X" );
diag( "Testing Statistics::Covid::DataProvider::Base $Statistics::Covid::DataProvider::Base::VERSION, Perl $], $^X" );
diag( "Testing Statistics::Covid::DataProvider::UK::GOVUK $Statistics::Covid::DataProvider::UK::GOVUK::VERSION, Perl $], $^X" );
diag( "Testing Statistics::Covid::DataProvider::UK::BBC $Statistics::Covid::DataProvider::UK::BBC::VERSION, Perl $], $^X" );
diag( "Testing Statistics::Covid::DataProvider::World::JHU $Statistics::Covid::DataProvider::World::JHU::VERSION, Perl $], $^X" );
diag( "Testing Statistics::Covid::DataProvider::World::JHUlocaldir $Statistics::Covid::DataProvider::World::JHUlocaldir::VERSION, Perl $], $^X" );
diag( "Testing Statistics::Covid::DataProvider::World::JHUgithub $Statistics::Covid::DataProvider::World::JHUgithub::VERSION, Perl $], $^X" );
diag( "Testing Statistics::Covid::Schema $Statistics::Covid::Schema::VERSION, Perl $], $^X" );
diag( "Testing Statistics::Covid::Version::Table $Statistics::Covid::Version::Table::VERSION, Perl $], $^X" );
diag( "Testing Statistics::Covid::Version::IO $Statistics::Covid::Version::IO::VERSION, Perl $], $^X" );
diag( "Testing Statistics::Covid::WorldbankData::Table $Statistics::Covid::WorldbankData::Table::VERSION, Perl $], $^X" );
diag( "Testing Statistics::Covid::WorldbankData::IO $Statistics::Covid::WorldbankData::IO::VERSION, Perl $], $^X" );
diag( "Testing Statistics::Covid::Datum::Table $Statistics::Covid::Datum::Table::VERSION, Perl $], $^X" );
diag( "Testing Statistics::Covid::Datum::IO $Statistics::Covid::Datum::IO::VERSION, Perl $], $^X" );
diag( "Testing Statistics::Covid::Schema::Result::Datum $Statistics::Covid::Schema::Result::Datum::VERSION, Perl $], $^X" );
diag( "Testing Statistics::Covid::Schema::Result::Version $Statistics::Covid::Schema::Result::Version::VERSION, Perl $], $^X" );
diag( "Testing Statistics::Covid::Schema::Result::WorldbankData $Statistics::Covid::Schema::Result::WorldbankData::VERSION, Perl $], $^X" );
diag( "Testing Statistics::Covid::Version $Statistics::Covid::Version::VERSION, Perl $], $^X" );
diag( "Testing Statistics::Covid::Analysis::Model $Statistics::Covid::Analysis::Model::VERSION, Perl $], $^X" );
diag( "Testing Statistics::Covid::Analysis::Plot::Simple $Statistics::Covid::Analysis::Plot::Simple::VERSION, Perl $], $^X" );
diag( "Testing Statistics::Covid::Analysis::Model::Simple $Statistics::Covid::Analysis::Model::Simple::VERSION, Perl $], $^X" );
diag( "Testing Statistics::Covid::Version $Statistics::Covid::Version::VERSION, Perl $], $^X" );
diag( "Testing Statistics::Covid::WorldbankData $Statistics::Covid::WorldbankData::VERSION, Perl $], $^X" );
diag( "Testing Statistics::Covid::IO::DualBase $Statistics::Covid::IO::DualBase::VERSION, Perl $], $^X" );
diag( "Testing Statistics::Covid::IO::Base $Statistics::Covid::IO::Base::VERSION, Perl $], $^X" );


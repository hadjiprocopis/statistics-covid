package Statistics::Covid::Datum::Table;

use 5.10.0;
use strict;
use warnings;

our $VERSION = '0.24';

our $SCHEMA = {
  'tablename' => 'Datum',
  'column-names-for-primary-key' => [
   qw/
	id
	admin0 admin1 admin2 admin3
	datetimeUnixEpoch
	datasource
   /],
  'schema' => {
	# general info on what this 'schema' is
	# key is the internal name and also column name in DB
	# its value is understood by DBIx::Class and is a spec on how to create this table column

	# specific table column names description:
	# the id of the location, e.g. 123AXY or CHINA12 - this is not a primary key
	# for example USA has FIPS (06037) and UK has its own like W06000001 or E07000108
	'id' => {data_type => 'varchar', is_nullable=>0, size=>100, default_value=>''},
	# admin0, country name
	'admin0' => {data_type => 'varchar', is_nullable=>0, size=>60, default_value=>''},
	# admin1, province or state
	'admin1' => {data_type => 'varchar', is_nullable=>0, size=>60, default_value=>''},
	# admin2, an area in admin1
	'admin2' => {data_type => 'varchar', is_nullable=>0, size=>60, default_value=>''},
	# admin3, see https://gis.stackexchange.com/questions/103063/how-many-levels-for-administration-divide
	'admin3' => {data_type => 'varchar', is_nullable=>0, size=>60, default_value=>''},
	# admin4, see https://gis.stackexchange.com/questions/103063/how-many-levels-for-administration-divide
	'admin4' => {data_type => 'varchar', is_nullable=>0, size=>60, default_value=>''},

	# the type of the location e.g. local authority, some geographical location, city, province,
	# country, ship
	# it's just for information
	'type' => {data_type => 'varchar', is_nullable=>0, size=>60, default_value=>''},
	# the number of confirmed cases
	'confirmed' => {data_type => 'integer', is_nullable=>0, default_value=>-1},
	# the number of unconfirmed cases
	'unconfirmed' => {data_type => 'integer', is_nullable=>0, default_value=>-1},
	# the number of terminal cases (deaths)
	'terminal' => {data_type => 'integer', is_nullable=>0, default_value=>-1},
	# the number of those confirmed cases which later recovered
	'recovered' => {data_type => 'integer', is_nullable=>0, default_value=>-1},

	'incidentrate' => {data_type => 'real', is_nullable=>0, default_value=>-1},

	'peopletested' => {data_type => 'integer', is_nullable=>0, default_value=>-1},

	# where this data came from e.g. JHU (john hopkins university) or BBC or GOV.UK
	'datasource' => {data_type => 'varchar', is_nullable=>0, size=>100, default_value=>'<NA>'},
	# datetime both as an ISO string (datetime) or unix epoch seconds
	# a 2020-03-20T12:23:35 assuming UTC tz if not tz specified
	'datetimeISO8601' => {data_type => 'varchar', is_nullable=>0, size=>21, default_value=>'<NA>'},
	'datetimeUnixEpoch' => {data_type => 'integer', is_nullable=>0, default_value=>0},
	# we also have area and population just in case this area is non-standard
	# i.e. it is not a province but say it is a school
	'area' => {data_type => 'real', is_nullable=>0, default_value=>-1},
	'population' => {data_type => 'real', is_nullable=>0, default_value=>-1},

	# indicator slots for future use
	'i1' => {data_type => 'real', is_nullable=>0, default_value=>-1},
	'i2' => {data_type => 'real', is_nullable=>0, default_value=>-1},
	'i3' => {data_type => 'real', is_nullable=>0, default_value=>-1},
	'i4' => {data_type => 'real', is_nullable=>0, default_value=>-1},
	'i5' => {data_type => 'real', is_nullable=>0, default_value=>-1},
	# lat/long, default is this which is existent off the coast of ghana
	'lat' => {data_type => 'real', is_nullable=>0, default_value=>-1},
	'long' => {data_type => 'real', is_nullable=>0, default_value=>-1},
  }, # end schema
};
$SCHEMA->{'column-names'} = [ sort {$a cmp $b } keys %{$SCHEMA->{'schema'}} ];
$SCHEMA->{'num-columns'} = scalar @{$SCHEMA->{'column-names'}};
1;
__END__
# end program, below is the POD

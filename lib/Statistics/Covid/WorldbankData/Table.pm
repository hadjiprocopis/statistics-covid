package Statistics::Covid::WorldbankData::Table;

use 5.10.0;
use strict;
use warnings;

our $VERSION = '0.24';

use Data::Dump qw/pp/;

our $SCHEMA = {
  # specify your table and schema
  'tablename' => 'WorldbankData',
  'column-names-for-primary-key' => [qw/countrycode year source/],
  'schema' => {
	# key is the internal name and also name in DB
	# then 'sql' is the sql spec for creating this DB column (SQLite and MySQL)
	# 'default-value' is the default value
	# the id of the location, e.g. 123AXY or CHINA12 - this is not a primary key (pk is formed as a combination see above)
	'countryname' => {data_type => 'varchar', is_nullable=>0, size=>50, default_value=>'<NA>'}, # uk is the longest with 48!
	'countrycode' => {data_type => 'varchar', is_nullable=>0, size=>10, default_value=>'<NA>'},
	'source' => {data_type => 'varchar', is_nullable=>0, size=>20, default_value=>'<NA>'},
	'year' => {data_type => 'integer', is_nullable=>0, default_value=>0},
	# this is the actual data, make sure you fill in the array of c2f below
	###################
	# IMPORTANT:
	#  don't add indicators here, add them below in 'c2f'
	###################
  }, # end schema
};
### this is a bit of a bad thing
# a hashref to hold the indicators we will add to our table (and also fetch from Worldbank's servers)
# Worldbank's indicators are separated by dots (.) but table column names can not contain dots
# SO: specify column names with a dot replaced with an underscore
# for example column name is 'SP_POP_TOTL' and indicator is 'SP.POP.TOTL'
# files can be downloaded from http://api.worldbank.org/v2/en/indicator/SP.DYN.LE00.IN?downloadformat=csv
# this data perhaps does not belong here but as it needs the column-names of the schema above
# and must be updated whenever the schema changes, i think is OK
$SCHEMA->{'c2f'} = {
	################
	# IMPORTANT:
	#   ADD indicators HERE:
	################
	# this SP.POP.TOTL represents population
	# and must be present ALWAYS because
	# Statistics::Covid::Schema::Result::WorldbankData::newer_than()
	# depends on it
	'SP.POP.TOTL' => { # <<<< this is the column name in the table (must not contain dots, must correspond to Worldbank existing indicator (with dots))
		# FILL THESE:
		'description'=>'Population, total',
		'sql' => {data_type => 'integer', is_nullable=>0, default_value=>-1},

		# ignore these, they will be filled automatically in section below:
		'indicator' => undef, # the indicator will be created from keyname=column name in table
		'url'=>undef, # the url is created below from the filename and the base url

	},
	'NY.GDP.MKTP.CD' => {
		'description'=>'GDP (current US$)',
		'sql' => {data_type => 'real', is_nullable=>0, default_value=>-1},
		'indicator' => undef,
		'url'=>undef,
	},
	'SH.XPD.CHEX.GD.ZS' => {
		'description'=>'Current health expenditure (% of GDP)',
		'sql' => {data_type => 'real', is_nullable=>0, default_value=>-1},
		'indicator' => undef,
		'url'=>undef,
	},
	'SE.XPD.TOTL.GD.ZS' => {
		'description'=>'Government expenditure on education, total (% of GDP)',
		'sql' => {data_type => 'real', is_nullable=>0, default_value=>-1},
		'indicator' => undef,
		'url'=>undef,
	},
	'SH.MED.BEDS.ZS' => {
		'description'=>'Hospital beds (per 1,000 people)',
		'sql' => {data_type => 'real', is_nullable=>0, default_value=>-1},
		'indicator' => undef,
		'url'=>undef,
	},
	'SP.DYN.IMRT.IN' => {
		'description'=>'Mortality rate, infant (per 1,000 live births)',
		'sql' => {data_type => 'real', is_nullable=>0, default_value=>-1},
		'indicator' => undef,
		'url'=>undef,
	},
	'SP.DYN.LE00.IN' => {
		'description'=>'Life expectancy at birth, total (years)',
		'sql' => {data_type => 'real', is_nullable=>0, default_value=>-1},
		'indicator' => undef,
		'url'=>undef,
	},
	'SP.DYN.CDRT.IN' => {
		'description'=>'Death rate, crude (per 1,000 people)',
		'sql' => {data_type => 'real', is_nullable=>0, default_value=>-1},
		'indicator' => undef,
		'url'=>undef,
	},
	'SP.ADO.TFRT' => {
		'description'=>'Adolescent fertility rate (births per 1,000 women ages 15-19)',
		'sql' => {data_type => 'real', is_nullable=>0, default_value=>-1},
		'indicator' => undef,
		'url'=>undef,
	},
};

### nothing to change below:
# to some additions to the c2f which can be automated so user does not have to deal with these
for my $k ((keys %{$SCHEMA->{'c2f'}})){
	# e.g. http://api.worldbank_org/v2/country/ind/indicator/AG.AGR.TRAC.NO?source=2&downloadformat=csv
	# the above is for india '/ind/', use '/all/' for all countries
	# WARNING: downloads a ZIP file
	if( $k !~ /^([A-Z]+[0-9]*)\.([A-Z]+[0-9]*\.?)+/ ){ die "ooppps, column name '$k' does not look like a World Bank indicator, see ".'https://data.worldbank.org/indicator' }
	my $v = $SCHEMA->{'c2f'}->{$k};
	$v->{'indicator'} = $k; # indicators contain dots
	# column names are the same as indicators but dots replaced for '_'
	my $kk = $k; $kk =~ s/\./_/g;
	$v->{'filename'} = $v->{'indicator'}.'.csv';
	$v->{'url'} = 'http://api.worldbank.org/v2/country/all/indicator/'.$v->{'indicator'}.'?source=2&downloadformat=csv';
	# this adds it to the schema
	if( exists $SCHEMA->{'schema'}->{$kk} ){ die "ooppps, column name '$kk' has already been added to this schema" }
	$SCHEMA->{'schema'}->{$kk} = $v->{'sql'};
	# and this deletes the old key and copies to new with underscore
	$SCHEMA->{'c2f'}->{$kk} = $SCHEMA->{'c2f'}->{$k};
	delete $SCHEMA->{'c2f'}->{$k};
}
# make a sanity check that column names are the same in c2f and schema
exists $SCHEMA->{'schema'}->{$_}
     or die "SCHEMA->{'c2f'} is:\n".pp($SCHEMA->{'c2f'})."SCHEMA->{'schema'} is:\n".pp($SCHEMA->{'schema'})."\ncolumn $_ exists in ".'Statistics::Covid::WorldbankData::Table:::SCHEMA{c2f}'." but not in its 'schema'"
   for keys %{$SCHEMA->{'c2f'}}
;
$SCHEMA->{'column-names'} = [ sort {$a cmp $b } keys %{$SCHEMA->{'schema'}} ];
$SCHEMA->{'num-columns'} = scalar @{$SCHEMA->{'column-names'}};
1;
__END__
# end program, below is the POD
http://api.worldbank.org/v2/country/ind/indicator/AG.AGR.TRAC.NO?source=2&downloadformat=csv

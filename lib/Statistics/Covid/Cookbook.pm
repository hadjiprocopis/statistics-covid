spackage Statistics::Covid::Cookbook;

use 5.10.0;
use strict;
use warnings;

our $VERSION = '0.24';

use Statistics::Covid;
use Statistics::Covid::Datum;
use Statistics::Covid::Utils;

1;
__END__
# end program, below is the POD
=pod

=encoding UTF-8

=head1 NAME

Statistics::Covid - Cookbook

=head1 VERSION

Version 0.24

=head1 DESCRIPTION

This module fetches, stores in a database, retrieves from a database and analyses
Covid-19 statistics from online or offline data providers.

This document puts together a few examples demonstrating its
functionality.

The module uses three database tables at the moment:
L<Statistics::Covid::Datum>,
L<Statistics::Covid::Version> and  L<Statistics::Covid::WorldbankData>.
Consult L<Statistics::Covid::Schema::Result::Datum> on how to do
create your own tables. For example for storing plots or fitted models.

In order to assist analysis and in particular in correlating the epidemic's statistics
with socio-economical data a sub-package
(L<Statistics::Covid::WorldbankData>)
has been created which
downloads such data provided by L<https://www.worldbank.org/ | the World Bank>
and stores it in the database, in a table on its own.

=head1 CONFIGURATION FILE

Below is an example configuration file which is essentially JSON with comments.
It can be found in C<t/config-for-t.json> relative to the root directory
of this distribution.

	# comments are allowed, otherwise it is json
	# this file does not get eval'ed, it is parsed
	# only double quotes! and no excess commas
	{
		# fileparams options
		"fileparams" : {
			# dir to store datafiles, each DataProvider class
			# then has its own path to append
			"datafiles-dir" : "datazz/files"
		},
		# database IO options
		"dbparams" : {
			# which DB to use: SQLite, MySQL (case sensitive)
			"dbtype" : "SQLite",
			# the name of DB
			# in the case of SQLite, this is a filepath
			# all non-existing dirs will be created (by module, not by DBI)
			"dbdir" : "datazz/db",
			"dbname" : "covid19.sqlite",
			# how to handle duplicates in DB? (duplicate=have same PrimaryKey)
			# only-better : replace records in DB if outdated (meaning number of markers is less, e.g. terminal or confirmed)
			# replace     : force replace irrespective of markers
			# ignore      : if there is a duplicate in DB DONT REPLACE/DONT INSERT
			# (see also Statistics::Covid::Datum for up-to-date info)
			"replace-existing-db-record" : "only-better",
			# username and password if needed
			# unfortunately this is in plain text
			# BE WARNED: do not store your main DB password here!!!!
			# perhaps create a new user or use SQLite
			# there is no need for these when using SQLite
			"hostname" : "", # must be a string (MySQL-related)
			"port"     : "", # must be a string (MySQL-related)
			"username" : "", # must be a string
			"password" : "", # must be a string
			# options to pass to DBI::connect
			# see https://metacpan.org/pod/DBI for all options
			"dbi-connect-params" : {
				"RaiseError" : 1, # die on error
				"PrintError" : 0  # do not print errors or warnings
			}
		}
	}

A configuration file can be read into a configuration hashtable. And either form of configuration
is accepted by all high-level functions in this package. For example,

  use Statistics::Covid::Utils;
  my $confighash = Statistics::Covid::Utils::configfile2perl('config/config.json')
    or die "failed to read config file";

A confighash can be adjusted to particular temporary
needs by modifying certain values
these adjustments are not saved back to file (!)

  $confighash->{'dbparams'}->{'hostname'} = ...;

The API for high-level subs or class constructors, provided by this package,
reserves a key in the input parameters hash for 'config-hash' or 'config-file'
to specify the configuration either as a file or as a previously read config hashtable.

=head1 FETCH DATA

Fetching data entails sucking it from the data providers' sites
using provided APIs or, in the worst case,
scraping it, even from HTML. Thankfully,
all the providers so far provide JSON or CSV files.

=head2 Known data providers

=over 4

=item * C<World::JHU> points to
L<Johns Hopkins University site|https://www.arcgis.com/apps/opsdashboard/index.html#/bda7594740fd40299423467b48e9ecf6>
and contains real-time world data. China, United States, Canada and some other
countries have data for states or provinces too. E.g. Colorado or Xiandong.

=item * C<World::JHUgithub> points to Johns Hopkins University github
repository L<https://github.com/CSSEGISandData/COVID-19> which contains
CSV files for each day since the beginning.
Their last CSV will more or less contain the data currently at
C<World::JHU>. Github being what it is restricts access to this
site and downloads of several files will be restricted.
In this case it is preferable to clone the repository into
a local directory and use C<World::JHUlocaldir> option, below.

=item * C<World::JHUlocaldir> is a local clone (git clone) of the above
git repository. For example:

  mkdir JHU-COVID-19-github
  cd JHU-COVID-19-github
  git clone 'https://github.com/CSSEGISandData/COVID-19.git'

Then everytime you want to fetch fresh data, do:

  cd JHU-COVID-19-github
  git pull

This will fetch CSV data locally. And see later on how to parse and insert it to the
local database.

=back

=head2 Prepare a Covid object

  use Statistics::Covid;
  $covid = Statistics::Covid->new({
    # configuration file (or hash)
    'config-file' => 't/config-for-t.json',
    #'config-hash' => {...}.,

    'providers' => [
    	#'UK::BBC',
    	'UK::GOVUK2',
    	'World::JHUlocaldir',
    	'World::JHUgithub',
    	'World::JHU'
    ],
    'provider-extra-params' => {
    	'World::JHUlocaldir' => {
    		'paths' => ['JHU-COVID-19'],
    	},
    	# 'World::JHUgithub' => defaults are enough but see L<Statistics::Covid::DataProvider::World::JHUgithub>
    },
    # save fetched data locally in its original format (json or csv)
    # and also as a perl var
    'save-to-file' => {
    	'UK::BBC' => 1,
    	'UK::GOVUK2' => 1,
    	'World::JHUlocaldir' => 0,
    	'World::JHUgithub' => 1,
    	'World::JHU' => 1,
    },
    # save fetched data into the database in table Datum
    'save-to-db' => {
    	'UK::BBC' => 1,
    	'UK::GOVUK2' => 1,
    	'World::JHUlocaldir' => 1,
    	'World::JHUgithub' => 1,
    	'World::JHU' => 1,
    },
    # debug level affects verbosity
    'debug' => 2, # 0, 1, ...
  }) or die "Statistics::Covid->new() failed";

The above will set up an object which can be used
for downloading the data and inserting it into the database
and/or selecting data from the database.

When instantiated, the object will check for the existence
of the database (as specified in the configuration file).
If the database does not exist, it will be deployed and
tables created, all ready for inserting data.
At this point, please be reminded that all functionality
has been tested with C<SQLite3>. However, because internally
L<DBIx::Class> is used, one would guess that it's fairly simple
to use other database vendors. The configuration file
is where the database vendor and parameters passed to the database
connector are set. Theoretically, changing a database vendor
is as easy as adjusting the configuration
file in one or two places.

So, after successful instantiation, a database and all required
tables are guaranteed to exist.

=head2 Datum

The main data item to be inserted into the database is the L<Statistics::Covid::Datum>.
It represents a set of quantities (something like C<confirmed> and C<unconfirmed> cases,
C<peopletested>, C<recovered> and C<terminal>) for a specific location and time point.
Which can be C<Italy, Tue 21 Apr 21:54:48 UTC 2020>. This will count all total
quantities over space and time. So, C<confirmed> cases will be the total
confirmed cases all over Italy and since the beginning of records.
C<Italy> in this package is what we call an C<admin0> location.
And so is the UK. For the UK, there is data for each "country"
which will be C<admin1> (e.g. Scotland). And also data for each
region C<admin2> (e.g. South-East). And also data for each
local authority C<admin3> (e.g. Hackney).

The Datum table can take up to 4 levels of location administrative
levels C<admin0 ... admin4>. It also can store C<lat> and C<long>
of locations in case they are not standard, e.g. cruise ships.

As far as markers are concerned, in addition to those mentioned above,
there are 5 user-specified indicators C<i1, i2, i3, i4, i5> (each storing a
real). Depending on the C<datasource> provider, these user-specified
markers can have different meanings.

The Datum table schema is specified in L<Statistics::Covid::Datum::Table>
as a hashtable (C<SCHEMA>). The column specification follows C<DBIx::Class>
convention, for example:

  'admin0' => {data_type => 'varchar', is_nullable=>0, size=>60, default_value=>''},
  'recovered' => {data_type => 'integer', is_nullable=>0, default_value=>1},
  'i1' => {data_type => 'real', is_nullable=>0, default_value=>-1},

Datum, in addition to being a database table, it is also a Class whose
objects store exact same data in memory. Its constructor accepts the above data
in a hashtable form. It does not deal with the particular data formats
specific data providers provide. It needs a hashtable of key/value
pairs of data (e.g. C<admin0>, C<confirmed>, etc.).

=head2 Data Provider Classes

The logic for converting fetched data from a specified provider to Datum objects
is done inside each C<DataProvider> class. There must exist one for each
data provider all inheriting from L<Statistics::Covid::DataProvider::Base> which
offers basic functionality.

For example, see L<Statistics::Covid::DataProvider::World::JHU>. Its constructor
specifies a set of URLs, headers, post-data (if any). The main
functionality is provided by L<Statistics::Covid::DataProvider::World::JHU/create_Datums_from_fetched_data>
which gets the fetched data and converts it to L<Statistics::Covid::Datum> objects.

More data provider classes can be created by following
L<Statistics::Covid::DataProvider::World::JHU>.

=head2 Fetch data and store

Data will be fetched from specified providers, either local or
remote using the following:

  # $covid has already been created using Statistics::Covid->new(...)
  $newObjs = $covid->fetch_and_store() or die "fetch failed";

  print $_->toString() for (@$newObjs);
  # or get the complete hash of params
  print pp($_->toHashtable()) for (@$newObjs);

Fetched data will optionally be saved to local files in the exact same
format as it was downloaded (so that they can be read again in the case
database needs to be rebuilt) and/or optionally be saved to the database
as the current table schema dictates.

=head2 Query the database

  $someObjs = $covid->select_datums_from_db({
    'conditions' => {
       admin0=>'United Kingdom of Great Britain and Northern Ireland',
       'datasource' => 'UK::GOVUK2',
       admin3=>'Hackney'
    },
    'attributes' => {
       rows => 10,
    }
  });

The query functions provided are just high-level C<DBIx::Class> searches
following the conventions of L<DBIx::Class::ResultSet/search>. C<conditions>
is the equivalent of the C<WHERE> clauses. In C<attributes> one can
specify maximum number of rows, C<ORDER BY> clauses, etc.

The following queries and sorts the results in time-ascending order,

  my $timelineObjs =
    $covid->select_datums_from_db_time_ascending({
      'conditions' => {
          'datasource' => 'UK::GOVUK2',
          admin0=>'United Kingdom of Great Britain and Northern Ireland',
          admin3=>'Hackney'
      }
    });

Count the number of rows matching certain conditions with,

  print "rows matched: ".db_count_datums({
    $covid->select_datums_from_db_time_ascending({
      'conditions' => {
          'datasource' => 'UK::GOVUK2',
          admin0=>'United Kingdom of Great Britain and Northern Ireland',
          admin3=>'Hackney'
      }
    });

If for some reason it is needed to insert an array of Datum objects
into the database, this will do it:

  $covid->db_datums_insert_bulk($arrayOfDatumObjs) or die "failed to insert"

At this point we should mention that the insertion of in-memory
objects in the database if identical-in-primary-key objects already exist
is done in accordance to the replacement policy specified in the configuation
file under the key C<replace-existing-db-record> which can take
the following values:

=over 4

=item * C<only-better> inserts the in-memory object, replacing the one existing in the database
only if L<Statistics::Covid::Datum/newer_than> returns true. That first compares
the data with respect to time and then if C<terminal> / C<confirmed>
/ C<recovered>, and finally, C<unconfirmed> cases have increased, in this order.

=item * C<ignore>, do not do an insert at all, no questions asked.

=item * C<replace>, do an insert, no questions asked.

=back

=head1 DATA ANALYSIS

=head2 Additional socio-economical data: World Bank Indicators

In order to assist analysis and in particular in correlating the epidemic's statistics
with socio-economical data a sub-package
(L<Statistics::Covid::WorldbankData>) 
has been created which
downloads such data provided by L<https://www.worldbank.org/ | the World Bank>
and stores it in the database, in a table on its own.

Like Datum, the L<Statistics::Covid::WorldbankData> class is dual, representing
an object in memory and a row in the corresponding table in the database.
The schema for this table is in L<Statistics::Covid::WorldbankData::Table>.
The entry C<< $SCHEMA->{'c2f'} >> specifies which descriptors to download
and create columns in the database table C<WorldbankData>. At the moment
adding another descriptor, in addition to the 9 already existing is not
difficult. It just means that the database table must be altered which is
not as easy for all database vendors. So, it is preferable to
re-create the table. Saving re-downloading data is desirable but that
means to store them locally. The consiensous user will find a modus-vivendi.

  builder = Statistics::Covid::WorldbankData::Builder->new({
        'config-file' => 'config/config.json',
        'debug' => 1,
  }) or die "failed to construct";

  $ret = $builder->update({
        # optional parameters to be passed to LWP::UserAgent
        # sane defaults already do exist
        'ua-params' => {
                'agent' => 'ABC XYZ'
        },
        # optionally specify whether to re-download data files (no!)
        'overwrite-local-files' => 0,
	# the replace-strategy for existing db rows is
        # in the config file under dbparams
	# this will clear ALL rows in THIS TABLE (only)
	'clear-db-first' => 0,
  }) or die "failed to update";

  print "Success fetching and inserting, this is some info:\n".pp($ret);

This is yearly data, so re-downloading data
must be done once a year, when data is updated at the source.

Using the data is as easy because the L<Statistics::Covid::WorldbankData> class
is similar in functionality to the L<Statistics::Covid::Datum> class, both
inheriting from the same parent class (L<Statistics::Covid::IO::DualBase>).

The main point to remember is that each L<Statistics::Covid::WorldbankData>
object is one datum in space (countries) and time (years) containing all
the indicators specified at the table creation time, like above. Getting
a column / field / attribute out of such an object is via C<get_column()>.

Unfortunately L<Statistics::Covid::WorldbankData> objects are not yet
integrated to the L<Statistics::Covid> class and so they have a somewhat
lower interface (which is identical to L<Statistics::Covid::Datum>'s, just that
the latter has also a higher interface). Anyway, the API is quite high-level
as it is,

  $io = Statistics::Covid::Version::IO->new({
      # the params, the relevant section is
      # under key 'worldbankdata'
      'config-hash' => $confighash,
      'debug' => 1,
  }) or die "failed to construct";

  $io->db_connect() or die "failed to connect to db";

  my $objs = $io->db_select({
      'conditions' => {
         #'countryname' => 'Italy',
         'countrycode' => ['it', 'gr', 'de'],
         'year' => { '>=' => 1990, '<=' => 2010 }
       }
  });

  print "Population of ".$_->get_column('countryname')." was "
        .$_->get_column('SP_POP_TOTL')
        ." in ".$_->get_column('year')
        ."\n"
    for @$objs;
  $io->db_disconnect();

Or get the latest data for each of these countries
using this special select,
see L<DBIx::Class::ResultSet#+select>,

  my $WBio = Statistics::Covid::WorldbankData::IO->new({
      # the params, the relevant section is
      # under key 'Worldbankdata'
      'config-hash' => $confighash,
      'debug' => 1,
  }) or die "failed to construct";
  $WBio->db_connect() or die "failed to connect to db (while on world bank)";
  my $WBobjs = $WBio->db_select({
	'conditions' => {
		countryname=>['Angola', 'Afghanistan'],
	},
	# see L<DBIx::Class::ResultSet#+select>
	'attributes' => {
		'group_by' => ['countrycode'],
		'+select' => {'max' => 'year'},
	},
  });
  print pp($_->toHashtable()) for @$WBobjs;

See L<Statistics::Covid::WorldbankData::Builder> and
L<Statistics::Covid::IO::Base> for more information.

=head2 Plotting data

A simple, if not naive plotting functionality exists in-built.
In the back of the author's mind there was the requirement
to have on the save graph
multiple plots, possibly over time, with the same vertical
and horizontal axes.

The first part is to select data from the database. Then
the selected array of L<Statistics::Covid::Datum> objects
(remember that each holds data for a single point in space and time)
is converted to a data-frame which is a convenient way to
have the data to be tabulated, e.g. the number of confirmed
cases for Spain in one single array. And the corresponding
time points in another single array. In this case, C<admin0>
is the C<groupby> column name (attribute, field, etc.).
The data-frame will contain one key/value pair for
each distinct item in the C<admin0> group. In our example,
just "Spain". But since data for other countries is
more detailed, we will use
C<< ['admin0','admin1', 'admin2', 'admin3', 'admin4'] >>
as the C<groupby> column names.

    use Statistics::Covid;
    use Statistics::Covid::Datum;
    use Statistics::Covid::Utils;
    use Statistics::Covid::Analysis::Plot::Simple;

    my $covid = Statistics::Covid->new({
       # no need to specify providers etc., that's only for fetching
       'config-file' => 't/config-for-t.json',
       'debug' => 2,
    }) or die "Statistics::Covid->new() failed";

    my $timelineObjs =
       $covid->select_datums_from_db_time_ascending({
           'conditions' => {
                'datasource' => 'UK::GOVUK2',
		'admin3' => 'Hackney',
		'admin0' => 'United Kingdom of Great Britain and Northern Ireland',
	}
    });

    # create a dataframe
    my $df = Statistics::Covid::Utils::datums2dataframe({
      'datum-objs' => $timelineObjs,
      # each unique geo-location will be a single group
      'groupby' => ['admin0','admin1', 'admin2', 'admin3', 'admin4'],
      # with these data in each group as an array keyed on group name
      'content' => ['confirmed', 'terminal', 'datetimeUnixEpoch'],
    }) or die;

    # plot 'confirmed' vs 'time'
    $ret = Statistics::Covid::Analysis::Plot::Simple::plot({
        # the dataframe we just created
	'dataframe' => $df,

	# saves the plot image to this file:
	'outfile' => 'confirmed-over-time.png',

	# plot this column against X
	# (which is not present and default is
	# time : 'datetimeUnixEpoch'
	'Y' => 'confirmed',
	# this is the default if no 'X'
        # in Statistics::Covid::Analysis::Plot::Simple
        # the format is '%d/%m(%Hhr)' (see Chart::Clicker)
	'X' => 'datetimeUnixEpoch', # secs since THE epoch
    });

=head2 Fitting data into a model

The selected data can be fitted into a user-specified model.
A model is just a mathematical equation which we think
the particular data generating procedure follows.
The procedure in this case is the
natural phenomenon of a virus spreading among a population.
Often an exponential model is used, and for good reason.

Such a model is C<< y = c1 * c2 ^ x >>. Where C<c1> and C<c2> are
coefficients which we need to find from the data at hand.
C<x> is the independent variable, which is time in our case in
some reasonable time unit, say hours or 12-hour spans.
C<y> is the dependent variable, for example the number of confirmed cases.
It depends on time (C<x>) and the
coefficients. With this equation, for a given time we can predict
the number of cases provided that the coefficients are accurate
and of course the data model, the exponential equation in our case,
is not too simplistic. Finding accurate and correct coefficients
requires a lot of data points and depends on the number of
coefficients.

Other models are the polynomials, C<< y = c0 + c1*x + c2*x^2 + ... >>

L<Algorithm::CurveFit> is used to find the coefficients for B<any>
user-specified equation provided there is sufficient data to do so.

User-specified equations can be written using the notation
as described in L<Math::Symbolic::Operator>, L<Math::Symbolic>,
L<Math::Symbolic::Parser>.
Usually C<*> denotes multiplication and C<^> raising to a power,
C<x> must be used for the independent variable and names valid
as Perl variables are valid for coefficient names.

A higher-order polynomial will fit the data better but will take some
time. Using an exponential and a polynomial model of degree 4 is probably
a sane choice. The polynomial can be used to fit the data from the beginning
to the end, where it forms a plateau. The exponential can fit the data
at the first stages.

Why do we need to fit the data to an analytical model? Because
if the fit is accurate, we can express all that data we fitted with a
handful of parameters. It is a kind of data compression. Once we
have good fit, we can compare the various data, how the virus
spread in different countries. We can do some clustering to
tell us if there are groups of countries with similar patterns.
We can correlate with some of World Bank's socio-economic
indicators and check the hypothesis that the demolition
of Public Health Systems or the decrease in Public spending
caused a lot of panic and instigated the foreseeable
economic meltdown.

Again, we will query the database and create a dataframe.
But we will "normalise" the dataframe so that time
is in hours since the first incident, instead of seconds
since the Unix Epoch which is a huge number which blinds
the curve fitting algorithm (and the matrix multiplications).

    use Statistics::Covid;
    use Statistics::Covid::Datum;
    use Statistics::Covid::Utils;
    use Statistics::Covid::Analysis::Plot::Simple;

    my $covid = Statistics::Covid->new({
       # no need to specify providers etc., that's only for fetching
       'config-file' => 't/config-for-t.json',
       'debug' => 2,
    }) or die "Statistics::Covid->new() failed";

    my $timelineObjs =
       $covid->select_datums_from_db_time_ascending({
           'conditions' => {
                'datasource' => 'UK::GOVUK2',
		'admin3' => 'Hackney',
		'admin0' => 'United Kingdom of Great Britain and Northern Ireland',
	}
    });

    # create a dataframe
    my $df = Statistics::Covid::Utils::datums2dataframe({
      'datum-objs' => $timelineObjs,
      # each unique geo-location will be a single group
      'groupby' => ['admin0','admin1, 'admin2', 'admin3', 'admin4'],
      # with these data in each group as an array keyed on group name
      'content' => ['confirmed', 'terminal', 'datetimeUnixEpoch'],
    }) or die;

    #print "Before:\n".pp($df);
    # discretise time-axis and insert to a new key in the dataframe
    for(sort keys %$df){
        my @copy = @{$df->{$_}->{'datetimeUnixEpoch'}->{'data'}};
	Statistics::Covid::Utils::discretise_increasing_sequence_of_seconds(
		\@copy, # << in-place modification
		3600, # unit in seconds: 3600 seconds -> 1 hour discrete steps
		0 # optional offset, (the 0 hour above)
	);
        # new key:
        $df->{$_}->{'datetimeHoursSinceOldest'} = {'data' => \@copy};
    }
    #print "After:\n".pp($df);

    # fit to a polynomial of degree 3 (max power of x is 3)
    $ret = Statistics::Covid::Analysis::Model::Simple::fit({
	'dataframe' => $df,
	'X' => 'datetimeHoursSinceOldest', # our X is this field from the dataframe
	'Y' => 'confirmed', # our Y is this field
	# initial values guess (here ONLY for some coefficients)
	'initial-guess' => {'c1'=>1, 'c2'=>1},
	'polynomial-fit' => 3, # max power of x is 3
	'fit-params' => {
		'maximum_iterations' => 100000
	}
    });

    # fit to an ad-hoc formula in 'x' - it is meaningless
    # (see L<Math::Symbolic::Operator> for supported operators)
    $ret = Statistics::Covid::Analysis::Model::Simple::fit({
	'dataframe' => $df,
	'X' => 'datetimeHoursSinceOldest', # our X is this field from the dataframe
	'Y' => 'confirmed', # our Y is this field
	# initial values guess (here ONLY for some coefficients)
	'initial-guess' => {'c1'=>1, 'c2'=>1},
	'formula' => 'c1*sin(x) + c2*cos(x)',
	'fit-params' => {
		'maximum_iterations' => 100000
	}
    });

    # do an exponential fit
    $ret = Statistics::Covid::Analysis::Model::Simple::fit({
	'dataframe' => $df,
	'X' => 'datetimeHoursSinceOldest', # our X is this field from the dataframe
	'Y' => 'confirmed', # our Y is this field
	'initial-guess' => {'c1'=>1, 'c2'=>1}, # initial values guess
	'exponential-fit' => 1,
	'fit-params' => {
		'maximum_iterations' => 100000
	}
    });
    print "Here are models, one for each group:\n".pp($ret);

    # evaluate the model at every time point
    # we have a model for each group of data (remember groupby)
    # e.g. for Spain
    my $aY = 'confirmed'; # this is what we fitted against, our Y
    for $k (keys %$ret){
        # k is like 'Spain'
        $model = $ret->{$k};
        my @outv;
        $actualdata = $df->{$k}->{$aY}->{'data'};
        $timepoints = $df->{$k}->{'datetimeHoursSinceOldest'}->{'data'};
        $N = scalar @$timepoints;
        for($i=0;$i<$N;$i++){
           $t = $timepoints->[$i];
           $actualv = $actualdata->[$i];
           $v = $model->evaluate($t); # << evaluates the equation at $t
           push @outv, $v;
        }
        $df->{$k}->{$aY}->{'fitted-exponential'} = \@outv;
    }

    # plot 'confirmed' vs 'time' AND the fitted data without
    # further complications, the plotted looks for 'fitted-*'
    # entries in the dataframe
    $ret = Statistics::Covid::Analysis::Plot::Simple::plot({
	'dataframe' => $df,
	'outfile' => 'confirmed-over-time.png',
	'Y' => 'confirmed',
	'X' => 'datetimeUnixEpoch', # secs since THE epoch
    });

Here we will do as above but normalise the confirmed cases to the
population size (at the C<admin0> level, e.g. country).

    use Statistics::Covid;
    use Statistics::Covid::Datum;
    use Statistics::Covid::Utils;
    use Statistics::Covid::Analysis::Plot::Simple;
    use Statistics::Covid::WorldbankData::IO;
    use Statistics::Covid::WorldbankData;

    my $covid = Statistics::Covid->new({
       # no need to specify providers etc., that's only for fetching
       'config-file' => 't/config-for-t.json',
       'debug' => 2,
    }) or die "Statistics::Covid->new() failed";

    my $timelineObjs =
       $covid->select_datums_from_db_time_ascending({
           'conditions' => {
		'admin0' => ['Spain', 'Italy', 'Belgium'],
	}
    });

    # create a dataframe
    my $df = Statistics::Covid::Utils::datums2dataframe({
      'datum-objs' => $timelineObjs,
      # each unique geo-location will be a single group
      'groupby' => ['admin0'],
      # with these data in each group as an array keyed on group name
      'content' => ['confirmed', 'recovered', 'terminal', 'datetimeUnixEpoch'],
    }) or die;

    # discretise time-axis and insert to a new key in the dataframe
    for(sort keys %$df){
        my @copy = @{$df->{$_}->{'datetimeUnixEpoch'}->{'data'}};
	Statistics::Covid::Utils::discretise_increasing_sequence_of_seconds(
		\@copy, # << in-place modification
		3600, # unit in seconds: 3600 seconds -> 1 hour discrete steps
		0 # optional offset, (the 0 hour above)
	);
        # new key:
        $df->{$_}->{'datetimeHoursSinceOldest'} = {'data' => \@copy};
    }
    #print "After:\n".pp($df);

    # normalise confirmed cases over total population
    # from the World Bank indicators
    $WBio = Statistics::Covid::WorldbankData::IO->new({
        # the params, the relevant section is
        # under key 'worldbankdata'
        'config-hash' => $confighash,
        'debug' => 0,
    }) or die "failed to construct";
    $WBio->db_connect() or die "failed to connect to db (while on world bank)";
    $WBobjs = $WBio->db_select({
         'conditions' => {
		countryname=>['Spain', 'Italy', 'Belgium'],
		year=>2018, # for last years some are not defined yet
	 },
    });
    print pp($WBobjs)."\n";

    my %indicators;
    # population size
    $indicators{'pop'} = { map { $_->get_column('countryname') => $_->get_column('SP_POP_TOTL') } @$WBobjs };
    # GDP (current US$)
    $indicators{'gdp'} = { map { $_->get_column('countryname') => $_->get_column('NY_GDP_MKTP_CD') } @$WBobjs };
    # Current health expenditure (% of GDP)
    $indicators{'health_exp'} = { map { $_->get_column('countryname') => $_->get_column('SH_XPD_CHEX_GD_ZS') } @$WBobjs };
    # Hospital beds (per 1,000 people)
    $indicators{'hospital_beds'} = { map { $_->get_column('countryname') => $_->get_column('SH_MED_BEDS_ZS') } @$WBobjs };
    # Death rate, crude (per 1,000 people)
    $indicators{'death_rate'} = { map { $_->get_column('countryname') => $_->get_column('SP_DYN_CDRT_IN') } @$WBobjs };

    # normalise all markers (confirmed, unconfirmed etc) to the population size
    # that's in-place for the data frame
    for my $admin0 (sort keys %$df){
        for my $aY (sort keys %{$df->{$admin0}}){
    	    for my $anIndicator (sort keys %indicators){
                my @vals = @{$df->{$admin0}->{$aY}->{'data'}};
    		$_ /= $indicators{$anIndicator}->{$admin0} for @vals;
		# add a new entry to the dataframe
		$df->{$admin0}->{$aY."-over-$anIndicator"} = {
			'data' => \@vals
		};
	    }
	}
    }

    # fit to a polynomial of degree 3 (max power of x is 3)
    $ret = Statistics::Covid::Analysis::Model::Simple::fit({
	'dataframe' => $df,
	'X' => 'datetimeHoursSinceOldest', # our X is this field from the dataframe
	'Y' => 'confirmed', # our Y is this field
	# initial values guess (here ONLY for some coefficients)
	'initial-guess' => {'c1'=>1, 'c2'=>1},
	'polynomial-fit' => 3, # max power of x is 3
	'fit-params' => {
		'maximum_iterations' => 100000
	}
    });

    # do an exponential fit
    $ret = Statistics::Covid::Analysis::Model::Simple::fit({
	'dataframe' => $df,
	'X' => 'datetimeHoursSinceOldest', # our X is this field from the dataframe
	'Y' => 'confirmed', # our Y is this field
	'initial-guess' => {'c1'=>1, 'c2'=>1}, # initial values guess
	'exponential-fit' => 1,
	'fit-params' => {
		'maximum_iterations' => 100000
	}
    });
    print "Here are models, one for each group:\n".pp($ret);

    # evaluate the model at every time point
    # we have a model for each group of data (remember groupby)
    # e.g. for Spain
    my $aY = 'confirmed'; # this is what we fitted against, our Y
    for $k (keys %$ret){
        # k is like 'Spain'
        $model = $ret->{$k};
        my @outv;
        $actualdata = $df->{$k}->{$aY}->{'data'};
        $timepoints = $df->{$k}->{'datetimeHoursSinceOldest'}->{'data'};
        $N = scalar @$timepoints;
        for($i=0;$i<$N;$i++){
           $t = $timepoints->[$i];
           $actualv = $actualdata->[$i];
           $v = $model->evaluate($t); # << evaluates the equation at $t
           push @outv, $v;
        }
        $df->{$k}->{$aY}->{'fitted-exponential'} = \@outv;
    }

    # plot 'confirmed' vs 'time'
    $aY = 'confirmed';
    $ret = Statistics::Covid::Analysis::Plot::Simple::plot({
	'dataframe' => $df,
	'outfile' => $aY.'-over-time.png',
	'Y' => $aY,
	'X' => 'datetimeUnixEpoch', # secs since THE epoch
    });

    # plot 'terminal' vs 'time'
    $aY = 'confirmed';
    $ret = Statistics::Covid::Analysis::Plot::Simple::plot({
	'dataframe' => $df,
	'outfile' => $aY.'-over-time.png',
	'Y' => $aY,
	'X' => 'datetimeUnixEpoch', # secs since THE epoch
    });

    for my $anIndicator (sort keys %indicators){
	$aY = 'confirmed-over-'.$anIndicator;
        # plot 'confirmed' vs 'time'
        $ret = Statistics::Covid::Analysis::Plot::Simple::plot({
	'dataframe' => $df,
	'outfile' => $aY.'-over-time.png',
	'Y' => $aY,
	'X' => 'datetimeUnixEpoch', # secs since THE epoch
        }) or die;

        # plot 'terminal' vs 'time'
        $ret = Statistics::Covid::Analysis::Plot::Simple::plot({
	'dataframe' => $df,
	'outfile' => $aY.'-over-time.png',
	'Y' => $aY,
	'X' => 'datetimeUnixEpoch', # secs since THE epoch
        }) or die;
    }

=head1 EXAMPLE SCRIPTS

    datasets-worldbank-fetch-data-and-store.pl \
       --config-file config/config.json \
      --no-overwrite \
      --debug 1

    statistics-covid-plot-data-and-fit-model.pl \
      --config-file config/config.json \
      --outdir xx \
      --fit-model exponential \
      --fit-model polynomial=4 \
      --group-by 'admin0' \
      --search-conditions '{admin0=>["Spain", "Italy", "Belgium"]}'

    statistics-covid-plot-data-and-fit-model.pl \
      --config-file config/config.json \
      --outdir xx \
      --fit-model exponential \
      --fit-model polynomial=4 \
      --group-by 'admin0' \
      --group-by 'admin3' \
      --search-conditions \
       '{admin0=>"United Kingdom of Great Britain and Northern Ireland",datasource=>"UK::GOVUK2",admin3=>["Hackney", "Tower Hamlets", "Kensington and Chelsea"]}'




C<script/statistics-covid-fetch-data-and-store.pl> is
a script which accompanies this distribution. It can be
used to fetch any data from specified providers using a
specified configuration file.

For a quick start:

copy an example config file to your local dir
from the test dir of the distribution, do not modify
t/config-for-t.json as tests may fail afterwards.
    cp t/config-for-t.json config.json

optionally modify config.json to change the destination data dirs
for example you can have undef "fileparams"
"datafiles-dir": "data/files",
    # and under "dbparams" (if you deal with SQLite)
    # "dbdir" : "t/t-data/db", 
    # now fetch data from some default data providers,
    # fetched data files will be placed in data/files/<PROVIDERDIR> (timestamped)
    # and a database will be created. If you are dealing with SQLite
    # the database will be at
    #     t/t-data/db/covid19.sqlite
    script/statistics-covid-fetch-data-and-store.pl \
        --config-file config.json

    # if you do not want to save the fetched data into local files
    # but only in db:
    script/statistics-covid-fetch-data-and-store.pl \
        --config-file config.json \
        --nosave-to-file \
        --save-to-db \
        --provider 'World::JHU'

The above examples will fetch the latest data and insert it into an SQLite
database in C<data/db/covid19.sqlite> directory (but that
depends on the "dbdir" entry in your config file.
When this script is called again, it will fetch the data again
and will be saved into a file timestamped with publication date.
So, if data was already fetched it will be simply overwritten by
this same data.

It will also insert fetched data in the database. There are three
modes of operation for that, denoted by the C<replace-existing-db-record>
entry in the config file (under C<dparams>).

=head3 Definition of duplicate records

A I<duplicate> record means duplicate as far as the primary key(s)
are concerned and nothing else. For example, L<Statistics::Covid::Datum>'s
PK is a combination of
C<name>, C<id> and C<datetimeISO8601> (see L<Statistics::Covid::Datum::Table>).
If two records have these 3 fields exactly the same, then they are considered
I<duplicate>. If one record's C<confirmed> value is 5 and the second record's
is 10, then the second record is considered more I<up-to-date>, I<newer>
than the first one. See L<Statistics::Covid::Datum::newer_than> on how to
overwrite that behaviour.

=over 2

C<replace> : will force B<replacing> existing database data with new data, 
no questions asked about. With this option existing data may be more
up-to-date than the newly fetched data, but it will be forcibly replaced.
No questions asked.

C<ignore> : will not insert new data if I<duplicate> exists in database.
End of story. No questions asked.

C<only-better> : this is the preferred option. Only I<newer>,
more I<up-to-date> data
will be inserted. I<newer> is decided by what
L<Statistics::Covid::Datum::newer_than> sub returns.
With this option in your config file,
calling this script, more than once will
make sure you have the latest data without accummulating it
redundantly either in the database or as a local file.

=back

B<Please call this script AT MAXIMUM one or two times per day so as not to
obstruct public resources.>

When the database is up-to-date, analysis of data is the next step:
plotting, fitting to analytical models, prediction, comparison.

=head1 DATABASE SUPPORT

SQLite and MySQL database types are supported through the
abstraction offered by L<DBI> and L<DBIx::Class>.

B<However>, only the SQLite support has been tested.

B<Support for MySQL is totally untested>.

=head1 REPOSITORY

L<https://github.com/hadjiprocopis/statistics-covid>

=head1 AUTHOR

Andreas Hadjiprocopis, C<< <bliako at cpan.org> >>, C<< <andreashad2 at gmail.com> >>

=head1 BENCHMARKS

There are some benchmark tests to time database insertion and retrieval
performance. These are
optional and will not be run unless explicitly stated via
C<make bench>

These tests do not hit the online data providers at all. And they
should not, see ADDITIONAL TESTING for more information on this.
They only time the creation of objects and insertion
to the database.

=head1 ADDITIONAL TESTING

Testing the DataProviders is not done because it requires
network access and hits on the providers which is not fair.
However, there are targets in the Makefile for initiating
the "network" tests by doing C<make network> .

=head1 CAVEATS

This module has been put together very quickly and under pressure.
There are must exist quite a few bugs. In addition, the database
schema, the class functionality and attributes are bound to change.
A migration database script may accompany new versions in order
to use the data previously collected and stored.

B<Support for MySQL is totally untested>. Please use SQLite for now
or test the MySQL interface.

B<Support for Postgres has been somehow missed but is underway!>.

=head1 BUGS

This module has been put together very quickly and under pressure.
There are must exist quite a few bugs.

Please report any bugs or feature requests to C<bug-statistics-Covid at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Statistics-Covid>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Statistics::Covid


You can also look for information at:

=over 4

=item * github L<repository|https://github.com/hadjiprocopis/statistics-covid>  which will host data and alpha releases

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Statistics-Covid>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Statistics-Covid>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Statistics-Covid>

=item * Search CPAN

L<http://search.cpan.org/dist/Statistics-Covid/>

=item * Information about the basis module DBIx::Class

L<http://search.cpan.org/dist/DBIx-Class/>

=back


=head1 DEDICATIONS

Almaz

=head1 ACKNOWLEDGEMENTS

=over 2

=item L<Perlmonks|https://www.perlmonks.org> for supporting the world with answers and programming enlightment

=item L<DBIx::Class>

=item the data providers:

=over 2

=item L<Johns Hopkins University|https://www.arcgis.com/apps/opsdashboard/index.html#/bda7594740fd40299423467b48e9ecf6>,

=item L<UK government|https://www.gov.uk/government/publications/covid-19-track-coronavirus-cases>,

=item L<https://www.bbc.co.uk> (for disseminating official results)

=back

=back

=head1 LICENSE AND COPYRIGHT

Copyright 2020 Andreas Hadjiprocopis.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
=cut

# NAME

Statistics::Covid - Fetch, store in DB, retrieve and analyse Covid-19 statistics from data providers

# VERSION

Version 0.23

# DESCRIPTION

This module fetches, stores in a database, retrieves from a database and analyses
Covid-19 statistics from online or offline data providers, such as
from [the John Hopkins University](https://www.arcgis.com/apps/opsdashboard/index.html#/bda7594740fd40299423467b48e9ecf6)
which I hope I am not obstructing (please send an email to the author if that is the case).

After specifying one or more data providers (as a url and a header for data and
optionally for metadata), this module will attempt to fetch the latest data
and store it in a database (SQLite and MySQL, only SQLite was tested so far).
Each batch of data should ideally contain information about one or more locations
and at a given point in time. All items in this batch are extracted and stored
in DB each with its location name and time (it was published, not fetched) as primary keys.
Each such data item (Datum) is described in [Statistics::Covid::Datum::Table](https://metacpan.org/pod/Statistics%3A%3ACovid%3A%3ADatum%3A%3ATable)
and the relevant class is [Statistics::Covid::Datum](https://metacpan.org/pod/Statistics%3A%3ACovid%3A%3ADatum). It contains
fields such as: `population`, `confirmed`, `unconfirmed`, `terminal`, `recovered`.

Focus was on creating very high-level which distances as much as possible
the user from the nitty-gritty details of fetching data using [LWP::UserAgent](https://metacpan.org/pod/LWP%3A%3AUserAgent)
and dealing with the database using [DBI](https://metacpan.org/pod/DBI) and [DBIx::Class](https://metacpan.org/pod/DBIx%3A%3AClass).

This is an early release until the functionality and the table schemata
solidify.

# SYNOPSIS

        use Statistics::Covid;
        use Statistics::Covid::Datum;

        $covid = Statistics::Covid->new({
                'config-file' => 't/config-for-t.json',
                'providers' => ['UK::BBC', 'UK::GOVUK', 'World::JHU'],
                'save-to-file' => 1,
                'save-to-db' => 1,
                'debug' => 2,
        }) or die "Statistics::Covid->new() failed";
        # fetch all the data available (posibly json), process it,
        # create Datum objects, store it in DB and return an array
        # of the Datum objects just fetched  (and not what is already in DB).
        my $newobjs = $covid->fetch_and_store();

        print $_->toString() for (@$newobjs);

        print "Confirmed cases for ".$_->name()
                ." on ".$_->date()
                ." are: ".$_->confirmed()
                ."\n"
        for (@$newobjs);

        my $someObjs = $covid->select_datums_from_db({
                'conditions' => {
                        belongsto=>'UK',
                        name=>'Hackney'
                }
        });

        print "Confirmed cases for ".$_->name()
                ." on ".$_->date()
                ." are: ".$_->confirmed()
                ."\n"
        for (@$someObjs);

        # or for a single place (this sub sorts results wrt publication time)
        my $timelineObjs =
          $covid->select_datums_from_db_for_specific_location_time_ascending(
                'Hackney'
          );

        # or for a wildcard match
        my $timelineObjs =
          $covid->select_datums_from_db_for_specific_location_time_ascending(
                {'like'=>'Hack%'}
          );

        # and maybe specifying max rows
        my $timelineObjs =
          $covid->select_datums_from_db_for_specific_location_time_ascending(
                {'like'=>'Hack%'}, {'rows'=>10}
          );

        # print those datums
        for my $anobj (@$timelineObjs){
                print $anobj->toString()."\n";
        }

        # total count of datapoints matching the select()
        print "datum rows matched: ".scalar(@$timelineObjs)."\n";

        # total count of datapoints in db
        print "datum rows in DB: ".$covid->db_count_datums()."\n";

        ###
        # Here is how to select data and plot it
        ##

        use Statistics::Covid;
        use Statistics::Covid::Datum;
        use Statistics::Covid::Utils;
        use Statistics::Covid::Analysis::Plot::Simple;

        # now read some data from DB and do things with it
        # this assumes a test database in t/t-data/db/covid19.sqlite
        # which is already supplied with this module (60K)
        # use a different config-file (or copy and modify
        # the one in use here, but don't modify itself because
        # tests depend on it)
        $covid = Statistics::Covid->new({
                'config-file' => 't/config-for-t.json',
                'debug' => 2,
        }) or die "Statistics::Covid->new() failed";

        # select data from DB for selected locations (in the UK)
        # data will come out as an array of Datum objects sorted wrt time
        # (wrt the 'datetimeUnixEpoch' field)
        $objs =
          $covid->select_datums_from_db_for_specific_location_time_ascending(
                #{'like' => 'Ha%'}, # the location (wildcard)
                ['Halton', 'Havering'],
                #{'like' => 'Halton'}, # the location (wildcard)
                #{'like' => 'Havering'}, # the location (wildcard)
                'UK', # the belongsto (could have been wildcarded or omitted)
          );

        # create a dataframe (see doc in L<Statistics::Covid::Utils>)
        $df = Statistics::Covid::Utils::datums2dataframe({
                # input data is an array of L<Statistics::Covid::Datum>'s
                # as fetched from providers or selected from DB (see above)
                'datum-objs' => $objs,

                # collect data from all those with same 'name' and same 'belongsto'
                # and maybe plot this data as a single curve (or fit or whatever)
                # this will essentially create an entry for 'Hubei|China'
                # another for 'Italy|World', another for 'Hackney|UK'
                # etc. FOR all name/belongsto tuples in your
                # selected L<Statistics::Covid::Datum>'s
                'groupby' => ['name','belongsto'],

                # what fields/attributes/column-names of the datum object
                # to insert into the dataframe?
                # for plotting you need at least 2, one for the role of X
                # and one for the role of Y (see plotting later)
                # if you want to plot multiple Y, then add here more dependent columns
                # e.g. ('unconfirmed', etc.).
                # here we insert the values of 3 column-names
                # it will be an array of values for each field in the same order
                # as in the input '$objs' array.
                # Which was time-ascending sorted upon the select() (see retrieving above)
                'content' => ['confirmed', 'unconfirmed', 'datetimeUnixEpoch'],
        });

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
                # if X is not present it is assumed to be this:
                #'X' => 'datetimeUnixEpoch',
        });

        # plot confirmed vs unconfirmed
        # if you see in your plot just a vertical line
        # it means that your data has no 'unconfirmed' variation
        # most likely all 'unconfirmed' are zero because
        # the data provider does not provide these values.
        $ret = Statistics::Covid::Analysis::Plot::Simple::plot({
                'dataframe' => $df,
                'outfile' => 'confirmed-vs-unconfirmed.png',
                # the role of X is now this, not time as above
                'X' => 'unconfirmed',
                # plot this column with X
                'Y' => 'confirmed',
        });

        # plot using an array of datum objects as they came
        # out of the DB.
        # For convenience, a dataframe is created internally, in  plot(),
        # This is not recommended if you are going to make several
        # plots because equally many dataframes must be created and destroyed
        # internally instead of recycling them like we do above  ...
        $ret = Statistics::Covid::Analysis::Plot::Simple::plot({
                # datum objs instead of a dataframe, you need to
                # define some parameters for the creation of
                # the dataframe, e.g. 'GroupBy'
                'datum-objs' => $objs,
                # see the datums2dataframe() example above for explanation:
                'GroupBy' => ['name', 'belongsto'],

                'outfile' => 'confirmed-over-time.png',
                # use this column as Y
                'Y' => 'confirmed',
                # X is not present so default is time ('datetimeUnixEpoch')
                # here we specify how to format the X (time) values,
                # i.e. seconds since the Unix epoch.
                # print them only as Months (numbers): %m
                # see Chart::Clicker::Axis::DateTime for all the options
                # if not present a default format for time will be supplied.
                'date-format-x' => {
                        format => '%m', ##<<< specify timeformat for X axis, only months
                        position => 'bottom',
                        orientation => 'horizontal'
                },
        });

        #####
        # Fit an analytical model to data
        # i.e. find the parameters of a user-specified
        # equation which can fit on all the data points
        # with the least error.
        # In suce cases (growth), an exponential model is
        # usual: c1 * c2^x (c1 and c2 must be found / fitted)
        # 'x' is the independent variable and usually denotes time
        # time in L<Statistics::Covid::Datum> is the
        # 'datetimeUnixEpoch' field     
        #####

        use Statistics::Covid;
        use Statistics::Covid::Datum;
        use Statistics::Covid::Utils;
        use Statistics::Covid::Analysis::Model::Simple;

        # create a dataframe, as before, from some select()'ed
        # L<Statistics::Covid::Datum> objects from DB or provider.
        my $df = Statistics::Covid::Utils::datums2dataframe({
                'datum-objs' => $objs,
                'groupby' => ['name'],
                'content' => ['confirmed', 'datetimeUnixEpoch'],
        });
        # we have a problem because seconds since the Unix epoch
        # is a huge number and the fitter algorithm does not like it.
        # So push their oldest datapoint to 0 (hours) and all
        # later datapoints to be relative to that.
        # This does not affect data in DB or even in the array of
        # datum objects. This affects the dataframe created above only
        for(sort keys %$df){
                Statistics::Covid::Utils::discretise_increasing_sequence_of_seconds(
                        $df->{$_}->{'datetimeUnixEpoch'}, # << in-place modification
                        3600, # seconds -> hours
                        0 # optional offset, (the 0 hour above)
                )
        }

        # do an exponential fit
        my $ret = Statistics::Covid::Analysis::Model::Simple::fit({
                'dataframe' => $df,
                'X' => 'datetimeUnixEpoch', # our X is this field from the dataframe
                'Y' => 'confirmed', # our Y is this field
                'initial-guess' => {'c1'=>1, 'c2'=>1}, # initial values guess
                'exponential-fit' => 1,
                'fit-params' => {
                        'maximum_iterations' => 100000
                }
        });

        # fit to a polynomial of degree 10 (max power of x is 10)
        my $ret = Statistics::Covid::Analysis::Model::Simple::fit({
                'dataframe' => $df,
                'X' => 'datetimeUnixEpoch', # our X is this field from the dataframe
                'Y' => 'confirmed', # our Y is this field
                # initial values guess (here ONLY for some coefficients)
                'initial-guess' => {'c1'=>1, 'c2'=>1},
                'polynomial-fit' => 10, # max power of x is 10
                'fit-params' => {
                        'maximum_iterations' => 100000
                }
        });

        # fit to an ad-hoc formula in 'x'
        # (see L<Math::Symbolic::Operator> for supported operators)
        my $ret = Statistics::Covid::Analysis::Model::Simple::fit({
                'dataframe' => $df,
                'X' => 'datetimeUnixEpoch', # our X is this field from the dataframe
                'Y' => 'confirmed', # our Y is this field
                # initial values guess (here ONLY for some coefficients)
                'initial-guess' => {'c1'=>1, 'c2'=>1},
                'formula' => 'c1*sin(x) + c2*cos(x)',
                'fit-params' => {
                        'maximum_iterations' => 100000
                }
        });

        # this is what fit() returns

        # $ret is a hashref where key=group-name, and
        # value=[ 3.4,  # <<<< mean squared error of the fit
        #  [
        #     ['c1', 0.123, 0.0005], # <<< coefficient c1=0.123, accuracy 0.00005 (ignore that)
        #     ['c2', 1.444, 0.0005]  # <<< coefficient c1=1.444
        #  ]
        # and group-name in our example refers to each of the locations selected from DB
        # in this case data from 'Halton' in 'UK' was fitted on 0.123*1.444^time with an m.s.e=3.4

        # This is what the dataframe looks like:
        #  {
        #  Halton   => {
        #               confirmed => [0, 0, 3, 4, 4, 5, 7, 7, 7, 8, 8, 8],
        #               datetimeUnixEpoch => [
        #                 1584262800,
        #                 1584349200,
        #                 1584435600,
        #                 1584522000,
        #                 1584637200,
        #                 1584694800,
        #                 1584781200,
        #                 1584867600,
        #                 1584954000,
        #                 1585040400,
        #                 1585126800,
        #                 1585213200,
        #               ],
        #             },
        #  Havering => {
        #               confirmed => [5, 5, 7, 7, 14, 19, 30, 35, 39, 44, 47, 70],
        #               datetimeUnixEpoch => [
        #                 1584262800,
        #                 1584349200,
        #                 1584435600,
        #                 1584522000,
        #                 1584637200,
        #                 1584694800,
        #                 1584781200,
        #                 1584867600,
        #                 1584954000,
        #                 1585040400,
        #                 1585126800,
        #                 1585213200,
        #               ],
        #             },
        #  }

        # and after converting the datetimeUnixEpoch values to hours and setting the oldest to t=0
        #  {
        #  Halton   => {
        #                confirmed => [0, 0, 3, 4, 4, 5, 7, 7, 7, 8, 8, 8],
        #                datetimeUnixEpoch => [0, 24, 48, 72, 104, 120, 144, 168, 192, 216, 240, 264],
        #              },
        #  Havering => {
        #                confirmed => [5, 5, 7, 7, 14, 19, 30, 35, 39, 44, 47, 70],
        #                datetimeUnixEpoch => [0, 24, 48, 72, 104, 120, 144, 168, 192, 216, 240, 264],
        #              },
        #  }



        use Statistics::Covid::Analysis::Plot::Simple;

        # plot something
        my $objs = $io->db_select({
                conditions => {belongsto=>'UK', name=>{'like' => 'Ha%'}}
        });
        my $outfile = 'chartclicker.png';
        my $ret = Statistics::Covid::Analysis::Plot::Simple::plot({
                'datum-objs' => $objs,
                # saves to this file:
                'outfile' => $outfile,
                # plot this column (x-axis is time always)
                'Y' => 'confirmed',
                # and make several plots, each group must have 'name' common
                'GroupBy' => ['name']
        });

# EXAMPLE SCRIPTS

`script/statistics-covid-fetch-data-and-store.pl` is
a script which accompanies this distribution. It can be
used to fetch any data from specified providers using a
specified configuration file.

For a quick start:

    # copy an example config file to your local dir
    # from the test dir of the distribution, do not modify
    # t/config-for-t.json as tests may fail afterwards.
    cp t/config-for-t.json config.json

    # optionally modify config.json to change the destination data dirs
    # for example you can have undef "fileparams"
    # "datafiles-dir": "data/files",
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
database in `data/db/covid19.sqlite` directory (but that
depends on the "dbdir" entry in your config file.
When this script is called again, it will fetch the data again
and will be saved into a file timestamped with publication date.
So, if data was already fetched it will be simply overwritten by
this same data.

It will also insert fetched data in the database. There are three
modes of operation for that, denoted by the `replace-existing-db-record`
entry in the config file (under `dparams`). Clarification:
a _duplicate_ record means duplicate as far as the primary key(s)
are concerned and nothing else. For example, [Statistics::Covid::Datum](https://metacpan.org/pod/Statistics%3A%3ACovid%3A%3ADatum)'s
PK is a combination of
`name`, `id` and `datetimeISO8601` (see [Statistics::Covid::Datum::Table](https://metacpan.org/pod/Statistics%3A%3ACovid%3A%3ADatum%3A%3ATable)).
If two records have these 3 fields exactly the same, then they are considered
_duplicate_.

> `ignore` : will not insert new data if duplicate exists 
>
> only newer, up-to-date data
> will be inserted. So, calling this script, say once or twice will
> make sure you have the latest data without accummulating it
> redundantly.
>
> **But please call this script AT MAXIMUM one or two times per day so as not to
> obstruct public resources. Please, Please.**
>
> When the database is up-to-date, analysis of data is the next step.
>
> In the synopis, it is shown how to select records from the database,
> as an array of [Statistics::Covid::Datum](https://metacpan.org/pod/Statistics%3A%3ACovid%3A%3ADatum) objects. Feel free to
> share any modules you create on analysing this data, either
> under this namespace (for example Statistics::Covid::Analysis::XYZ)
> or any other you see appropriate.

# CONFIGURATION FILE

Below is an example configuration file which is essentially JSON with comments.
It can be found in `t/config-for-t.json` relative to the root directory
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

# DATABASE SUPPORT

SQLite and MySQL database types are supported through the
abstraction offered by [DBI](https://metacpan.org/pod/DBI) and [DBIx::Class](https://metacpan.org/pod/DBIx%3A%3AClass).

**However**, only the SQLite support has been tested.

**Support for MySQL is totally untested**.

# AUTHOR

Andreas Hadjiprocopis, `<bliako at cpan.org>`, `<andreashad2 at gmail.com>`

# BENCHMARKS

There are some benchmark tests to time database insertion and retrieval
performance. These are
optional and will not be run unless explicitly stated via
`make bench`

These tests do not hit the online data providers at all. And they
should not, see ADDITIONAL TESTING for more information on this.
They only time the creation of objects and insertion
to the database.

# ADDITIONAL TESTING

Testing the DataProviders is not done because it requires
network access and hits on the providers which is not fair.
However, there are targets in the Makefile for initiating
the "network" tests by doing `make network` .

# CAVEATS

This module has been put together very quickly and under pressure.
There are must exist quite a few bugs. In addition, the database
schema, the class functionality and attributes are bound to change.
A migration database script may accompany new versions in order
to use the data previously collected and stored.

**Support for MySQL is totally untested**. Please use SQLite for now
or test the MySQL interface.

**Support for Postgres has been somehow missed but is underway!**.

# BUGS

This module has been put together very quickly and under pressure.
There are must exist quite a few bugs.

Please report any bugs or feature requests to `bug-statistics-Covid at rt.cpan.org`, or through
the web interface at [http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Statistics-Covid](http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Statistics-Covid).  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

# SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Statistics::Covid

You can also look for information at:

- github [repository](https://github.com/hadjiprocopis/statistics-covid)  which will host data and alpha releases
- RT: CPAN's request tracker (report bugs here)

    [http://rt.cpan.org/NoAuth/Bugs.html?Dist=Statistics-Covid](http://rt.cpan.org/NoAuth/Bugs.html?Dist=Statistics-Covid)

- AnnoCPAN: Annotated CPAN documentation

    [http://annocpan.org/dist/Statistics-Covid](http://annocpan.org/dist/Statistics-Covid)

- CPAN Ratings

    [http://cpanratings.perl.org/d/Statistics-Covid](http://cpanratings.perl.org/d/Statistics-Covid)

- Search CPAN

    [http://search.cpan.org/dist/Statistics-Covid/](http://search.cpan.org/dist/Statistics-Covid/)

- Information about the basis module DBIx::Class

    [http://search.cpan.org/dist/DBIx-Class/](http://search.cpan.org/dist/DBIx-Class/)

# DEDICATIONS

Almaz

# ACKNOWLEDGEMENTS

- [Perlmonks](https://www.perlmonks.org) for supporting the world with answers and programming enlightment
- [DBIx::Class](https://metacpan.org/pod/DBIx%3A%3AClass)
- the data providers:
    - [John Hopkins University](https://www.arcgis.com/apps/opsdashboard/index.html#/bda7594740fd40299423467b48e9ecf6),
    - [UK government](https://www.gov.uk/government/publications/covid-19-track-coronavirus-cases),
    - [https://www.bbc.co.uk](https://www.bbc.co.uk) (for disseminating official results)

# LICENSE AND COPYRIGHT

Copyright 2020 Andreas Hadjiprocopis.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

[http://www.perlfoundation.org/artistic\_license\_2\_0](http://www.perlfoundation.org/artistic_license_2_0)

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

# POD ERRORS

Hey! **The above document had some coding errors, which are explained below:**

- Around line 912:

    &#x3d;over should be: '=over' or '=over positive\_number'

- Around line 935:

    You forgot a '=back' before '=head1'

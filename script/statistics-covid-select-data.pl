#!/usr/bin/env perl

# for more documentation use the -h flag

our $VERSION = '0.24';

use strict;
use warnings;

use Statistics::Covid::Utils;
use Statistics::Covid::Datum;

use Getopt::Long;
use DateTime;
use Geography::Countries::LatLong;

use Data::Dump qw/pp/;
use Data::Undump qw/undump/;

# there is a:
#    require Statistics::Covid;
# further down, don't place one here

my $configfile = undef;
my $admin1 = '{like => "%"}';
# undef means anything, but don't leave it empty ('') nothing will be matched
my $admin0 = undef;
my $search_conditions = {};
my $search_attributes = {};
my $time_range = undef;
my $DEBUG = 0;
my $outfile = undef;
my $fitmodels = undef;
# these will overwrite config-file settings
# modules also have some internal sane defaults
my $X = 'datetimeUnixEpoch'; # default independent variable 'x'
my $Y = {
	'confirmed' => 1, # default dependent variables for 'y'
	'terminal' => 1,
	'recovered' => 1,
#	'unconfirmed' => 1,
};
my $GroupBy = {
	'admin0' => 1,
};

my $GetoptParser = Getopt::Long::Parser->new;

# 1st pass of argv, we need to read the config file first
# because in the second pass we push option value into the config hash
# which is too nested for Getopt's feature of pushing to hash
# pass_through: this option ignores options for 2nd pass but removes options parsed by 1st pass
$GetoptParser->configure('pass_through');
$GetoptParser->getoptions(
	'config-file=s' => \$configfile,
); # dont check it
die usage() . "\n\nA configuration file (--config-file) is required." unless defined $configfile;

my $confighash = Statistics::Covid::Utils::configfile2perl($configfile);
if( ! defined $confighash ){ print STDERR "$0 : config-file '$configfile' failed to read or parse.\n"; exit(1) }
if( $DEBUG > 0 ){ print "$0 : read the config file as:\n".pp($confighash)."\n" }

# 2nd pass of the ARGV (1st pass deleted some options and let others pass through)
# now we have a config-hash ready
if( ! $GetoptParser->getoptions(
	'search-conditions=s' => sub {
		# we are (hopefully) not eval'ing this perl var we get from user. AFAIK we are not
		my $pvstr = $_[1];
		my $pv = Data::Undump::undump($pvstr);
		if( ! defined $pv ){ print STDERR "--search-conditions '$pvstr' : input is not a perl variable.\n"; exit(1) }
		@{ $search_conditions }{keys %$pv} = values %$pv;
	},
	'search-attributes=s' => sub {
		# we are (hopefully) not eval'ing this perl var we get from user. AFAIK we are not
		my $pvstr = $_[1];
		my $pv = Data::Undump::undump($pvstr);
		if( ! defined $pv ){ print STDERR "--search-attributes '$pvstr' : input is not a perl variable.\n"; exit(1) }
		@{ $search_attributes }{keys %$pv} = values %$pv;
	},
	'search-attributes=s' => \$search_attributes,
	# exact name or SQL wildcard
	# or SQL::Abstract search condition (as a string)
	'admin1=s' => sub {
		# we are (hopefully) not eval'ing this perl var we get from user. AFAIK we are not
		my $pvstr = $_[1];
		my $pv = Data::Undump::undump($pvstr);
		if( ! defined $pv ){ print STDERR "--location-name '$pvstr' : input is not a perl variable.\n"; exit(1) }
		$search_conditions->{'admin1'} = $pv;
		$GroupBy->{'admin1'} = 1;
	},
	# optional: the 'admin1' belongs to this geo-entity
	# UK, China, World, USA etc.
	'admin0=s' => sub {
		# we are (hopefully) not eval'ing this perl var we get from user. AFAIK we are not
		my $pvstr = $_[1];
		my $pv = Data::Undump::undump($pvstr);
		if( ! defined $pv ){ print STDERR "--admin0 '$pvstr' : input is not a perl variable.\n"; exit(1) }
		$search_conditions->{'admin0'} = $pv;
		$GroupBy->{'admin0'} = 1;
	},
	'max-rows=s' => sub {
		$search_attributes->{'rows'} = $_[1];
	},
	'outfile=s' => \$outfile,
	'time-range=s{2}' => sub {
		# it requires exactly 2 DateTime-iso8601-parsable dates
		# for the beginning and the end of the time range (inclusive)
		my $from = Statistics::Covid::Utils::iso8601_to_DateTime($_[1]);
		if( ! defined $from ){ print STDERR "$0 : ".$_[0]." : FROM datetime does not parse: '".$_[1]."'\n"; exit(1) }
		my $to = Statistics::Covid::Utils::iso8601_to_DateTime($_[1]);
		if( ! defined $from ){ print STDERR "$0 : ".$_[0]." : FROM datetime does not parse: '".$_[2]."'\n"; exit(1) }
		$time_range = [$from, $to];
	},
	'X=s' => \$X,
	'Y=s' => sub { $Y->{$_[1]} = 1 },
	'no-Y=s' => sub { delete $Y->{$_[1]} },
	'group-by=s' => sub { $GroupBy->{$_[1]} = 1 },
	'no-group-by=s' => sub { delete $GroupBy->{$_[1]} },
	'fit-model=s' => sub {
		$fitmodels = {} unless defined $fitmodels;
		if( $_[1] eq 'exponential' ){
			$fitmodels->{$_[1]} = {'exponential-fit'=>1};
		} elsif( $_[1] =~ /^polynomial=([0-9]+)$/ ){
			$fitmodels->{$_[1]} = {'polynomial-fit'=>$1};
		} else {
			# a formula in 'x' with ad-hoc named coefficients, e.g. c1+c2*x+c3*x^2 as a string
			$fitmodels->{'adhoc'} = $_[1];
		}
	},
	'debug=i' => \$DEBUG,

	'plot-min-points=i' => \$confighash->{'analysis'}->{'plot'}->{'min-points'},
	'fit-min-points=i' => \$confighash->{'analysis'}->{'fit'}->{'min-points'},
	'fit-max-iterations=i' => \$confighash->{'analysis'}->{'fit'}->{'max-iterations'},
	'fit-max-mean-error=i' => \$confighash->{'analysis'}->{'fit'}->{'max-mean-error'},

) ){ die usage() . "\n\nerror in command line."; }

if( $DEBUG > 0 ){ print "$0 : after parsing user-specified options from the command line, config is now:\n".pp($confighash)."\n" }

$GroupBy = [sort keys %$GroupBy];
$Y = [sort keys %$Y];

#die usage() . "\n\nGroup-by column names (--group-by) do not exist." if scalar(@$GroupBy)==0;
#die usage() . "\n\nColumn names for the role of the 'Y' variable (--Y) do not exist." if scalar(@$Y)==0;
#die usage() . "\n\nAt least one model to fit (--fit-model) must be specified." unless defined $fitmodels;

##### end of parsing cmd line params
if( ! defined $outfile ){
	my $dt = DateTime->now();
	my $stamp = $dt->ymd('.').'_'.$dt->hms('.');
	$outfile = $stamp.'.json';
}

my $ts = time;

print "attributes are:\n".pp($search_attributes)."\n";
print "conditions are:\n".pp($search_conditions)."\n";

# the reason is that loading this module will create schemas etc
# which is a bit of a heavy work just to exit because we do not have a config file
# so load the module after all checks OK.
require Statistics::Covid;

# create the main entry point to fetch and store data
my $covid = Statistics::Covid->new({   
	'config-hash' => $confighash,
	'debug' => $DEBUG,
}) or die "Statistics::Covid->new() failed";

my $dbparams = $covid->dbparams();
my $dbtype = $dbparams->{'dbtype'};
my $dbname = $dbtype eq 'SQLite'
	? File::Spec->catfile($dbparams->{'dbdir'}, $dbparams->{'dbname'})
	: $dbparams->{'dbname'}
;

# select rows from db
# see L<Statistics::Covid> for examples.
my $objs =
#  $covid->select_datums_from_db_time_ascending({
  $covid->select_datums_from_db_latest({
	'conditions' => $search_conditions,
	'attributes' => $search_attributes,
  });
if( ! defined($objs) ){ print STDERR "$0 : call to ".'select_datums_from_db_time_ascending()'." has failed for database '$dbname'.\n"; exit(1) }
my $numobjs = scalar @$objs;
if( $numobjs == 0 ){ print STDERR pp($search_conditions)."\n\n$0 : nothing in database '".$dbname."' for the above conditions.\n"; exit(0) }

my $datums_in_db = $covid->db_count_datums();
if( $datums_in_db < 0 ){ print STDERR "$0 : failed to get the row count of Datum records from the database.\n"; exit(1) }
$covid = undef; # disconnect it

my %correspondences = (
	'Cabo Verde' => 'Cape Verde',
	'West Bank and Gaza' => 'Gaza Strip',
	'Palestine' => 'Gaza Strip',
	'Palestine, State of' => 'Gaza Strip',
	'occupied Palestinian territory' => 'Gaza Strip',
	'The Gambia' => 'Gambia',
	'The Bahamas' => undef, # those with undef will be skiiped
	'Bahamas, The' => undef, # those with undef will be skiiped
	'Taiwan' => 'Taiwan Province of China',
	'Taiwan*' => 'Taiwan Province of China',
	'Timor Leste' => 'East Timor',
	'Timor-Leste' => 'East Timor',
	'South Sudan' => 'Sudan',
	'Republic of Moldova' => 'Moldova',
	'Republic of Ireland' => 'Ireland',
	'North Macedonia' => 'Macedonia',
	'Czechia' => 'Czech Republic',
	'Congo (Kinshasa)' => 'Congo, Democratic Republic of the',
	'Congo (Brazzaville)' => 'Congo, Democratic Republic of the',
	'Diamond Princess' => [43,-61],
	'Grand Princess' => [43.1,-61.1],
	'Curacao' => [12.169570, -68.990021],
	'Kosovo' => [42.667542, 21.166191],
	'North Ireland' => [54.607868, -5.926437],
	'Saint Barthelemy' => [17.9139,  -62.8339],
	'MS Zaandam' => [18.9139,  -62.1339],
	'Saint Martin' => [18.073099, -63.082199],
	'St. Martin' => [18.073099, -63.082199],
	'Channel Islands' => [49.372284, -2.364351],
	'Eswatini' => [-26.5179, 31.4630],
	'Tanzania, the United Republic of' => 'United Republic of Tanzania',
	'Taiwan (Province of China)' => 'Taiwan',
	'Myanmar' => [21.9139652, 95.9562225],
	'Venezuela (Bolivarian Republic of)' => [10.48801, -66.87919],
);
my ($aname, $latlong, $m, $perc);
my %totals_for_each_country;
my %totals = (
	'confirmed' => 0,
	'recovered' => 0,
	'terminal' => 0,
);
my @total_keys = keys %totals;
my (%pv, $ep, $id, $d);
# min and max update of the records
my $newest_record = $objs->[0];
my $oldest_record = $objs->[0];
my $epoch_newest_record = $objs->[0]->date_unixepoch();
my $epoch_oldest_record = $objs->[0]->date_unixepoch();
my @statnames = qw/confirmed terminal recovered/;
my $ukgeofile = File::Spec->catfile($confighash->{'uk-local-authorities-geodata'}->{'datafiles-dir'},$confighash->{'uk-local-authorities-geodata'}->{'districts-coordinates-json-file'});
my $ukgeo = Statistics::Covid::Utils::configfile2perl($ukgeofile);
if( ! defined $ukgeo ){ print STDERR "$0 : call to ".'Statistics::Covid::Utils::json2perl()'." has failed for '$ukgeofile'\n"; exit(1) }

for my $anobj (@$objs){
	$admin1 = $anobj->admin1();
	$admin0 = $anobj->admin0();
	$admin1 =~ s/^\s+|\s+$//;

	$ep = $anobj->date_unixepoch();
	if( $epoch_newest_record < $ep ){ $newest_record = $anobj; $epoch_newest_record = $ep } 
	if( $epoch_oldest_record > $ep ){ $oldest_record = $anobj; $epoch_oldest_record = $ep } 
	$totals{$_} += $anobj->get_column($_) for @total_keys;

	$latlong = undef;
	if( exists($correspondences{$admin0}) && ! defined($correspondences{$admin0}) ){
		warn "skipping this '$admin0'";
		next
	}
	if( $admin0 ne 'World' ){
		if( ! exists $totals_for_each_country{$admin0} ){ $totals_for_each_country{$admin0} = {} }
		$d = $totals_for_each_country{$admin0};
		$d->{$_} += $anobj->get_column($_) for @statnames;
		$id = $anobj->id();
		if( $admin0 eq 'United States of America' ){
			my @iditems = split(/\//, $id);
			$latlong = [$iditems[2], $iditems[3]];
		} elsif( $admin0 eq 'United Kingdom of Great Britain and Northern Ireland' ){
			if( exists $ukgeo->{$id} ){
				$latlong = [$ukgeo->{$id}->{'lat'}, $ukgeo->{$id}->{'long'}];
			} else { 
				my @iditems = split(/\//, $id);
				if( (scalar(@iditems)==4) && ($iditems[2] ne '<na>') ){
					$latlong = [$iditems[2], $iditems[3]];
				} else { warn "error, UK coordinates for '$id' not found (belongs to '$admin0', name is '$admin0')" }
			}
		} else {
			my @iditems = split(/\//, $id);
			if( (scalar(@iditems)==4) && ($iditems[2] ne '<na>') ){
				$latlong = [$iditems[2], $iditems[3]];
			} else { warn "error, ANY coordinates for '$id' not found (belongs to '$admin0', name is '$admin0')" }
		}
	} elsif( ! Geography::Countries::LatLong::supports($admin0) ){
		if( exists $correspondences{$admin0} ){
			if( ref($correspondences{$admin0}) eq 'ARRAY' ){
				$latlong = $correspondences{$admin0}
			} elsif( Geography::Countries::LatLong::supports($m=$correspondences{$admin0}) ){
				$latlong = Geography::Countries::LatLong::latlong($m);
			}
		}
	} else {
		$latlong = Geography::Countries::LatLong::latlong($admin0);
	}
	if( ! defined $latlong ){ warn "name '$admin0' is not supported in ".'Geography::Countries::LatLong' }
	$pv{$admin0} = {
		'admin0' => $admin0,
		'lat' => $latlong->[0],
		'lon' => $latlong->[1],
		'confirmed' => 0+$anobj->confirmed(),
		'terminal' => 0+$anobj->terminal(),
		'recovered' => 0+$anobj->recovered(),
		'date-updated' => $anobj->date_iso8601()
	};
}
$pv{'Metadata'} = {
	'oldest-update-name' => $oldest_record->admin0(),
	'oldest-update-time' => $oldest_record->date_iso8601(),
	'newest-update-name' => $newest_record->admin0(),
	'newest-update-time' => $newest_record->date_iso8601(),
};
$pv{'Metadata'}->{'total-'.$_} = $totals{$_} for @total_keys;

# now do some for cyprus
my $cy_specific_file = File::Spec->catfile(
	$confighash->{'fileparams'}->{'datafiles-dir'},
	'Cyprus',
	'cyprus-cases-percent.json'
);
my $cyprus_specific_pv = Statistics::Covid::Utils::configfile2perl($cy_specific_file);
if( ! defined $cyprus_specific_pv ){ die "NO CYPRUS SPECIFICS at '$cy_specific_file'" }
my $cy_data = $pv{'Cyprus'};
if( ! defined $cy_data ){ die pp(\%pv)."\nerror, Cyprus not found!" }

my $sum_confirmed = 0;
my $sum_terminal = 0;
my $sum_recovered = 0;
for my $acityhash (@$cyprus_specific_pv){
	$perc = $acityhash->{'percentage'};
	$acityhash->{'confirmed'} = int(0.5+$perc*$cy_data->{'confirmed'});
	$acityhash->{'terminal'} = int(0.5+$perc*$cy_data->{'terminal'});
	$acityhash->{'recovered'} = int(0.5+$perc*$cy_data->{'recovered'});
	delete $acityhash->{'percentage'};
	$cy_data->{'locations'}->{$acityhash->{'admin1'}} = $acityhash;
	$sum_confirmed += $acityhash->{'confirmed'};
	$sum_terminal += $acityhash->{'terminal'};
	$sum_recovered += $acityhash->{'recovered'};
}
if( $sum_terminal != $cy_data->{'terminal'} ){ warn "cyprus terminal: $sum_terminal != ".$cy_data->{'terminal'} }
if( $sum_confirmed != $cy_data->{'confirmed'} ){ warn "cyprus confirmed: $sum_confirmed != ".$cy_data->{'confirmed'} }
if( $sum_recovered != $cy_data->{'recovered'} ){ warn "cyprus recovered: $sum_recovered != ".$cy_data->{'recovered'} }

#print pp(\%pv); exit(0);

my @cypv = (
	{ map { $_ => $pv{'Cyprus'}->{$_} } grep { ! /locations/ } (keys %{$pv{'Cyprus'}}) }
);
#delete $cypv[0]->{'total'}->{'locations'};
push @cypv, values %{$pv{'Cyprus'}->{'locations'}};
#pp(\@cypv); exit(0);

my ($fh, $astr);
if( ! open($fh, '>:encoding(utf-8)', $outfile) ){ print STDERR "$0 : error, failed to open file '$outfile' for writing, $!\n"; exit(1) }
print $fh Statistics::Covid::Utils::perl2json(\@cypv);
close($fh);

print "$0 : world totals:\n".pp(\%totals)."\n";
print "$0 : world totals for regions:\n".pp(\%totals_for_each_country)."\n";
print "$0 : ".pp($pv{'Metadata'})."\n";

if( $DEBUG > 0 ){ print "$0 : selected $numobjs rows from database '$dbname' from a total of $datums_in_db.\n" }
print "$0 : output file '$outfile'.\n";
print "$0 : success, done in ".(time-$ts)." seconds.\n";

#### end

sub usage {
	return "Usage : $0 <options>\n"
	. " --config-file C : specify a configuration file which contains where to save files, where is the DB, what is its type (SQLite or MySQL), and DB connection options. The example configuration at 't/example-config.json' can be used as a quick start. Make a copy if that file and do not modify that file directly as tests may fail.\n"
	. " --outdir O : specify an outdir to prefix all file writing, this can be a directory (which must exists) or a file-prefix or both.]\n"
	. "--model M : can be 'exponential', 'polynomial=<DEGREE>' (e.g. <DEGREE>=10) or any equation in 'x' with as many coefficients and any names, see Math::Symbolic::Operator for all available expressions and operators and general syntax.]\n"
	. "[--location-name N : specify a location name either as an exact string, e.g. 'Cyprus', or as a SQL::Abstract search condition, something like: '{like=>\"%abc%\"}'.]\n"
	. "[--admin0 B : specify a string for where does the required locattion belongs to, this is optional in case names need to be clarified.]\n"
	. "[--X X : specify which field name (column, attribute) should be used for the x-axis, default is time, '$X'.]\n"
	. "[--Y Y : can be used multiple times to build an array of field names to plot against, in the y-axis.]\n"
	. "[--group-by G : can be used multiple times to specify the field names to group data by. For example: --group-by 'name' will group data accordinng to their 'name' and build as many plots and models.]\n"
	. "[--debug Level : specify a debug level, anything >0 is verbose.]\n"
	. "\nNote: --Y and --group-by have defaults. To remove one, e.g. XYZ  do --no-Y XYZ and --no-group-by XYZ\n"
	. "\nExample use:\n\n  $0 --config-file 'config/config.json' --outdir 'analysis/plots' --debug 1 --location-name \"{like=>'Ha%'}\" --no-Y 'unconfirmed' --group-by 'name' --fit-model 'exponential'\n"
	. "\nProgram by Andreas Hadjiprocopis (andreashad2\@gmail.com / bliako\@cpan.org)\n"
}
1;
__END__

=pod
# end program, below is the POD

=encoding UTF-8

=head1 NAME

script/statistics-covid-fit-model.pl - simple script to plot and fit data

=head1 VERSION

Version 0.24

=head1 DESCRIPTION

This script searches the database for specified location (or all locations)
and retrieves the matching rows. Data is then plotted and also fitted on the
user-specified choice of model.

=head1 SYNOPSIS
	script/statistics-covid-fit-model.pl \
	  --config-file 'config/config.json' \
	  --outdir 'analysis/plots' \
	  --debug 1 \
	  --location-name "{like=>'Ha%'}"

will produce the image files
C<analysis/plots/unconfirmed-over-time.png>,
C<analysis/plots/confirmed-over-time.png>,
C<analysis/plots/recovered-over-time.png>,
and C<analysis/plots/terminal-over-time.png>.

=head1 CONFIGURATION FILE

For information about the format of the configuration
file read L<Statistics::Covid>.

=head1 AUTHOR

Andreas Hadjiprocopis, C<< <bliako at cpan.org> >>, C<< <andreashad2 at gmail.com> >>

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


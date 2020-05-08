#!/usr/bin/env perl

# for more documentation use the -h flag

our $VERSION = '0.24';

use strict;
use warnings;

use Getopt::Long;
use Data::Dump qw/pp/;
use Data::Undump qw/undump/;

use Statistics::Covid::Utils;
use Statistics::Covid::Datum;
use Statistics::Covid::Analysis::Plot::Simple;
use Statistics::Covid::Analysis::Model::Simple;

# there is a:
#    require Statistics::Covid;
# further down, don't place one here

my $configfile = undef;
my $location_name = '{like => "%"}';
# undef means anything, but don't leave it empty ('') nothing will be matched
my $belongsto = undef;
my $search_conditions = {};
my $search_attributes = {};
my $time_range = undef;
my $DEBUG = 0;
my $outdir = undef;
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
	'admin1' => 0,
	'admin2' => 0,
	'admin3' => 0,
	'admin4' => 0,
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
	'max-rows=s' => sub {
		$search_attributes->{'rows'} = $_[1];
	},
	'outdir=s' => \$outdir,
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
	'group-by=s' => sub {
		if( ! exists $GroupBy->{$_[1]} ){ warn "error, unknown column name '$_[1]' for '--group-by', known columns are: '".join("','", sort keys %$GroupBy)."'"; exit(1) }
		$GroupBy->{$_[1]} = 1;
	},
	'no-group-by=s' => sub {
		if( ! exists $GroupBy->{$_[1]} ){ warn "error, unknown column name '$_[1]' for '--no-group-by', known columns are: '".join("','", sort keys %$GroupBy)."'"; exit(1) }
		$GroupBy->{$_[1]} = 0;
	},
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

$GroupBy = [grep { $GroupBy->{$_} == 1 } sort keys %$GroupBy];
$Y = [sort keys %$Y];

die usage() . "\n\nAn output basename (--outdir) is required." unless defined $outdir;
die usage() . "\n\nGroup-by column names (--group-by) do not exist." if scalar(@$GroupBy)==0;
die usage() . "\n\nColumn names for the role of the 'Y' variable (--Y) do not exist." if scalar(@$Y)==0;
die usage() . "\n\nAt least one model to fit (--fit-model) must be specified." unless defined $fitmodels;

##### end of parsing cmd line params

my $ts = time;

print "attributes are:\n".pp($search_attributes)."\n";
print "conditions are:\n".pp($search_conditions)."\n";

# the reason is that loading this module will create schemas etc
# which is a bit of a heavy work just to exit because we do not have a config file
# so load the module after all checks OK.
require Statistics::Covid;

$Statistics::Covid::Analysis::Plot::Simple::DEBUG = $DEBUG;
$Statistics::Covid::Analysis::Model::Simple::DEBUG = $DEBUG;

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
  $covid->select_datums_from_db_time_ascending({
	'conditions' => $search_conditions,
	'attributes' => $search_attributes,
  });
if( ! defined($objs) ){ print STDERR "$0 : call to ".'select_datums_from_db_time_ascending()'." has failed for database '$dbname'.\n"; exit(1) }
my $numobjs = scalar @$objs;
if( $numobjs == 0 ){ print STDERR pp($search_conditions)."\n\n$0 : nothing in database '".$dbname."' for the above conditions.\n"; exit(0) }

my $datums_in_db = $covid->db_count_datums();
if( $datums_in_db < 0 ){ print STDERR "$0 : failed to get the row count of Datum records from the database.\n"; exit(1) }
$covid = undef; # disconnect it

if( $DEBUG > 0 ){ print "$0 : selected $numobjs rows from database '$dbname' from a total of $datums_in_db.\n" }

# convert datum objects to a dataframe
my $df = Statistics::Covid::Utils::datums2dataframe({
	'datum-objs' => $objs,
	'groupby' => $GroupBy,
	'content' => [$X, @$Y],
});
if( ! defined $df ){ print STDERR "$0 : call to ".'Statistics::Covid::Utils::datums2dataframe()'." has failed.\n"; exit(1) }

my $REGEX_FOR_DF_SEP = qr/\Q${Statistics::Covid::Utils::DATAFRAME_KEY_SEPARATOR}\E/;

# make a copy of 'datetimeUnixEpoch' data and convert it
# to hours, the oldest will be hour 0
# this is because fitting with X at 1585682763 may give us problems (it shouldn't
# but ...)

for(sort keys %$df){
	my @copy = @{$df->{$_}->{'datetimeUnixEpoch'}->{'data'}};
	Statistics::Covid::Utils::discretise_increasing_sequence_of_seconds(
		\@copy, # in-place modification
		3600 # seconds->hours
	);
	$df->{$_}->{'datetimeHoursSinceOldest'} = {'data' => \@copy};
}

# now fit
my $modelsdir = File::Spec->catdir($outdir, 'models');
if( ! -d $modelsdir ){ if( ! Statistics::Covid::Utils::make_path($modelsdir) ){ print STDERR "$0 : failed to create output dir '$outdir'."; exit(1) } }
my ($k, $kk, $afitmodel, $v, $actualv, $t, $timepoints, $actualdata, $i, $N, $model);
for my $fitmodel_name (sort keys %$fitmodels){
	$afitmodel = $fitmodels->{$fitmodel_name};
	my $fitparams = {
		'dataframe' => $df,
		'X' => 'datetimeHoursSinceOldest',
		%$afitmodel
	};
	for my $aY (@$Y){
		if( $DEBUG > 0 ){ print "$0 : over all data: fitting ${fitmodel_name} model of 'datetimeUnixEpoch' against '$aY' ...\n" }

		$fitparams->{'Y'} = $aY;
		my $ret = Statistics::Covid::Analysis::Model::Simple::fit($fitparams);
		if( ! defined $ret ){ print STDERR "$0 : call to ".'Statistics::Covid::Analysis::Plot::Simple::plot()'." has failed.\n"; exit(1) }
		my @model_keys = sort keys %$ret;
		for $k (@model_keys){ # e.g. k = 'Islington'
			$model = $ret->{$k};
			if( ! defined $model ){
				print STDERR "$0 : failed to fit model for '$k', that's OK that happens.\n";
				next
			}
			# replace the separator (see datums2dataframe() in Statistics/Covid/Utils.pm)
			# with something acceptable by the filesystem
			$kk = $k; $kk =~ s/${REGEX_FOR_DF_SEP}/-/g;
			my $outfile = File::Spec->catfile($modelsdir, $kk.'-'.$aY.'-over-time.'.$fitmodel_name.'.txt');
			# and write to file
			if( ! $model->toFile($outfile) ){
				print STDERR "$0 : failed to save model (of '$k') to file '$outfile' : ".$ret->toString()."\n";
				exit(1)
			}
			if( $DEBUG > 0 ){ print "$0 : $k : saved model of '$X' against '$aY' to '$outfile'.\n" }
			# now add it to the df by evaluating the fitted model on each timepoint
			# but do not exceed the actual data (Y)
			my @outv;
			my $mean = 0;
			$actualdata = $df->{$k}->{$aY}->{'data'};
			$timepoints = $df->{$k}->{'datetimeHoursSinceOldest'}->{'data'};
			$N = scalar @$timepoints;
			for($i=0;$i<$N;$i++){
				$t = $timepoints->[$i];
				$actualv = $actualdata->[$i];
				$v = $model->evaluate($t);
				if( $v > 1E06 ){ # a prediction for over a million? well...
					warn "warning, this model did not do very well and will be removed";
					delete $ret->{$k};
					$mean = -1;
					last
				} elsif( $v < 0 ){ $v = 0 } # negative prediction (not with exp but others can)
				elsif( $v > $actualv*1.2 ){ $v = $actualv } # clip it to max y
				$mean += $v;
				push @outv, $v;
			}
			if( $mean > 0 ){
				# with this, plot below will plot it too!
				$df->{$k}->{$aY}->{'fitted-'.$fitmodel_name} = \@outv;
			}
		}
	}
}

# plot each Y with the time column as X
# this will plot keys 'data' as well as 'fitted' placed by the fitter above
my $plotsdir = File::Spec->catdir($outdir, 'plots');
if( ! -d $plotsdir ){ if( ! Statistics::Covid::Utils::make_path($plotsdir) ){ print STDERR "$0 : failed to create output dir '$outdir'."; exit(1) } }
my $plotparams = {
	'dataframe' => $df,
	'GroupBy' => $GroupBy,
	%{$confighash->{'analysis'}->{'plot'}} # can't be bother to check if it exists or not
};
my $plotparams2 = {
	%{$confighash->{'analysis'}->{'plot'}} # can't be bother to check if it exists or not
};
for my $aY (@$Y){
	# overall plots for all locations selected from db
	my $outfile = File::Spec->catfile($plotsdir, $aY.'-over-time.png');
	$plotparams->{'Y'} = $aY;
	$plotparams->{'outfile'} = $outfile;
	my $ret = Statistics::Covid::Analysis::Plot::Simple::plot($plotparams);
	if( ! defined $ret ){ print STDERR "$0 : call to ".'Statistics::Covid::Analysis::Plot::Simple::plot()'." has failed.\n"; exit(1) }
	if( $DEBUG > 0 ){ print "$0 : saved plot of '$X' against '$aY' to '$outfile'.\n" }

	# now do individual plots for each location
	$plotparams2->{'Y'} = $aY;
	for my $k (keys %$df){
		my %newdf = ($k => $df->{$k});
		# replace the separator (see datums2dataframe() in Statistics/Covid/Utils.pm)
		# with something acceptable by the filesystem
		$kk = $k; $kk =~ s/${REGEX_FOR_DF_SEP}/-/g;
		$outfile = File::Spec->catfile($plotsdir, $kk.'-'.$aY.'-over-time.png');
		$plotparams2->{'dataframe'} = \%newdf;
		$plotparams2->{'outfile'} = $outfile;
		my $ret = Statistics::Covid::Analysis::Plot::Simple::plot($plotparams2);
		if( ! defined $ret ){ print STDERR "$0 : $k : call to ".'Statistics::Covid::Analysis::Plot::Simple::plot()'." has failed.\n"; exit(1) }
		if( $ret eq '' ){ 
			if( $DEBUG > 1 ){ print pp($df->{$k}) }
			print STDERR "$0 : $k : nothing plotted.\n";
			next
		}
		if( $DEBUG > 0 ){ print "$0 : $k : saved plot of '$X' against '$aY' to '$outfile'.\n" }
	}
}


print "  total rows in database : $datums_in_db.\n";
print "$0 : success, done in ".(time-$ts)." seconds.\n";

#### end

sub usage {
	return "Usage : $0 <options>\n"
	. " --config-file C : specify a configuration file which contains where to save files, where is the DB, what is its type (SQLite or MySQL), and DB connection options. The example configuration at 't/example-config.json' can be used as a quick start. Make a copy if that file and do not modify that file directly as tests may fail.\n"
	. " --outdir O : specify an outdir to prefix all file writing, this can be a directory (which must exists) or a file-prefix or both.]\n"
	. "--model M : can be 'exponential', 'polynomial=<DEGREE>' (e.g. <DEGREE>=10) or any equation in 'x' with as many coefficients and any names, see Math::Symbolic::Operator for all available expressions and operators and general syntax.]\n"
	. "[--location-name N : specify a location name either as an exact string, e.g. 'Cyprus', or as a SQL::Abstract search condition, something like: '{like=>\"%abc%\"}'.]\n"
	. "[--belongsto B : specify a string for where does the required locattion belongs to, this is optional in case names need to be clarified.]\n"
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


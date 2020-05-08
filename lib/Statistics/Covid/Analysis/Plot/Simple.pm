package Statistics::Covid::Analysis::Plot::Simple;

use 5.10.0;
use strict;
use warnings;

use Statistics::Covid::Datum;
use Statistics::Covid::Utils;

# this takes ages to load!
use Chart::Clicker;
use Chart::Clicker::Axis::DateTime;
use Chart::Clicker::Data::DataSet;
use Chart::Clicker::Data::Series;
use Chart::Clicker::Decoration::Annotation;
use Chart::Clicker::Data::Range;
use Chart::Clicker::Drawing::ColorAllocator;

use Data::Dump qw/pp/;

our $VERSION = '0.24';

our $DEBUG = 0;

sub	plot {
	my $params = $_[0];

	# an array of column names to be used for grouping the data
	my $GroupBy = defined($params->{'GroupBy'})
		? $params->{'GroupBy'} : ['name'];

	my $debug = exists($params->{'debug'}) && defined($params->{'debug'})
		? $params->{'debug'} : $DEBUG;

	# and then for all that data groupped, plot just a single variable, the Y
	my $Y = exists($params->{'Y'}) && defined($params->{'Y'})
		? $params->{'Y'} : 'confirmed';

	# optional X, default is time (e.g. datetimeUnixEpoch)
	my $X = exists($params->{'X'}) && defined($params->{'X'})
		? $params->{'X'} : 'datetimeUnixEpoch';

	my $Xstr;
	if( $X eq 'datetimeUnixEpoch' ){ $Xstr = 'time' } else { $Xstr = $X }
	# optional title, default is nothing
	my $title = exists($params->{'title'}) && defined($params->{'title'})
		? $params->{'title'} : "$Xstr vs $Y";

	# optional with-legend? for plots with lots of groups it takes over the display!
	my $with_legend = exists($params->{'with-legend'}) && defined($params->{'with-legend'})
		? $params->{'with-legend'} : 1;

	# optional width and height with defaults
	my $width = exists($params->{'width'}) && defined($params->{'width'})
		? $params->{'width'} : 1024;
	# optional X, default is time (e.g. datetimeUnixEpoch)
	my $height = exists($params->{'height'}) && defined($params->{'height'})
		? $params->{'height'} : 768;
	# optional, labels avoidance factors
	my $labels_avoid_margins_factor = exists($params->{'labels-avoid-margins-factor'}) && defined($params->{'labels-avoid-margins-factor'})
		? $params->{'labels-avoid-margins-factor'} : 30/100;
	my $labels_avoid_other_labels_factor = exists($params->{'labels-avoid-other-labels-factor'}) && defined($params->{'labels-avoid-other-labels-factor'})
		? $params->{'labels-avoid-other-labels-factor'} : 30;

	# optionally specify a minimum number of data points before plotting
	my $min_points = exists($params->{'min-points'}) && defined($params->{'min-points'})
		? $params->{'min-points'} : 1
	;

	# optionally specify date-formatting for X-axis (expecting X to be seconds since unix epoch)
	my $dateformatX = undef;
	if( exists($params->{'date-format-x'}) && defined($params->{'date-format-x'}) ){
		if( (ref($params->{'date-format-x'}) eq 'HASH') && exists($params->{'date-format-x'}->{'format'}) ){
			$dateformatX = $params->{'date-format-x'}
		} else { warn "error, 'date-format-x' must be a hashref and contain at least the 'format' key, see L<Chart::Clicker::Axis::DateTime> and L<Chart::Clicker::Axis> for the spec. 'date-format-x' was not recognised: ".pp($params->{'date-format-x'}); return undef }
	} elsif( $X eq 'datetimeUnixEpoch' ){
		# set default params for Chart::Clicker::Axis::DateTime
		$dateformatX = {
			format => '%d/%m(%Hhr)',
			position => 'bottom',
			orientation => 'horizontal'
		}
	}

	my $outfile;
	if( ! exists($params->{'outfile'}) || ! defined($outfile=$params->{'outfile'}) ){ warn "error, no output file specified (via '$outfile')."; return undef }

	my $df = undef;
	if( exists($params->{'datum-objs'}) && defined($params->{'datum-objs'}) ){
		warn "datum-objs no longer supported, add a dataframe instead ('dataframe'), see Statistics::Covid for how to do this.";
		return undef
	} elsif( exists($params->{'dataframe'}) && defined($params->{'dataframe'}) ){
		$df = $params->{'dataframe'};
	}
	if( ! defined $df ){ warn "error, no data specified (via 'dataframe')."; return undef }

	# automatically give us colors, thank you
	my $ColorPicker = Chart::Clicker::Drawing::ColorAllocator->new({seed_hue => 0});
	# this is where we save the colors we automatically get
	# the complication is that some plots must be with the same color
	# because they belong the same group.
	my $ColorAllocator = Chart::Clicker::Drawing::ColorAllocator->new();
	$ColorAllocator->clear_colors();

	# X will be only in 'data'
	my (@series, @series_labels, $dfkX, $dfkXdata, $good, $N,
	    $dfkY, $dfkYdata, $i, $x, $y, $Xmin, $Ymin, $Ymax, $label_str,
	    $arange, $Ysens, $Xsens, $badX, $badY, $acolor, $aseries
	);
	my $LW = $width * $labels_avoid_margins_factor; my $LH = $height * $labels_avoid_margins_factor;
	# the minus is to account for text width and height
	my $UW = ($width-30) * (1-$labels_avoid_margins_factor); my $UH = ($height-5) * (1-$labels_avoid_margins_factor);
	for my $k (sort keys %$df){ # the group-name (e.g. country name)
		# pick a color for all the plots of that key
		$acolor = $ColorPicker->next(); if( ! defined $acolor ){ $ColorPicker->reset(); $acolor = $ColorPicker->next() }
		$dfkY = $df->{$k}->{$Y};
		$dfkX = $df->{$k}->{$X};
		$dfkXdata = $dfkX->{'data'};
		$N = scalar @$dfkXdata;
		if( $N < $min_points ){
			warn "$k :  warning, number of data rows ($N) is less than the minimum number specified ($min_points) and will skip plotting this scenario";
			next
		}
		$Xmin = $dfkXdata->[0];
		# range of the x-axis
		$Xsens = ($dfkXdata->[$N-1] - $dfkXdata->[0]) / $width;
		#print "$k: keys: ".join(",", keys %$dfkY)."\nDoing group '$k' with $N time points and ".scalar(@{$dfkY->{'data'}})." and ".scalar(@{$dfkY->{'fitted-exponential-fit'}})."\n";
		for my $kk (sort keys %$dfkY){ # the entry, e.g. data or 'fitted-*'
			# we have asked to have x-axis as time and y-axis as $Y (y is user specified)
			$dfkYdata = $dfkY->{$kk};
			#print "Doing group '$k' with $N time points which has kk=$kk ".scalar(@$dfkYdata)."\n";
			die "counts for X($N) and Y(".scalar(@$dfkYdata).") data differ for '$k/$kk'"
				unless $N==scalar(@$dfkYdata)
			;
			eval {
				$aseries = Chart::Clicker::Data::Series->new(
					keys   => $dfkXdata,
					values => $dfkYdata,
					name   => $k
				);
			};
			if( $@ || ! defined $aseries ){ warn "Xdata:\n".pp($dfkXdata)."\nYdata:\n".pp($dfkYdata)."\nerror, call to ".'Chart::Clicker::Data::Series->new()'." has failed for dataframe entry '$k' (see above content)".(defined($@)?': '.$@:".")."\n";return undef }

			$arange = $aseries->range();
			$Ymin = $arange->lower();
			$Ymax = $arange->upper();
			$Ysens = ($Ymax-$Ymin) / $height; 

			# no variation but we needed to calculate the series to reach at this point
			if( $Xsens < 1E-12 ){ 
				warn "$k/$kk : no variation along X ($X).";
				next
			}
			if( $Ysens < 1E-12 ){ 
				warn "$k/$kk : no variation along Y ($Y).";
				next
			}
			# data will be plotted when pushed in here:
			push @series, $aseries;
			$ColorAllocator->add_to_colors($acolor);
			$acolor = Statistics::Covid::Utils::make_lighter_color_rgb($acolor, 0.33);

			# here we add a label to the curve.
			# The problem is to find a place not to overlap other labels
			# this is very basic and very buggy:
			# major TODO!
			# skip labels for N<2
			if( $N < 2 ){ $good = 0; goto GOOD } else { $good = scalar(@series_labels)==0 }

			#if( $kk ne 'data' ){ next } # put only labels for curves of 'data'

			PICK:
			for($i=$N;$i-->0;){
				$x = $dfkXdata->[$i]; $y = $dfkYdata->[$i];
				$badX = ($x-$Xmin)/$Xsens; $badY = ($y-$Ymin)/$Ysens;
				if( $debug > 2 ){ warn "PICK labels: x=$x, y=$y, badX=$badX, badY=$badY, checking if $badX < $LW or $badY < $LH or $badX > $UW or $badY > $UH" }
				if(  ($badX < $LW)
				  || ($badY < $LH)
				){ next }
				if(  ($badX > $UW)
				  || ($badY > $UH)
				){ next }
				for my $alabel (@series_labels){
					if( (abs($alabel->{x}-$x)>$labels_avoid_other_labels_factor*$Xsens)
					 && (abs($alabel->{y}-$y)>$labels_avoid_other_labels_factor*$Ysens)
					){
						if( $debug > 2 ){ warn "FOUND a good placement for labels: x=$x, y=$y, badX=$badX, badY=$badY, checking if $badX < $LW or $badY < $LH or $badX > $UW or $badY > $UH" }
						$good=1;
						last PICK
					}
				}
				if( $good ){ last PICK }
			}
			GOOD:
			if( $good == 0 ){
				$i = int(rand($N));
				$x = $dfkXdata->[$i]; $y = $dfkYdata->[$i];
				if($N>1){ warn "warning, failed to find space for label for '$k/$kk' and goes to ($x,$y). That's OK that happens." }
				if( $debug > 2 ){ warn "$k/$kk : all tests for label constraints failed, placing one at random at ($x,$y)" }
			} else { if( $debug > 2 ){ warn "$k/$kk : picked labels OK" } }

			if( $kk =~ /^fitted\-(.{3})/ ){
				$label_str = $k.'-'.$1
			} else { $label_str = $k }
			$label_str =~ s/\Q${Statistics::Covid::Utils::DATAFRAME_KEY_SEPARATOR}\E+//g;
			push @series_labels, {
				'x' => $x,
				'y' => $y,
				'k' => $k,
				'kk' => $kk,
				't' => $label_str #$k, #$k.'/'.$kk
			};
			if( $debug > 2 ){ warn "$k/$kk : placed the label at ($x,$y)" }
		}
	}
	if( scalar(@series) == 0 ){
		warn pp($df)."\nwarning, nothing to plot for above dataframe!";
		return ''
	}

	my $dataset = Chart::Clicker::Data::DataSet->new(series => \@series);

	if( ! defined $dataset ){ warn "error, call to ".' Chart::Clicker::Data::DataSet->new()'." has failed.\n"; return undef }

	my $clicker = Chart::Clicker->new(width => $width, height => $height);
	if( ! defined $clicker ){ warn "error, call to ".' Chart::Clicker->new()'." has failed.\n"; return undef }
	$clicker->title->text($title) if $title;
	$clicker->legend->visible($with_legend);
	$clicker->add_to_datasets($dataset);
	$clicker->color_allocator($ColorAllocator);

	my $context = $clicker->get_context('default');
	if( ! defined $context ){ warn "error, call to get_context() has failed."; return undef }

	# X-axis setup:
	if( $dateformatX ){
		$context->domain_axis(Chart::Clicker::Axis::DateTime->new($dateformatX))
	} else {
		$context->domain_axis->format('%.0f')
	}
	#$context->domain_axis->hidden(1);
	#$context->domain_axis->ticks(scalar @{$df->{$_}->{$Y}->{'data'}});

	# Y-axis setup (range-axis: that's the y-axis for you and me)
	$context->range_axis->format('%.0f');

	# draw the points with this circle
	$context->renderer->shape(
		Geometry::Primitive::Circle->new({
			radius => 3,
		})
	);
	$context->renderer->shape_brush(
		Graphics::Primitive::Brush->new(
			width => 2,
			color => Graphics::Color::RGB->new(red => 1, green => 1, blue => 1)
		)
	);
	$context->renderer->brush->width(2);

	# put a label for this set of plots, question is where?
	for (@series_labels){
		# TODO remove this when tested hard
		my $rc = eval {
			$clicker->add_to_over_decorations(
			  Chart::Clicker::Decoration::Annotation->new(
				key => $_->{x},
				value => $_->{y},
				text => $_->{t},
				context => 'default',
			  )
			);
			1;
		};
		if( !$rc ){ die "error, call to ".'Chart::Clicker::Decoration::Annotation->new()'." has failed for this label:\n".pp($_) }
	}

	# and plot to file, trapping exceptions (i think it throws exceptions? return value didn't say anything):
	my $rc = eval { $clicker->write_output($outfile); 1 };
	if( $@ || ! defined($rc) ){
		# test fails here and don't know why
		warn "dataframe for X=$X:\n".pp($df);
		warn "dateformatX for X=$X:\n".pp($dateformatX);
		warn "driver is ".$clicker->driver."\n";
		warn "driver size is w=".$clicker->driver->width.", h=".$clicker->driver->height."\n";
		warn "error, call to write_output() has failed (exception caught: '".(defined($@)?$@:'<na>')."') for output file '$outfile'.\n";
		return undef
	}
	return $outfile # success, return the output image file
}
1;
__END__
# end program, below is the POD
=pod

=encoding UTF-8

=head1 NAME

Statistics::Covid::Analysis::Plot::Simple - Plots data

=head1 VERSION

Version 0.24

=head1 DESCRIPTION

This package contains routine(s) for plotting a number of
L<Statistics::Covid::Datum> objects using L<Chart::Clicker>.

=head1 SYNOPSIS

	use Statistics::Covid;
	use Statistics::Covid::Datum;
	use Statistics::Covid::Utils;
	use Statistics::Covid::Analysis::Plot::Simple;
	
	# read data from db
	$covid = Statistics::Covid->new({   
		'config-file' => 't/config-for-t.json',
		'debug' => 2,
	}) or die "Statistics::Covid->new() failed";
	# retrieve data from DB for selected locations (in the UK)
	# data will come out as an array of Datum objects sorted wrt time
	# (the 'datetimeUnixEpoch' field)
	$objs = $covid->select_datums_from_db_for_specific_location_time_ascending(
		#{'like' => 'Ha%'}, # the location (wildcard)
		['Halton', 'Havering'],
		#{'like' => 'Halton'}, # the location (wildcard)
		#{'like' => 'Havering'}, # the location (wildcard)
		# the belongsto (could have been wildcarded) or undef for anything (not blank!)
		'UK',
	);
	# create a dataframe
	$df = Statistics::Covid::Utils::datums2dataframe({
		'datum-objs' => $objs,
		# collect data from all those with same 'name' and same 'belongsto'
		# and plot this data as a single curve (or fit or whatever)
		'groupby' => ['name','belongsto'],
		# put only these values of the datum object into the dataframe
		# one of them will be X, another will be Y
		# if you want to plot multiple Y, then add here more dependent columns
		# like ('unconfirmed').
		'content' => ['confirmed', 'unconfirmed', 'datetimeUnixEpoch'],
	});

	# plot time vs confirmed
	$ret = Statistics::Covid::Analysis::Plot::Simple::plot({
		'dataframe' => $df,
		# saves to this file:
		'outfile' => 'confirmed-over-time.png',
		# plot this column against X
		# (which is not present and default is time ('datetimeUnixEpoch')
		'Y' => 'confirmed',
		# width and height have sane defaults so these are optional:
		'width' => 500,
		'height' => 500,
	});

	# plot confirmed vs unconfirmed
	# if you see a vertical line it means that your data has no 'unconfirmed'
	$ret = Statistics::Covid::Analysis::Plot::Simple::plot({
		'dataframe' => $df,
		# saves to this file:
		'outfile' => 'confirmed-vs-unconfirmed.png',
		'X' => 'unconfirmed',
		# plot this column against X
		'Y' => 'confirmed',
	});

	# plot using an array of datum objects as they came
	# out of the DB. A dataframe is created internally to the plot()
	# but this is not recommended if you are going to make several
	# plots because equally many dataframes must be created and destroyed
	# internally instead of recycling them like we do here...
	$ret = Statistics::Covid::Analysis::Plot::Simple::plot({
		'datum-objs' => $objs,
		# saves to this file:
		'outfile' => 'confirmed-over-time.png',
		# plot this column as Y
		'Y' => 'confirmed', 
		# X is not present so default is time ('datetimeUnixEpoch')
		# and make several plots, each group must have 'name' common
		'GroupBy' => ['name', 'belongsto'],
		'date-format-x' => {
			# see Chart::Clicker::Axis::DateTime for all the options:
			format => '%m', ##<<< specify timeformat for X axis, only months
			position => 'bottom',
			orientation => 'horizontal'
		},
	});


	# This is what the dataframe looks like (fictitious data):
	#  {
	#  Halton   => {
	#		confirmed => [0, 0, 3, 4, 4, 5, 7, 7, 7, 8, 8, 8],
	#		unconfirmed => [15, 15, 17, 17, 24, 29, 40, 45, 49, 54, 57, 80],
	#		datetimeUnixEpoch => [
	#		  1584262800,
	#		  1584349200,
	#		  1584435600,
	#		  1584522000,
	#		  1584637200,
	#		  1584694800,
	#		  1584781200,
	#		  1584867600,
	#		  1584954000,
	#		  1585040400,
	#		  1585126800,
	#		  1585213200,
	#		],
	#	      },
	#  Havering => {
	#		confirmed => [5, 5, 7, 7, 14, 19, 30, 35, 39, 44, 47, 70],
	#		unconfirmed => [15, 15, 17, 17, 24, 29, 40, 45, 49, 54, 57, 80],
	#		datetimeUnixEpoch => [
	#		  1584262800,
	#		  1584349200,
	#		  1584435600,
	#		  1584522000,
	#		  1584637200,
	#		  1584694800,
	#		  1584781200,
	#		  1584867600,
	#		  1584954000,
	#		  1585040400,
	#		  1585126800,
	#		  1585213200,
	#		],
	#	      },
	#  }

=head2 plot

Plots data to specified file using L<Chart::Clicker>. The input data
is either an array of L<Statistics::Covid::Datum> objects or
a dataframe (as created by L<Statistics::Covid::Utils::datums2dataframe>
(see the SYNOPSIS for examples).
	
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

    perldoc Statistics::Covid::Analysis::Plot::Simple


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


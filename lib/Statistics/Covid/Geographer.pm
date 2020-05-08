package Statistics::Covid::Geographer;

use 5.10.0;
use strict;
use warnings;

use utf8;
use Locale::Country;
use Geography::Countries::LatLong;

our $VERSION = '0.24';

my %WorldLocations2Coordinates_additional = (
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
my $aliases = {
	# if a name matches this then the "official name"
	# (the value of the hash) will be returned
	# unless an official check matches
	qr/palestin(?:e|ian)/i => 'State of Palestine',
	qr/gaza|west[ ,]bank/i => 'State of Palestine',
	qr/(?:republic)?(?:south)?.*(?:korea)(?:south)?/i => 'South Korea',
	qr/taiwa/i => 'Taiwan',
	qr/kosovo/i => 'Kosovo',
	qr/diamond/i => 'Diamond Princess',
	qr/zaandam/i => 'MS Zaandam',
	qr/\bcruise|others\b/i => 'Cruise Ship',
	qr/china/i => 'China',
	qr/ivo(?:ry|ire)/i => 'Ivory Coast',
	qr/ca(?:bo|pe)\s+verde/i => 'Cabo Verde',
	qr/republic of ireland/i => 'Ireland',
	qr/north\s+ireland/i => 'UK',
	qr/hong/i => 'Hong Kong',
	qr/taipei/i => 'Taiwan', # just once!
	qr/macao/i => 'Macao', # just once!
	qr/channel\s+island/i => 'Channel Islands', # can't find it,is it uk?
	# for all the saints/st. see the regex below
};
my $CYLocations2Coordinates = {
	# lat, long
	'Αμμόχωστος' => [33.927441, 35.115740],
	'Λευκωσία' => [33.385040, 35.184376],
	'Λάρνακα' => [33.622635, 34.899101],
	'Λεμεσός' => [33.019181, 34.707527],
	'Πάφος' => [32.424770, 34.776484],
	'Ακρωτήρι' => [32.983425, 34.590664],
};
# returns arrayref of lat,long
sub	cylocation2coordinates {
	my $aname = $_[0];
	if( exists $CYLocations2Coordinates->{$aname} ){ return $CYLocations2Coordinates->{$aname} }
	warn "'".join("', '", sort keys %$CYLocations2Coordinates)."\nerror, cy-location name '$aname' is not known, above is what I know";
	return undef
}
sub	worldlocation2coordinates {
	my $aname = $_[0];
	if( ! Geography::Countries::LatLong::supports($aname) ){
		$aname = get_official_name($aname);
		if( ! Geography::Countries::LatLong::supports($aname) ){ 
			# check in the aliases
			if( exists $WorldLocations2Coordinates_additional{$aname} ){ return $WorldLocations2Coordinates_additional{$aname} }
			die "error, unknown country name '$aname'";
		}
	}
	return Geography::Countries::LatLong::latlong($aname);
}
sub	get_official_name {
	my $name = $_[0];

	$name =~ s/\bst\.[ \-]?/Saint /gi;
	my $n = Statistics::Covid::Geographer::_check_aliases($name);
	if( defined $n ){ $name = $n }
	my $co = Locale::Country::country2code($name);
	return $n unless defined $co;
	return Locale::Country::code2country($co)
}
sub	_check_aliases {
	my $name = $_[0];
	for(keys %$aliases){
		#print "checking $name agains $_\n";
		return $aliases->{$_} if $name =~ $_
	}
	return undef
}	
1;
__END__
# end program, below is the POD
=pod

=encoding UTF-8


=head1 NAME

Statistics::Covid::Geographer - Return the (first) official country name given an alias

=head1 VERSION

Version 0.24

=head1 DESCRIPTION

This package contains 


This module tries to expose all the fields of the Datum table in the database.
It inherits from L<Statistics::Covid::IO::DualBase>. And overwrites some subs
from it. For example the L<Statistics::Covid::Geographer::newer_than>.
It exposes all its dual table fields as setter/getter subs and also
via the generic sub L<Statistics::Covid::Geographer::get_column> (which
takes as an argument the field/column name and returns its value).

See also L<Statistics::Covid::Geographer::Table> which describes the
Datum table in a format L<DBIx::Class> understands.

=head1 AUTHOR

Andreas Hadjiprocopis, C<< <bliako at cpan.org> >>, C<< <andreashad2 at gmail.com> >>


=head1 BUGS

Please report any bugs or feature requests to C<bug-statistics-Covid at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Statistics-Covid>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Statistics::Covid::Geographer


You can also look for information at:

=over 4

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


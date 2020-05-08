package Statistics::Covid::Datum;

use 5.10.0;
use strict;
use warnings;

use parent 'Statistics::Covid::IO::DualBase';

# this is where our DB schema is specified
# edit this file to reflect your table design as well as your $self variables
use Statistics::Covid::Datum::Table;

use DateTime;

use Data::Dump qw/pp/;

our $VERSION = '0.23';

# our constructor which calls parent constructor first and then does
# things specific to us, like dates
# create a Data item, either by supplying parameters as a hashref
# of name=>value or as an array which must have as many elements
# as the 'db-columns' items and in this order.
sub	new {
	my ($class, $params) = @_;
	$params = {} unless defined $params;

	my $parent = ( caller(1) )[3] || "N/A";
	my $whoami = ( caller(0) )[3];

	my $self = $class->SUPER::new($Statistics::Covid::Datum::Table::SCHEMA, $params);
	if( ! defined $self ){ warn "error, call to $class->new() has failed."; return undef }

	# add some more fields to our self
	$self->{'p'}->{'datetime-obj'} = undef;

	# if input params is a hashref,
	# date must come either as a datetime-obj or datetimeISO8601 or datetimeUnixEpoch or date
	# the 1st is a DateTime object, the last is any of the 3 and we try to find what it is
	# if input params is an arrayref, then all fields must be specified in that array
	# which means both datetimeUnixEpoch and datetimeISO8601
	# and so from these we create our DateTime Object which goes into private 'datetime-obj'

	# populate our self with the data and set to default values (before checking input params)
	my $c = $self->{'c'}; # content fields as they go to DB
	my $p = $self->{'p'}; # private fields
	# now check input params for particular data values
	if( ref($params) eq 'HASH' ){
		# this will update all date fields given just any one of them (set the priority in the if)
		if( exists $params->{'datetimeUnixEpoch'} and defined $params->{'datetimeUnixEpoch'} ){
			if( ! $self->date($params->{'datetimeUnixEpoch'}) ){ warn "error, setting the date from a unix-epoch seconds (".$params->{'datetimeUnixEpoch'}.") has failed."; return undef }
		} elsif( exists $params->{'datetimeISO8601'} and defined $params->{'datetimeISO8601'} ){
			if( ! $self->date($params->{'datetimeISO8601'}) ){ warn "error, setting the date from an ISO8601 string (".$params->{'datetimeISO8601'}.") has failed."; return undef }
		} elsif( exists $params->{'datetime-obj'} and defined $params->{'datetime-obj'} ){
			if( ! $self->date($params->{'datetime-obj'}) ){ warn "error, setting the date from a DateTime object (".$params->{'datetime-obj'}.") has failed."; return undef }
		} elsif( exists $params->{'date'} and defined $params->{'date'} ){
			if( ! $self->date($params->{'date'}) ){ warn "error, setting the date from date spec (".$params->{'date'}.") has failed."; return undef }
		} else { warn "error, no 'date', 'datetime-obj', 'datetimeISO8601' or 'datetimeUnixEpoch' was specified, one must be specified (ISO8601, unix-epoch-seconds or DateTime object are all accepted)."; return undef }
	} elsif( ref($params) eq 'ARRAY' ){
		die pp($params)."\nthis needs more work, the array is above.";
		# this will update all date fields given just any one of them
#		if( exists $c->{'datetimeUnixEpoch'} and defined $c->{'datetimeUnixEpoch'} ){
#			if( ! $self->date($c->{'datetimeUnixEpoch'}) ){ warn "error, setting the date from a unix-epoch seconds (".$c->{'datetimeUnixEpoch'}.") has failed."; return undef }
#		} elsif( exists $c->{'datetimeISO8601'} and defined $c->{'datetimeISO8601'} ){
#			if( ! $self->date($c->{'datetimeISO8601'}) ){ warn "error, setting the date from a unix-epoch seconds (".$c->{'datetimeISO8601'}.") has failed."; return undef }
#		} elsif( exists $p->{'datetime-obj'} and defined $p->{'datetime-obj'} ){
#			if( ! $self->date($p->{'datetime-obj'}) ){ warn "error, setting the date from a unix-epoch seconds (".$p->{'datetime-obj'}.") has failed."; return undef }
#		} else { warn "error, something seriously wrong with the input array specified, datetimeUnixEpoch was undefined.\n"; return undef }
	} else { warn "parameter can be a hashref or an arrayref with values"; return undef }

	# and done
	return $self
}
# get or set the date this was created
# it accepts a DateTime object or an ISO8601 string or a unix-epoch seconds
# returns the datetime object (created) on success or undef on failure
sub	date {
	my $self = $_[0];
	my $m = $_[1];
	return $self->{'p'}->{'datetime-obj'} unless defined $m;
	if( ref($m) eq '' ){
		if( $m =~ /[\:\-]/ ){
			# it's an ISO8601 string
			if( ! defined($self->{'p'}->{'datetime-obj'} = Statistics::Covid::Utils::iso8601_to_DateTime($m)) ){ warn "error, call to ".'Statistics::Covid::Utils::iso8601_to_DateTime()'." has failed."; return undef }
		} else {
			# it's a unix-epoch seconds, notice default timezone
			if( ! defined($self->{'p'}->{'datetime-obj'} = Statistics::Covid::Utils::epoch_seconds_to_DateTime($m)) ){ warn "error, call to ".'Statistics::Covid::Utils::epoch_seconds_to_DateTime()'." has failed."; return undef }
		}
	} elsif( ref($m) eq 'DateTime' ){
		$self->{'p'}->{'datetime-obj'} = $m
	} else { warn "understand only iso8601 date string or unix-epoch seconds (as an integer) or a DateTime object"; return undef }
	# set the other two
	$self->{'c'}->{'datetimeISO8601'} = $self->{'p'}->{'datetime-obj'}->iso8601();
	$self->{'c'}->{'datetimeUnixEpoch'} = $self->{'p'}->{'datetime-obj'}->epoch();
	return $self->{'p'}->{'datetime-obj'}
}
# compares 2 objs and returns the "newer"
# which means the one with more up-to-date markers in our case
# as follows:
# returns 1 if self is bigger than input (and probably more up-to-date)
# returns 0 if self is same as input
# returns -1 if input is bigger than self
# we compare only markers, we don't care about any other fields
# note that self is Statistics::Covid::Datum
# and another can be:
#    Statistics::Covid::Schema::Result::Datum
# or
#    Statistics::Covid::Datum
# if you want to get the name of a column for which there is
# no getter, use
# Statistics::Covid::Datum::get_column('terminal')
# and
# Statistics::Covid::Schema::Result::Datum::get_column('terminal')
sub	newer_than {
	my $self = $_[0];
	my $inputObj = $_[1];
	my ($S, $I);

	if( ($S=$self->get_column('datetimeUnixEpoch')) > ($I=$inputObj->get_column('datetimeUnixEpoch')) ){ return 1 }
	elsif( $S < $I ){ return -1 }
	if( ($S=$self->get_column('terminal')) > ($I=$inputObj->get_column('terminal')) ){ return 1 }
	elsif( $S < $I ){ return -1 }
	# terminals are the same, go to next marker
	if( ($S=$self->get_column('confirmed')) > ($I=$inputObj->get_column('confirmed')) ){ return 1 }
	elsif( $S < $I ){ return -1 }
	# confirmed are the same, go to next marker
	if( ($S=$self->get_column('recovered')) > ($I=$inputObj->get_column('recovered')) ){ return 1 }
	elsif( $S < $I ){ return -1 }
	# recovered are the same, go to next marker
	if( ($S=$self->get_column('unconfirmed')) > ($I=$inputObj->get_column('unconfirmed')) ){ return 1 }
	elsif( $S < $I ){ return -1 }
	# recovered are the same, we have nothing else, they are identical
	return 0 # identical
}
# compares this object with another and returns 0 if different or 1 if the same
sub	equals {
	my $self = $_[0];
	my $another = $_[1];
	my $res;
	my $c = $self->{'c'};
	my $C = $another->{'c'};
	for (@{$self->column_names()}){
		#print "comparing '$_': ".$c->{$_}." and ".$C->{$_}."\n";
		if( ($c->{$_} cmp $C->{$_}) != 0 ){ return 0 }
	}
	return 1 # equal!
}
sub	id {
	my $self = $_[0];
	my $m = $_[1];
	return $self->{'c'}->{'id'} unless defined $m;
	$self->{'c'}->{'id'} = $m;
	return $m;
}
sub	admin0 {
	my $self = $_[0];
	my $m = $_[1];
	return $self->{'c'}->{'admin0'} unless defined $m;
	$self->{'c'}->{'admin0'} = $m;
	return $m;
}
sub	admin1 {
	my $self = $_[0];
	my $m = $_[1];
	return $self->{'c'}->{'admin1'} unless defined $m;
	$self->{'c'}->{'admin1'} = $m;
	return $m;
}
sub	admin2 {
	my $self = $_[0];
	my $m = $_[1];
	return $self->{'c'}->{'admin2'} unless defined $m;
	$self->{'c'}->{'admin2'} = $m;
	return $m;
}
sub	admin3 {
	my $self = $_[0];
	my $m = $_[1];
	return $self->{'c'}->{'admin3'} unless defined $m;
	$self->{'c'}->{'admin3'} = $m;
	return $m;
}
sub	admin4 {
	my $self = $_[0];
	my $m = $_[1];
	return $self->{'c'}->{'admin4'} unless defined $m;
	$self->{'c'}->{'admin4'} = $m;
	return $m;
}
# shortcuts to admin/name:
sub	country { return $_[0]->admin0($_[1]) }
sub	type {
	my $self = $_[0];
	my $m = $_[1];
	return $self->{'c'}->{'type'} unless defined $m;
	$self->{'c'}->{'type'} = $m;
	return $m;
}
sub	date_iso8601 { return $_[0]->{'c'}->{'datetimeISO8601'} }
sub	date_unixepoch { return $_[0]->{'c'}->{'datetimeUnixEpoch'} }
sub	datasource {
	my $self = $_[0];
	my $m = $_[1];
	return $self->{'c'}->{'datasource'} unless defined $m;
	$self->{'c'}->{'datasource'} = $m;
	return $m;
}
sub	unconfirmed {
	my $self = $_[0];
	my $m = $_[1];
	return $self->{'c'}->{'unconfirmed'} unless defined $m;
	$self->{'c'}->{'unconfirmed'} = $m;
	return $m;
}
sub	confirmed {
	my $self = $_[0];
	my $m = $_[1];
	return $self->{'c'}->{'confirmed'} unless defined $m;
	$self->{'c'}->{'confirmed'} = $m;
	return $m;
}
sub	recovered {
	my $self = $_[0];
	my $m = $_[1];
	return $self->{'c'}->{'recovered'} unless defined $m;
	$self->{'c'}->{'recovered'} = $m;
	return $m;
}
sub	terminal {
	my $self = $_[0];
	my $m = $_[1];
	return $self->{'c'}->{'terminal'} unless defined $m;
	$self->{'c'}->{'terminal'} = $m;
	return $m;
}
# use it like Statistics::Covid::Datum->make_random_object(optional-seed)
sub	make_random_object {
	my $class = $_[0];
	srand $_[1] if defined $_[1];

	my $datum_params = {
	'id' => "E".sprintf("%07d", int(rand(1000000))),
	'admin0' => join('', map { chr(ord('a')+int(rand(ord('z')-ord('a')))) } (1..10)),
	'admin1' => join('', map { chr(ord('a')+int(rand(ord('z')-ord('a')))) } (1..10)),
	'admin2' => join('', map { chr(ord('a')+int(rand(ord('z')-ord('a')))) } (1..10)),
	'admin3' => join('', map { chr(ord('a')+int(rand(ord('z')-ord('a')))) } (1..10)),
	'admin4' => join('', map { chr(ord('a')+int(rand(ord('z')-ord('a')))) } (1..10)),
	'type' => 'english local authority',
	'confirmed' => 10 + int(rand(10000)),
	'unconfirmed' => 10 + int(rand(100)),
	'terminal' => 0 + int(rand(100)),
	'recovered' => 5 + int(rand(100)),
	'datasource' => 'BBC',
	'datetimeISO8601' => DateTime->now()->iso8601().'Z'
	};
	my $obj = __PACKAGE__->new($datum_params);
	if( ! defined $obj ){ warn "error, call to ".'Statistics::Covid::Datum->new()'." has failed."; return undef }
	return $obj
}
sub	toString {
	my $self = $_[0];
	return '['
		.$self->admin0().'/'.$self->admin1()
		.' (id:'
			.$self->id()
			.'@'
			.'<'.$self->date_iso8601().'>'
			.' from '
			."'".$self->datasource()."'"
		.', '
		.'c:'.$self->confirmed()
		.'|'
		.'t:'.$self->terminal()
		.'|'
		.'r:'.$self->recovered()
	. ']'
}
1;
__END__
# end program, below is the POD
=pod

=encoding UTF-8


=head1 NAME

Statistics::Covid::Datum - Class dual to the 'Datum' table in DB - it contains data for one time and space point.

=head1 VERSION

Version 0.23

=head1 DESCRIPTION

This module tries to expose all the fields of the Datum table in the database.
It inherits from L<Statistics::Covid::IO::DualBase>. And overwrites some subs
from it. For example the L<Statistics::Covid::Datum::newer_than>.
It exposes all its dual table fields as setter/getter subs and also
via the generic sub L<Statistics::Covid::Datum::get_column> (which
takes as an argument the field/column name and returns its value).

See also L<Statistics::Covid::Datum::Table> which describes the
Datum table in a format L<DBIx::Class> understands.

=head1 AUTHOR

Andreas Hadjiprocopis, C<< <bliako at cpan.org> >>, C<< <andreashad2 at gmail.com> >>


=head1 BUGS

Please report any bugs or feature requests to C<bug-statistics-Covid at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Statistics-Covid>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Statistics::Covid::Datum


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

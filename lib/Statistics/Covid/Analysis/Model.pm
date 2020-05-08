package Statistics::Covid::Analysis::Model;

use 5.10.0;
use strict;
use warnings;

use Statistics::Covid::Utils;

use Math::Symbolic;
use Math::Symbolic::Parser;
use Math::Symbolic::Compiler;
use Storable; # need it for dclone

use Data::Dump qw/pp/;

our $VERSION = '0.24';

sub	new {
	my ($class, $params) = @_;
	$params = {} unless defined $params;

	my $parent = ( caller(1) )[3] || "N/A";
	my $whoami = ( caller(0) )[3];

	my $self = {
		'error' => 10E+06,
		'coefficients' => undef,
		'equation-str-general' => undef, # this is like c1*x (and not 12.3*x)
		'X' => '<na>',
		'Y' => '<na>',
		# private
		'equation-str' => undef, # this is with all coefficiens substituted for real numbers, e.g. 12.3*x (and not c1*x)
		'equation-coderef' => undef, # << must be undef until someone asks to eval
		'coefficients-names' => undef,
		'debug' => 0,
	};
	bless $self => $class;

	if( exists $params->{'error'} ){ $self->error($params->{'error'}) }
	if( exists $params->{'Y'} ){ $self->Y($params->{'Y'}) }
	if( exists $params->{'X'} ){ $self->X($params->{'X'}) }
	if( exists $params->{'equation'} ){ $self->equation_str_general($params->{'equation'}) }

	# no coeff is the default, an equ can have no coeff, e.g. y=3.4*x
	if( exists $params->{'coefficients'} ){
		$self->{'coefficients'} = $params->{'coefficients'};
		$self->{'coefficients-names'} = [sort keys %{$params->{'coefficients'}}];
	}
	else {
		$self->{'coefficients'} = {};
		$self->{'coefficients-names'} = [];
	}

	if( ! defined($self->{'equation-str-general'}) ){ warn "error, 'equation' was not specified - give it a string equation of a mathematical formula in 'x' and using just the coefficients you specified - this must be a general equation (e.g. c1+c2*x)."; return undef }
	# and done
	return $self
}
# getter/setter subs
sub     debug {
	my $self = $_[0];
	my $m = $_[1];
	if( defined $m ){ $self->{'debug'} = $m; return $m }
	return $self->{'debug'}
}
sub     equation_str_general {
	my $self = $_[0];
	my $m = $_[1];
	return $self->{'equation-str-general'} unless defined $m;
	$self->{'equation-str-general'} = $m;
	# the equation has changed, there is no need to recalc
	# the coderef, lazily-calc it when needed (call to calculate())
	$self->{'equation-coderef'} = undef;
	return $m
}
sub	_create_equation_coderef {
	my $self = $_[0];
	my $m = $_[1]; # the equation as a string Math::Symbolic understands
	if( ! defined $m ){ $m = $self->{'equation-str-general'} }
	my $tree = Math::Symbolic->parse_from_string($m);
	if( ! defined $tree ){ warn "error, call to ".'Math::Symbolic->parse_from_string()'." has failed for equation string '$m'."; return undef }
	my $co = $self->{'coefficients'};
	for (keys %$co){
		$tree->implement($_, $co->{$_});
	}
	my ($sub) = Math::Symbolic::Compiler->compile($tree);
	if( ! defined $sub ){ warn "error, call to ".'Math::Symbolic::Compiler->compile()'." has failed."; return undef }
	$self->{'equation-coderef'} = $sub;
	$self->{'equation-str'} = "$tree"; # stringify tree
	return $sub;
}
sub	equation_str {
	my $self = $_[0];
	if( ! defined $self->{'equation-str'} ){
		if( ! $self->_create_equation_coderef() ){ warn "error, call to ".'equation_str_general()'." has failed."; return undef }
	}
	return $self->{'equation-str'}
}
# evaluates the model given one or more inputs (as many as the independent
# variables, like 'x') supplied as an arrayref in the case of more than 1
# inputs or a single numerical scalar in the case of just 1
# returns the evaluated expression as a number or undef if something fails
# the 'equation-str' remains unparsed and 'equation-coderef' undefined
# until this sub is called (lazy)
sub	evaluate {
	my $self = $_[0];
	my $inps = $_[1]; # an arrayref of inputs or a single input (scalar)
	my $m = $self->{'equation-coderef'};
	if( ! defined $m ){
		if( ! defined $self->_create_equation_coderef() ){ warn "error, call to ".'_create_equation_coderef()'." has failed."; return undef }
		$m = $self->{'equation-coderef'};
	}
	return $m->(
		ref($inps) eq 'ARRAY' ? @$inps : $inps
	)
}
sub     equation_coderef { return $_[0]->{'equation-coderef'} }
sub     coefficients { return $_[0]->{'coefficients'} }
sub     error {
	my $self = $_[0];
	my $m = $_[1];
	if( defined $m ){ $self->{'error'} = $m; return $m }
	return $self->{'error'}
}
sub     Y {
	my $self = $_[0];
	my $m = $_[1];
	if( defined $m ){ $self->{'Y'} = $m; return $m }
	return $self->{'Y'}
}
sub     X {
	my $self = $_[0];
	my $m = $_[1];
	if( defined $m ){ $self->{'X'} = $m; return $m }
	return $self->{'X'}
}
# must have the same equation string and same coefficients (both name and value)
sub	equals {
	my $self = $_[0];
	my $another = $_[1];

	if( $self->equation_str() ne $another->equation_str() ){ return 0 }

	my @co = @{$self->coefficients_names()};
	my $otherco = $another->coefficients_names();
	if( scalar(@$otherco) != scalar(@co) ){ return 0 }
	for (@co){
		my $c = $self->coefficient($_);
		my $C = $another->coefficient($_);
		if( ! defined($C) || ($c != $C) ){ return 0 }
	}
	return 1 # equal
}
sub	coefficient {
	my $co = $_[0]->coefficients();
	if( exists $co->{$_[1]} ){ return $co->{$_[1]} }
	return undef
}
sub	coefficients_names { return $_[0]->{'coefficients-names'} }
sub	toString {
	my $self = $_[0];
	return     "X=".$self->X()
		."\nY=".$self->Y()
		."\ny=".$self->equation_str()
		."\ny=".$self->equation_str_general()
		."\n".pp($self->coefficients())."\n"
}
sub	toJSON {
	my $self = $_[0];
	# send this to json:
	my $stru = {
		'X' => $self->X(),
		'Y' => $self->Y(),
		'equation-str' => $self->equation_str(),
		'equation-str-general' => $self->equation_str_general(),
		'coefficients' => $self->coefficients()
	};
	my $ret = JSON::encode_json($stru);
	if( ! defined $ret ){ warn pp($stru)."\n\nerror, call to ".'JSON::encode_json()'." has failed for the above Perl structure."; return undef }
	return $ret
}
# writes us as JSON to file
sub	toFile {
	my $self = $_[0];
	my $outfile = $_[1];
	if( ! Statistics::Covid::Utils::save_text_to_localfile($self->toJSON()."\n", $outfile) ){ warn "error, call to ".'Statistics::Covid::Utils::save_text_to_localfile()'." has failed for saving a JSON string to file '$outfile'."; return 0 }
	return 1
}
# factory method to create a Model object from a JSON string
sub	fromJSON {
	my $injsonstr = $_[0];
	my $pv = Data::Roundtrip::json2perl($injsonstr);
	if( ! defined $pv ){ warn $injsonstr."\n\nerror, call to ".'Data::Roundtrip::json2perl()'." has failed for above JSON string."; return undef }
	delete $pv->{'equation-str'};
	$pv->{'equation'} = $pv->{'equation-str-general'}; delete $pv->{'equation-str-general'};
	my $obj = Statistics::Covid::Analysis::Model->new($pv);
	if( ! defined $obj ){ warn pp($pv)."\n\nerror, call to ".'Statistics::Covid::Analysis::Model->new()'." has failed for above parameters."; return undef }
	return $obj
}
# factory method to create a Model object from a file which contains a Model in JSON
# (can be written by toFile())
sub	fromFile {
	my $infile = $_[0];
	my $jsonstring = Statistics::Covid::Utils::slurp_localfile($infile);
	if( ! defined $jsonstring ){ warn "error, call to ".'Statistics::Covid::Utils::slurp_localfile()'." has failed for file '$infile'."; return undef }
	my $obj = Statistics::Covid::Analysis::Model::fromJSON($jsonstring);
	if( ! defined $obj ){ warn $jsonstring."\n\nerror, call to ".'Statistics::Covid::Analysis::Model::fromJSON()'." has failed for file '$infile' (read above JSON string)."; return undef }
	return $obj;
}
	
1;
__END__
# end program, below is the POD
=pod

=encoding UTF-8


=head1 NAME

Statistics::Covid::Analysis::Model - Class dual to the 'Datum' table in DB - it contains data for one time and space point.

=head1 VERSION

Version 0.24

=head1 DESCRIPTION

Class encompassing a fitted analytical model. Such a model is nothing
more than an equation and a set of coefficient values. For
example the equation can be C<c1 + c2*x> and the coefficients
can be C<{c1=>1.2, c2=>2.3}>. Such a model can be used to
evaluate the equation at any specified input, i.e. when C<x>
assumes a user-specified value.

Optionally, the model can contain a value for the error
which occured during fitting this model (see L<Statistics::Covid::Analysis::Model::Simple::fit>).
A string of what C<x> represents, for example C<mass>, or in our case,
C<time>. Similarly a string of what C<y> represents (for example C<confirmed cases>).

=head1 SYNOPSIS

  $model = Statistics::Covid::Analysis::Model->new({
	'error' => 1.2, # optional
	'


=head1 AUTHOR

Andreas Hadjiprocopis, C<< <bliako at cpan.org> >>, C<< <andreashad2 at gmail.com> >>


=head1 BUGS

Please report any bugs or feature requests to C<bug-statistics-Covid at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Statistics-Covid>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Statistics::Covid::Analysis::Model


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

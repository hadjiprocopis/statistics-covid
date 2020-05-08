package Statistics::Covid::WorldbankData;

use 5.10.0;
use strict;
use warnings;

use parent 'Statistics::Covid::IO::DualBase';

# this is where our DB schema is specified
# edit this file to reflect your table design as well as your $self variables
use Statistics::Covid::WorldbankData::Table;

use DateTime;

our $VERSION = '0.24';

# our constructor which calls parent constructor first and then does
# things specific to us, like dates
# create a Data item, either by supplying parameters as a hashref
# of name=>value or as an array which must have as many elements
# as the 'db-columns' items and in this order.
sub	new {
	my ($class, $colNameValuePairs, $otherparams) = @_;
	$colNameValuePairs = {} unless defined $colNameValuePairs;
	$otherparams = {} unless defined $otherparams; 

	my $parent = ( caller(1) )[3] || "N/A";
	my $whoami = ( caller(0) )[3];

	my $self = $class->SUPER::new(
		$Statistics::Covid::WorldbankData::Table::SCHEMA,
		$colNameValuePairs,
		$otherparams
	);
	if( ! defined $self ){ warn "error, call to $class->new() has failed."; return undef }

	return $self
}
# returns 1 if self is bigger than input (and probably more up-to-date/NEWER)
# returns 0 if self is same as input
# returns -1 if input is bigger than self
# remember that it compares for the same year AND country
# so it means the data source has contradictory data
# which is not likely, so an idea is to return 0, same all the time
# note that self is Statistics::Covid::WorldbankData
# and another is Statistics::Covid::Schema::Result::WorldbankData
# if you want to get the name of a column for which there is
# no getter, use
# Statistics::Covid::WorldbankData::column_name('terminal')
# and
# Statistics::Covid::Schema::Result::WorldbankData::get_column('terminal')
sub	newer_than {
	my ($self, $another) = @_;
	# returns -1 if self pop < another pop (which makes another NEWER?)
	# this presupposes that population column (SP.POP.TOTL) exists
	# in Statistics::Covid::WorldbankData::Table.pm!!!
	return $self->get_column('SP_POP_TOTL')
		<=> $another->get_column('SP_POP_TOTL')
}
# there is a toString in parent class which we wont overwrite
1;
__END__
# end program, below is the POD

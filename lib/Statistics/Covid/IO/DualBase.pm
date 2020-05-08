package Statistics::Covid::IO::DualBase;

use 5.10.0;
use strict;
use warnings;

our $VERSION = '0.24';

use Data::Dump qw/pp/;

###########
#### These subs must be implemented by anyone using this base class
###########
# compares 2 objs and returns the "newer"
# which means the one with more up-to-date markers in our case
# as follows:
# returns 1 if self is bigger than input (and probably more up-to-date)
# returns 0 if self is same as input
# returns -1 if input is bigger than self
# we compare only markers, we don't care about any other fields
sub	newer_than {
	my $self = $_[0];
	my $inputObj = $_[1];
	die "you need to implement me";

	return 0 # identical
}
###########
#### This constructor must not change and every class inheriting from us
#### must call it prior to doing their own 'constructor things'
#### it takes a hashref OR arrayref of params to initialise the fields
#### whose names are specified above as keys to the DBCOLUMNS_SPEC
###########

# create a Data item, either by supplying 1st input parameter,
# $params as a hashref of name=>value
# or
# $params as an array which must have as many elements
# as the 'db-columns' items and in the same order.
sub	new {
	my ($class, $dbschema, $colNameValuePairs, $otherparams) = @_;
	$colNameValuePairs = {} unless defined $colNameValuePairs;
	$otherparams = {} unless defined $otherparams;

	my $parent = ( caller(1) )[3] || "N/A";
	my $whoami = ( caller(0) )[3];

	if( ! defined $dbschema ){ warn "error, dbschema parameter was not specified."; return undef }

	my $fail_on_undef_value = exists($otherparams->{'fail-on-undefined-value'}) && defined($otherparams->{'fail-on-undefined-value'})
			? $otherparams->{'fail-on-undefined-value'} : 1;

	my $self = {
		# our data goes here and that goes straight to DB
		'c' => {},
		# other private data we do not want to send to DB
		'p' => {
			# must be a hashref as below which is exactly what $dbschema must contain
			'db-specific' => $dbschema,
# example of the $dbschema
#			{
#				# ADD HERE YOUR TABLENAME
#				'tablename' => undef, # 'our table name'
#				'schema' => {
#					# ADD HERE YOUR FIELDS
#					# key is the internal name and also name in DB
#					# for example, this is the 'id' field, both in DB and in our $self
#					# it is of varchar data type (relevant only for DB),
#					# 'default_value' applies to both DB and $self
#					'id' => {data_type => 'varchar', is_nullable=>0, size=>100, default_value=>'<NA>'},
#					# ... add more fields
#				}, # end schema
#				# ADD HERE THE NAME OF THE FIELDS TO create the PK
#				'column-names-for-primary-key' => undef, # [qw/one or more keys from 'schema' to act as PK/]
#				'column-names' => undef, # will be created later by init as an arrayref
#				'num-columns' => -1, # later by init
#			}, # end db-specific fields
			'debug' => 0,
		},
	};
	bless $self => $class;

	my $c = $self->{'c'}; # content fields as they go to DB
	my $p = $self->{'p'}; # private fields
	my $d = $p->{'db-specific'};
	my $s = $d->{'schema'};

	# do some sanity checks first
	if( !exists($d->{'tablename'}) || !defined($d->{'tablename'}) ){ warn "error, 'tablename' was not specified in the dbschema parameter."; return undef }
	if( !exists($d->{'schema'}) || !defined($d->{'schema'}) ){ warn "error, 'schema' was not specified in the dbschema parameter."; return undef }
	if( !exists($d->{'column-names-for-primary-key'}) || !defined($d->{'column-names-for-primary-key'}) ){ warn "error, 'column-names-for-primary-key' was not specified in the dbschema parameter."; return undef }

	# populate our self with the data and set to default values (before checking input params)
	for (@{$d->{'column-names'}}){
		# create the field in $self and set its default value
		$c->{$_} = $s->{$_}->{'default_value'}
	}
	# now check input params for particular data values
	# it is only considered if input param exists in the 'column-names' of the db-schema
	if( ref($colNameValuePairs) eq 'HASH' ){
		# input params is a HASHref, we are allowed to have as little data as possible,
		# the rest will assume default values BUT those undef are illegal and must be filled as a minimum
		foreach my $k (@{$d->{'column-names'}}){
			if( exists $colNameValuePairs->{$k} ){ $c->{$k} = $colNameValuePairs->{$k} }
		}
		if( exists $colNameValuePairs->{'debug'} ){ $self->debug($colNameValuePairs->{'debug'}) }
	} elsif( ref($colNameValuePairs) eq 'ARRAY' ){
		# input params is an ARRAYref, which is expected to have values FOR ALL DATA
		# this is used for cloning or loading from DB
		# IMPORTANT: order of the params array must be exactly the same as in the 'column-names' array
		# which is keys of 'schema' sorted alphabetically {$a cmp $b}
		if( @$colNameValuePairs != $d->{'num-columns'} ){ warn "size of the array of parameters (".@$colNameValuePairs.") is not the same as the size of our parameters (".$d->{'num-columns'}.")."; return undef }
		my $i = 0;
		foreach my $k (@{$d->{'column-names'}}){ $c->{$k} = $colNameValuePairs->[$i++] }
	} else { warn "parameter can be a hashref or an arrayref with values"; return undef }

	# TODO: automatically insert getters and setter subs for each column name in the schema

	# now check if anything is left undef and complain
	# we could replace it with default value (from schema) but complain cleans the data better
	foreach my $k (@{$d->{'column-names'}}){
		if( ! defined $c->{$k} ){
			if( ! exists($s->{$k}->{'default_value'}) ){
				print STDERR pp($colNameValuePairs)."\n\n$whoami (via $parent) : parameter '$k' was not given a value or left undefined but the table schema does not specify a 'default_value', can not continue.\n";
				return undef
			}
			if( $fail_on_undef_value == 1 ){ 
				print STDERR pp($colNameValuePairs)."\n\n$whoami (via $parent) : parameter '$k' was not given a value or left undefined and that's not allowed, input data is above, use 'fail-on-undefined-value'=>0 to disable this check.\n";
				return undef
			}
			# set the default value
			$c->{$k} = $s->{$k}->{'default_value'};
		}
	}
	return $self
}
# returns the value for this field/attribute/column name
# and it is compatible with DBIx::Class's Schema::Result
sub	get_column {
	my $self = $_[0];
	my $column_name = $_[1];
	if( ! $self->column_name_is_valid($column_name) ){ die "column name '$column_name' does not exist." }
	return $self->{'c'}->{$column_name}
}
sub	column_name_is_valid { return exists $_[0]->{'c'}->{$_[1]} }
###########
#### Nothing to change below, the subs to implement and overwrite are those above
###########
# compares this object with another and returns 0 if different or 1 if the same
sub	equals {
	my $self = $_[0];
	my $another = $_[1];
	my $res;
	my $c = $self->{'c'};
	my $C = $another->{'c'};
	for (@{$self->column_names()}){
		if( ($c->{$_} cmp $C->{$_}) != 0 ){ return 0 }
	}
	return 1 # equal!
}
# compares this object's primary key(s) with another
# and returns 0 if different or 1 if the same
# this can be used in checking whether two objs will be mapped
# to the same db row (if they have the same PK they will be)
# thus checking for duplicates in-memory or in-db
sub	equals_primary_key {
	my $self = $_[0];
	my $another = $_[1];
	my $res;
	my $c = $self->{'c'};
	my $C = $another->{'c'};
	my $dbs = $self->_dbspecific();
	return 0 if $dbs->{'num-columns'} != $another->_dbspecific()->{'num-columns'};
	for (@{$dbs->{'column-names-for-primary-key'}}){
		if( ($c->{$_} cmp $C->{$_}) != 0 ){ return 0 }
	}
	return 1 # equal!
}
# returns the values of PK columns joined with '-'
# the separator should not be present in any db field.
# I assume all databaes do not use '-' in their column names.
# the choice of this character is important in saving later to a filename
# it should be acceptable by the filesystem, if it is not then substitutions have
# to be made prior to saving to disk. So '-' is a good choice I think.
# this acts as a form of a PK but DB internally may hash this (with different separator)
# but this will definetely be a unique primary key.
sub	unique_id_based_on_primary_key {
	my $self = $_[0];
	my $c = $self->{'c'};
	my $dbs = $self->_dbspecific()->{'column-names-for-primary-key'};
	my $ret = join '-', map { $c->{$_} } @$dbs;
	return $ret # a primary key (this may not be exactly the same used in DB internally)
}
# check if the objects in the 2 input arrays of objects equal
# the objects must be derived from this class and have the equals() sub defined
sub	objects_equal {
	my ($array_of_datum_objs1, $array_of_datum_objs2) = @_;
	my $N = scalar(@$array_of_datum_objs1);
	return 0 if $N != scalar(@$array_of_datum_objs2);
	for (0 .. $N-1){
		if( ! $array_of_datum_objs1->[$_]->equals($array_of_datum_objs2->[$_]) ){
			die "DIFFER: ".pp($array_of_datum_objs1->[$_]->toHashtable())."\n\nAND:\n\n".pp($array_of_datum_objs2->[$_]->toHashtable())."\n";
		}
		return 0 unless $array_of_datum_objs1->[$_]->equals($array_of_datum_objs2->[$_]);
	}
	return 1 # same in each and every way
}
sub	_dbspecific { return $_[0]->{'p'}->{'db-specific'} }
sub	toArray {
	my $self = $_[0];
	my @ret = ();
	my $c = $self->{'c'};
	my $dbc = $self->_dbspecific()->{'column-names'};
	for (@$dbc){ push @ret, $c->{$_} }
	return \@ret
}
sub	toHashtable {
	my $self = $_[0];
	my %ret = ();
	my $c = $self->{'c'};
	my $dbc = $self->_dbspecific()->{'column-names'};
	for (@$dbc){ $ret{$_} = $c->{$_} }
	return \%ret
}
sub	clone { return new($_[0]->toArray()) }
sub	debug {
	my $self = $_[0];
	my $m = $_[1];
	return $self->{'p'}->{'debug'} unless defined $m;
	$self->{'p'}->{'debug'} = $m;
	return $m;
}
sub column_names_for_primary_key { return $_[0]->_dbspecific()->{'column-names-for-primary-key'} }
sub num_columns { return $_[0]->_dbspecific()->{'num-columns'} }
sub tablename { return $_[0]->_dbspecific()->{'tablename'} }
sub column_names { return $_[0]->_dbspecific()->{'column-names'} }
# these work but can be overwritten if you wish
sub	make_random_object {
	my $class = $_[0];
	srand $_[1] if defined $_[1];

	(my $file = $class) =~ s|::|/|g; $file .= '.pm';
	my $rc = eval { require $file; 1 };
	if( $@ || ! $rc ){ warn "failed to create random object of type '$class', because class failed to load: $@"; return undef }

	my $s = do { no strict 'refs'; ${$class.'::Table::SCHEMA'} };
	$s = $s->{'schema'};
	my ($dtype, $sz);
	my %objhash;
	for my $colname (sort keys %$s){
		$dtype = $s->{$colname}->{'data_type'};
		if( $dtype eq 'varchar' ){
			$sz = int($s->{$colname}->{'size'} / 10)+4;
			$objhash{$colname} = join '', map { chr(ord('a')+int(rand(26))) } 1..$sz
		} elsif( $dtype eq 'real' ){
			$objhash{$colname} = int(rand(1000000))/100
		} elsif( $dtype eq 'integer' ){
			$objhash{$colname} = int(rand(1000000))
		} else { die "make_random_object() : you need to implement me for colname='$colname' and data type '$dtype'" }
	}
	my $obj = $class->new(\%objhash);
	if( ! defined $obj ){ warn pp(\%objhash)."\nerror, call to $class".'->new()'." has failed for the above parameters"; return undef }
	return $obj
}
sub	toString {
	my $self = $_[0];
	my $ret = "";
	my $c = $self->{'c'};
	return join(
		"\n",
		map { $_ . " = " . $c->{$_} }
			@{$self->column_names()}
	)
}
1;
__END__
# end program, below is the POD

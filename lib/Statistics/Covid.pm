package Statistics::Covid;
use lib 'blib/lib';

use 5.10.0;
use strict;
use warnings;

our $VERSION = '0.24';

use Statistics::Covid::Utils;
use Statistics::Covid::Datum;
use Statistics::Covid::Datum::IO;
use Statistics::Covid::Version;
use Statistics::Covid::Version::IO;

use Storable qw/dclone/;

use Data::Dump qw/pp/;

sub	new {
	my ($class, $params) = @_;
	$params = {} unless defined $params;

	my $parent = ( caller(1) )[3] || "N/A";
	my $whoami = ( caller(0) )[3];

	my $self = {
		# these are one for each provider:
		'save-to-file' => {},
		'save-to-db' => {},
		'debug' => 0,
		# internal variables,
		'p' => {
			# a hash to hold the providers providername => providerobj (which we create here)
			'provider-objs' => undef,
			'config-hash' => undef,
			'io-datum' => undef,
			'db-version' => undef,
			# pass extra params to each provider
			# the params is a hashref keyed on provider name
			'provider-extra-params' => undef,
		},
	};
	bless $self => $class;

	my $m;

	if( exists $params->{'debug'} ){ $self->debug($params->{'debug'}) }
	my $debug = $self->debug();

	my $config_hash = undef;
	if( exists($params->{'config-file'}) && defined($m=$params->{'config-file'}) ){
		$config_hash = Statistics::Covid::Utils::configfile2perl($m);
		if( ! defined $config_hash ){ warn "error, failed to read config file '$m'"; return undef }
	} elsif( exists($params->{'config-string'}) && defined($m=$params->{'config-string'}) ){
		$config_hash = Statistics::Covid::Utils::configstring2perl($m);
		if( ! defined $config_hash ){ warn "error, failed to parse config string '$m'"; return undef }
	} elsif( exists($params->{'config-hash'}) && defined($m=$params->{'config-hash'}) ){ $config_hash = Storable::dclone($m) }
	else { warn "error, configuration was not specified using one of 'config-file', 'config-string', 'config-hash'. For an example configuration file see t/example-config.t"; return undef }
	$self->config($config_hash);

	# optional params
	# shall we save? (specific for each provider, default is yes)
	# expects a hash of providername=>1 or 0 (for each provider)
	# at this stage we don't know any providers yet!
	# if nothing is specified, then when providers are set, we put default values (see below)
	if( exists($params->{'save-to-file'}) && defined($params->{'save-to-file'}) ){
		if( ref($params->{'save-to-file'}) ne 'HASH' ){ die "'save-to-file': a HASHref is needed" }
		$self->save_to_file($_, $params->{'save-to-file'}->{$_})
			for keys %{$params->{'save-to-file'}};
	}
	if( exists($params->{'save-to-db'}) && defined($params->{'save-to-db'}) ){
		if( ref($params->{'save-to-db'}) ne 'HASH' ){ die "'save-to-db': a HASHref is needed" }
		$self->save_to_db($_, $params->{'save-to-db'}->{$_})
			for keys %{$params->{'save-to-db'}};
	}

	if( exists $params->{'save-to-db'} ){ $self->save_to_db($params->{'save-to-db'}) }
	# extra params to pass to providers?
	if( exists $params->{'provider-extra-params'} ){ $self->{'p'}->{'provider-extra-params'} = $params->{'provider-extra-params'} }
	else { $self->{'p'}->{'provider-extra-params'} = {} }

	for(keys %$params){
		$self->{$_} = $params->{$_} if exists $self->{$_}
	}
	if( ! defined($self->{'p'}->{'io-datum'}=$self->_create_Datum_IO()) ){ warn "error, failed to create IO object"; return undef }

	if( exists($params->{'providers'}) && defined($m=$params->{'providers'}) ){
		if( ! $self->providers($m) ){ warn "error, failed to install specified provider(s) (calling providers()) : '".join("','", @$m)."'"; return undef }
	} else {
		if( $debug > 0 ){ warn "warning, 'providers' (like 'UK::GOVUK' and/or 'World::JHU') was not specified, that's ok, but you must insert some before fetching any data - interacting with db will be ok." }
	}
	# default values for save-to-file/db
	for( @{$self->provider_names()} ){
		# don't save to file if provider is a localdir, assumes localdir providers
		# follow this special name pattern, e.g. JHUlocaldir
		$self->{'save-to-file'}->{$_} = 1
		  unless ($_=~/localdir$/) || exists($self->{'save-to-file'}->{$_})
		;
		$self->{'save-to-db'}->{$_} = 1 unless exists $self->{'save-to-db'}->{$_};
	}

	if( ! defined $self->version() ){ warn "error, failed to get the db-version"; return undef }
	if( $debug > 0 ){ warn "db-version: ".$self->version() }

	return $self
}
sub	DESTROY {
	# disconnect just in case, usually this is not required
	my $self = $_[0];
	if( defined $self->datum_io() ){
		$self->datum_io()->db_disconnect();
		$self->{'p'}->{'io-datum'} = undef;
	}
}
# fetch data from the providers and optionally save to file and/or db
# returns undef on failure
# returns the items fetched (that's datum objects) as an arrayref (which can also be empty)
sub	fetch_and_store {
	my $self = $_[0];

	my @retObjs = (); # we are returning the objects we just fetched
	my $debug = $self->debug();
	my $num_fetched_total = 0;
	my $providers = $self->providers();
	if( ! defined $providers ){ warn "error, data providers must be inserted prior to using this, e.g. providers('World::JHU')"; return undef }
	for my $pn (keys %$providers){
		my $providerObj = $providers->{$pn};
		my $datas = $providerObj->fetch();
		if( ! defined $datas ){ warn "$pn : error, failed to fetch()"; return undef }
		if( $debug > 0 ){ warn "$pn : fetched latest data OK." }
#		if( $self->save_to_file($pn) ){
#			my $outbase = $providerObj->save_fetched_data_to_localfile($datas);
#			if( ! defined($outbase) ){ warn "error, failed to save the data just fetched to local file"; return undef }
#			if( $debug > 0 ){ warn "$pn : fetched data saved to local file, with this basename '$outbase'." }
#		}
		my $objs = $providerObj->create_Datums_from_fetched_data($datas);
		if( ! defined $objs ){ warn "$pn : error, failed to processed fetched data and create Datum objects"; return undef }
		push @retObjs, @$objs;
		my $num_fetched = scalar @$objs;
		$num_fetched_total += $num_fetched;
		if( $debug > 0 ){ warn "$pn : fetched $num_fetched objects." }
		if( $self->save_to_db($pn) ){
			my $io = $self->datum_io();
			my $rows_in_db_before = $io->db_count();
			my $ret = $io->db_insert_bulk($objs);
			my $rows_in_db_after = $io->db_count();
			if( $debug > 0 ){ print STDOUT _db_insert_bulk_returnvalue_toString($ret, $rows_in_db_before, $rows_in_db_after) }
			if( $ret->{'num-failed'} > 0 ){ warn "$pn : error, there were failed inserts into DB." }
			my $dbfilename = $io->db_filename();
			if( $dbfilename ne '' ){ print STDOUT "$pn : fetch_and_store() : saved data to database in '$dbfilename'.\n" }
		}
	}
	if( $debug > 0 ){ warn "fetched $num_fetched_total objects in total and from all providers: '".join("','",sort keys %$providers)."'." }
	# returns an arrayref of all the Datums JUST fetched (after being converted from raw data to objects)
	return \@retObjs
}
# a shortcut to saving an arrayref of Datum Objects to our db
# returns a hashref of statistics on what happened with the insert
# see L<Statistics::Covid::IO::Base::db_insert_bulk>() for details
# returns undef on failure
sub	db_datums_insert_bulk { return $_[0]->datum_io()->db_insert_bulk($_[1]) }

# a shortcut to gettting the count of the Datum table,
# optional hashref parameters can specify 'conditions' and 'attributes'
# else it counts all rows in Datum table
# and returns that count (can be zero)
# returns -1 on failure
sub	db_datums_count { return $_[0]->datum_io()->db_count($_[0]) }

# load datums from DB into our own internal storage (appending to whatever we already may have stored)
# use clear() to empty thats storage.
# input params are exactly what Statistics::Covid::IO::Base::db_select($params) takes
# optional: 'conditions', 'attributes', 'debug'
# 'conditions' is a DBIx::Class condition, a DBIx::Class::ResultSet->search() takes
# returns undef on failure
# returns the loaded datum objs on success (can be empty) as a hashref
sub	select_datums_from_db {
	my ($self, $params) = @_;

	my $objs = $self->datum_io()->db_select($params);
	if( ! defined $objs ){ warn pp($params)."\n\nerror, failed to load Datum objects from DB using above parameters."; return -1 }
	return $objs
}
# shortcut to selecting datum objects from db (select_datums_from_db())
# with optional conditions (where clauses)
# and ordering the results in time-ascending order.
# it's useful for getting the timeline for a given place.
# for conditions see https://metacpan.org/pod/SQL::Abstract#WHERE-CLAUSES
# if successful, it returns an array of Datum objects (sorted on time)
# it returns undef on failure
sub	select_datums_from_db_time_ascending {
	my $self = $_[0];
	my $params = $_[1];
	$params = {} unless defined $params;

	# if no params given it will much everything in db and sort wrt time!

	my $select_params = {};

	# optionally specify the conditions:
	# this is a hash of conditions, we can get this from input params
	# or we can fill it in with specific conditions
	# if specified, this must be a hashref of SQL::Abstract compatible
	# search conditions mentioning the exact column names of the Datum table
	if( exists($params->{'conditions'}) && defined($params->{'conditions'}) ){
		$select_params->{'conditions'} = $params->{'conditions'};
	}

	# optionally specify the attributes, e.g. {'rows' => 10}
	if( exists($params->{'attributes'}) && defined($params->{'attributes'}) ){
		$select_params->{'attributes'} = $params->{'attributes'};
	}
	# set (can overwrite user-specific!)
	$select_params->{'attributes'}->{'order_by'} = {'-asc' => 'datetimeUnixEpoch'};

	my $results = $self->select_datums_from_db($select_params);
	if( ! defined $results ){ warn pp($select_params)."\nerror, call to ".'select_datums_from_db()'." has failed for above conditions"; return undef }
	return $results
}
# shortcut to selecting datum objects from db (select_datums_from_db())
# with optional conditions (where clauses)
# BUT returning the max(datetimeUnixEpoch) which is the latest
# row for this query
# for conditions see https://metacpan.org/pod/SQL::Abstract#WHERE-CLAUSES
# if successful, it returns an array of Datum objects (sorted on time)
# it returns undef on failure
sub	select_datums_from_db_latest {
	my $self = $_[0];
	my $params = $_[1];
	$params = {} unless defined $params;

	# if no params given it will much everything in db and sort wrt time!

	my $select_params = {};

	# optionally specify the conditions:
	# this is a hash of conditions, we can get this from input params
	# or we can fill it in with specific conditions
	# if specified, this must be a hashref of SQL::Abstract compatible
	# search conditions mentioning the exact column names of the Datum table
	if( exists($params->{'conditions'}) && defined($params->{'conditions'}) ){
		$select_params->{'conditions'} = $params->{'conditions'};
	}

	# optionally specify the attributes, e.g. {'rows' => 10}
	if( exists($params->{'attributes'}) && defined($params->{'attributes'}) ){
		$select_params->{'attributes'} = $params->{'attributes'};
	}
	# TODO: append to '+select' and 'group_by' if user specifies them too
	if( exists $select_params->{'attributes'}->{'+select'} ){ die "ooppps, 'attributes'->'+select' was specified, but I am using it and appending is not implemented, you are welcome to submit a patch" }
	if( exists $select_params->{'attributes'}->{'group_by'} ){ die "ooppps, 'attributes'->'group_by' was specified, but I am using it and appending is not implemented, you are welcome to submit a patch" }
	# TODO: the group_by is hardcoded
	$select_params->{'attributes'}->{'group_by'} = ['admin0', 'admin1', 'admin2', 'admin3', 'admin4'];
	$select_params->{'attributes'}->{'+select'} = [
		{'max' => 'datetimeUnixEpoch'}
	];
	my $results = $self->select_datums_from_db($select_params);
	if( ! defined $results ){ warn pp($select_params)."\nerror, call to ".'select_datums_from_db()'." has failed for above conditions"; return undef }
	return $results
}
# read data from data file (original data as fetched by the scrapper)
# given at least a provider string in the input params hash
#         as $params->{'provider'} = 'XYZ'
# in which case all data found in XYZ's datafilesdir will be read
# Now, the files to read will be specified in the
#            $params->{'basename'} = 'ABC' | ['ABC', '123', ...]
# which again can be a scalar if it's a single basename
# or an arrayref for one or more.
# All the basenames will apply to the provider specified.
# Each basename will be used to construct the exact data-file name(s)
# for the specified provider.
# The specified provider string id must correspond to a provider object
# already created and loaded during construction via the 'providers' param
# returns undef on failure
# returns an array of L<Statistics::Covid::Datum> Objects on success
sub	read_data_from_file {
	my $self = $_[0];
	my $params = $_[1];

	my $debug = $self->debug();

	my $providerstr;
	if( ! exists($params->{'provider'}) || ! defined($providerstr=$params->{'provider'}) ){ warn "error, 'provider' was not specified"; return undef }
	my $providerObj = $self->providers($providerstr);
	if( ! defined $providerObj ){ warn "provider does not exist in my list, you may need to load it if indeed the name is correct: '$providerstr'"; return undef }

	# optional list of basenames of data
	# if this is missing then all files in the datafilesdir() of the provider specified
	# will be loaded
	my (@basenames, $m);
	if( exists($params->{'basename'}) && defined($m=$params->{'basename'}) ){
		# basename was specified, we expect an arrayref of basenames or a single basename
		my $r = ref($m);
		if( $r eq '' ){ @basenames = ($m) }
		elsif( $r eq 'ARRAY' ){ @basenames = @{$m} }
		else { warn "error, expected scalar string or arrayref for input 'basename' but got ".$r; return undef }
		if( scalar(@basenames) == 0 ){
			warn "no data files were specified for provider '$providerstr'.";
			return () # not a failure
		}
	} else {
		# no basenames specified, find them
		my $datadir = $providerObj->datafilesdir();
		# TODO : remove this check when stable
		if( ! defined($datadir) ){ die "something wrong here, datafilesdir() is not specified for provider '$providerstr'." }
		my $datafiles = Statistics::Covid::Utils::find_files(
			$datadir,
			# can be 2020-04-12T00.00.00_1586649600.data.json
			# or 2020-04-12T00.00.00_1586649600.data.1.json
			# (when multiple datafiles)
			# or 2020-04-12T00.00.00_1586649600.metadata.json
			[qr/\.(json|csv)$/i]
		);
		my %tmp;
		for my $adatafile (@$datafiles){
			$adatafile =~ s!\.(?:(?:data)|(?:meta))(?:\.\d+)?\.(?:json|csv)$!!;
			$tmp{$adatafile} = 1;
		}
		if( scalar(keys %tmp) == 0 ){
			warn "no data files were found for provider '$providerstr' in data dir '$datadir'.";
			return () # not a failure
		} else { @basenames = sort keys %tmp }
	}
	my @ret;
	for my $abasename (@basenames){
		my $datas = $providerObj->load_fetched_data_from_localfile($abasename);
		if( ! defined $datas ){ warn "error, call to ".'load_fetched_data_from_localfile()'." has failed for provider '$providerstr' and data-file basename '$abasename'"; return undef }
		# convert datas to datums
		my $datumObjs = $providerObj->create_Datums_from_fetched_data($datas);
		if( $debug > 0 ){ warn "read ".scalar(@$datumObjs)." items from basename '$abasename'.\n"; }
		if( ! defined $datumObjs ){ warn "error, call to ".'create_Datums_from_fetched_data()'." has failed for provider '$providerstr' and data-file basename '$abasename'"; return undef }
		push @ret, @$datumObjs
	}
	if( $debug > 0 ){ warn "read ".scalar(@ret)." items in total for provider '$providerstr'." }
	return \@ret # success
}
# read data from data files given
# an input hashref of $params->{'what'}={providerID => [list-of-basenames]}
# returns a hashref {providerID => $datumObjs}
# or undef on failure, for more information see L<read_data_from_file()>
sub	read_data_from_files {
	my $self = $_[0];
	my $params = $_[1];
	my $inp;

	my @providerstrs;
	if( ! exists($params->{'what'}) || ! defined($params->{'what'}) ){
		# nothing was provided in the input, we use ALL our providers loaded during construction
		my $m = $self->providers();
		if( ! defined $m ){ warn "error, data providers must be inserted prior to using this, e.g. providers('World::JHU')"; return undef }
		@providerstrs = keys %$m;
	} else {
		# something was given at input
		$inp = $params->{'what'};
		if( ref($inp) eq 'HASH' ){
			# this is a hash of {providerID => [list-of-basenames]}
			my %ret;
			for my $aproviderstr (sort keys %$inp){
				my $da = $self->read_data_from_file({
					'basename' => $inp->{$aproviderstr}
				});
				if( ! defined $da ){ warn "error, call to read_data_from_file() has failed for provider '$aproviderstr'"; return undef }
				$ret{$aproviderstr} = $da;
			}
			return \%ret
		} elsif( ref($inp) eq 'ARRAY' ){
			# this is an array of provider strings,
			# all files from the data dir of this provider will be loaded
			@providerstrs = @$inp;
		} elsif( ref($inp) eq '' ){
			# this is just a lone provider string
			@providerstrs = ($inp);
		}
	}
	# Here we have a list of providerstrs only
	# So, we will let read_data_from_file() find data files in our datafilesdir()
	my %ret;
	foreach my $aproviderstr (@providerstrs){
		my $da = $self->read_data_from_file({
			'provider' => $aproviderstr
		});
		if( ! defined($da) ){ warn "error, call to read_data_from_file() has failed for the provider '$aproviderstr'"; return undef }
		$ret{$aproviderstr} = $da;
	}
	return \%ret
}
# read the Version table from DB which holds the db-version which is useful
# for migrating to newer db-versions when upgrades happen.
# ideally each upgrade should have a migration script for migrating from
# old version to newer.
# read db-version from DB and cache the result (and also return it)
# if $force==1 then it discards the cached version and re-connects to DB
# returns the version as a string or undef on failure
sub	version {
	my $self = $_[0];
	my $force = defined $_[1] ? $_[1] : 0;
	if( $force==0 && defined($self->{'db-version'}) ){ return $self->{'db-version'} }

	my $vio = $self->_create_Version_IO();
	if( ! defined $vio ){ warn "error, call to _create_Version_IO() has failed"; return undef }
	if( ! defined $vio->db_connect() ){ warn "error, failed to connect to DB, call to ".'db_connect()'." has failed"; return undef }
	my $versionobj = $vio->db_select();
	if( defined($versionobj) && (scalar(@$versionobj)==1) ){
		$self->{'db-version'} = $versionobj->[0]->version(); return $self->{'db-version'}
	}
	if( scalar @$versionobj >1 ){ warn "error, why there are more than 1 rows for table Version? (got ".@$versionobj." rows)"; return undef }

	# no version row, create one
	$versionobj = Statistics::Covid::Version->new();
	if( ! defined $versionobj ){ warn "error, call to ".'Statistics::Covid::Version->new()'." has failed"; return undef }
	$self->{'db-version'} = $versionobj->version();
	# and save the version to db;
	if( 1 != $vio->db_insert($versionobj) ){ warn "error, db_insert() failed for version"; return undef }
	return $versionobj->version();
}
# returns the number of rows in the Datum table in the database
# with optional conditions (WHERE clauses) in the $params
# conditions follow the convention of L<DBIx::Class::ResultSet>
# here is an example:
# e.g. $params = {'conditions' => { 'name' => 'Hackney' } }
# it returns -1 on failure
# it returns the count (can be zero or positive) on success
sub	db_count_datums {
	my $self = $_[0];
	my $params = defined($_[1]) ? $_[1] : undef;
	my $count = $self->datum_io()->db_count($params);
	if( $count < 0 ){ warn "error, call to db_count() has failed for the above parameters."; return -1 }
	return $count
}
sub	db_merge {
	my $self = $_[0];
	my $another_db = $_[1];

	die "not yet implemented"
}
sub	db_backup {
	my $self = $_[0];
	# optional output file, or default
	my $outfile = $_[1]; # if undef then a timestamped filename will be created in current dir (not in db dir)
	return $self->datum_io()->db_create_backup_file($outfile)
}
sub	datum_io { return $_[0]->{'p'}->{'io-datum'} }
# getter/setter subs
sub     debug {
	my $self = $_[0];
	my $m = $_[1];
	if( defined $m ){ $self->{'debug'} = $m; return $m }
	return $self->{'debug'}
}
sub     dbparams { return $_[0]->config()->{'dbparams'} }
# returns the hashref of providers (id=>obj) if no input
# provider string id is provided
# else checks to see if a provider can be matched from our list
# and if it does, it returns the provider obj
# if not found returns undef (so undef can happen only
# if a provider id is specified at input)
sub	provider_names { 
	my $self = $_[0];
	my $prov = $_[0]->providers();
	return defined($prov)
		? [sort keys %$prov]
		: []
	;
}
sub	providers {
	my $self = $_[0];
	my $m = $_[1];

	if( ! defined $m ){ return $self->{'p'}->{'provider-objs'} }
	my $debug = $self->debug();
	if( ref($m) eq '' ){
		# we were given a string to search for that provider and return its data
		# return the exact provider if the pstr matches an id from our providers
		return($self->{'p'}->{'provider-objs'}->{$m})
			if exists($self->{'p'}->{'provider-objs'}->{$m});
		return undef # id given is not in our list
	} elsif( ref($m) eq 'ARRAY' ){
		# we were given an arrayref, presumably a list of providers
		# we need to find the package of each provider and load it,
		# that's why the contents of this array plus the package string below
		# must much exactly our installed provider packages
		my %providers = ();
		for my $aprovider (@$m){
			my $modulename = 'Statistics::Covid::DataProvider::'.$aprovider;
			my $modulefilename = File::Spec->catdir(split(/\:\:/, $modulename)).'.pm';
			if( ! Statistics::Covid::Utils::is_module_loaded($modulename) ){
				my $loadedOK = eval {
					require $modulefilename;
					$modulename->import;
					1;
				};
				if( ! $loadedOK ){ warn "error, failed to load module '$modulename' (file '$modulefilename'), does it exist?"; return undef }
			} else { if( $debug>0 ){ warn "module '$modulename' is already loaded and will not be loaded again" } }
			my $pparams = {
				'config-hash' => Storable::dclone($self->config()),
				'debug' => $debug,
				'save-to-file' => $self->save_to_file($aprovider),
			};
			if( exists $self->{'p'}->{'provider-extra-params'}->{$aprovider} ){
				# append to params hash extra provider params if exist for this provider
				@{$pparams}{keys %{$self->{'p'}->{'provider-extra-params'}->{$aprovider}}}
				  = values %{$self->{'p'}->{'provider-extra-params'}->{$aprovider}}
				;
				if( $debug>0 ){ warn "added extra parameters to provider '$aprovider': ".join(', ', keys %{$self->{'p'}->{'provider-extra-params'}->{$aprovider}}) }
			}
			my $providerObj = $modulename->new($pparams);
			if( ! defined $providerObj ){ warn "error, call to $modulename->new() has failed"; return undef }
			# the key to the providers can be the full package or just this bit
			# we prefer this bit (e.g. World::JHU)
			#$providers{$modulename} = $providerObj;
			$providers{$aprovider} = $providerObj;
			if( $debug > 0 ){ warn "provider constructed and added '$modulename':\n".$providerObj->toString() }
		}
		$self->{'p'}->{'provider-objs'} = \%providers;
	}
	return $self->{'p'}->{'provider-objs'} # that's the hash with the providers
}
sub     config {
	my $self = $_[0];
	my $m = $_[1];
	if( defined $m ){ $self->{'p'}->{'config-hash'} = $m; return $m }
	return $self->{'p'}->{'config-hash'}
}
sub     save_to_file {
	my $self = $_[0];
	my $pn = $_[1]; # provider name
	my $m = $_[2]; # 1 or 0 for on/off
	if( defined $m ){ $self->{'save-to-file'}->{$pn} = $m; return $m }
	return $self->{'save-to-file'}->{$pn}
}
sub     save_to_db {
	my $self = $_[0];
	my $pn = $_[1]; # provider name
	my $m = $_[1]; # 1 or 0 for on/off
	if( defined $m ){ $self->{'save-to-db'}->{$pn} = $m; return $m }
	return $self->{'save-to-db'}->{$pn}
}
# private subs
sub	_create_Datum_IO {
	my $self = $_[0];
	my $params = defined($_[1]) ? $_[1] : {}; # optional params
	my $io = Statistics::Covid::Datum::IO->new({
		'config-hash' => $self->config(),
		'debug' => $self->debug(),
		%$params
	});
	if( ! defined $io ){ warn "error, call to ".'Statistics::Covid::Datum::IO->new()'." has failed"; return undef }
	if( ! defined $io->db_connect() ){ warn "error, failed to connect to DB, call to ".'db_connect()'." has failed"; return undef }
	if( ! $io->db_is_connected() ){ warn "error, not connected to DB when it should be"; return undef }
	return $io;
}
sub	_create_Version_IO {
	my $self = $_[0];
	my $params = defined($_[1]) ? $_[1] : {}; # optional params
	my $io = Statistics::Covid::Version::IO->new({
		'config-hash' => $self->config(),
		'debug' => $self->debug(),
		%$params
	});
	if( ! defined $io ){ warn "error, call to ".'Statistics::Covid::Datum::IO->new()'." has failed"; return undef }
	if( ! defined $io->db_connect() ){ warn "error, failed to connect to DB, call to ".'db_connect()'." has failed"; return undef }
	if( ! $io->db_is_connected() ){ warn "error, not connected to DB when it should be"; return undef }
	return $io;
}
sub	_db_insert_bulk_returnvalue_toString {
	# $inhash is a hashref of what was inserted in db, what was replaced, what was omitted because identical
	my ($inhash, $rows_before, $rows_after) = @_;
	my $ret =
  "attempted a DB insert for ".$inhash->{'num-total-records'}." records in total, on ".DateTime->now(time_zone=>'UTC')->iso8601()." UTC:\n"
. "new records inserted                           : ".$inhash->{'num-virgin'}."\n"
. "  records outdated replaced                    : ".$inhash->{'num-replaced'}."\n"
. "  records not replaced because better exists   : ".$inhash->{'num-not-replaced-because-better-exists'}."\n"
. "  records not replaced because of no overwrite : ".$inhash->{'num-not-replaced-because-ignore-was-set'}."\n"
. "  records in DB before                         : ".$rows_before."\n"
. "  records in DB after                          : ".$rows_after."\n"
	;
	if( $inhash->{'num-failed'} > 0 ){ $ret .= "  records FAILED            : ".$inhash->{'num-failed'}."\n" }
	return $ret
}
1;
__END__
# end program, below is the POD
=pod

=encoding UTF-8

=head1 NAME

Statistics::Covid - Fetch, store in DB, retrieve and analyse Covid-19 statistics from data providers

=head1 VERSION

Version 0.24

=head1 DESCRIPTION

This module fetches, stores in a database, retrieves from a database and analyses
Covid-19 statistics from online or offline data providers, such as
from L<the Johns Hopkins University|https://www.arcgis.com/apps/opsdashboard/index.html#/bda7594740fd40299423467b48e9ecf6>
which I hope I am not obstructing (please send an email to the author if that is the case).

After specifying one or more data providers (as a url and a header for data and
optionally for metadata), this module will attempt to fetch the latest data
and store it in a database (SQLite and MySQL, only SQLite was tested so far).
Each batch of data should ideally contain information about one or more locations
and at a given point in time. All items in this batch are extracted and stored
in DB each with its location name and time (it was published, not fetched) as primary keys.
Each such data item (Datum) is described in L<Statistics::Covid::Datum::Table>
and the relevant class is L<Statistics::Covid::Datum>. It contains
fields such as: C<population>, C<confirmed>, C<unconfirmed>, C<terminal>, C<recovered>.

Focus was on creating a very high-level API and command line scripts
to distance the user as much as possible
from the nitty-gritty details of fetching data using L<LWP::UserAgent>,
cleaning the data, dealing with the database using L<DBI> and L<DBIx::Class>.

This is still considered an early release until the functionality and the table schemata
solidify.

Feel free to
share any modules you create on analysing this data, either
under the L<Statistics::Covid>
namespace (for example in L<Statistics::Covid::Analysis::MyModule>)
or any other you see appropriate.

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

=head1 SYNOPSIS

	use Statistics::Covid;
	use Statistics::Covid::Datum;

	# create the object for downloading data, parsing, cleaning
	# and storing to DB. If table is not deployed it will be deployed.
	# (tested with SQLite)
	$covid = Statistics::Covid->new({
		# configuration file (or hash)
		'config-file' => 't/config-for-t.json',
		#'config-hash' => {...}.,
		# known data providers
		# 'World::JHU' points to
		# https://www.arcgis.com/apps/opsdashboard/index.html#/bda7594740fd40299423467b48e9ecf6
		# it's a Johns Hopkins University site and contains world data since the
		# beginning as well as local data (states) for the US, Canada and China
		# 'World::JHUgithub' points to this:
		# https://github.com/CSSEGISandData/COVID-19
		# 'World::JHUlocaldir' is a local clone (git clone) of the above
		# because the online github has a limit on files to download
		# the best is to git-clone locally and use 'World::JHUlocaldir'
		# Then there are 2 repositories for UK statistics broken
		# into local areas.
		'providers' => ['UK::BBC', 'UK::GOVUK2',
		  'World::JHUlocaldir', 'World::JHUgithub',
		  'World::JHU'
		],
		# save fetched data locally in its original format (json or csv)
		# and also as a perl var
		'save-to-file' => 1,
		# save fetched data into the database in table Datum
		'save-to-db' => 1,
		# debug level affects verbosity
		'debug' => 2, # 0, 1, ...
	}) or die "Statistics::Covid->new() failed";

	# Do the download:
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
			admin0=>'UK',
			admin1=>'Hackney'
		}
	});

	print "Confirmed cases for ".$_->name()
		." on ".$_->date()
		." are: ".$_->confirmed()
		."\n"
	for (@$someObjs);

	# or for a single place (this sub sorts results wrt publication time)
	my $timelineObjs =
	  $covid->select_datums_from_db_time_ascending({
		'conditions' => {
			'admin1' => 'Hackney',
			'admin0' => 'UK',
		}
	  });

	# or for a wildcard match
	my $timelineObjs =
	  $covid->select_datums_from_db_time_ascending({
		'conditions' => {
			'admin1' => {'like'=>'Hack%'},
			'admin0' => 'UK',
		}
	  });

	# and maybe specifying max rows
	my $timelineObjs =
	  $covid->select_datums_from_db_time_ascending({
		'conditions' => {
			'admin1' => {'like'=>'Hack%'},
			'admin0' => 'UK',
		},
		'attributes' => {'rows' => 10}
	  });

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
	  $covid->select_datums_from_db_time_ascending(
		'conditions' => {
			# admin1 is a province, state
			# similarly admin2 can be a local authority but
			# that varies between countries and data providers
			#'admin1' =>{'like' => 'Ha%'},
			#'admin1' =>['Halton', 'Havering'],
			# the admin0 (could be a wildcard) is like a country name
			'admin0' => 'United Kingdom of Great Britain and Northern Ireland',
		}
	  );

	# create a dataframe (see L<Statistics::Covid::Utils/datums2dataframe>)
	$df = Statistics::Covid::Utils::datums2dataframe({
		# input data is an array of L<Statistics::Covid::Datum>'s
		# as fetched from providers or selected from DB (see above)
		'datum-objs' => $objs,

		# collect data from all those with same 'admin1' and same 'admin0'
		# and maybe plot this data as a single curve (or fit or whatever)
		# this will essentially create an entry for 'Hubei|China'
		# another for 'Italy|World', another for 'Hackney|UK'
		# etc. FOR all admin0/admin1 tuples in your
		# selected L<Statistics::Covid::Datum>'s
		'groupby' => ['admin0','admin1', 'admin2', 'admin3', 'admin4'],

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
		'GroupBy' => ['admin0', 'admin1'],

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
	# Fit a model to data
	# i.e. find the parameters of a user-specified
	# equation which can fit on all the data points
	# with the least error.
	# An exponential model is often used in the spread of a virus:
	# c1 * c2^x (c1 and c2 are the coefficients to be found / fitted)
	# 'x' is the independent variable and usually denotes time
	# in L<Statistics::Covid::Datum> is the 'datetimeUnixEpoch' field
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
	# actually exponential functions in a discrete computer don't like it.
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
	#		confirmed => [0, 0, 3, 4, 4, 5, 7, 7, 7, 8, 8, 8],
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



=head1 EXAMPLE SCRIPTS

C<script/statistics-covid-fetch-data-and-store.pl> is
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

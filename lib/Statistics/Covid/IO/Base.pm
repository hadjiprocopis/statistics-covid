package Statistics::Covid::IO::Base;

use 5.10.0;
use strict;
use warnings;

binmode STDERR, ':encoding(UTF-8)';
binmode STDOUT, ':encoding(UTF-8)';

use Data::Dump qw/pp/;
use Storable;
use File::Copy;
use File::Temp;

use Statistics::Covid::Utils;

our $VERSION = '0.24';

sub	new {
	my (
		$class,
		# Specify the Schema class, this is
		#   Statistics::Covid::Schema
		# and it is fixed for this application.
		$schema_package_name,

		# Specify the class we are doing IO for
		# it must be a child of: Statistics::Covid::IO::DualBase
		# and represents a class which stores its fields in memory
		# as well as in a table in DB (with the aid of DBIx::Class)
		# this can be:
		#    Statistics::Covid::Datum (for Datum table)
		# or
		#    Statistics::Covid::Version (for Version table)
		# (and more, as many as your tables in DB)
		$dual_package_name,

		# a hash of additional parameters, of which
		# config-file or config-hash are necessary
		$params
	) = @_;
	if( ! defined $dual_package_name ){ warn "error, a dual_package_name must be specified as the 2nd parameter (and schema_package_name as a 1st), 3rd parameter must be a parameters hash with at least a config-file or config-hash entry."; return undef }

	$params = {} unless $params;
	my $self = {
		'debug' => 0,
		'log-filename' => undef,

		# internal variables, nothing to see here:
		# what schema we are doing the IO for?
		# something like: 'Statistics::Covid::Schema' (as a string)
		'schema-package-name' => undef,
		# this is a string with the name of the package which acts as our dual
		# and contains all the data which must go to DB
		# e.g. Statistics::Covid::Datum
		'dual-package-name' => undef,
		# some 'our' vars in the dual package which should be already defined in here
		# e.g. the tablename, db spec, etc.
		'dual-package-vars' => undef,
		# a hash with our configuration as read from file or set via the config* subs
		# this reflects exactly the configuration json file (e.g. t/example-config.json)
		# with 'dbparams' as subhash
		'config-hash' => undef,
	};
	bless $self => $class;

	# we accept a debug level parameter>=0
	if( exists $params->{'debug'} ){ $self->debug($params->{'debug'}) }

	my $debug = $self->debug();

	if( ! defined $schema_package_name ){ warn "error, you need to specify a schema package name as a string, like 'Statistics::Covid::Schema'."; return undef }
	$self->{'schema-package-name'} = $schema_package_name;
	if( ! defined $dual_package_name ){ warn "error, you need to specify a dual-object package name as a string, like 'Statistics::Covid::Datum'."; return undef }
	$self->{'dual-package-name'} = $dual_package_name;
	if( $debug > 0 ){ warn "creating an IO object for inserting objects of type '$dual_package_name' into DB." }
	{
		no strict 'refs';
		die "table schema package '".$dual_package_name.'::Table::SCHEMA'."' can not be found, does it exist?"
			unless defined ${$dual_package_name.'::Table::SCHEMA'};
		$self->{'dual-package-vars'} = Storable::dclone(${$dual_package_name.'::Table::SCHEMA'});
		if( $debug > 0 ){ warn "loaded the table schema from ".$dual_package_name.'::Table::SCHEMA'."\n" }
	}

	# declare a log file to be used for db operations, you must additionally set debug>0
	if( exists $params->{'log-filename'} ){ $self->logfilename($params->{'log-filename'}) }

	# we accept config-file or config-hash, see t/example-config.json for an example
	if( exists $params->{'config-file'} ){ if( ! $self->config_file($params->{'config-file'}) ){ warn "error, call to config_file() has failed."; return undef } }
	elsif( exists $params->{'config-hash'} ){ if( ! $self->config($params->{'config-hash'}) ){ warn "error, call to config() has failed."; return undef } }
	else { warn "error, no configuration was specified via 'config-file' or 'config-hash'."; return undef }
	return $self;
}
# construct the db filename, if one is used (SQLite)
# returns undef on failure
# returns the db filename for the case of SQLite
# or an empty string for the case of MySQL
sub	db_filename {
	my $self = $_[0];
	my $dbparams = $self->dbparams();
	my $current_db_file = "";
	if( $dbparams->{'dbtype'} eq 'SQLite' ){
		if( exists $dbparams->{'dbdir'} and defined $dbparams->{'dbdir'} and $dbparams->{'dbdir'} ne '' ){
			$current_db_file = File::Spec->catdir($dbparams->{'dbdir'}, $dbparams->{'dbname'})
		} else { $current_db_file = $dbparams->{'dbname'} }
		return $current_db_file;
	} elsif( $dbparams->{'dbtype'} eq 'MySQL' ){ return $current_db_file }
	warn "don't know this dbtype '".$dbparams->{'dbtype'}."'.";
	return undef # failed
}
# does a backup of the DB
# it currently works for SQLite by copying it to a new file
# and returns that new file's filename
# for MySQL i did not want to shell out and use mysqldump
# so the commands to do that from a terminal/command prompt
# are printed and the program does not complain (but informs)
# it returns the backup filename on success
# or undef on failure
sub	db_create_backup_file {
	my $self = $_[0];
	# optional output file, or default
	my $outfile = defined($_[1]) ? $_[1] : Statistics::Covid::Utils::make_timestamped_string() . '.bak';

	my $dbparams = $self->dbparams();
	if( $dbparams->{'dbtype'} eq 'SQLite' ){
		my $current_db_file = "";
		if( exists $dbparams->{'dbdir'} and defined $dbparams->{'dbdir'} and $dbparams->{'dbdir'} ne '' ){
			$current_db_file = File::Spec->catdir($dbparams->{'dbdir'}, $dbparams->{'dbname'})
		} else { $current_db_file = $dbparams->{'dbname'} }
		if( ! File::Copy::copy($current_db_file, $outfile) ){ warn "error, failed to copy '$current_db_file' to '$outfile'."; return undef }
		return $outfile # success
	} elsif( $dbparams->{'dbtype'} eq 'MySQL' ){
		if( ! $self->db_is_connected() ){ warn "error, you must connect to db first (isn't there a better way to find the known Schema without connecting?"; return undef }
		my @tablenames = $self->schemah()->sources;
		my $cmd = 'mysqldump -R -h'.$dbparams->{'hostname'}
			.' --events --triggers'
			.' -u '.$dbparams->{'username'}
			.' --password='.$dbparams->{'password'}
			.' --routines --add-drop-database --set-gtid-purged=OFF --add-drop-table'
			.' "'.$dbparams->{'dbname'}.'"'
			.' "'.join('" "', @tablenames).'"' # all the table names related to this module
			.' > "'.$outfile.'"'
		;
		warn "I dare not shell out on your system, so run the following command from a terminal or a command prompt:\n\n$cmd\n";
		return $outfile
	}
	warn "don't know this dbtype '".$dbparams->{'dbtype'}."'.";
	return undef # failed
}
sub	schema_package_name { return $_[0]->{'schema-package-name'} }
sub	dual_package_name { return $_[0]->{'dual-package-name'} }
sub	dual_package_vars { return $_[0]->{'dual-package-vars'} }
sub     debug {
	my $self = $_[0];
	my $m = $_[1];
	return $self->{'debug'} unless defined $m;
	$self->{'debug'} = $m;
	return $m;
}
# sets the log filename and opens it if we are connected to DB for logging the DB operations
# it needs to set debug>1 to log
# if not connected it will not open the log file. It will be opened once db_connect() is called
# and each time db_connect() is called.
# db_disconnect() closes the log handle.
sub     logfilename {
	my $self = $_[0];
	my $m = $_[1];
	return $self->{'log-filename'} unless defined $m;
	$self->{'log-filename'} = $m;
	return undef unless defined $m;
	return $m unless $self->db_is_connected();

	# only if we are connected to a db
	# this will close existing log handle and open the new one
	# if log-filename is defined and also we are connected to DB
	# it will only complain if the log file could not be opened for writing
	if( 0 == _init_log_file($self->schemah(), $m) ){ warn "call to ".'_init_log_file()'." has failed for file '$m'."; return undef }
	return $m;
}
# returns 0 on failure (i.e. can't open output file)
# returns 1 on success
# returns 2 if not connected yet to DB
sub	_init_log_file {
	my ($schemah, $logfilename) = @_;
	return 2 unless defined $schemah;

	my $fh = $schemah->debugfh();
	close($fh) if defined $fh;
	$fh = IO::File->new($logfilename,'w');
	if( ! defined $fh ){ warn "failed to open log file '$logfilename' for writing, $!"; return 0 }
	$schemah->debugfh($fh);
	return 1 # success
}
sub	schemah { return $_[0]->dbparams()->{'schemah'} }
sub     dbparams { return $_[0]->config()->{'dbparams'} }
sub     fileparams { return $_[0]->config()->{'fileparams'} }
# reads json data from file which represents the configuration settings
# for this module. It contains a 'fileparams' and a 'dbparams' section
# each with their own sub-sections and options (like dbtype, dbname, password, username, hostname, port)
# any of these can also be inserted in $self->dbparams()->{'password'} for example
# returns 0 on failure, 1 on success
# NOTE: it does not eval, it slurps the file and then converts json content to perl hash
# NOTE2: the configuration file DOES accept COMMENTS (unlike json) which are discarded
# if you have config hash then just use config($hash)
sub	config_file {
	my ($self, $infile) = @_;
	my $inhash = Statistics::Covid::Utils::configfile2perl($infile);
	if( ! defined $inhash ){ warn "error, call to ".'Statistics::Covid::Utils::configfile2perl()'." has failed for file '$infile'."; return 0 }
	if( ! $self->config($inhash) ){ warn "error, call to ".'$self->config()'." has failed for configuration file '$infile'."; return undef }
	return 1 # success
}
sub	config {
	my ($self, $m) = @_;
	return $self->{'config-hash'} unless defined $m;

	my $debug = $self->debug();

	if( ! exists($m->{'dbparams'}) || ! defined($m->{'dbparams'}) ){ warn pp($m)."\n\neerror, no 'dbparams' section exists in configuration (dumped above)."; return undef }
	if( ! exists($m->{'fileparams'}) || ! defined($m->{'fileparams'}) ){ warn pp($m)."\n\nerror, no 'fileparams' section exists in configuration (dumped above)."; return undef }

	$self->{'config-hash'} = Storable::dclone($m);

	my $dbparams = $m->{'dbparams'};

	# do we have dbi-connect-params or shall we use defaults?
	if( ! exists($dbparams->{'dbi-connect-params'}) || ! defined($dbparams->{'dbi-connect-params'}) ){
		$dbparams->{'dbi-connect-params'} = {RaiseError => 1, PrintError => 0}
	}
	if( $dbparams->{'dbtype'} eq 'SQLite' ){
		# in SQLite we have an optional path before the db-filename, using unix-pathsep
		if( exists $dbparams->{'dbdir'} and defined $dbparams->{'dbdir'} and $dbparams->{'dbdir'} ne '' ){
			if( ! Statistics::Covid::Utils::make_path($dbparams->{'dbdir'}) ){ warn "error, failed to create data dir '".$dbparams->{'dbdir'}."'."; return 0 }
			if( $self->debug() > 0 ){ warn "checked and/or made dir for db files'".$dbparams->{'dbdir'}."'." }
		}
	}
	my $fileparams = $self->{'config-hash'}->{'fileparams'};
	if( ! exists $fileparams->{'datafiles-dir'} or ! defined $fileparams->{'datafiles-dir'} ){ $fileparams->{'datafiles-dir'} = '.' }
	else {
		# now make sure target dir is created already or create it
		# make the output datadir
		if( ! Statistics::Covid::Utils::make_path($fileparams->{'datafiles-dir'}) ){ warn "error, failed to create data dir '".$fileparams->{'datafiles-dir'}."'."; return 0 }
		if( $self->debug() > 0 ){ warn "checked and/or made dir for data files '".$fileparams->{'datafiles-dir'}."'." }
	}
	if( $debug > 0 ){ warn pp($self->{'config-hash'})."\nset config as above" }
	return 1 # success
}
# make a dsn for connecting to DB
# input is a hash of params, including 'dbname' and 'dbtype' (also password, hostname, port if necessary)
# returns the dsn string on success or undef on failure
sub     db_make_dsn {
	my $self = $_[0];
	my $dsn = Statistics::Covid::Utils::db_make_dsn({'config-hash'=>$self->config()});
	if( ! defined $dsn ){ warn "error, call to ".'Statistics::Covid::Utils::db_make_dsn()'." has failed"; return undef }
	return $dsn;
}
sub	db_is_connected { return defined $_[0]->schemah() }
# creates or re-creates the table we are associated with
# if 'drop-table' is added in the input params, then if table exists it will be erased
# with all its data and the new table will be created
# there is no use for external use unless you want to recreate the database because
# of a table schema change.
# if it is not connected already it connects to db
# at the end if successful it attempts to re-connect to db
# WARNING: before using this sub
#  !!!!! make a backup first L<Statistics::Covid::IO::Base::db_create_backup_file>
sub	db_deploy {
	my $self = $_[0];
	my $params = $_[1]; # optional params hash

	my $debug = $self->debug();

	my $drop_table_first = 0;
	if( defined $params ){
		if( exists($params->{'drop-table'}) && defined($params->{'drop-table'}) ){
			$drop_table_first = $params->{'drop-table'}
		}
	}

	if( ! $self->db_is_connected() ){ if( ! $self->db_connect() ){ warn "error, failed to connect to db"; return 0 } }

	my $dbparams = $self->dbparams();
	if( $debug > 0 ){ if( $drop_table_first>0 ){ warn "dropping existing table if exists ..." } warn "creating table '".$self->dual_package_vars()->{'tablename'}."' ..." }
	my $rc = eval { $dbparams->{'schemah'}->deploy({ add_drop_table => $drop_table_first }); 1 };
	if( $@ || ! $rc ){ warn "error, call to deploy() has failed for table '".$self->dual_package_vars()->{'tablename'}."'"; return 0 }
	$self->db_disconnect();
	# db_connect() automatically and by default
	# will try to deploy and a deep recursion will ensue, so deploy=0 explicitly
	if( ! $self->db_connect({'deploy'=>0}) ){ warn "error, failed to re-connect to database"; return 0 }
	return 1 # success and we are db-connected
}
# connect to db
# input is a hash of params, including 'dbname' and 'dbtype' (also password, hostname, port if necessary)
# returns the connection handle on success or undef on failure
# caller must disconnect from db ($dbh->disconnect()) when finished with it.
# if called while a connection SEEMS to be valid, that connection is returned and nothing else happens
# if you want to force a new connection then disconnect first.
sub     db_connect {
	my $self = $_[0];
	my $params = $_[1]; # optional params hash

	#if( defined $params ){
	#	if( exists($params->{'disconnect-first'}) && defined($params->{'disconnect-first'}) ){
	#		$force_disconnect_first = $params->{'disconnect-first'}
	#	}
	#}

	my $dbparams = $self->dbparams();

	my $debug = $self->debug();

	if( $self->db_is_connected() ){ return $dbparams->{'schemah'} }

	my $dsn = $self->db_make_dsn($dbparams);
	if( ! defined $dsn ){ warn "call to ".'db_make_dsn()'." has failed."; return undef }

	my $schemaHandle;
	$schemaHandle = eval { Statistics::Covid::Schema->connect($dsn, "", "", $dbparams->{'dbi-connect-params'}) };
	if( $@ or ! defined($schemaHandle) or $schemaHandle->storage==1 ){ warn pp($dbparams->{'dbi-connect-params'})."\n".'Statistics::Covid::Schema->connect('.$dsn.') has failed for above parameters: $@'; return undef }
	$dbparams->{'schemah'} = $schemaHandle;

	if( $debug > 1 ){
		$schemaHandle->storage->debug($debug);
		warn "DBIx::Class : debug ON (level $debug)."
	}
	my $m = $self->logfilename();
	if( $m ){
		# this will close existing log handle and open the new one
		# if log-filename is defined and also we are connected to DB
		# it will only complain if the log file could not be opened for writing
		if( 0 == _init_log_file($schemaHandle, $m) ){ warn "call to ".'_init_log_file()'." has failed for file '$m'."; return undef }
		if( $debug > 0 ){ warn "logging to file '$m'." }
	}
	# optionally deploy, default is yes unless input params say otherwise
	if( (exists($params->{'deploy'})
	     && defined($params->{'deploy'})
	     && ($params->{'deploy'}>0)
	    ) || (
	   ! exists($params->{'deploy'}) || ! defined($params->{'deploy'})
	   )
	   && (0 == $self->db_is_deployed())
	){
		# the table does not exist => we deploy the db (and that's that!)
		if( $debug > 0 ){ warn "creating table '".$self->dual_package_vars()->{'tablename'}."'..." }
		if( ! $self->db_deploy() ){ warn "error, call to ".'db_deploy()'." has failed"; return undef }
	}
	if( $debug > 0 ){ warn pp($dbparams->{'dbi-connect-params'})."\nConnected to database using dsn='$dsn' and DBI connection parameters as above" }
	$dbparams->{'dsn'} = $dsn;
	return $schemaHandle
}
# returns true if db is deployed (created)
# must already be connect to db
sub	db_is_deployed {
	my $self = $_[0];
	if( ! $self->db_is_connected() ){ warn "error, not connected to any database."; return -1 }

	return Statistics::Covid::Utils::table_exists_dbix_class(
		$self->schemah(),
		$self->dual_package_vars()->{'tablename'}
	)
}
# erases all rows in the given table of the database
# it returns the number of rows deleted (can be zero) on success
# or -1 on failure
sub	db_clear { return $_[0]->db_delete_rows() }

# deletes those rows in DB which match the L<SQL::Abstract> search
# conditions and attributes, optionally specified in the input params
# C<$params->{'conditions'}> and C<$params->{'attributes'}>
# WARNING: If no conditions and/or attributes are specified ALL rows in DB will be deleted.
# In the latter case one may call C<db_clear()> as a mnemonic shortcut.
# it returns the number of rows deleted (can be zero) on success
# or -1 on failure
sub	db_delete_rows {
	my $self = $_[0];
	my $params = $_[1];

	if( ! $self->db_is_connected() ){ warn "error, not connected to any database."; return -1 }

	$params = {} unless $params;
	# params optionally contains 'conditions' something like:
#  my $rs = $schema->resultset('Album')->search({
#    title   => 'abc'
# or
#    title   => {-like     => 'foo', -not_like => 'bar' }
# and
#    artist  => { '!=', 'Janis Joplin' },
#    year    => { '<' => 1980 },
#    albumid => { '-in' => [ 1, 14, 15, 65, 43 ] }
# also there is chaining:
# '-and' => [ #<<< notice the quoting
#   { title => 'abc' }
#   { year => 2000 }
# ]
# '-or' => ...
# date to be between date1 and date2
#   date => { '>=' => $date1, '<=' => $date2 }
	my $conditions = (exists $params->{'conditions'} and defined $params->{'conditions'}) ? $params->{'conditions'} : {};

	# params optionally contains attributes as a hashref
	# for example:
	#   specify maximum rows ({rows=>3}), order_by (e.g. order_by => { -desc => 'year' }) etc.
	my $attributes = (exists $params->{'attributes'} and defined $params->{'attributes'}) ? $params->{'attributes'} : {};
	# params can contain a debug level integer:
	my $debug = (exists $params->{'debug'} and defined $params->{'debug'}) ? $params->{'debug'} : $self->debug();

	my $dbparams = $self->dbparams();
	my $schemah = $dbparams->{'schemahs'};
	my $RS = $dbparams->{'schemah'}->resultset($self->dual_package_vars()->{'tablename'});
	if( ! defined $RS ){ warn "error, failed to create a resultset object."; return -1 }

	my $searcher = $RS->search($conditions, $attributes);
	if( $debug > 0 ){ warn "deleting all rows found with ".${$searcher->as_query()}->[0]."\n" }
	my $num_to_delete = $searcher->count;
	$searcher->delete_all() if $num_to_delete>0;
	return $num_to_delete
}
# Inserts a lot of Objects into DB (first parameter is an array)
# the 1st param is this array of datum objs
# It returns undef on failure to connect to DB or other DB problem
# otherwise, it returns a hashref with statistics (either it did insert or failed to insert)
# the returned hashref will contain entries to tell caller how many records failed to be inserted
# or did not replace already existing duplicates in DB, see at the end for the hashref structure
# this is bound to be slow but we need to check on duplicates in DB ...
sub	db_insert_bulk {
	my $self = $_[0];
	my $arrayOfobjToInsert = $_[1]; # arrayref with object(s) to insert
	# optional, else we look into config hash, or default below
	my $replace_strategy = $_[2];

	if( ! $self->db_is_connected() ){ warn "error, not connected to any database."; return undef }

	my $debug = $self->debug();

	if( ($debug > 0) && defined($replace_strategy) ){ print STDOUT "db_insert_bulk() : overwriting replace strategy with this: '$replace_strategy' ...\n" }

	my $ret = 1;
	my $num_failed = 0;
	my $num_virgin = 0;
	my $num_replaced = 0;
	my $num_not_replaced_because_better_exists = 0;
	my $num_not_replaced_because_ignore_was_set = 0;

	# first of all remove those objs which are duplicates
	my %objs_by_uidpk = ();
	my $hasduplicates = 0;
	my ($uidpk, $anotherobj);
	for my $anobj (@$arrayOfobjToInsert){
		$uidpk = $anobj->unique_id_based_on_primary_key();
		if( exists $objs_by_uidpk{$uidpk} ){
			$anotherobj = $objs_by_uidpk{$uidpk};
			if( $debug > 0 ){ warn "warning, found duplicate records within the array of objects to return with common uidpk=\n  $uidpk\nThe newer will be inserted in DB (now no action will be taken)\n   ".$anotherobj->toString()."\nand\n   ".$anobj->toString() }
			$hasduplicates++;
			if( $anobj->newer_than($anotherobj) == 1 ){ $objs_by_uidpk{$uidpk} = $anobj }
		} else { $objs_by_uidpk{$uidpk} = $anobj }
	}
	if( ($debug>0) && $hasduplicates ){ warn "found $hasduplicates duplicates among the objects in the input array specified." }
	# now our hash contains non-duplicates, and so we insert it
	# but enclose all this into a transaction so that it's faster
	# it looks that this guard has an effect over the db_insert() sub which does all the inserting
	# we commit at the end of the loop
	my $guard = $self->dbparams()->{'schemah'}->txn_scope_guard;

	my $numobjs = scalar(@$arrayOfobjToInsert);
	for my $anobj (@$arrayOfobjToInsert){
		$ret = $self->db_insert($anobj, $replace_strategy);
		# see also db_insert() return codes
		if( $ret == 0 ){
			# failed to insert, db problem
			$num_failed++;
			warn $anobj->toString()."\nerror, call to ".'db_insert()'." has failed for above Datum object."
		} elsif( $ret == 1 ){
			# inserted OK, no previous duplicate record existed
			$num_virgin++;
		} elsif( $ret == 2 ){
			# replaced existing duplicate (by PK) either because we had nore up-to-date
			# data (i.e. greater markers), or because the 'force' flag was on
			$num_replaced++;
		} elsif( $ret == 3 ){
			# nothing inserted/replaced although a duplicate exists in DB and is either identical or worst
			$num_not_replaced_because_better_exists++;
		} elsif( $ret == 4 ){
			# nothing inserted/replace because exists in db fullstop (we don't compare markers, 'ignore' was set)
			$num_not_replaced_because_ignore_was_set++;
		} else { die "unknown return code $ret from db_insert()" }
	}
	if( $debug > 0 ){ print STDOUT "db_insert_bulk() : num failed: $num_failed, 1st-time-inserted: $num_virgin, replaced: $num_replaced, not-replaced: $num_not_replaced_because_better_exists.\n" }

	# commit results to DB as we enclosed the inserts into a transaction for efficiency
	$guard->commit;

	return {
		'num-total-records' => $numobjs,
		'num-failed' => $num_failed,
		'num-virgin' => $num_virgin,
		'num-replaced' => $num_replaced,
		'num-not-replaced-because-better-exists' => $num_not_replaced_because_better_exists,
		'num-not-replaced-because-ignore-was-set' => $num_not_replaced_because_ignore_was_set,
		'num-duplicates-in-input' => $hasduplicates
	}
}
# Inserts one object into DB (first and only input parameter)
# it will optionally REPLACE already existing record in db if:
#    'replace-existing-db-record' = 'only-better' was set AND any of the markers is greater than existing
# or will optionally REPLACE already existing record in db if:
#    'replace-existing-db-record' = 'replace' was set in input params
# it will optionally NOT REPLACE existing DB record (irrespective of markers) if
#    'replace-existing-db-record' = 'ignore' was set in input params
# returns 0 on failure
# returns 1 if inserted OK and nothing existed there
# returns 2 if replaced existing entry because db had less markers or because it was forced
# returns 3 if not inserted/replace because identical or better exists in DB with greater markers, this is still considered success
# returns 4 if not inserted/replace because exists in db fullstop (we don't compare markers, 'ignore' was set)
sub	db_insert {
	my $self = $_[0];
	my $objToInsert = $_[1];
	# optional, else we look into config hash, or default below
	my $replace_strategy = $_[2];

	if( ! $self->db_is_connected() ){ warn "error, not connected to any database."; return 0 }

	my $debug = $self->debug();

	my $dbparams = $self->dbparams();

	if( ! defined $replace_strategy ){
		$replace_strategy = 'ignore';
		if( exists $dbparams->{'replace-existing-db-record'} and defined($dbparams->{'replace-existing-db-record'}) ){
			$replace_strategy = $dbparams->{'replace-existing-db-record'};
			if( $debug > 1 ){ warn "setting replace strategy to '".$dbparams->{'replace-existing-db-record'}."'." }
		}
	}

	##################################
	# this is how to print db row obj
	#Statistics::Covid::Utils::dbixrow2string($existingObj->get_columns())
	##################################

	my $resultset = $dbparams->{'schemah'}->resultset($self->dual_package_vars()->{'tablename'});
	if( ! defined $resultset ){ warn "error, failed to create a resultset object."; return 0 }
	my $ret = -1;
	my ($rc, $existingObj);
	if( $replace_strategy eq 'replace' ){
		# updates if duplicate exists or creates a new one which we must insert() manually
		my $existingObj = eval { $resultset->update_or_new($objToInsert->toHashtable()) };
		if( $@ ){ warn "error, call to ".'update_or_new()'." has failed with this exception: $@"; $ret=0; goto RET }
		if( $existingObj->in_storage ){
			# in db and updated (forcibly)
			if( $debug > 1 ){ if( $debug > 2 ){ warn "in DB:\n".pp($existingObj->toHashtable())."in memory:\n".pp($objToInsert->toHashtable()) } warn "duplicate record exists and forcibly updated with in-memory (replace_strategy=$replace_strategy)."; }
			$ret = 2;
		} else {
			# nothing like it exists in db
			$rc = eval { $existingObj->insert(); 1; };
			if( $@ || ! $rc ){ warn pp($objToInsert->toHashtable())."\ninsert() error for above data."; $ret=0; goto RET }
			if( $debug > 1 ){ warn "record inserted, no duplicate found (1) (replace_strategy=$replace_strategy)."; }
			$ret = 1;
		}
	} elsif( $replace_strategy eq 'only-better' ){
		# if it exists in DB, examine it and check if its markers are same or better than us
		# in which case we do not update
		my $existingObj = eval { $resultset->find_or_new($objToInsert->toHashtable()) };
		if( $@ ){ warn "error, call to ".'find_or_new()'." (1) has failed with this exception: $@"; $ret=0; goto RET }
		
		if( $existingObj->in_storage ){
			# it exists in db, let's compare markers
			if( 1 == $objToInsert->newer_than($existingObj) ){
				# our memory obj is bigger than one in DB we need to insert it
				$rc = eval { $existingObj->update(); 1; };
				if( $@ || ! $rc ){ warn pp($objToInsert->toHashtable())."\nupdate() error for above data."; $ret=0; goto RET }
				if( $debug > 1 ){ if( $debug > 2 ){ warn "in DB:\n".Statistics::Covid::Utils::dbixrow2string($existingObj->get_columns())."in memory:\n".pp($objToInsert->toHashtable()) } warn "duplicate record exists but is not-up-to-date compared to that in-memory, so it was updated (replace_strategy=$replace_strategy)."; }
				$ret = 2;
			} else {
				if( $debug > 1 ){ if( $debug > 2 ){ warn "in DB:\n".Statistics::Covid::Utils::dbixrow2string($existingObj->get_columns())."in memory:\n".pp($objToInsert->toHashtable()) } warn "duplicate exists but is up-to-date, so it was not updated (replace_strategy=$replace_strategy)."; }
				$ret = 3; # not inserted in db because existing is better
			}
		} else {
			# nothing like it exists in db
			# uncomment this to tackle DB warnings
			#local $SIG{__WARN__} = sub { print pp($objToInsert->toHashtable())."\n"; die "DDDDDDDDDD: ".$_[0]};
			$rc = eval { $existingObj->insert(); 1; };
			if( $@ || ! $rc ){ warn pp($objToInsert->toHashtable())."\ninsert() error for above data."; $ret=0; goto RET }
			if( $debug > 1 ){ warn "record inserted, no duplicate found (2) (replace_strategy=$replace_strategy)."; }
			$ret = 1;
		}
	} else { # this is $replace_strategy eq 'ignore'
		my $existingObj = $resultset->find_or_new($objToInsert->toHashtable());
		if( $@ ){ warn "error, call to ".'find_or_new()'." (2) has failed with this exception: $@"; $ret=0; goto RET }
		if( $existingObj->in_storage ){
			# it exists in db, we don't re-insert
			$ret = 4;
			if( $debug > 1 ){ if( $debug > 2 ){ warn "in DB:\n".Statistics::Covid::Utils::dbixrow2string($existingObj->get_columns())."in memory:\n".pp($objToInsert->toHashtable()) } warn "duplicate found, nothing was compared, nothing was inserted (replace_strategy=$replace_strategy)."; }
		} else {
			$rc = eval { $existingObj->insert(); 1; };
			if( $@ || ! $rc ){ warn pp($objToInsert->toHashtable())."\ninsert() error for above data."; $ret=0; goto RET }
			if( $debug > 1 ){ warn "record inserted, no duplicate found (3) (replace_strategy=$replace_strategy)."; }
			$ret = 1;
		}
	}
RET:
	die "why ret==-1?" if $ret == -1;
	return $ret
}
# returns the count of the rows matched the optional criteria (conditions)
# specified in the input parameters ($params)
# and returns the count on success (can also be zero)
# or returns -1 on failure
sub	db_count {
	my $self = $_[0];
	my $params = $_[1]; # optional

	if( ! $self->db_is_connected() ){ warn "error, not connected to any database."; return -1 }

	$params = {} unless $params;
	# params optionally contains 'conditions' something like:
#  my $rs = $schema->resultset('Album')->search({
#    title   => 'abc'
# or
#    title   => {-like     => 'foo', -not_like => 'bar' }
# and
#    artist  => { '!=', 'Janis Joplin' },
#    year    => { '<' => 1980 },
#    albumid => { '-in' => [ 1, 14, 15, 65, 43 ] }
# also there is chaining:
# '-and' => [ #<<< notice the quoting
#   { title => 'abc' }
#   { year => 2000 }
# ]
# '-or' => ...
# date to be between date1 and date2
#   date => { '>=' => $date1, '<=' => $date2 }
	my $conditions = (exists $params->{'conditions'} and defined $params->{'conditions'}) ? $params->{'conditions'} : {};

	# params optionally contains attributes as a hashref
	# for example:
	#   specify maximum rows ({rows=>3}), order_by (e.g. order_by => { -desc => 'year' }) etc.
	my $attributes = (exists $params->{'attributes'} and defined $params->{'attributes'}) ? $params->{'attributes'} : {};
	# params can contain a debug level integer:
	my $debug = (exists $params->{'debug'} and defined $params->{'debug'}) ? $params->{'debug'} : $self->debug();

	my $dbparams = $self->dbparams();
	my $schemah = $dbparams->{'schemah'};
	my $RS = $dbparams->{'schemah'}->resultset($self->dual_package_vars()->{'tablename'});
	if( ! defined $RS ){ warn "error, failed to create a resultset object."; return -1 }

	my $searcher = $RS->search($conditions, $attributes);
	if( $debug > 1 ){ warn "searching with ".${$searcher->as_query()}->[0]."\n" }
	return $searcher->count # success but can be zero!
}
# find records given optional conditions (where statements)
# $params can optionally contain 'conditions' and 'attributes'
# it returns an array (can be empty) of our Dual objects (i.e. Datum or Version)
# which are instantiated with data from one row of the DB
# returns undef on failure.
sub	db_select {
	my $self = $_[0];
	my $params = $_[1];

	if( ! $self->db_is_connected() ){ warn "error, not connected to any database."; return undef }

	$params = {} unless $params;
	# params optionally contains 'conditions' something like:
#  my $rs = $schema->resultset('Album')->search({
#    title   => 'abc'
# or
#    title   => {-like     => 'foo', -not_like => 'bar' }
# and
#    artist  => { '!=', 'Janis Joplin' },
#    year    => { '<' => 1980 },
#    albumid => { '-in' => [ 1, 14, 15, 65, 43 ] }
# also there is chaining:
# '-and' => [ #<<< notice the quoting
#   { title => 'abc' }
#   { year => 2000 }
# ]
# '-or' => ...
# date to be between date1 and date2
#   date => { '>=' => $date1, '<=' => $date2 }
	my $conditions = (exists $params->{'conditions'} and defined $params->{'conditions'}) ? $params->{'conditions'} : {};

	# params optionally contains attributes as a hashref
	# for example:
	#   specify maximum rows ({rows=>3}), order_by (e.g. order_by => { -desc => 'year' }) etc.
	my $attributes = (exists $params->{'attributes'} and defined $params->{'attributes'}) ? $params->{'attributes'} : {};
	# params can contain a debug level integer:
	my $debug = (exists $params->{'debug'} and defined $params->{'debug'}) ? $params->{'debug'} : $self->debug();

	my $dbparams = $self->dbparams();
	my $schemah = $dbparams->{'schemah'};
	my $RS = $dbparams->{'schemah'}->resultset($self->dual_package_vars()->{'tablename'});
	if( ! defined $RS ){ warn "error, failed to create a resultset object."; return undef }

	my $searcher = $RS->search($conditions, $attributes);
	if( $debug > 1 ){ warn "searching with ".${$searcher->as_query()}->[0]."\n" }
	my @results;
	my $dual_package_name = $self->dual_package_name();
	while( 1 ){
		my $arow = eval { $searcher->next };
		if( $@ ){ warn "error, search failed for this dsn '".$dbparams->{'dsn'}."' with this exception:\n".$@; return undef }
		if( ! defined $arow ){ last }
		my $objparams = {$arow->get_columns()};
		if( $debug > 2 ){ warn "creating an object of type '$dual_package_name'..." }
		my $datumobj = $dual_package_name->new($objparams);
		if( ! defined $datumobj ){ warn pp($objparams)."\n\nerror, call to $dual_package_name".'->new()'." has failed for above parameters."; return undef }
		push @results, $datumobj
	}
	return \@results # returns an array of Datum objects, can be empty.
}
# disconnects from DB if it is already connected else ignored
# it returns 1 in any case.
sub	db_disconnect {
	my $self = $_[0];
	my $dbparams = $self->dbparams();
	if( $self->db_is_connected() ){
		$dbparams->{'schemah'}->storage()->disconnect();
		my $m = $self->logfilename();
		my $debug = $self->debug();
		if( $m ){
			$dbparams->{'schemah'}->storage()->debugfh(undef); # I guess that closes it
			if( $debug > 0 ){ warn "stopped logging to file '$m'." }
		}
		if( $debug > 0 ){ warn "db_disconnect() : disconnected from DB." }
	}
	$dbparams->{'schemah'} = undef;
	$dbparams->{'dsn'} = undef;
	return 1
}
# return an arrayref of all table names in the db we are connected to
sub	db_get_all_tablenames {
	my $self = $_[0];
	if( ! $self->db_is_connected() ){ warn "error, not connected to any database."; return undef }
	return [$self->schemah()->sources]
}
# Get our database schema and return it as a hashref where key=dbtype and value=schema as a string
# must be already connected to db (via L<db_connect()>)
# optionally specify the following in the input parameters hashref
# *** 'outdir' an output dir where to dump SQL files as well
# their filename will be formed with our Schema class (L<Statistics::Covid::Schema>)
# our current module version (found in $VERSION of present file)
# and the database type (e.g. 'SQLite', 'Pg', 'MySQL')
# can be used with 'outfile' too.
# *** 'dbtypes' is an arrayref of database type strings. A schema file will be
# created for each of these databases. Default is our current database type
# as contained in the configuration set during construction
# *** 'outfile' is an optional local file to dump all schemas into
# can be used with 'outdir' too.
# it will return undef on failure
sub	db_get_schema {
	my $self = $_[0];
	my $params = $_[1];

	my $debug = $self->debug();

	if( ! $self->db_is_connected() ){ warn "error, not connected to any database."; return undef }

	my $outdir = exists($params->{'outdir'}) ? $params->{'outdir'} : undef;
	if( ! defined $outdir ){
		# we create a tmp dir
		$outdir = File::Temp::tempdir(CLEANUP=>1);
	}
	if( ! -e $outdir ){
		if( ! Statistics::Covid::Utils::make_path($outdir) ){ warn "error, failed to create output dir '$outdir'."; return undef }
		if( $debug > 0 ){ warn "created output dir '$outdir'." }
	}
	# optional db types, e.g. SQLite, MySQL, Pg
	# default is to use our own dbtype as found in the loaded config during construction
	my $dbtypes = exists($params->{'dbtypes'}) ? $params->{'dbtypes'} : [$self->dbparams()->{'dbtype'}];

	my $rc;
	# i assume it throws exception
	for my $adbtype (@$dbtypes){
		$rc = eval { $self->schemah()->create_ddl_dir([$adbtype], $VERSION, $outdir); 1 };
		if( $@ || ! $rc ){ warn "error, call to create_ddl_dir() has failed for db type '$adbtype', $@"; return undef }
		if( $debug > 0 ){ warn "dumped schemata for '$adbtype' to '$outdir'" }
	}

	# optional file to save ALL schemas (all schemas in one file)
	# separated by '-'x29
	my $outfile = exists($params->{'outfile'}) ? $params->{'outfile'} : undef;
	my $outfh = undef;
	if( defined $outfile ){
		if( ! open($outfh, '>:encoding(UTF-8)', $outfile) ){ warn "error, failed to open output file '$outfile', $!"; return undef }
	}
	# now for each datatype we have the following file in outdir
	#    Statistics-Covid-Schema-<VERSION>-<DBTYPE>.sql
	# read each of these files and return them bundled in a hashtable keyed on dbtype
	my %ret;
	for my $adbtype (@$dbtypes){
		my $infile = File::Spec->catfile($outdir, 'Statistics-Covid-Schema-'.$VERSION.'-'.$adbtype.'.sql');
		my $fh;
		if( ! open($fh, '<:encoding(UTF-8)', $infile) ){ warn "error, failed to open just created SQL file '$infile' for reading, $!"; return undef }
		my $contents = undef;
		{local $/=undef; $contents = <$fh> } close $fh;
		$ret{$adbtype} = $contents;
		if( defined $outfile ){ print $outfh $contents."\n".('-'x29)."\n" }
		if( $debug > 0 ){ warn "created schema for database type '$adbtype'." }
	}
	if( defined $outfile ){ close($outfh); warn "dumped all schemata to one single file '$outfile'." }

	# if used a tmp outdir, it is erased on out-scope
	return \%ret
}
# TODO
# there are now migration scripts, this is not needed or could be part of a high-level api
sub	db_migrate_from_different_database {
	my $self = $_[0];
	my $params = $_[1];

	my $other_confighash;
	if( exists($params->{'other-config-hash'}) && defined($params->{'other-config-hash'}) ){
		$other_confighash = $params->{'other-config-hash'};
	} elsif( exists($params->{'other-config-file'}) && defined($params->{'other-config-file'}) ){
		my $configfile = $params->{'other-config-file'};
		if( ! defined($other_confighash=Statistics::Covid::Utils::configfile2perl($configfile)) ){ warn "error, failed to read and/or parse configuration file '$configfile'"; goto FAIL }
	} else { warn "error, either 'other-config-file' or 'other-config-hash' must be specified"; return undef }

	my $other_dbh = Statistics::Covid::Utils::db_connect_using_dbi({'config-hash'=>$other_confighash});
	if( ! defined $other_dbh ){ warn pp($other_confighash)."\nerror, call to ".'Statistics::Covid::Utils::db_connect_using_dbi()'." has failed for above configuration"; return undef }


FAIL:
	if( defined $other_dbh ){ $other_dbh->disconnect() }
	return undef # failed
}

1;

package Statistics::Covid::Utils;

# various stand-alone utils (static subs so-to-speak)

use 5.10.0;
use strict;
use warnings;

use utf8;

our $VERSION = '0.23';

our $DATAFRAME_KEY_SEPARATOR = '||';
# when we convert dates, must be in this range
our $DATE_CONVERTER_CHECK_MIN_DATE = '1570954887'; #2019_10_13 11:21:27
our $DATE_CONVERTER_CHECK_MAX_DATE = '1695954887'; #2023_09_29 05:34:47

use DateTime;
use DateTime::Format::Strptime;
use File::Path;
use Encode qw( encode_utf8 );
use JSON qw/decode_json encode_json/;
#use JSON::Parse qw/parse_json/;
use File::Find;
use Text::CSV_XS;
use Graphics::Color::RGB;
use Data::Dump qw/dump pp/;
use DBI;
use Devel::StackTrace;
use Data::Roundtrip;

our $DEBUG = 0;
sub	stacktrace { warn Devel::StackTrace->new->as_string }
sub	mypp { return Data::Roundtrip::perl2dump($_[0], {'dont-bloody-escape-unicode'=>1}) }

sub	db_dump {
	my $params = defined($_[0]) ? $_[0] : {};

	my ($dbtype, $dbh, $outfile, $outfh);
	my $add_drop_table_statement = 0;
	my $must_disconnect = 0;
	if( exists($params->{'outfile'}) && defined($params->{'outfile'}) ){
		$outfile = $params->{'outfile'}
	} else { warn "error, no 'outfile' was specified in the input params"; goto FAIL }

	# can give us a 'dbh' or a 'config-hash'/'config-file' to connect and get a dbh ourselves
	if( exists($params->{'dbh'}) && defined($params->{'dbh'}) ){
		$dbh = $params->{'dbh'}
	} else {
		$dbh = Statistics::Covid::Utils::db_connect_using_dbi($params); # which must contain 'config-file or hash'
		if( ! defined $dbh ){ warn "error, call to ".'Statistics::Covid::Utils::db_connect_using_dbi()'." has failed"; return undef }
		$must_disconnect = 1;
	}
	my $confighash;
	if( exists($params->{'config-hash'}) && defined($params->{'config-hash'}) ){
		$confighash = $params->{'config-hash'};
	} elsif( exists($params->{'config-file'}) && defined($params->{'config-file'}) ){
		my $configfile = $params->{'config-file'};
		if( ! defined($confighash=Statistics::Covid::Utils::configfile2perl($configfile)) ){ warn "error, failed to read and/or parse configuration file '$configfile'"; goto FAIL }
	}
	if( exists($params->{'dbtype'}) && defined($params->{'dbtype'}) ){
		$dbtype = $params->{'dbtype'}
	} elsif( defined($confighash) && exists($confighash->{'dbparams'}) && defined($confighash->{'dbparams'}) ){
		$dbtype = $confighash->{'dbparams'}->{'dbtype'}
	}
	if( ! defined $dbtype ){ warn "error, 'dbtype' was not specified and either there is no 'config-hash' or 'config-file' or their data do not contain key 'dbparams'->'dbtype'"; goto FAIL }

	# optionally specify a 'tablename' or 'tablenames' or will dump all tables
	my $tablenames;
	if( exists($params->{'tablenames'}) && defined($params->{'tablenames'}) && (ref($params->{'tablenames'}) eq 'ARRAY') ){ 
		$tablenames = $params->{'tablenames'}
	}
	if( exists($params->{'tablename'}) && defined($params->{'tablename'}) && (ref($params->{'tablename'}) eq '') ){ 
		$tablenames = [$params->{'tablename'}]
	}
	if( ! defined $tablenames ){
		# all tablenames
		$tablenames = Statistics::Covid::Utils::db_table_names_using_dbi({'dbh'=>$dbh});
		if( ! defined $tablenames ){ warn "error, call to ".'Statistics::Covid::Utils::db_table_names_using_dbi()'." has failed, can not get the table names!"; goto FAIL }
		if( 0 == scalar(@$tablenames) ){ warn "error, no items in the array of table names"; goto FAIL }
	}
	# optionally add a drop table statement to the dump
	if( exists($params->{'add-drop-table-statement'}) && defined($params->{'add-drop-table-statement'}) ){
		$add_drop_table_statement = $params->{'add-drop-table-statement'}
	}

	my $drop_table_sql = Statistics::Covid::Utils::db_make_drop_table_statement($dbtype);
	if( ! defined $drop_table_sql ){ warn "error, call to ".'Statistics::Covid::Utils::db_make_drop_table_statement()'." has failed for dbtype='$dbtype'"; return undef }

	if( ! open $outfh, '>:encoding(UTF-8)', $outfile ){ warn "error, failed to open file '$outfile' for writing, $!"; goto FAIL }

	#print "TABLENAMES: '".join("','", @$tablenames)."'\n";
	# Get data from each table
	my ($sqlstr, $insertstmstr);
	foreach my $atablename (@$tablenames) {
		print $outfh "-- begin table '$atablename'\n";
		# get the create table statement as a string
		my $create_table_sql = Statistics::Covid::Utils::db_get_create_table_sql({
			'dbh' => $dbh,
			'dbtype' => $dbtype,
			'tablename' => $atablename
		});
		if( ! defined $create_table_sql ){ warn "error, call to ".'Statistics::Covid::Utils::db_get_create_table_sql()'." has failed for dbtype='$dbtype'"; goto FAIL }
		# get table column names as an arrayref
		my $all_column_names =	Statistics::Covid::Utils::db_get_table_column_names({'create-table-sql-str'=>$create_table_sql});
		if( ! defined $all_column_names ){ warn "error, call to ".'Statistics::Covid::Utils::db_get_table_column_names()'." has failed"; goto FAIL }
		# this only holds for SQLite and MySQL and Postgress >9.1
		$create_table_sql =~ s/^CREATE TABLE/CREATE TABLE IF NOT EXISTS/i;
		if( $add_drop_table_statement == 1 ){ print $outfh $drop_table_sql." $atablename\n"; }
		print $outfh $create_table_sql."\n";
		$sqlstr = "SELECT " . (join ',', @$all_column_names) . " FROM $atablename";
		# Store the data in a 2D array reference
		my $all_column_values = eval { $dbh->selectall_arrayref($sqlstr) };
		if( $@ || ! defined $all_column_values ){ warn "error, ".'dbh->selectall_arrayref()'." has failed for sql '$sqlstr', $@\n".$DBI::errstr; goto FAIL }
		for my $arow_of_values (@$all_column_values){
			$insertstmstr = Statistics::Covid::Utils::db_get_insert_statement_for_specific_dbtype(
				$dbtype,
				$atablename,
				$all_column_names,
				$arow_of_values
			);
			if( ! defined $insertstmstr ){ warn "error, call to ".'Statistics::Covid::Utils::db_get_insert_statement_for_specific_dbtype()'." has failed"; goto FAIL }
			print $outfh $insertstmstr."\n";
		}
		print $outfh "-- end table '$atablename'\n";
	}

	if( $must_disconnect ){ $dbh->disconnect() }
	close $outfh;
	return ""; # success

FAIL:
	if( $must_disconnect ){ $dbh->disconnect() }
	if( defined $outfh ){ close $outfh }
	return undef
}
sub	db_get_create_table_sql {
	my $params = defined($_[0]) ? $_[0] : {};

	my ($dbtype, $dbh);
	my $must_disconnect = 0;
	# must specify a 'tablename'
	my $tablename;
	if( exists($params->{'tablename'}) && defined($params->{'tablename'}) ){ 
		$tablename = $params->{'tablename'}
	} else { warn "error, a 'tablename' was not specified or it was empty, in the input params"; goto FAIL }

	# can give us a 'dbh' or a 'config-hash'/'config-file' to connect and get a dbh ourselves
	if( exists($params->{'dbh'}) && defined($params->{'dbh'}) ){
		$dbh = $params->{'dbh'}
	} else {
		$dbh = Statistics::Covid::Utils::db_connect_using_dbi($params);
		if( ! defined $dbh ){ warn "error, call to ".'Statistics::Covid::Utils::db_connect_using_dbi()'." has failed"; return undef }
		$must_disconnect = 1;
	}
	my $confighash;
	if( exists($params->{'config-hash'}) && defined($params->{'config-hash'}) ){
		$confighash = $params->{'config-hash'};
	} elsif( exists($params->{'config-file'}) && defined($params->{'config-file'}) ){
		my $configfile = $params->{'config-file'};
		if( ! defined($confighash=Statistics::Covid::Utils::configfile2perl($configfile)) ){ warn "error, failed to read and/or parse configuration file '$configfile'"; goto FAIL }
	}
	if( exists($params->{'dbtype'}) && defined($params->{'dbtype'}) ){
		$dbtype = $params->{'dbtype'}
	} elsif( defined($confighash) && exists($confighash->{'dbparams'}) && defined($confighash->{'dbparams'}) ){
		$dbtype = $confighash->{'dbparams'}->{'dbtype'}
	}
	if( ! defined $dbtype ){ warn "error, 'dbtype' was not specified and either there is no 'config-hash' or 'config-file' or their data do not contain key 'dbparams'->'dbtype'"; goto FAIL }

	my $create_table_sqlstr = Statistics::Covid::Utils::db_get_create_table_statement_for_specific_dbtype($dbtype, $tablename);
	if( ! defined $create_table_sqlstr ){ warn "error, call to ".'Statistics::Covid::Utils::db_get_create_table_statement_for_specific_dbtype()'." has failed for dbtype='$dbtype'"; goto FAIL }
	my $sth = eval { $dbh->prepare($create_table_sqlstr) };
	if( $@ || ! defined $sth ){ warn "error, call to prepare('$create_table_sqlstr') has failed, $@\n".$DBI::errstr; goto FAIL }
	my $rv = eval { $sth->execute() };
	if( $@ || ! defined $rv ){ warn "error, call to execute('$create_table_sqlstr') has failed, $@\n".$DBI::errstr; goto FAIL}
	my $results = eval { $sth->fetchall_arrayref({}) };
	if( $@ || ! defined $results ){ warn "error, call to fetchall_arrayref('$create_table_sqlstr') has failed, $@\n".$DBI::errstr; goto FAIL }
	die "TODO: you need to check with $dbtype and see what it returns for '$create_table_sqlstr' and add it to the statement below..." if $dbtype ne 'SQLite';
	return join("\n", $results->[0]->{'sql'}); # success

FAIL:
	if( $must_disconnect ){ $dbh->disconnect() }
	return undef
}
sub	db_get_table_column_names {
	my $params = defined($_[0]) ? $_[0] : {};

	# either give us a create-sql string or we will get one ourselves given connection details in the params
	my $create_table_sql;
	if( exists($params->{'create-table-sql-str'}) && defined($params->{'create-table-sql-str'}) ){
		$create_table_sql = $params->{'create-table-sql-str'};
	} else {
		$create_table_sql = Statistics::Covid::Utils::db_get_create_table_sql($params);
		if( ! defined $create_table_sql ){ warn pp($params)."\nerror, call to ".'Statistics::Covid::Utils::db_get_create_table_sql()'." has failed for above parameters"; return undef }
	}
	# we are parsing something like
	# CREATE TABLE Datum (
	#  area real NOT NULL DEFAULT 0,
	#  confirmed integer NOT NULL DEFAULT 0,
	# );

	if( $create_table_sql !~ /create table\s+.+?\s*\(\s*(.+)\)\s*;?/is ){ warn "$create_table_sql\nerror, unexpected content of the create-table-sql string (as returned by ".'Statistics::Covid::Utils::db_get_create_table_sql()'."), see above"; return undef }
	my $beef = $1;
	my (@tablenames, $line);
	while( $beef =~ /^\s*(.+?)\s*$/gm ){
		$line = $1;
		next if $line =~ /^PRIMARY\s+KEY/i;
		if( $line =~ /^(.+?)\s+/ ){
			push @tablenames, $1
		}
	}
	return \@tablenames
}
sub	db_get_create_table_statement_for_specific_dbtype {
	my $dbtype = $_[0];
	# optionally specify a tablename or we will use <tablename> and caller just substs that
	my $tablename = defined($_[1]) ? $_[1] : '<tablename>';

	# sacrifice a bit of portability than still searching for available module
	# for postgres see https://serverfault.com/questions/231952/is-there-an-equivalent-of-mysqls-show-create-table-in-postgres
	if( $dbtype eq 'SQLite' ){
		return "select * from sqlite_master where name='$tablename'";
	} elsif( $dbtype eq 'MySQL' ){
		return "SHOW CREATE TABLE '$tablename'";
	}
	warn "error, 'dbtype'='$dbtype' is not known to me";
	return undef
}
sub	db_get_insert_statement_for_specific_dbtype {
	my $dbtype = $_[0];
	# specify a tablename or we will use <tablename> and caller just substs that
	my $tablename = $_[1];
	my $param2 = $_[2];
	if( ! defined $param2 ){ warn "error, 3 or 4 parameters are required (dbtype, tablename, col_name_vals_hash) or (dbtype, tablename, col_names, col_values)"; return undef }
	my ($col_values, $col_names);
	if( ref($param2) eq 'HASH' ){
		my (@n, @v);
		for my $k (sort keys %$param2){
			push @n, $k;
			push @v, $param2->{$k};
		}
		$col_names = \@n;
		$col_values = \@v;
	} else {
		if( ! defined $_[3] ){ warn "error, 3 or 4 parameters are required (dbtype, tablename, col_name_vals_hash) or (dbtype, tablename, col_names, col_values)"; return undef }
		$col_names = $param2;
		$col_values = $_[3];
	}
	# sacrifice a bit of portability than still searching for available module
	# for postgres see https://serverfault.com/questions/231952/is-there-an-equivalent-of-mysqls-show-create-table-in-postgres
	if( $dbtype eq 'SQLite' ){
		return "INSERT INTO $tablename ('" . join("','", @$col_names)
		  . "') VALUES ('" . join("','", map { my $x=$_; $x =~ s/(['])/\\$1/g; $x } @$col_values) . "')"
	} elsif( $dbtype eq 'MySQL' ){
		return "INSERT INTO $tablename ('" . join("','", @$col_names)
		  . "') VALUES ('" . join("','", map {  my $x=$_; $x =~ s/(['])/\\$1/g; $x } @$col_values) . "')"
	}
	warn "error, 'dbtype'='$dbtype' is not known to me";
	return undef
}
sub	db_make_drop_table_statement {
	my $dbtype = $_[0];

	# sacrifice a bit of portability than still searching for available module
	# for postgres see https://serverfault.com/questions/231952/is-there-an-equivalent-of-mysqls-show-create-table-in-postgres
	if( $dbtype eq 'SQLite' ){
		return "DROP TABLE IF EXISTS"
	} elsif( $dbtype eq 'MySQL' ){
		return "DROP TABLE IF EXISTS"
	}
	warn "error, 'dbtype'='$dbtype' is not known to me";
	return undef
}
sub	db_make_dsn {
	my $params = defined($_[0]) ? $_[0] : {};

	my $confighash;
	if( exists($params->{'config-hash'}) && defined($params->{'config-hash'}) ){
		$confighash = $params->{'config-hash'};
	} elsif( exists($params->{'config-file'}) && defined($params->{'config-file'}) ){
		my $configfile = $params->{'config-file'};
		if( ! defined($confighash=Statistics::Covid::Utils::configfile2perl($configfile)) ){ warn "error, failed to read and/or parse configuration file '$configfile'"; return undef }
	} else { warn "error, input parameter 'config-file' or 'config-hash' must be specified"; return undef }
	if( ! exists($confighash->{'dbparams'}) || ! defined($confighash->{'dbparams'}) ){ warn pp($confighash).die"\nerror, configuration hash does not contain key 'dbparams', see above for its contents"; return undef }
	my $dbparams = $confighash->{'dbparams'};

	my $dsn = undef;
	if( $dbparams->{'dbtype'} eq 'SQLite' ){
		$dsn = 'dbi:SQLite:dbname=';
		if( exists($dbparams->{'dbdir'}) && defined($dbparams->{'dbdir'}) && ($dbparams->{'dbdir'} ne '') ){
			$dsn .= $dbparams->{'dbdir'}.'/'
		}
		$dsn .= $dbparams->{'dbname'};
	} elsif( $dbparams->{'dbtype'} eq 'MySQL' ){
		$dsn = "dbi:mysql:database=".$dbparams->{'dbname'}.";host=".$dbparams->{'hostname'}.";port=".$dbparams->{'port'};
	} else { warn "don't know this dbtype '".$dbparams->{'dbtype'}."'."; return 0 }
	return $dsn;
}
# generic way to connect to a database and return a handle
# the database type,name,credentials will be taken from
# the input configuration hash or file under the key 'dbparams'
# (it uses the common configuration file format)
sub	db_connect_using_dbi {
	my $params = defined($_[0]) ? $_[0] : {};

	my $confighash;
	if( exists($params->{'config-hash'}) && defined($params->{'config-hash'}) ){
		$confighash = $params->{'config-hash'};
	} elsif( exists($params->{'config-file'}) && defined($params->{'config-file'}) ){
		my $configfile = $params->{'config-file'};
		if( ! defined($confighash=Statistics::Covid::Utils::configfile2perl($configfile)) ){ warn "error, failed to read and/or parse configuration file '$configfile'"; return undef }
	} else { warn "error, input parameter 'config-file' or 'config-hash' must be specified"; return undef }
	if( ! exists($confighash->{'dbparams'}) || ! defined($confighash->{'dbparams'}) ){ warn pp($confighash).die"\nerror, configuration hash does not contain key 'dbparams', see above for its contents"; return undef }
	my $dbparams = $confighash->{'dbparams'};

	my $dsn = Statistics::Covid::Utils::db_make_dsn({'config-hash'=>$confighash});
	if( ! defined $dsn ){ warn "error, call to ".'Statistics::Covid::Utils::db_make_dsn()'." has failed"; return undef }
	my $dbh = DBI->connect($dsn,
		exists($confighash->{'dbparams'}->{'username'}) && defined($confighash->{'dbparams'}->{'username'})
			? $confighash->{'dbparams'}->{'username'} : '',
		exists($confighash->{'dbparams'}->{'password'}) && defined($confighash->{'dbparams'}->{'password'})
			? $confighash->{'dbparams'}->{'password'} : '',
		exists($confighash->{'dbparams'}->{'dbi-connect-params'}) && defined($confighash->{'dbparams'}->{'dbi-connect-params'})
			? $confighash->{'dbparams'}->{'dbi-connect-params'} : {}
	);
	if( ! defined $dbh ){ warn "error, failed to connect to database (via DBI) using this dsn '$dsn' : ".$DBI::errstr; return undef }
	return $dbh
}
# DBIx::Class specific sub to check if a table exists
# just tries to create a resultset based on this table
# which will fail if table does not exist (within the eval).
# the 1st param is a schema-obj (what you get when you do MyApp::Schema->connect($dsn))
# the 2nd is the table name (which accepts % wildcards)
# returns 1 if table exists in db,
#         0 if table does not exist in db
sub	table_exists_dbix_class {
	my ($schema, $tablename) = @_;
	return Statistics::Covid::Utils::table_exists_dbi($schema->storage->dbh, $tablename)
}
sub	db_table_names_using_dbi {
	my $params = defined($_[0]) ? $_[0] : {};

	# can give us a 'dbh' or a 'config-hash'/'config-file' to connect and get a dbh ourselves
	my $dbh;
	my $must_disconnect = 0;
	if( exists($params->{'dbh'}) && defined($params->{'dbh'}) ){
		$dbh = $params->{'dbh'}
	} else {
		$dbh = Statistics::Covid::Utils::db_connect_using_dbi($params);
		if( ! defined $dbh ){ warn "error, call to ".'Statistics::Covid::Utils::db_connect_using_dbi()'." has failed"; return undef }
		$must_disconnect = 1;
	}
	my @tables;
	eval {
		# see https://docstore.mik.ua/orelly/linux/dbi/ch06_01.htm
		my $tabsth = $dbh->table_info();
		### Iterate through all the tables...
		while ( my ( $qual, $owner, $name, $type, $remarks ) = 
			$tabsth->fetchrow_array()
		){
			#printf "%-9s  %-9s %-32s %-6s %s\n", $qual, $owner, $name, $type, $remarks;
			push(@tables, $name) if $type eq 'TABLE';
		}
	};
	if( $@ ){ warn "error, call to ".'dbh->tables()'." has failed: $@\n".$DBI::errstr; goto FAIL }
	return \@tables;

FAIL:
	if( $must_disconnect ){ $dbh->disconnect() }
	return undef
}
# DBI specific sub to check if a table exists
# just tries to create a resultset based on this table
# which will fail if table does not exist (within the eval).
# the 1st param is a DB handle (like the one you get from DBI->connect($dsn)
# the 2nd is the table name (which accepts % wildcards)
# returns 1 if table exists in db,
#         0 if table does not exist in db
# from https://www.perlmonks.org/bare/?node=DBI%20Recipes
sub	table_exists_dbi {
	my ($dbh, $tablename) = @_;
	my $tables = Statistics::Covid::Utils::db_table_names_using_dbi({'dbh'=>$dbh});
	if( defined $tables ){
		for (@$tables) {
			next unless $_;
			return 1 if $_ eq $tablename;
		}
	} else {
		warn "warning: failed to get a list of the table names using ".'Statistics::Covid::Utils::db_table_names_using_dbi()'." and trying something different ...";
		eval {
			local $dbh->{PrintError} = 0;
			local $dbh->{RaiseError} = 1;
			$dbh->do(qq{SELECT * FROM $tablename WHERE 1 = 0});
		};
		return 1 unless $@;
	}
	return 0
}
# returns an arrayref of the files inside the input dir(s) specified
# by $indirs (which can be a scalar for a signle dir or an arrayref for one or more dirs)
# and further, matching the $pattern regex (if specified,
# else no check is made and all files are returned)
# $pattern can be left undefined or it can be a string containing a
# regex pattern, e.g. '\.json$' or can be a precompiled regex
# which apart from the added speed (possibly) offers the flexibility
# of using regex switches, e.g. qr/\.json$/i
sub	find_files {
	# an input dir to search in as a string
	# or one or more input dirs as a hashref
	# is the 1st input parameter:
	my @indirs = (ref($_[0]) eq 'ARRAY') ? @{$_[0]} : ($_[0]);

	# an optional regex pattern or array of regex patterns as the 2nd param:
	my ($m, @patterns, $rem);
	if( defined($m=$_[1]) ){
		$rem = ref($m);
		if( $rem eq '' ){ push @patterns, $m }
		elsif( $rem eq 'ARRAY' ){ push @patterns, @$m }
		else { warn "error, 2nd parameter can be a pattern or an array of patterns (either pre-compiled regexes or qr// already (but it was a ref of type '$rem'))"; return undef }
	}
	my @qrpatterns;
	for $m (@patterns){
		$rem = ref($m);
		if( $rem eq 'Regexp' ){ push @qrpatterns, $m }
		elsif( $rem eq '' ){
			$rem = qr/${m}/;
			if( ! defined $rem ){ warn "error, failed to compile regex '$m'."; return undef }
			push @qrpatterns, $rem
		} else { warn "error, patterns can be strings (to be compiled as regexes) or already compiled (qr//) regexes, type '$rem' is not known"; return undef }
	}
	my @filesfound;
	File::Find::find({
		untaint => 1, # << untaint dirs for chdir
		wanted => defined scalar(@qrpatterns)>0 ?
	# now this does a chdir internally, so -f $File::Find::name does not work!
	sub {
		if( -f $_ ){
			for my $m (@qrpatterns){
				if( $DEBUG > 1 ){ print "find_files() : checking if file '".$File::Find::name."' matches pattern '$m' ..." }
				if( $File::Find::name =~ $m ){
					if( $DEBUG > 1 ){ print "yes.\n" }
					push @filesfound, $File::Find::name;
				} else { if( $DEBUG > 1 ){ print "no.\n" } }
			}
		}
	} # end sub
	: 
	sub {
		push @filesfound, $File::Find::name
			if (-f $_)
	} # end sub
	}, @indirs
	); # and of File::Find::find
	return \@filesfound
}
sub	make_path {
	my $adir = $_[0];
	if( ! -d $adir ){
		if( ! File::Path::make_path($adir) ){
			warn "error, failed to create dir '$adir', $!";
			return 0
		}
	}
	return 1 # success
}
sub	configfile2perl {
	my $infile = $_[0];
	my $fh;
	if( ! open $fh, '<:encoding(UTF-8)', $infile ){ warn "error, failed to open file '$infile' for reading, $!"; return undef }
	my $json_contents = undef;
	{local $/ = undef; $json_contents = <$fh> } close($fh);
	my $inhash = Statistics::Covid::Utils::configstring2perl(
		Encode::encode_utf8($json_contents)
	);
	if( ! defined $inhash ){ warn "error, call to ".'Statistics::Covid::Utils::configstring2perl()'." has failed for file '$infile'."; return undef }
	return $inhash
}
sub	configstring2perl {
	my $json_contents = $_[0];
	# now remove comments
	$json_contents =~ s/#.*$//mg;
	my $inhash = Data::Roundtrip::json2perl($json_contents);
	if( ! defined $inhash ){ warn $json_contents."\n\nerror, call to ".'Data::Roundtrip::json2perl()'." has failed for above json string."; return undef }
	return $inhash
}
# parse CSV into a perl variable.
# Content can be from a file 'input-filename', or from an in-memory
# string scalar 'input-string'. One or the other must be specified.
# Optionally, set 'has-header-in-first-line' to true if the
# first line contains the header.
# On failure it returns undef
# On success:
# If 'has-header-in-first-line' is true, it returns an arrayref
# of hashrefs. Each item of the array is a line in the file/contents
# in the order it appears. Each item in the hashref is a value(column)
# in that line, keyed on the column name. e.g. 'confirmed' => 12,
# If 'has-header-in-first-line' is false, it returns an arrayref
# of arrayrefs. Each item of the array is a line in the file/contents
# in the order it appears. Each item in the inside arrayref is
# a column value in the same order it appears (so no column-names)
sub	csv2perl {
	my $params = $_[0];

	my ($INFH, $m);
	if( exists($params->{'input-filename'}) && defined($m=$params->{'input-filename'}) ){
		if( ! open($INFH, '<:encoding(UTF-8)', $m) ){ warn "error, failed to open file '$m' for reading, $!"; return undef }
	} elsif( exists($params->{'input-string'}) && defined($params->{'input-string'}) ){
		if( ! open($INFH, '<:encoding(UTF-8)', \$params->{'input-string'}) ){ warn "error, failed to open in-memory string(!!), $!"; return undef }
	} else { warn "error, neither 'input-filename' nor 'input-string' was specified"; return undef }

	my $has_header_at_this_line = exists($params->{'has-header-at-this-line'}) && defined($m=$params->{'has-header-at-this-line'})
		? $params->{'has-header-at-this-line'} : undef;

	my %csv_params = (auto_diag => 1);
	if( exists($params->{'Text::CSV_XS-params-new'}) && defined($params->{'Text::CSV_XS-params-new'}) ){
		@csv_params{keys %{$params->{'Text::CSV_XS-params-new'}}} = values %{$params->{'Text::CSV_XS-params-new'}}
	}
	my $csv = eval { Text::CSV_XS->new(\%csv_params) };
	if( $@ || ! defined $csv ){ warn pp(\%csv_params)."\nerror, call to ".'Text::CSV_XS->new()'." has failed (check parameters above): $@"; close($INFH); return undef }

	my @ret;
	if( defined $has_header_at_this_line ){
		my %csv_header_params = (set_column_names => 1);
		if( exists($params->{'Text::CSV_XS-params-header'}) && defined($params->{'Text::CSV_XS-params-header'}) ){
			@csv_header_params{keys %{$params->{'Text::CSV_XS-params-header'}}} = values %{$params->{'Text::CSV_XS-params-header'}}
		}
		# munch the lines until we reach to the header
		<$INFH> for 1..($has_header_at_this_line-1);
		my @header = eval { $csv->header($INFH, \%csv_header_params) };
		if( $@ ){ warn pp(\%csv_header_params)."\ncall to ".'csv->header()'." has failed for above parameters (".$csv->error_diag ()."): $@"; return undef }
		if( $DEBUG > 0 ){ warn "read header from CSV file '".join("','", @header)."\n" }
		while( 1 ){
			my $row = eval { $csv->getline_hr($INFH) };
			if( $@ ){ warn "call to ".'csv->getline_hr()'." has failed (".$csv->error_diag ()."): $@"; return undef }
			if( ! defined $row ){ last }
			push @ret, $row;
		}
	} else {
		if( $DEBUG > 0 ){ warn "no header specified for input CSV" }
		while( 1 ){
			my $row = eval { $csv->getline($INFH) };
			if( $@ ){ warn "call to ".'csv->getline()'." has failed (".$csv->error_diag ()."): $@"; return undef }
			if( ! defined $row ){ last }
			push @ret, $row;
		}
	}
	close($INFH);
	return \@ret
}
sub	save_perl_var_to_localfile {
	my ($avar, $outfile) = @_;
	my $outfh;
	if( ! open $outfh, '>:encoding(UTF-8)', $outfile ){
		warn "error, failed to open file '$outfile' for writing json content, $!";
		return 0;
	}
	print $outfh Data::Dump::dump $avar;
	close $outfh;
	return 1;
}
# save text to outfile
# return 0 on failure, 1 on success
sub	save_text_to_localfile {
	my ($text, $outfile) = @_;
	if( ! defined $text ){ warn "error, 'text' (1st parameter) was not specified"; return 0 }
	if( ! defined $outfile ){ warn "error, 'outfile' (2nd parameter) was not specified"; return 0 }
	my $outfh;
	if( ! open $outfh, '>:encoding(UTF-8)', $outfile ){
		warn "error, failed to open file '$outfile' for writing text content, $!";
		return 0;
	}
	print $outfh $text;
	close $outfh;
	return 1;
}
# save binary blob to outfile
# return 0 on failure, 1 on success
sub	save_blob_to_localfile {
	my ($blob, $outfile) = @_;
	if( ! defined $blob ){ warn "error, 'blob' (1st parameter) was not specified"; return 0 }
	if( ! defined $outfile ){ warn "error, 'outfile' (2nd parameter) was not specified"; return 0 }
	my $outfh;
	if( ! open $outfh, '>:encoding(UTF-8)', $outfile ){
		warn "error, failed to open file '$outfile' for writing blob content, $!";
		return 0;
	}
	binmode $outfh;
	print $outfh $blob;
	close $outfh;
	return 1;
}
sub	slurp_localfile {
	my $infile = $_[0];
	my $fh;
	if( ! open $fh, '<:encoding(UTF-8)', $infile ){
		warn "error, failed to open file '$infile' for reading, $!";
		return 0;
	}
	my $content;
	{ local $/ = undef; $content = <$fh> } close $fh;
	return $content;
}
# converts an ISO8601 date string to DateTime object
# which is something like:
#	 2020-03-21T22:47:56 or 2020-03-21 22:47:56
# or 2020-03-21T22:47:56Z <<< timezone is UTC
# OR(!) 3/22/20 23:45
sub JHU_datestring_to_DateTime {
	my $datespec = $_[0];
	my $ret = undef;
	if( $datespec =~ /\d{10}/ ){
		$ret = epoch_seconds_to_DateTime($datespec);
		if( ! defined $ret ){ warn "error, call to ".'epoch_seconds_to_DateTime()'." has failed for datespec '$datespec'"; return undef }
		return $ret;
	} elsif( $datespec =~ /\d{13}/ ){
		$ret = epoch_milliseconds_to_DateTime($datespec);
		if( ! defined $ret ){ warn "error, call to ".'epoch_milliseconds_to_DateTime()'." has failed for datespec '$datespec'"; return undef }
		return $ret;
	} elsif( $datespec =~ m!^(\d{1,2})/(\d{1,2})/(\d{2}(?:\d{2})?)\s*[ T]\s*(\d+)\:(\d+)! ){
		my $ayear = $3; $ayear = '20'.$ayear if length($ayear)==2;
		$ret = eval { DateTime->new(
				year => $ayear,
				month => $1,
				day => $2,
				hour => $4,
				minute => $5,
			)
		};
		if( $@ || ! defined($ret) ){ warn "error, call to ".'DateTime::Format::Strptime->new()'." has failed for spec '$datespec'".(defined($@)?': '.$@:'.'); return undef }
		my $ep = $ret->epoch(); if( ($ep < $DATE_CONVERTER_CHECK_MIN_DATE) || ($ep > $DATE_CONVERTER_CHECK_MAX_DATE) ){ warn "error, datespec '$datespec' falls outside the sane date range '$DATE_CONVERTER_CHECK_MIN_DATE' and '$DATE_CONVERTER_CHECK_MAX_DATE'"; return undef }
		return $ret;
	}

	if( $datespec !~ m/(Z|[+-](?:2[0-3]|[01][0-9])(?::?(?:[0-5][0-9]))?)$/ ){ $datespec .= 'UTC' }
	$datespec =~ s/(\d+)\s+(\d+)/$1T$2/;
	my $parser = DateTime::Format::Strptime->new(
		# %Z covers both string timezone (e.g. 'UTC') and '+08:00'
		pattern => '%FT%T%Z',
		locale => 'en_GB',
		time_zone => 'UTC',
		on_error => sub { warn "error, failed to parse date: ".$_[1] }
	);
	if( ! defined($parser) ){ warn "error, call to ".'DateTime::Format::Strptime->new()'." has failed".(defined($@)?': '.$@:'.'); return undef }
	$ret = eval { $parser->parse_datetime($datespec) };
	if( $@ || ! defined($ret) ){ warn "error, call to ".'DateTime::Format::Strptime->new()'." has failed for spec '$datespec'".(defined($@)?': '.$@:'.'); return undef }
	my $ep = $ret->epoch(); if( ($ep < $DATE_CONVERTER_CHECK_MIN_DATE) || ($ep > $DATE_CONVERTER_CHECK_MAX_DATE) ){ warn "error, datespec '$datespec' falls outside the sane date range '$DATE_CONVERTER_CHECK_MIN_DATE' and '$DATE_CONVERTER_CHECK_MAX_DATE'"; return undef }
	return $ret
}
# converts an ISO8601 date string to DateTime object
# which is something like:
#	 2020-03-21T22:47:56
# or 2020-03-21T22:47:56Z <<< timezone is UTC
sub iso8601_to_DateTime {
	my $datespec = $_[0];
	my $ret = undef;
	# check if we have timezone, else we add a UTC ('UTC' or 'Z')
	if( $datespec !~ m/(Z|[+-](?:2[0-3]|[01][0-9])(?::?(?:[0-5][0-9]))?)$/ ){ $datespec .= 'UTC' }
	$datespec =~ s/(\d+)\s+(\d+)/$1T$2/;
	my $parser = DateTime::Format::Strptime->new(
			# %Z covers both string timezone (e.g. 'UTC') and '+08:00'
			pattern => '%FT%T%Z',
			locale => 'en_GB',
			time_zone => 'UTC',
			on_error => sub { warn "error, failed to parse date: ".$_[1] }
	);
	if( ! defined($parser) ){ warn "error, call to ".'DateTime::Format::Strptime->new()'." has failed"; return undef }
	$ret = eval { $parser->parse_datetime($datespec) };
	if( $@ || ! defined($ret) ){ warn "error, call to ".'DateTime::Format::Strptime->new()'." has failed for spec '$datespec'".(defined($@)?': '.$@:'.'); return undef }
	my $ep = $ret->epoch(); if( ($ep < $DATE_CONVERTER_CHECK_MIN_DATE) || ($ep > $DATE_CONVERTER_CHECK_MAX_DATE) ){ warn "error, datespec '$datespec' falls outside the sane date range '$DATE_CONVERTER_CHECK_MIN_DATE' and '$DATE_CONVERTER_CHECK_MAX_DATE'"; return undef }
	return $ret
}
# ISO8601 without the time and zones, 2020-01-30
sub iso8601_up_to_days_to_DateTime {
	my $datespec = $_[0];
	my $ret = undef;
	my $parser = DateTime::Format::Strptime->new(
			pattern => '%Y-%m-%d',
			locale => 'en_GB',
			time_zone => 'UTC',
			on_error => sub { warn "error, failed to parse date: ".$_[1] }
	);
	if( ! defined($parser) ){ warn "error, call to ".'DateTime::Format::Strptime->new()'." has failed"; return undef }
	$ret = eval { $parser->parse_datetime($datespec) };
	if( $@ || ! defined($ret) ){ warn "error, call to ".'DateTime::Format::Strptime->new()'." has failed for spec '$datespec'".(defined($@)?': '.$@:'.'); return undef }
	my $ep = $ret->epoch(); if( ($ep < $DATE_CONVERTER_CHECK_MIN_DATE) || ($ep > $DATE_CONVERTER_CHECK_MAX_DATE) ){ warn "error, datespec '$datespec' falls outside the sane date range '$DATE_CONVERTER_CHECK_MIN_DATE' and '$DATE_CONVERTER_CHECK_MAX_DATE'"; return undef }
	return $ret
}
# converts a time that data from the BBC contains (not their fault as they probably get it from the government)
# which is something like:
#   09:00 GMT, 25 March 
# ooops it can have BST as timezone
sub epoch_stupid_date_format_from_the_BBC_to_DateTime {
	my $datespec = $_[0];
	my $ret = undef;
	# sometimes BBC forgets the time!
	if( $datespec !~ /\:/ ){ 
		warn "date has no time, setting time to morning, 09:00 GMT";
		$datespec = '09:00 GMT, '.$datespec;
	} else {
		# and sometimes (argg!!!) replaces GMT for BST
		$datespec =~ s/BST/GMT/g
	}
	# ... and sometimes they forget a comma!!!
	if( $datespec !~ /GMT\s*,\s*/ ){ $datespec =~ s/GMT/GMT,/ }
	my $parser = DateTime::Format::Strptime->new(
		pattern => '%H:%M %Z, %d %b %Y', # hour:minute tz, day weekday (our addition: the year!)
		locale => 'en_GB',
		on_error => sub { warn "error, failed to parse date: ".$_[1] }
	);
	if( ! defined($parser) ){ warn "error, call to ".'DateTime::Format::Strptime->new()'." has failed."; return undef }
	# assuming it's the 2020! surely an optimist :(
	$ret = eval { $parser->parse_datetime($datespec.' 2020') };
	if( $@ || ! defined($ret) ){ warn "error, call to ".'DateTime::Format::Strptime->parse_datetime()'." has failed for date spec: '$datespec'".(defined($@)?': '.$@:'.'); return undef }
	my $ep = $ret->epoch(); if( ($ep < $DATE_CONVERTER_CHECK_MIN_DATE) || ($ep > $DATE_CONVERTER_CHECK_MAX_DATE) ){ warn "error, datespec '$datespec' falls outside the sane date range '$DATE_CONVERTER_CHECK_MIN_DATE' and '$DATE_CONVERTER_CHECK_MAX_DATE'"; return undef }
	return $ret
}
# converts a time in MILLISECONDS since the Unix Epoch to a DateTime obj
sub epoch_milliseconds_to_DateTime {
	my $datespec = $_[0];
	$datespec = substr($datespec, 0,-3); # convert millis to seconds, remove last 3 chars
	my $ret = Statistics::Covid::Utils::epoch_seconds_to_DateTime($datespec);
	warn "error, call to ".'epoch_seconds_to_DateTime()'." has failed for spec '$datespec'." unless defined $ret;
	# already checked
	#my $ep = $ret->epoch(); if( ($ep < $DATE_CONVERTER_CHECK_MIN_DATE) || ($ep > $DATE_CONVERTER_CHECK_MAX_DATE) ){ warn "error, datespec '$datespec' falls outside the sane date range '$DATE_CONVERTER_CHECK_MIN_DATE' and '$DATE_CONVERTER_CHECK_MAX_DATE'"; return undef }
	return $ret
}
# converts a time epoch in SECONDS since the Unix Epoch to a DateTime obj
sub epoch_seconds_to_DateTime {
	my $datespec = $_[0];

	my $ret = eval {
		DateTime->from_epoch(
			epoch => $datespec,
			locale => 'en_GB',
			time_zone => 'UTC'
		)
	};
	if( $@ || ! defined($ret) ){ warn "error, call to ".'DateTime::Format::Strptime->new()'." has failed for spec '$datespec'".(defined($@)?': '.$@:'.'); return undef }
	my $ep = $ret->epoch(); if( ($ep < $DATE_CONVERTER_CHECK_MIN_DATE) || ($ep > $DATE_CONVERTER_CHECK_MAX_DATE) ){ warn "error, datespec '$datespec' falls outside the sane date range '$DATE_CONVERTER_CHECK_MIN_DATE' and '$DATE_CONVERTER_CHECK_MAX_DATE'"; return undef }
	return $ret
}
# a shortcut really
# given 2 arrays of objects inheriting from Statistics::Covid::IO::DualBase
# (e.g. Datum, Version, WorldbankData)
# compare each item from the 1st array with their counterpart in the 2nd array
# CAVEAT: all objects may be the same but the order placed in the array
# maybe different in which case equality tests will fail.
sub	objects_equal { return Statistics::Covid::IO::DualBase::objects_equal(@_) }
sub	dbixrow2string {
	my %rowhash = @_; # get_columns() returns this hash
	my $ret = "";
	$ret .= $_ . '=>' . $rowhash{$_} . "\n" for sort { $a cmp $b } keys %rowhash;
	return $ret;
}
# dumps the array of objects (any object as long as
# they inherit from Statistics::IO::DualBase)
# to a JSON string and accepts optional parameters
# like 'pretty'=>0,1 and/or 'escape-unicode'=>0,1
# (for the conversion parameters look in L<Data::Roundtrip>)
# returns undef on failure or the JSON string on success
sub	objects_to_JSON {
	my $objs = $_[0];
	my $params = $_[1];
	my @pv;
	for my $anobj (@$objs){
		push @pv, $anobj->toHashtable()
	}
	my $jsonstring = Data::Roundtrip::perl2json(\@pv, $params);
	if( ! defined $jsonstring ){ warn "error, call to ".'Data::Roundtrip()'." has failed"; return undef }
	return $jsonstring
}
# create a string timestamp of current (now)
# date and time as a string, to be used in creating filenames for example.
# it takes an optional timezone parameter ($tz) which L<DateTime> must understand
# or do not specify one for using the default, at your local system
sub	make_timestamped_string {
	my $tz = $_[0];
	my %dtparams = ();
	$dtparams{time_zone} = $tz if defined $tz;
	my $dt = DateTime->now(%dtparams);
	if( ! defined $dt ){ warn pp(\%dtparams)."\nerror, call to DateTime->now() has failed for the above params."; return undef }
	return $dt->ymd('-') . '_' . $dt->hms('.')
}
# given an increasing sequence of seconds, e.g. 1,3,56,89,...
# which also includes a sequence of increasing Unix-epoch seconds (i.e. sorted asc.)
# convert it to hours or 6-hour units or 24-hour units etc.
# the conversion happens IN-PLACE!
sub	discretise_increasing_sequence_of_seconds {
	my $inarr = $_[0];
	my $unit = $_[1]; # 3600 will convert the seconds to hours and 3600*24 to days
	my $offset = defined($_[2]) ? $_[2] : 0;
	# the first point in the time sequence (@$inarr)
	# is the reference point, all subsequent ones
	# are going to be offset to this first point being T=0

	my $t0 = $inarr->[0];
	# at least one test complaied about a negative epoch of 
#The 'epoch' parameter ("-6e-05") to DateTime::from_epoch did not pass regex check
# at /usr/lib/x86_64-linux-gnu/perl5/5.22/DateTime.pm line 488.
# https://www.cpantesters.org/cpan/report/5e9b5676-7249-11ea-9f79-29611f24ea8f
	# I suspect the culprit is $_-$t0 for the first element
	$_ = ($offset + (int($_-$t0))/$unit) for @$inarr;
	# to eliminate the above bug, also make the first element equal to offset
	$inarr->[0] = $offset;
}
# this will take an array of Datum objects and a set of one or more
# (table) column names (attributes of each object), e.g. 'confirmed'
# and will create a hash, where keys are column names
# and values are arrays of the values for that column name for each object
# in the order they appear in the input array.
# A datum object has column names and each one has values (e.g. 'confirmed', 'name' etc)
# for clarity let's say that our datum objects have column names sex,age,A
# here they are (unquoted): (m,30,1), (m,31,2), (f,40,3), (f,41,4)
# a DF (dataframe) with no params will be created and returned as:
#     { '*' => {sex=>[m,m,f,f], age=>[30,30,40,40], A=>[1,2,3,4]} }
# which is equivalent to @groupby=() and @content_columnNames=(sex,age,A) (i.e. all columns)
# a DF groupped by column 'sex' will be
#     {
#       'm' => {sex=>[m,m], age=>[30,30], A=>[1,2]]},
#       'f' => {sex=>[f,f], age=>[40,40], A=>[3,4]]},
#     }
# and a DF groupped by 'sex' and 'age':
#     {
#       'm|30' => {sex=>[m,m], age=>[30,30], A=>[1,2]]},
#       'f|40' => {sex=>[f,f], age=>[40,40], A=>[3,4]]},
#     }
# notice that m|40 does not exist as it is not an existing combination in the data
# notice also that by specifying @content_columnNames, you make your DF leaner.
# e.g. why have sex in the hash when is also a key?
sub	datums2dataframe {
	my $params = $_[0];
	# this is required parameter
	my $objs = exists($params->{'datum-objs'}) ? $params->{'datum-objs'} : undef;
	if( ! defined($objs) || scalar(@$objs)==0 ){ warn "error, no objects specified with first parameter."; return undef }

	# these are optional parameters
	# the default for this is to groupby nothing
	my @groupby = exists($params->{'groupby'})&&defined($params->{'groupby'}) ? @{$params->{'groupby'}} : ();
	my $NGB = scalar @groupby;

	# the default for this is to include all columns
	# be as specific as possible so as not to return huge dataframes and on the other hand
	# not to create a dataframe for each column (inmo), as a compromise create a dataframe
	# only for the markers (confirmed, unconfirmed, etc.) and not for belongsto etc. (which can be for grouping by)
	my @content_columnNames = defined($params->{'content'}) ? @{$params->{'content'}} : @{$objs->[0]->column_names()};
	my $NCC = scalar @content_columnNames;

	# make sure that all column names exist in the first object (for the rest...)
	my $tmpobj = $objs->[0];
	foreach (@content_columnNames){ if( ! $tmpobj->column_name_is_valid($_) ){ warn "error, column name '$_' does not exist."; return undef } }
	foreach (@groupby){ if( ! $tmpobj->column_name_is_valid($_) ){ warn "error, group-by columns name '$_' does not exist."; return undef } }

	# and start the grouping
	my (%ret, $agv, $R);
	for my $anobj (@$objs){
		# create a key for the 'groupby' columns, its values will be an arrayref of data from the @content_columnNames
		# key is formed by values of the columns, e.g. if groupby column is sex, then keys will be 'm' and 'f'
		# and the values for key 'm' will be only for those datums with sex=m
		# and for key 'f' values will be only for datums with sex=f
		# if groupby is empty, then key is '*'
		if( $NGB == 0 ){ $agv = '*' } else {
			# the separator here is important. It separates column values
			# which can contain essentially anything (i.e. this separator too!)
			# otoh this serves as a key to the dataframe for each object.
			# and it will probably be used to save to files (with this key as basename)
			# so must be acceptable by the filesystem without string substitutions if possible
			# well it is not possible!
			$agv = join('||', map { $anobj->get_column($_) } @groupby);
		}
		if( ! exists $ret{$agv} ){
			$ret{$agv} = $R = {};
			for (@content_columnNames){
				$R->{$_} = { 'data' => [] }
			}
		} else { $R = $ret{$agv} }
		for (@content_columnNames){
			push @{$R->{$_}->{'data'}}, $anobj->get_column($_)
		}
	}
	return \%ret
}
sub	make_darker_color_rgb {
	my $inp = $_[0];
	my $factor = defined($_[1]) ? $_[1] : 0.25;
	my @rgb = $inp->as_array();
	$_ = (1 - $factor)*$_ for @rgb;
	return Graphics::Color::RGB->new({red=>$rgb[0], green=>$rgb[1], blue=>$rgb[2]});
}
sub	make_lighter_color_rgb {
	my $inp = $_[0];
	my $factor = defined($_[1]) ? $_[1] : 0.25;
	my @rgb = $inp->as_array();
	$_ += (1 - $_)*$factor for @rgb;
	return Graphics::Color::RGB->new({red=>$rgb[0], green=>$rgb[1], blue=>$rgb[2]});
}
sub	is_module_loaded {
	my $module_name = $_[0];
	if( grep { /\A${module_name}::\z/ } keys %:: ){ return 1 }
	return 0
}
sub	has_utf8 { return $_[0] =~ /[^\x00-\x7f]/ }
1;
__END__
# end program, below is the POD
=pod

=encoding UTF-8

=head1 NAME

Statistics::Covid::Utils - assorted, convenient, stand-alone, public and semi-private subroutines

=head1 VERSION

Version 0.23

=head1 DESCRIPTION

This package contains assorted convenience subroutines.
Most of which are private or semi-private but some are
required by module users.

=head1 SYNOPSIS

	use Statistics::Covid;
	use Statistics::Covid::Datum;
	use Statistics::Covid::Utils;

	# read data from db
	$covid = Statistics::Covid->new({   
		'config-file' => 't/config-for-t.json',
		'debug' => 2,
	}) or die "Statistics::Covid->new() failed";
	# retrieve data from DB for selected locations (in the UK)
	# data will come out as an array of Datum objects sorted wrt time
	# (the 'datetimeUnixEpoch' field)
	my $objs = $covid->select_datums_from_db_for_specific_location_time_ascending(
		#{'like' => 'Ha%'}, # the location (wildcard)
		['Halton', 'Havering'],
		#{'like' => 'Halton'}, # the location (wildcard)
		#{'like' => 'Havering'}, # the location (wildcard)
		'UK', # the belongsto (could have been wildcarded)
	);
	# create a dataframe
	my $df = Statistics::Covid::Utils::datums2dataframe({
		'datum-objs' => $objs,
		'groupby' => ['name'],
		'content' => ['confirmed', 'datetimeUnixEpoch'],
	});
	# convert all 'datetimeUnixEpoch' data to hours, the oldest will be hour 0
	for(sort keys %$df){
		Statistics::Covid::Utils::discretise_increasing_sequence_of_seconds(
			$df->{$_}->{'datetimeUnixEpoch'}, # in-place modification
			3600 # seconds->hours
		)
	}

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


=head2 datums2dataframe

It will take an array of Datum objects and a set of one or more
(table) column names (attributes of each object), e.g. 'confirmed'
and will create a hash, where keys are column names
and values are arrays of the values for that column name for each object
in the order they appear in the input array.
A datum object has column names and each one has values (e.g. C<'confirmed'>, C<'name'> etc.)
for clarity let's say that our datum objects have column names sex,age,A
here they are (unquoted): C<(m,30,1), (m,31,2), (f,40,3), (f,41,4)>
a DF (dataframe) with no params will be created and returned as:

    { '*' => {sex=>[m,m,f,f], age=>[30,30,40,40], A=>[1,2,3,4]} }

which is equivalent to C<@groupby=()> and C<@content_columnNames=(sex,age,A)>
(i.e. all columns) a DF groupped by column C<'sex'> will be

    {
      'm' => {sex=>[m,m], age=>[30,30], A=>[1,2]]},
      'f' => {sex=>[f,f], age=>[40,40], A=>[3,4]]},
    }

and a DF groupped by C<'sex'> and C<'age'>:

    {
      'm|30' => {sex=>[m,m], age=>[30,30], A=>[1,2]]},
      'f|40' => {sex=>[f,f], age=>[40,40], A=>[3,4]]},
    }

notice that C<m|40> does not exist as it is not an existing combination in the data
notice also that by specifying C<@content_columnNames>, you make your DF leaner.
e.g. why have sex in the hash when is also a key?

The reason why use a dataframe instead of an array of
L<Statistics::Covid::Datum> objects is economy.
One Datum object represents data in a single time point.
Plotting or fitting data requies a lot of data objects.
whose data from specific columns/fields/attributes must
be collected together in an array, possibly transformed,
and plotted or fitted. If you want to plot and fit the
same data you have to repeat this process twice. Whereas
by inserting this data into a dataframe you can pass it
around. The dataframe is a more high-level collection of data.

A good question is why a new dataframe structure when there is already
existing L<Data::Frame>. It's because the existing is based on L<PDL>
and I considered it too heavy a dependency when the plotter
(L<Statistics::Covid::Analysis::Plot::Simple>) or the
model fitter (L<Statistics::Covid::Analysis::Model::Simple>)
do not use (yet) L<PDL>.

The reason that this dataframe has not been turned into a
Class is because I do not want to do one before
I exhaust my search on finding an existing solution.

See L<Statistics::Covid::Analysis::Plot::Simple> how to plot
dataframes and L<Statistics::Covid::Analysis::Model::Simple>
how to fit models on data. They both take dataframes as
input.

=head1 EXPORT

None by default. But C<Statistics::Covid::Utils::datums2dataframe()>
is the sub to call with full qualified name.

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

    perldoc Statistics::Covid::Utils


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


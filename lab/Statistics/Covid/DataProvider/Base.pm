package Statistics::Covid::DataProvider::Base;

# parent class of all DataProvider classes

use 5.10.0;
use strict;
use warnings;

our $VERSION = '0.23';

use re 'regexp_pattern';

use Statistics::Covid::Utils;

#use LWP::ConsoleLogger::Easy qw( debug_ua );
use HTTP::Headers;
use HTTP::Request;
use HTTP::CookieJar::LWP;
use LWP::UserAgent;
use DateTime;
use File::Spec;
use File::Path;
use Data::Dump;
use File::Basename;
use WWW::Github::Files;

use Data::Dump qw/pp/;

# this will take all the pv (the perl-vars-from-json fetched)
# and create a data id to be used for labelling and saving to files
# this must be unique of each time point.
# the data generally should be for all locations
# it is specific to each data provider so abstract
# an array of data items or a single data item, depends
sub	create_data_id {
	die "create_data_id() : abstract method, you need to implement it.";
	#my $self = $_[0];
	#my $datas = $_[1]; # an array of data items or a single data item, depends
	# return data_id
}

# given some fetched data converted to perlvar
# this sub should create Datum objects from this perlvar
# the 1st parameter is an arrayref (see save_fetched_data_to_localfile() for what this data is)
# returns an arrayref of Datum objects on success or undef on failure
sub create_Datums_from_fetched_data {
	die "create_Datums_from_fetched_data() : abstract method you need to implement it"
	#my $self = $_[0];
	#my $datas = $_[1];
	# return \@datum_objs # return an array of Datum objects created
}
# post-process the fetched data (as an array etc.)
# it operates in-place
# the minimum functionality is for each data item in input $datas
# to fill in a data_id using create_data_id()
# we can't do it here because the $datas can contain metadata etc.
# each provider (as a child class of this) should know how to do that
# returns 1 on success, 0 on failure
sub postprocess_fetched_data {
	die "postprocess_fetched_data() : you need to implement me anyway, even if you have nothing to post-process"
	#my $self = $_[0];
	#my $datas = $_[1];
	# return 1 or 0
}
# saves the input datas (a perl arrayref) to a local file
# whose filename is deduced by our datafilesdir() and the
# data_id specific for each data
# returns undef on failure or an array of local files data saved to
# '$datas' is an arrayref of
# [ [url, data_received_string, data_as_perlvar] ... ] (where ... denotes optionally more of that first array)
# some data providers send data and metadata, in which cases $datas will contain 2
# such sub-arrays (metadata, followed by data)
# others send only data, so they have 1 such array.
# from others (like github or localdir) we may receive
# lots of datafiles one for each date, so that array will have
# as many items as files received/read.
# And other future providers may send more data items...
# About [url, data_received_string, data_as_perlvar, data_id] :
# url is where data was fetched
# data_received_string is the json string fetched (or whatever the provider sent)
# data_as_perlvar is the data received as a perlvar (if it's json we received, then JSON::json_decode()
# will give the perlvar.
# the 'data_id' part is produced by create_data_id($dataitem_above)
# this is actually filled in by the postprocess_fetched_data()
# which is provider-specific (overwritten by each provider child class)
# and knows what to do
sub save_fetched_data_to_localfile {
	die 'save_fetched_data_to_localfile()'." : abstract method you need to implement it"
	#my $self = $_[0];
	#my $datas = $_[1]; # an array of data items
	# return 0 or 1
}
# returns the data read if successful or undef if failed
sub load_fetched_data_from_localfile {
	die 'load_fetched_data_from_localfile()'." : abstract method you need to implement it"
	#my $self = $_[0];
	# this is the basename for the particular batch downloaded
	# depending on provider, some data is stored in just one file
	# as a perl variable (Data::Dump) with extension .pl
	# and also as a json file (verbatim from the data provider)
	# with extension .json.
	# Ideally you need only the .pl file
	# For other data providers, there are 2 files for each batch of data
	# 1 is the data, the other is metadata (for example the dates!)
	# so our input parameter is a basename which you either append a '.pm' and eval its contents
	# or do some more work to read the metadata also.
	# my $inbasename = $_[1];
	# return $datas_read_from_local_file
}
##### methods below are implemented and do not generally need to be overwritten

# creates an obj. There are no input params
sub     new {
	my ($class, $params) = @_;
	$params = {} unless defined $params;

	my $parent = ( caller(1) )[3] || "N/A";
	my $whoami = ( caller(0) )[3];

	my $self = {
		# urls is a an array of urls
		# each item/url contains
		#  [0] : the url
		#  [1] : optional headers as an arrayref (see HTTP::Request and its header)
		#  [2] : optional POST data, if this is defined then we do a POST
		#        else (not defined) we do a GET
		'urls' => undef,
		# alternatively specify github repo(s)
		# as an array of hashrefs of (author, resp, branch, path)
		# see JHUgithub.pm for an example
		'repository-github' => undef,
		# a local dir which holds JSON or CSV files
		'repository-local' => undef,

		'name' => undef, # this is the name for each provider, e.g. JHU or BBC
		'fileparams' => {
			# where downloaded data files go
			'datafiles-dir' => undef,
		},
		'save-to-file' => 1,
		'debug' => 0,
	};
	bless $self => $class;
	for (keys %$params){
		$self->{$_} = $params->{$_} if exists $self->{$_}
	}

	# we accept config-file or config-hash, see t/example-config.json for an example
	if( exists $params->{'config-file'} ){ if( ! $self->config_file($params->{'config-file'}) ){ warn "error, call to config_file() has failed."; return undef } }
	elsif( exists $params->{'config-hash'} ){ if( ! $self->config_hash($params->{'config-hash'}) ){ warn "error, call to config_hash() has failed."; return undef } }

	# you need to call init() from subclasses after new() and set
	# params
	return $self
}
sub	init {
	my $self = $_[0];

	my $debug = $self->debug();

	# leave the die someone is doing something wrong...
	die "'urls' or 'repository-github' or 'repository-local' have not been defined, set ONLY ONE via the parameters." unless defined($self->{'urls'}) || defined($self->{'repository-github'}) || defined($self->{'repository-local'});
	die "'datafiles-dir' has not been defined, set it via the parameters or specify a configuration file via 'config-file'." unless defined $self->datafilesdir();

	# make the output datadir
	if( ! Statistics::Covid::Utils::make_path($self->datafilesdir()) ){ warn "error, failed to create data dir '".$self->datafilesdir()."'."; return 0 }
	if( $debug > 0 ){ warn "check and/or made dir for datafiles '".$self->datafilesdir()."'." }
	return 1 # success
}
# returns undef on failure
# or an arrayref of [$aurl, $pv] on success
sub	fetch {
	my $self = $_[0];
	# params can contain params for the particular fetchers too
	# for example can contain hashref 'ua-params' to be passed to the UserAgent (for fetching urls)
	my $params = $_[1];

	my $debug = $self->debug();

	my $ret;
	if( defined $self->{'urls'} ){ if( ! defined($ret=$self->_fetch_from_urls($params)) ){ warn "error, ".'call to _fetch_from_urls()'." has failed"; return undef } }
	elsif( defined $self->{'repository-github'} ){ if( ! defined($ret=$self->_fetch_from_github_repository($params)) ){ warn "error, call to ".'_fetch_from_github_repository()'." has failed"; return undef } }
	elsif( defined $self->{'repository-local'} ){ if( ! defined($ret=$self->_fetch_from_local_repository($params)) ){ warn "error, call to ".'_fetch_from_local_repository()'." has failed"; return undef } }
	else { warn "error, 'urls', 'repository-github' and 'repository-local' are undefined, one must be specified"; return undef }

	# post-processing of the fetched data (in arrays)
	# at least if must create a data_id for each datas item fetched
	# children can overwrite postprocess_fetched_data() else, it is doing nothing as it is
	if( ! $self->postprocess_fetched_data($ret) ){ warn "error, call to ".'postprocess_fetched_data()'." has failed"; return undef }
	if( $debug > 0 ){ warn "postprocess_fetched_data() : done" }

	if( $self->save_to_file() ){
		my $debug = $self->debug();
		my $outbase = $self->save_fetched_data_to_localfile($ret);
		if( ! defined($outbase) ){ warn "error, failed to save the data just fetched to local file"; return undef }
		if( $debug > 0 ){ warn "saved fetched data to local files:\n   ".join("\n   ", @$outbase)."\nend of saved filenames list" }
	}

	return $ret
}
# returns undef on failure
# or an arrayref of [$aurl, $pv] on success
sub	_fetch_from_local_repository {
	my $self = $_[0];
	my $params = defined($_[1]) ? $_[1] : {};

	my $debug = exists($params->{'debug'})&&defined($params->{'debug'})
		? $params->{'debug'} : $self->debug();
	$Statistics::Covid::Utils::DEBUG = $debug;

	my $repoinfo = $self->{'repository-local'}->[0]; # just one url for us thank you
	my $paths;
	if( exists($params->{'paths'}) && defined($params->{'paths'}) ){ $paths = $params->{'paths'} }
	elsif( exists($repoinfo->{'paths'}) && defined($repoinfo->{'paths'}) ){ $paths = $repoinfo->{'paths'} }
	else { warn "error, the 'repository-local' hash does not define field 'paths' which should be an array to one or more dirs which contain files to process (subdirs will also be searched). Can be absolute or relative to current dir"; return undef }

	# was a file-pattern or filename specified either in params or self
	# precedence has filename over file-pattern and params over $self->{params}
	my ($m, $mm, @qrs, $q, $rem);
	if( exists($params->{'filenames'}) && defined($m=$params->{'filenames'}) ){
		if( ($rem=ref($m)) ne 'ARRAY' ){ warn "error, 'filenames' must be an arrayref and not $rem"; return undef }
		for my $q (@$m){
			$mm = qr!^.*?[\\/]*\Q${q}\E$!;
			if( ! defined($mm) ){ warn "error, failed to compile regex '$q'"; return undef }
			push @qrs, $mm;
		}
	} elsif( exists($repoinfo->{'filenames'}) && defined($m=$repoinfo->{'filenames'}) ){
		if( ($rem=ref($m)) ne 'ARRAY' ){ warn "error, 'filenames' must be an arrayref and not $rem"; return undef }
		for my $q (@$m){
			$mm = qr!^.*?[\\/]*\Q${q}\E$!;
			if( ! defined($mm) ){ warn "error, failed to compile regex '$q'"; return undef }
			push @qrs, $mm;
		}
	} elsif( exists($params->{'file-patterns'}) && defined($m=$params->{'file-patterns'}) ){
		if( ($rem=ref($m)) ne 'ARRAY' ){ warn "error, 'file-patterns' must be an arrayref and not $rem"; return undef }
		for my $q (@$m){
			if( ref($q) eq '' ){
				# we need to compile this pattern, it's a string with a regex
				$mm = qr/${q}/;
				if( ! defined($mm) ){ warn "error, failed to compile regex '$q'"; return undef }
				push @qrs, $mm;
			} else { push @qrs, $q } # an already compiled regex
		}
	} elsif( exists($repoinfo->{'file-patterns'}) && defined($m=$repoinfo->{'file-patterns'}) ){
		if( ($rem=ref($m)) ne 'ARRAY' ){ warn "error, 'file-patterns' must be an arrayref and not $rem"; return undef }
		for my $q (@$m){
			if( ref($q) eq '' ){
				# we need to compile this pattern, it's a string with a regex
				$mm = qr/${q}/;
				if( ! defined($mm) ){ warn "error, failed to compile regex '$q'"; return undef }
				push @qrs, $mm;
			} else { push @qrs, $q } # an already compiled regex
		}
	} else { push @qrs, qr// } # no file spec, use anything

	my $matched_files = Statistics::Covid::Utils::find_files($paths, \@qrs);
	if( ! defined $matched_files ){ warn "call to ".'Statistics::Covid::Utils::find_files()'." has failed for paths: '".join("', '", @$paths)."' and pattern: ".join(" ",regexp_pattern($m)); return undef }
	if( 0 == scalar(@$matched_files) ){ warn pp($repoinfo)."\nerror, no files matched 'file-patterns' pattern ".join(" ",regexp_pattern($m))." in path(s) '".join("', '", @$paths)."'"; return undef }

	if( $debug > 0 ){ warn "files to read from local repository:\n  ".join("\n  ", @$matched_files)."\nend list of files to fetch" } 

	my $has_header_at_this_line =
		exists($repoinfo->{'has-header-at-this-line'})
	     && defined($m=$repoinfo->{'has-header-at-this-line'})
		? $repoinfo->{'has-header-at-this-line'} : undef;
	my @ret;
	my $aurl;
	foreach my $afile (sort {$a cmp $b } @$matched_files){
		my $contents = Statistics::Covid::Utils::slurp_localfile($afile);
		if( ! defined $contents ){ warn pp($repoinfo)."\nerror, call to ".'Statistics::Covid::Utils::slurp_localfile()'." has failed for file '$afile'"; return undef }
		if( $debug > 0 ){ warn "fetched '$afile' ..." }
		my $pv = Statistics::Covid::Utils::csv2perl({
			'input-filename' => $afile,
			'has-header-at-this-line' => $has_header_at_this_line
		});
		if( ! defined $pv ){ warn pp($repoinfo)."\nerror, call to ".'Statistics::Covid::Utils::csv2perl()'." has failed for local file '$afile' of the above local-dir spec"; return undef }
		warn "data read from local file '$afile'";
		# e.g. https://api.github.com/repos/CSSEGISandData/COVID-19/contents/csse_covid_19_data/csse_covid_19_daily_reports/.gitignore?ref=33640a584cfe72958910c0a9620f4d0bcf36b159
		$aurl = 'file://'.$afile;
		push @ret, [$aurl, $contents, $pv];
	}
	return \@ret;
}
# returns undef on failure
# or an arrayref of [$aurl, $pv] on success
sub	_fetch_from_github_repository {
	my $self = $_[0];
	my $params = defined($_[1]) ? $_[1] : {};

	my $debug = exists($params->{'debug'})&&defined($params->{'debug'})
		? $params->{'debug'} : $self->debug();

	my $repoinfo = $self->{'repository-github'}->[0]; # just one url for us thank you
	if( ! exists($repoinfo->{'author'}) || ! defined($repoinfo->{'author'}) ){ warn "error, the 'repository-github' hash does not define field 'author'"; return undef }
	if( ! exists($repoinfo->{'resp'}) || ! defined($repoinfo->{'resp'}) ){ warn "error, the 'repository-github' hash does not define field 'resp'"; return undef }
	if( ! exists($repoinfo->{'branch'}) || ! defined($repoinfo->{'branch'}) ){ warn "error, the 'repository-github' hash does not define field 'branch', use 'master' if in doubt"; return undef }
	if( ! exists($repoinfo->{'path'}) || ! defined($repoinfo->{'path'}) ){ warn "error, the 'repository-github' hash does not define field 'path', use 'master' if in doubt"; return undef }

	# was a file-pattern or filename specified either in params or self
	# precedence has filename over file-pattern and params over $self->{params}
	my ($m, $mm, @qrs, $q, $rem);
	if( exists($params->{'filenames'}) && defined($m=$params->{'filenames'}) ){
		if( ($rem=ref($m)) ne 'ARRAY' ){ warn "error, 'filenames' must be an arrayref and not $rem"; return undef }
		for my $q (@$m){
			$mm =  qr!^.*?[\\/]*\Q${q}\E$!;
			if( ! defined($mm) ){ warn "error, failed to compile regex '$q'"; return undef }
			push @qrs, $mm;
		}
	} elsif( exists($repoinfo->{'filenames'}) && defined($m=$repoinfo->{'filenames'}) ){
		if( ($rem=ref($m)) ne 'ARRAY' ){ warn "error, 'filenames' must be an arrayref and not $rem"; return undef }
		for my $q (@$m){
			$mm =  qr!^.*?[\\/]*\Q${q}\E$!;
			if( ! defined($mm) ){ warn "error, failed to compile regex '$q'"; return undef }
			push @qrs, $mm;
		}
	} elsif( exists($params->{'file-patterns'}) && defined($m=$params->{'file-patterns'}) ){
		if( ($rem=ref($m)) ne 'ARRAY' ){ warn "error, 'file-patterns' must be an arrayref and not $rem"; return undef }
		for my $q (@$m){
			if( ref($q) eq '' ){
				# we need to compile this pattern, it's a string with a regex
				$mm = qr/${q}/;
				if( ! defined($mm) ){ warn "error, failed to compile regex '$q'"; return undef }
				push @qrs, $mm;
			} else { push @qrs, $q } # an already compiled regex
		}
	} elsif( exists($repoinfo->{'file-patterns'}) && defined($m=$repoinfo->{'file-patterns'}) ){
		if( ($rem=ref($m)) ne 'ARRAY' ){ warn "error, 'file-patterns' must be an arrayref and not $rem"; return undef }
		for my $q (@$m){
			if( ref($q) eq '' ){
				# we need to compile this pattern, it's a string with a regex
				$mm = qr/${q}/;
				if( ! defined($mm) ){ warn "error, failed to compile regex '$q'"; return undef }
				push @qrs, $mm;
			} else { push @qrs, $q } # an already compiled regex
		}
	} else { push @qrs, qr// } # no file spec, use anything

	my $gitter =  WWW::Github::Files->new(
		'author' => $repoinfo->{'author'},
		'resp' => $repoinfo->{'resp'},
		'branch' => $repoinfo->{'branch'},
	);
	if( ! defined $gitter ){ warn "error, call to ".'WWW::Github::Files->new()'." has failed"; return undef }

	my $path = $repoinfo->{'path'};
	my $op;
	$op = eval { $gitter->open($path) };
	if( $@ || ! defined $op ){ warn pp($repoinfo)."\nerror, failed to open remote path '$path' from above github-repo spec ".(defined($@)?$@:''); return undef }
	my @remote_files = eval { $op->readdir() };
	if( $@ ){ warn "error, failed to readdir($path), ".(defined($@)?$@:''); return undef };

	if( 0 == scalar(@remote_files) ){ warn pp($repoinfo)."\nerror, no files in remote path '$path' from above github-repo spec"; return undef }
	my @matched_files_to_fetch;
	my $afile;
	for $afile (@remote_files){
		for $m (@qrs){
			if( $debug > 1 ){ print "checking if remote file name '".$afile->{'name'}."' matches '$m'.." }
			if( $afile->{'name'} =~ $m ){
				push @matched_files_to_fetch, $afile;
				if( $debug > 1 ){ print "yes\n" }
			} else { if( $debug > 1 ){ print "no\n" } }
		}
	}
	if( 0 == scalar(@matched_files_to_fetch) ){ warn pp($repoinfo)."\nerror, no files matched 'file-patterns' pattern ".join(" ",regexp_pattern($m))." in remote path '$path' from above github-repo spec"; return undef }

	if( $debug > 0 ){ warn "files to fetch from remote githup repository:\n  ".join("\n  ", map { $_->{name} } @matched_files_to_fetch)."\nend list of files to fetch" } 

	my $has_header_at_this_line =
		exists($repoinfo->{'has-header-at-this-line'})
	     && defined($m=$repoinfo->{'has-header-at-this-line'})
		? $repoinfo->{'has-header-at-this-line'} : undef;
	my @ret;
	my $aurl;
	foreach my $_afile (sort {$a cmp $b} @matched_files_to_fetch){
		$aurl = $_afile->{'_links'}->{'self'};
		$aurl =~ s/\?ref=.+$//;
		$afile = '/'.$_afile->{'path'};
		my $contents = eval { $gitter->get_file($afile) };
		if( $@ || ! defined $contents ){ 
			warn "warning, failed to get_file($afile) (url is '$aurl'), skipping the rest and keeping what I have, $@";
			last
		}
		if( ! defined $contents ){ warn pp($repoinfo)."\nerror, failed to fetch file/path '$afile' from above github-repo"; return undef }
		if( $debug > 0 ){ warn "fetched '$afile' ..." }
		my $pv = Statistics::Covid::Utils::csv2perl({
			'input-string' => $contents,
			'has-header-at-this-line' => $has_header_at_this_line
		});
		if( ! defined $pv ){ warn pp($repoinfo)."\nerror, call to ".'Statistics::Covid::Utils::csv2perl()'." has failed for remote file '$afile' of the above github-repository"; return undef }
		# e.g. https://api.github.com/repos/CSSEGISandData/COVID-19/contents/csse_covid_19_data/csse_covid_19_daily_reports/.gitignore?ref=33640a584cfe72958910c0a9620f4d0bcf36b159
		warn "data fetched from remote repository: '$aurl'";
		push @ret, [$aurl, $contents, $pv]
	}
	return \@ret;
}
# returns undef on failure
# or an arrayref of [$aurl, $pv] on success
sub	_fetch_from_urls {
	my $self = $_[0];
	my $params = defined($_[1]) ? $_[1] : {};

	# optional debug param or use the one set at construction
	my $debug = exists($params->{'debug'})&&defined($params->{'debug'})
		? $params->{'debug'} : $self->debug();

	# optional ua-params in our input parameters
	my %ua_params = exists($params->{'ua-params'})&&defined($params->{'ua-params'})
		? %{$params->{'ua-params'}} : ();

	my $jar = HTTP::CookieJar::LWP->new;
	my $ua = LWP::UserAgent->new(
		cookie_jar => $jar,
		timeout => 50, # seconds
		agent => 'Mozilla/5.0 (Windows NT 6.1; WOW64; rv:64.0) Gecko/20100101 Firefox/64.0',
		%ua_params # overwrites any of the above if needed
	);
	if( ! defined $ua ){ warn "error, call to ".'LWP::UserAgent->new()'." has failed"; return undef }
	#debug_ua($ua);
	# the return array will be [url, perlvar] for each url
	my @retPerlVars = ();
	my ($response, $request, $aurl, $headers, $post_data);
	my $idx = 0;
	for my $anentry (@{$self->{'urls'}}){
		my $cb;
		$aurl = $anentry->{'url'};
		if( ! defined $aurl ){ warn pp($self->{'urls'})."\nerror, url is not defined for index $idx and above urls data"; return undef }
		if( defined($cb=$anentry->{'cb-preprocess'}) ){
			if( $debug > 0 ){ warn "calling preprocess callback ..." }
			if( ! $cb->($self) ){ warn "error, preprocess callback has failed for url '$aurl'"; return undef }
			if( $debug > 0 ){ warn "done, called preprocess callback, success" }
		}
		if( $debug > 0 ){ warn "fetching url '$aurl' (index $idx) ...\n" }
		$headers = exists($anentry->{'headers'}) && defined($anentry->{'headers'})
			? $anentry->{'headers'} : [];
		$post_data = exists($anentry->{'post-data'}) && defined($anentry->{'post-data'})
			? $anentry->{'post-data'} : undef;
		if( defined $post_data ){
			$request = eval { HTTP::Request->new('POST', $aurl, $headers, $post_data) };
			if( $@ || ! defined $request ){ warn $post_data."\nerror, (index $idx) call to ".'HTTP::Request->new(POST)'." has failed for this url '$aurl' and for above post data: ".$@; return undef }
		} else {
			$request = eval { HTTP::Request->new('GET', $aurl, $headers) };
			if( $@ || ! defined $request ){ warn "error, (index $idx) call to ".'HTTP::Request->new(GET)'." has failed for this url '$aurl' : ".$@; return undef }
		}

		$response = $ua->request($request);
		if( ! $response->is_success ){
			warn "failed to get url '$aurl': ".$response->status_line;
			return undef;
		}

		my $remote_content = $response->decoded_content;
		if( ! defined $remote_content or $remote_content eq '' ){
			warn "failed to get url '$aurl': content is empty";
			return undef;
		}
		if( $debug > 1 ){ warn "fetched this data from url '$aurl':\n".$remote_content."\nend of data from url '$aurl'." }

		my $pv;
		if( defined($cb=$anentry->{'cb-postprocess'}) ){
			if( $debug > 0 ){ warn "calling postprocess callback ..." }
			$pv = $cb->($self, $remote_content);
			if( ! defined $pv ){ warn "error, postprocess callback has failed for url '$aurl'"; return undef }
			if( $debug > 0 ){ warn "done, called postprocess callback, success." }
		} else {
			$pv = Data::Roundtrip::json2perl($remote_content);
			if( ! defined $pv ){ warn $remote_content."\n\nfailed to parse above json data from URL '$aurl', is it valid?"; return undef; }
		}
		my $adatas = [$aurl, $remote_content, $pv];
		push @retPerlVars, [$aurl, $remote_content, $pv];
		$idx++;
	}
	return \@retPerlVars;
}
sub	debug {
	my $self = $_[0];
	my $m = $_[1];
	if( defined $m ){ $self->{'debug'} = $m; return $m }
	return $self->{'debug'}
}
sub     fileparams {
	my $self = $_[0];
	my $m = $_[1];
	return $self->{'fileparams'} unless defined $m;
	$self->{'fileparams'} = $m;
	if( ! exists $m->{'datafiles-dir'} or ! defined $m->{'datafiles-dir'} ){ $m->{'datafiles-dir'} = '.' }
	else {
		# now make sure target dir is created already or create it
		# make the output datadir
		if( ! Statistics::Covid::Utils::make_path($m->{'datafiles-dir'}) ){ warn "error, failed to create data dir '".$m->{'datafiles-dir'}."'."; return 0 }
		if( $self->debug() > 0 ){ warn "checked and/or made dir for data files '".$m->{'datafiles-dir'}."'." }
	}
	return $m;
}
sub	datafilesdir {
	my $self = $_[0];
	my $m = $_[1];
	if( defined $m ){ $self->{'fileparams'}->{'datafiles-dir'} = $m; return $m }
	return $self->{'fileparams'}->{'datafiles-dir'}
}
sub	save_to_file {
	my $self = $_[0];
	my $m = $_[1];
	if( defined $m ){ $self->{'save-to-file'} = $m; return $m }
	return $self->{'save-to-file'}
}
sub	name {
	my $self = $_[0];
	my $m = $_[1];
	if( defined $m ){ $self->{'name'} = $m; return $m }
	return $self->{'name'}
}
sub	urls {
	my $self = $_[0];
	my $m = $_[1];
	if( defined $m ){ $self->{'urls'} = $m; return $m }
	return $self->{'urls'}
}
sub	repository_local {
	my $self = $_[0];
	my $m = $_[1];
	if( defined $m ){ $self->{'repository-local'} = $m; return $m }
	return $self->{'repository-local'}
}
sub	repository_github {
	my $self = $_[0];
	my $m = $_[1];
	if( defined $m ){ $self->{'repository-github'} = $m; return $m }
	return $self->{'repository-github'}
}

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
	return $self->config_hash($inhash)
}
sub	config_hash {
	my ($self, $inhash) = @_;
	if( exists $inhash->{'fileparams'} ){ if( ! $self->fileparams($inhash->{'fileparams'}) ){ warn "error, call to fileparams() has failed."; return undef } }
	return 1 # success
}
sub	toString {
	my $self = $_[0];
	my $ret = "DataProvider: ".$self->name().':'
		."\ndata files dir: ".$self->datafilesdir()
	;
	my $m;
	if( defined($m=$self->urls()) ){
		$ret .= "\nurls:\n".pp($m)."\n"
	} elsif( defined($m=$self->repository_local()) ){
		$ret .= "\nrepository-local:\n".pp($m)."\n"
	} elsif( defined($m=$self->repository_github()) ){
		$ret .= "\nrepository-github:\n".pp($m)."\n"
	}
	return $ret
}
1;
__END__
# end program, below is the POD

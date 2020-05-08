package Statistics::Covid::DataProvider::World::JHUlocaldir;

# Johns Hopkins University

use 5.10.0;
use strict;
use warnings;

our $VERSION = '0.24';

use parent 'Statistics::Covid::DataProvider::Base';

use DateTime;
use File::Spec;
use File::Path;
use Data::Dump qw/pp/;

use Statistics::Covid::Utils;
use Statistics::Covid::Datum;
use Statistics::Covid::Geographer;

# new method inherited but here we will create one
# to be used as a factory
sub new {
	my ($class, $params) = @_;
	$params = {} unless defined $params;
	# this is from a github repository not a url
	my ($m, $mm, $q, @filepaQR);
	if( exists($params->{'file-patterns'}) && defined($m=$params->{'file-patterns'}) ){
		if( ref($m) ne 'ARRAY' ){ warn "error, 'file-patterns' expect an arrayref of patterns, not '".ref($m)."'"; return undef }
		for my $q (@$m){
			$mm = qr/${q}/;
			if( ! defined $mm ){ warn "error, 'file-patterns'\n$q\nfailed to compile to a regex"; return undef }
			push @filepaQR, $mm
		}
	} else { push(@filepaQR, qr/\d{2}\-\d{2}\-\d{4}\.csv/i) } # << default file-patterns for JHU files
	my $filenames = exists($params->{'filenames'}) && defined($params->{'filenames'})
		? $params->{'filenames'} : undef;

	$params->{'repository-local'} = [
	    { # start a local repository
		'paths' => exists($params->{'paths'})
			? $params->{'paths'} : undef
		,
		# default file pattern (can also be set as a parameter to fetch())
		'file-patterns' => \@filepaQR, # there is a default see above
		'file-type' => 'CSV',
		'has-header-at-this-line' => 1,
		'overwrite' => 0, # fetch files again if already exist locally?
		'filenames' => $filenames, # default is undef
	    }, # end a github repository
	];

	# initialise our parent class
	my $self = $class->SUPER::new($params);
	if( ! defined $self ){ warn "error, call to $class->new() has failed."; return undef }

	# and do set parameters specific to this particular data provider
	$self->name('World::JHUlocaldir'); # <<<< Make sure this is unique over all providers
	$self->datafilesdir(File::Spec->catfile(
		$self->datafilesdir(), # use this as prefix it was set in config
		# and append a dir hierarchy relevant to this provider
		# all :: will become '/' (filesys separators)
		split(/::/, $self->name())
	)); # so this is saved to <datafilesdir>/World/JHU

	# initialise this particular data provider
	if( ! $self->init() ){ warn "error, call to init() has failed."; return undef }

	# this will now be JHU obj (not generic)
	return $self
}
# post-process the fetched data (as an array of arrays etc.)
# each item in the inp arrayref is a [url,fetched_data, pv]
# and we calculate its data_id as well as make sure the variation
# in keys from version to version is handled robustly
# it operates in-place
# returns 1 on success, 0 on failure
sub postprocess_fetched_data {
	my $self = $_[0];
	my $datas = $_[1];

	my ($d, $v, $ad, $k, $data_id, $errors, $aurl);
	# we have Province/State or Province_State
	# earlier versions:
	# Province/State,Country/Region,Last Update,Confirmed,Deaths,Recovered
	# other versions
	# Province/State,Country/Region,Last Update,Confirmed,Deaths,Recovered,Latitude,Longitude
	# we have later versions:
	# FIPS,Admin2,Province_State,Country_Region,Last_Update,Lat,Long_,Confirmed,Deaths,Recovered,Active,Combined_Key
	# replace all spaces and slashes with a single underscore '_'	
	# and lowercase all keys
	# Latitude,Longitude become 'lat' and 'long_'

	# if we get errors, we will skip them by creating a new array...
	for my $adatas (@$datas){
		$aurl = $adatas->[0];
		$errors = 0;
		my @nd;
		for $ad (@{$adatas->[2]}){
			my %newhash;
			for $k (keys %$ad){
				$v = $ad->{$k};
				$k =~ s=/=_=g; # we have Province/State or Province_State
				$k =~ s=\s+=_=g;
				$k = lc $k;
				$k =~ s/^lati.+$/lat/;
				$k =~ s/^longi.+$/long_/;
				#print "NEW '$k'\n";
				$newhash{$k} = $v;
			}
			# validate:
			if( ! defined($newhash{'last_update'}) || ($newhash{'last_update'} eq '') ){
				warn pp(\%newhash)."\nwarning, 'last_update' field for above data is empty (for url '$aurl')";
				$errors++;
			} else {
				push @nd, \%newhash
			}
		}
		# in-place modification:
		$adatas->[2] = \@nd;
		# in-place additon of a data_id to each datas item
		$data_id = $self->create_data_id($adatas);
		if( ! defined $data_id ){ warn "warning, call to ".'create_data_id()'." has failed for the content from url '".$adatas->[0]."'"; return 0 }
		$adatas->[3] = $data_id;
		if( $errors > 0 ){ warn "warning, $errors items in data did not validate and were discarded (from url '$aurl')" }
	}
	return 1
}
# overwriting this from parent
# returns undef on failure or a data id unique on timepoint
# which can be used for saving data to a file or labelling this data
sub create_data_id {
	my $self = $_[0];
	my $adatas = $_[1]; # this is an arrayref of [url, data_received_string, data_as_perlvar] (and not an array of arrays)

	# get the date from the first pv
	my $aurl = $adatas->[0];
	my $apv = $adatas->[2];
	# note this is in any kind of funny date
	my $epochsecs;
	my $i = 0;
	my $dt = Statistics::Covid::Utils::JHU_datestring_to_DateTime($apv->[$i]->{'last_update'});
	if( ! defined $dt ){ warn pp($apv->[$i])."\nerror, call to ".'JHU_datestring_to_DateTime()'." has failed for 'last_update' value of '".$apv->[$i]->{'last_update'}."' for above data"; return undef }
	my $latest = [$dt->epoch(), $i];
	for($i=scalar(@{$apv});$i-->1;){
		# note that this is like 2020-03-21T10:13:08
		$dt = Statistics::Covid::Utils::JHU_datestring_to_DateTime($apv->[$i]->{'last_update'});
		# just ignore it if it does not validate but it should have been removed earlier
		# in postprocess!
		if( ! defined $dt ){
			warn pp($apv->[$i])."\nwarning, call to ".'JHU_datestring_to_DateTime()'." has failed for 'last_update' value of '".$apv->[$i]->{'last_update'}."' for above data from '$aurl' and it will be skipped BUT IT SHOULD HAVE BEEN CAUGHT in postprocess_fetched_data ";
			next
		}
		$epochsecs = $dt->epoch();
		if( $epochsecs > $latest->[0] ){ $latest->[0] = $epochsecs; $latest->[1] = $i; }
	}
	$i = $latest->[1];
	$epochsecs = $latest->[0];
	if( ! defined($dt=Statistics::Covid::Utils::JHU_datestring_to_DateTime($epochsecs)) ){
		warn pp($apv->[$i])."\nerror, failed to parse date '$epochsecs' from input json data just transfered from url '$aurl'.";
		return undef;
	}
	my $dataid = $dt->strftime('2020-%m-%dT%H.%M.%S')
		     . '_'
		     . $epochsecs
	;
	if( $self->debug() > 0 ){ warn "create_data_id() : using last updated time of '".$apv->[$i]->{'country_region'}."', last updated on: ".$dt->iso8601() }
	return $dataid
}
# returns the data read if successful or undef if failed
# as an array of arrays
sub load_fetched_data_from_localfile {
	my $self = $_[0];
	my $inbasename = $_[1]; # BASENAME (not filename)

	my $infile = $inbasename . '.data.csv';
	my $infh;
	if( ! open($infh, '<:encoding(UTF-8)', $infile) ){ warn "error, failed to open file '$infile' for reading, $!"; return undef }
	my $csv_contents; {local $/=undef; $csv_contents = <$infh> } close $infh;
	my $pv = Statistics::Covid::Utils::csv2perl({
		'input-string' => $csv_contents,
		'has-header-at-this-line' => 1,
	});
	if( ! defined $pv ){ warn "error, call to ".'Data::Roundtrip::json2perl()'." has failed (for data, file '$infile')."; return undef }
	if( $self->debug() > 0 ) { warn "load_fetched_data_from_localfile() : read file '$infile' ..." }
	my $ret = [['file://'.$infile, $csv_contents, $pv]];
	if( ! $self->postprocess_fetched_data($ret) ){ warn "error, call to ".'postprocess_fetched_data()'." has failed"; return undef }
	return $ret
}
sub create_Datums_from_fetched_data {
	my $self = $_[0];
	# the fetched data as an arrayref of arrayrefs
	# with as many elements as files read, each item is [url, data_received_string, data_as_perlvar, data_id]
	my $datas = $_[1];

	my @ret;
	my ($admin0, $admin1, $admin2, $admin3, $admin4,
	    $datetimeobj, $aWorldLocation, $datumobj,
	    $id, $lat, $long, $type, $official_name, $pv, $province_state, $country_region,
	    $confirmed, $recovered, $deaths, $incidentrate, $peopletested, $m,
	);
	my $ds = $self->name();
	for my $adata (@$datas){
		#my $aurl = $adata->[0];
		#my $content = $adata->[1];
		$pv = $adata->[2]; # getting to the array of locations
		for $aWorldLocation (@$pv){
			$admin2 = exists($aWorldLocation->{'admin2'}) && defined($aWorldLocation->{'admin2'})
				? $aWorldLocation->{'admin2'} : undef;
			$admin3 = exists($aWorldLocation->{'admin3'}) && defined($aWorldLocation->{'admin3'})
				? $aWorldLocation->{'admin3'} : undef;
			$admin4 = exists($aWorldLocation->{'admin4'}) && defined($aWorldLocation->{'admin4'})
				? $aWorldLocation->{'admin4'} : undef;
			$province_state = $aWorldLocation->{'province_state'};
			if( defined($province_state) ){ $province_state =~ s/^\s+|\s+$// }
			$country_region = $aWorldLocation->{'country_region'};
			$lat = defined($aWorldLocation->{'lat'}) ? $aWorldLocation->{'lat'} : '<na>';
			$long = defined($aWorldLocation->{'long_'}) ? $aWorldLocation->{'long_'} : '<na>';
			$incidentrate = defined($aWorldLocation->{'Incident_Rate'}) ? $aWorldLocation->{'Incident_Rate'} : -1;
			$peopletested = defined($aWorldLocation->{'People_Tested'}) ? $aWorldLocation->{'People_Tested'} : -1;
			if( exists($aWorldLocation->{'confirmed'}) && defined($m=$aWorldLocation->{'confirmed'}) && ($m ne '') ){ $confirmed = 0+$m } else { $confirmed = 0 }
			if( exists($aWorldLocation->{'recovered'}) && defined($m=$aWorldLocation->{'recovered'}) && ($m ne '') ){ $recovered = 0+$m } else { $recovered = 0 }
			if( exists($aWorldLocation->{'deaths'}) && defined($m=$aWorldLocation->{'deaths'}) && ($m ne '') ){ $deaths = 0+$m } else { $deaths = 0 }
			if( defined($country_region) ){
			  $country_region =~ s/^\s+|\s+$//;
			  if( $country_region =~ /\bship\b/i ){
				$official_name = Statistics::Covid::Geographer::get_official_name($province_state);
				if( ! defined $official_name ){ die pp($aWorldLocation)."\ncould not find official name for province_state='$province_state' in above data" }
				$admin1 = $official_name;
				$admin0 = 'Cruise Ship';
				$type = 'ship';
			  } elsif( defined($province_state)
			        && $province_state =~ /\bship\b/i
			  ){
				$official_name = Statistics::Covid::Geographer::get_official_name($country_region);
				if( ! defined $official_name ){ die pp($aWorldLocation)."\ncould not find official name for country_region='$country_region' in above data" }
				$admin1 = $official_name;
				$admin0 = 'Cruise Ship';
				$type = 'ship';
			  } elsif( ! defined($province_state)
				   || ($province_state eq '')
				   || ($province_state eq 'None')
				   || ($province_state eq 'fix')
				   || ($province_state eq $country_region) # e.g. France,France
			  ){
				$official_name = Statistics::Covid::Geographer::get_official_name($country_region);
				if( ! defined $official_name ){ die pp($aWorldLocation)."\ncould not find official name for country_region='$country_region' in above data (4)" }
				$admin0 = $official_name;
				$admin1 = '';
				$type = 'admin0'; # a country (as opposed to a province)
			  } else {
				$official_name = Statistics::Covid::Geographer::get_official_name($country_region);
				if( ! defined $official_name ){ die pp($aWorldLocation)."\ncould not find official name for country_region='$country_region' in above data (3)" }
				$admin1 = $province_state;
				$admin0 = $official_name;
				$type = 'admin1'; # a province or state or local authority...
			  }
			} else { die pp($aWorldLocation)."\ndon't know how to handle the above data (2)" }

			$datetimeobj = Statistics::Covid::Utils::JHU_datestring_to_DateTime($aWorldLocation->{'last_update'});
			if( ! defined $datetimeobj ){ warn pp($aWorldLocation)."\n\nerror, call to ".'Statistics::Covid::Utils::JHU_datestring_to_DateTime()'." has failed for date field of 'last_update' in the above parameters (it must be like '2020-04-01 21:58:49'. A filename (or a url) may be associated with it at\n  ".$adata->[0]."\n"; return undef }
			$id = join('/', $admin0, $admin1,
				defined($admin2) ? $admin2:'',
				defined($admin3) ? $admin3:'',
				defined($admin4) ? $admin4:'',
				$datetimeobj->epoch()
			);
			my %datparams = (
				'id' => $id,
				'admin0' => $admin0,
				'admin1' => $admin1,
				'confirmed' => $confirmed,
				'recovered' => $recovered,
				'terminal' => $deaths,
				# what is 'Active'?
				'date' => $datetimeobj,
				'type' => $type,
				'datasource' => $ds,
				'incidentrate' => $incidentrate,
				'peopletested' => $peopletested,
			);
			$datparams{'admin2'} = $admin2 if defined $admin2;
			$datparams{'admin3'} = $admin2 if defined $admin3;
			$datparams{'admin4'} = $admin2 if defined $admin4;
			$datumobj = Statistics::Covid::Datum->new(\%datparams);
			if( ! defined $datumobj ){ warn "error, call to ".'Statistics::Covid::Datum->new()'." has failed for url '".$adata->[0]."' and this data: ".join(",", @$aWorldLocation); return undef }
			push @ret, $datumobj;
		}
	}
	return \@ret
}
# saves data received as CSV and PL (perl variables)
# into files whose basename is specified by our datafilesdir()
# and this data's data_id (see create_data_id()) and the extension '.data.csv', '.data.pl'
# '$datas' is an arrayref of
# [ [url, data_received_string, data_as_perlvar, optiona-data-id], [...] ]
# there must be one inner item for each local file read
# the 3rd entry in the item is optional and is the data_id if it was already
# created, else we create it here
# this provider does not have any metadata, all data is received in 1 chunk for each remote file read
# returns undef on failure or the ARRAY of OUTBASE (one for each saved file) 
# if successful, so each local file is saved separately
sub save_fetched_data_to_localfile {
	my $self = $_[0];
	my $datas = $_[1]; # this is an arrayref of [url, data_received_string, data_as_perlvar]

	my ($dataid, @outbases, $outbase, $outfile);
	# the input datas array is in this case [[..],[...]...]
	# i.e. there is an item for each file we read
	for my $adatas (@$datas){
		if( ! defined($dataid=$adatas->[3]) ){
			$dataid = $self->create_data_id($adatas);
			if( ! defined $dataid ){
				warn "error, call to ".'create_data_id()'." has failed.";
				return undef;
			}
			$adatas->[3] = $dataid;
		}
		$outbase = File::Spec->catfile($self->datafilesdir(), $dataid);

		$outfile = $outbase . '.data.csv';
		my $aurl = $adatas->[0];
		if( ! Statistics::Covid::Utils::save_text_to_localfile($adatas->[1], $outfile) ){ warn "error, call to ".'save_text_to_localfile()'." has failed for url '$aurl'."; return undef }
		$outfile = $outbase . '.data.pl';
		if( ! Statistics::Covid::Utils::save_perl_var_to_localfile($adatas->[2], $outfile) ){ warn "error, call to ".'save_perl_var_to_localfile()'." has failed for url '$aurl'."; return undef }
		print "save_fetched_data_to_localfile() : saved data to '$outfile' (and csv too).\n";
		push @outbases, $outbase;
	}
	return \@outbases
}
1;
__END__
# end program, below is the POD

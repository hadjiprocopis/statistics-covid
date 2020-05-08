package Statistics::Covid::DataProvider::World::JHU;

# Johns Hopkins University

use 5.10.0;
use strict;
use warnings;

our $VERSION = '0.23';

use parent 'Statistics::Covid::DataProvider::Base';

use DateTime;
use File::Spec;
use File::Path;
use Data::Dump qw/pp/;

use Statistics::Covid::Utils;
use Statistics::Covid::Geographer;

# new method inherited but here we will create one
# to be used as a factory
sub new {
	my ($class, $params) = @_;
	$params = {} unless defined $params;
	$params->{'urls'} = [
	    { # start a url
		# check the resultRecordCount=10000 and where=TotalCases%20%3E%3D%200
		# modified for where=TotalCases%20%3D%3E%200 (that is >=0) and resultRecordCount=10000
		# and change resultRecordCount=200
		'url' => <<'EOS',
https://services9.arcgis.com/N9p5hsImWXAccRNI/arcgis/rest/services/Nc2JKvYFoAEOFCG5JSI6/FeatureServer/1/query?f=json&where=Country_Region%3D%27US%27&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&orderByFields=Confirmed%20desc%2CCountry_Region%20asc%2CProvince_State%20asc&resultOffset=0&resultRecordCount=1200&cacheHint=true
EOS
		#'url' => 'https://services9.arcgis.com/N9p5hsImWXAccRNI/arcgis/rest/services/Nc2JKvYFoAEOFCG5JSI6/FeatureServer/1/query?f=json&where=Deaths%3E0&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&orderByFields=Deaths%20desc%2CCountry_Region%20asc%2CProvince_State%20asc&resultOffset=0&resultRecordCount=1250&cacheHint=true',
		# old, which it stopped working 22
		#'https://services9.arcgis.com/N9p5hsImWXAccRNI/arcgis/rest/services/Z7biAeD8PAkqgmWhxG2A/FeatureServer/1/query?f=json&where=Confirmed%20%3E%3D%200&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&orderByFields=Confirmed%20desc%2CCountry_Region%20asc%2CProvince_State%20asc&resultOffset=0&resultRecordCount=250&cacheHint=true',
		#'https://services9.arcgis.com/N9p5hsImWXAccRNI/arcgis/rest/services/Z7biAeD8PAkqgmWhxG2A/FeatureServer/1/query?cacheHint=true&f=json&orderByFields=Confirmed+desc%2CCountry_Region+asc%2CProvince_State+asc&outFields=*&resultOffset=0&resultRecordCount=250&returnGeometry=false&spatialRel=esriSpatialRelIntersects&where=Confirmed+%3E+0',
		# the headers associated with that url
		'headers' => [
			'Cache-Control'     => 'max-age=0',
			'Connection'        => 'keep-alive',
			'Accept'	    => '*/*',
			'Accept-Encoding'   => 'gzip, x-gzip, deflate, x-bzip2, bzip2',
			'Accept-Language'   => 'en-US,en;q=0.5',
			'Host'		    => 'services9.arcgis.com:443',
			# likes this: 'Mon, 16 Mar 2020 21:14:13 GMT',
			'If-Modified-Since' => DateTime->now(time_zone=>'GMT')->add(minutes=>-1)->strftime('%a, %d %b %Y %H:%M:%S %Z'),
			'If-None-Match'     => 'sd8_-224912290',
			'Referer'           => 'https://services9.arcgis.com/N9p5hsImWXAccRNI/arcgis/rest/services/Z7biAeD8PAkqgmWhxG2A/FeatureServer/1/query?f=json&where=Confirmed%20%3E%200&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&orderByFields=Confirmed%20desc%2CCountry_Region%20asc%2CProvince_State%20asc&resultOffset=0&resultRecordCount=250&cacheHint=true',
			'TE'                => 'Trailers',
			# we have our own default
			#'User-Agent'        => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.20; rv:61.0) Gecko/20100101 Firefox/73.0',
			'DNT'               => '1',
			'Origin'            => 'https://www.arcgis.com',
		], # end headers
		'post-data' => undef,
	    }, # end a url
	]; # end 'urls'

	# initialise our parent class
	my $self = $class->SUPER::new($params);
	if( ! defined $self ){ warn "error, call to $class->new() has failed."; return undef }

	# and do set parameters specific to this particular data provider
	$self->name('World::JHU'); # <<<< Make sure this is unique over all providers
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
# overwriting this from parent
# returns undef on failure or a data id unique on timepoint
# which can be used for saving data to a file or labelling this data
sub create_data_id {
	my $self = $_[0];
	my $adatas = $_[1]; # this is an arrayref of [url, data_received_string, data_as_perlvar] and not an arrayref of arrayrefs!

	# get the date from the first pv

	# this json is idiotic because it's just arrays,
	# 0: location id
	# 1: location name
	# 2: cases
	# 3: population
	# unless [0] is 'UpdatedOn', in which case [1] is 09:00 GMT, 15 March
	# thankfully this update info is last
	my $date = undef;
	my $aurl = $adatas->[0];
	my $apv = $adatas->[2];
	# note this is in milliseconds epoch, but parser will take care
	# also note that this is about countries and each country has its own last-update
	# some countries (only china?) have province data too
	# so, for the time being find the maximum epoch which is the latest data at least one country was updated
	# epoch and index in the array
	my $latest = [$apv->{'features'}->[0]->{'attributes'}->{'Last_Update'}, 0];
	my $epoch_date_str;
	for(my $i=scalar(@{$apv->{'features'}});$i-->1;){
		# note that this is millis epoch
		$epoch_date_str = $apv->{'features'}->[$i]->{'attributes'}->{'Last_Update'} + 0;
		if( $epoch_date_str > $latest->[0] ){ $latest = [$epoch_date_str, $i] }
	}
	$epoch_date_str = $apv->{'features'}->[$latest->[1]]->{'attributes'}->{'Last_Update'};
	if( ! defined($date=Statistics::Covid::Utils::epoch_milliseconds_to_DateTime($epoch_date_str)) ){
		warn "error, failed to parse date '$epoch_date_str' from input json data just transfered from url '$aurl'.";
		return undef;
	}
	my $dataid = $date->strftime('2020-%m-%dT%H.%M.%S')
		     . '_'
		     . $date->epoch()
	;
	if( $self->debug() > 0 ){ warn "create_data_id() : using last updated time of '".$apv->{'features'}->[$latest->[1]]->{'attributes'}->{'Country_Region'}."', last updated on: ".$date->iso8601() }
	return $dataid
}
# returns the data read if successful or undef if failed
sub load_fetched_data_from_localfile {
	my $self = $_[0];
	my $inbasename = $_[1];

	my $infile = $inbasename . '.data.json';
	my $infh;
	if( ! open($infh, '<:encoding(UTF-8)', $infile) ){ warn "error, failed to open file '$infile' for reading, $!"; return undef }
	my $json_contents; {local $/=undef; $json_contents = <$infh> } close $infh;
	my $pv = Data::Roundtrip::json2perl($json_contents);
	if( ! defined $pv ){ warn "error, call to ".'Data::Roundtrip::json2perl()'." has failed (for data, file '$infile')."; return undef }
	if( $self->debug() > 0 ) { warn "load_fetched_data_from_localfile() : read file '$infile' ..." }
	my $ret = [['file://'.$infile, $json_contents, $pv]];
	if( ! $self->postprocess_fetched_data($ret) ){ warn "error, call to ".'postprocess_fetched_data()'." has failed"; return undef }
	return $ret
}
# post-process the fetched data (as an array of arrays etc.)
# it operates in-place
# returns 1 on success, 0 on failure
sub postprocess_fetched_data {
	my $self = $_[0];
	my $datas = $_[1];

	# no metadata, just data
	my $index = 0;
	my $dataid = $self->create_data_id($datas->[$index]);
	if( ! defined $dataid ){ warn "error, call to ".'create_data_id()'." has failed for '".$datas->[$index]->[0]."'"; return 0 }
	$datas->[$index]->[3] = $dataid;
	return 1
}
# a slight overwrite(sic) of the parent's method
# both URL and GIT have keys all lower case
# (url has keys capitalised like: Last_Update
#   whereas the git is Last_Update (just trying to recycle code from JHU.pm)
#sub     _fetch_from_urls {
#	my $self = $_[0];
#	my $params = $_[1];
#	my $ret = $self->SUPER::_fetch_from_urls($params);
#	if( ! defined $ret ){ warn "error, call to parent's ".'SUPER::_fetch_from_github_repository()'." has failed"; return undef }
#	# capitalise first letter of keys
#	my $ahash;
#	my $f = $ret->[0]->[2]->{'features'};
#	for(my $i=scalar(@{$f});$i-->0;){
#		$ahash = $f->[$i];
#		my %newhash = map { lc $_ => $ahash->{$_} } keys %$ahash;
#		$f->[$i] = \%newhash
#	}
#	return $ret;
#}
sub create_Datums_from_fetched_data {
	my $self = $_[0];
	my $datas = $_[1]; # the fetched data as an arrayref with 1 element which is an array of [url, data_received_string, data_as_perlvar]

	my $data = $datas->[0]->[2]->{'features'}; # getting to the array of locations
# data is an array of
#	  {
#   	 attributes => {
#   	   Active => 6285,
#   	   Admin2 => undef,
#   	   Combined_Key => 'fix',
#   	   Confirmed => 67800,
#   	   Country_Region => "China",
#   	   Deaths => 3133,
#   	   FIPS => 'fix',
#   	   Last_Update => 1584690182000,
#   	   Lat => 30.9756403482891,
#   	   Long_ => 112.270692167452,
#   	   OBJECTID => 106,
#   	   Province_State => "Hubei",
#   	   Recovered => 58382,
#   	 },

# and for countries only data
#	{
#	  attributes => {
#	    Active => 91,
#	    Admin2 => 'fix',
#	    Combined_Key => 'fix',
#	    Confirmed => 95,
#	    Country_Region => "Cyprus",
#	    Deaths => 1,
#	    FIPS => 'fix',
#	    Last_Update => 1584895387000,
#	    Lat => 35.1264,
#	    Long_ => 33.4299,
#	    OBJECTID => 7,
#	    Province_State => 'fix',
#	    Recovered => 3,
#	  },

	my $ds = $self->name();
	my ($admin0, $admin1, $admin2, $admin3, $admin4,
	    $datetimeobj, $lat, $long, $type,
	    $official_name, $id, $province_state, $country_region,
	    $confirmed, $recovered, $deaths, $incidentrate, $peopletested, $m
	);
	my @ret = ();
	#print "BEGIN Data received:\n".pp($data)."\nEND data\n";
	for my $aWorldLocation (@$data){
		$aWorldLocation = $aWorldLocation->{'attributes'};
		$admin2 = exists($aWorldLocation->{'Admin2'}) && defined($aWorldLocation->{'Admin2'})
			? $aWorldLocation->{'Admin2'} : undef;
		$admin3 = exists($aWorldLocation->{'Admin3'}) && defined($aWorldLocation->{'Admin3'})
			? $aWorldLocation->{'Admin3'} : undef;
		$admin4 = exists($aWorldLocation->{'Admin4'}) && defined($aWorldLocation->{'Admin4'})
			? $aWorldLocation->{'Admin4'} : undef;

		$province_state = $aWorldLocation->{'Province_State'};
		if( defined($province_state) ){ $province_state =~ s/^\s+|\s+$// }
		$country_region = $aWorldLocation->{'Country_Region'};
		$lat = defined($aWorldLocation->{'Lat'}) ? $aWorldLocation->{'Lat'} : '<na>';
		$long = defined($aWorldLocation->{'Long_'}) ? $aWorldLocation->{'Long_'} : '<na>';
		$incidentrate = defined($aWorldLocation->{'Incident_Rate'}) ? $aWorldLocation->{'Incident_Rate'} : -1;
		$peopletested = defined($aWorldLocation->{'People_Tested'}) ? $aWorldLocation->{'People_Tested'} : -1;
		if( exists($aWorldLocation->{'Confirmed'}) && defined($m=$aWorldLocation->{'Confirmed'}) && ($m ne '') ){ $confirmed = 0+$m } else { $confirmed = 0 }
		if( exists($aWorldLocation->{'Recovered'}) && defined($m=$aWorldLocation->{'Recovered'}) && ($m ne '') ){ $recovered = 0+$m } else { $recovered = 0 }
		if( exists($aWorldLocation->{'Deaths'}) && defined($m=$aWorldLocation->{'Deaths'}) && ($m ne '') ){ $deaths = 0+$m } else { $deaths = 0 }
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
			$admin1 = '';
			$admin0 = $official_name;
			$type = 'admin0'; # a country (as opposed to a province)
		  } else {
			$official_name = Statistics::Covid::Geographer::get_official_name($country_region);
			if( ! defined $official_name ){ die pp($aWorldLocation)."\ncould not find official name for country_region='$country_region' in above data (3)" }
			$admin1 = $province_state;
			$admin0 = $official_name;
			$type = 'admin1'; # a state, a province, a local authority whatever
		  }
		} else { die pp($aWorldLocation)."\ndon't know how to handle the above data (2)" }

		$datetimeobj = Statistics::Covid::Utils::epoch_milliseconds_to_DateTime($aWorldLocation->{'Last_Update'});
		if( ! defined $datetimeobj ){ warn pp($aWorldLocation)."\n\nerror, call to ".'Statistics::Covid::Utils::epoch_milliseconds_to_DateTime()'." has failed for date field of 'Last_Update' in the above parameters (it must be milliseconds since unix epoch. A filename (or a url) may be associated with it at\n  ".$datas->[0]->[0]."\n"; return undef }
		$id = join('/', $admin0, $admin1,
			defined($admin2) ? $admin2:'',
			defined($admin3) ? $admin3:'',
			defined($admin4) ? $admin4:'',
			$datetimeobj->epoch()
		);

		my %datparams = (
			'id' => $id,
			'admin1' => $admin1,
			'admin0' => $admin0,
			'incidentrate' => 0+$incidentrate,
			'peopletested' => 0+$peopletested,
			'confirmed' => 0+$confirmed,
			'recovered' => 0+$recovered,
			'terminal' => 0+$deaths,
			# what is 'Active'?
			'date' => $datetimeobj,
			'type' => $type,
			'datasource' => $ds,
		);
		$datparams{'admin2'} = $admin2 if defined $admin2;
		$datparams{'admin3'} = $admin2 if defined $admin3;
		$datparams{'admin4'} = $admin2 if defined $admin4;
		my $datumobj = Statistics::Covid::Datum->new(\%datparams);
		if( ! defined $datumobj ){ warn "error, call to ".'Statistics::Covid::Datum->new()'." has failed for this data: ".join(",", @$aWorldLocation); return undef }
		push @ret, $datumobj
	}
	return \@ret
}
# saves data received as JSON and PL (perl variables)
# into files specified by an optional basename (input param: $outbase)
# OR if no outbase is specified, it creates one
# as a timestamped id and the dir will be the datafielesdir()
# as it was specified in its config during construction
# '$datas' is an arrayref of
# [ [url, data_received_string, data_as_perlvar] ]
# this provider does not have any metadata, all data is received in 1 chunk
# returns undef on failure or the basename if successful
sub save_fetched_data_to_localfile {
	my $self = $_[0];
	my $datas = $_[1]; # this is an arrayref of [url, data_received_string, data_as_perlvar]

	my ($dataid, $outbase);
	my $index = 0;
	if( ! defined($dataid=$datas->[$index]->[3]) ){
		$dataid = $self->create_data_id($datas->[$index]);
		if( ! defined $dataid ){
			warn "error, call to ".'create_data_id()'." has failed.";
			return undef;
		}
		$datas->[$index]->[3] = $dataid;
	}
	$outbase = File::Spec->catfile($self->datafilesdir(), $dataid);

	my $outfile = $outbase . '.data.json';
	my $aurl = $datas->[$index]->[0];
	if( ! Statistics::Covid::Utils::save_text_to_localfile($datas->[$index]->[1], $outfile) ){ warn "error, call to ".'save_text_to_localfile()'." has failed for url '$aurl'."; return undef }
	$outfile = $outbase . '.data.pl';
	if( ! Statistics::Covid::Utils::save_perl_var_to_localfile($datas->[$index]->[2], $outfile) ){ warn "error, call to ".'save_perl_var_to_localfile()'." has failed for url '$aurl'."; return undef }
	print "save_fetched_data_to_localfile() : saved data to base '$outbase'.\n";
	return [$outbase];
}
1;
__END__
# end program, below is the POD

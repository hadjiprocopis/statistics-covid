package Statistics::Covid::DataProvider::UK::GOVUK;

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
use Statistics::Covid::Datum;
use Statistics::Covid::Geographer;

# new method inherited but here we will create one
# to be used as a factory
sub new {
	my ($class, $params) = @_;
	$params = {} unless defined $params;
	$params->{'urls'} = [
		# here we have 2 urls we need to fetch for one data-batch
		# one is the actual data, the other is metadata containing the very important ... date!
		# so, add 2 entries:
		{
			# start a url (for metadata)
			# returns overall cases and also date
			'url' => 'https://services1.arcgis.com/0IrmI40n5ZYxTUrV/arcgis/rest/services/DailyIndicators/FeatureServer/0/query?f=json&where=1%3D1&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&resultOffset=0&resultRecordCount=50&cacheHint=true',
			'headers' => undef,
			'post-data' => undef
		}, # end this url
		{
			# start a url (for actual data)
			# data for each local authority but without dates
			# check the resultRecordCount=10000 and where=TotalCases%20%3E%3D%200
			#'https://services1.arcgis.com/0IrmI40n5ZYxTUrV/arcgis/rest/services/CountyUAs_cases/FeatureServer/0/query?f=json&where=TotalCases%20%3C%3E%200&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&orderByFields=TotalCases%20desc&resultOffset=0&resultRecordCount=1000&cacheHint=true'
			# modified for where=TotalCases%20%3E%3D%200 (that is >=0) and resultRecordCount=10000
			'url' => 'https://services1.arcgis.com/0IrmI40n5ZYxTUrV/arcgis/rest/services/CountyUAs_cases/FeatureServer/0/query?f=json&where=TotalCases%20%3E%3D%200&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&orderByFields=TotalCases%20desc&resultOffset=0&resultRecordCount=10000&cacheHint=true',
			'headers' => undef,
			'post-data' => undef
		}, # end this url
	];
	# initialise our parent class
	my $self = $class->SUPER::new($params);
	if( ! defined $self ){ warn "error, call to $class->new() has failed."; return undef }

	# and do set parameters specific to this particular data provider
	$self->name('UK::GOVUK'); # <<<< Make sure this is unique over all providers
	$self->datafilesdir(File::Spec->catfile(
		$self->datafilesdir(), # use this as prefix it was set in config
		# and append a dir hierarchy relevant to this provider
		# all :: will become '/' (filesys separators)
		split(/::/, $self->name())
	)); # so this is saved to <datafilesdir>/World/JHU

	# initialise this particular data provider
	if( ! $self->init() ){ warn "error, call to init() has failed."; return undef }

	# we use this all the time so we may as well cache it
	$self->{'_admin0'} = Statistics::Covid::Geographer::get_official_name('UK');

	# this will now be GOVUK obj (not generic)
	return $self
}
# returns the data read if successful or undef if failed
sub load_fetched_data_from_localfile {
	my $self = $_[0];
	my $inbasename = $_[1];

	my @ret = ();
	my $infile = $inbasename . '.meta.json';
	my $infh;
	if( ! open($infh, '<:encoding(UTF-8)', $infile) ){ warn "error, failed to open file '$infile' for reading, $!"; return undef }
	my $json_contents = undef; {local $/=undef; $json_contents = <$infh> } close $infh;
	my $metadata = Data::Roundtrip::json2perl($json_contents);
	if( ! defined $metadata ){ warn "error, call to ".'Data::Roundtrip::json2perl()'." has failed (for metadata, file '$infile')."; return undef }
	push @ret, ['file://'.$infile, $json_contents, $metadata];

	$infile = $inbasename . '.data.json';
	if( ! open($infh, '<:encoding(UTF-8)', $infile) ){ warn "error, failed to open file '$infile' for reading, $!"; return undef }
	$json_contents = undef; {local $/=undef; $json_contents = <$infh> } close $infh;
	my $pv = Data::Roundtrip::json2perl($json_contents);
	if( ! defined $pv ){ warn "error, call to ".'Data::Roundtrip::json2perl()'." has failed (for data, file '$infile'))."; return undef }
	if( $self->debug() > 0 ) { warn "load_fetched_data_from_localfile() : read file '$infile' ..." }
	push @ret, ['file://'.$infile, $json_contents, $pv];
	if( ! $self->postprocess_fetched_data(\@ret) ){ warn "error, call to ".'postprocess_fetched_data()'." has failed"; return undef }
	return \@ret
}
# post-process the fetched data (as an array etc.)
# it operates in-place
# returns 1 on success, 0 on failure
sub postprocess_fetched_data {
	my $self = $_[0];
	my $datas = $_[1];

	if( $datas->[0]->[1] =~ /error.+?Token Required/ ){ warn pp($datas->[0]->[1])."\nerror, failed to retrieve page '".$datas->[0]->[0]."', see above what data got back"; return 0 }
	# we need to do the minimum which is to add a data_id created using the 2nd slot (data)
	# in-place additon of a data_id to each datas item
	# note: we do have metadata (1st slot) and data (2nd slot)
	my $dataid = $self->create_data_id($datas->[0]); # we need to use the metadata for this
	if( ! defined $dataid ){
		warn "error, call to ".'create_data_id()'." has failed for '".$datas->[1]->[0]."'";
		return 0
	}
	$datas->[0]->[3] = $dataid; # for metatdata
	$datas->[1]->[3] = $dataid; # for data
	return 1
}
sub create_Datums_from_fetched_data {
	my $self = $_[0];
	# the fetched data as an arrayref with 2 elements:
	# each is an array of [url, data_received_string, data_as_perlvar]
	# the 1st is metadata, the 2nd the actual data
	my $datas = $_[1];

	if( ! exists $datas->[0]->[2]->{'features'} ){ warn pp($datas)."\n\nerror, input data is not of the format expected (metadata)."; return undef }
	my $metadata = $datas->[0]->[2]->{'features'};
	if( ! defined $metadata ){ warn "error, metadata does not contain the expected structure"; return undef }
	# unix-epoch seconds (data provides milliseconds but we convert it)
	# (also there we have NewUKCases, EnglandCases, NICases, ScotlandCases, TotalUKCases, TotalUKDeaths, WalesCases)
	my $dt = Statistics::Covid::Utils::epoch_milliseconds_to_DateTime($metadata->[0]->{'attributes'}->{'DateVal'});
	my $epochseconds = $dt->epoch();
	if( ! defined $epochseconds ){ warn "error, did not find any 'DateVal' in metadata"; return undef }
	# this is actual data as an array of 
#      {
#	attributes => {
#	  FID => 132,
#	  GSS_CD => "E10000014",
#	  GSS_NM => "Hampshire",
#	  Shape__Area => 9307104053.23901,
#	  Shape__Length => 753284.882915695,
#	  TotalCases => 87,
#	},
#      },

	my $admin0 = $self->{'_admin0'};
	my ($confirmed, $id, @ret, $admin1);
	if( ! exists $datas->[1]->[2]->{'features'} ){ warn pp($datas)."\n\nerror, input data is not of the format expected (data)."; return undef }
	my $data = $datas->[1]->[2]->{'features'};
	if( ! defined $data ){ warn "error, data does not contain the expected structure"; return undef }
	my $ds = $self->name();
	for my $aUKlocation (@$data){
		if( ! exists $aUKlocation->{'attributes'} ){ warn "json data:".$datas->[1]->[1]."\ndata is:\n".pp($data)."\n\nAND location data is:\n".pp($aUKlocation)."\n\nerror data does not contain an 'attribute' field."; return undef }
		$aUKlocation = $aUKlocation->{'attributes'};
		# make a random test, if that does not exist then something wrong
		if( ! exists $aUKlocation->{'Shape__Area'} ){ warn "json data:".$datas->[1]->[1]."\ndata is:\n".pp($data)."\n\nAND location data is:\n".pp($aUKlocation)."\n\nerror data does not contain a 'Shape__Area' field."; return undef }
		$confirmed = $aUKlocation->{'TotalCases'};
		if( $confirmed !~ /^\d+$/ ){ die "confirmed value '$confirmed' was not an integer" }

		if( ! defined($aUKlocation->{'GSS_CD'})
		|| ! defined($aUKlocation->{'GSS_NM'})
		|| ! defined($aUKlocation->{'TotalCases'})
		){ die pp($aUKlocation)."\nerror, data does not validate" }
		$id = join('/', $aUKlocation->{'GSS_CD'}, $epochseconds);
		$admin1 = $aUKlocation->{'GSS_NM'};
		my $datumobj = Statistics::Covid::Datum->new({
			'id' => $id,
			'admin1' => $admin1,
			'admin0' => $admin0,
			'confirmed' => $confirmed,
			'area' => $aUKlocation->{'Shape__Area'},
			'date' => $epochseconds,
			'type' => 'admin1',
			'datasource' => $ds,
		});
		if( ! defined $datumobj ){ warn "error, call to ".'Statistics::Covid::Datum->new()'." has failed for this data: ".pp($aUKlocation); return undef }
		push @ret, $datumobj;
	}
	return \@ret
}
# overwriting this from parent
# returns undef on failure or a data id unique on timepoint
# which can be used for saving data to a file or labelling this data
sub create_data_id {
	my $self = $_[0];
	my $metadata = $_[1]; # this is an arrayref of [url, data_received_string, data_as_perlvar]

	my $date = undef;
	my $aurl = $metadata->[0];
	my $apv = $metadata->[2];
	# note this is in milliseconds epoch, but parser will take care
	my $epoch_date_str = $apv->{'features'}->[0]->{'attributes'}->{'DateVal'};
	if( ! defined($date=Statistics::Covid::Utils::epoch_milliseconds_to_DateTime($epoch_date_str)) ){
		warn pp($apv)."\nerror, failed to parse date '$epoch_date_str' from input json data just transfered from url '$aurl', see data above (which is the metadata)";
		return undef;
	}
	my $dataid = $date->strftime('2020-%m-%dT%H.%M.%S')
		     . '_'
		     . $date->epoch()
	;
	if( $self->debug() > 0 ){ warn "create_data_id() : made one as '$dataid'" }
	return $dataid
}
# OR if no outbase is specified, it creates one
# as a timestamped id and the dir will be the datafielesdir()
# as it was specified in its config during construction
# '$datas' is an arrayref of 2 items (metadata and data)
# [ [url, data_received_string, data_as_perlvar], [url, data_received_string, data_as_perlvar] ]
# this provider has BOTH metadata and data
# and so 2 output files will be written, one for each
# returns undef on failure or the basename if successful
sub save_fetched_data_to_localfile {
	my $self = $_[0];
	# this is an arrayref of [url, data_received_string, data_as_perlvar]
	# there are 2 items in there, the first is the metadata, the other is the actual data
	my $datas = $_[1]; # this is an arrayref of [url, data_received_string, data_as_perlvar]

	my $debug = $self->debug();

	my ($dataid, $outbase);
	my $index = 1; # we have metadata in 1st slot, data in 2nd, data_id is from 2nd slot
	if( ! defined($dataid=$datas->[$index]->[3]) ){
		$dataid = $self->create_data_id($datas->[$index]);
		if( ! defined $dataid ){
			warn "error, call to ".'create_data_id()'." has failed.";
			return undef;
		}
		$datas->[$index]->[3] = $dataid;
	}
	$outbase = File::Spec->catfile($self->datafilesdir(), $dataid);

	$index = 0; # metadata
	my $outfile = $outbase . '.meta.json';
	if( ! Statistics::Covid::Utils::save_text_to_localfile($datas->[$index]->[1], $outfile) ){ warn "error, call to ".'save_text_to_localfile()'." has failed."; return undef }
	$outfile = $outbase . '.meta.pl';
	if( ! Statistics::Covid::Utils::save_perl_var_to_localfile($datas->[$index]->[2], $outfile) ){ warn "error, call to ".'save_perl_var_to_localfile()'." has failed."; return undef }
	if( $debug > 0 ){ print STDOUT "save_fetched_data_to_localfile() : saved data to base '$outfile'.\n" }

	$index = 1; # data
	$outfile = $outbase . '.data.json';
	if( ! Statistics::Covid::Utils::save_text_to_localfile($datas->[$index]->[1], $outfile) ){ warn "error, call to ".'save_text_to_localfile()'." has failed."; return undef }
	$outfile = $outbase . '.data.pl';
	if( ! Statistics::Covid::Utils::save_perl_var_to_localfile($datas->[$index]->[2], $outfile) ){ warn "error, call to ".'save_perl_var_to_localfile()'." has failed."; return undef }
	if( $debug > 0 ){ print STDOUT "save_fetched_data_to_localfile() : saved data to base '$outfile'.\n" }
	return [$outbase]
}
1;
__END__
# end program, below is the POD

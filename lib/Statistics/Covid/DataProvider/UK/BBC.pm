package Statistics::Covid::DataProvider::UK::BBC;

use 5.10.0;
use strict;
use warnings;

our $VERSION = '0.24';

use parent 'Statistics::Covid::DataProvider::Base';

use DateTime;
use DateTime::Format::Strptime;
use File::Spec;
use File::Path;
use Data::Dump qw/pp/;

use Statistics::Covid::Datum;
use Statistics::Covid::Utils;
use Statistics::Covid::Geographer;

# new method inherited but here we will create one
# to be used as a factory
sub new {
	my ($class, $params) = @_;
	$params = {} unless defined $params;
	$params->{'urls'} = [
		{
			# start a url
			'url' => 'https://www.bbc.co.uk/indepthtoolkit/data-sets/coronavirus_lookup/json',
			# and its headers if any
			'headers' => undef,
			'post-data' => undef
		}, # end this url
	];
	# initialise our parent class
	my $self = $class->SUPER::new($params);
	if( ! defined $self ){ warn "error, call to $class->new() has failed."; return undef }

	# and do set parameters specific to this particular data provider
	$self->name('UK::BBC'); # <<<< Make sure this is unique over all providers
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

	# this will now be BBC obj (not generic)
	return $self
}
# overwriting this from parent
# returns undef on failure or a data id unique on timepoint
# which can be used for saving data to a file or labelling this data
sub create_data_id {
	my $self = $_[0];
	my $datas_item = $_[1]; # this is an arrayref of [url, data_received_string, data_as_perlvar]

	# this json is idiotic because it's just arrays,
	# 0: location id
	# 1: location name
	# 2: cases
	# 3: population
	# unless [0] is 'UpdatedOn', in which case [1] is 09:00 GMT, 15 March
	# thankfully this update info is last
	my $date = undef;
	my $aurl = $datas_item->[0];
	my $pv = $datas_item->[2];

	my $apv;
	# usually the UpdatedOn is last!
	for(my $i=scalar(@$pv);$i-->0;){
		$apv = $pv->[$i];
		if( $apv->[0] eq 'UpdatedOn' ){
			$date = Statistics::Covid::Utils::epoch_stupid_date_format_from_the_BBC_to_DateTime($apv->[1]);
			if( ! defined $date ){
				warn "error, failed to parse date '".$apv->[1]."' from input json data just transfered from url '$aurl'.";
				return undef;
			}
			last;
		}
	}
	if( ! defined $date ){
		warn "error, did not find any date information in input json data just transfered from url '$aurl'.";
		return undef;
	}
	my $dataid = $date->strftime('2020-%m-%dT%H.%M.%S')
		     . '_'
		     . $date->epoch()
	;
	if( $self->debug() > 0 ){ warn "create_data_id() : made one as '$dataid'" }
	return $dataid
}
# reads from the specified file the data that was
# fetched exactly from the remote provider.
# the input base name (and not an exact filename)
# will be used to create all the necessary filenames
# for data and metadata if exists.
# returns the data read if successful 
# as an arrayref of
#   [ [url, data_received_string, data_as_perlvar] ]
# or undef if failed
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
# post-process the fetched data (as an array etc.)
# it operates in-place
# returns 1 on success, 0 on failure
sub postprocess_fetched_data {
	my $self = $_[0];
	my $datas = $_[1];
		 
	# we need to do the minimum which is to add a data_id created using the 1st slot (data)
	# in-place additon of a data_id to each datas item
	# note: no metadata for us, just data in 1st slot
	my $index = 0;
	my $dataid = $self->create_data_id($datas->[$index]);
	if( ! defined $dataid ){ warn "error, call to ".'create_data_id()'." has failed for '".$datas->[$index]->[0]."'"; return 0 }
	$datas->[$index]->[3] = $dataid;
	return 1
}
# the fetched data as an arrayref with 1 element which is an array of
#   [ [url, data_received_string, data_as_perlvar] ]
# returns the arrayref of Datum Objects on success or undef on failure
sub create_Datums_from_fetched_data {
	my $self = $_[0];
	my $datas = $_[1];

	my $data = $datas->[0]->[2]; # getting to the array of locations
	my @ret = ();
	my $dateobj = undef;
	for my $aUKlocation (@$data){
		# now this is an arrayref of id, name, confirmed, population (in this order)
		# unless the first item is 'UpdatedOn', then #2 is 09:00 GMT, 16 March
		if( $aUKlocation->[0] eq 'UpdatedOn' ){
			$dateobj = Statistics::Covid::Utils::epoch_stupid_date_format_from_the_BBC_to_DateTime($aUKlocation->[1]);
			if( ! defined $dateobj ){ warn "error, call to ".'Statistics::Covid::Utils::epoch_stupid_date_format_from_the_BBC_to_DateTime()'." has failed for this date-spec '".$aUKlocation->[1]."'."; return undef }
			last
		}
	}
	if( ! defined $dateobj ){ warn "error, did not find any date (searched for 'UpdatedOn') in the perl-var data."; return undef }
	# now we know the date so go ahead
	my $ds = $self->name();
	my $admin0 = $self->{'_admin0'};
	my ($admin1, $confirmed, $id);
	#my $i = 1;
	for my $aUKlocation (@$data){
		if( ($aUKlocation->[0] eq 'UpdatedOn')
		 || ($aUKlocation->[0] eq '')
		 || ($aUKlocation->[3] eq '') ){
			next # must skip date and a lot of empty things
		}
		# [0] is alphanumeric government ID
		$id = join('/', $aUKlocation->[0], $dateobj->epoch());
		$admin1 = $aUKlocation->[1];
		$confirmed = $aUKlocation->[2];
		# The BBC likes to report "fewer than five" rather than the actual exact
		# numerical value. Probably some Peter Sellers scientists at play there...
		if( $confirmed !~ /^\d+$/ ){
			if( $confirmed =~ /NaN/i ){ $confirmed = 0 }
			elsif( $confirmed =~ /fewer than five/ ){ $confirmed = 4 }
			else { die "confirmed value could not be understood, it was '$confirmed'" }
		}
		my $datumobj = Statistics::Covid::Datum->new({
			'id' => $id,
			'admin1' => $admin1,
			'admin0' => $admin0,
			'confirmed' => $confirmed,
			'date' => $dateobj,
			'type' => 'admin1',
			# BBC gives population
			'population' => $aUKlocation->[3],
			'datasource' => $ds,
		});
		#print "$i created::\n".pp($datumobj->{'c'})."\n"; $i++;
		if( ! defined $datumobj ){ warn "error, call to ".'Statistics::Covid::Datum->new()'." has failed for this data: ".join(",", @$aUKlocation); return undef }
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
# returns undef on failure or the basename if successful.
sub save_fetched_data_to_localfile {
	my $self = $_[0];
	my $datas = $_[1]; # this is an arrayref of [url, data_received_string, data_as_perlvar]

	my ($dataid, $outbase);
	my $index = 0;
	if( ! defined($dataid=$datas->[$index]->[3]) ){
		$dataid = $self->create_data_id($datas);
		if( ! defined $dataid ){
			warn "error, call to ".'create_data_id()'." has failed.";
			return undef;
		}
		$datas->[$index]->[3] = $dataid;
	}

	$outbase = File::Spec->catfile($self->datafilesdir(), $dataid);
	my $outfile = $outbase . '.data.json';
	if( ! Statistics::Covid::Utils::save_text_to_localfile($datas->[$index]->[1], $outfile) ){ warn "error, call to ".'save_text_to_localfile()'." has failed."; return undef }
	$outfile = $outbase . '.data.pl';
	if( ! Statistics::Covid::Utils::save_perl_var_to_localfile($datas->[$index]->[2], $outfile) ){ warn "error, call to ".'save_perl_var_to_localfile()'." has failed."; return undef }
	print "save_fetched_data_to_localfile() : saved data to base '$outbase'.\n";
	return [$outbase];
}
1;
__END__
# end program, below is the POD

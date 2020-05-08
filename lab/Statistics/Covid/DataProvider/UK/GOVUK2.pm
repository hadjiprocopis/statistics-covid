package Statistics::Covid::DataProvider::UK::GOVUK2;

use 5.10.0;
use strict;
use warnings;

our $VERSION = '0.23';

use parent 'Statistics::Covid::DataProvider::Base';

use DateTime;
use File::Spec;
use File::Path;
use Data::Dump qw/pp/;
use XML::Twig;
use Data::Roundtrip;

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
			# start a url (returns XML with url of document with data)
			'url' => 'https://publicdashacc.blob.core.windows.net/publicdata?restype=container&comp=list',
			'headers' => [
				'Origin' => 'https://coronavirus.data.gov.uk'
			],
			'post-data' => undef,
			'cb-preprocess' => undef,
			'cb-postprocess' => sub {
				my ($self, $data) = @_;
				my $twig = new XML::Twig;

				if( ! $twig->parse($data) ){ warn pp($data)."\nerror, failed to parse above XML data"; return undef }

				my $root = $twig->root;
				if( ! defined $root ){ die "rroto" }

				my ($m, $fname, $latest_fname);
				my $latest_date;
				my $strp = DateTime::Format::Strptime->new(
					'locale'  => 'en_GB',
					'pattern' => '%A, %d %B %Y %H:%M:%S %Z',
				);
				for my $ablobs ($root->children()){
					for my $ablob ($ablobs->children()){
						if( defined($m=$ablob->first_child('Name')) ){
							$fname = $m->text;
						} else { next }
						if( defined($m=$ablob->first_child('Properties'))
							&& defined($m=$m->first_child('Last-Modified'))
						){
							my $adateobj = $strp->parse_datetime($m->text);
							if( ! defined $adateobj ){ die "failed to parse '".$m->text."'" }
							if( ! $latest_date ){ $latest_date = $adateobj; next }
							if( $latest_date < $adateobj ){
								$latest_date = $adateobj;
								$latest_fname = $fname;
							}
						}
					}
				}
				if( ! defined $latest_fname ){ warn pp($data)."\nerror, failed to find valid latest date and filename for above data"; return undef }
				my $aurl = 'https://c19pub.azureedge.net/'.$latest_fname;
				# modify the url of the next entry
				$self->{'urls'}->[1]->{'url'} = $aurl;
				if( $self->debug() > 0 ){ warn "fetched and parsed the entry point url, data file last updated on $latest_date is at '$aurl'" }
				return {'url'=>$aurl, 'last-updated'=>$latest_date->epoch()} # success
			} # ends the processor sub
		}, # end this url
		{
			# start a url (for actual data)
			'url' => undef, # this will be set from the first hit above
			'headers' => undef,
			'post-data' => undef,
		}, # end this url
	];
	# initialise our parent class
	my $self = $class->SUPER::new($params);
	if( ! defined $self ){ warn "error, call to $class->new() has failed."; return undef }

	# and do set parameters specific to this particular data provider
	$self->name('UK::GOVUK2'); # <<<< Make sure this is unique over all providers
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

	# this will now be GOVUK2 obj (not generic)
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
# overwriting this from parent
# returns undef on failure or a data id unique on timepoint
# which can be used for saving data to a file or labelling this data
sub create_data_id {
	my $self = $_[0];
	my $data = $_[1]; # this is an arrayref of [url, data_received_string, data_as_perlvar]

	my $date = undef;
	my $aurl = $data->[0];
	my $apv = $data->[2];
	my $date_str = $apv->{'lastUpdatedAt'};
	if( ! defined $date_str ){ warn pp($apv)."\nerror, there is no 'lastUpdatedAt' in the above data" }
	# it is like: 2020-04-16T14:44:18.371573Z
	# so remove last millis
	$date_str =~ s/\.\d+//;
	if( ! defined($date=Statistics::Covid::Utils::iso8601_to_DateTime($date_str)) ){ warn pp($apv)."\nerror, failed to parse date '$date_str' from input json data just transfered from url '$aurl', see data above (which is the metadata)"; return undef }
	my $dataid = $date->strftime('2020-%m-%dT%H.%M.%S')
		     . '_'
		     . $date->epoch()
	;
	if( $self->debug() > 0 ){ warn "create_data_id() : made one as '$dataid'" }
	return $dataid
}
# post-process the fetched data (as an array etc.)
# it operates in-place
# returns 1 on success, 0 on failure
sub postprocess_fetched_data {
	my $self = $_[0];
	my $datas = $_[1];

	# we are interested in the last (2nd) entry (1st was the entry point url)
	# it's json so let's just convert it to a perl-var.
	my $aurl = $datas->[1]->[0];
	my $pv = Data::Roundtrip::json2perl($datas->[1]->[1]);
	if( ! defined $pv ){ warn pp($datas->[1]->[1])."\nerror, call to ".'Statistics::Covid::Utils::json2perl()'." has failed for this url '$aurl'"; return 0 }
	$datas->[1]->[2] = $pv;

	# there is a lastUpdatedAt entry in the 2nd data (main data).
	# but also the first data contains last-update date in epoch seconds
	my $dataid = $self->create_data_id($datas->[1]);
	if( ! defined $dataid ){ warn "error, call to ".'create_data_id()'." has failed for '".$datas->[1]->[0]."'"; return 0 }
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

	# there are 'countries', 'regions' (like 'South East' and 'London'), 
	# 'utlas' (like Hartlepool)
	# each of them is keyed on 'E06000002' and has: 'totalCases'->'value'=771
	# has 'name'->'value'=Hartlepool
	# and 'dailyTotalConfirmedCases', 'dailyConfirmedCases' which have 'date'(2020-02-12) and 'value'
	# 'name'->'value'=Hartlepool

	my $admin0 = $self->{'_admin0'};
	my ($id, @ret, $admin1, $admin2, $admin3,
            $terminal, $confirmed,
	    $v, $v2, $adateobj, $adatestr, $pv
	);
	my $ds = $self->name();

	# it is like: 2020-04-16T14:44:18.371573Z
	# so remove last millis
	$adatestr = $datas->[1]->[2]->{'lastUpdatedAt'};
	$adatestr =~ s/\.\d+//;
	my $dt = Statistics::Covid::Utils::iso8601_to_DateTime($adatestr);
	if( ! defined $dt ){ warn "error, failed to parse date '$adatestr'"; return undef }
	my $epochseconds = $dt->epoch();

	## countries within the UK...
	$pv = $datas->[1]->[2]->{'countries'};
	for my $id (sort keys %$pv){ # this is like N92000002
		$v = $pv->{$id};
		$admin1 = $v->{'name'}->{'value'}; # this will be like england for 'countries' or Scotland
		$terminal = $v->{'deaths'}->{'value'};
		$confirmed = $v->{'totalCases'}->{'value'};
		my $datumobj = Statistics::Covid::Datum->new({
			'id' => $id,
			'admin1' => $admin1,
			'admin0' => $admin0,
			'confirmed' => $confirmed,
			'terminal' => $terminal,
			'date' => $dt,
			'type' => 'admin1',
			'datasource' => $ds,
		});
		if( ! defined $datumobj ){ warn pp($v)."\nerror, call to ".'Statistics::Covid::Datum->new()'." has failed for above data"; return undef }
		push @ret, $datumobj;
		# and now for each date
		my %col;
		for my $dtcc (@{$v->{'dailyTotalConfirmedCases'}}){
			$adatestr = $dtcc->{'date'};
			$confirmed = $dtcc->{'value'};
			if( ! defined $confirmed ){ warn pp($dtcc)."\nand this specific item:\n".pp($dtcc)."\nerror, value is undefined, see above"; return undef }
			if( ! exists $col{$adatestr} ){
				$col{$adatestr} = {'confirmed'=>$confirmed}
			}
			$col{$adatestr} = {'confirmed'=>$confirmed};
		}
		for my $dtcc (@{$v->{'dailyTotalDeaths'}}){
			$adatestr = $dtcc->{'date'};
			$terminal = $dtcc->{'value'};
			if( ! defined $terminal ){ warn pp($dtcc)."\nand this specific item:\n".pp($dtcc)."\nerror, value is undefined, see above"; return undef }
			if( ! exists $col{$adatestr} ){
				$col{$adatestr} = {'terminal'=>$terminal}
			} else { $col{$adatestr}->{'terminal'} = $terminal }
		}
		for $adatestr (sort keys %col){
			$v2 = $col{$adatestr};
			$adateobj = Statistics::Covid::Utils::iso8601_up_to_days_to_DateTime($adatestr);
			if( ! defined $adateobj ){ warn pp($v)."\nerror, call to ".'Statistics::Covid::Utils::iso8601_up_to_days_to_DateTime()'." has failed for date spec '$adatestr' and the above data."; return undef }
			$terminal = exists($v2->{'terminal'}) && defined($v2->{'terminal'}) ? $v2->{'terminal'} : -1;
			$confirmed = exists($v2->{'confirmed'}) && defined($v2->{'confirmed'}) ? $v2->{'confirmed'} : -1;
			my $datumobj = Statistics::Covid::Datum->new({
				'id' => $id,
				'admin1' => $admin1,
				'admin0' => $admin0,
				'confirmed' => $confirmed,
				'terminal' => $terminal,
				'date' => $adateobj,
				'type' => 'admin1',
				'datasource' => $ds,
			});
			if( ! defined $datumobj ){ warn pp($v)."\nerror, call to ".'Statistics::Covid::Datum->new()'." has failed for above data"; return undef }
			push @ret, $datumobj;
		}
	}

	## regions (e.g. South East or London, that would be admin2
	$pv = $datas->[1]->[2]->{'regions'};
	for my $id (sort keys %$pv){ # this is like N92000002
		$v = $pv->{$id};
		$admin2 = $v->{'name'}->{'value'}; # this will be like 'South East' or 'London'
		$confirmed = $v->{'totalCases'}->{'value'};
		my $datumobj = Statistics::Covid::Datum->new({
			'id' => $id,
			'admin2' => $admin2,
			'admin0' => $admin0,
			'confirmed' => $confirmed,
			'date' => $dt,
			'type' => 'admin2',
			'datasource' => $ds,
		});
		if( ! defined $datumobj ){ warn pp($v)."\nerror, call to ".'Statistics::Covid::Datum->new()'." has failed for above data"; return undef }
		push @ret, $datumobj;
		# and now for each date
		my %col;
		for my $dtcc (@{$v->{'dailyTotalConfirmedCases'}}){
			$adatestr = $dtcc->{'date'};
			$confirmed = $dtcc->{'value'};
			if( ! defined $confirmed ){ warn pp($dtcc)."\nand this specific item:\n".pp($dtcc)."\nerror, value is undefined, see above"; return undef }
			$col{$adatestr} = {'confirmed'=>$confirmed};
		}
		for $adatestr (sort keys %col){
			$v2 = $col{$adatestr};
			$adateobj = Statistics::Covid::Utils::iso8601_up_to_days_to_DateTime($adatestr);
			if( ! defined $adateobj ){ warn pp($v)."\nerror, call to ".'Statistics::Covid::Utils::iso8601_up_to_days_to_DateTime()'." has failed for date spec '$adatestr' and the above data."; return undef }
			$confirmed = exists($v2->{'confirmed'}) && defined($v2->{'confirmed'}) ? $v2->{'confirmed'} : -1;
			my $datumobj = Statistics::Covid::Datum->new({
				'id' => $id,
				'admin2' => $admin2,
				'admin0' => $admin0,
				'confirmed' => $confirmed,
				'date' => $adateobj,
				'type' => 'admin2',
				'datasource' => $ds,
			});
			if( ! defined $datumobj ){ warn pp($v)."\nerror, call to ".'Statistics::Covid::Datum->new()'." has failed for above data"; return undef }
			push @ret, $datumobj;
		}
	}

	## local authorities e.g. Blackpool
	$pv = $datas->[1]->[2]->{'utlas'};
	for my $id (sort keys %$pv){ # this is like E06000001
		$v = $pv->{$id};
		$admin3 = $v->{'name'}->{'value'}; # this will be like 'South East' or 'London'
		$confirmed = $v->{'totalCases'}->{'value'};
		my $datumobj = Statistics::Covid::Datum->new({
			'id' => $id,
			'admin3' => $admin3,
			'admin0' => $admin0,
			'confirmed' => $confirmed,
			'date' => $dt,
			'type' => 'admin3',
			'datasource' => $ds,
		});
		if( ! defined $datumobj ){ warn pp($v)."\nerror, call to ".'Statistics::Covid::Datum->new()'." has failed for above data"; return undef }
		push @ret, $datumobj;
		# and now for each date
		my %col;
		for my $dtcc (@{$v->{'dailyTotalConfirmedCases'}}){
			$adatestr = $dtcc->{'date'};
			$confirmed = $dtcc->{'value'};
			if( ! defined $confirmed ){ warn pp($dtcc)."\nand this specific item:\n".pp($dtcc)."\nerror, value is undefined, see above"; return undef }
			$col{$adatestr} = {'confirmed'=>$confirmed};
		}
		for $adatestr (sort keys %col){
			$v2 = $col{$adatestr};
			$adateobj = Statistics::Covid::Utils::iso8601_up_to_days_to_DateTime($adatestr);
			if( ! defined $adateobj ){ warn pp($v)."\nerror, call to ".'Statistics::Covid::Utils::iso8601_up_to_days_to_DateTime()'." has failed for date spec '$adatestr' and the above data."; return undef }
			$terminal = exists($v2->{'terminal'}) && defined($v2->{'terminal'}) ? $v2->{'terminal'} : -1;
			$confirmed = exists($v2->{'confirmed'}) && defined($v2->{'confirmed'}) ? $v2->{'confirmed'} : -1;
			my $datumobj = Statistics::Covid::Datum->new({
				'id' => $id,
				'admin3' => $admin3,
				'admin0' => $admin0,
				'confirmed' => $confirmed,
				'date' => $adateobj,
				'type' => 'admin3',
				'datasource' => $ds,
			});
			if( ! defined $datumobj ){ warn pp($v)."\nerror, call to ".'Statistics::Covid::Datum->new()'." has failed for above data"; return undef }
			push @ret, $datumobj;
		}
	}
	return \@ret
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
	if( ! Statistics::Covid::Utils::save_text_to_localfile(Data::Roundtrip::perl2json($datas->[$index]->[2]), $outfile) ){ warn "error, call to ".'save_text_to_localfile()'." has failed."; return undef }
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

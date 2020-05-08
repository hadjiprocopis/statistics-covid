package Statistics::Covid::DataProvider::CY::UCY;

use 5.10.0;
use strict;
use warnings;

our $VERSION = '0.23';

use parent 'Statistics::Covid::DataProvider::Base';

use utf8; # we do some greek language regex

use DateTime;
use DateTime::Format::Strptime;
use File::Spec;
use File::Path;
use Data::Dump qw/pp/;

use Statistics::Covid::Datum;
use Statistics::Covid::Utils;
use Statistics::Covid::Geographer;

binmode STDERR, ':encoding(UTF-8)';
binmode STDOUT, ':encoding(UTF-8)';
binmode STDIN,  ':encoding(UTF-8)';

# new method inherited but here we will create one
# to be used as a factory
sub new {
	my ($class, $params) = @_;
	$params = {} unless defined $params;

	my $debug = exists($params->{'debug'}) && defined($params->{'debug'})
		? $params->{'debug'} : 0;

	# extra params for this one: 'model-params' for modelBi POST
	# can be extracted from a single HEADER+POST params (as-curl) of any 'query' in network tab of dev tools

	if( ! exists($params->{'model-params'}) || ! defined($params->{'model-params'}) ){
		# setting default model-bi params but that's likely to fail unless they are updated.
		$params->{'model-params'} = {
			# things to patch headers and post-data with, so don't worry if headers or post-data
			# contain stale values BUT these are defaults...
			'DatasetId' => 'a1c6541b-1317-4ab8-bc9c-9b62a79434b4',
			'ReportId' => '070fa74b-ddb8-4174-b170-008df997d2ad',
			'modelId' => '3466180', #'3467183',
			'ActivityId' => '1f087812-7cde-d6a0-fa1f-1bca2cda84d0', #'f025dae0-e8a8-1775-80cf-0bd1fccc38e7',
			'RequestId' => '7357fa92-75d8-cc26-5cde-8a6b1ab47fd0', #'c9af742e-d40f-60ba-419d-5ecd71125a32',
			'X-PowerBI-ResourceKey' => '7f7f1f4f-69e5-4d2e-98ec-602bc0a9e33c', #'bf7b9a52-bfd4-46f4-bcd7-a55f44b074c0'
		};
		warn "WARNING, default model-params are likely to fail at some point. When they do you must refresh them: network-tab/right-click on POST query and copy ac curl."
	}

	$params->{'urls'} = [
		{
			# 0. LAST REFRESHED
			# start a url
			'url' => 'https://wabi-west-europe-api.analysis.windows.net/public/reports/querydata',
			# and its headers if any
			'headers' => [
				"User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.13; rv:61.0) Gecko/20100101 Firefox/73.0",
				"Accept" => "application/json, text/plain, */*",
				"Accept-Language" => "en-US,en;q=0.5",
				"ActivityId" => "6a5ceb1f-5e01-e897-03a0-c78c68c78a0b",
				"RequestId" => "20dad21b-a268-8bf9-3e5e-c82fade95d35",
				"X-PowerBI-ResourceKey" => "7f7f1f4f-69e5-4d2e-98ec-602bc0a9e33c",
				"Content-Type" => "application/json;charset=UTF-8",
				"referrer" => "https://wabi-west-europe-api.analysis.windows.net/public/reports/querydata",
			], # end header
			# 'modelId' is the most critical here, if this stops working (old: 3461989)
			# open developer tools in firefox/network tab/ open 'https://covid19.ucy.ac.cy/'
			# find a query and right-click copy as post and extract the modelId
			# NOTE: escape single quote ' -> \' and escape all unicode (e.g. must be literal \u1234)
			# timeline total confirmed
			'post-data' => <<'EOSHIT',
{"cancelQueries":[],"version":"1.0.0","queries":[{"Query":{"Commands":[{"SemanticQueryDataShapeCommand":{"Query":{"Version":"2","From":[{"Name":"q","Entity":"LastRefresh"}],"Select":[{"Name":"Min(Query1.Date Last Refreshed)","Aggregation":{"Expression":{"Column":{"Property":"Date Last Refreshed","Expression":{"SourceRef":{"Source":"q"}}}},"Function":"3"}}]},"Binding":{"Version":"1","Primary":{"Groupings":[{"Projections":["0"]}]}}}}]},"ApplicationContext":{"Sources":[{"ReportId":"070fa74b-ddb8-4174-b170-008df997d2ad"}],"DatasetId":"a1c6541b-1317-4ab8-bc9c-9b62a79434b4"},"QueryId":""}],"modelId":"3466180"}
EOSHIT
		}, # and this url entry
		{
			# 1. OVERALL
			# start a url
			'url' => 'https://wabi-west-europe-api.analysis.windows.net/public/reports/querydata',
			# and its headers if any
			'headers' => [
				"User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.13; rv:61.0) Gecko/20100101 Firefox/73.0",
				"Accept" => "application/json, text/plain, */*",
				"Accept-Language" => "en-US,en;q=0.5",
				"ActivityId" => "6a5ceb1f-5e01-e897-03a0-c78c68c78a0b",
				"RequestId" => "20dad21b-a268-8bf9-3e5e-c82fade95d35",
				"X-PowerBI-ResourceKey" => "7f7f1f4f-69e5-4d2e-98ec-602bc0a9e33c",
				"Content-Type" => "application/json;charset=UTF-8",
				"referrer" => "https://wabi-west-europe-api.analysis.windows.net/public/reports/querydata",
			], # end header
			# 'modelId' is the most critical here, if this stops working (old: 3461989)
			# open developer tools in firefox/network tab/ open 'https://covid19.ucy.ac.cy/'
			# find a query and right-click copy as post and extract the modelId
			# NOTE: escape single quote ' -> \' and escape all unicode (e.g. must be literal \u1234)
			# timeline total confirmed
			'post-data' => <<'EOSHIT',
{"version":"1.0.0","queries":[{"QueryId":"","Query":{"Commands":[{"SemanticQueryDataShapeCommand":{"Binding":{"Primary":{"Groupings":[{"Projections":["0","1","2","3","4","5"]}]},"Version":"1"},"Query":{"From":[{"Entity":"pg_timeseries","Name":"p"},{"Entity":"dashboard_view","Name":"d"}],"Select":[{"Aggregation":{"Function":"4","Expression":{"Column":{"Property":"Active","Expression":{"SourceRef":{"Source":"p"}}}}},"Name":"Sum(pg_timeseries.Active)"},{"Aggregation":{"Function":"0","Expression":{"Column":{"Property":"Deaths","Expression":{"SourceRef":{"Source":"p"}}}}},"Name":"Sum(pg_timeseries.Deaths)"},{"Name":"Sum(pg_timeseries.totaltests)","Aggregation":{"Expression":{"Column":{"Expression":{"SourceRef":{"Source":"p"}},"Property":"totaltests"}},"Function":"4"}},{"Aggregation":{"Function":"0","Expression":{"Column":{"Property":"Recovered","Expression":{"SourceRef":{"Source":"p"}}}}},"Name":"Sum(pg_timeseries.Recovered)"},{"Aggregation":{"Expression":{"Column":{"Property":"Possitive","Expression":{"SourceRef":{"Source":"p"}}}},"Function":"0"},"Name":"Sum(pg_timeseries.Possitive)"},{"Aggregation":{"Expression":{"Column":{"Expression":{"SourceRef":{"Source":"d"}},"Property":"UUID"}},"Function":"5"},"Name":"Min(dashboard_view.UUID)"}]}}}]},"ApplicationContext":{"DatasetId":"a1c6541b-1317-4ab8-bc9c-9b62a79434b4","Sources":[{"ReportId":"070fa74b-ddb8-4174-b170-008df997d2ad"}]}}],"modelId":"3466180","cancelQueries":[]}
EOSHIT
		}, # and this url entry
		{
			# 2. TIMELINE
			# start a url
			'url' => 'https://wabi-west-europe-api.analysis.windows.net/public/reports/querydata',
			# and its headers if any
			'headers' => [
				"User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.13; rv:61.0) Gecko/20100101 Firefox/73.0",
				"Accept" => "application/json, text/plain, */*",
				"Accept-Language" => "en-US,en;q=0.5",
				"ActivityId" => "6a5ceb1f-5e01-e897-03a0-c78c68c78a0b",
				"RequestId" => "20dad21b-a268-8bf9-3e5e-c82fade95d35",
				"X-PowerBI-ResourceKey" => "7f7f1f4f-69e5-4d2e-98ec-602bc0a9e33c",
				"Content-Type" => "application/json;charset=UTF-8",
				"referrer" => "https://wabi-west-europe-api.analysis.windows.net/public/reports/querydata",
			], # end header
			# 'modelId' is the most critical here, if this stops working (old: 3461989)
			# open developer tools in firefox/network tab/ open 'https://covid19.ucy.ac.cy/'
			# find a query and right-click copy as post and extract the modelId
			# NOTE: escape single quote ' -> \' and escape all unicode (e.g. must be literal \u1234)
			# timeline total confirmed
			'post-data' => <<'EOSHIT',
{"version":"1.0.0","modelId":"3466180","cancelQueries":[],"queries":[{"QueryId":"","Query":{"Commands":[{"SemanticQueryDataShapeCommand":{"Binding":{"Primary":{"Groupings":[{"Projections":["0","1","2","3","4","5","6"]}]},"Version":"1"},"Query":{"From":[{"Entity":"pg_timeseries","Name":"p"},{"Entity":"dashboard_view","Name":"d"}],"Version":"2","Select":[{"Aggregation":{"Function":"0","Expression":{"Column":{"Property":"Total","Expression":{"SourceRef":{"Source":"p"}}}}},"Name":"Sum(pg_timeseries.Total)"},{"Aggregation":{"Function":"0","Expression":{"Column":{"Property":"Possitive","Expression":{"SourceRef":{"Source":"p"}}}}},"Name":"Sum(pg_timeseries.Possitive)"},{"Aggregation":{"Function":"0","Expression":{"Column":{"Expression":{"SourceRef":{"Source":"p"}},"Property":"Deaths"}}},"Name":"Sum(pg_timeseries.Deaths)"},{"Aggregation":{"Function":"0","Expression":{"Column":{"Expression":{"SourceRef":{"Source":"p"}},"Property":"tests"}}},"Name":"Sum(pg_timeseries.tests)"},{"Name":"Sum(pg_timeseries.Recovered)","Aggregation":{"Expression":{"Column":{"Expression":{"SourceRef":{"Source":"p"}},"Property":"Recovered"}},"Function":"0"}},{"Measure":{"Property":"\u0391\u03bd\u03b1\u03c6\u03bf\u03c1\u03ad\u03c2 Normalized","Expression":{"SourceRef":{"Source":"d"}}},"Name":"dashboard_view.\u0391\u03bd\u03b1\u03c6\u03bf\u03c1\u03ad\u03c2 Normalized"},{"Column":{"Expression":{"SourceRef":{"Source":"p"}},"Property":"Date"},"Name":"pg_timeseries.Date"}]}}}]},"ApplicationContext":{"Sources":[{"ReportId":"070fa74b-ddb8-4174-b170-008df997d2ad"}],"DatasetId":"a1c6541b-1317-4ab8-bc9c-9b62a79434b4"}}]}
EOSHIT
		}, # and this url entry
		{
			# 3. EPARXIA
			# start a url
			'url' => 'https://wabi-west-europe-api.analysis.windows.net/public/reports/querydata',
			# and its headers if any
			'headers' => [
				"User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.13; rv:61.0) Gecko/20100101 Firefox/73.0",
				"Accept" => "application/json, text/plain, */*",
				"Accept-Language" => "en-US,en;q=0.5",
				"ActivityId" => "6a5ceb1f-5e01-e897-03a0-c78c68c78a0b",
				"RequestId" => "20dad21b-a268-8bf9-3e5e-c82fade95d35",
				"X-PowerBI-ResourceKey" => "7f7f1f4f-69e5-4d2e-98ec-602bc0a9e33c",
				"Content-Type" => "application/json;charset=UTF-8",
				"referrer" => "https://wabi-west-europe-api.analysis.windows.net/public/reports/querydata",
			], # end header
			# 'modelId' is the most critical here, if this stops working (old: 3461989)
			# open developer tools in firefox/network tab/ open 'https://covid19.ucy.ac.cy/'
			# find a query and right-click copy as post and extract the modelId
			# NOTE: escape single quote ' -> \' and escape all unicode (e.g. must be literal \u1234)
			# eparxia, most reliable because it gets exactly 3 numbers for each
			'post-data' => <<'EOSHIT',
{"modelId":"3466180","queries":[{"ApplicationContext":{"DatasetId":"a1c6541b-1317-4ab8-bc9c-9b62a79434b4","Sources":[{"ReportId":"070fa74b-ddb8-4174-b170-008df997d2ad"}]},"Query":{"Commands":[{"SemanticQueryDataShapeCommand":{"Query":{"OrderBy":[{"Expression":{"Column":{"Property":"name_gr","Expression":{"SourceRef":{"Source":"p"}}}},"Direction":"1"}],"Version":"2","From":[{"Entity":"pb_districtpop","Name":"p"},{"Name":"d","Entity":"dashboard_view"}],"Select":[{"Column":{"Expression":{"SourceRef":{"Source":"p"}},"Property":"name_gr"},"Name":"pb_districtpop.name_gr"},{"Name":"dashboard_view.\u0391\u03bd\u03b1\u03c6\u03bf\u03c1\u03ad\u03c2 Normalized","Measure":{"Property":"\u0391\u03bd\u03b1\u03c6\u03bf\u03c1\u03ad\u03c2 Normalized","Expression":{"SourceRef":{"Source":"d"}}}},{"Name":"dashboard_view.\u0398\u03b5\u03c4\u03b9\u03ba\u03ac Normalized","Measure":{"Property":"\u0398\u03b5\u03c4\u03b9\u03ba\u03ac Normalized","Expression":{"SourceRef":{"Source":"d"}}}},{"Name":"dashboard_view.\u0394\u03b5\u03af\u03b3\u03bc\u03b1\u03c4\u03b1 Normalized","Measure":{"Expression":{"SourceRef":{"Source":"d"}},"Property":"\u0394\u03b5\u03af\u03b3\u03bc\u03b1\u03c4\u03b1 Normalized"}},{"Measure":{"Expression":{"SourceRef":{"Source":"d"}},"Property":"\u0398\u03b5\u03c4\u03b9\u03ba\u03ac"},"Name":"dashboard_view.\u0398\u03b5\u03c4\u03b9\u03ba\u03ac"},{"Measure":{"Property":"\u0394\u03b5\u03af\u03b3\u03bc\u03b1\u03c4\u03b1","Expression":{"SourceRef":{"Source":"d"}}},"Name":"dashboard_view.\u0394\u03b5\u03af\u03b3\u03bc\u03b1\u03c4\u03b1"}]},"Binding":{"Primary":{"Groupings":[{"Projections":["0","1","2","3","4","5"]}]},"Version":"1"}}}]},"QueryId":""}],"version":"1.0.0","cancelQueries":[]}
EOSHIT
		}, # and this url entry
		{
			# 4. ALL locations with > 1 anafores (unconfirmed)
			# start a url
			'url' => 'https://wabi-west-europe-api.analysis.windows.net/public/reports/querydata',
			# and its headers if any
			'headers' => [
				"User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.13; rv:61.0) Gecko/20100101 Firefox/73.0",
				"Accept" => "application/json, text/plain, */*",
				"Accept-Language" => "en-US,en;q=0.5",
				"ActivityId" => "6a5ceb1f-5e01-e897-03a0-c78c68c78a0b",
				"RequestId" => "20dad21b-a268-8bf9-3e5e-c82fade95d35",
				"X-PowerBI-ResourceKey" => "7f7f1f4f-69e5-4d2e-98ec-602bc0a9e33c",
				"Content-Type" => "application/json;charset=UTF-8",
				"referrer" => "https://wabi-west-europe-api.analysis.windows.net/public/reports/querydata",
			], # end header
			# 'modelId' is the most critical here, if this stops working (old: 3461989)
			# open developer tools in firefox/network tab/ open 'https://covid19.ucy.ac.cy/'
			# find a query and right-click copy as post and extract the modelId
			# NOTE: escape single quote ' -> \' and escape all unicode (e.g. must be literal \u1234)
			'post-data' => <<'EOSHIT',
{"cancelQueries":[],"queries":[{"ApplicationContext":{"DatasetId":"a1c6541b-1317-4ab8-bc9c-9b62a79434b4","Sources":[{"ReportId":"070fa74b-ddb8-4174-b170-008df997d2ad"}]},"QueryId":"","Query":{"Commands":[{"SemanticQueryDataShapeCommand":{"Binding":{"Version":"1","Primary":{"Groupings":[{"Projections":["0","1","2"]}]}},"Query":{"Version":"2","OrderBy":[{"Direction":"2","Expression":{"Measure":{"Expression":{"SourceRef":{"Source":"d"}},"Property":"\u0398\u03b5\u03c4\u03b9\u03ba\u03ac"}}}],"Select":[{"Aggregation":{"Function":"5","Expression":{"Column":{"Expression":{"SourceRef":{"Source":"d"}},"Property":"UUID"}}},"Name":"CountNonNull(dashboard_view.UUID)"},{"Column":{"Expression":{"SourceRef":{"Source":"p1"}},"Property":"Name_GR"},"Name":"pb_map.Name_GR"},{"Measure":{"Property":"\u0398\u03b5\u03c4\u03b9\u03ba\u03ac","Expression":{"SourceRef":{"Source":"d"}}},"Name":"\u0398\u03b5\u03c4\u03b9\u03ba\u03ac"}],"Where":[{"Target":[{"Column":{"Expression":{"SourceRef":{"Source":"p1"}},"Property":"Name_GR"}}],"Condition":{"Comparison":{"Left":{"Aggregation":{"Expression":{"Column":{"Expression":{"SourceRef":{"Source":"d"}},"Property":"UUID"}},"Function":"5"}},"ComparisonKind":"2","Right":{"Literal":{"Value":"1D"}}}}}],"From":[{"Name":"d","Entity":"dashboard_view"},{"Name":"p1","Entity":"pb_map"}]}}}]}}],"modelId":"3466180","version":"1.0.0"}
EOSHIT
# before 2020-04-17: {"modelId":"3466180","cancelQueries":[],"version":"1.0.0","queries":[{"Query":{"Commands":[{"SemanticQueryDataShapeCommand":{"Query":{"OrderBy":[{"Direction":"2","Expression":{"Measure":{"Expression":{"SourceRef":{"Source":"d"}},"Property":"\u0398\u03b5\u03c4\u03b9\u03ba\u03ac"}}}],"From":[{"Entity":"pb_postcodes","Name":"p"},{"Name":"d","Entity":"dashboard_view"}],"Version":"2","Where":[{"Target":[{"Column":{"Property":"Name","Expression":{"SourceRef":{"Source":"p"}}}}],"Condition":{"Comparison":{"Left":{"Aggregation":{"Function":"5","Expression":{"Column":{"Property":"UUID","Expression":{"SourceRef":{"Source":"d"}}}}}},"Right":{"Literal":{"Value":"100D"}},"ComparisonKind":"1"}}}],"Select":[{"Column":{"Property":"Name","Expression":{"SourceRef":{"Source":"p"}}},"Name":"pb_postcodes.Name"},{"Name":"CountNonNull(dashboard_view.UUID)","Aggregation":{"Function":"5","Expression":{"Column":{"Expression":{"SourceRef":{"Source":"d"}},"Property":"UUID"}}}},{"Measure":{"Property":"\u0398\u03b5\u03c4\u03b9\u03ba\u03ac","Expression":{"SourceRef":{"Source":"d"}}},"Name":"dashboard_view.Count of result for 2"},{"Measure":{"Property":"\u0394\u03b5\u03af\u03b3\u03bc\u03b1\u03c4\u03b1","Expression":{"SourceRef":{"Source":"d"}}},"Name":"dashboard_view.\u0394\u03b5\u03b9\u03b3\u03bc\u03b1\u03c4\u03bf\u03bb\u03b7\u03c8\u03af\u03b1"}]},"Binding":{"Primary":{"Groupings":[{"Projections":["0","1","2","3"]}]},"DataReduction":{"Primary":{"Window":{"Count":"1000"}},"DataVolume":"4"},"Version":"1"}}}]},"QueryId":"","ApplicationContext":{"Sources":[{"ReportId":"070fa74b-ddb8-4174-b170-008df997d2ad"}],"DatasetId":"a1c6541b-1317-4ab8-bc9c-9b62a79434b4"},"CacheKey":"{\"Commands\":[{\"SemanticQueryDataShapeCommand\":{\"Query\":{\"Version\":2,\"From\":[{\"Name\":\"p\",\"Entity\":\"pb_postcodes\"},{\"Name\":\"d\",\"Entity\":\"dashboard_view\"}],\"Select\":[{\"Column\":{\"Expression\":{\"SourceRef\":{\"Source\":\"p\"}},\"Property\":\"Name\"},\"Name\":\"pb_postcodes.Name\"},{\"Aggregation\":{\"Expression\":{\"Column\":{\"Expression\":{\"SourceRef\":{\"Source\":\"d\"}},\"Property\":\"UUID\"}},\"Function\":5},\"Name\":\"CountNonNull(dashboard_view.UUID)\"},{\"Measure\":{\"Expression\":{\"SourceRef\":{\"Source\":\"d\"}},\"Property\":\"\u0398\u03b5\u03c4\u03b9\u03ba\u03ac\"},\"Name\":\"dashboard_view.Count of result for 2\"},{\"Measure\":{\"Expression\":{\"SourceRef\":{\"Source\":\"d\"}},\"Property\":\"\u0394\u03b5\u03af\u03b3\u03bc\u03b1\u03c4\u03b1\"},\"Name\":\"dashboard_view.\u0394\u03b5\u03b9\u03b3\u03bc\u03b1\u03c4\u03bf\u03bb\u03b7\u03c8\u03af\u03b1\"}],\"Where\":[{\"Condition\":{\"Comparison\":{\"ComparisonKind\":1,\"Left\":{\"Aggregation\":{\"Expression\":{\"Column\":{\"Expression\":{\"SourceRef\":{\"Source\":\"d\"}},\"Property\":\"UUID\"}},\"Function\":5}},\"Right\":{\"Literal\":{\"Value\":\"100D\"}}}},\"Target\":[{\"Column\":{\"Expression\":{\"SourceRef\":{\"Source\":\"p\"}},\"Property\":\"Name\"}}]}],\"OrderBy\":[{\"Direction\":2,\"Expression\":{\"Measure\":{\"Expression\":{\"SourceRef\":{\"Source\":\"d\"}},\"Property\":\"\u0398\u03b5\u03c4\u03b9\u03ba\u03ac\"}}}]},\"Binding\":{\"Primary\":{\"Groupings\":[{\"Projections\":[0,1,2,3]}]},\"DataReduction\":{\"DataVolume\":4,\"Primary\":{\"Window\":{\"Count\":1000}}},\"Version\":1}}}]}"}]}
		}, # and this url entry
		{
			# 5. SEX
			# start a url
			'url' => 'https://wabi-west-europe-api.analysis.windows.net/public/reports/querydata',
			# and its headers if any
			'headers' => [
				"User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.13; rv:61.0) Gecko/20100101 Firefox/73.0",
				"Accept" => "application/json, text/plain, */*",
				"Accept-Language" => "en-US,en;q=0.5",
				"ActivityId" => "6a5ceb1f-5e01-e897-03a0-c78c68c78a0b",
				"RequestId" => "20dad21b-a268-8bf9-3e5e-c82fade95d35",
				"X-PowerBI-ResourceKey" => "7f7f1f4f-69e5-4d2e-98ec-602bc0a9e33c",
				"Content-Type" => "application/json;charset=UTF-8",
				"referrer" => "https://wabi-west-europe-api.analysis.windows.net/public/reports/querydata",
			], # end header
			# 'modelId' is the most critical here, if this stops working (old: 3461989)
			# open developer tools in firefox/network tab/ open 'https://covid19.ucy.ac.cy/'
			# find a query and right-click copy as post and extract the modelId
			# NOTE: escape single quote ' -> \' and escape all unicode (e.g. must be literal \u1234)
			'post-data' => <<'EOSHIT',
{"modelId":"3466180","cancelQueries":[],"queries":[{"QueryId":"","ApplicationContext":{"Sources":[{"ReportId":"070fa74b-ddb8-4174-b170-008df997d2ad"}],"DatasetId":"a1c6541b-1317-4ab8-bc9c-9b62a79434b4"},"Query":{"Commands":[{"SemanticQueryDataShapeCommand":{"Binding":{"Version":"1","Primary":{"Groupings":[{"Projections":["0","1"]}]}},"Query":{"Select":[{"Name":"CountNonNull(dashboard_view.\u03a6\u03cd\u03bb\u03bf)","Arithmetic":{"Left":{"Aggregation":{"Expression":{"Column":{"Expression":{"SourceRef":{"Source":"d"}},"Property":"\u03a6\u03cd\u03bb\u03bf"}},"Function":"5"}},"Operator":"3","Right":{"ScopedEval":{"Expression":{"Aggregation":{"Expression":{"Column":{"Expression":{"SourceRef":{"Source":"d"}},"Property":"\u03a6\u03cd\u03bb\u03bf"}},"Function":"5"}},"Scope":[]}}}},{"Column":{"Property":"\u03a6\u03cd\u03bb\u03bf","Expression":{"SourceRef":{"Source":"d"}}},"Name":"dashboard_view.\u03a6\u03cd\u03bb\u03bf"}],"Where":[{"Condition":{"In":{"Expressions":[{"Column":{"Property":"\u03a6\u03cd\u03bb\u03bf","Expression":{"SourceRef":{"Source":"d"}}}}],"Values":[[{"Literal":{"Value":"'\u0386\u03bd\u03b4\u03c1\u03b5\u03c2'"}}],[{"Literal":{"Value":"'\u0393\u03c5\u03bd\u03b1\u03af\u03ba\u03b5\u03c2'"}}]]}}},{"Condition":{"In":{"Expressions":[{"Column":{"Expression":{"SourceRef":{"Source":"d"}},"Property":"flagpositive"}}],"Values":[[{"Literal":{"Value":"'1'"}}]]}}}],"From":[{"Name":"d","Entity":"dashboard_view"}],"Version":"2"}}}]}}],"version":"1.0.0"}
EOSHIT
		}, # and this url entry
		{
			# 6. NATIONALITY
			# start a url
			'url' => 'https://wabi-west-europe-api.analysis.windows.net/public/reports/querydata',
			# and its headers if any
			'headers' => [
				"User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.13; rv:61.0) Gecko/20100101 Firefox/73.0",
				"Accept" => "application/json, text/plain, */*",
				"Accept-Language" => "en-US,en;q=0.5",
				"ActivityId" => "6a5ceb1f-5e01-e897-03a0-c78c68c78a0b",
				"RequestId" => "20dad21b-a268-8bf9-3e5e-c82fade95d35",
				"X-PowerBI-ResourceKey" => "7f7f1f4f-69e5-4d2e-98ec-602bc0a9e33c",
				"Content-Type" => "application/json;charset=UTF-8",
				"referrer" => "https://wabi-west-europe-api.analysis.windows.net/public/reports/querydata",
			], # end header
			# 'modelId' is the most critical here, if this stops working (old: 3461989)
			# open developer tools in firefox/network tab/ open 'https://covid19.ucy.ac.cy/'
			# find a query and right-click copy as post and extract the modelId
			# NOTE: escape single quote ' -> \' and escape all unicode (e.g. must be literal \u1234)
			'post-data' => <<'EOSHIT',
{"cancelQueries":[],"modelId":"3466180","version":"1.0.0","queries":[{"QueryId":"","ApplicationContext":{"DatasetId":"a1c6541b-1317-4ab8-bc9c-9b62a79434b4","Sources":[{"ReportId":"070fa74b-ddb8-4174-b170-008df997d2ad"}]},"Query":{"Commands":[{"SemanticQueryDataShapeCommand":{"Query":{"Version":"2","Select":[{"Column":{"Property":"\u03a5\u03c0\u03b7\u03ba\u03bf\u03cc\u03c4\u03b7\u03c4\u03b1","Expression":{"SourceRef":{"Source":"d"}}},"Name":"dashboard_view.nationality (groups)"},{"Name":"Divide(CountNonNull(dashboard_view.UUID), ScopedEval(CountNonNull(dashboard_view.UUID), []))","Arithmetic":{"Right":{"ScopedEval":{"Expression":{"Aggregation":{"Function":"5","Expression":{"Column":{"Property":"UUID","Expression":{"SourceRef":{"Source":"d"}}}}}},"Scope":[]}},"Operator":"3","Left":{"Aggregation":{"Function":"5","Expression":{"Column":{"Expression":{"SourceRef":{"Source":"d"}},"Property":"UUID"}}}}}}],"OrderBy":[{"Expression":{"Column":{"Property":"\u03a5\u03c0\u03b7\u03ba\u03bf\u03cc\u03c4\u03b7\u03c4\u03b1","Expression":{"SourceRef":{"Source":"d"}}}},"Direction":"2"}],"From":[{"Name":"d","Entity":"dashboard_view"}],"Where":[{"Condition":{"In":{"Expressions":[{"Column":{"Expression":{"SourceRef":{"Source":"d"}},"Property":"\u03a5\u03c0\u03b7\u03ba\u03bf\u03cc\u03c4\u03b7\u03c4\u03b1"}}],"Values":[[{"Literal":{"Value":"'\u0386\u03bb\u03bb\u03b7'"}}],[{"Literal":{"Value":"'\u039a\u03c5\u03c0\u03c1\u03b9\u03b1\u03ba\u03ae'"}}]]}}},{"Condition":{"In":{"Expressions":[{"Column":{"Property":"flagpositive","Expression":{"SourceRef":{"Source":"d"}}}}],"Values":[[{"Literal":{"Value":"'1'"}}]]}}}]},"Binding":{"Primary":{"Groupings":[{"Projections":["0","1"]}]},"Version":"1"}}}]}}]}
EOSHIT
		}, # and this url entry
		{
			# 7. AGE groups
			# start a url
			'url' => 'https://wabi-west-europe-api.analysis.windows.net/public/reports/querydata',
			# and its headers if any
			'headers' => [
				"User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.13; rv:61.0) Gecko/20100101 Firefox/73.0",
				"Accept" => "application/json, text/plain, */*",
				"Accept-Language" => "en-US,en;q=0.5",
				"ActivityId" => "6a5ceb1f-5e01-e897-03a0-c78c68c78a0b",
				"RequestId" => "20dad21b-a268-8bf9-3e5e-c82fade95d35",
				"X-PowerBI-ResourceKey" => "7f7f1f4f-69e5-4d2e-98ec-602bc0a9e33c",
				"Content-Type" => "application/json;charset=UTF-8",
				"referrer" => "https://wabi-west-europe-api.analysis.windows.net/public/reports/querydata",
			], # end header
			# 'modelId' is the most critical here, if this stops working (old: 3461989)
			# open developer tools in firefox/network tab/ open 'https://covid19.ucy.ac.cy/'
			# find a query and right-click copy as post and extract the modelId
			# NOTE: escape single quote ' -> \' and escape all unicode (e.g. must be literal \u1234)
			'post-data' => <<'EOSHIT',
{"cancelQueries":[],"queries":[{"Query":{"Commands":[{"SemanticQueryDataShapeCommand":{"Query":{"Where":[{"Condition":{"Not":{"Expression":{"In":{"Values":[[{"Literal":{"Value":"'\u0386\u03b3\u03bd\u03c9\u03c3\u03c4\u03bf'"}}]],"Expressions":[{"Column":{"Property":"Category","Expression":{"SourceRef":{"Source":"p"}}}}]}}}}}],"From":[{"Name":"p","Entity":"pb_age_category"},{"Name":"d","Entity":"dashboard_view"}],"Version":"2","Select":[{"Column":{"Property":"Category","Expression":{"SourceRef":{"Source":"p"}}},"Name":"pb_age_category.Category"},{"Name":"dashboard_view.\u0398\u03b5\u03c4\u03b9\u03ba\u03ac","Arithmetic":{"Left":{"Measure":{"Property":"\u0398\u03b5\u03c4\u03b9\u03ba\u03ac","Expression":{"SourceRef":{"Source":"d"}}}},"Right":{"ScopedEval":{"Scope":[],"Expression":{"Measure":{"Expression":{"SourceRef":{"Source":"d"}},"Property":"\u0398\u03b5\u03c4\u03b9\u03ba\u03ac"}}}},"Operator":"3"}},{"Arithmetic":{"Left":{"Measure":{"Expression":{"SourceRef":{"Source":"d"}},"Property":"\u0394\u03b5\u03af\u03b3\u03bc\u03b1\u03c4\u03b1"}},"Right":{"ScopedEval":{"Expression":{"Measure":{"Expression":{"SourceRef":{"Source":"d"}},"Property":"\u0394\u03b5\u03af\u03b3\u03bc\u03b1\u03c4\u03b1"}},"Scope":[]}},"Operator":"3"},"Name":"dashboard_view.\u0394\u03b5\u03af\u03b3\u03bc\u03b1\u03c4\u03b1"},{"Arithmetic":{"Left":{"Measure":{"Expression":{"SourceRef":{"Source":"d"}},"Property":"\u0391\u03bd\u03b1\u03c6\u03bf\u03c1\u03ad\u03c2 Normalized"}},"Right":{"ScopedEval":{"Scope":[],"Expression":{"Measure":{"Expression":{"SourceRef":{"Source":"d"}},"Property":"\u0391\u03bd\u03b1\u03c6\u03bf\u03c1\u03ad\u03c2 Normalized"}}}},"Operator":"3"},"Name":"dashboard_view.\u0391\u03bd\u03b1\u03c6\u03bf\u03c1\u03ad\u03c2 Normalized"}],"OrderBy":[{"Expression":{"Column":{"Property":"Category","Expression":{"SourceRef":{"Source":"p"}}}},"Direction":"1"}]},"Binding":{"Primary":{"Groupings":[{"Projections":["0","1","2","3"]}]},"Version":"1"}}}]},"QueryId":"","ApplicationContext":{"Sources":[{"ReportId":"070fa74b-ddb8-4174-b170-008df997d2ad"}],"DatasetId":"a1c6541b-1317-4ab8-bc9c-9b62a79434b4"}}],"version":"1.0.0","modelId":"3466180"}
EOSHIT
		}, # and this url entry
	];

	my $P = $params->{'model-params'};
	my $modelId = exists($P->{'modelId'}) && defined('modelId')
		? $P->{'modelId'} : undef; 

	my ($i, $H, $k, $apv);
	for my $U (@{$params->{'urls'}}){
		for my $apk (keys %$P){
			$apv = $P->{$apk};
			$U->{'post-data'} =~ s/("${apk}"\s*\:\s*(?:"?))([0-9a-zA-Z\-]+)("?)/$1${apv}$3/g;
			$U->{'post-data'} =~ s/(\\"${apk}\\"\s*\:\s*(?:\\"?))([0-9a-zA-Z\-]+)(\\"?)/$1${apv}$3/g;
		}
		$H = $U->{'headers'};
		for($i=scalar(@$H)-2;$i>=0;$i-=2){
			$k = $H->[$i];
			if( exists($P->{$k}) && defined($P->{$k}) ){ $H->[$i+1] = $P->{$k} }
		}
	}
#	if( $debug > 0 ){ warn "these are my params:\n".Statistics::Covid::Utils::mypp($params)."\n" }

	# initialise our parent class
	my $self = $class->SUPER::new($params);
	if( ! defined $self ){ warn "error, call to $class->new() has failed."; return undef }

	# and do set parameters specific to this particular data provider
	$self->name('CY::UCY'); # <<<< Make sure this is unique over all providers
	$self->datafilesdir(File::Spec->catfile(
		$self->datafilesdir(), # use this as prefix it was set in config
		# and append a dir hierarchy relevant to this provider
		# all :: will become '/' (filesys separators)
		split(/::/, $self->name())
	)); # so this is saved to <datafilesdir>/World/JHU

	# initialise this particular data provider
	if( ! $self->init() ){ warn "error, call to init() has failed."; return undef }

	# we use this all the time so we may as well cache it
	$self->{'_admin0'} = Statistics::Covid::Geographer::get_official_name('Cyprus');

	# this will now be UCY obj (not generic)
	return $self
}
# overwriting this from parent
# returns undef on failure or a data id unique on timepoint
# which can be used for saving data to a file or labelling this data
# timeline we are interested in, its last point is the last date of update
# timeline is the 1st slot [0]
sub create_data_id {
	my $self = $_[0];
	my $datas_item = $_[1]; # this is an arrayref of [url, data_received_string, data_as_perlvar]

	my $aurl = $datas_item->[0];
	my $pv = $datas_item->[2]->{'results'}->[0]->{'result'}->{'data'}->{'dsr'}->{'DS'}->[0]->{'PH'}->[0]->{'DM0'};

	my $millisecondsSinceEpoch = $pv->[0]->{'M0'};
	my $date = Statistics::Covid::Utils::epoch_milliseconds_to_DateTime($millisecondsSinceEpoch);
	if( ! defined $date ){ warn Statistics::Covid::Utils::mypp($pv)."\nerror, call to ".'Statistics::Covid::Utils::epoch_milliseconds_to_DateTime()'." has failed for this datespec (expected millis) '$millisecondsSinceEpoch', check above data, url was '$aurl'"; return undef }
	my $dataid = $date->strftime('2020-%m-%dT%H.%M.%S')
		     . '_'
		     . $date->epoch()
	;
	if( $self->debug() > 0 ){ warn "create_data_id() : made one as '$dataid' from millis '$millisecondsSinceEpoch'" }
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

	my $debug = $self->debug();
	my ($infile, $pv);
	my @ret;
	for my $index (0..(scalar(@{$self->{'urls'}})-1)){
		$infile = "${inbasename}.data.${index}.json";
		my $infh;
		if( ! open($infh, '<:encoding(UTF-8)', $infile) ){ warn "error, failed to open file '$infile' for reading, $!"; return undef }
		my $json_contents; {local $/=undef; $json_contents = <$infh> } close $infh;
		$pv = Data::Roundtrip::json2perl($json_contents);
		if( ! defined $pv ){ warn "error, call to ".'Data::Roundtrip::json2perl()'." has failed (for data, file '$infile')."; return undef }
		if( $debug > 0 ) { warn "load_fetched_data_from_localfile() : read file '$infile' ..." }
		push @ret, ['file://'.$infile, $json_contents, $pv];
	}
	if( ! $self->postprocess_fetched_data(\@ret) ){ warn "error, call to ".'postprocess_fetched_data()'." has failed"; return undef }
	return \@ret
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
	my $dataid = $self->create_data_id($datas->[$index]); # extract date from timeline, 1st element in datas
	if( ! defined $dataid ){ warn "error, call to ".'create_data_id()'." has failed for '".$datas->[$index]->[0]."'"; return 0 }
	$_->[3] = $dataid for @$datas;
	return 1
}
sub	_complete_the_shit {
	my ($pvLatestComplete, $apv) = @_;
	#print "_complete_the_shit() called with:\n".Statistics::Covid::Utils::mypp($pvLatestComplete)."\nand: ".Statistics::Covid::Utils::mypp($apv)."\n";
	if( (ref($apv)ne'HASH') || (ref($pvLatestComplete)ne'HASH') || ! exists $apv->{'R'} ){ warn Statistics::Covid::Utils::mypp($pvLatestComplete)."\nand apv:\n".Statistics::Covid::Utils::mypp($apv)."\nR does not exist in the above or it is not a HASH or the above that is not a hash, why want to complete? I guess you have fed me the wrong data - you think is e.g. eparxies but it is timelines (just an example)"; return 0 }
	if( exists $apv->{'Ø'} ){ die "_complete_the_shit() called with: pvLatestComplete:\n".Statistics::Covid::Utils::mypp($pvLatestComplete)."\nand:\n".Statistics::Covid::Utils::mypp($apv)."\nSHIT found! Check above details"; return 0 }
	my $idx = -1;
	my $C = $apv->{'C'};
	my $LC = $pvLatestComplete->{'C'};
	#print "LC=".Statistics::Covid::Utils::mypp($LC)."\n"; print "R=".$apv->{'R'}." and bin=".sprintf('%b', $apv->{'R'})."\n";
	for my $bitR (reverse split //, sprintf('%b', $apv->{'R'})){
		$idx++;
		next unless $bitR == 1;
		splice @$C, $idx, 0, $LC->[$idx]; # squeeze it in the middle (possibly) - the 0 is to delete nothing
		#print "DOUG: R=$bitR, idx=$idx\n";
	}
	#print "now C=".Statistics::Covid::Utils::mypp($C)."\n";
	return 1; # success
}
# the fetched data as an arrayref with 1 element which is an array of
#   [ [url, data_received_string, data_as_perlvar] ]
# returns the arrayref of Datum Objects on success or undef on failure
sub create_Datums_from_fetched_data {
	my $self = $_[0];
	my $datas = $_[1];

	my $debug = $self->debug();

	# each of our items in 'urls' will be saved as a Datum with the data as comment and admin4 will be the label, e.g. eparxia

	my $aurl = $datas->[0]->[0];
	my $data_id = $datas->[0]->[3];

	my $ds = $self->name();
	my $admin0 = $self->{'_admin0'};
	my ($confirmed, $anafores, $deigmata, $admin1, $admin2, $admin4, $numitems,
	    $last_complete_entry, $atmillis, $admin3, @ret, $subIage, $subIper100000,
	    $total_confirmed, $total_active, $total_terminal,
	    $total_peopletested, $total_anafores, $total_recovered,
	    $peopletested_today, $terminal_today, $recovered_today, $anafores_today,
	    $active, $terminal, $peopletested, $confirmed_today, $recovered,
	    $total_last_update_epoch,
	    $peopletested_per_100000, $confirmed_per_100000, $anafores_per_100000,
	    $pv, $I, $aC, $id, $idx
	);

	# last update
	$I = 0;
	$pv = $datas->[$I]->[2]->{'results'}->[0]->{'result'}->{'data'}->{'dsr'}->{'DS'}->[0]->{'PH'}->[0]->{'DM0'};
	$total_last_update_epoch = $pv->[0]->{'M0'};
	$total_last_update_epoch = substr($total_last_update_epoch, 0, -3); # convert millis to seconds
	my $total_last_update_date = Statistics::Covid::Utils::epoch_seconds_to_DateTime($total_last_update_epoch);
	if( ! defined $total_last_update_date ){ warn "error, call to ".'Statistics::Covid::Utils::epoch_seconds_to_DateTime()'." has failed for this date spec '$total_last_update_epoch'"; return undef }
	# OVERALL
	# here we will see all latest data (top-right-box on dashboard).
	# the confirmed must be the same with latest timeline and also latest refresh date
	# but this is the official total data and last update time (if individual data does not provide)
	$I = 1;
	$admin4 = 'CY-TOTAL';
	$pv = $datas->[$I]->[2]->{'results'}->[0]->{'result'}->{'data'}->{'dsr'}->{'DS'}->[0]->{'PH'}->[0]->{'DM0'}->[0];
	($total_active, $total_terminal, $total_peopletested,
	 $total_recovered, $total_confirmed, $total_anafores) = @{ $pv->{'C'} };
	if( ! defined $total_anafores ){ warn pp($datas)."\nand in particular C:\n".pp($pv)."\n$admin4 : error, one of confirmed,terminal,recovered,peopletested,anafores,active is undefined for I=$I."; return undef }
	$id = join('/', $admin4, $total_last_update_epoch);
	my $datumobj = Statistics::Covid::Datum->new({
		'id' => $id,
		'admin0' => $admin0,
		'admin4' => $admin4,
		'confirmed' => $total_confirmed,
		'peopletested' => $total_peopletested,
		'recovered' => $total_recovered,
		'unconfirmed' => $total_anafores,
		'terminal' => $total_terminal,
		'i1' => $total_active,
		'date' => $total_last_update_date,
		'type' => 'admin0',
		'datasource' => $ds,
	});
	if( ! defined $datumobj ){ warn pp($pv)."\nerror, call to ".'Statistics::Covid::Datum->new()'." has failed for above data"; return undef }
	push @ret, $datumobj;
	if( $debug > 0 ){ warn $datumobj->get_column('datetimeISO8601').", Overall: confirmed=$total_confirmed, terminal=$total_terminal, recovered=$total_recovered, peopletested=$total_peopletested, anafores=$total_anafores, active=$total_active" }

	# TIMELINE
	$I = 2; # index to the 'urls' array
	$admin4 = 'CY-TIMELINE';
	$pv = $datas->[$I]->[2]->{'results'}->[0]->{'result'}->{'data'}->{'dsr'}->{'DS'}->[0]->{'PH'}->[0]->{'DM0'};
	$last_complete_entry = undef;
	my ($timeline_latest_confirmed_total, $timeline_latest_confirmed_today);
	$confirmed = $terminal = $peopletested = $recovered = $anafores = 0;
	for my $aCYlocation (@$pv){
		# quick validation, it's milliseconds since epoch, circa 2020 so 156+...
		if( $aCYlocation->{'C'}->[0] !~ /^1[56]\d{11}$/ ){ warn pp($aCYlocation)."\nerror, the above does not validate as '$admin4': it is not seconds-since-unix-epoch around 2020"; return undef }
		#print "going for ".Statistics::Covid::Utils::mypp($aCYlocation)."\n";
		if( scalar(@{$aCYlocation->{'C'}}) != 7 ){ if( ! _complete_the_shit($last_complete_entry, $aCYlocation) ){ die Statistics::Covid::Utils::mypp($pv)."\nand this\n".Statistics::Covid::Utils::mypp($aCYlocation)."\n\nerror, _complete_the_shit() has failed for above data" } }
		$last_complete_entry = $aCYlocation;

		#print "and returned for ".Statistics::Covid::Utils::mypp($aCYlocation)."\n";
		# if it is empty then it is the same as the most recent complete entry
		# the first one always  is complete
		$aCYlocation = $aCYlocation->{'C'};
		# this is actually milliseconds but we chop them last bits ...
		$atmillis = $aCYlocation->[0];
		$confirmed = $aCYlocation->[1]; # total confirmed all days
		$confirmed_today = $aCYlocation->[2]; # confirmed only today
		$terminal_today = $aCYlocation->[3]; $terminal += $terminal_today;
		$peopletested_today = $aCYlocation->[4]; $peopletested += $peopletested_today;
		$recovered_today = $aCYlocation->[5]; $recovered += $recovered_today;
		# this is a bit dodgy, total is 130,000 whereas actual total is 25000
		# but if it is overall is too little like 3000
		$anafores_today = $aCYlocation->[6]; $anafores += $anafores_today;
		if( ! defined($confirmed) || ! defined($confirmed_today) || ! defined($terminal_today) || ! defined($peopletested_today) || ! defined($recovered_today) || ! defined($anafores_today) ){ die Statistics::Covid::Utils::mypp($pv)."\nand last complete entry:\n".Statistics::Covid::Utils::mypp($last_complete_entry)."\nand current entry:\n".Statistics::Covid::Utils::mypp($aCYlocation)."\nlast complete entry is bad (TIMELINE), see data above" }
		$last_complete_entry = {C=>[$atmillis, $confirmed, $confirmed_today, $terminal_today, $peopletested_today, $recovered_today, $anafores_today]};
		$atmillis =~ s/.{3}$//; # convert millis to seconds
		$id = join('/', $admin0, $admin4, $atmillis);
		my $datumobj = Statistics::Covid::Datum->new({
			'id' => $id,
			'admin0' => $admin0,
			'admin4' => $admin4,
			'confirmed' => $confirmed,
			'peopletested' => $peopletested,
			'terminal' => $terminal,
			'unconfirmed' => $anafores,
			'recovered' => $recovered,
			'i1' => $confirmed_today,
			'i2' => $terminal_today,
			'i3' => $peopletested_today,
			'i4' => $recovered_today,
			'i5' => $anafores_today,
			'date' => $atmillis, # converted to seconds
			'type' => 'admin0', # country
			'datasource' => $ds,
		});
		if( ! defined $datumobj ){ warn pp($aCYlocation)."\nerror, call to ".'Statistics::Covid::Datum->new()'." has failed for the above data"; return undef }
		push @ret, $datumobj;
		if( $debug > 0 ){
			my $date = Statistics::Covid::Utils::epoch_seconds_to_DateTime($atmillis);
			if( ! defined $date ){ warn "error, call to ".'Statistics::Covid::Utils::epoch_seconds_to_DateTime()'." has failed for this datespec: '$atmillis'"; return undef }
			warn "count: on $date : confirmed-for-today: $confirmed_today, confirmed-total: $confirmed, terminal-total: $terminal, recoved-total: $recovered, anafores-total: $anafores, tests-total: $peopletested";
		}
	}
	if( $debug > 0 ){
		my $date = Statistics::Covid::Utils::epoch_seconds_to_DateTime($atmillis);
		if( ! defined $date ){ warn "error, call to ".'Statistics::Covid::Utils::epoch_seconds_to_DateTime()'." has failed for this datespec: '$atmillis'"; return undef }
		warn "Most accurate count: on $date : confirmed-for-today: $confirmed_today, confirmed-total: $confirmed, terminal-total: $terminal, recoved-total: $recovered, anafores-total: $anafores, tests-total: $peopletested";
	}

	# EPARXIA
	$I = 3;
	$admin4 = 'CY-EPARXIA';
	$pv = $datas->[$I]->[2]->{'results'}->[0]->{'result'}->{'data'}->{'dsr'}->{'DS'}->[0]->{'PH'}->[0]->{'DM0'};
	$last_complete_entry = undef;
	for my $aCYlocation (@$pv){
		# quick validation: it must be (and this is the order in regex) ammo, larn, leme, lefk, pafo
		if( exists $aCYlocation->{'Ø'} ){ next } # skip this because it had nothing useful
		if( $aCYlocation->{'C'}->[0] !~ /^\x{391}\x{3bc}\x{3bc}\x{3cc}\x{3c7}\x{3c9}\x{3c3}\x{3c4}\x{3bf}\x{3c2}|\x{39b}\x{3ac}\x{3c1}\x{3bd}\x{3b1}\x{3ba}\x{3b1}|\x{39b}\x{3b5}\x{3bc}\x{3b5}\x{3c3}\x{3cc}\x{3c2}|\x{39b}\x{3b5}\x{3c5}\x{3ba}\x{3c9}\x{3c3}\x{3af}\x{3b1}|\x{3a0}\x{3ac}\x{3c6}\x{3bf}\x{3c2}$/ ){ warn pp($datas->[$I]->[2])."\nand in particular this item:\n".pp($aCYlocation)."\nerror, the above does not validate as '$admin4': because '".$aCYlocation->{'C'}->[0]."' is not cyprus district name"; return undef }
		#print "going for ".Statistics::Covid::Utils::mypp($aCYlocation)."\n";
		if( scalar(@{$aCYlocation->{'C'}}) != 6 ){ if( ! _complete_the_shit($last_complete_entry, $aCYlocation) ){ die Statistics::Covid::Utils::mypp($pv)."\nand this\n".Statistics::Covid::Utils::mypp($aCYlocation)."\n\nerror, _complete_the_shit() has failed for above data" } }
		$last_complete_entry = $aCYlocation;
		$aCYlocation = $aCYlocation->{'C'};
		$admin1 = $aCYlocation->[0];
		if( ! defined $admin1 ){ die Statistics::Covid::Utils::mypp($pv)."\nadmin1 was not defined for above" }
		$anafores_per_100000 = $aCYlocation->[1]; # unconfirmed?
		$confirmed_per_100000 = $aCYlocation->[2];
		$peopletested_per_100000 = $aCYlocation->[3];
		$confirmed = $aCYlocation->[4];
		$peopletested = $aCYlocation->[5];
		if( ! defined($anafores_per_100000) || ! defined($confirmed_per_100000) || ! defined($peopletested_per_100000) || ! defined($confirmed) || ! defined($peopletested) ){ die Statistics::Covid::Utils::mypp($pv)."\nand last complete entry:\n".Statistics::Covid::Utils::mypp($last_complete_entry)."\nand current entry:\n".Statistics::Covid::Utils::mypp($aCYlocation)."\nlast complete entry is bad ($admin4), see data above" }
		$last_complete_entry = {C=>[$aCYlocation->[0], $anafores_per_100000, $confirmed_per_100000, $peopletested_per_100000, $confirmed, $peopletested]};
		$id = join('/', $admin0, $admin1, $admin4, $total_last_update_epoch);
		# make it into a percentage, 0.3 means 30%
		$anafores_per_100000 /= 100000;
		$confirmed_per_100000 /= 100000;
		$peopletested_per_100000 /= 100000;
		my $datumobj = Statistics::Covid::Datum->new({
			'id' => $id, #$admin1.'_'.$admin4.'_'.$data_id,
			'admin1' => $admin1,
			'admin0' => $admin0,
			'admin4' => $admin4,
			'confirmed' => $confirmed,
			'peopletested' => $peopletested,
			# percentages, e.g. 0.3 -> 30%
			'i1' => $anafores_per_100000,
			'i2' => $confirmed_per_100000,
			'i3' => $peopletested_per_100000,
			'date' => $total_last_update_epoch,
			'type' => 'admin1', # eparxia
			'datasource' => $ds,
		});
		if( ! defined $datumobj ){ warn pp($aCYlocation)."\nerror, call to ".'Statistics::Covid::Datum->new()'." has failed for the above data"; return undef }
		push @ret, $datumobj;
		if( $debug > 0 ){ warn "$admin4 : $admin1 : confirmed: $confirmed, peopletested: $peopletested, anafores: $anafores_per_100000, confirmed: $confirmed_per_100000, peopletested: $peopletested_per_100000" }
	}

	# ALL LOCATIONS (good)
	$I = 4;
	$admin4 = 'CY-ALL-LOCATIONS';
	$pv = $datas->[$I]->[2]->{'results'}->[0]->{'result'}->{'data'}->{'dsr'}->{'DS'}->[0]->{'PH'}->[0]->{'DM0'};
	$last_complete_entry = undef;
	for my $aCYlocation (@$pv){
		# quick validation: we can only check for unicode
		if( ! Statistics::Covid::Utils::has_utf8($aCYlocation->{'C'}->[0]) ){ warn pp($aCYlocation)."\nerror, the above does not validate as '$admin4': it is not unicode as the name of a city/town/village!"; return undef }
		if( scalar(@{$aCYlocation->{'C'}}) != 3 ){ if( ! _complete_the_shit($last_complete_entry, $aCYlocation) ){ die Statistics::Covid::Utils::mypp($pv)."\nand this\n".Statistics::Covid::Utils::mypp($aCYlocation)."\n\nerror, _complete_the_shit() has failed for above data while doing '$admin4', is it the correct data we are feeding it?" } }
		$last_complete_entry = $aCYlocation;

		$aCYlocation = $aCYlocation->{'C'};
		$admin2 = $aCYlocation->[0];
		if( ! defined $admin2 ){ die Statistics::Covid::Utils::mypp($pv)."\nadmin2 was not defined for above" }
		$confirmed = $aCYlocation->[1];
		$anafores = $aCYlocation->[2];
		if( ! defined($confirmed) || ! defined($anafores) ){ die Statistics::Covid::Utils::mypp($pv)."\nand last complete entry:\n".Statistics::Covid::Utils::mypp($last_complete_entry)."\nand current entry:\n".Statistics::Covid::Utils::mypp($aCYlocation)."\nlast complete entry is bad (admin4A), see data above" }
		$last_complete_entry = {C=>[$admin2, $confirmed, $anafores]};
		$id = join('/', $admin0, $admin2, $admin4, $total_last_update_epoch);
		my $datumobj = Statistics::Covid::Datum->new({
			'id' => $id, #$admin2.'_'.$admin4.'_'.$data_id,
			'admin2' => $admin2, # which is a city or village (or suburb but hey!)
			'admin0' => $admin0,
			'admin4' => $admin4,
			'confirmed' => $confirmed,
			'date' => $total_last_update_epoch,
			'type' => 'admin3', # villages but also latsia, that's what all locations is
			'datasource' => $ds,
		});
		if( ! defined $datumobj ){ warn pp($aCYlocation)."\nerror, call to ".'Statistics::Covid::Datum->new()'." has failed for the above data"; return undef }
		push @ret, $datumobj
	}

	# SEX
	$I = 5;
	$admin4 = 'CY-SEX';
	my %translate = (
		'Άνδρες' => 'male',
		'Γυναίκες' => 'female',
	);
	# admin3 will be 'men', 'women'
	my %percs;
	$pv = $datas->[$I]->[2]->{'results'}->[0]->{'result'}->{'data'}->{'dsr'}->{'DS'}->[0]->{'PH'}->[0]->{'DM0'};
	if( ! defined($pv) || (ref($pv) ne 'ARRAY') ){ die Statistics::Covid::Utils::mypp($pv)."\nfailed to find the path" }
	for $idx (0..1){
		if( ! defined $pv->[$idx]->{'C'}->[0] ){ die Statistics::Covid::Utils::mypp($pv)."\nerror, for 'CY-SEX-NAT' (I=$I), tried to translate above but element [".$idx."] was undefined" }
		if( ! exists $translate{$pv->[$idx]->{'C'}->[0]} ){ die Statistics::Covid::Utils::mypp($pv)."\nerror, for 'CY-SEX-NAT' (I=$I), nothing in ".'%translate'." contains this (for index $idx): '".$pv->[$idx]->{'C'}->[0]."'" }
		$percs{$translate{$pv->[$idx]->{'C'}->[0]}} = $pv->[$idx]->{'C'}->[1];
	}
	for my $aperc (sort keys %percs){
		$admin3 = $aperc; # in english see above
		$id = join('/', $admin0, $admin3, $admin4, $total_last_update_epoch);
		my $datumobj = Statistics::Covid::Datum->new({
			'id' => $id, #$admin4.'_'.$admin3.'_'.$data_id,
			'admin0' => $admin0,
			'admin3' => $admin3,
			'admin4' => $admin4,
			'confirmed' => int($total_confirmed * $percs{$aperc}),
			'peopletested' => int($total_peopletested * $percs{$aperc}),
			'unconfirmed' => int($total_anafores * $percs{$aperc}),
			'terminal' => int($total_terminal * $percs{$aperc}),
			'recovered' => int($total_recovered * $percs{$aperc}),
			'i1' => 0+$percs{$aperc}, # the percentage
			'date' => $total_last_update_epoch,
			'type' => 'admin0', # country
			'datasource' => $ds,
		});
		if( ! defined $datumobj ){ warn pp($pv)."\nerror, call to ".'Statistics::Covid::Datum->new()'." has failed for the above data"; return undef }
		if( $debug > 0 ){ warn "$admin4 : $aperc : ".$percs{$aperc}." %" }
		push @ret, $datumobj;
	}

	# NATIONALITY
	$I = 6;
	$admin4 = 'CY-NATIONALITY';
	%translate = (
		'Κυπριακή' => 'Cypriots',
		'Άλλη' => 'Others' # !!
	);
	# admin3 will be 'men', 'women'
	%percs = ();
	$pv = $datas->[$I]->[2]->{'results'}->[0]->{'result'}->{'data'}->{'dsr'}->{'DS'}->[0]->{'PH'}->[0]->{'DM0'};
	if( ! defined($pv) || (ref($pv) ne 'ARRAY') ){ die Statistics::Covid::Utils::mypp($pv)."\nfailed to find the path" }
	for $idx (0..1){
		if( ! defined $pv->[$idx]->{'C'}->[0] ){ die Statistics::Covid::Utils::mypp($pv)."\nerror, for 'CY-SEX-NAT' (I=$I), tried to translate above but element [".$idx."] was undefined" }
		if( ! exists $translate{$pv->[$idx]->{'C'}->[0]} ){ die Statistics::Covid::Utils::mypp($pv)."\nerror, for 'CY-SEX-NAT' (I=$I), nothing in ".'%translate'." contains this (for index $idx): '".$pv->[$idx]->{'C'}->[0]."'" }
		$percs{$translate{$pv->[$idx]->{'C'}->[0]}} = $pv->[$idx]->{'C'}->[1];
	}
	for my $aperc (sort keys %percs){
		$admin3 = $aperc; # in english see above
		$id = join('/', $admin0, $admin3, $admin4, $total_last_update_epoch);
		my $datumobj = Statistics::Covid::Datum->new({
			'id' => $id, #$admin4.'_'.$admin3.'_'.$data_id,
			'admin0' => $admin0,
			'admin3' => $admin3,
			'admin4' => $admin4,
			'confirmed' => int($total_confirmed * $percs{$aperc}),
			'peopletested' => int($total_peopletested * $percs{$aperc}),
			'unconfirmed' => int($total_anafores * $percs{$aperc}),
			'terminal' => int($total_terminal * $percs{$aperc}),
			'recovered' => int($total_recovered * $percs{$aperc}),
			'i1' => 0.0+$percs{$aperc}, # the percentage
			'date' => $total_last_update_epoch,
			'type' => 'admin0', # country
			'datasource' => $ds,
		});
		if( ! defined $datumobj ){ warn pp($pv)."\nerror, call to ".'Statistics::Covid::Datum->new()'." has failed for the above data"; return undef }
		if( $debug > 0 ){ warn "$admin4 : $aperc : ".$percs{$aperc}." %" }
		push @ret, $datumobj;
	}

	# AGE
	$I = 7;
	$admin4 = 'CY-AGE';
	$last_complete_entry = undef;
	my %ages;
	$pv = $datas->[$I]->[2]->{'results'}->[0]->{'result'}->{'data'}->{'dsr'}->{'DS'}->[0]->{'PH'}->[0]->{'DM0'};
	if( ! defined($pv) || (ref($pv) ne 'ARRAY') ){ die Statistics::Covid::Utils::mypp($pv)."\nfailed to find the path" }
	for my $aCYlocation (@$pv){
		# quick validation: it must be an age group like 0-10 or 30-49 or 80+
		if( $aCYlocation->{'C'}->[0] !~ /^\d+(?:\-\d+)|\+$/ ){ warn pp($aCYlocation)."\nerror, the above does not validate as '$admin4': not an age group"; return undef }
		if( scalar(@{$aCYlocation->{'C'}}) != 4 ){ if( ! _complete_the_shit($last_complete_entry, $aCYlocation) ){ die Statistics::Covid::Utils::mypp($pv)."\nand this\n".Statistics::Covid::Utils::mypp($aCYlocation)."\n\nerror, _complete_the_shit() has failed for above data while doing '$admin4', is it the correct data we are feeding it?" } }
		#print "going for ".Statistics::Covid::Utils::mypp($aCYlocation)."\n";
		$last_complete_entry = $aCYlocation;
		$admin3 = $aCYlocation->{'C'}->[0];
		if( ! defined $aCYlocation->{'C'}->[3] ){ warn pp($aCYlocation)."\n$admin4 : error, the above does not contain what it should"; return undef }
		$ages{$admin3} = [ $aCYlocation->{'C'}->@[1,2,3] ];
		# 1,2,3: thetika, deigmata, anafores
		$last_complete_entry = {C=>[$admin3, @{$ages{$admin3}}]};
	}
	for my $aperc (sort keys %ages){
		$admin3 = $aperc; # an age group like '30-39' or '80+' (starts from '0-9')
		$id = join('/', $admin0, $admin3, $admin4, $total_last_update_epoch);
		$confirmed = int($total_confirmed * $ages{$aperc}->[0]);
		$peopletested = int($total_peopletested * $ages{$aperc}->[1]);
		$anafores = int($total_anafores * $ages{$aperc}->[2]);
		my $datumobj = Statistics::Covid::Datum->new({
			'id' => $id, #$admin4.'_'.$admin3.'_'.$data_id,
			'admin0' => $admin0,
			'admin3' => $admin3,
			'admin4' => $admin4,
			'confirmed' => $confirmed,
			'peopletested' => $peopletested,
			'unconfirmed' => $anafores,
			'i1' => 0.0+$ages{$aperc}->[0],
			'i2' => 0.0+$ages{$aperc}->[1],
			'i3' => 0.0+$ages{$aperc}->[2],
			'date' => $total_last_update_epoch,
			'type' => 'admin0', # country
			'datasource' => $ds,
		});
		if( ! defined $datumobj ){ warn pp($pv)."\nerror, call to ".'Statistics::Covid::Datum->new()'." has failed for the above data"; return undef }
		if( $debug > 0 ){ warn "$admin4 : age group $aperc: confirmed: $confirmed (".$ages{$aperc}->[0]."), tests: $peopletested (".$ages{$aperc}->[1]."), anafores: $anafores (".$ages{$aperc}->[2].")" }
		push @ret, $datumobj;
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

	my ($outfile, @ret, $outbase, $dataid);
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
	for $index (0..(scalar(@$datas)-1)){
		$outfile = "${outbase}.data.${index}.json";
		if( ! Statistics::Covid::Utils::save_text_to_localfile($datas->[$index]->[1], $outfile) ){ warn "error, call to ".'save_text_to_localfile()'." has failed."; return undef }
		$outfile = "${outbase}.data.${index}.pl";
		if( ! Statistics::Covid::Utils::save_perl_var_to_localfile($datas->[$index]->[2], $outfile) ){ warn "error, call to ".'save_perl_var_to_localfile()'." has failed."; return undef }
		print "save_fetched_data_to_localfile() : saved data to base '$outbase'.\n";
		push @ret, $outbase;
	}
	return \@ret
}
1;
# end program, below is the POD

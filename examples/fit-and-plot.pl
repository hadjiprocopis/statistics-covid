#!/usr/bin/env perl

use strict;
use warnings;

use lib 'blib/lib';

use Data::Dump qw/pp/;

use Statistics::Covid;
use Statistics::Covid::Analysis::Model::Simple;
use Statistics::Covid::Analysis::Model;
use Statistics::Covid::Analysis::Plot::Simple;

my ($objs, $covid, $ret, $df, $models, @fitted_data);

# create the main entry point to fetch and store data
my $cparams = {
	'config-file' => 'config/config.json',
	# no providers because we are only searching
	'debug' => 2,
};

# set verbosity to the 2 modules which do the plot/fit
# they are not OO
$Statistics::Covid::Analysis::Plot::Simple::DEBUG = 1;
$Statistics::Covid::Analysis::Model::Simple::DEBUG = 1;

# create the main entry point.
# if database is not deployed it will be
# with all the necessary tables
$covid = Statistics::Covid->new($cparams)
	or die pp($cparams)."\nStatistics::Covid->new() failed for the above parameters";

$objs = $covid->select_datums_from_db_time_ascending({
	'conditions' => {
	      # admin0=country-name, admin4=a neighbourhood
	      # also there is the 'datasource' (the provider of data, e.g. World::JHU)
	      # and type which is 'admin0' for country-totals, 'admin1' for state-totals
	      # for example UK has type='admin0' record (for the whole country)
	      # and type='amdin1' records for all local authorities
	      'admin0' => 'Madagascar',
	},
});
die "select_datums_from_db_time_ascending() has failed" unless defined $objs;

# convert datum objects (DO) to a dataframe
# a DO holds data for 1 single point in time.
# an array of DO is just that.
# a dataframe is where the array of DO is converted
# to arrays of values for each quantity (see 'content' below)
# we are interested in.
# At the end we will have all time in one array (named 'datetimeUnixEpoch')
# all confirmed number of cases in another array and so on.
# that makes it easier to plot and pass this data onto 3rd-party graphers.
# just arrays of values.
# This dataframe-building utility can optionally group data given a number
# of other properties. For example the country name 'admin0'.
$df = Statistics::Covid::Utils::datums2dataframe({
	'datum-objs' => $objs,
	'groupby' => ['admin0'],
	'content' => ['datetimeUnixEpoch', 'confirmed'],
	#'content' => ['datetimeUnixEpoch', 'confirmed', 'recovered', 'terminal'],
});
# our X-axis or independent variable is time.
# Measured in seconds since the dawn of Unix (thank god for that)
# However these are large numbers and I prefer to convert to hours since the
# oldest record in our dataframe, this is how to do this:
for(sort keys %$df){
	# this is our original seconds array:
	my @copy = @{$df->{$_}->{'datetimeUnixEpoch'}->{'data'}};
	# this takes an array of 'seconds-since-unix-epoch' already
	# sorted ascending and discretises them to hours and subtracts the
	# oldest from them to create 0-based hours since the oldest record:
	Statistics::Covid::Utils::discretise_increasing_sequence_of_seconds(
		\@copy, # in-place modification
		3600 # seconds->hours
	);
	# the result is in this new entry in the dataframe
	$df->{$_}->{'datetimeHoursSinceOldest'} = {'data' => \@copy};
}
print "Here is the dataframe:\n".pp($df)."\n";

# Let's plot the dataframe
$ret = Statistics::Covid::Analysis::Plot::Simple::plot({
	'dataframe' => $df,
	'GroupBy' => ['admin0'],
	'min-points' => 1,
	'X' => 'datetimeUnixEpoch',
	'Y' => 'confirmed',
	'outfile' => 'plot1.png',
});
print "Plot in file 'plot1.png'\n";

# now let's fit the data to a model,
# which can be 'exponential-fit',
# 'polynomial-fit' of degree N (the max power of x)
# or any ad-hoc equation in 'x' with as many parameters to optimise.
# Remember: the number of parameters represents degrees of freedom
# and in order to get some meaningful estimation the number of data
# points must be enough! Else one either gets a very bad model or
# crashes the fitter (which is provided by Algorithm::CurveFit)
# and the ad-hoc equations adhere to Math::Symbolic notation
# the most important is raising to a power is ^ (and not Perl's **)

$models = Statistics::Covid::Analysis::Model::Simple::fit({
	'dataframe' => $df,
	'X' => 'datetimeHoursSinceOldest',
	'Y' => 'confirmed',
	'exponential-fit' => 1,
}) or die "failed to fit";
# the result is a hashtable-ref keyed on the group-by items
# in this case only 'Cyprus', otherwise we would have as many models
# as the group-by distinct items
# the values of the returned hashtable-ref is a Model object
# which holds the equation fitting the data with the model we specified
# e.g. it was an 'exponential-fit'
print "Here is the result of the fit:\n".pp($models)."\n";

die "failed to save model to file" unless $models->{'Madagascar'}->toFile('model1.txt');
print "Model saved to file 'model1.txt'.\n";

# now let's incorporate the fit's data into our existing dataframe
# and plot both actual and fitted data.
# Fitted data does not yet exist, only a fitted function,
# we need to evaluate that function at our time-points in order
# to get a value out - the 'fitted data'.
my @fitted_data;
for my $atime_value (@{$df->{'Madagascar'}->{'datetimeHoursSinceOldest'}->{'data'}}){
	# it is worth checking if values make sense
	push @fitted_data, $models->{'Madagascar'}->evaluate($atime_value);
}
# and put it into the dataframe too!
# in the DF each entry (e.g. 'datetimeHoursSinceOldest' or 'confirmed')
# has a 'data' section which is the array of values for that variable.
# It can also have a 'fitted-XYZ' section for each fitted data where
# XYZ is an ad-hoc name of the fitter, user specified, e.g. 'exponential-fit-good'
# the plotter will know to plot confirmed actual and fitted cols together
$df->{'Madagascar'}->{'confirmed'}->{'fitted-exponential-fit'} = \@fitted_data;

print "Here is the dataframe with the fitted-values incorporated:\n".pp($df)."\n";

# and plot the data in the dataframe
# it will plot 'confirmed' and also it knows to look for 'fitted-confirmed' too
$ret = Statistics::Covid::Analysis::Plot::Simple::plot({
	'dataframe' => $df,
	'GroupBy' => ['admin0'],
	'min-points' => 1,
	'X' => 'datetimeUnixEpoch',
	'Y' => 'confirmed',
	'outfile' => 'plot2.png',
});
print "Plot is in file 'plot2.png', it contains 2 curves for actual and fitted data.\n";

#################
# PART 2 : Select, fit and plot data from many countries
#################

$objs = $covid->select_datums_from_db_time_ascending({
	'conditions' => {
	      # admin0=country-name, admin4=a neighbourhood
	      # also there is the 'datasource' (the provider of data, e.g. World::JHU)
	      # and type which is 'admin0' for country-totals, 'admin1' for state-totals
	      # for example UK has type='admin0' record (for the whole country)
	      # and type='amdin1' records for all local authorities
	      'admin0' => ['Italy', 'Belgium', 'Spain'],
	},
});
die "select_datums_from_db_time_ascending() has failed" unless defined $objs;

# convert datum objects (DO) to a dataframe
# a DO holds data for 1 single point in time.
# an array of DO is just that.
# a dataframe is where the array of DO is converted
# to arrays of values for each quantity (see 'content' below)
# we are interested in.
# At the end we will have all time in one array (named 'datetimeUnixEpoch')
# all confirmed number of cases in another array and so on.
# that makes it easier to plot and pass this data onto 3rd-party graphers.
# just arrays of values.
# This dataframe-building utility can optionally group data given a number
# of other properties. For example the country name 'admin0'.
$df = Statistics::Covid::Utils::datums2dataframe({
	'datum-objs' => $objs,
	'groupby' => ['admin0'],
	'content' => ['datetimeUnixEpoch', 'confirmed'],
	#'content' => ['datetimeUnixEpoch', 'confirmed', 'recovered', 'terminal'],
});
# our X-axis or independent variable is time.
# Measured in seconds since the dawn of Unix (thank god for that)
# However these are large numbers and I prefer to convert to hours since the
# oldest record in our dataframe, this is how to do this:
for(sort keys %$df){
	# this is our original seconds array:
	my @copy = @{$df->{$_}->{'datetimeUnixEpoch'}->{'data'}};
	# this takes an array of 'seconds-since-unix-epoch' already
	# sorted ascending and discretises them to hours and subtracts the
	# oldest from them to create 0-based hours since the oldest record:
	Statistics::Covid::Utils::discretise_increasing_sequence_of_seconds(
		\@copy, # in-place modification
		3600 # seconds->hours
	);
	# the result is in this new entry in the dataframe
	$df->{$_}->{'datetimeHoursSinceOldest'} = {'data' => \@copy};
}
print "Here is the dataframe:\n".pp($df)."\n";

# Let's plot the dataframe
$ret = Statistics::Covid::Analysis::Plot::Simple::plot({
	'dataframe' => $df,
	'GroupBy' => ['admin0'],
	'min-points' => 1,
	'X' => 'datetimeUnixEpoch',
	'Y' => 'confirmed',
	'outfile' => 'plot3.png',
});
print "Plot in file 'plot3.png'\n";

# now let's fit the data to a model,
# which can be 'exponential-fit',
# 'polynomial-fit' of degree N (the max power of x)
# or any ad-hoc equation in 'x' with as many parameters to optimise.
# Remember: the number of parameters represents degrees of freedom
# and in order to get some meaningful estimation the number of data
# points must be enough! Else one either gets a very bad model or
# crashes the fitter (which is provided by Algorithm::CurveFit)
# and the ad-hoc equations adhere to Math::Symbolic notation
# the most important is raising to a power is ^ (and not Perl's **)

$models = Statistics::Covid::Analysis::Model::Simple::fit({
	'dataframe' => $df,
	'X' => 'datetimeHoursSinceOldest',
	'Y' => 'confirmed',
	'exponential-fit' => 1,
}) or die "failed to fit";
# the result is a hashtable-ref keyed on the group-by items
# in this case only 'Cyprus', otherwise we would have as many models
# as the group-by distinct items
# the values of the returned hashtable-ref is a Model object
# which holds the equation fitting the data with the model we specified
# e.g. it was an 'exponential-fit'
print "Here is the result of the fit:\n".pp($models)."\n";

for my $admin0 (sort keys %$models){
	my $outfile = "'model_$admin0.txt";
	die "failed to save model to file" unless $models->{$admin0}->toFile($outfile);
	print "Model saved to file '$outfile'.\n";
	# now let's incorporate the fit's data into our existing dataframe
	# and plot both actual and fitted data.
	# Fitted data does not yet exist, only a fitted function,
	# we need to evaluate that function at our time-points in order
	# to get a value out - the 'fitted data'.
	my @fitted_data;
	for my $atime_value (@{$df->{$admin0}->{'datetimeHoursSinceOldest'}->{'data'}}){
		# it is worth checking if values make sense
		push @fitted_data, $models->{$admin0}->evaluate($atime_value);
	}
	# and put it into the dataframe too!
	# in the DF each entry (e.g. 'datetimeHoursSinceOldest' or 'confirmed')
	# has a 'data' section which is the array of values for that variable.
	# It can also have a 'fitted-XYZ' section for each fitted data where
	# XYZ is an ad-hoc name of the fitter, user specified, e.g. 'exponential-fit-good'
	# the plotter will know to plot confirmed actual and fitted cols together
	$df->{$admin0}->{'confirmed'}->{'fitted-exponential-fit'} = \@fitted_data;
}
print "Here is the dataframe with the fitted-values incorporated:\n".pp($df)."\n";

# and plot the data in the dataframe all on the same plot
# it will plot 'confirmed' and also it knows to look for 'fitted-confirmed' too
$ret = Statistics::Covid::Analysis::Plot::Simple::plot({
	'dataframe' => $df,
	'GroupBy' => ['admin0'], # each admin0(a country) will be a group of its own
	'min-points' => 1,
	'X' => 'datetimeUnixEpoch',
	'Y' => 'confirmed',
	'outfile' => 'plot4.png',
});
print "Plot is in file 'plot4.png', it contains 2 curves for actual and fitted data.\n";

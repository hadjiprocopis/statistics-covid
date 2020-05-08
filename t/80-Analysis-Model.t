#!/usr/bin/perl
use 5.006;

use strict;
use warnings;

our $VERSION = '0.25';

use lib 'blib/lib';

use Statistics::Covid::Analysis::Model;

use Test::More;
use File::Basename;
use File::Spec;
use File::Temp;
use File::Path;

use Data::Dump qw/pp/;

my $dirname = dirname(__FILE__);

my $num_tests = 0;

my $tmpdir = File::Temp::tempdir(CLEANUP=>1);
ok(-d $tmpdir, "output dir exists"); $num_tests++;

my $coeff = {
	'c1' => 1.2,
	'c2' => 2.5,
	'c3' => 1.1
};
my $model = Statistics::Covid::Analysis::Model->new({
	'error' => 1.2,
	'X' => 'abc',
	'Y' => 'xyz',
	'equation' => 'c1 + c2*x + c3*x^2',
	'coefficients' => $coeff,
	'debug' => 0,
});
ok(defined($model), "Statistics::Covid::Analysis::Model->new() called"); $num_tests++;
ok(!defined($model->equation_coderef()), "equation_coderef is lazy"); $num_tests++;

my ($v);
for (keys %$coeff){
	$v = $model->coefficient($_);
	ok(defined($v), "found coefficient '$_'"); $num_tests++;
	is($model->coefficient($_), $v, "compare coefficient '$_'"); $num_tests++;
}
$v = $model->coefficients_names();
ok(defined($v), "coefficients_names() called"); $num_tests++;
is(scalar(@$v), scalar(keys %$coeff), "compared number of coefficients."); $num_tests++;
my $res = $model->evaluate(42);
ok(defined($res), "evaluate() called"); $num_tests++;
ok(abs($res-(1.2+2.5*42+1.1*42*42))<=10E-5, "evaluated result: $res"); $num_tests++;

my $outfile = File::Spec->catdir($tmpdir, "model.json");
ok($model->toFile($outfile), "save to file $outfile"); $num_tests++;
ok(-f $outfile, "outfile exists"); $num_tests++;
ok(-s $outfile, "outfile is not empty"); $num_tests++;

my $inobj = Statistics::Covid::Analysis::Model::fromFile($outfile);
ok(defined $inobj, "Statistics::Covid::Analysis::Model::fromFile() called"); $num_tests++;

my $injsonstr = Statistics::Covid::Utils::slurp_localfile($outfile);
ok(defined($injsonstr), "read JSON from file '$outfile'."); $num_tests++;
my $obj2 = Statistics::Covid::Analysis::Model::fromJSON($injsonstr);
ok(defined($obj2), "create Model object from JSON string."); $num_tests++;

ok($model->equals($obj2), "compare original model and fromJSON()."); $num_tests++;
ok($inobj->equals($obj2), "compare object fromFile() and fromJSON()."); $num_tests++;

done_testing($num_tests);


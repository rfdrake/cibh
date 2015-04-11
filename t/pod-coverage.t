#!perl -T

# needed for Pod::Coverage or CIBH::Config will die with no config
$ENV{'CIBHRC'}='dot.cibhrc.sample';
push(@INC, '.'); # needed because for some reason it can't find dot.cibhrc.sample without this

use Test::More;
eval "use Test::Pod::Coverage 1.04";
plan skip_all => "Test::Pod::Coverage 1.04 required for testing POD coverage" if $@;
all_pod_coverage_ok();

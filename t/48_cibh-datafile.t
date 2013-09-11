use Test::More tests => 2;
use Test::AutoLoader;

# 1. Can we load CIBH::Datafile
use_ok('CIBH::Datafile');
# 2.
autoload_ok('CIBH::Datafile');


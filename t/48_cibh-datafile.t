use Test::More tests => 2;
use Test::AutoLoader;

# 1. Can we load CIBH::Datafile
use_ok('CIBH::Datafile');
# 2. only works on prove -b and you have blib dir with autosplit run
autoload_ok('CIBH::Datafile');


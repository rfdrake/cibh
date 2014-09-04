use Test::More tests => 2;

# this only works if you start your tests from the root of the cibh tree, but
# that is the only way they apparently work anyway, if you're running the
# test commands, like "prove -lv t/*.t"
$ENV{'CIBHRC'}='dot.cibhrc.sample';

# 1. does the module load
use_ok ('CIBH::Config', '$default_options');

$default_options if 0; # prevent used only once warning
# 2. does $default_options{user} == 'pwhiting'
ok($default_options->{'user'} eq 'pwhiting', 'Check if user==pwhiting to see if cibhrc config loads properly');


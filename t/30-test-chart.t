use Test::More;
use Test::Mojo;

$ENV{'CIBHRC'}='t/data/datafile.cibhrc';

# Include application
use FindBin;
require "$FindBin::Bin/../cgi-bin/chart";

my $t = Test::Mojo->new;
$t->get_ok('/')->status_is(501)->content_like(qr/naughty/);

done_testing();

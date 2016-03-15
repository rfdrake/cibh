use Test::More;
use Test::Mojo;

# Include application
use FindBin;
require "$FindBin::Bin/../cgi-bin/new_chart";

my $t = Test::Mojo->new;
$t->get_ok('/')->status_is(501)->content_like(qr/naughty/);

done_testing();

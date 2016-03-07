use strict;
use warnings;
use Test::Most tests => 3;
use File::Temp;
use CIBH::DS::Datafile;

my $ds = CIBH::DS::Datafile->new();

warning_like { $ds->File('hello&') }
    qr/BOGUS filename:/, 'invalid filename return warning';
warning_like { $ds->File('/unlikely_file_that_wont_exist_but_passes_the_first_check/dot/com/etx') }
    qr/file not available:/, 'Non-existant file return file not available';

# now let's create a real file and test it
my $tmp = File::Temp->new( UNLINK => 0 );
syswrite $tmp, "d" x 30;  # syswrite so it's unbuffered and writes immediately
is($ds->File($tmp)->{filesize}, 30, 'Do we get the right size on our test file?');

done_testing();

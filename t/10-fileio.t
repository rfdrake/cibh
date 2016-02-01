use Test::More;

use CIBH::File;
use File::Temp;
use IO::All;

my $output = "test" . rand 32;
my $outfile = File::Temp->new( UNLINK => 0 )->filename;

CIBH::File::overwrite($outfile, $output);
chmod(0644, $outfile);

is(io->file($outfile)->slurp, $output, 'Does overwrite overwrite the file?');
unlink($outfile);
done_testing();

use Test::More;

use CIBH::File;
use File::Temp;
use IO::All;

my $output = "test" . rand 32;
my $outfile = File::Temp->new( UNLINK => 0 )->filename;
my $outfile2 = File::Temp->new->filename;

CIBH::File::overwrite($outfile, $output);
CIBH::File::overwrite($outfile2, $output);
chmod(0644, $outfile);

is(io->file($outfile)->slurp, $output, 'overwrite overwrote the file');
is(io->file($outfile2)->slurp, $output, 'overwrite work on new dest file');

my ($size,$atime,$mtime,$ctime)=(stat $outfile)[7,8,9,10];

my $f = CIBH::File->new( $outfile );

is($f->atime, $atime, 'atime correct?');
is($f->ctime, $atime, 'ctime correct?');
is($f->mtime, $atime, 'mtime correct?');
is($f->size, $size, 'size correct?');

unlink($outfile);
unlink($outfile2);
done_testing();

use Test::More tests => 5;
use Test::Exception;

use CIBH::DS;

dies_ok { CIBH::DS::load_ds(undef) } 'load_ds on undef croaks';
dies_ok { CIBH::DS::load_ds({ name => '___a datastore that probably will never exist___' } ) } 'load_ds on non-existant file croaks';
lives_ok { CIBH::DS::load_ds( { name => 'Datafile' }) } 'load_ds on Datafile (default DS) works';

my $ds = CIBH::DS::load_ds({ name => 'Datafile' });
is($ds,'CIBH::DS::Datafile','load_ds return the namespace of the loaded module?');
is(ref($ds->new()), 'CIBH::DS::Datafile', 'Can we use the $ds namespace to access the module?');

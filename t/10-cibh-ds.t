use Test::More tests => 3;
use Test::Exception;

use CIBH::DS;

dies_ok { CIBH::DS::load_ds(undef) } 'load_ds on undef file croaks';
dies_ok { CIBH::DS::load_ds('___a datastore that probably will never exist___') } 'load_ds on non-existant file croaks';
lives_ok { CIBH::DS::load_ds('Datafile') } 'load_ds on Datafile (default DS) works';


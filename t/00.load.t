use Test::More tests => 7;
use Test::AutoLoader;

use_ok( 'CIBH' );
use_ok( 'CIBH::Chart');
use_ok( 'CIBH::Datafile');
autoload_ok('CIBH::Datafile');
use_ok( 'CIBH::Dia');
use_ok( 'CIBH::Fig');
use_ok( 'CIBH::Win');

diag( "Testing CIBH $CIBH::VERSION" );

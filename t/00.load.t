use Test::More tests => 13;

# needed to test loading CIBH::Config
$ENV{'CIBHRC'}='dot.cibhrc.sample';

use_ok( 'CIBH' );
use_ok( 'CIBH::Chart' );
use_ok( 'CIBH::Config' );
use_ok( 'CIBH::Fig' );
use_ok( 'CIBH::FileIO' );
use_ok( 'CIBH::Graphviz' );
use_ok( 'CIBH::Logs' );
use_ok( 'CIBH::Win' );
use_ok( 'CIBH::DS' );
use_ok( 'CIBH::DS::Datafile' );
use_ok( 'CIBH::DS::InfluxDB' );
use_ok( 'CIBH::SNMP' );

SKIP: {
    eval { require XML::LibXML };
    skip "XML::LibXML not installed", 1 if $@;
    use_ok( 'CIBH::Dia' );
    ++$tests;
}

diag( "Testing CIBH $CIBH::VERSION" );


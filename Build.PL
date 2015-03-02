use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'CIBH',
    license             => 'gpl2',
    dist_author         => 'Robert Drake <rdrake@cpan.org>',
    dist_version_from   => 'lib/CIBH.pm',
    create_makefile_pl => 'traditional',
    configure_requires => { 'Module::Build' => 0.38 },
    autosplit => [ 'lib/CIBH/Datafile', 'lib/CIBH/Fig', 'lib/CIBH/Win', 'lib/CIBH/Chart' ],
    test_requires => {
        'Test::More' => 0,
        'Test::AutoLoader' => 0,
        'Digest::MD5' => 0,
    },
    recommends => {
        'IO::Uncompress::Gunzip'    => 0,
        'XML::LibXML'               => 0,
        'Math::BigInt::GMP'         => 1.38,
    },
    requires => {
        'version'    => 0,
        'GD'         => 0,
        'SNMP'       => 0,
        'Math::BigInt' => 1.9991,
        'File::Path' => 0,   # core module
        'IO::File'   => 0,   # core module
    },
    add_to_cleanup      => [ 'CIBH-*' ],
);

$builder->create_build_script();

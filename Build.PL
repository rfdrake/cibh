use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'CIBH',
    license             => 'gpl2',
    dist_author         => 'Robert Drake <rdrake@direcpath.com>',
    dist_version_from   => 'lib/CIBH.pm',
    create_makefile_pl => 'traditional',
    configure_requires => { 'Module::Build' => 0.38 },
    autosplit => [ 'lib/CIBH/Datafile', 'lib/CIBH/Fig', 'lib/CIBH/Win', 'lib/CIBH/Chart' ],
    test_requires => {
        'Test::More' => 0,
        'Test::AutoLoader' => 0,
    },
    requires => {
        'version'    => 0,
        'GD'         => 0,
        'SNMP'       => 0,
    },
    add_to_cleanup      => [ 'CIBH-*' ],
);

$builder->create_build_script();

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
    requires => {
        'Test::More' => 0,
        'version'    => 0,
        'GD'         => 0,
        'SNMP'       => 0,
    },
    add_to_cleanup      => [ 'CIBH-*' ],
);

$builder->create_build_script();

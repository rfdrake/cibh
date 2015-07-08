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
    test_requires => {
        'Test::More' => 0,
        'Digest::MD5' => 0,
    },
    recommends => {
        'IO::Uncompress::Gunzip'    => 0,      # dia
        'XML::LibXML'               => 0,      # dia
        'Math::BigInt::GMP'         => 1.37,   # faster 64bit math
        'Mojolicious::Lite'         => 0,      # replacing CGI in some scripts
    },
    requires => {
        'version'    => 0,
        'GD'         => 0,
        'SNMP'       => 0,
        'Math::BigInt' => 1.9991,
        'File::Temp' => 0,
        'File::Path' => 0,   # core module
        'File::Basename' => 0, # core module
        'File::Copy' => 0,   # core module
        'IO::File'   => 0,   # core module
        'CGI'        => 0,   # core module (for now)
        'Carp'       => 0,   # core module
        'Getopt::Long' => 0, # core module
        'Getopt::Std' => 0,  # core module
        'File::Spec' => 0,   # core module
        'POSIX'      => 0,   # core module
        'Socket'     => 0,   # core module
        'List::Util' => 0,   # core module
        'Time::Local' => 0,  # core module
        'Cwd'        => 0,   # core module
        'Data::Dumper' => 0, # core module
        'File::Basename' => 0, # core module
    },
    add_to_cleanup      => [ 'CIBH-*' ],
);

$builder->create_build_script();

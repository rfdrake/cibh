use inc::Module::Install;

name           'CIBH';
all_from       'lib/CIBH.pm';

test_requires q(Test::Most) => 0;
test_requires q(Test::Stream) => 0;
test_requires q(Test::Mock::Net::SNMP) => 0;
test_requires q(Digest::MD5) => 0;
test_requires q(IO::All) => 0;
recommends 'InfluxDB' => 0;  # CIBH::DS::InfluxDB

requires 'Mojolicious::Lite' => 0; # replacing CGI in some scripts
requires 'GD'         => 0;
requires 'SNMP::OID::Translate' => 0.0002;
requires 'Net::SNMP'  => 0;
requires 'AnyEvent::SNMP' => 0;
requires 'Math::BigInt' => 1.90; # require something from 2010 or newer
recommends 'Math::BigInt::GMP' => 1.32; # faster 64bit math
requires 'File::Temp' => 0;
requires 'File::Path' => 0;   # core module
requires 'File::Basename' => 0; # core module
requires 'File::Copy' => 0;   # core module
requires 'IO::File'   => 0;   # core module
requires 'CGI'        => 0;   # core module (for now)
requires 'Carp'       => 0;   # core module
requires 'Getopt::Long' => 0; # core module
requires 'Getopt::Std' => 0;  # core module
requires 'File::Spec' => 0;   # core module
requires 'POSIX'      => 0;   # core module
requires 'List::Util' => 0;   # core module
requires 'Time::Local' => 0;  # core module
requires 'Cwd'        => 0;   # core module
requires 'Data::Dumper' => 0; # core module
requires 'Scalar::Util' => 0; # core module
requires 'Module::Runtime' => 0;
requires 'Module::Load' => '0.20'; # 0.20 required for trailing :: to fix undef test

requires_external_bin 'dot';  # graphviz dot command

bugtracker q(https://github.com/rfdrake/cibh/issues);
homepage q(http://search.cpan.org/dist/cibh);
repository q(git://github.com/rfdrake/cibh.git);
license 'perl';

auto_install;
WriteAll;


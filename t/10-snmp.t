use strict;
use warnings;
use Test::Stream -V1;

use CIBH::SNMP qw (translate);
use Test::Mock::Net::SNMP;

my $mock_snmp = Test::Mock::Net::SNMP->new();
my $iftable_tags = [ 'ifDescr','ifSpeed','ifHighSpeed','ifAdminStatus', 'ifAlias' ];

my $output = [
            '.1.3.6.1.2.1.2.2.1.2',
            '.1.3.6.1.2.1.2.2.1.5',
            '.1.3.6.1.2.1.31.1.1.1.15',
            '.1.3.6.1.2.1.2.2.1.7',
            '.1.3.6.1.2.1.31.1.1.1.18'
          ];

my $snmp = CIBH::SNMP->new( hostname => 'localhost', community => 'public');

is(translate($iftable_tags), $output, 'Does an arrayref work for translate?');
is(translate(@$iftable_tags), $output, 'Does an array work for translate?');
# need to use regex because while testing it returns Test::Mock::Net::SNMP
ok(ref($snmp) =~ /Net::SNMP|T::MO::E::a/, 'Does CIBH::SNMP->new return a Net::SNMP object?');
done_testing();

use Test::More tests => 5;

use CIBH::Logs;

my $files = [ qw ( bb1-test.eth0.in bb1-test.eth0.out gw1-test.eth0.in gw1-test.eth0.out ) ];
my $logs = new_ok('CIBH::Logs');

$logs->{logs}->{usage}->{'bb1-test.eth0.in'}->{usage}=.3333;
$logs->{logs}->{usage}->{'bb1-test.eth0.out'}->{usage}=.2423;
$logs->{logs}->{usage}->{'gw1-test.eth0.in'}->{usage}=.2411;
$logs->{logs}->{usage}->{'gw1-test.eth0.out'}->{usage}=.3323;

# not sure about this one yet..
$logs->{logs}->{aliases}->{'bb1-test--gw1-test'};

is($logs->GetUtilization($files), '33.33', 'Normal utilization should be 33');
is($logs->GetUtilization($files, usemin => 1), '24.11', 'Usemin = 24');
is($logs->GetUtilization($files, filename => 'bb1-test', dir => 'in'), '33.33', 'Inbound direction test');
is($logs->GetUtilization($files, filename => 'bb1-test', dir => 'out'), '24.23', 'Outbound direction test');

use strict;
use warnings;
#use Test::Stream qw /Subtest/;
#use Test::Stream -V1;
use Test::Most;


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

my $queue_output = { map { $_ => 10 } @$output };
$mock_snmp->set_varbindlist( [ $queue_output, $queue_output, $queue_output, $queue_output ] );

is_deeply(translate($iftable_tags), $output, 'Does an arrayref work for translate?');
is_deeply(translate(@$iftable_tags), $output, 'Does an array work for translate?');

subtest normal => sub {
    my $snmp = CIBH::SNMP->new( hostname => 'localhost', community => 'public');

    is(ref($snmp), 'CIBH::SNMP', 'Does CIBH::SNMP return an object');
    # need to use regex because while testing it returns Test::Mock::Net::SNMP
    ok(ref($snmp->{session}) =~ /Net::SNMP|T::MO::E::a/, 'Does CIBH::SNMP->new return a Net::SNMP object?');

    my $cb = sub {
        is_deeply(shift->var_bind_list, $queue_output, 'callback for get_request has correct values?');
    };

    my $cb2 = sub {
        is_deeply(shift->var_bind_list, $queue_output, 'callback for get_entries has correct values?');
    };

    $snmp->queue({ -varbindlist => $output, -callback => $cb });
    $snmp->queue({ -columns => $output, -callback => $cb2 });
    $snmp->wait;
    done_testing();
};


subtest anyevent_cv => sub {
    use AE;
    my $cv = AE::cv;

    my $cb = sub {
        is_deeply(shift->var_bind_list, $queue_output, 'callback for get_request+cv has correct values?');
        $cv->end;
    };

    my $cb2 = sub {
        is_deeply(shift->var_bind_list, $queue_output, 'callback for get_entries+cv has correct values?');
        $cv->end;
    };

    my $snmp = CIBH::SNMP->new( hostname => 'localhost', community => 'public', cv => $cv);
    $snmp->queue({ -varbindlist => $output, -callback => $cb, cv => $cv });
    $snmp->queue({ -columns => $output, -callback => $cb2, cv => $cv });
    $cv->wait;
    done_testing();
};

done_testing();

use strict;
use warnings;
use Test::More tests => 3;
use File::Temp;
use Math::BigInt try => 'GMP';

# CounterAppend uses time() and we can't get a deterministic output unless we
# overload it.  This overload needs to happen before use CIBH::DS::Datafile;
no warnings 'redefine';
my $time2 = 1425309835;
BEGIN {
    *CORE::GLOBAL::time = sub () {
        $time2;
    };
}

use CIBH::DS::Datafile qw ( $FORMAT $RECORDSIZE );

my $time1 = 1425309535;
my $spike = 10**11;

sub write_header {
    my $value1 = shift;
    my $tmpf = File::Temp->new();
    $tmpf->syswrite(pack($FORMAT . $FORMAT, $time1, $value1, 0, $value1), $RECORDSIZE*2);
    return $tmpf;
}

subtest 'test a spike value' => sub {
    my $value1 = Math::BigInt->new('2_200_281_748_332');
    my $value2 = Math::BigInt->new('4_611_686_018_427_387_904');
    my $tmpf = write_header($value1);

    my $value = CIBH::DS::Datafile::CounterAppend($tmpf->filename, $value2, $spike, Math::BigInt->new(2)->bpow(64) );
    is($value, 0, 'Test spiked value should return 0bps');
    $time2 = 1425309835+300;
    $value = CIBH::DS::Datafile::CounterAppend($tmpf->filename, $value2+250_000, $spike, Math::BigInt->new(2)->bpow(64) );
    is($value, 833, 'Next write after spike with non-spike value should be 833bps');

    # test OO interface..
    my $data = CIBH::DS::Datafile->new(filename=>$tmpf->filename)->GetValues($time1-1, $time2+1);
    use Data::Dumper; warn Dumper($data);

    # change time2 back to global value before leaving subtest
    $time2 = 1425309835;
    done_testing();
};


subtest 'test a non-spike value' => sub {
    my $value1 = Math::BigInt->new('2_200_281_748_332');
    my $value2 = Math::BigInt->new('2_500_281_748_332');  # 300_000_000_000 higher than value1 (1Gbps)
    my $tmpf = write_header($value1);
    $tmpf->syswrite(pack($FORMAT . $FORMAT, $time1, $value1, 0, $value1), $RECORDSIZE*2);
    my $value = CIBH::DS::Datafile::CounterAppend($tmpf->filename, $value2, $spike, Math::BigInt->new(2)->bpow(64) );
    is($value, 1_000_000_000, 'NON-spike test, value should be 1Gbps');
    done_testing();
};

subtest 'test a wrap' => sub {
    my $value1 = Math::BigInt->new(2)->bpow(64);
    my $value2 = Math::BigInt->new('3_900_000_000');  # value2 is lower than value1, wrap happens
    my $tmpf = write_header($value1);

    my $value = CIBH::DS::Datafile::CounterAppend($tmpf->filename, $value2, $spike, Math::BigInt->new(2)->bpow(64) );
    is($value, 13_000_000, 'Normal wrap, value should be 13Mbps');
    done_testing();
};

done_testing();


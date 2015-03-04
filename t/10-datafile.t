use strict;
use warnings;
use Test::More tests => 4;
use File::Temp;
use Math::BigInt try => 'GMP';

# CounterAppend uses time() and we can't get a deterministic output unless we
# overload it.  This overload needs to happen before use CIBH::Datafile;
no warnings 'redefine';
my $time2 = 1425309835;
BEGIN {
    *CORE::GLOBAL::time = sub () {
        $time2;
    };
}

use CIBH::Datafile qw ( $FORMAT $RECORDSIZE );

my $time1 = 1425309535;
my $value1 = Math::BigInt->new('2_200_281_748_332');
my $spike = 10**11;

# test a spike value
{
    my $tmpf = File::Temp->new();
    my $value2 = Math::BigInt->new('4_611_686_018_427_387_904');
    $tmpf->syswrite(pack($FORMAT . $FORMAT, $time1, $value1, 0, $value1), $RECORDSIZE*2);
    my $value = CIBH::Datafile::CounterAppend($tmpf->filename, $value2, $spike, Math::BigInt->new(2)->bpow(64) );
    is($value, 0, 'Test spiked value should return 0bps');
    $time2 = 1425309835+300;
    $value = CIBH::Datafile::CounterAppend($tmpf->filename, $value2+250_000, $spike, Math::BigInt->new(2)->bpow(64) );
    is($value, 833, 'Next poll after spike with non-spike value should be 833bps');
    $time2 = 1425309835;
}


# test a non-spike value
{
    my $tmpf = File::Temp->new();
    my $value2 = Math::BigInt->new('2_200_281_998_332');  # 250_000 higher than value1
    $tmpf->syswrite(pack($FORMAT . $FORMAT, $time1, $value1, 0, $value1), $RECORDSIZE*2);
    my $value = CIBH::Datafile::CounterAppend($tmpf->filename, $value2, $spike, Math::BigInt->new(2)->bpow(64) );
    is($value, 833, 'Test non-spiked value should return 833bps');
}

# test a wrap
{
    my $tmpf = File::Temp->new();
    $value1 = Math::BigInt->new(2)->bpow(64);
    my $value2 = Math::BigInt->new('250000');  # value2 is lower than value1, wrap happens
    $tmpf->syswrite(pack($FORMAT . $FORMAT, $time1, $value1, 0, $value1), $RECORDSIZE*2);
    my $value = CIBH::Datafile::CounterAppend($tmpf->filename, $value2, $spike, Math::BigInt->new(2)->bpow(64) );
    is($value, 833, 'Normal wrap should return 833bps');
}



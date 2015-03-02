use strict;
use warnings;
use Test::More tests => 3;
use File::Temp;

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
my $value1 = 2_200_281_748_332;
my $spike = 10**11;

# test a spike value
{
    my $tmpf = File::Temp->new();
    my $value2 = 4_611_686_018_427_387_904;
    $tmpf->syswrite(pack($FORMAT . $FORMAT, $time1, $value1, 0, $value1), $RECORDSIZE*2);
    my $value = CIBH::Datafile::CounterAppend($tmpf->filename, $value2, $spike, 2**64);
    is($value, 0, 'Test spiked value should return 0bps');
    $time2 = 1425309835+300;
    $value = CIBH::Datafile::CounterAppend($tmpf->filename, $value2+250_000, $spike, 2**64);
    is($value, 833, 'Next poll after spike with non-spike value should be 833bps');
    $time2 = 1425309835;
}


# test a non-spike value
{
    my $tmpf = File::Temp->new();
    my $value2 = 2_200_281_998_332;  # 250_000 higher than value1
    $tmpf->syswrite(pack($FORMAT . $FORMAT, $time1, $value1, 0, $value1), $RECORDSIZE*2);
    my $value = CIBH::Datafile::CounterAppend($tmpf->filename, $value2, $spike, 2**64);
    is($value, 833, 'Test non-spiked value should return 833bps');
}

# test a wrap at 2**64 to zero or something

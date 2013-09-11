use Test::More tests => 6;
# 1. 
{
    my $x = 2_200_281_748_332;
    ok ( $x == 2_200_281_748_332, 'Can we assign 64bit without bigint?' );
}

# 2. 
{
    my $x = 2**64;
    ok ( $x == 18_446_744_073_709_551_616, 'Can we assign max 64bit properly without bigint?' );
}

# 3.
{
    my $x = 2**64-1;
    ok ( $x == 18_446_744_073_709_551_615, 'Can we assign 2**64-1 properly without bigint?' );
}

# will be used for a couple of the next tests
sub packtest {
    my $x = shift;
    my $msg = shift;
    my $time = time();
    my $packed = pack("NQ", $time, $x);
    my ($time2, $x2) = unpack("NQ", $packed);
    ok (( $x == $x2 and $time == $time2), $msg);
}
# 4.
packtest( 2**32-28, 'Does packing a 32bit integer into a 64 bit space work?' );
    
# 5.
packtest( 2**64-1, 'Does packing a 64bit integer into a 64bit space work?' );

# 6.
{
    my $sample1 = 2**64-355000;
    my $sample2 = 2**64-123456;
    my $speed = 1000 * 1_000_000; # ifHighSpeed.  1Gbps interface
    ok ( (($sample2-$sample1)/$speed)*100 == 0.0231424, 'Testing usage calculation for 64bit values.' );
}
    

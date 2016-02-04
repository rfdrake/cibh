use strict;
use warnings;
use Test::Most tests => 5;
use File::Temp;
use Math::BigInt try => 'GMP,Pari';


use CIBH::DS::Datafile qw ( $FORMAT $RECORDSIZE );

my $time1 = 1425309535;
my $time2 = $time1+300;
my $spike = 10**11;

my $args = {
    spikekiller => $spike,
    time => $time2
};

sub write_header {
    my $value1 = shift;
    my $tmpf = File::Temp->new();
    # the initial data for the file should be time1, value1, zero, value1.
    # the reason for this is that The first entry is time1, value1.  The last
    # record of a counterappend file is a record with a zero timestamp and the
    # current counter value.

    $tmpf->syswrite(pack($FORMAT . $FORMAT, $time1, $value1, 0, $value1), $RECORDSIZE*2);
    return $tmpf;
}


# even with testing code I'm not positive I've got this right...
subtest 'test a spike value' => sub {
    my $value1 = Math::BigInt->new('2_200_281_748_332');
    my $value2 = Math::BigInt->new('4_611_686_018_427_387_904');
    my $tmpf = write_header($value1);

    $args->{value}=$value2;
    $args->{file}=$tmpf->filename;
    my $value = CIBH::DS::Datafile::CounterAppend( $args );
    is($value, 0, 'Test spiked value should return 0bps');
    $args->{time} += 300;
    $args->{value} += 250_000;
    $value = CIBH::DS::Datafile::CounterAppend( $args );
    is($value, 833, 'Next write after spike with non-spike value should be 833bps');

    # test OO interface..
    my $data = CIBH::DS::Datafile->new(filename=>$tmpf->filename)->GetValues($time1-1, $args->{time}+1);
    # currently I don't think this data looks right, but I need to examine the
    # code to decide if I'm right or wrong.
    is_deeply( $data, [ { '1425310135' => 833 } ], 'Does our stored data look correct when we read it back?' );

    done_testing();
};


subtest 'test a non-spike value' => sub {
    my $value1 = Math::BigInt->new('2_200_281_748_332');
    my $value2 = Math::BigInt->new('2_500_281_748_332');  # 300_000_000_000 higher than value1 (1Gbps)
    my $tmpf = write_header($value1);
    #$tmpf->syswrite(pack($FORMAT . $FORMAT, $time1, $value1, 0, $value1), $RECORDSIZE*2);
    $args->{file}=$tmpf->filename;
    $args->{value}=$value2;
    $args->{time}=$time2;
    my $value = CIBH::DS::Datafile::CounterAppend( $args );
    is($value, 1_000_000_000, 'NON-spike test, value should be 1Gbps');
    done_testing();
};

subtest 'test a wrap' => sub {
    my $value1 = Math::BigInt->new(2)->bpow(64);
    my $value2 = Math::BigInt->new('3_900_000_000');  # value2 is lower than value1, wrap happens
    my $tmpf = write_header($value1);
    $args->{file}=$tmpf->filename;
    $args->{value}=$value2;
    $args->{time}=$time2;

    my $value = CIBH::DS::Datafile::CounterAppend( $args );
    is($value, 13_000_000, 'Normal wrap, value should be 13Mbps');
    done_testing();
};

# octetsappend multiplies the numbers by 8 before sending them, so we need to
# know our values will be affected by this.
subtest 'octetsappend' => sub {
    my $tmpf = File::Temp->new();
    $args->{file}=$tmpf->filename;
    $args->{value}=80_000;
    $args->{time}=$time1;
    CIBH::DS::Datafile::OctetsAppend( $args );  # this should write the headers/first sample

    $args->{value}=128_000;
    $args->{time}=$time2;
    my $value = CIBH::DS::Datafile::OctetsAppend( $args );
    is($value, 1280, 'OctetsAppend test');

    $args->{value}=256_000;
    $args->{time}+=300;
    # since we aren't near a counter wrap, it should be safe to mix 64 and 32.
    $value = CIBH::DS::Datafile::OctetsAppend64( $args );
    is($value, 3413, 'OctetsAppend64 test');
    done_testing();
};

subtest 'nonexistent file' => sub {
    my $tmpf = File::Temp->new();
    $args->{file}=$tmpf->filename;
    close($tmpf); #
    unlink($args->{file});
    $args->{value}=80_000;
    warning_like { CIBH::DS::Datafile::OctetsAppend( $args ) }
        qr#Can't open #, 'non existent file gives warning';
    done_testing();
};

done_testing();

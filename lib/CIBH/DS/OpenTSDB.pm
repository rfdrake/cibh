package CIBH::DS::OpenTSDB;

use strict;
use warnings;
use Math::BigInt try => 'GMP';
use CIBH::Config qw / $default_options /;
use OpenTSDB;
use v5.14;

=head1 NAME

CIBH::DS::OpenTSDB - CIBH datasource backend for OpenTSDB

=head1 SYNOPSIS

  use CIBH::DS::OpenTSDB;

=head1 DESCRIPTION

=head1 AUTHOR

Robert Drake <rdrake@cpan.org>

=head1 SEE ALSO

CIBH::Win, CIBH::Chart, CIBH::Fig.

=head1 SUBROUTINES

=head2 Store

    my $value = CIBH::DS::OpenTSDB::Store($hash);

This subroutine will open the filename given as the hash->{file}
argument and will store the value passed as the hash->{value} argument
in that file, as text, overwriting whatever was previously in there.
In the event it fails to open the file it will try to make the
directory the file is in and then retry to open the file.

=cut

sub Store {
    my ($hash)=(@_);
    my $value = $hash->{value};

    return $value;
}

=head2 GaugeAppend

    my $value = CIBH::DS::OpenTSDB::GaugeAppend($hash);

This subroutine will open the $hash->{file} and seek to the end, then store a
timestamp and the value passed as $hash->{value}.  On success the value is
returned.

=cut

sub GaugeAppend {
    my ($hash)=(@_);
    my $value = $hash->{value};

    return $value;
}

=head2 OctetsAppend

    my $value = CIBH::DS::OpenTSDB::OctetsAppend($hash);

Wrapper for CIBH::DS::OpenTSDB::CounterAppend for 32 bit values.

=cut

sub OctetsAppend {
    my($hash)=(@_);
    return CounterAppend($hash->{file},$hash->{value},$hash->{spikekiller});
}

=head2 OctetsAppend64

    my $value = CIBH::DS::OpenTSDB::OctetsAppend64($hash);

Wrapper for CIBH::DS::OpenTSDB::CounterAppend for 64 bit values.

=cut

sub OctetsAppend64 {
    my($hash)=(@_);
    state $max64 = Math::BigInt->new(2)->bpow(64);
    return CounterAppend($hash->{file},$hash->{value},$hash->{spikekiller}, $max64);
}

1;

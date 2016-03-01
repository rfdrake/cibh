package CIBH::DS::InfluxDB;

use strict;
use warnings;
use Math::BigInt try => 'GMP';
use Module::Runtime qw ( use_module );
use v5.14;

# static $InfluxDB object created if the module is available and someone has
# called a create method.
my $influxDB;

our $VERSION = '1.00';

=head1 NAME

CIBH::DS::InfluxDB - Perl extension for writing CIBH data to InfluxDB

=head1 SYNOPSIS

  use CIBH::DS::InfluxDB;

=head1 DESCRIPTION

Routines for accessing and storing graph data.  Some of these use scaling and
sampling, which I think should be handled in a "display" module but haven't
figured out where to move them.  I'm leaving them here because they don't hurt
anything.

=head1 AUTHOR

Robert Drake <rdrake@cpan.org>

=head1 SEE ALSO

CIBH::Win, CIBH::Chart, CIBH::Fig.

=head1 SUBROUTINES

=head2 Store

    my $value = CIBH::DS::InfluxDB::Store($hash);

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

    my $value = CIBH::DS::InfluxDB::GaugeAppend($hash);

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

    my $value = CIBH::DS::InfluxDB::OctetsAppend($hash);

Wrapper for CIBH::DS::InfluxDB::CounterAppend for 32 bit values.

=cut

sub OctetsAppend {
    my($hash)=(@_);
    return CounterAppend($hash->{file},$hash->{value},$hash->{spikekiller});
}

=head2 OctetsAppend64

    my $value = CIBH::DS::InfluxDB::OctetsAppend64($hash);

Wrapper for CIBH::DS::InfluxDB::CounterAppend for 64 bit values.

=cut

sub OctetsAppend64 {
    my($hash)=(@_);
    state $max64 = Math::BigInt->new(2)->bpow(64);
    return CounterAppend($hash->{file},$hash->{value},$hash->{spikekiller}, $max64);
}


# This is used to initialize things during module load.  I didn't use import
# because options might need to be passed and we also aren't loading the
# module normally.

sub _ds_init {
    $influxDB = use_module('InfluxDB')->new($_[0]);
}


1;

package CIBH::SNMP;

use strict;
use warnings;
use Carp;
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw( load_snmp_config );

=head1 NAME

CIBH::SNMP - SNMP methods common to CIBH scripts

=head1 SYNOPSIS

   use CIBH::SNMP;

=head1 DESCRIPTION

=head1 AUTHOR

Robert Drake, rdrake@cpan.org

=head1 SUBROUTINES

=head2 load_snmp_config

    my $config = load_snmp_config($host,$opts);

Loads the .snmp.config file.

=cut

sub load_snmp_config {
    my ($host, $opts) = @_;
    $opts->{config} = "$opts->{config_path}/$host.snmp.config";
    warn "Reading $opts->{config}\n" if $opts->{debug};

    # using do here to make sure it runs every time.  Require only runs once
    # per file, so it won't work if you need to load the file multiple times
    # for some reason.
    do $opts->{config} || die "Can't read file $opts->{config} (check permissions)";
}

# this takes a dotted decimal IP address from SNMP and converts it to x.x.x.x
# or xx:xx:xx format depending on ipv4 or ipv6.  This method doesn't need
# large integer libraries for ipv6
sub _convert_address {
    my ($in, $size) = @_;
    return if (!$size || ($size != 16 && $size != 4));

    my $ipv6 = $size == 16 ? 1 : 0;
    my $sep = $ipv6 ? ':' : '.';
    my $modulus = $ipv6 ? 2 : 1;
    my $ip = '';
    for(1..$size) {
        $ip .= sprintf($ipv6 ? "%02x%s" : "%s%s", $in->[$_-1], ($_ % $modulus == 0 && $_ != $size) ? $sep : '');
    }
    return $ip;
}

=head2 parse_prefix

    my ($index, $prefix) = parse_prefix($val);

Parses the output of ipAddressPrefix returning the ifIndex, then the human
readable IPv4 or IPv6 address/cidr.

=cut

sub parse_prefix {
    my $addr = shift;
    return if ($addr eq '.0.0');

    $addr =~ s/^\.1\.3\.6\.1\.2\.1\.4\.32\.1\.5\.//;
    my $in = [split(/\./,$addr)];
    my $index = shift @$in;
    shift @$in;  # throw away unused value
    my $size = shift @$in;
    my $cidr = pop @$in;
    my $ip = _convert_address($in, $size);
    return $index, "$ip/$cidr";
}

=head2 parse_ifindex

    my $address = parse_ifindex($val);

Parses the output of ipAddressIfIndex returning the human readable IPv4 or
IPv6 address.

=cut

sub parse_ifindex {
    my $oid = shift;
    my $in = [split(/\./, $oid)];
    shift @$in;   # throw away unused value
    my $size = shift @$in;
    my $addr = _convert_address($in, $size);

    return $addr;
}

1;

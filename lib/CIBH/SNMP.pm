package CIBH::SNMP;

use strict;
use warnings;
use AE;
use AnyEvent::SNMP;
use Net::SNMP;
use Carp;
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw( load_snmp_config );

=head1 NAME

CIBH::SNMP - Wrapper for Net::SNMP methods common to CIBH scripts

=head1 SYNOPSIS

   use CIBH::SNMP;

=head1 DESCRIPTION

=head1 AUTHOR

Robert Drake, rdrake@cpan.org

=head1 SUBROUTINES

=head2 new

    my $snmp = CIBH::SNMP->new(
                hostname => $host,
                community => $community,
                debug => 1
    );

Creates a new Net::SNMP session.  Returns a CIBH::SNMP object on success, undef on
error.  Carps the error message if session fails and debug is set.

We need to make this work with multiple SNMP versions.

=cut

sub new {
    my $class = shift;
    my %args = @_;

    my ($snmp, $error) = Net::SNMP->session(
                  -hostname    => $args{hostname},
                  -community   => $args{community},
                  -version     =>  2,
                  -nonblocking =>  1,
    );

    if (!defined($snmp)) {
        carp "Error creating SNMP Session for $args{hostname}: $error\n" if $args{debug};
        return;
    }

    return bless {
        session => $snmp,
        debug => $args{debug},
        cv => $args{cv} || AE::cv,
    }, $class;
}

=head2 load_snmp_config

    my $config = load_snmp_config($host,$opts);

Loads the .snmp.config file.  We should probably move this to an SNMPData
module which loads and stores these things.

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

=head2 queue

    $snmp->queue( %args );

Used to run get_entries or get_request and output to a callback function.

=cut

sub queue {
    my ($self, $args) = @_;
    my $snmp = $self->{session};
    my $callback = $args->{'-callback'};
    my $cv = $self->{cv};

    # the outer program is probably not callback aware and needs a wrapper for $cv->end.
    if (!defined($args->{cv})) {
        my $cbwrapper = sub {
            &$callback;
            $cv->end;
        };
        $args->{'-callback'}=$cbwrapper;
    } else {
        $cv = delete $args->{cv};
    }

    $cv->begin;
    if (defined($args->{'-columns'})) {
        $snmp->get_entries( %$args );
    } else {
        $snmp->get_request( %$args );
    }
    if ($snmp->error) {
        warn $snmp->error if $self->{debug};
        $cv->end;
    }
}

# too many ternaries?  You be the judge!
sub _convert_address {
    my $in = shift;
    my $size = shift;
    return if ($size != 16 && $size != 4);

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
    my $unk = shift @$in;
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
    my $unk = shift @$in;
    my $size = shift @$in;
    my $addr = _convert_address($in, $size);

    return $addr;
}


=head2 wait

    $snmp->wait

Wrapper for $cv->wait since the calling program might not load AnyEvent.

=cut

sub wait {
    $_[0]->{cv}->wait;
}

1;

package CIBH::SNMP;

use strict;
use warnings;
use AE;
use AnyEvent::SNMP;
use Net::SNMP;
use SNMP;
use Carp;
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw( load_snmp_config translate );

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

=head2 translate

=cut

sub translate {
    [ map { SNMP::translateObj($_) } ref($_[0]) eq 'ARRAY' ? @{$_[0]} : @_ ];
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

=head2 wait

    $snmp->wait

Wrapper for $cv->wait since the calling program might not load AnyEvent.

=cut

sub wait {
    $_[0]->{cv}->wait;
}

1;

package CIBH::SNMP;

use strict;
use warnings;
use Net::SNMP;
use Carp;

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

Creates a new Net::SNMP session.  Returns the session on success, undef on
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

    # set to avoid this.. I don't know what happens if we exceed 64k bytes, I
    # suspect we would have to check for it and break up our messages which
    # would suck.

    # The message size 1604 exceeds the maxMsgSize 1472 at ./snmp-poll line 157.
    $snmp->max_msg_size(65535);
    return $snmp;
}

1;

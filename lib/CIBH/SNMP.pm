package CIBH::SNMP;

=head1 NAME

CIBH::SNMP - Functions dealing with SNMP

=cut

use strict;
use warnings;
use CIBH::Config qw / $default_options /;
use SNMP;

=head2 new

    my $snmp=CIBH::SNMP->new( $host, $opts );

Creates a new CIBH::SNMP object.

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $host = shift;
    my $opts = shift || {};

    my $self = {
        'host' => $host,
        'opts' => {
            %{$default_options},
            %{$opts},
        },
    };

    $host .= $self->{opts}->{domain} if ($self->{opts}->{domain});
    my $version = $self->{opts}->{snmp_version} || '2';

    warn "No community\n" and return if(not $self->{opts}->{community});


    $self->{session} = SNMP::Session->new(DestHost => $host,
                                          Version=> $version,
                                          Community => $self->{opts}->{community},
                                          UseSprintValue => 1,# might not want this
                                          RetryNoSuch => 1);

    warn "bombed session to $host\n", return if not $self->{session};

    bless($self,$class);
    return $self;
}

=head2 session
    my $session = $self->session;

Getter for SNMP session.

=cut

sub session { $_[0]->{session} }

=head2 query

    my $vars = $snmp->query($oids);

Given a list of oids, this builds an SNMP::VarList and attempts to query them.
It will return the results.

=cut

sub query {
    my $self = shift;
    my $oids = shift;

    my $size=256;
    my $session=$self->session;
    my $vars;

    # limit the size of the SNMP query - the big ones don't return...
    my @tmp; # this can probably be moved in scope
    while(@$oids) {
        $vars=SNMP::VarList->new(@tmp=splice(@$oids,0,$size));
        $session->get($vars);

        if($session->{ErrorStr}){
            if($session->{ErrorStr}=~/Timeout/ and $size>=2) {
                $size=int($size/2);
                unshift(@$oids,@tmp);
                warn "Changed query size to $size for $self->{host}.\n";
            } else {
                warn "Error with snmp get on $self->{host}: " .
                    "$session->{ErrorStr}\n".
                        "Be sure you have connectivity to this host\n" .
                            "and snmp access is allowed from this source.\n";
                return;
            }
        }
    }

    return $vars;
}

=head2 translate

    my $tag = translate($line, $metrics);

Given the line from an an SNMP get and the metrics from the build-snmp-config file, this will match OID
or Object Name to the metric tag defined in the configuration file.

=cut

sub translate {
    my $self = shift;
    my $line = shift;
    my $metrics = shift;

    my $tag = $line->tag;
    my $index='';
    $index = '.'.$line->iid if ($line->iid ne '');
    # append the Index if it exists.
    $tag.=$index;

    if (not defined $metrics->{$tag}) {
        $tag=SNMP::translateObj($line->tag,0);
        $tag.=$index;   # translateObj strips the index again
    }
    $tag=~s/^\.//;  # this almost certainly is bugged.  It should be in the above if or somewhere else.
    if(not defined $metrics->{$tag}) {
        warn "couldn't find OID for $tag\n";
    }
    return $tag;
}

1;

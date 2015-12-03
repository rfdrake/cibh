package CIBH::SNMP;

use strict;
use warnings;
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
1;

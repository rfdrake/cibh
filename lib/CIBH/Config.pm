package CIBH::Config;

=head1 NAME

CIBH::Config - Module for finding and loading CIBH configuration files

=head1 SYNOPSIS

  use CIBH::Config qw/ $default_options /;

=head1 DESCRIPTION

=head1 AUTHOR

Robert Drake, <rdrake@cpan.org>

=head1 SEE ALSO

perl(1) CIBH::Datafile, CIBH::Win, CIBH::Chart.

=cut

use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw();
our @EXPORT_OK = qw ( $default_options );

our $default_options;
# $ENV{CIBHRC} should override all the others. $ENV{HOME}/.cibhrc should be
# last resort.


# we could possibly put this in "sub import {}".  It works how it is, but I
# think it pisses off Test::Pod::Coverage.

my @configs = ( '/etc/cibhrc', '/usr/local/etc/cibhrc', '/opt/cibh/etc/cibhrc' );
unshift(@configs, $ENV{CIBHRC}) if (defined($ENV{CIBHRC}));
push(@configs, "$ENV{HOME}/.cibhrc") if (defined($ENV{HOME}));

foreach my $conf (@configs) {
    if (-r $conf) {
        require $conf;
        $default_options->{'cibhrc_file'}=$conf;
        # only load the first file found
        last;
    }
}

1;

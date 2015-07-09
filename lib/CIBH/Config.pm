package CIBH::Config;

=head1 NAME

CIBH::Config - Module for finding and loading CIBH configuration files

=head1 SYNOPSIS

  use CIBH::Config qw/ $default_options /;

=head1 DESCRIPTION

This checks in various OS specific locations for the main CIBH configuration
file, cibhrc.  You can override all of the preferred choices by setting the
CIBHRC environment variable.  If no configuration file is found anywhere then
it checks $HOME/.cibhrc for historic reasons.

I advise against using $HOME/.cibhrc because the definition of $HOME can
change between the web user and the poller.

Here are the possible locations you might use in order of their preference:

    $CIBHRC
    /etc/cibhrc
    /etc/cibh/cibhrc
    /usr/local/etc/cibhrc
    /opt/cibh/etc/cibhrc
    $HOME/.cibhrc

=head1 AUTHOR

Robert Drake, <rdrake@cpan.org>

=head1 SEE ALSO

perl(1), CIBH::Datafile, CIBH::Win, CIBH::Chart.

=cut

use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw();
our @EXPORT_OK = qw ( $default_options );

our $default_options;

BEGIN {
    # if the option isn't defined in cibhrc then get the default from here
    my $placeholder_options = {
        log_path    => '.',
        config_path => '.',
        data_path   => '.',
        datastore   => "Datafile",
        shades      => 20,
        log_glob    => '*',
    };

    my @configs = ( '/etc/cibhrc', '/etc/cibh/cibhrc', '/usr/local/etc/cibhrc', '/opt/cibh/etc/cibhrc' );
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

    if (!defined($default_options->{'cibhrc_file'})) {
        die << '        NOCIBHRC';

            No CIBHRC file has been found.  Please copy the sample file into one of the
            usable locations and edit it to suit your network.  See perldoc CIBH::Config
            for a list of locations you may choose.

        NOCIBHRC
    }
    $default_options={ %{$placeholder_options}, %{$default_options} };
}

1;

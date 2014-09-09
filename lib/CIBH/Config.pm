package CIBH::Config;

use strict;
use vars qw($VERSION @ISA @EXPORT);

require Exporter;

@ISA = qw(Exporter);
@EXPORT = qw();
our @EXPORT_OK = qw ( $default_options );
our $default_options;

# This should probably be in a BEGIN?

# $ENV{CIBHRC} should override all the others. $ENV{HOME}/.cibhrc should be
# last resort.
my @configs = ( "$ENV{CIBHRC}", "/etc/cibhrc", "/usr/local/etc/cibhrc",
                "/opt/cibh/etc/cibhrc", "$ENV{HOME}/.cibhrc" );

foreach my $conf (@configs) {
    if (-r $conf) {
        require $conf;
        $default_options->{'cibhrc_file'}=$conf;
        # only load the first file found
        last;
    }
}

1;

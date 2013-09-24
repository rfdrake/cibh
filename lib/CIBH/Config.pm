package CIBH::Config;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK $default_options);

require Exporter;

@ISA = qw(Exporter);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw();
@EXPORT_OK = qw ( $default_options );
$VERSION = '1.00';

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

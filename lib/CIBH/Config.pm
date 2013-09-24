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


if (-r "$ENV{CIBHRC}") {
    require "$ENV{CIBHRC}"; ## no critic
} elsif (-r "/etc/cibhrc") {
    require "/etc/cibhrc"; ## no critic
# not recommended because map and chart will need to run as the same user to
# pickup the config file.
} elsif (-r "$ENV{HOME}/.cibhrc") {
    require "$ENV{HOME}/.cibhrc"; ## no critic
}

1;

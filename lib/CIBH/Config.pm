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

perl(1), CIBH::DS::Datafile, CIBH::Win, CIBH::Chart.

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

    # glob expands ~ home variable and doesn't cry if $ENV{HOME} is undef
    my @configs = ( '/etc/cibhrc', '/etc/cibh/cibhrc', '/usr/local/etc/cibhrc', '/opt/cibh/etc/cibhrc', glob '~/.cibhrc' );
    unshift(@configs, $ENV{CIBHRC}) if (defined($ENV{CIBHRC}));

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

=head2 load_snmp_config

    my $config = CIBH::Config::load_snmp_config($host,$opts);

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
    do "$opts->{config}";
}

=head2 save_file

    CIBH::Config::save_file($filename,$data,'variablename',$opts);

Saves variable data to a file using Data::Dumper with indention.

=cut

sub save_file {
    my ($file,$data,$name,$opts) = (@_);
    use Data::Dumper;
    use CIBH::FileIO;
    $Data::Dumper::Indent = 1;
    $Data::Dumper::Deepcopy = 1;

    my $out=Data::Dumper->Dump([$data],[$name]);
    if (!defined $opts->{stdout}) {
        warn "Dumping config to $file\n" if $opts->{debug};
        CIBH::FileIO::overwrite($file,$out);
    } else {
        print $out;
    }
}


1;

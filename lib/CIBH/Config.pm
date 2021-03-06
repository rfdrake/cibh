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
our @EXPORT = ();
our @EXPORT_OK = qw ( $default_options );

our $default_options;

=head2 load_cibhrc

    my $options = CIBH::Config::load_cibhrc($location);

Tries to load the CIBHRC file from the locations listed above.  If need be you
can pass a specific location to override everything.  This is the function
called by the importer.  Returns the $default_options value.

=cut

sub load_cibhrc {
    # if the option isn't defined in cibhrc then get the default from here
    my $placeholder_options = {
        log_path    => '.',
        config_path => '.',
        data_path   => '.',
        datastore   => { name => 'Datafile', options => {} },
        shades      => 20,
        log_glob    => '*',
    };

    no warnings 'uninitialized';  # needed for $ENV{XDG_CONFIG_HOME} and $ENV{HOME}
    my $xdg = $ENV{XDG_CONFIG_HOME} || "$ENV{HOME}/.config/";
    my @configs = ( '/etc/cibhrc',
                    '/etc/cibh/cibhrc',
                    '/usr/local/etc/cibhrc',
                    '/opt/cibh/etc/cibhrc',
                    "$xdg/cibhrc",
                    "$ENV{HOME}/.cibhrc" );

    unshift(@configs, $ENV{CIBHRC}) if (defined($ENV{CIBHRC}));
    unshift(@configs, $_[0]) if (defined($_[0]));

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
    # fix the base_path if they didn't provide one
    ($default_options->{base_path} ||= $default_options->{data_path}) =~ s/\/snmp//;
    $default_options={ %{$placeholder_options}, %{$default_options} };
}

sub import {
    # if they don't import $default_options then don't try to load them.  This
    # stops the file not found error when POD tests run.
    if (grep { $_ eq '$default_options' } @_) {
        load_cibhrc();
    }

    __PACKAGE__->export_to_level(1,@_);
}

=head2 save_file

    CIBH::Config::save_file($filename,$data,'variablename',$opts);

Saves variable data to a file using Data::Dumper with indention.

=cut

sub save_file {
    my ($file,$data,$name,$opts) = (@_);
    use Data::Dumper;
    use CIBH::File;
    $Data::Dumper::Indent = 1;
    $Data::Dumper::Deepcopy = 1;

    my $out=Data::Dumper->Dump([$data],[$name]);
    if (!defined $opts->{stdout}) {
        warn "Dumping config to $file\n" if $opts->{debug};
        CIBH::File::overwrite($file,$out);
    } else {
        print $out;
    }
}


1;

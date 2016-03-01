package CIBH::DS;

use strict;
use warnings;
use Module::Runtime qw ( use_module );
use Carp;

=head1 NAME

CIBH::DS - Module for dealing with datastores

=head1 SYNOPSIS

  use CIBH::DS;
  my $ds = CIBH::DS::load_ds($opt->{datastore});

=head1 METHODS

=head2 load_ds

    my $ds = CIBH::DS::load_ds($opt->{datastore});

Loads the module for the specified datastore.

=cut

sub load_ds {
    my $datastore = shift;
    # there is only support for 1 datastore.  If they put more than one then
    # this will either load the first one or die.
    croak if (!defined($datastore));
    while (my ($ds, $ds_opts) = each %$datastore) {
        $ds = "CIBH::DS::$ds";
        eval {
            use_module($ds)->_ds_init($ds_opts);
        };
        croak "Something went wrong with our load of datastore $ds: $@" if ($@);
        return $ds;
    }
}

1;

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
    croak if (!defined($datastore));
    my $ds = 'CIBH::DS::'.$datastore->{name};
    eval {
        use_module($ds)->_ds_init($datastore->{options});
    };
    croak "Something went wrong with our load of datastore $ds: $@" if ($@);
    return $ds;
}

1;

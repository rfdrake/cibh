package CIBH::DS;

use strict;
use warnings;
use Module::Load;
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
    my $datastore = shift || '';
    my $ds = "CIBH::DS::$datastore";
    eval {
        Module::Load::load $ds;
    };
    croak "Something went wrong with our load of datastore $ds: $@" if ($@);
    return $ds;
}

1;

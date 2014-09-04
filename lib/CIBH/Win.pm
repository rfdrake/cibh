package CIBH::Win;

# Copyright (c) 2000 Peter Whiting (Sprint). All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
use Carp;
use AutoLoader 'AUTOLOAD';

require Exporter;

@ISA = qw(Exporter);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw();
$VERSION = '0.01';


# Preloaded methods go here.

# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__
# Below is the stub of documentation for your module. You better edit it!

=head1 NAME

CIBH::Win - Perl extension for managing regions

=head1 SYNOPSIS

  use CIBH::Win;

=head1 DESCRIPTION

=head1 AUTHOR

Peter Whiting, pwhiting@sprint.net

=head1 SEE ALSO

CIBH::Datafile, CIBH::Win, CIBH::Chart, CIBH::Fig.

=cut

# this package will translate coord pairs into coord pairs within a
# window.  The pairs passed in will be floating point numbers from 0
# to 1 representing the relative location within the window.  The
# pairs returned will be absolute coordinates in the image defined
# by GD.  Note that in GD terms 0,0 is upper left.  This package
# will remap that into lower left.

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {
	x => 0,			# left of box
	y => 0,			# bottom of box (in GD coords)
	width => 0,
	height => 0,
	@_,
    };
    bless($self,$class);
    return $self;
}

sub map {
    my($self)=shift;
    my(@mapping,$x,$y);
    while(@_>1) {
	($x,$y)=(shift,shift);
	$x=1 if($x>1);
	$y=1 if($y>1);
	$x=0 if($x<0);
	$y=0 if($y<0);
	push(@mapping,($x*$self->{width})+$self->{x});
	push(@mapping,$self->{y}-($y*$self->{height}));
    }
    return @mapping;
}

sub map_relax {
    my($self)=shift;
    my(@mapping,$x,$y);
    while(@_>1) {
	($x,$y)=(shift,shift);
	push(@mapping,($x*$self->{width})+$self->{x});
	push(@mapping,$self->{y}-($y*$self->{height}));
    }
    return @mapping;
}



1;

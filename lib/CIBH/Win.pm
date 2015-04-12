package CIBH::Win;

# Copyright (c) 2000 Peter Whiting (Sprint). All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

use strict;
use warnings;

=head1 NAME

CIBH::Win - Perl extension for managing regions

=head1 SYNOPSIS

  use CIBH::Win;

=head1 DESCRIPTION

this package will translate coord pairs into coord pairs within a
window.  The pairs passed in will be floating point numbers from 0
to 1 representing the relative location within the window.  The
pairs returned will be absolute coordinates in the image defined
by GD.  Note that in GD terms 0,0 is upper left.  This package
will remap that into lower left.

=head1 AUTHOR

Peter Whiting, pwhiting@sprint.net

=head1 SEE ALSO

CIBH::Datafile, CIBH::Win, CIBH::Chart, CIBH::Fig.

=head2 new

    my $win = new CIBH::Win(x => 0, y => 0, width => 0, height => 0);

Creates a new CIBH::Win object.  Requires x,y,width,and height to be useful.

=cut

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

=head2 map

    @mapoutput = $win->map(0,0,1,1);

Given sets of coordinate pairs, map will translate them according to the
absolute coordinates.  In GD, 0,0 is the upper left, this remaps it to the
lower left.  So, for example, passing map(0,0); would return $self->{x},
$self->{y}.

=cut

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

=head2 map_relax

    @mapoutput = $win->map_relax(0,0);

This is the same as map() except it doesn't check the input is >=0 and <=1 boundries
so your data can go outside the window.

I'm not sure when you would want to use one vs the other.

=cut

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

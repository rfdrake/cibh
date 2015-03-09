package CIBH::Utility;

# TODO: Find out how to deal with things like $opts needing to be available to
# these subs.

=head1 NAME

CIBH::Utility - Utility functions that may be called by multiple modules or scripts

=cut

use strict;
use warnings;
use v5.14;     # for "state" variable

my $opts;


=head2 GetFiles

    $files=GetFiles($str,$logs);

Originally just called from HandleString in usage2fig, this takes a regex str
and searches for sets of files that match.  For instance, sl-bb10-atl--sl-bb.*-chi
might match some links between routers in two cities.  If a string doesn't
have a -- then it's assumed to be a router name and we search for usage data
for things like CPU utilisation.

There is a state variable that keeps a cache of found values so that lookups
are only done once, since they can be expensive.

=cut

sub GetFiles {
    my($str,$logs)=(@_);
    state %filehash;
    if (exists($filehash{$str})) {
        return $filehash{$str};
    }
    my $files = [];
    $str=~s/\\\\/\\/g; # strip these out - xfig puts them in;
    foreach my $alias (grep(/^$str$/,(keys %{$logs->{aliases}}))) {
        push(@{$files},@{$logs->{aliases}->{$alias}});
        warn "GetFiles regexp match: $str, $alias\n" if($opts->{debug});
    }
    if ($str !~ /--/) {
        push(@{$files},grep(/^$str$/,(keys %{$logs->{usage}})));
    }
    $filehash{$str}=$files;
    return $files;
}

=head2 build_color_map

    $color_map=build_color_map($shades);

Build a color map that will be used to convert utilisation into RGB values.

=cut

sub build_color_map {
    my $shades = shift;
    my $step = 255/$shades;
    my $color_map;
    my ($r,$g,$b)=(0,255,0);
    for(my $i=0;$i<$shades;$i++) {
        push(@$color_map,sprintf('#%02x%02x%02x',$r,$g,$b));
        ($r,$g,$b)=($r+$step,$g-$step,$b+2*$step*(($i>=$shades/2)?-1:1));
    }
    return $color_map;
}

1;

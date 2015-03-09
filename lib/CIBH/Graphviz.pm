package CIBH::Graphviz;

use strict;
use warnings;
use File::Temp;

# ultimately, Graphviz does everything for us.  The only choice we need to
# make is do we use imgmap or svg.  Either way we only need to parse the
# Graphviz digraph format, update the colors, then call the "dot" program to
# create the svg or png output.

sub new {

    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $opts = shift || {};

    my $self = {
        'shades' => 20,
        'output' => '',
        'buffer' => '',
        'color_map' => [],
        %{$opts},
    };
    bless($self,$class);
    $self->{color_map}=$self->build_color_map;
    return $self;
}

sub parse {
    my $self = shift;
    my %opts = @_;

    my $fh;

    if ($opts{file}) {
        open $fh, '<', $opts{file} or die "Can't read $opts{file} $!\n";
    } elsif ($opts{fh}) {
        $fh = $opts{fh};
    }

    read $fh, $self->{buffer}, -s $fh or die "Couldn't read file: $!";
    for (split(/^/, $self->{buffer})) {
        $self->parseline($_);
    }

    print $self->svg;
}

sub parseline {
    my $self = shift;
    my $line = shift;

    # parse a node
    if (/([A-Z][A-Z0-9]*)\[.*?id="(\S+?)\/(\S+)".*?\];/i) {
#        print "Node id=$2\n";
        my $b = $self->{color_map}[18];
        $line =~ s/fillcolor=\S+,/fillcolor="$b",/g;
    }

    # parse a link
    if (/([A-Z][A-Z0-9]*) -> ([A-Z][A-Z0-9]*) \[.*\];/i) {
    }

    $self->{output}.=$line;
}

sub build_color_map {
    my $self = shift;
    my $shades = $self->{shades};
    my $step = 255/$shades;
    my $color_map;
    my ($r,$g,$b)=(0,255,0);
    for(my $i=0;$i<$shades;$i++) {
        push(@$color_map,sprintf('#%02x%02x%02x',$r,$g,$b));
        ($r,$g,$b)=($r+$step,$g-$step,$b+2*$step*(($i>=$shades/2)?-1:1));
    }
    return $color_map;
}

sub output {
    $_[0]->{output};
}

sub svg {
    my $self = shift;
    my $file = shift;
    my $fh;
    if (!defined($file)) {
        $fh = File::Temp->new( DESTROY => 1 );
        $file = $fh->filename;
        print $fh $self->output;
    }
    qx#dot -Tsvg $file#;
}

sub png {
    my $self = shift;
    my $file = shift;
    my $fh;
    if (!defined($file)) {
        $fh = File::Temp->new( DESTROY => 1 );
        $file = $fh->filename;
        print $fh $self->output;
    }
    qx#dot -Tpng $file#;
}

sub imgmap {
    my $this = shift;
    my $output;
    my $fname = $this->{filename};
    $fname =~ s/.dia//;
    my $width = $this->{width};
    my $height = $this->{height};

    $output .= "<image src=\"$fname.png\" width=\"$width\", height=\"$height\" usemap=\"#mymap\">\n";
    $output .= "<map name=\"mymap\">\n";

    foreach my $obj (@{$this->{objects}}) {
        next if (!defined($obj->url));
        $output .= $obj->imgmap;
    }

    $output .= "</map>\n";
}


=head1 NAME

CIBH::Graphviz - Perl extension for dealing with Graphviz files

=head1 SYNOPSIS

  use CIBH::Graphviz;

=head1 DESCRIPTION

=head1 AUTHOR

Robert Drake, <rdrake@cpan.org>

=head1 SEE ALSO

perl(1) CIBH::Datafile, CIBH::Win, CIBH::Chart.

=cut

1;

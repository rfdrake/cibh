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
        'output'  => '',
        'buffer'  => '',
        'map_path'=> '.',
        %{$opts},
    };
    bless($self,$class);
    return $self;
}

sub parse {
    my $self = shift;
    my %opts = @_;

    if (!$opts{data} || !$opts{file}) {
        die "Graphviz->parse( file, data ); Need the data from GetAliases/build_color_map\n";
    }

    open my $infh, '<', $opts{file} or die "Can't read $opts{file} $!\n";
    read $infh, $self->{buffer}, -s $infh or die "Couldn't read file: $!";

    for (split(/^/, $self->{buffer})) {
        $self->parseline($_,$opts{data});
    }

    if(defined $self->{stdout}) {
        print $self->svg;
    } else {
        my $fh=new IO::File ">$self->{map_path}/$opts{file}.svg" or
            die "Cannot open $self->{map_path}/$opts{file}.svg for writing.";
        print $fh $self->svg;
    }
}

sub parseline {
    my $self = shift;
    my $line = shift;
    my $data = shift;

    # parse a node
    if (/([A-Z][A-Z0-9]*)\[.*?id="(\S+?)\/(\S+)".*?\];/i) {
#        print "Node id=$2\n";
        my $b = $data->{color_map}[18];
        $line =~ s/fillcolor=\S+,/fillcolor="$b",/g;
    }

    # parse a link
    if (/([A-Z][A-Z0-9]*) -> ([A-Z][A-Z0-9]*) \[.*\];/i) {
    }

    $self->{output}.=$line;
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

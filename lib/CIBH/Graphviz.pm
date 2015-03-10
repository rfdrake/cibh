package CIBH::Graphviz;

use strict;
use warnings;
use File::Temp;

# ultimately, Graphviz does everything for us.  The only choice we need to
# make is do we use imgmap or svg.  Either way we only need to parse the
# Graphviz digraph format, update the colors, then call the "dot" program to
# create the svg or png output.

=head2 new

    my $graphviz = CIBH::Graphviz->new( $opts );

Creates a new CIBH::Graphviz object.

=cut

sub new {

    my $proto = shift;
    my $class = ref($proto) || $proto;

    my $opts = shift || {};

    my $self = {
        'output'  => '',
        'buffer'  => '',
        'opts'    => { 'map_path' => '.', %{$opts} },
    };
    bless($self,$class);
    return $self;
}

=head2 parse

    my $output = $graphviz->parse( 'file' => '100-mid.gv', 'data' => $logs );

This takes the graphviz file and parses it, finding router names and changing
utilisation.  It can take an optional 'format' argument to tell it to return
an svg, png or imgmap.  It defaults to returning an svg.

=cut

sub parse {
    my $self = shift;
    my %args = @_;

    if (!$args{data} || !$args{file}) {
        die "Graphviz->parse( file, data ); Need the data from GetAliases/build_color_map\n";
    }

    open my $infh, '<', $args{file} or die "Can't read $args{file} $!\n";
    read $infh, $self->{buffer}, -s $infh or die "Couldn't read file: $!";

    for (split(/^/, $self->{buffer})) {
        $self->parseline($_,$args{data});
    }

    $args{format} ||= 'svg';

    if ($args{format} eq 'svg') {
        return $self->svg;
    } elsif($args{format} eq 'png') {
        return $self->png;
    } elsif($args{format} eq 'imgmap') {
        return $self->imgmap;
    } else {
        die "Unknown graph format $args{format}\n";
    }
}

=head2 parseline

    $self->parseline($line, $logs);

Parses a line of a graphviz file and looks for nodes or connections.

=cut

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

=head2 output

    my $output = $graphviz->output();

Returns the graphviz source file that has been modified with the utilisation
colors and other changes.

=cut

sub output {
    $_[0]->{output};
}

=head2 svg

    my $svg = $graphviz->svg();

Returns an SVG of the current output.

=cut

sub svg {
    my $self = shift;
    my $fh = File::Temp->new( UNLINK => 1 );
    my $file = $fh->filename;
    print $fh $self->output;
    qx#dot -Tsvg $file#;
}

=head2 png

    my $png = $graphviz->png();

Returns a PNG of the current output.

=cut

sub png {
    my $self = shift;
    my $fh = File::Temp->new( UNLINK => 1 );
    my $file = $fh->filename;
    print $fh $self->output;
    qx#dot -Tpng $file#;
}

=head2 imgmap

    my $imgmap = $graphviz->imgmap();

Returns an IMGMAP of the current output.  This corresponds with the PNG you
can get with $graphviz->png().

=cut

sub imgmap {
    my $self = shift;
    my $fh = File::Temp->new( UNLINK => 1 );
    my $file = $fh->filename;
    print $fh $self->output;
    qx#dot -Tcmapx $file#;
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

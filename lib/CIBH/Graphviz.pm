package CIBH::Graphviz;

use strict;
use warnings;
use File::Temp;

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
        'nodes'   => {},
        'opts'    => $opts,
    };
    bless($self,$class);
    return $self;
}

=head2 parse

    my $output = $graphviz->parse( 'file' => '100-mid.gv', 'logs' => CIBH::Logs->new() );

This takes the graphviz file and parses it, finding router names and changing
utilization.  It can take an optional 'format' argument to tell it to return
an svg, png or imgmap.  It defaults to returning an svg.

=cut

sub parse {
    my $self = shift;
    my %args = @_;

    if (!$args{logs} || !$args{file}) {
        die "Graphviz->parse( file, logs ); Need a filename and CIBH::Logs object\n";
    }

    open my $infh, '<', $args{file} or die "Can't read $args{file} $!\n";
    read $infh, $self->{buffer}, -s $infh or die "Couldn't read file: $!";

    for (split(/^/, $self->{buffer})) {
        $self->parseline($_,$args{logs});
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
    my $opts = $self->{opts};
    my $line = shift;
    my $logs = shift;
    my $nodes = $self->{nodes};

    # parse a node
    if (/([A-Z][A-Z0-9]*)\s*\[.*?id="(\S+?)\/(\S+)".*?\];/i) {
        $nodes->{ids}->{$1}=$2;
        $nodes->{names}->{$2}=$1;
        my $str = $2.'/'.$3;
        my $files = $logs->GetFiles($str);
        if (@{$files}) {
            my $util = $logs->GetUtilization($files);
            my $url = $logs->url($files);
            $line =~ s/URL=""/URL="$url"/ if (!$opts->{hide_urls});
            $line =~ s/%%/$util/g;
            my $color = $logs->color_map->[int($util*($opts->{shades}-.001)/100)];
            $line =~ s/fillcolor=\S+([, ])/fillcolor="$color"$1/;
        } else {
            warn "Didn't match anything for $str\n";
        }
    }

    # parse a link
    #BB2 -> WAL [dir=none color=red id="bb2-56-mar--ubr1-wal-cha" xlabel="%%  " URL=""];
    #WAL -- BER [dir=both color="yellow:green" id="bb2-56-mar--ubr1-ber-med" xlabel="%%:%%  " URL=""];

    if (/([A-Z][A-Z0-9]*) -[\->] ([A-Z][A-Z0-9]*) \[(.*)\];/i) {
        $line = $self->parselink($line, $logs, $1, $2, $3);
    }

    $self->{output}.=$line;
}

=head2 parselink

    $line=$self->parselink($line, $logs, $node1, $node2, $attributes);

Parses a link.  If the id is specified it will use it as the sources.  If not
the nodes will be used to lookup their ids and they will be used for the
lookup.

=cut

sub parselink {
    my $self = shift;
    my $opts = $self->{opts};
    my $line = shift;
    my $logs = shift;
    my $nodes = $self->{nodes};


}

=head2 output

    my $output = $graphviz->output();

Returns the graphviz source file that has been modified with the utilization
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

1;

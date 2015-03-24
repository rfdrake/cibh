package CIBH::Graphviz;

use strict;
use warnings;
use File::Temp;
use POSIX;
use List::Util qw ( max );

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

    # ignore lines starting with comments
    if (/^\s*#/) {

    } elsif (/([A-Z][A-Z0-9]*)\s*\[.*?id="(\S+?)\/(\S+)".*?\];/i) {
        # parse a node
        $nodes->{ids}->{$1}=$2;
        $nodes->{names}->{$2}=$1;
        my $str = $2.'/'.$3;
        my $files = $logs->GetFiles($str);
        my $color = $opts->{default_line_color} ? $opts->{default_line_color} : '#000000';
        if (@{$files}) {
            my $util = sprintf("%2.0f", $logs->GetUtilization($files));
            my $url = $logs->url($files);
            $url =~ s/&/&amp;/g;
            $line =~ s/URL=""/URL="$url"/ if (!$opts->{hide_urls});
            $line =~ s/%%/$util/g;
            $color = $self->shade($logs,$util);
        } else {
            warn "Didn't match anything for $str\n";
        }
        $line =~ s/fillcolor=\S+([, ])/fillcolor="$color"$1/;
    } elsif (/([A-Z][A-Z0-9]*) -[\->] ([A-Z][A-Z0-9]*) \[(.*)\];/i) {
        $line = $self->parselink($line, $logs, $1, $2, $3);
    }

    $self->{output} .= $line;
}

=head2 shade

    my $color = $self->shade($logs,$util);

Takes a utilization percentage and returns a RGB color value.

=cut

sub shade {
    my $self=shift;
    my $logs=shift;
    my $util=shift;
    my $opts=$self->{opts};
    # normally utilization can't exceed 100%, but sometimes it can.  If
    # someone sets a circuit bandwidth lower than reality, then it can be
    # well above 100.  We want the actual percentage to display, but for
    # the color we need 99/100 to be the max.
    return $logs->color_map->[int(($util > 99.9 ? 99.9 : $util)*($opts->{shades}-.001)/100)];
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
    my $nodes = $self->{nodes};
    my ($line, $logs, $node1, $node2, $attributes) = @_;
    my $str = $nodes->{ids}->{$node1} . '--' . $nodes->{ids}->{$node2};

    # need to support dir=both and other multicolor options
    # as well as being able to handle link directions

    if ($attributes =~ /id="(.*?)"/) {
        $str = $1;
    }
    my $files = $logs->GetFiles($str);
    my $color = $opts->{default_line_color} ? $opts->{default_line_color} : '#000000';
    if (@{$files}) {
        my $url = $logs->url($files);
        $url =~ s/&/&amp;/g;
        $line =~ s/URL=""/URL="$url"/ if (!$opts->{hide_urls});
        my $util;
        if ($line =~ /dir=both/) {
            my ($name1) = split(/--/, $str);
            my $in = $logs->GetUtilization($files, filename => $name1, dir => 'in');
            my $out = $logs->GetUtilization($files, filename => $name1, dir => 'out');
            $color = $self->shade($logs,$in) . ':' . $self->shade($logs,$out);
            $util = sprintf("%2.0f", max($in,$out));

        } elsif ($line =~ /dir=none/) {
            $util = sprintf("%2.0f", $logs->GetUtilization($files));
            $color = $self->shade($logs,$util);
        } else {  # no dir= means arrow points to second node so we do output
            my ($name1) = split(/--/, $str);
            my $out = $logs->GetUtilization($files, filename => $name1, dir => 'out');
            $color = $self->shade($logs,$out);
            $util = sprintf("%2.0f", $out);
        }
        $line =~ s/%%/$util/g;
    } else {
        warn "Didn't match anything for $str\n";
    }
    if ($line =~ /color="\S+;([\d\.]+)"/) {
        my $val = $1;
        $line =~ s/color=\S+/color="$color;$val"/;
    } else {
        $line =~ s/color=\S+/color="$color"/;
    }
    return $line;
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

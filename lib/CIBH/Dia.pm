package CIBH::Dia;

use strict;
use IO::Uncompress::Gunzip;
use List::Util qw(min max);
use File::Temp;
use Module::Runtime qw ( use_module );
use Carp;

use constant TOP => 0;
use constant BOTTOM => 1;
use constant LEFT => 2;
use constant RIGHT => 3;

=head2 new

    my $dia = CIBH::Dia->new($filename, $fh, $debug);

Creates a new dia object.

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {
        'filename' => $_[0], # filename for XML file (used for imgmap)
        'fh' => $_[1],     # filehandle for XML file
        'debug' => $_[2],  # they can pass $opts->{debug} in to enable warnings
        'boxes' => undef,
        'texts' => undef,
        'lines' => undef,
        'doc' => undef,    # the XML document
        # top and left are 1 million to make sure minimum extent < default
        'extents' => [ 1_000_000, 0, 1_000_000, 0 ], # top, bottom, left, right
        'ids' => undef,    # hashmap of id attributes to objects for connections
        'scale' => -1,
    };
    bless($self,$class);
    my $err = $self->load_xml;
    if ($err) {
        warn "CIBH::Dia::new error:  I think the Dia file is invalid." if ($self->{debug});
        return;
    }
    $self->parse_scale;           # update the scale with the value of data.paper.scaling
    $self->parse_ids;
    return $self;
}

sub _stat {
    return $_[0]->{fh}->stat;
}

=head2 atime

    my $atime = $dia->atime;

Returns the last access time of the object file.

=cut

sub atime {
    localtime(($_[0]->_stat)[8]);
}

=head2 mtime

    my $mtime = $dia->mtime;

Returns the last modified time of the object file.

=cut

sub mtime {
    localtime(($_[0]->_stat)[9]);
}

=head2 ctime

    my $ctime = $dia->ctime;

Returns the creation time of the object file.

=cut

sub ctime {
    localtime(($_[0]->_stat)[10]);
}

=head2 load_xml

    my $err = $dia->load_xml;

Attempts to load the dia object from the filehandle in $self->{fh}.  It will
uncompress first if it needs to.

Currently this will return an error if $self->{debug} is set, otherwise it
returns nothing.  I will probably change it later so that it dies on error and
returns $self on success.

=cut

sub load_xml {
    my $self = shift;
    my $gzdata = IO::Uncompress::Gunzip->new($self->{fh}, { Transparent => 1 });
    eval {
        $self->{doc} = use_module('XML::LibXML')->load_xml(IO => $gzdata);
   };
   if ($@) {
        carp $@ if ($self->{debug});
        return $@;
   }
}

=head2 parse_scale

    my $scale = $self->parse_scale;

Parses the scale of the dia drawing.

=cut

sub parse_scale {
    my $self = shift;

    my ($scale) = $self->{doc}->findnodes('/dia:diagram/dia:diagramdata/dia:attribute[@name="paper"]/dia:composite[@type="paper"]/dia:attribute[@name="scaling"]/dia:real/@val');
    $self->{scale} = $scale->getValue * 20;
    return $self->{scale};
}

=head2 parse_ids

    $self->parse_ids;

maps objects by the dia:object[@id] attribute into a hash table.  This figures
out if they are lines, text, or boxes and creates Dia objects for those
attributes.

=cut

sub parse_ids {
    my $self = shift;
    my @objects = $self->{doc}->findnodes('/dia:diagram/dia:layer/dia:object');
    my $objects;
    my @boxes;
    my @texts;

    for(@objects) {
        my $type = $_->getAttribute('type');
        my $obj;
        if ($type eq 'Standard - Text') {
            $obj = CIBH::Dia::Text->new($self, $_, $self->{debug});
            push(@texts, $obj);
        } elsif ($type =~ /Standard - (Line|PolyLine|ZigZagLine|BezierLine|Arc)/) {
            $obj = CIBH::Dia::Line->new($self, $_, $self->{debug});
        } else {
            $obj = CIBH::Dia::Box->new($self, $_, $self->{debug});
            push(@boxes, $obj);
        }
        $objects->{$_->getAttribute('id')}=$obj;
    }
    $self->{boxes}=\@boxes;
    $self->{texts}=\@texts;
    my @merged = (@boxes, @texts);
    $self->{objects}=\@merged;
    $self->{ids}=$objects;
    return $self;
}

=head2 get_object_by_id

    my $obj = $self->get_object_by_id("id");

Given an object ID this returns the object.

=cut

sub get_object_by_id {
    $_[0]->{ids}{$_[1]};
}

=head2 boxes

    my $boxes = $self->boxes;

Returns an arrayref of the boxes.

=cut

sub boxes {
    $_[0]->{boxes};
}

=head2 texts

    my $texts = $self->texts;

Returns an arrayref of the texts.


=cut
sub texts {
    $_[0]->{texts};
}

=head2 extents

    my $extents = $self->extents($r);

This takes an optional argument ($r) which is an array of 4 values, TOP,
BOTTOM, LEFT, and RIGHT.  When given it updates the size of the dia object.

Returns an arrayref of the 4 current maximum extents.

=cut


sub extents {
    my $self = shift;
    my $r2 = shift;
    my $r1 = $self->{extents};
    my $scale = $self->{scale};

    my $rectangle_union = sub {
        my ($r1, $r2) = (@_);
        $r1->[TOP] = min( $r1->[TOP], $r2->[TOP] );
        $r1->[BOTTOM] = max( $r1->[BOTTOM], $r2->[BOTTOM] );
        $r1->[LEFT] = min( $r1->[LEFT], $r2->[LEFT] );
        $r1->[RIGHT] = max( $r1->[RIGHT], $r2->[RIGHT] );
    };
    if (defined($r2)) {
        &{$rectangle_union}($r1, $r2);
        $self->{width} = int(($r1->[RIGHT] - $r1->[LEFT]) * $scale);
        $self->{height} = int(($r1->[BOTTOM] - $r1->[TOP]) * $scale);
        $self->{xofs} = -($r1->[LEFT] * $scale);
        $self->{yofs} = -($r1->[TOP] * $scale);
    }
    $self->{extents} = $r1;
    return $r1;
}

=head2 output

    my $output = $self->output;

Returns a string output of the dia stuff.

=cut

sub output {
    $_[0]->{doc}->toString();
}

=head2 png

    my $png = $self->png($file);

Returns the dia as a PNG image.  Given an optional filename it will save the
file as that filename.

=cut

sub png {
    my $self = shift;
    my $file = shift;
    my $fh;
    if (!defined($file)) {
        # unlink the file when we leave the png sub
        $fh = File::Temp->new( DESTROY => 1 );
        $file = $fh->filename;
        print $fh $self->output;
    }
    # dia doesn't accept input from stdin or -.  2>/dev/null is needed to
    # suppress bogus warning about unable to open X11 display.

    qx#dia --nosplash --export=/dev/stdout -t png $file 2>/dev/null#;
}

=head2 imgmap

    my $imgmap = $self->imgmap;

Returns an HTML image map for the dia PNG.  This looks through all the Dia
sub-objects and compiles their image maps to create the global image map.

=cut

sub imgmap {
    my $self = shift;
    my $output;
    my $fname = $self->{filename};
    $fname =~ s/.dia//;
    my $width = $self->{width};
    my $height = $self->{height};

    $output .= "<image src=\"$fname.png\" width=\"$width\", height=\"$height\" usemap=\"#mymap\">\n";
    $output .= "<map name=\"mymap\">\n";

    foreach my $obj (@{$self->{objects}}) {
        next if (!defined($obj->url));
        $output .= $obj->imgmap;
    }

    $output .= "</map>\n";
    return $output;
}


=head1 NAME

CIBH::Dia - Perl extension for dealing with dia files

=head1 SYNOPSIS

  use CIBH::Dia;

=head1 DESCRIPTION

=head1 AUTHOR

Robert Drake, <rfdrake@gmail.com>


=head1 SEE ALSO

perl(1) CIBH::DS::Datafile, CIBH::Win, CIBH::Chart.

=cut

1;

package CIBH::Dia::Object;
use strict;

=head2 imgmap

    my $output = $self->imgmap;

Returns an imgmap for the Dia object.

=cut

sub imgmap { undef }

=head2 bounding_box

=cut

sub bounding_box {
    my $self = shift;

    if (defined($self->{bb})) {
        return $self->{bb};
    }
    my ($objbb) = $self->{object}->findnodes('dia:attribute[@name="obj_bb"]/dia:rectangle/@val');
    my $in = $objbb->getValue;
    $in =~ tr/;/,/;
    my @bb = split(/,/, $in);  # order is top, bottom, left, right
    $self->{bb} = \@bb;
    return \@bb;
}

=head2 color

=cut

sub color {
    my $self = shift;
    my $newcolor = shift;

    if (!defined($self->color_name)) {
        warn 'Attempt to find color of non-colorable object: '. ref($self) ."\n" if ($self->{debug});
        return;
    }
    if (!defined($self->{object})) {
        warn 'Attempt to find color on invalid object' if ($self->{debug});
        return;
    }
    my ($color) = $self->{object}->findnodes('dia:attribute[@name="'. $self->color_name . '"]/dia:color/@val');
    if (!defined($color)) {
        return;
    }
    if (defined($newcolor)) {
        $color->setValue($newcolor);
    }
    return $color->getValue;
}

=head2 text

# this does not update the boundary box to account for the text length change

=cut

sub text {
    my $self = shift;
    my $newtext = shift;

    if (!defined($self->{object})) {
        warn 'Attempt to find text on invalid object' if ($self->{debug});
        return;
    }
    my $xml = $self->{object};
    my ($text) = $xml->findnodes('dia:attribute[@name="text"]/dia:composite[@type="text"]/dia:attribute[@name="string"]/dia:string');
    if (!defined($text)) {
        return;
    }

    my $textvalue = $xml->findnodes('dia:attribute[@name="text"]/dia:composite[@type="text"]/dia:attribute[@name="string"]/dia:string/text()')->shift->getValue();

    if (defined($newtext)) {
        $text->removeChildNodes();
        $text->appendText("#$newtext#");
        $textvalue=$newtext;
    } else {
        # get rid of leading and trailing # characters
        $textvalue = substr($textvalue,1,length($textvalue)-2);
    }
    return $textvalue;
}

=head2 color_name

=cut

sub color_name {
    'color';
}

=head2 url
# getter and setter for imgmap url
=cut

sub url {
    my $self = shift;
    my $url = shift;
    if (defined($url)) {
        $self->{mapurl}=$url;
    }

    return $self->{mapurl};
}

=head2 connection

=cut

sub connection {
    my $self = shift;
    my @obj;
    foreach my $c ($self->{object}->findnodes('dia:connections/dia:connection/@to')) {
        my $id = $c->getValue;
        push(@obj, $self->{dia}->get_object_by_id($id))
    }

    return \@obj;
}

=head2 new
=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    if (!defined($_[1])) {
        return;
    }
    my $self = {
        'dia'   => $_[0],
        'object' => $_[1],
        'debug' => $_[2],
        'mapurl' => undef,      # for imgmap
        'bb'    => undef,       # boundary_box
    };
    bless($self,$class);
    $self->{dia}->extents($self->bounding_box);
    return $self;
}

1;

package CIBH::Dia::Box;
use parent -norequire, 'CIBH::Dia::Object';
use strict;

use constant TOP => 0;
use constant BOTTOM => 1;
use constant LEFT => 2;
use constant RIGHT => 3;

=head2 imgmap
=cut

sub imgmap {
    my $self = shift;
    return if !defined($self->url);

    my $scale = $self->{dia}->{scale};
    my $xofs = $self->{dia}->{xofs};
    my $yofs = $self->{dia}->{yofs};

    my $r = $self->bounding_box;
    my $x1 = int($r->[LEFT] * $scale) + $xofs;
    my $y1 = int($r->[TOP] * $scale) + $yofs;
    my $x2 = int($r->[RIGHT] * $scale) + $xofs;
    my $y2 = int($r->[BOTTOM] * $scale) + $yofs;

    my $area = sprintf("<area shape='rect' href='%s' title='%s' alt='%s' coords='%d,%d,%d,%d'/>",
                        $self->url, $self->url, $self->url, $x1, $y1, $x2, $y2);
    return $area;
}

=head2 color_name
=cut

sub color_name {
    'inner_color';
}

1;

package CIBH::Dia::Text;
use parent -norequire, 'CIBH::Dia::Object';
use strict;

# returns the first connection.  This assumes that the text is only attached
# to one place.
sub line {
    return $_[0]->connection->[0];
}

1;

package CIBH::Dia::Line;
use parent -norequire, 'CIBH::Dia::Object';
use strict;

sub color_name {
    return 'line_color';
}

sub points {
    my $self = shift;
    my @points;

    foreach my $point ($self->{object}->findnodes('dia:attribute[@name="'.$self->point_name.'"]/dia:point/@val')) {
        my $xy = $point->getValue;
        push(@points, split(/,/, $xy));
    }
    return \@points;
}

# figure out if they have poly_points, conn_endpoints, orth_points.
# some Polygons have points as well so we need to decide if this should be
# under CIBH::Dia::Line.  Right now my inclination is to not support those
# object types for simplicity
sub point_name {
    my $self = shift;
    my $obj = $self->{object};
    if (defined($self->{point_name})) {
        return $self->{point_name};
    }

    if ($obj->exists('dia:attribute[@name="poly_points"]')) {
        $self->{point_name}='poly_points';
    } elsif ($obj->exists('dia:attribute[@name="orth_points"]')) {
        $self->{point_name}='orth_points';
    } elsif ($obj->exists('dia:attribute[@name="conn_endpoints"]')) {
        $self->{point_name}='conn_endpoints';
    }

    return $self->{point_name};
}


1;

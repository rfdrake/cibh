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

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $this = {
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
    bless($this,$class);
    my $err = $this->load_xml;
    if ($err) {
        warn "CIBH::Dia::new error:  I think the Dia file is invalid." if ($this->{debug});
        return;
    }
    $this->parse_scale;           # update the scale with the value of data.paper.scaling
    $this->parse_ids;
    return $this;
}

sub stat {
    return $_[0]->{fh}->stat;
}

sub atime {
    return localtime(($_[0]->{fh}->stat)[8]);
}

sub mtime {
    return localtime(($_[0]->{fh}->stat)[9]);
}

sub ctime {
    return localtime(($_[0]->{fh}->stat)[10]);
}

sub load_xml {
    my $this = shift;
    my $gzdata = IO::Uncompress::Gunzip->new($this->{fh}, { Transparent => 1 });
    eval {
        $this->{doc} = use_module('XML::LibXML')->load_xml(IO => $gzdata);
   };
   if ($@) {
        croak $@ if ($this->{debug});
        die;
   }
}

sub get_objects_by_id {
    my $this = shift;
    my $id = shift;
    return $this->{ids}->{$id};
}

sub parse_scale {
    my $this = shift;

    my ($scale) = $this->{doc}->findnodes('/dia:diagram/dia:diagramdata/dia:attribute[@name="paper"]/dia:composite[@type="paper"]/dia:attribute[@name="scaling"]/dia:real/@val');
    $this->{scale} = $scale->getValue * 20;
    return $this->{scale};
}

# map objects by the dia:object[@id] attribute into a hash table
sub parse_ids {
    my $this = shift;
    my @objects = $this->{doc}->findnodes('/dia:diagram/dia:layer/dia:object');
    my $objects;
    my @boxes;
    my @texts;

    for(@objects) {
        my $type = $_->getAttribute('type');
        my $obj;
        if ($type eq 'Standard - Text') {
            $obj = CIBH::Dia::Text->new($this, $_, $this->{debug});
            push(@texts, $obj);
        } elsif ($type =~ /Standard - (Line|PolyLine|ZigZagLine|BezierLine|Arc)/) {
            $obj = CIBH::Dia::Line->new($this, $_, $this->{debug});
        } else {
            $obj = CIBH::Dia::Box->new($this, $_, $this->{debug});
            push(@boxes, $obj);
        }
        $objects->{$_->getAttribute('id')}=$obj;
    }
    $this->{boxes}=\@boxes;
    $this->{texts}=\@texts;
    my @merged = (@boxes, @texts);
    $this->{objects}=\@merged;
    $this->{ids}=$objects;
}

sub get_object_by_id {
    return $_[0]->{ids}{$_[1]};
}

sub boxes {
    return $_[0]->{boxes};
}

sub texts {
    return $_[0]->{texts};
}

# everytime extents is called, we're going to update width, height, xofs and yofs
sub extents {
    my $this = shift;
    my $r2 = shift;
    my $r1 = $this->{extents};
    my $scale = $this->{scale};

    my $rectangle_union = sub {
        my ($r1, $r2) = (@_);
        $r1->[TOP] = min( $r1->[TOP], $r2->[TOP] );
        $r1->[BOTTOM] = max( $r1->[BOTTOM], $r2->[BOTTOM] );
        $r1->[LEFT] = min( $r1->[LEFT], $r2->[LEFT] );
        $r1->[RIGHT] = max( $r1->[RIGHT], $r2->[RIGHT] );
    };
    if (defined($r2)) {
        &{$rectangle_union}($r1, $r2);
        $this->{width} = int(($r1->[RIGHT] - $r1->[LEFT]) * $scale);
        $this->{height} = int(($r1->[BOTTOM] - $r1->[TOP]) * $scale);
        $this->{xofs} = -($r1->[LEFT] * $scale);
        $this->{yofs} = -($r1->[TOP] * $scale);
    }
    $this->{extents} = $r1;
    return $r1;
}

sub output {
    return $_[0]->{doc}->toString();
}

sub png {
    my $this = shift;
    my $file = shift;
    my $fh;
    if (!defined($file)) {
        # unlink the file when we leave the png sub
        $fh = File::Temp->new( DESTROY => 1 );
        $file = $fh->filename;
        print $fh $this->output;
    }
    # dia doesn't accept input from stdin or -.  2>/dev/null is needed to
    # suppress bogus warning about unable to open X11 display.

    qx#dia --nosplash --export=/dev/stdout -t png $file 2>/dev/null#;
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

# this should be defined by the more specific object if there is a function
# for it (Line or Box.  Text won't have one)
sub imgmap { }

sub bounding_box {
    my $this = shift;

    if (defined($this->{bb})) {
        return $this->{bb};
    }
    my ($objbb) = $this->{object}->findnodes('dia:attribute[@name="obj_bb"]/dia:rectangle/@val');
    my $in = $objbb->getValue;
    $in =~ tr/;/,/;
    my @bb = split(/,/, $in);  # order is top, bottom, left, right
    $this->{bb} = \@bb;
    return \@bb;
}

sub color {
    my $this = shift;
    my $newcolor = shift;

    if (!defined($this->color_name)) {
        warn 'Attempt to find color of non-colorable object: '. ref($this) ."\n" if ($this->{debug});
        return;
    }
    if (!defined($this->{object})) {
        warn 'Attempt to find color on invalid object' if ($this->{debug});
        return;
    }
    my ($color) = $this->{object}->findnodes('dia:attribute[@name="'. $this->color_name . '"]/dia:color/@val');
    if (!defined($color)) {
        return;
    }
    if (defined($newcolor)) {
        $color->setValue($newcolor);
    }
    return $color->getValue;
}

# this does not update the boundry box to account for the text length change
sub text {
    my $this = shift;
    my $newtext = shift;

    if (!defined($this->{object})) {
        warn 'Attempt to find text on invalid object' if ($this->{debug});
        return;
    }
    my $xml = $this->{object};
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

sub color_name {
    return 'color';
}

# getter and setter for imgmap url
sub url {
    my $this = shift;
    my $url = shift;
    if (defined($url)) {
        $this->{mapurl}=$url;
    }

    return $this->{mapurl};
}

sub connection {
    my $this = shift;
    my @obj;
    foreach my $c ($this->{object}->findnodes('dia:connections/dia:connection/@to')) {
        my $id = $c->getValue;
        push(@obj, $this->{dia}->get_object_by_id($id))
    }

    return \@obj;
}

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    if (!defined($_[1])) {
        return;
    }
    my $this = {
        'dia'   => $_[0],
        'object' => $_[1],
        'debug' => $_[2],
        'mapurl' => undef,      # for imgmap
        'bb'    => undef,       # boundry_box
    };
    bless($this,$class);
    $this->{dia}->extents($this->bounding_box);
    return $this;
}

1;

package CIBH::Dia::Box;
use parent -norequire, 'CIBH::Dia::Object';
use strict;

use constant TOP => 0;
use constant BOTTOM => 1;
use constant LEFT => 2;
use constant RIGHT => 3;

sub imgmap {
    my $this = shift;
    return if !defined($this->url);

    my $scale = $this->{dia}->{scale};
    my $xofs = $this->{dia}->{xofs};
    my $yofs = $this->{dia}->{yofs};

    my $r = $this->bounding_box;
    my $x1 = int($r->[LEFT] * $scale) + $xofs;
    my $y1 = int($r->[TOP] * $scale) + $yofs;
    my $x2 = int($r->[RIGHT] * $scale) + $xofs;
    my $y2 = int($r->[BOTTOM] * $scale) + $yofs;

    my $area = sprintf("<area shape='rect' href='%s' title='%s' alt='%s' coords='%d,%d,%d,%d'/>",
                        $this->url, $this->url, $this->url, $x1, $y1, $x2, $y2);
    return $area;
}

sub color_name {
    return 'inner_color';
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
    my $this = shift;
    my @points;

    foreach my $point ($this->{object}->findnodes('dia:attribute[@name="'.$this->point_name.'"]/dia:point/@val')) {
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
    my $this = shift;
    my $obj = $this->{object};
    if (defined($this->{point_name})) {
        return $this->{point_name};
    }

    if ($obj->exists('dia:attribute[@name="poly_points"]')) {
        $this->{point_name}='poly_points';
    } elsif ($obj->exists('dia:attribute[@name="orth_points"]')) {
        $this->{point_name}='orth_points';
    } elsif ($obj->exists('dia:attribute[@name="conn_endpoints"]')) {
        $this->{point_name}='conn_endpoints';
    }

    return $this->{point_name};
}


1;

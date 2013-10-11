package CIBH::Dia;

use strict;
use XML::LibXML;
use IO::Uncompress::Gunzip;
use List::Util qw(min max);
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;

@ISA = qw(Exporter);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw();
$VERSION = '1.00';

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
    };
    bless($this,$class);
    my $err = $this->load_xml;
    if ($err) {
        warn "CIBH::Dia::new error:  I think the Dia file is invalid." if ($this->{debug});
        return;
    }
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
        $this->{doc} = XML::LibXML->load_xml(IO => $gzdata);
   };
   if ($@) {
        warn $@ if ($this->{debug});
        return 1;
   }
}

# map objects by the dia:object[@id] attribute into a hash table
sub parse_ids {
    my $this = shift;
    my @objects = $this->{doc}->findnodes('/dia:diagram/dia:layer/dia:object');
    my $objects;
    my @boxes;
    my @texts;

    # map objects by id into a hash table
    map { $objects->{$_->getAttribute('id')}=$_ } @objects;
    $this->{ids}=$objects;

    for(@objects) {
        my $type = $_->getAttribute('type');
        if ($type eq 'Standard - Text') {
            my ($c) = $_->findnodes('dia:connections/dia:connection/@to');
            my $connection = undef;
            if (defined($c) && defined($c->getValue)) {
                $connection = $this->{ids}->{$c->getValue};
            }
            push(@texts, CIBH::Dia::Text->new($this, $_, $this->{debug}, CIBH::Dia::Line->new($this, $connection, $this->{debug})));
        # anything that isn't a line or text is treated as a box
        } elsif ($type ne 'Standard - Line') {
            push(@boxes, CIBH::Dia::Box->new($this, $_, $this->{debug}));
        }
    }
    $this->{boxes}=\@boxes;
    $this->{texts}=\@texts;
    my @merged = (@boxes, @texts);
    $this->{objects}=\@merged;
}

sub boxes {
    return $_[0]->{boxes};
}

sub texts {
    return $_[0]->{texts};
}

sub output {
    return $_[0]->{doc}->toString();
}

sub extents {
    my $this = shift;
    my $r2 = shift;
    my $r1 = $this->{extents};

    use constant TOP => 0;
    use constant BOTTOM => 1;
    use constant LEFT => 2;
    use constant RIGHT => 3;
    

    sub rectangle_union {
        my ($r1, $r2) = (@_);
        $r1->[TOP] = min( $r1->[TOP], $r2->[TOP] );
        $r1->[BOTTOM] = max( $r1->[BOTTOM], $r2->[BOTTOM] );
        $r1->[LEFT] = min( $r1->[LEFT], $r2->[LEFT] );
        $r1->[RIGHT] = max( $r1->[RIGHT], $r2->[RIGHT] );
    }
    if (defined($r2)) {
        rectangle_union($r1, $r2);
    } 
    $this->{extents} = $r1; 
    return $r1;
}

# another issue:  Currently this would only support rectangle bounding boxes.
# In order to support ZigZagLine or polygons like Network - Radio Cell it
# needs to understand poly_points or orth_points and translate them into
# shape='poly'
# for a line you draw a polygon trace around the object, giving x/y
# coordinates for every edge.  We'll need to add/subtract half line width
# because orth_points only show the middle of the line.
# for poly_points the same problem happens.  The line thickness isn't taken
# into account so it would create a poly clickmap on the inside of the poly
# without including the surrounding line (not really too important unless you
# make the surrounding line 1cm or something.
sub imgmap {
    my $this = shift;
    my $output;
    my $fname = $this->{filename};
    $fname =~ s/.dia//;
    my $e = $this->extents;
    # fix this
    my $scale =  20.0 ;#* data.paper.'scaling';
    my $width = int(($e->{'right'} - $e->{'left'}) * $scale);
    my $height = int(($e->{'bottom'} - $e->{'top'}) * $scale);
    my $xofs = -($e->{'left'} * $scale);
    my $yofs = -($e->{'top'} * $scale);
    
    $output .= "<image src=\"$fname.png\" width=\"$width\", height=\"$height\" usemap=\"#mymap\">\n";
    $output .= "<map name=\"mymap\">\n";

    foreach my $obj (@{$this->{objects}}) {
        next if (!defined($obj->url));
        my $r = $obj->bounding_box;
        my $x1 = int($r->{'left'} * $scale) + $xofs;
        my $y1 = int($r->{'top'} * $scale) + $yofs;
        my $x2 = int($r->{'right'} * $scale) + $xofs;
        my $y2 = int($r->{'bottom'} * $scale) + $yofs;
        my $area;
        sprintf($area, "    <area shape='rect' href='%s' title='%s' alt='%s' coords='%d,%d,%d,%d'>\n", 
                        $obj->url, $obj->url, $obj->url, $x1, $y1, $x2, $y2);
        $output .= $area;    
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

perl(1) CIBH::Datafile, CIBH::Win, CIBH::Chart.

=cut

1;

package CIBH::Dia::Object;
use strict;

sub boundry_box {
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

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    if (!defined($_[1])) {
        return undef;
    }
    my $this = {
        'dia'   => $_[0],
        'object' => $_[1],
        'debug' => $_[2],
        'mapurl' => undef,      # for imgmap
        'bb'    => undef,       # boundry_box
    };
    bless($this,$class);
    $this->{dia}->extents($this->boundry_box);
    return $this;
}

1;

package CIBH::Dia::Box;
use parent -norequire, 'CIBH::Dia::Object';
use strict;

sub color_name {
    return 'inner_color';
}

1;

package CIBH::Dia::Text;
use parent -norequire, 'CIBH::Dia::Object';
use strict;
sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $this = {
        'dia'   => $_[0],
        'object' => $_[1],
        'debug' => $_[2],
        'connection' => $_[3],
    };
    bless($this,$class);
    $this->{dia}->extents($this->boundry_box);
    return $this;
}

sub line {
    return $_[0]->{connection};
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

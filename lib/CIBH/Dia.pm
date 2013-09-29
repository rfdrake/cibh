package CIBH::Dia;

use strict;
use XML::LibXML;
use IO::Uncompress::Gunzip;
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
        'fh' => $_[0],     # filehandle for XML file
        'boxes' => undef,
        'texts' => undef,
        'lines' => undef,  
        'doc' => undef,    # the XML document
        'ids' => undef,    # hashmap of id attributes to objects for connections
        'debug' => $_[1],  # they can pass $opts->{debug} in to enable warnings
    };
    bless($this,$class);
    my $err = $this->load_xml;
    if ($err) {
        warn "CIBH::Dia::new error:  I think the Dia file is invalid." if ($this->{debug});
        return;
    }
    $this->parse_ids;
    $this->parse_boxes;
    $this->parse_text;
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

    # map objects by id into a hash table
    map { $objects->{$_->getAttribute('id')}=$_ } @objects;
    $this->{ids}=$objects; 
}

sub parse_boxes {
    my $this = shift;
    my @objects = $this->{doc}->findnodes('/dia:diagram/dia:layer/dia:object[@type="Flowchart - Box"]');
    my @boxes;
    for(@objects) {
        push(@boxes, CIBH::Dia::Box->new($_, $this->{debug}));
    }

    $this->{boxes}=\@boxes;

}

sub parse_text {
    my $this = shift;
    my @objects = $this->{doc}->findnodes('/dia:diagram/dia:layer/dia:object[@type="Standard - Text"]');
    my @texts;
    for(@objects) {
        # I'm reasonably certain text will only ever have (at most) one connection
        my ($c) = $_->findnodes('dia:connections/dia:connection/@to');
        my $connection = undef;
        if (defined($c)) {
            $connection = $this->{ids}->{$c->getValue};
        }
        push(@texts, CIBH::Dia::Text->new($_, $this->{debug}, CIBH::Dia::Line->new($connection, $this->{debug})));
    }

    $this->{texts}=\@texts;
}

sub boxes {
    return $_[0]->{boxes};
}

sub texts {
    return $_[0]->{texts};
}

sub lines {
    return $_[0]->{lines};
}

sub output {
    return $_[0]->{doc}->toString();
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

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $this = {
        'object' => $_[0],
        'debug' => $_[1],
    };
    bless($this,$class);
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
        'object' => $_[0],
        'debug' => $_[1],
        'connection' => $_[2],
    };
    bless($this,$class);
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

1;

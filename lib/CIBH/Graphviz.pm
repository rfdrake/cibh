package CIBH::Graphviz;

use strict;
use warnings;

# ultimately, Graphviz does everything for us.  The only choice we need to
# make is do we use imgmap or svg.  Either way we only need to parse the
# Graphviz digraph format, update the colors, then call the "dot" program to
# create the svg or png output.

sub new {

    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $opts = shift;
    $opts->{output}='';
    $opts->{buffer}='';
    bless($opts,$class);
    return $opts;
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

#    print $self->{output};
}

sub parseline {
    my $self = shift;
    my $line = shift;

    # parse a node
    if (/([A-Z][A-Z0-9]*)\[.*?id="(\S+?)\/(\S+)".*?\];/i) {
#        print "Node id=$2\n";
        $line =~ s/fillcolor=\S+,/fillcolor=blue,/g;
    }

    # parse a link
    if (/([A-Z][A-Z0-9]*) -> ([A-Z][A-Z0-9]*) \[.*\];/i) {
    }

    $self->{output}.=$line;
}

sub output {
    return $_[0]->{doc}->toString();
}

sub svg {

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

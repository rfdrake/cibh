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
    bless($opts,$class);
    return $opts;
}

sub parse {
    my $self = shift;
    my $opts = shift;

    my $fh;
    my $output;

    if ($opts->{file}) {
        open $fh, '<', $opts->{file} or die "Can't read $opts->{file} $!\n";
    } elsif ($opts->{fh}) {
        $fh = $opts->{fh};
    }

    read $fh, my $buffer, -s $fh or die "Couldn't read file: $!";

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

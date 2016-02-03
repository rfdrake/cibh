package CIBH::File;

use strict;
use warnings;

use IO::All -base;
use File::Basename qw/ dirname /;
use File::Copy qw / move /;
use File::Temp;

=head1 NAME

CIBH::File - Module for functions dealing with File IO

=head1 SYNOPSIS

   use CIBH::File;

=head1 DESCRIPTION

These functions are for dealing with File IO and mainly consist of things I
found in multiple places in the code, or, in the case of handle, just
an attempt to move all the File:: modules into one place to clean things up.

=head1 AUTHOR

Robert Drake, rdrake@cpan.org

=head1 FUNCTIONS

=head2 mv

    mv($oldfile, $newfile);

Moves a file from one place to another.  If the new directory does not exist
it will create it.  This is different from a normal move and shouldn't be used
unless needed.

=cut

sub _dirname {
    CIBH::File->new(File::Basename::dirname($_[0]->name));
}

sub mv {
    my ($filename, $new)=(@_);
    move($filename, $new);
}

=head2 overwrite

    CIBH::File::overwrite($filename,$output);

Safely* overwrites a file by opening a tempfile, writing the contents then
moving that over the existing file.

* Yes, this doesn't look for people doing shennanigans like sockets, links or
other things, but it's primary purpose is to eliminate the unlink race
condition.  My primary concern was making sure a file opened by the web
interface was fully written.

=cut

sub overwrite {
    my ($file,$contents) = (@_);
    my $mode = sprintf '%04o', (stat $file)[2] & 07777;  ## no critic
    my $tmp=File::Temp->new( UNLINK => 0 );
    print $tmp $contents;
    chmod($mode, $tmp->filename);
    mv($tmp->filename,$file);
}

=head2 METHODS

=cut

=head2 new

    my $fileio = CIBH::File->new($path, $create);

Returns a CIBH::File object, which for most purposes is the same as an
IO::All object.  if $create is true then it tries to create the file.  If the
directory doesn't exist it creates the directory as well as the file.

=cut

sub new {
    my ($class, $name, $create) = @_;
    my $self = $class->SUPER::new($name);
    $self->_dirname->mkpath if ($create);
    # if the file doesn't exist and we're not creating it then it's not valid
    if (!$create && !-e $name) {
        return;
    }
    return $self;
}

1;

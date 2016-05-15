package CIBH::File;

use strict;
use warnings;

use IO::File;
use File::Basename qw/ dirname /;
use File::Path qw ( make_path );
use File::Copy qw / move /;
use File::Temp;

use parent qw (IO::File Exporter );
our @EXPORT = qw( O_CREAT O_RDWR O_TRUNC O_WRONLY O_RDONLY SEEK_END SEEK_SET );


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

sub mv {
    my ($filename, $new)=(@_);
    make_path(dirname($new));
    move($filename, $new);
}

=head2 overwrite

    CIBH::File::overwrite($filename,$output);

Safely* overwrites a file by opening a tempfile, writing the contents then
moving that over the existing file.

* Yes, this doesn't look for people doing shenanigans like sockets, links or
other things, but it's primary purpose is to eliminate the unlink race
condition.  My primary concern was making sure a file opened by the web
interface was fully written.

=cut

sub overwrite {
    my ($file,$contents) = (@_);
    my $mode = 0644; ## no critic
    if ( -e $file ) {
        $mode = sprintf '%04o', (stat $file)[2] & 07777;  ## no critic
    }
    my $tmp=File::Temp->new( UNLINK => 0 );
    print $tmp $contents;
    close($tmp);
    chmod($mode, $tmp->filename);
    mv($tmp->filename,$file);
}

=head2 METHODS

=cut

=head2 size

Returns the handles size.

=head2 atime

Returns the handles last access time.

=head2 mtime

Returns the handles last modified time.

=head2 ctime

Returns the handles creation time.

=cut

sub size { ($_[0]->stat)[7] };
sub atime { ($_[0]->stat)[8] };
sub mtime { ($_[0]->stat)[9] };
sub ctime { ($_[0]->stat)[10] };

=head2 new

    my $fileio = CIBH::File->new($path, $flags);

Returns a CIBH::File object, which for most purposes is the same as an
IO::File object.  if $create is true then it tries to create the file.  If the
directory doesn't exist it creates the directory as well as the file.

=cut

sub new {
    my ($class, $name, $flags) = @_;
    $flags=O_RDWR|O_CREAT if (!defined($flags));
    my $created=0;

    ERROR:
    my $handle =  $class->SUPER::new($name, $flags);
    if(!defined $handle) {
        # attempt to create the directory once
        if($!=~/directory/ && !$created && $flags & O_CREAT) {
            make_path(dirname($name));
            $created=1;
            next ERROR;
        }
    }
    return $handle;
}

1;

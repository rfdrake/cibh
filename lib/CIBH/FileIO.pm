package CIBH::FileIO;

use strict;
use warnings;

use IO::File;
use File::Path qw( make_path );
use File::Basename qw/ dirname /;
use File::Temp;
use File::Copy qw / move /;

=head1 NAME

CIBH::FileIO - Module for functions dealing with File IO

=head1 SYNOPSIS

   use CIBH::FileIO;

=head1 DESCRIPTION

These functions are for dealing with File IO and mainly consist of things I
found in multiple places in the code, or, in the case of handle, just
an attempt to move all the File:: modules into one place to clean things up.

This might be a bad idea.  If it causes confusion someone can kick me later.

=head1 AUTHOR

Robert Drake, rdrake@cpan.org

=head1 SUBROUTINES

=head2 mv

    mv($oldfile, $newfile);

Moves a file from one place to another.  If the new directory does not exist
it will create it.  This is different from a normal move and shouldn't be used
unless needed.

=cut

sub mv {
    my ($filename, $new)=(@_);
    ERROR:
    while(!move($filename, $new)) {
        if ($!=~ /directory/) {
            make_path(dirname($new));
            next ERROR;
        }

        last;
    }
}

=head2 Open

    my $handle = Open($filename, $flags);

Given a filename it will return a filehandle.  If the directory doesn't exist
it will create it and retry.

=cut

sub Open {
    my($filename,$flags)=(@_);
    $flags=O_RDWR|O_CREAT unless $flags;
    if (-s $filename) {
        return IO::File->new($filename, $flags);
    } else {
        my $handle;
        ERROR:
        while (!($handle=IO::File->new($filename, $flags))) {
            if($!=~/directory/) {
                make_path(dirname($filename));
                next ERROR;
            }
            last;
        }
        return $handle;
    }
}

=head2 handle

    my $handle = handle($filename);

Wrapper for IO::File->new();

=cut

sub handle {
    IO::File->new($_[0]);
}

=head2 overwrite

    CIBH::FileIO::overwrite($filename,$output);

Safely* overwrites a file by opening a tempfile, writing the contents then
moving that over the existing file.

* Yes, this doesn't look for people doing shennanigans like sockets, links or
other things, but it's primary purpose is to eliminate the unlink race
condition.

=cut

sub overwrite {
    my ($file,$out) = (@_);
    my $mode = sprintf '%04o', (stat $file)[2] & 07777;
    my $tmp=File::Temp->new( UNLINK => 0 );
    my $tmp_name = $tmp->filename;
    print $tmp $out;
    close($tmp);
    chmod($mode, $tmp_name);
    mv($tmp_name,$file);
}

1;

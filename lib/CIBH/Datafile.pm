package CIBH::Datafile;

# Copyright (c) 2000 Peter Whiting (Sprint). All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

use strict;
use Carp;
use IO::File;
use File::Path qw( make_path );
use Math::BigInt try => 'GMP';
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw( $FORMAT $RECORDSIZE );

our $FORMAT = 'NQ<';
our $RECORDSIZE = 12;

our $VERSION = '1.00';

=head1 NAME

CIBH::Datafile - Perl extension for dealing with files of snmp data

=head1 SYNOPSIS

  use CIBH::Datafile;

=head1 DESCRIPTION

Routines for accessing and storing graph data.  Some of these use scaling and
sampling, which I think should be handled in a "display" module but haven't
figured out where to move them.  I'm leaving them here because they don't hurt
anything.

=head1 AUTHOR

Pete Whiting, pwhiting@sprint.net

=head1 SEE ALSO

CIBH::Win, CIBH::Chart, CIBH::Fig.

=head1 SUBROUTINES

=head2 Store

This subroutine will open the filename given as the second arguement
and will store the value passed as the first arguement in that
file, as text, overwriting whatever was previously in there.
In the event it fails to open the file it will try to make the
directory the file is in and then retry to open the file.

=cut

sub Store {
    my($filename,$value)=(@_);
    my($handle) = Open($filename,O_WRONLY|O_CREAT|O_TRUNC);
    if(!defined $handle) {
        warn "couldn't open $filename";
        return;
    }
    print $handle $value . "\n";
    close($handle);
    return $value;
}

# the file format will be as follows:
# 4 bytes of timestamp then 12 bytes of value

sub GaugeAppend {
    my($filename,$value)=(@_);
    my($handle) = Open($filename);
    if(!defined $handle) {
        warn "couldn't open $filename";
        return;
    }
    $handle->seek(0,SEEK_END);
    $handle->syswrite(pack($FORMAT,time,$value),$RECORDSIZE);
    return $value;
}

=head2 CounterAppend

    Datafile::CounterAppend($filename,$value,$spikekiller,$maxvalue);

The last recordsize bytes of the file is the most recently read counter value.
It can be used to calculate the gauge value.  The timestamp for this value is
zero.

Maxvalue is optional and if unspecified it defaults to 2**32.  It is used to
determine if the counter has wrapped.

Spikekiller is an insanely high value that can be used to determine if the
device has been rebooted.  This basically says if the sample is > some insane
value the circuit can't achieve in <interval> time then count it as a zero
value.

=cut

sub CounterAppend {
    my($filename,$value,$spikekiller,$maxvalue)=(@_);
    $maxvalue ||= Math::BigInt->new('4294967296'); # 2**32
    my($handle) = Open($filename);
    if(!defined $handle) {
        warn "couldn't open $filename";
        return;
    }
    my $counter=$value;
    my $record;
    $value=Math::BigInt->new("$value"); # make sure value is a BigInt
    $handle->seek(-$RECORDSIZE*2,SEEK_END);
    $handle->read($record,$RECORDSIZE*2);
    my ($oldtime, $zero);
    my $oldcount = Math::BigInt->new();
    my $oldval = Math::BigInt->new();
    ($oldtime,$oldval,$zero,$oldcount)=unpack($FORMAT . $FORMAT, $record);
    #print "$oldtime,$oldval,$oldcount,$value," . time . "\n";
    if($oldtime and $zero == 0) { # modify val to be the delta
        $value->bsub($oldcount);
        $value->badd($maxvalue) if($value<0);  # counter roll/wrap
        $value=$value / int(time-$oldtime+.01);
        if (defined($spikekiller) && $value > $spikekiller) {
            #print "Spikekiller called time: " . time . " because $value > $spikekiller\n";
            $value=0;
        }
    } else { # starting from an empty file
        $value=0;
    }
    sysseek($handle,-$RECORDSIZE,SEEK_END);
    $handle->syswrite(pack($FORMAT . $FORMAT,time,$value,0,$counter),$RECORDSIZE*2);
    return $value;
}

sub Open {
    my($filename,$flags)=(@_);
    $flags=O_RDWR|O_CREAT unless $flags;
    if (-s $filename) {
        return new IO::File $filename, $flags;
    } else {
        my $handle = new IO::File $filename, $flags;
        if(!defined $handle) {
            if($!=~/directory/) {
                my $dir;
                if((($dir)=($filename=~/(.*)\/[^\/]+$/)) && ($dir ne ".")){
                    warn "Creating directory $dir\n";
                    make_path($dir);
                    $handle=new IO::File $filename,$flags;
                }
            }
        }
        return $handle;
    }
}

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {
        handle => undef,
        filename => undef,
        filesize => undef,
        scale => 1.0,
        @_
    };
    bless($self,$class);
    $self->{scale}=1 if($self->{scale}==0);
    $self->File if defined $self->{filename};
    return $self;
}

=head2 File

    $self->File($filename);

Opens a file and sets up the Datafile object.  The filename, handle and
filesize are stored internally.  Errors are returned if the file does not
exist or the name is bogus.

=cut

sub File {
    my($self,$filename)=(@_);

    carp("BOGUS filename: $filename"),return 0
	    if ($filename=~/[\|\;\(\&]/);

    $self->{filename}=$filename if $filename;

    carp("file not available: $self->{filename}\n"),return 0
	    if not -r $self->{filename};

    #warn "filename is " .  $self->{filename} . "\n";

    $self->{handle}=new IO::File "$self->{filename}" or
	    carp("couldn't open $self->{filename}"),return 0;

    my $size = ($self->{handle}->stat)[7];
    $self->{filesize} = $size-4;

    1;
}

=head2 _next_record

    my ($time, $value) = $self->_next_record;

reads the next record and returns it without any modifications.

=cut

sub _next_record {
    my($self)=(@_);
    carp ("no handle"),return () if not defined $self->{handle};
    my($record);
    $self->{handle}->read($record,$RECORDSIZE)==
	    $RECORDSIZE or return ();
    my ($x,$y)=unpack($FORMAT,$record);
#    warn "Record: $x $y\n";
    return $self->_next_record if($x==0);     # bogus value (most likely end of counter file)
    return ($x,$y);
}

=head2 NextRecord

    my ($time, $value) = $self->NextRecord;

This reads the filehandle at it's current location then scales the results
according to whatever output format has been specified and returns it as a
time, value pair.

=cut

sub NextRecord {
    my $self = shift;
    my ($x,$y) = $self->_next_record;
    return () if (not defined $x);
    $y=$y*$self->{scale};
    return ($x,$y);
}



=head2 NextValue

    my (ave_y,$max_y,$last) = $self->NextValue($stop);

read all pairs from the current position in the file to the
last position in the file such that the x value does not exceed
that given by stopx.  Return an average of these values.  More
complex processing (like weighing averages based on the coverage
of the range on the x axis might be something worth trying)
For now, don't worry about overflowing the total (if that was
the case we could just keep track of the average at each step,
then, to add another value do the floating point scale (count/count+1)
of the average and then add in (val/count+1) to the average.  For
now, the values are scaled by nextrecord to fit on a chart so the
values should be small enough.

Purpose: When you ask for a sample between 5:00pm and 5:05pm you might have
two or more data points that match your request.  We need to handle this in some way.
We could return all data points and let the grapher figure it out, but in this
case we are the grapher, so we're doing the processing.  We do this by
averaging the results.

In this case they didn't go by time interval they went by graph resolution, so
the timespan for the average is determined by canvas_width (default 600).
This is usually 1/600*86400=144 seconds or so.

=cut

sub NextValue {
    my($self,$stopx)=(@_);
    carp ("no handle"),return if not defined $self->{handle};

    my($x,$y,$count,$total,$max,$last)=(0,0,0,0,0);

    while(($x,$y)=$self->NextRecord and $x<$stopx) {
        $count++;
        $total+=$y;
        $last=$y;
        $max=$y if($max<$y);
    }

    if( $x > $stopx) {  # back up - this might not be "worth it"
	    $self->{handle}->seek(-$RECORDSIZE,SEEK_CUR);
    }
    return if(not $count);
    $total/=$count;
    #warn "stopx was $stopx\n";
    return wantarray ? ($total,$max,$last):$total;
}

=head2 Sample

    my ($ave, $max, $aveval, $maxval, $curr) = $file->Sample($start,$stop,$step);

# remove scaling of y values.
# change x value to be absolute.

=cut

sub Sample {
    my($self,$start,$stop,$step)=(@_);
    my($x,$ave_y,$max_y,@ave,@max,$total,$maxval,$last,$tmp);
    my($span)=$stop-$start;
    #warn "sample: $start $stop $step $span\n";
    $self->TimeWarp($start);
    for($x=0;$x<1;$x+=$step) {
        ($ave_y,$max_y,$tmp)=$self->NextValue($start+$x*$span);
        next if not defined $ave_y;
        $total+=$ave_y;
        $last=$tmp;
        $maxval=$max_y if($max_y>$maxval);
        push(@ave,[$x,$ave_y]);
        push(@max,[$x,$max_y]);
    }
    if(@ave>0) {  # did we collect any samples
        $total/=(@ave*$self->{scale});
        $maxval/=($self->{scale});
        $last/=($self->{scale});
    }
    return wantarray ? ([@ave],[@max],$total,$maxval,$last) : [@ave];
}

=head2 GetValues

    my $values = $file->GetValues($start,$stop);

Returns an arrayref of time, value pairs that are between start and stop
times.  This does no sample averaging or scaling or normalizing of the time.
All processing is left up to the calling charting application.

=cut

sub GetValues {
    my ($self,$start,$stop)=(@_);
    my $output = [];
    $self->TimeWarp($start);
    while(my ($x,$y)=$self->_next_record and $x<$stop) {
        push(@$output, { $x => $y });
    }
    return $output;
}

# return the first value whose x value is greater than that passed
# in as startx.  This should be faster than next value because it
# isn't calculating an average and it doesn't have to read past
# the last value.  For this routine you also need to return the
# x value because it can be anything.

sub FirstValue {
    my($self,$startx)=(@_);
    carp ("no handle"),return () if not defined $self->{handle};
    my($x,$y);
    while(($x,$y)=$self->NextRecord and $x<$startx){  }
    return if($x<$startx);
    return ($x,$y);
}

=head2 TimeWarp

Try to Binary search through the dataset to find the last
sample with time less than the time passed as the argument.
Since you don't know the sample distance, estimate it and then
continue to upgrade your estimate.

I think this is premature optimization.  At least now that disk I/O is faster,
people have more memory and the fact that long reads are always better than
seeks.  The reason for my theory is that 12 bytes/sample * 12 samples/hour *
24 hours/day * 365 = 1.2Mb.

Small enough to fit in the read-ahead cache of the OS most likely.  Even at 10
years or faster sampling you should be able to read the whole file as fast as
you can seek around.

So, when we were on a sparc with maybe 512Mb of ram, this made
sense, but now I think it's overly complicated.

=cut

sub TimeWarp {
    my($self,$start)=(@_);
    carp ("no handle"),return if not defined $self->{handle};
    my($mid);
    my($head)=0;
    my($tail)=int($self->{filesize}/$RECORDSIZE-1);
    my($x,$y);
    while($head<$tail-1) {
        #warn "Warp1: $start $head $tail";
        $mid=int(($tail+$head)/2);
        last if(not (($x,$y)=$self->GetRecord($mid)));
        if($x<$start) {
            $head=$mid+1;
        } else {
            $tail=$mid-1;
        }
    }
    #warn "Warp: $head $tail";
}



sub GetRecord {
    my($self,$rec)=(@_);
    carp ("no handle"),return () if not defined $self->{handle};
    $self->{handle}->seek($rec*$RECORDSIZE,SEEK_SET);
    return $self->_next_record;
}


# return x value (time) of first record
sub GetStart {
    my($self)=(@_);
    carp ("no handle"),return if not defined $self->{handle};
    my($pos)=$self->{handle}->tell;
    $self->{handle}->seek(0,SEEK_SET);
    my($x)=$self->_next_record;
    $self->{handle}->seek($pos,SEEK_SET);
    return($x);
}

sub GetStop {
    my($self)=(@_);
    carp ("no handle"), return if not defined $self->{handle};
    my($pos)=$self->{handle}->tell;
    $self->{handle}->seek(-$RECORDSIZE,SEEK_END);
    my($x)=$self->_next_record;
    $self->{handle}->seek($pos,SEEK_SET);
    return($x);
}

1;

package CIBH::DS::Datafile;

# Copyright (C) 2000 Peter Whiting (Sprint). All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

use strict;
use Carp;
use CIBH::FileIO;
use IO::File;
use Math::BigInt try => 'GMP,Pari';
require Exporter;
use v5.14;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw( $FORMAT $RECORDSIZE $TIMESIZE );

use constant MAX64 => Math::BigInt->new(2)->bpow(64);
our $FORMAT = 'NQ<';
our $RECORDSIZE = length pack $FORMAT;

our $VERSION = '1.00';

=head1 NAME

CIBH::DS::Datafile - Perl extension for dealing with files of SNMP data

=head1 SYNOPSIS

  use CIBH::DS::Datafile;

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

    my $value = CIBH::DS::Datafile::Store($hash);

This subroutine will open the filename given as the hash->{file}
argument and will store the value passed as the hash->{value} argument
in that file, as text, overwriting whatever was previously in there.
In the event it fails to open the file it will try to make the
directory the file is in and then retry to open the file.

=cut

sub Store {
    my ($hash)=(@_);
    my $filename = "$hash->{file}.text";
    my $value = $hash->{value};

    my($handle) = CIBH::FileIO::Open($filename,O_WRONLY|O_CREAT|O_TRUNC);
    if(!defined $handle) {
        warn "couldn't open $filename";
        return;
    }
    print $handle $value . "\n";
    close($handle);
    return $value;
}

=head2 GaugeAppend

    my $value = CIBH::DS::Datafile::GaugeAppend($hash);

This subroutine will open the $hash->{file} and seek to the end, then store a
timestamp and the value passed as $hash->{value}.  On success the value is
returned.

=cut

sub GaugeAppend {
    my ($hash)=(@_);
    my $filename = $hash->{file};
    my $value = $hash->{value};

    my($handle) = CIBH::FileIO::Open($filename);
    if(!defined $handle) {
        warn "couldn't open $filename";
        return;
    }
    $handle->seek(0,SEEK_END);
    $handle->syswrite(pack($FORMAT,time,$value),$RECORDSIZE);
    return $value;
}

=head2 OctetsAppend

    my $value = CIBH::DS::Datafile::OctetsAppend($hash);

Wrapper for CounterAppend for 32 bit values.

Because historically we save things in bits/sec we need to multiply the
incoming value by 8.

=cut

sub OctetsAppend {
    my($hash)=(@_);
    return CounterAppend($hash->{file},$hash->{value}*8,$hash->{spikekiller});
}

=head2 OctetsAppend64

    my $value = CIBH::DS::Datafile::OctetsAppend64($hash);

Wrapper for CounterAppend for 64 bit values.

Because historically we save things in bits/sec we need to multiply the
incoming value by 8.

=cut

sub OctetsAppend64 {
    my($hash)=(@_);
    return CounterAppend($hash->{file},$hash->{value}*8,$hash->{spikekiller}, MAX64);
}

=head2 CounterAppend

    CIBH::DS::Datafile::CounterAppend($filename,$value,$spikekiller,$maxvalue);

The last recordsize bytes of the file is the most recently read counter value.
It can be used to calculate the gauge value.  The timestamp for this value is
zero.

Maxvalue is optional and if unspecified it defaults to 2**32.  It is used to
determine if the counter has wrapped.

Spikekiller is an insanely high value that can be used to determine if the
device has been rebooted.  This basically says if the sample is > some insane
value the circuit can't achieve in <interval> time then count it as a zero
value.

FWIW, storing time in seconds limits the precision of this datastore to 1
second resolution.

=cut

sub CounterAppend {
    my($filename,$value,$spikekiller,$maxvalue)=(@_);
    $maxvalue ||= Math::BigInt->new('4294967296'); # 2**32
    my $handle = CIBH::FileIO::Open($filename);
    if(!defined $handle) {
        warn "couldn't open $filename";
        return;
    }
    my $counter=$value;
    my $record;
    $value=Math::BigInt->new($value); # make sure value is a BigInt
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

=head2 new

    my $ds = CIBH::DS::Datafile->new(filename=>$file);
    my $ds = CIBH::DS::Datafile->new(opts=>$opts,host=>$host,metric=>$metric,debug=>0);

Returns an OO handle for the Datafile datasource.  This is needed to read from
files, while the writing is done via non-OO methods.

If you specify opts, host, metric then the filename is constructed by saying
$filename = $opts->{data_path}/$host/$metric.  This will be used in the future
to be compatible with the syntax for other datasources.

You can also specify debug=>1 to turn on warnings from certian functions.

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {
        handle => undef,
        filename => undef,
        filesize => undef,
        scale => 1.0,
        opts => {},
        debug => 0,
        @_
    };
    bless($self,$class);
    $self->{scale}=1 if($self->{scale}==0);
    if ($self->{opts}->{data_path} && $self->{host} && $self->{metric}) {
        $self->{filename}="$self->{opts}->{data_path}/$self->{host}/$self->{metric}";
    }
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

    $self->{handle}=CIBH::FileIO::handle($self->{filename}) or
        carp("couldn't open $self->{filename}"),return 0;

    my $size = ($self->{handle}->stat)[7];
    $self->{filesize} = $size;
    return $self;
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
We could return all data points and let the grapher figure it out, but in the
case of Chart.pm/CGI chart, we are the grapher, so we're doing the processing.
We do this by averaging the results.

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

    if($x > $stopx) {
        $self->{handle}->seek(-$RECORDSIZE,SEEK_CUR);
    }
    return if(not $count);
    $total/=$count;
    warn "stopx was $stopx, total=$total,max=$max,last=$last\n" if ($self->{debug});
    return ($total,$max,$last);
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
    warn "sample: $start $stop $step $span\n" if ($self->{debug});
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
    my ($x, $y);
    while(($x,$y)=$self->_next_record and $x<$stop) {
        push(@$output, { $x => $y });
    }
    return $output;
}

=head2 FirstValue
    my ($x, $y) = $file->FirstValue($startx);

return the first value whose x value is greater than that passed
in as startx.  This should be faster than next value because it
isn't calculating an average and it doesn't have to read past
the last value.  For this routine you also need to return the
x value because it can be anything.

=cut

sub FirstValue {
    my($self,$startx)=(@_);
    carp ("no handle"),return () if not defined $self->{handle};
    my($x,$y);
    while(($x,$y)=$self->NextRecord and $x<$startx) { }
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
    my $head=0;
    # subtract the last record, which would be the counter in counterappend
    # then subtract one from our total records so this averaging thing works
    my $tail=int(($self->{filesize}-$RECORDSIZE)/$RECORDSIZE-1);
    my($x,$y);
    while($head<$tail-1) {
        warn "Warp1: $start $head $tail" if ($self->{debug});
        my $mid=int(($tail+$head)/2);
        last if(not (($x,$y)=$self->GetRecord($mid)));
        if($x<$start) {
            $head=$mid+1;
        } else {
            $tail=$mid-1;
        }
    }
    warn "Warp: $head $tail" if ($self->{debug});
}

=head2 GetRecord

    my ($x, $y) = $self->GetRecord($recordnum);

Seeks to the position of the recordnum and fetches the record.  This is used
by TimeWarp.

=cut

sub GetRecord {
    my($self,$rec)=(@_);
    carp ("no handle"),return () if not defined $self->{handle};
    $self->{handle}->seek($rec*$RECORDSIZE,SEEK_SET);
    return $self->_next_record;
}

1;

package CIBH::Datafile;

# Copyright (c) 2000 Peter Whiting (Sprint). All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
use Carp;
use IO::File;
use AutoLoader 'AUTOLOAD';

use constant FORMAT => 'NQ';
use constant RECORDSIZE => 12;
use constant NRECORDSIZE => -12;


require Exporter;

@ISA = qw(Exporter);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw();
$VERSION = '1.00';


# Preloaded methods go here.

# This subroutine will open the filename given as the second arguement
# and will store the value passed as the first arguement in that
# file, as text, overwriting whatever was previously in there.
# In the event it fails to open the file it will try to make the
# directory the file is in and then retry to open the file.

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
    $handle->syswrite(pack(FORMAT,time,$value),RECORDSIZE);
    return $value;
}

# The last recordsize bytes of the file
# is the most recently read counter value.  It can be
# used to calculate the gauge value.  The timestamp
# for this value is zero.

# Input: filename, value, maxvalue (for counter roll, default 32bit)
#        value needs to be in bits

sub CounterAppend {
    my($filename,$value,$spikekiller,$maxvalue)=(@_);
    $maxvalue ||= 0xFFFFFFFF;
    my($handle) = Open($filename);
    if(!defined $handle) {
        warn "couldn't open $filename";
        return;
    }
    my $counter=$value;
    my $record;
    $handle->seek(NRECORDSIZE*2,SEEK_END);
    $handle->read($record,RECORDSIZE*2);
    my($oldtime,$oldval,$zero,$oldcount)=unpack(FORMAT . FORMAT,$record);
#    print "$oldtime,$oldval,$oldcount,$val," . time . "\n";
    if($oldtime and $zero == 0) { # modify val to be the delta
        $value-=$oldcount;
        $value+=$maxvalue if($value<0);  # counter roll/wrap
        $value=int($value/(time-$oldtime+.01));
        if (defined($spikekiller) && $value > $spikekiller) {
            $value=0;
        }
    } else { # starting from an empty file
        $value=0;
    }
    sysseek($handle,NRECORDSIZE,SEEK_END);
    $handle->syswrite(pack(FORMAT . FORMAT,time,$value,0,$counter),RECORDSIZE*2);
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
                    system("mkdir -p $dir");
                    $handle=new IO::File $filename,$flags;
                }
            }
        }
        return $handle;
    }
}


# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__
# Below is the stub of documentation for your module. You better edit it!

=head1 NAME

CIBH::Datafile - Perl extension for dealing with files of snmp data

=head1 SYNOPSIS

  use CIBH::Datafile;

=head1 DESCRIPTION

=head1 AUTHOR

Pete Whiting, pwhiting@sprint.net

=head1 SEE ALSO

CIBH::Win, CIBH::Chart, CIBH::Fig.

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {
        handle => undef,
        filename => undef,
        filesize => undef,
        scale => 1.0,
        offset => 0,
        @_
    };
    bless($self,$class);
    $self->{scale}=1 if($self->{scale}==0);
    $self->File if defined $self->{filename};
    return $self;
}

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

    my($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
       $atime,$mtime,$ctime,$blksize,$blocks)
	= $self->{handle}->stat;

    $self->{filesize} = $size-4;

    1;
}


sub Scale {
    my($self,$scale)=(@_);
    if($scale) {
	    $self->{scale}=$scale;
    }
    return $self->{scale};
}

sub Offset {
    my($self,$offset)=(@_);
    if(defined $offset) {
	    $self->{offset}=$offset;
    }
    return $self->{offset};
}

sub NextRecord {
    my($self)=(@_);
    carp ("no handle"),return () if not defined $self->{handle};
    my($record,$x,$y);
    $self->{handle}->read($record,RECORDSIZE)==
	    RECORDSIZE or return ();
    ($x,$y)=unpack(FORMAT,$record);
#    warn "Record: $x $y\n";
    return $self->NextRecord if($x==0);
# bogus value (most likely end of counter file)
    $y=($y+$self->{offset})*$self->{scale};
    return ($x,$y);
}


# read all pairs from the current position in the file to the
# last position in the file such that the x value does not exceed
# that given by stopx.  Return an average of these values.  More
# complex processing (like weighing averages based on the coverage
# of the range on the x axis might be something worth trying)
# For now, don't worry about overflowing the total (if that was
# the case we could just keep track of the average at each step,
# then, to add another value do the floating point scale (count/count+1)
# of the average and then add in (val/count+1) to the average.  For
# now, the values are scaled by nextrecord to fit on a chart so the
# values should be small enough.

sub NextValue {
    my($self,$stopx)=(@_);
    carp ("no handle"),return undef if not defined $self->{handle};

    my($x,$y,$count,$total,$max,$last)=(0,0,0,0,0);

    while(($x,$y)=$self->NextRecord and $x<$stopx) {
        $count++;
        $total+=$y;
        $last=$y;
        $max=$y if($max<$y);
    }
# check the direction pete - this might be backwards..

    if($x>$stopx ) {  # back up - this might not be "worth it"
	$self->{handle}->seek(NRECORDSIZE,SEEK_CUR);
    }
    return undef if(not $count);
    $total/=$count;
    #warn "stopx was $stopx\n";
    return wantarray ? ($total,$max,$last):$total;
}

# remove scaling of y values.
# change x value to be absolute.
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
    return undef if($x<$startx);
    return ($x,$y);
}

# Try to Binary search through the dataset to find the last
# sample with time less than the time passed as the arguement.
# Since you don't know the sample distance, estimate it and then
# continue to upgrade your estimate.

sub TimeWarp {
    my($self,$start)=(@_);
    carp ("no handle"),return undef if not defined $self->{handle};
    my($mid);
    my($head)=0;
    my($tail)=int($self->{filesize}/RECORDSIZE-1);
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
    $self->{handle}->seek($rec*RECORDSIZE,SEEK_SET);
    return $self->NextRecord;
}


# return x value (time) of first record
sub GetStart {
    my($self)=(@_);
    carp ("no handle"),return undef if not defined $self->{handle};
    my($pos)=$self->{handle}->tell;
    $self->{handle}->seek(0,SEEK_SET);
    my($x)=$self->NextRecord;
    $self->{handle}->seek($pos,SEEK_SET);
    return($x);
}

sub GetStop {
    my($self)=(@_);
    carp ("no handle"), return undef if not defined $self->{handle};
    my($pos)=$self->{handle}->tell;
    $self->{handle}->seek(NRECORDSIZE,SEEK_END);
    my($x)=$self->NextRecord;
    $self->{handle}->seek($pos,SEEK_SET);
    return($x);
}

1;

package CIBH::DS::Datafile;

# Copyright (C) 2000 Peter Whiting (Sprint). All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

use strict;
use Carp;
use CIBH::File;
use Math::BigInt try => 'GMP,Pari';
require Exporter;
use v5.14;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw( $FORMAT $RECORDSIZE );

use constant MAX64 => Math::BigInt->new(2)->bpow(64);
use constant MAX32 => Math::BigInt->new('4294967296'); # 2**32
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

    my $handle = CIBH::File->new($filename,O_WRONLY|O_CREAT|O_TRUNC);
    if(!defined $handle) {
        warn "can't open $filename";
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

    my($handle) = CIBH::File->new($filename,O_RDWR|O_CREAT);
    if(!defined $handle) {
        warn "can't open $filename";
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
    $_[0]->{maxvalue} = MAX32;
    $_[0]->{value} *= 8;
    goto &CounterAppend;
}

=head2 OctetsAppend64

    my $value = CIBH::DS::Datafile::OctetsAppend64($hash);

Wrapper for CounterAppend for 64 bit values.

Because historically we save things in bits/sec we need to multiply the
incoming value by 8.

=cut

sub OctetsAppend64 {
    $_[0]->{value} *= 8;
    goto &CounterAppend;
}

=head2 CounterAppend

    CIBH::DS::Datafile::CounterAppend($hashref);

Arguments: spikekiller, value, file, maxvalue, time
Returns: value (which is modified from the input value)

The last recordsize bytes of the file is the most recently read counter value.
It can be used to calculate the gauge value.  The timestamp for this value is
zero.

Maxvalue is optional and if unspecified it defaults to MAX64.  It is used to
determine if the counter has wrapped.

Spikekiller is an insanely high value that can be used to determine if the
device has been rebooted.  This basically says if the sample is > some insane
value the circuit can't achieve in <interval> time then count it as a zero
value.

Time is optional and used for testing.  If unspecified the current time is
used.

For what it's worth, storing time in seconds limits the precision of this data
store to 1 second resolution.

=cut

sub CounterAppend {
    my $args = shift;
    return if (!defined($args->{file}) or !defined($args->{value}));

    my $value = $args->{value};
    my $maxvalue = $args->{maxvalue} || MAX64;
    my $time = $args->{time} || time;
    my $handle = IO::File->new($args->{file},O_RDWR|O_CREAT);
    if(!defined $handle) {
        warn "Can't open $args->{file}";
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
    #print "$oldtime,$oldval,$oldcount,$value,$time\n";
    if($oldtime and $zero == 0) { # modify val to be the delta
        $value->bsub($oldcount);
        $value->badd($maxvalue) if($value<0);  # counter roll/wrap
        $value->bdiv($time-$oldtime);
        if (defined($args->{spikekiller}) && $value > $args->{spikekiller}) {
            #print "Spikekiller called at time: $time because $value > $args->{spikekiller}\n";
            $value=0;
        }
    } else { # starting from an empty file
        $value=0;
    }
    sysseek($handle,-$RECORDSIZE,SEEK_END);
    $handle->syswrite(pack($FORMAT . $FORMAT,$time,$value,0,$counter),$RECORDSIZE*2);
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

You can also specify debug=>1 to turn on warnings from certain functions.

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {
        handle => undef,
        filename => undef,
        filesize => undef,
        opts => {},
        debug => 0,
        @_
    };
    bless($self,$class);
    if ($self->{opts}->{data_path} && $self->{host} && $self->{metric}) {
        $self->{filename}="$self->{opts}->{data_path}/$self->{host}/$self->{metric}";
    }
    $self->File if defined $self->{filename};
    return $self;
}

=head2 File

    $self->File($filename);

Opens a file and sets up the Datafile object.  The filename, handle and
file size are stored internally.  Errors are returned if the file does not
exist or the name is bogus.

=cut

sub File {
    my($self,$filename)=(@_);
    $filename ||= $self->{filename};

    carp("BOGUS filename: $filename"),return 0
        if ($filename=~/[\|\;\(\&]/);

    carp("file not available: $filename\n"),return 0
        if not -r $filename;

    $self->{handle}=CIBH::File->new($filename,O_RDONLY) or
        carp("couldn't open $filename"),return 0;

    $self->{filename}=$filename;
    $self->{filesize} = ($self->{handle}->stat)[7];
    return $self;
}

=head2 _next_record

    my ($time, $value) = $self->_next_record;

Reads the next record and returns it without any modifications.

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
        push(@$output, [ $x, $y ]);
    }
    return $output;
}

=head2 FirstValue
    my ($x, $y) = $file->FirstValue($startx);

Return the first value whose x value is greater than that passed
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

So, when we were on a Sparc with maybe 512Mb of ram, this made
sense, but now I think it's overly complicated.

---

With further thought, I still think a binsearch is best for what we're trying
to do, but seeking through the file isn't needed.  We might mmap the file
instead to treat it like an array.

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

# This is used to initialize things during module load.  I didn't use import
# because options might need to be passed and we also aren't loading the
# module normally.
sub _ds_init {}

1;

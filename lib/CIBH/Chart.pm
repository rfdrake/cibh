package CIBH::Chart;

# Copyright (c) 2000 Peter Whiting (Sprint). All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

=head1 NAME

CIBH::Chart - Perl extension charting data

=head1 SYNOPSIS

  use CIBH::Chart;

=head1 DESCRIPTION

This is mainly a low-level library for building the charts using GD.  Higher
level functions like Sampling and composing the graph were left up to either
Datafile or cgi-bin/chart.  I'm now trying to abstract those into another
module (at least the parts that need to be reused by d3chart)

=head1 AUTHOR

Pete Whiting pwhiting@sprint.net

=head1 SEE ALSO

CIBH::DS::Datafile, CIBH::Win, CIBH::Fig.

=cut

use strict;
use warnings;
use GD;
use CIBH::Win;
use Time::Local;

=head2 GetHourBoundaries

returns a list of list refs, each list ref points to a list
of two values: the x position (0-1) and the hour info

=cut

sub GetHourBoundaries {
    my($start,$stop,$stride)=(@_);
    my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
        localtime($start);
    my($first_hour)=$start+(59-$min)*60+(60-$sec);
    $hour++;
    my(@rval);
    my($marks)=4;
    while($first_hour<$stop) {
        my $minors;
        my($x)=($first_hour-$start)/($stop-$start);
        my($dx)=(3600*$stride/$marks)/($stop-$start);
        for(my $i=0;$i<$marks;$i++) {
            push(@{$minors},$x+$i*$dx);
            # the following line takes care of the small ticks in front
            # of the first major tick
            push(@{$minors},$x-$i*$dx) if not @rval;
        }
        push(@rval,[$x,$hour,$minors]);
        $hour=($hour+$stride)%24;
        $first_hour+=3600*$stride;
    }
    return wantarray ? @rval : [@rval];
}

=head2 GetDayBoundaries

returns a list of list refs, each list ref points to a list
of two values: the x position (0-1) and the hour info

=cut

sub GetDayBoundaries {
    my($start,$stop)=(@_);
    my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
        localtime($start);
    my($first_day)=$start+(23-$hour)*3600+(59-$min)*60+(60-$sec);
    my($marks)=6; # 6 tick marks per day = one every 4 hours
    my(@rval);
    while($first_day<$stop) {
        my($dx)=(86400/$marks)/($stop-$start);
        my($x)=($first_day-$start)/($stop-$start);
        my($minors);
        for(my $i=0;$i<$marks;$i++) {
            push(@{$minors},$x+$i*$dx);
            push(@{$minors},$x-$i*$dx) if not @rval;
        }
        ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
            localtime($first_day);
        $mon++;
        push(@rval,[$x,"$mon/$mday",$minors]);
        $first_day+=86400;
    }
    return wantarray ? @rval : [@rval];
}

=head2 GetWeekBoundaries

returns a list of list refs, each list ref points to a list
of two values: the x position (0-1) and the hour info

=cut
sub GetWeekBoundaries {
    my($start,$stop)=(@_);
    my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
        localtime($start);
    my($first_week)=$start+(6-$wday)*86400+(23-$hour)*3600+(59-$min)*60+$sec;
    my(@rval);
    my($marks)=7;
    while($first_week<$stop) {
        my($dx)=(86400*7/$marks)/($stop-$start);
        my($x)=($first_week-$start)/($stop-$start);
        my($minors);
        for(my $i=0;$i<$marks;$i++) {
            push(@{$minors},$x+$i*$dx);
            push(@{$minors},$x-$i*$dx) if not @rval;
        }
        ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
            localtime($first_week);
        $mon++;
        push(@rval,[$x,"$mon/$mday",$minors]);
        $first_week+=86400*7;
    }
    return wantarray ? @rval : [@rval];
}


=head2 GetMonthBoundaries

returns a list of list refs, each list ref points to a list
of two values: the x position (0-1) and the hour info

=cut

sub GetMonthBoundaries {
    my($start,$stop)=(@_);
    my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
        localtime($start);
    # som: start of month
    my($som)=timelocal(0,0,0,1,$mon,$year);
    my(@rval);

    # about this many months.  We want about 10 boundaries...
    my($stride)=86400*32*int(1+($stop-$start)/(86400*32*10));

    my $minors;
    while($som<$stop) {
        my($x)=($som-$start)/($stop-$start);
        ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
            localtime($som);
        $year%=100;
        $mon+=1;
        push(@rval,[$x,"$mon/$year",$minors]);
        ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
            localtime($som+$stride);
        $som=timelocal(0,0,0,1,$mon,$year);
    }
    return wantarray ? @rval : [@rval];
}


=head2 GetBoundaries

    my $boundaries = GetBoundaries($start,$stop,$max);

Returns a list of refs, each lists of refs points to a list of two values: the
x position and the hour info.  This calls Get(Hour|Day|Week|Month)Boundaries
according to how long the max time is.

=cut

sub GetBoundaries {
    my($start,$stop,$max)=(@_);

    return GetHourBoundaries($start,$stop,1)
        if(($stop-$start)/(1800) < $max );
    return GetHourBoundaries($start,$stop,2)
        if(($stop-$start)/(3600*2) < $max );
    return GetDayBoundaries($start,$stop)
        if(($stop-$start)/(86400) < $max);
    return GetWeekBoundaries($start,$stop)
        if(($stop-$start)/(86400*5) < $max);
    return GetMonthBoundaries($start,$stop);

}

=head2 GetUnits

    my $units = GetUnits($start,$stop,$count);

Convienence function for Units() which runs with ($stop-$start)/$count.

=cut

sub GetUnits {
    my($start,$stop,$count)=(@_);
    return Units(($stop-$start)/$count);
}

=head2 Units

    my $units = Units($stride);

Given a number, determine what unit would best be used for it in output.
Returns a list of a divisor and a unit name.

=cut

sub Units {
    my($stride)=(@_);
    return (1/1e9,'G') if($stride>1e9);
    return (1/1e6,'M') if($stride>1e6);
    return (1/1e3,'K') if($stride>1e3);
    return (1,'');
}

=head2 GetNumericBoundaries

this routine returns a list of $count boundaries -
each element is a pair - a position (between 0 and 1)
and a value to print, it you want...

=cut

sub GetNumericBoundaries {
    my($start,$stop,$count)=(@_);
    $count--;
    my($stride)=($stop-$start)/$count;

    my($scale,$label)=GetUnits($start,$stop,$count);
    my(@rval);
    for(my $i=0;$i<=$count;$i++) {
        my($pos)=$i/$count;
        push(@rval,[$pos,int(($stop-$start)*$scale*$pos)."$label"]);
    }
    return wantarray ? @rval : [@rval];
}

=head2 StringLength

    my $length = StringLength($str,$font);

Returns the length of the string in the image.  This should be in pixels I
think.

=cut

sub StringLength {
    my($str,$font)=(@_);
    length($str)*$font->width;
}

=head2 GetColor

    my ($color) = $self->GetColor($red, $green, $blue);

Given red, green, and blue value return a color thing from
image->colorAllocate/colorExact.

=cut

sub GetColor {
    my($self,$r,$g,$b)=(@_);
    return if !defined $r || !defined $g || !defined $b;
    my($color)=($self->{image}->colorExact($r,$g,$b));
    if ($color == -1) {
        $color=$self->{image}->colorAllocate($r,$g,$b);
    }
    return $color;
}

=head2 Color

    my ($color) = $self->Color("$red,$green,$blue");

Given a red, green, and blue value as a string return a color thing from
$self->GetColor;  Does not handle undefined values well.

=cut

sub Color {
    $_[0]->GetColor(split(',',$_[1]));
}

=head2 Bright

    my $color = Bright('255,0,255');

Given RGB values this will try to turn them to a brighter color.  Returns an
RGB value.

=cut

sub Bright {
    my(@rval);
    foreach my $val (split(",",$_[0])) {
        push(@rval,int(($val*2+255*3)/5));
    }
    return join(',',@rval);
}

=head2 Dark

    my $color = Dark('255,0,255');

Given RGB values this will try to turn them to a darker color.  Returns an
RGB value.

=cut

sub Dark {
    my(@rval);
    foreach my $val (split(",",$_[0])) {
        push(@rval,($val/1.5));
    }
    return join(',',@rval);
}

=head2 Brighten

    my $newcolor = Brighten($color);

Wrapper for Color(Bright($color))

=cut

sub Brighten {
    $_[0]->Color(Bright($_[1]));
}

=head2 Darken

    my $newcolor = Darken($color);

Wrapper for Color(Dark($color))

=cut

sub Darken {
    $_[0]->Color(Dark($_[1]));
}

=head2 new

    my $chart = CIBH::Chart->new($opts);

Makes a new chart object.

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $this = {
        canvas_width => 600,
        canvas_height => 200,
        left_scale_width => 50,
        right_scale_width => 40,
        top_scale_height => 40,
        bottom_scale_height => 40,
        text_area_height => 60,
        cursor_y => 1,
        background => '255,255,255',
        transparent => 1,
        no_image => 0, # don't create an image
        @_
    };

    $this->{width}=
        $this->{canvas_width} +
            $this->{left_scale_width} +
                $this->{right_scale_width} + 3;
    $this->{height}=
        $this->{canvas_height}+
            $this->{top_scale_height} +
                $this->{bottom_scale_height} +
                    $this->{text_area_height} + 4;

    $this->{image} = GD::Image->new($this->{width},$this->{height})
       if ($this->{no_image}==0);

    bless($this,$class);

    $this->{image}->transparent($this->Color($this->{background}))
        if($this->{transparent} and $this->{image});

    $this->BuildWindows;

    return $this;
}

=head2 BuildWindows

=cut

sub BuildWindows {
    my($this)=(@_);

    $this->{canvas} = CIBH::Win->new(x      => $this->{left_scale_width} + 1,
            y      => $this->{canvas_height}+$this->{top_scale_height} + 1,
            width  => $this->{canvas_width},
            height => $this->{canvas_height});

    $this->{left} = CIBH::Win->new(x      => 0,
            y      => $this->{canvas_height}+$this->{top_scale_height} + 1,
            width  => $this->{left_scale_width},
            height => $this->{canvas_height});

    $this->{right} = CIBH::Win->new(x      => $this->{width}-$this->{right_scale_width} - 1,
            y      => $this->{canvas_height}+$this->{top_scale_height} + 1,
            width  => $this->{right_scale_width},
            height => $this->{canvas_height});

    $this->{top} = CIBH::Win->new(x      => $this->{left_scale_width} + 1,
            y      => $this->{top_scale_height},
            width  => $this->{canvas_width},
            height => $this->{top_scale_height});

    $this->{bottom} = CIBH::Win->new(x      => $this->{left_scale_width} + 1,
            y      => $this->{height}-$this->{text_area_height} - 2,
            width  => $this->{canvas_width},
            height => $this->{bottom_scale_height});

    $this->{text_area} = CIBH::Win->new(x      => $this->{left_scale_width} + 1,
            y      => $this->{height}-1,
            width  => $this->{canvas_width},
            height => $this->{text_area_height});
}

=head2 CanvasCoords

=cut

sub CanvasCoords {
    return $_[0]->{canvas}->map(0,0,1,1);
}

=head2 Print

=cut

sub Print {
    my($self)=shift;
    my($tmp)={color=>'0,0,0',@_};
    $self->{image}->rectangle(($self->{canvas}->map(0,0,1,1)),
                              $self->Color($tmp->{color}));
    print $self->{image}->png;
}

=head2 YAxis

=cut

sub YAxis {
    my($this)=shift;
    my($tmp)={
        grid_color=>'0,0,0',
        color=>'55,55,55',
        min=>0,
        max=>100,
        major=>10,
        tick_size=>4,
        tick_color=>'0,0,0',
        mode=>'left,grid',
        @_};

    my $labels = GetNumericBoundaries($tmp->{min},$tmp->{max},$tmp->{major}+1);

    if($tmp->{mode} =~ /left/) {
        $this->LeftTicks($this->{left},
                         $tmp->{tick_color},
                         $labels,
                         $tmp->{major},
                         $tmp->{tick_size});
    }
    if($tmp->{mode} =~ /right/) {
        $this->RightTicks($this->{right},
                          $tmp->{tick_color},
                          $labels,
                          $tmp->{major},
                          $tmp->{tick_size});
    }

    if($tmp->{mode} =~ /grid/) {
        $this->HorizontalDemarks($this->{canvas},$tmp->{grid_color},$labels);
    }
}

=head2 XAxis

=cut

sub XAxis {
    my($this)=shift;
    my($tmp)={
        grid_color=>'0,0,0',
        color=>'0,0,0',
        start=>0,
        stop=>1,
        interval=>24.1,
        ticks=>10,
        mode=>'top,bottom',
        @_ };

    my $labels=GetBoundaries($tmp->{start},$tmp->{stop},$tmp->{interval});

    $this->BottomTicks($this->{bottom},$tmp->{color},$labels,$tmp->{ticks},$tmp->{ticks}/3)
        if($tmp->{mode}=~/bottom/);

    $this->TopTicks($this->{top},$tmp->{color},$labels,$tmp->{ticks},$tmp->{ticks}/3)
        if($tmp->{mode}=~/top/);

    $this->VerticalDemarks($this->{canvas},$tmp->{grid_color},$labels)
        if($tmp->{mode}=~/grid/);
}

=head2 Threshold

=cut

sub Threshold {
    my($this)=shift;
    my($tmp)={color=>'0,0,0',pos=>0,@_};
    $this->HorizontalDemarks($this->{canvas},$tmp->{color},[[$tmp->{pos}]]);
}

=head2 TimeBoundaries

=cut

sub TimeBoundaries {
    $_[0]->XAxis(interval=>2,mode=>'grid',@_);
}

=head2 PrintText

=cut

sub PrintText {
    my($self,$rgb,$labels)=(@_);
    my($color)=$self->Color($rgb);
    my($win)=$self->{text_area};
    foreach my $line (@$labels) {
        my($xpos,$string)=@$line;
#        warn "$rgb pos $xpos str $string $self->{cursor_y}\n";
        $self->{image}->string(gdSmallFont,
                               $win->map_relax($xpos,$self->{cursor_y}),
                               $string,$color);
    }
    $self->{cursor_y}-=gdSmallFont->height/$win->{height};
}


=head2 BottomTicks

=cut

sub BottomTicks {
    my($self,$win,$rgb,$labels,$height,$mheight)=(@_);
    my($color)=$self->Color($rgb);
    $height/=$win->{height};
    $mheight/=$win->{height};
    foreach my $line (@$labels) {
        my($xpos,$string,$minors)=@$line;
        undef $minors if not $mheight;
        $self->{image}->line($win->map($xpos,1-$height,$xpos,1),$color);
        if(length($string)) {
            $xpos-=(length($string)*gdSmallFont->width/2)/$win->{width};
            $self->{image}->string(gdSmallFont,
                                   $win->map_relax($xpos,1-$height-.1),
                                   $string,$color);
        }
        foreach my $m_xpos (@{$minors}) {
            $self->{image}->line($win->map($m_xpos,1-$mheight,$m_xpos,1),$color);
        }
    }
}

=head2 TopTicks

=cut

sub TopTicks {
    my($self,$win,$rgb,$labels,$height,$mheight)=(@_);
    my($color)=$self->Color($rgb);
    $height/=$win->{height};
    $mheight/=$win->{height};
    foreach my $line (@$labels) {
        my($xpos,$string,$minors)=@$line;
        undef $minors if not $mheight;
        $self->{image}->line($win->map($xpos,$height,$xpos,0),$color);
        if(length($string)) {
            $xpos-=(length($string)*gdSmallFont->width/2)/$win->{width};
            my($ypos)=(gdSmallFont->height)/$win->{height};
            $self->{image}->string(gdSmallFont,
                                   $win->map_relax($xpos,$height+$ypos),
                                   $string,$color);
        }
        foreach my $m_xpos (@{$minors}) {
            $self->{image}->line($win->map($m_xpos,$mheight,$m_xpos,0),$color);
        }
    }
}


=head2 LeftTicks

=cut

sub LeftTicks {
    my($self,$win,$rgb,$labels,$width)=(@_);
    my($color)=$self->Color($rgb);
    $width/=$win->{width};
    foreach my $line (@$labels) {
        my($ypos,$string)=@$line;
        $self->{image}->line($win->map(1-$width,$ypos,1,$ypos),$color);
        if(length($string)){
            $ypos+=(gdSmallFont->height/2)/$win->{height};
            my($xpos)=1-$width-.1;
            $xpos-=(length($string)*gdSmallFont->width)/$win->{width};
            $self->{image}->string(gdSmallFont,$win->map_relax($xpos,$ypos),
                                   $string,$color);
        }
    }
}

=head2 RightTicks

=cut

sub RightTicks {
    my($self,$win,$rgb,$labels,$width)=(@_);
    my($color)=$self->Color($rgb);
    $width/=$win->{width};
    foreach my $line (@$labels) {
        my($ypos,$string)=@$line;
        $self->{image}->line($win->map(0,$ypos,$width,$ypos),$color);
        if(length($string)) {
            $ypos+=(gdSmallFont->height/2)/$win->{height};
            my($xpos)=$width+.1;
            $self->{image}->string(gdSmallFont,$win->map_relax($xpos,$ypos),
                                   $string,$color);
        }
    }
}

=head2 VerticalDemarks

=cut

sub VerticalDemarks {
    my($self,$win,$rgb,$labels)=(@_);
    my($color)=$self->Color($rgb);
    foreach my $line (@$labels) {
        my($xpos)=@$line;
        $self->{image}->line($win->map($xpos,0,$xpos,1),$color);
    }
}

=head2 HorizontalDemarks

=cut

sub HorizontalDemarks {
    my($self,$win,$rgb,$labels)=(@_);
    my($color)=$self->Color($rgb);
    foreach my $line (@$labels) {
        my($ypos)=@$line;
        $self->{image}->line($win->map(0,$ypos,1,$ypos),$color);
    }
}

=head2 Chart

=cut

sub Chart {
    my($self)=shift;
    my($dataset)=shift || return;
    my($tmp)={
        mode=>'line', #(line|fill|fill3d)
        color=>'200,0,0',
        @_
    };
    my($color)=$self->Color($tmp->{color});
    if(defined $tmp->{labels}) {
        $self->PrintText($tmp->{color},$tmp->{labels});
    }
    if($tmp->{mode} =~/line/) {
        for(my $i=1;$i<@$dataset;$i++) {
            my($x1,$x2)=($dataset->[$i-1]->[0],$dataset->[$i]->[0]);
            my($y1,$y2)=($dataset->[$i-1]->[1],$dataset->[$i]->[1]);
            $self->{image}->line($self->{canvas}->map($x1,$y1,$x2,$y2),
                                 $color);
        }
    } elsif ($tmp->{mode} =~ /fill/) {
        my($poly)=$self->MakePolygon($self->{canvas},$dataset);
        return if not defined $poly;
        $self->{image}->filledPolygon($poly,$color);
        if($tmp->{mode} =~ /3d/) {
            my($bright)=$self->Brighten($tmp->{color});
            my($dark)=$self->Darken($tmp->{color});
            for(my $i=1;$i<@$dataset;$i++) {
                my($x1,$x2)=($dataset->[$i-1]->[0],$dataset->[$i]->[0]);
                my($y1,$y2)=($dataset->[$i-1]->[1],$dataset->[$i]->[1]);
                $self->{image}->line($self->{canvas}->map($x1,$y1,$x2,$y2),
                                     ($y2<$y1)?$bright:
                                     (($y2==$y1)?$color:$dark));
            }
        }
    }
}

=head2 MakePolygon

=cut

sub MakePolygon {
    my($self,$win,$dataset)=(@_);
    my($poly)=GD::Polygon->new;
    $poly->addPt($win->map($dataset->[0]->[0],0));
    foreach my $line (@$dataset) {
        $poly->addPt($win->map($line->[0],$line->[1]));
    }
    $poly->addPt($win->map($dataset->[-1]->[0],0));
    return $poly;
}

=head2 NextValue

    my (ave_y,$max_y,$last) = $self->NextValue($values,$stop);

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
This is usually (1/600)*86400=144 seconds or so.

=cut

sub NextValue {
    my($self,$values,$stopx)=(@_);
    my($count,$total,$max,$last)=(0,0,0,0);

    for(my $i=0; $i<scalar @$$values; $i++) {
        my ($x,$y)=@{$$values->[$i]};
        last if ($x>$stopx);
        $count++;
        $total+=$y;
        $last=$y;
        $max=$y if($max<$y);
    }

    return if (!$count);
    splice @$$values, 0, $count;   # remove the values we've processed
    $total/=$count;
    warn "stopx was $stopx, count=$count,total=$total,max=$max,last=$last\n" if ($self->{debug});
    return ($total,$max,$last);
}

=head2 Sample

    my ($ave, $max, $aveval, $maxval, $curr) = $chart->Sample($values,$start,$stop,$scale);


=cut

sub Sample {
    my($self,$values,$start,$stop,$scale)=(@_);
    my $step = 1/$self->{canvas_width};
    my $span = $stop-$start;
    my(@ave,@max);
    my ($total,$maxval,$last)=(0,0,0);
    warn "sample: $start $stop $step $span\n" if ($self->{debug});
    for(my $x=0;$x<1;$x+=$step) {
        my ($ave_y,$max_y,$tmp)=$self->NextValue(\$values,$start+$x*$span);
        next if not defined $ave_y;
        $total+=$ave_y;
        $last=$tmp;
        $maxval=$max_y if($max_y>$maxval);
        push(@ave,[$x,$ave_y*$scale]);
        push(@max,[$x,$max_y*$scale]);
    }
    if(@ave>0) {  # did we collect any samples
        $total/=(@ave);
    }
    return wantarray ? ([@ave],[@max],$total,$maxval,$last) : [@ave];
}

1;

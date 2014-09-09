package CIBH::Chart;

# Copyright (c) 2000 Peter Whiting (Sprint). All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

use strict;
use GD;
use CIBH::Win;
use Time::Local;
use AutoLoader 'AUTOLOAD';

# Preloaded methods go here.

# returns a list of list refs, each list ref points to a list
# of two values: the x position (0-1) and the hour info
sub GetHourBoundaries {
    my($start,$stop,$stride)=(@_);
    my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
        localtime($start);
    my($first_hour)=$start+(59-$min)*60+(60-$sec);
    $hour++;
    my(@rval);
    my($i);
    my($marks)=4;
    while($first_hour<$stop) {
        my $minors;
        my($x)=($first_hour-$start)/($stop-$start);
        my($dx)=(3600*$stride/$marks)/($stop-$start);
        for($i=0;$i<$marks;$i++) {
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

# returns a list of list refs, each list ref points to a list
# of two values: the x position (0-1) and the hour info
sub GetDayBoundaries {
    my($start,$stop)=(@_);
    my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
        localtime($start);
    my($first_day)=$start+(23-$hour)*3600+(59-$min)*60+(60-$sec);
    my($marks)=6; # 6 tick marks per day = one every 4 hours
    my(@rval);
    while($first_day<$stop) {
        my($dx)=(3600*24/$marks)/($stop-$start);
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
        $first_day+=3600*24;
    }
    return wantarray ? @rval : [@rval];
}

# returns a list of list refs, each list ref points to a list
# of two values: the x position (0-1) and the hour info
sub GetWeekBoundaries {
    my($start,$stop)=(@_);
    my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
        localtime($start);
    my($first_week)=$start+(6-$wday)*3600*24+(23-$hour)*3600+(59-$min)*60+$sec;
    my(@rval);
    my($marks)=7;
    while($first_week<$stop) {
        my($dx)=(3600*24*7/$marks)/($stop-$start);
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
        $first_week+=3600*24*7;
    }
    return wantarray ? @rval : [@rval];
}

# returns a list of list refs, each list ref points to a list
# of two values: the x position (0-1) and the hour info

sub GetMonthBoundaries {
    my($start,$stop)=(@_);
    my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
        localtime($start);
    # som: start of month
    my($som)=timelocal(0,0,0,1,$mon,$year);
    my(@rval);

    # about this many months.  We want about 10 boundaries...
    my($stride)=3600*24*32*int(1+($stop-$start)/(3600*24*32*10));

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


sub GetBoundaries {
    my($start,$stop,$max)=(@_);

    return GetHourBoundaries($start,$stop,1)
        if(($stop-$start)/(1800) < $max );
    return GetHourBoundaries($start,$stop,2)
        if(($stop-$start)/(3600*2) < $max );
    return GetDayBoundaries($start,$stop)
        if(($stop-$start)/(3600*24) < $max);
    return GetWeekBoundaries($start,$stop)
        if(($stop-$start)/(3600*24*5) < $max);
    return GetMonthBoundaries($start,$stop);

}

sub GetUnits {
    my($start,$stop,$count)=(@_);
    return Units(($stop-$start)/$count);
}

sub Units {
    my($stride)=(@_);
    return (1/1e9,"G") if($stride>1e9);
    return (1/1e6,"M") if($stride>1e6);
    return (1/1e3,"K") if($stride>1e3);
    return (1,"");
}

# this routine returns a list of $count boundaries -
# each element is a pair - a position (between 0 and 1)
# and a value to print, it you want...
sub GetNumericBoundaries {
    my($start,$stop,$count)=(@_);
    $count--;
    my($stride)=($stop-$start)/$count;

    my($scale,$label)=GetUnits($start,$stop,$count);
    my(@rval,$i);
    for($i=0;$i<=$count;$i++) {
        my($pos)=$i/$count;
        push(@rval,[$pos,int(($stop-$start)*$scale*$pos)."$label"]);
    }
    return wantarray ? @rval : [@rval];
}

sub NiceValue {
    my($value,$scale)=(@_);
    $value*=$scale;
    my($a,$b)=($value=~/^(\d)(\d+)$/);
    return ($value-$b)/$scale;
}

sub GetNiceNumericBoundaries {
    my($start,$stop,$count,$minor_tics)=(@_);
    my($scale,$label)=GetUnits($start,$stop,$count);
    my(@rval,$i,$j);
    my($stride)=NiceValue(($stop-$start)/$count,$scale);
    my($minorstride)=$stride/($minor_tics+1);
    for($i=NiceValue($start);$i<$stop;$i+=$stride) {
        my(@list)=(($i-$start)/($stop-$start),$i*$scale."$label");
        for($j=1;$j<=$minor_tics;$j++) {
            push(@list,($i-$start+$j*$minorstride)/($stop-$start));
        }
        push(@rval,[@list]);
    }
    return wantarray ? @rval : [@rval];
}

sub Label {
    my($curr,$stop,$count)=(@_);
    my($stride)=($stop-$curr)/$count;
    my(@rval);
    my($scale,$label)=GetUnits($curr,$stop,$count);
    for(;$curr<=$stop;$curr+=$stride) {
	push(@rval,$curr*$scale . "$label");
    }
    return (@rval);
}

sub TimeLabel {
    my($curr,$stop,$count)=(@_);
    my($delta)=($stop-$curr);
    my($stride)=$delta/$count;
    my(@rval);

    for(;$curr<=$stop;$curr+=$stride) {
	my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
	    localtime($curr);
	$mon++;$mday++;
	push(@rval,sprintf("%d.%02d",$min,$sec)),next if($delta<=60*60);
	push(@rval,sprintf("%d:%02d",$hour,$min)),next if($delta<=60*60*24);
	push(@rval,"$mon/$mday $hour:$min");
    }
    return (@rval);

}

sub StringLength {
    my($str,$font)=(@_);
    length($str)*$font->width;
}

sub Bright {
    my(@vals)=split(",",$_[0]);
    my(@rval);
    foreach my $val (@vals) {
        push(@rval,int(($val*2+255*3)/5));
    }
    return join(",",@rval);
}

sub Dark {
    my(@vals)=split(",",$_[0]);
    my(@rval);
    foreach my $val (@vals) {
        push(@rval,($val/1.5));
    }
    return join(",",@rval);
}





# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__
# Below is the stub of documentation for your module. You better edit it!

=head1 NAME

CIBH::Chart - Perl extension charting data

=head1 SYNOPSIS

  use CIBH::Chart;

=head1 DESCRIPTION

=head1 AUTHOR

Pete Whiting pwhiting@sprint.net

=head1 SEE ALSO

CIBH::Datafile, CIBH::Win, CIBH::Fig.

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
        background => "255,255,255",
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

    $this->{image} = new GD::Image($this->{width},$this->{height})
       if ($this->{no_image}==0);

    bless($this,$class);


    $this->{image}->transparent($this->Color($this->{background}))
        if($this->{transparent} and $this->{image});

    $this->BuildWindows;

    return $this;
}

sub BuildWindows {
    my($this)=(@_);

    $this->{canvas} = new
        CIBH::Win(x      => $this->{left_scale_width} + 1,
            y      => $this->{canvas_height}+$this->{top_scale_height} + 1,
            width  => $this->{canvas_width},
            height => $this->{canvas_height});

    $this->{left} = new
        CIBH::Win(x      => 0,
            y      => $this->{canvas_height}+$this->{top_scale_height} + 1,
            width  => $this->{left_scale_width},
            height => $this->{canvas_height});

    $this->{right} = new
        CIBH::Win(x      => $this->{width}-$this->{right_scale_width} - 1,
            y      => $this->{canvas_height}+$this->{top_scale_height} + 1,
            width  => $this->{right_scale_width},
            height => $this->{canvas_height});

    $this->{top} = new
        CIBH::Win(x      => $this->{left_scale_width} + 1,
            y      => $this->{top_scale_height},
            width  => $this->{canvas_width},
            height => $this->{top_scale_height});

    $this->{bottom} = new
        CIBH::Win(x      => $this->{left_scale_width} + 1,
            y      => $this->{height}-$this->{text_area_height} - 2,
            width  => $this->{canvas_width},
            height => $this->{bottom_scale_height});

    $this->{text_area} = new
        CIBH::Win(x      => $this->{left_scale_width} + 1,
            y      => $this->{height}-1,
            width  => $this->{canvas_width},
            height => $this->{text_area_height});
}

sub CanvasCoords {
    my($self)=shift;
    return $self->{canvas}->map(0,0,1,1);
}

sub Print {
    my($self)=shift;
    my($tmp)={color=>"0,0,0",@_};
    $self->{image}->rectangle(($self->{canvas}->map(0,0,1,1)),
                              $self->Color($tmp->{color}));
#    $self->{image}->rectangle(($self->{right}->map(0,0,1,1)),
#                              $self->Color("255,0,0"));
#    $self->{image}->rectangle(($self->{left}->map(0,0,1,1)),
#                              $self->Color("0,255,0"));
#    $self->{image}->rectangle(($self->{top}->map(0,0,1,1)),
#                              $self->Color("255,0,255"));
#    $self->{image}->rectangle(($self->{bottom}->map(0,0,1,1)),
#                              $self->Color("0,0,255"));
#    $self->{image}->rectangle(($self->{text_area}->map(0,0,1,1)),
#                              $self->Color("155,10,255"));
    print $self->{image}->png;
}

sub GetColor {
    my($self,$r,$g,$b)=(@_);
    my($color)=($self->{image}->colorExact($r,$g,$b));
    $color=$self->{image}->colorAllocate($r,$g,$b)
        if($color==-1);
    return($color);
}

sub Color {
    my($self,$str)=(@_);
    return $self->GetColor(split(",",$str));
}


sub YAxis {
    my($this)=shift;
    my($tmp)={
        grid_color=>0,
        color=>"55,55,55",
        min=>0,
        max=>100,
        major=>10,
        tick_size=>4,
        mode=>"left,grid",
        @_};

    $tmp->{grid_color}=$tmp->{color} if(not $tmp->{grid_color});

    my($labels);
    $labels = GetNumericBoundaries($tmp->{min},$tmp->{max},$tmp->{major}+1);

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


sub XAxis {
    my($this)=shift;
    my($tmp)={
        grid_color=>0,
        color=>"0,0,0",
        start=>0,
        stop=>1,
        interval=>24.1,
        ticks=>10,
        mode=>"top,bottom",
        @_ };

    $tmp->{grid_color}=$tmp->{color} if(not $tmp->{grid_color});

    my($labels);
    $labels=GetBoundaries($tmp->{start},$tmp->{stop},$tmp->{interval});

    $this->BottomTicks($this->{bottom},$tmp->{color},$labels,$tmp->{ticks},
	$tmp->{ticks}/3)
        if($tmp->{mode}=~/bottom/);

    $this->TopTicks($this->{top},$tmp->{color},$labels,$tmp->{ticks},
	$tmp->{ticks}/3)
        if($tmp->{mode}=~/top/);

    $this->VerticalDemarks($this->{canvas},$tmp->{grid_color},$labels)
        if($tmp->{mode}=~/grid/);
}

sub Threshold {
    my($this)=shift;
    my($tmp)={color=>"0,0,0",pos=>0,@_ };
    $this->HorizontalDemarks($this->{canvas},$tmp->{color},[[$tmp->{pos}]]);
}


sub TimeBoundaries {
    my($this)=shift;
    $this->XAxis(interval=>2,mode=>"grid",@_);
}

sub PrintText {
    my($self,$rgb,$labels)=(@_);
    my($color)=$self->Color($rgb);
    my($line);
    my($win)=$self->{text_area};
     foreach $line (@$labels) {
        my($xpos,$string)=@$line;
#        warn "$rgb pos $xpos str $string $self->{cursor_y}\n";
        $self->{image}->string(gdSmallFont,
                               $win->map_relax($xpos,$self->{cursor_y}),
                               $string,$color);
    }
    $self->{cursor_y}-=gdSmallFont->height/$win->{height};
}
sub BottomTicks {
    my($self,$win,$rgb,$labels,$height,$mheight)=(@_);
    my($color)=$self->Color($rgb);
    my($line);
    $height/=$win->{height};
    $mheight/=$win->{height};
    foreach $line (@$labels) {
        my($xpos,$string,$minors)=@$line;
        undef $minors if not $mheight;
        $self->{image}->line($win->map($xpos,1-$height,$xpos,1),$color);
        if(length($string)) {
            $xpos-=(length($string)*gdSmallFont->width/2)/$win->{width};
            $self->{image}->string(gdSmallFont,
                                   $win->map_relax($xpos,1-$height-.1),
                                   $string,$color);
        }
        foreach $xpos (@{$minors}) {
            $self->{image}->line($win->map($xpos,1-$mheight,$xpos,1),$color);
        }
    }
}

sub TopTicks {
    my($self,$win,$rgb,$labels,$height,$mheight)=(@_);
    my($color)=$self->Color($rgb);
    my($line);
    $height/=$win->{height};
    $mheight/=$win->{height};
    foreach $line (@$labels) {
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
        foreach $xpos (@{$minors}) {
            $self->{image}->line($win->map($xpos,$mheight,$xpos,0),$color);
        }
    }
}


sub LeftTicks {
    my($self,$win,$rgb,$labels,$width)=(@_);
    my($color)=$self->Color($rgb);
    my($line);
    $width/=$win->{width};
    foreach $line (@$labels) {
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

sub RightTicks {
    my($self,$win,$rgb,$labels,$width)=(@_);
    my($color)=$self->Color($rgb);
    my($line);
    $width/=$win->{width};
    foreach $line (@$labels) {
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

sub VerticalDemarks {
    my($self,$win,$rgb,$labels)=(@_);
    my($color)=$self->Color($rgb);
    my($line);
    foreach $line (@$labels) {
        my($xpos)=@$line;
        $self->{image}->line($win->map($xpos,0,$xpos,1),$color);
    }
}

sub HorizontalDemarks {
    my($self,$win,$rgb,$labels)=(@_);
    my($color)=$self->Color($rgb);
    my($line);
    foreach $line (@$labels) {
        my($ypos)=@$line;
        $self->{image}->line($win->map(0,$ypos,1,$ypos),$color);
    }
}


sub Chart {
    my($self)=shift;
    my($dataset)=shift;
    my($tmp)={
        mode=>"line", #(line|fill|fill3d)
        color=>"200,0,0",
        @_ };
    my($color)=$self->Color($tmp->{color});
    if(defined $tmp->{labels}) {
        $self->PrintText($tmp->{color},$tmp->{labels});
    }
    my($i);
    if($tmp->{mode} =~/line/) {
        for($i=1;$i<@$dataset;$i++) {
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
            for($i=1;$i<@$dataset;$i++) {
                my($x1,$x2)=($dataset->[$i-1]->[0],$dataset->[$i]->[0]);
                my($y1,$y2)=($dataset->[$i-1]->[1],$dataset->[$i]->[1]);
                $self->{image}->line($self->{canvas}->map($x1,$y1,$x2,$y2),
                                     ($y2<$y1)?$bright:
                                     (($y2==$y1)?$color:$dark));
            }
        }
    }
}

sub Brighten {
    my($self,$str)=(@_);
    return $self->Color(Bright($str));
}

sub Darken {
    my($self,$str)=(@_);
    return $self->Color(Dark($str));
}

sub MakePolygon {
    my($self,$win,$dataset)=(@_);
    my($poly)=new GD::Polygon;
    my($line);
    $poly->addPt($win->map($dataset->[0]->[0],0));
    foreach $line (@$dataset) {
        $poly->addPt($win->map($line->[0],$line->[1]));
    }
    $poly->addPt($win->map($dataset->[-1]->[0],0));
    return $poly;
}

1;

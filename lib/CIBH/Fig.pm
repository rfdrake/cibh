package CIBH::Fig;

# Copyright (c) 2000 Peter Whiting (Sprint). All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

use strict;
use GD;
use AutoLoader 'AUTOLOAD';

# Preloaded methods go here.

sub rgb {
    my($r,$g,$b)=($_[0]=~/([a-fA-F0-9].)(..)(..)/);
    return (hex($r),hex($g),hex($b));
}

sub AdjustBounds {
    my($a,$b)=(@_);
    $a->{minx}=$b->{minx} if($a->{minx}>$b->{minx} or not defined $a->{minx});
    $a->{miny}=$b->{miny} if($a->{miny}>$b->{miny} or not defined $a->{miny});
    $a->{maxx}=$b->{maxx} if($a->{maxx}<$b->{maxx} or not defined $a->{maxx});
    $a->{maxy}=$b->{maxy} if($a->{maxy}<$b->{maxy} or not defined $a->{maxy});
    return $a;
}

sub GroupBounds {
    my($line)=(@_);
    return {minx=>$line->[1],miny=>$line->[2],
            maxx=>$line->[3],maxy=>$line->[4]};
}

sub EllipseBounds {
    my($line)=(@_);
    my($obj,$type,$style,$thickness,$color,$fillcolor,$depth,$pen,
       $fillstyle,$styleval,$direction,$ang,$cx,$cy,$rx,$ry,
       $sx,$sy,$ex,$ey)=(@{$line});
    return {minx=>$sx,miny=>$sy,maxx=>$ex,maxy=>$ey};
}

sub LineBounds {
    my($line)=(@_);
    my($obj,$type,$style,$thickness,$color,$fillcolor,$depth,$pen,
       $fillstyle,$styleval,$joinstyle,$capstyle,$radius,
       $fa,$ba,$num_points,@pts)=(@{$line});
    my(@x,@y);
    if($type==5) { shift @pts; shift @pts; }
    while(@pts) {
        push @x,shift @pts;
        push @y,shift @pts;
    }
    @x=sort {$a <=> $b} @x;
    @y=sort {$a <=> $b} @y;
    return {minx=>$x[0],miny=>$y[0],maxx=>$x[-1],maxy=>$y[-1]};
}

sub TextBounds {
    my($line)=(@_);
    my($obj,$type,$color,$depth,$pen,$font,$size,$angle,$flags,$height,
       $length,$x,$y,@s)=(@{$line});
    # ignore angle for now...
    return {minx=>$x,miny=>$y-$height,maxx=>$x+$length,maxy=>$y};
}


sub XY {
    my($pts)=(@_);
    my(@rval);
     while(@{$pts}) {
        push @rval, shift(@{$pts}) . "," . shift(@{$pts});
    }
     return join(" ",@rval);
}


sub AdjustForThickness
{
    my($thickness,$pts)=@_;
    # don't do any thing if we join at the end.
    return $pts if($pts->[0]==$pts->[-2] && $pts->[1]==$pts->[-1]);
    # adjust starting point
    my($dy)=$pts->[3]<=>$pts->[1];
    my($dx)=$pts->[2]<=>$pts->[0];
    $pts->[0]+=($thickness/2*$dx);
    $pts->[1]+=($thickness/2*$dy);
    #adjust the ending point
    $dy=$pts->[-3]<=>$pts->[-1];
    $dx=$pts->[-4]<=>$pts->[-2];
    $pts->[-2]+=($thickness/2*$dx);
    $pts->[-1]+=($thickness/2*$dy);
    return $pts;
}



# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__
# Below is the stub of documentation for your module. You better edit it!

=head1 NAME

CIBH::Fig - Perl extension for dealing with xfig files

=head1 SYNOPSIS

  use CIBH::Fig;

=head1 DESCRIPTION

=head1 AUTHOR

Pete Whiting, pwhiting@sprint.net


=head1 SEE ALSO

perl(1) CIBH::DataSet, CIBH::Datafile, CIBH::Win, CIBH::Chart.

=cut


sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $this = {
        fat=>4,
        scale=>1/15,
        @_
        };
    bless($this,$class);
    $this->ReadFig;
    $this->FindExtremes;
    return $this;
}

sub png {
    my($this)=(@_);
    $this->{image}->png;
}

sub ReadFig {
    my($this)=(@_);
    my($lines)=$this->{fig};
    delete $this->{fig};
    foreach $_ (@{$lines}) {
        if(/^\s/) { # continuation lines
            push(@{$this->{fig}->[-1]},split);
        } else {
            push(@{$this->{fig}},[split]);
        }
    }
}


sub BuildImage {
    my($this)=(@_);
    $this->{image}=new GD::Image($this->{width},$this->{height}) || die;
    $this->ProcessColors;
    foreach my $line (@{$this->{fig}}) {
        $this->FigImage($line) if($line->[0]==2 and $line->[1]==5 );
    }

    foreach my $line (@{$this->{fig}}) {
        if($line->[0]==1) { $this->FigEllipse($line); }
        elsif($line->[0]==2) { $this->FigLines($line); }
        elsif($line->[0]==4) { $this->FigText($line); }
    }
}


sub FilledBox
{
    my($this,$pts,$color)=(@_);
    my($poly)=(new GD::Polygon,0);
    my($i);
    for($i=0;$i<@{$pts};$i+=2) {
        $poly->addPt($pts->[$i],$pts->[$i+1]);
    }
    $this->{image}->filledPolygon($poly,$color);
}

sub DrawLines
{
    my($this,$pts,$color)=(@_);
    for(my $i=0;$i<=@{$pts}-4;$i+=2) {
        $this->{image}->line($pts->[$i],$pts->[$i+1],
                     $pts->[$i+2],$pts->[$i+3],$color) ;
   }
}


sub SetStyle
{
    my($this,$style,$c,$thickness)=@_;
    my($color)=$this->{colors}->[$c];
    if ($style==1) {
        $this->{image}->setStyle($color,$color,gdTransparent,gdTransparent);
        return gdStyled;
    } elsif ($style==2) {
        $this->{image}->setStyle($color,gdTransparent,gdTransparent);
        return gdStyled;
    } elsif ($thickness<2) {
        return $color;
    } else {
        $this->{image}->setThickness($thickness);
        return $color;
    }
}

sub FigImage
{
   my($this,$line)=(@_);
   my($obj,$type,$style,$thickness,$color,$fillcolor,$depth,$pen,
       $fillstyle,$styleval,$joinstyle,$capstyle,$radius,
       $fa,$ba,$num_points,$zero,$file,$x0,$y0,$x1,$y1,$x2,$y2)=(@{$line});
   my($img);
   if($file=~/\.jpg$/) {
       $img=GD::Image->newFromJpeg(new IO::File($file,"r"));
   } elsif($file=~/\.png$/) {
       $img=GD::Image->newFromPng(new IO::File($file,"r"));
   } elsif($file=~/\.xbm$/) {
       $img=GD::Image->newFromXbm(new IO::File($file,"r"));
   } elsif($file=~/\.xpm$/) {
       $img=GD::Image->newFromXpm(new IO::File($file,"r"));
   } else {
       return;
   }
   my($x,$y,$w,$h)=$this->Scale($this->Offset($x0,$y0),$x2-$x0,$y2-$y0);
   $this->{image}->copyResized($img,$x,$y,0,0,$w,$h,$img->getBounds);
}
sub FigLines
{
    my($this,$line)=(@_);
    my($obj,$type,$style,$thickness,$color,$fillcolor,$depth,$pen,
        $fillstyle,$styleval,$joinstyle,$capstyle,$radius,
        $fa,$ba,$num_points,@points)=(@{$line});
    return if($type==5);
    my $pts=$this->Scale($this->Offset([@points]));
    $pts=AdjustForThickness($thickness,$pts) if($thickness>1);
    if($fillstyle==-1){ # normal box or group of lines
        $this->DrawLines($pts,$this->SetStyle($style,$color,$thickness));
    } else { # filled box if fillstye isn't -1
        $this->FilledBox($pts,$this->{colors}->[$fillcolor]);
    }
}


sub FigEllipse
{
    my($this,$line)=(@_);
    my($obj,$type,$style,$thickness,$color,$fillcolor,$depth,$pen,
       $fillstyle,$styleval,$direction,$ang,$cx,$cy,$rx,$ry,
       $sx,$sy,$ex,$ey)=(@{$line});
    ($rx,$ry)=(sin($ang)*$ry+cos($ang)*$rx,sin($ang)*$rx+cos($ang)*$ry);
    ($cx,$cy,$sx,$sy,$ex,$ey)=
        $this->Scale($this->Offset($cx,$cy,$sx,$sy,$ex,$ey));
    ($rx,$ry)=$this->Scale($rx*2,$ry*2);
    if($fillstyle!=-1){
	$this->{image}->arc($cx,$cy,$rx,$ry,0,360,$this->{colors}->[-1]);
	$this->{image}->fillToBorder($cx,$cy,$this->{colors}->[-1],
                                     $this->{colors}->[$fillcolor]);
    }
    $this->{image}->arc($cx,$cy,$rx,$ry,0,360,
                        $this->SetStyle($style,$color,$thickness));
}


sub GetFont
{
    my($this,$size)=(@_);
    $size*=12*$this->{scale};
    return(GD::Font->Tiny) if($size<9);
    return(GD::Font->Small) if($size<15);
    return(GD::Font->Medium) if($size<20);
    return(GD::Font->Large);
}

sub FigText
{
    my($this,$line)=(@_);
    my($obj,$type,$color,$depth,$pen,$font,$size,$angle,$flags,$height,
       $length,$x,$y,@s)=(@{$line});
    ($x,$y)=$this->Scale($this->Offset($x,$y-$height));
    my($string)="@s";
    return if $string=~/^\#/;
    $string=~s/\\001$//;
    if($angle>1.5 && $angle<1.6) { # really need to use ttf and arb angles
        my($font)=$this->GetFont($size);
        $x-=$font->height;
        $this->{image}->stringUp($font,$x,$y,$string,
                                 $this->{colors}->[$color]);

    } else {
        $this->{image}->string($this->GetFont($size),$x,$y,$string,
                               $this->{colors}->[$color]);
    }
}


sub ProcessColors  {
    my($this)=(@_);
    my(@default_colors)=
        ("000000","0000ff","00ff00","00ffff","ff0000","ff00ff","ffff00",
         "ffffff","000096","0000b6","0000d7","86cfff","009200","00b200",
         "00d300","009296","00b2b6","00d3d7","960000","b60000","d70000",
         "960096","b600b6","d700d7","863000","a64100","c76100","ff8286",
         "ffa2a6","ffc3c7","ffe3e7","ffd700");
    my($background)=$this->{image}->colorAllocate(255,255,255);
    $this->{image}->transparent($background);
    my($color);
    for(my $i=0;$i<@default_colors;$i++) {
        $this->{colors}->[$i]=
            $this->{image}->colorAllocate(rgb($default_colors[$i]));
    }
    foreach my $line (@{$this->{fig}}) {
        if($line->[0] eq "0") {
            $this->{colors}->[$line->[1]]=
                $this->{image}->colorAllocate(rgb($line->[2]));
        }
    }
    # make the last color black... It is the "default" color (-1)
    $this->{colors}->[@{$this->{colors}}]=
        $this->{image}->colorAllocate(0,0,0);
}

sub FindExtremes {
    my($this)=(@_);
    my($line,$bnds);
    foreach $line (@{$this->{fig}}) {
        if($line->[0]==1)    {$bnds=AdjustBounds($bnds,EllipseBounds($line));}
        elsif($line->[0]==2) {$bnds=AdjustBounds($bnds,LineBounds($line));}
        elsif($line->[0]==4) {$bnds=AdjustBounds($bnds,TextBounds($line));}
        elsif($line->[0]==6) {$bnds=AdjustBounds($bnds,GroupBounds($line));}
    }
    $this->{xoffset}=$bnds->{minx} if not defined $this->{xoffset};
    $this->{yoffset}=$bnds->{miny} if not defined $this->{yoffset};
    ($this->{width})=$this->Scale($bnds->{maxx}-$bnds->{minx}+2)
        if not defined $this->{width};
    ($this->{height})=$this->Scale($bnds->{maxy}-$bnds->{miny}+2)
        if not defined $this->{height};
    return $bnds;
}



sub LineMap {
    my($this,$line,$shapes)=(@_);
    my($obj,$type,$style,$thickness,$color,$fillcolor,$depth,$pen,
       $fillstyle,$styleval,$joinstyle,$capstyle,$radius,
       $fa,$ba,$num_points,@points)=@{$line};
    my $pts=$this->Scale($this->Offset([@points]));
    $pts=AdjustForThickness($thickness,$pts) if($thickness>1);
    if($pts->[0]==$pts->[-2] and $pts->[1]==$pts->[-1]) { # enclosed
        push @{$shapes->{poly}},$pts;
    } else {
        my($i);
        for($i=0;$i<=@{$pts}-4;$i+=2) {
            my($xa,$ya,$xb,$yb)=(@{$pts}[$i..$i+3]);
            my($dx,$dy)=$this->GetDeltas($xa,$ya,$xb,$yb); # account for angle

            push @{$shapes->{poly}},[$xa+$dx,$ya+$dy,$xb-$dy,$yb+$dx,
                                    $xb-$dx,$yb-$dy,$xa+$dy,$ya-$dx];
#            warn "$xa+$dx,$ya+$dy,$xb-$dy,$yb+$dx,$xb-$dx,$yb-$dy,$xa+$dy,$ya-$dx\n";
        }
    }
    return $shapes;
}

sub Limit {
    my($this,$pts)=(@_);
    my($i);
    for($i=0;$i<=@{$pts};$i+=2) {
        $pts->[$i]=0 if $pts->[$i]<0;
        $pts->[$i+1]=0 if $pts->[$i+1]<0;
        $pts->[$i]=$this->{width} if $pts->[$i]>$this->{width};
        $pts->[$i+1]=$this->{height} if $pts->[$i+1]>$this->{height};
    }
    return $pts;
}


sub EllipseMap {
    my($this,$line,$shape)=(@_);
    my($obj,$type,$style,$thickness,$color,$fillcolor,$depth,$pen,
       $fillstyle,$styleval,$direction,$ang,$cx,$cy,$rx,$ry,
       $sx,$sy,$ex,$ey)=(@{$line});
# for non-circle ellipse (at an angle) a rectangle approximates it
# better than a circle, usually.  Eventually this routine should
# treat an oval not at an angle as an oval.
    my($x1,$y1,$x2,$y2)=
        $this->Scale($this->Offset($cx-$rx,$cy-$ry,$cx+$rx,$cy+$ry));
    push @{$shape->{rect}},[$x1,$y1,$x2,$y2];
    return $shape;
}



sub BuildMap {
    my($this)=(@_);
    my($shape,@stack,$url,$el,$type,$line);
    foreach $line (@{$this->{fig}}) {
        if($line->[0]==1) {
            $shape=$this->EllipseMap($line,$shape);
        } elsif($line->[0]==2) {
            $shape=$this->LineMap($line,$shape);
        } elsif($line->[0]==4) {
            $shape->{url}=$1 if($line->[13]=~/^\#<(.*)>/);
        } elsif($line->[0]==6) {
            push @stack,$shape;
            undef $shape;
        } elsif($line->[0]==-6) {
            $this->StoreMapping($shape);
            $shape=pop @stack;
        }
    }
    $this->StoreMapping($shape);

}

sub StoreMapping {
    my($this,$shape)=(@_);
#    $shape->{url}="tmp.url";
    if(defined $shape->{url}) {
        my $url=$shape->{url};
        delete $shape->{url};
        push @{$this->{mapping}},{url=>$url,shapes=>$shape};
    }
}

sub csImageMap {
    my($this)=(@_);
    my($type,$el);
    my($rval,$group);
    foreach $group (@{$this->{mapping}}) {
        my($url)=$group->{url};
        my($shape)=$group->{shapes};
        foreach $type (keys %{$shape}) {
            foreach $el (@{$shape->{$type}}) {
                $rval .= "<area shape=\"$type\" href=\"$url\" coords=\"".
                    join(",",@{$this->Limit($el)})."\">\n";
            }
        }
    }
    $rval;
}

sub ssImageMap {
    my($this)=(@_);
    my($type,$el);
    my($rval,$group);
    foreach $group (@{$this->{mapping}}) {
        my($url)=$group->{url};
        my($shape)=$group->{shapes};
        foreach $type (keys %{$shape}) {
            foreach $el (@{$shape->{$type}}) {
                $rval .= "$type $url ". XY($this->Limit($el)) . "\n";
            }
        }
    }
    $rval;
}

sub ImageMap {
    my($this)=(@_);
    return $this->ssImageMap;
}



sub Scale
{
    my($this,@points)=(@_);
    my($pts)=ref $points[0]?$points[0]:[@points];
    my($i);
    for($i=0;$i<@{$pts};$i++){
	$pts->[$i]=int($pts->[$i]*$this->{scale}+.5);
    }
    return wantarray ? @{$pts}:$pts;
}

sub Offset
{
    my($this,@points)=(@_);
    my($pts)=ref $points[0]?$points[0]:[@points];
    return $pts if($this->{xoffset}==0 and $this->{yoffset}==0);
    my($i);
    my(@offset)=($this->{xoffset},$this->{yoffset});
    for($i=0;$i<@{$pts};$i++){
	$pts->[$i]=$pts->[$i]-$offset[$i%2];
	$pts->[$i]=0 if($pts->[$i]<0);
    }
    return wantarray ? @{$pts}:$pts;
}

sub GetDeltas {
    my($this,$xa,$ya,$xb,$yb)=(@_);
    my($cx,$cy)=($xb-$xa,$ya-$yb);
    my($l)=1+sqrt($cx*$cx+$cy*$cy);
    my($dy)=$this->{fat}*($cx-$cy)/$l; # fat*(cos(alpha)-sin(alpha))
    my($dx)=$this->{fat}*(-$cy-$cx)/$l;
# this doesn't extend the bounding box past the ends of the line
#    my($dy)=$fat*($cx)/$l;
#    my($dx)=$fat*(-$cy)/$l;
    return (int($dx),int(-$dy));
}
# assume points come in pairs of x,y

1;

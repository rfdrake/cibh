use strict;
use warnings;
use Test::More;
use CIBH::Dia;
use Digest::MD5 qw (md5_hex);
use IO::File;

my $dia = CIBH::Dia->new('data', \*DATA);

# 1. 
ok(ref($dia) eq 'CIBH::Dia', 'CIBH::Dia should return dia object.');

# 2.
my $box1 = $dia->boxes->[0];
ok($box1->color eq '#0000ff', 'Box color should be 0000ff');

# 3.
ok($box1->text eq 'SHINY', 'Box text should say SHINY');

# 4.
my $text = $dia->texts->[0];
ok ($text->text eq 'LINE TEXT', 'Text attached to line should say LINE TEXT');

$box1->text('DULL');
$text->text('ANGRY CAT');

# 5.
ok($box1->text eq 'DULL', 'Box text should now say DULL');

# 6.
ok($text->text eq 'ANGRY CAT', 'Text attached to line should now say ANGRY CAT');

# 7.
ok($text->line->color eq '#00ff00', 'Line color should be 00ff00');

# 8.
ok(!defined($text->line->text), 'Line text should be undef (cannot put text inside line object)');

# 9.
ok(($dia->stat)[3] == 1, 'Checking what happens if you stat __DATA__');

# 10. mtime looks like a date.. Sat Sep 28 18:32:54 2013
ok($dia->mtime =~ /\w+ \w+\s+\d+\s+\d+:\d+:\d+ \d+/, "mtime should be a date: ".  $dia->mtime);

# 11. bounding_box
ok($box1->bounding_box->[3] == 25.1, "box1 bb right should be 25.1");

# 12. extents
ok($dia->extents ~~ [ 3.1, 19.45, 8.30377, 25.1 ], 'Extents should match precalculated values.');

# 13. set box1->url to be "testing", then look at $box1->imgmap

$box1->url('testing');
ok($box1->imgmap eq "<area shape='rect' href='testing' title='testing' alt='testing' coords='87,14,335,327'/>", 
                    'box1 imgmap cords should match precalculated values.');

# 14. general imgmap test
ok(md5_hex($dia->imgmap) eq 'ca3557b545814c609f7efb74f62871eb', '$dia->imgmap should match precalculated values.');

# 15. can we produce a png?  3d77a48e2ea19763c6073c015ed09831
ok(md5_hex($dia->png) eq '3d77a48e2ea19763c6073c015ed09831', 'Can we produce a png?');

done_testing();


# had to switch to uncompressed XML because the binary version was confusing
# prove into thinking this wasn't a perl file, so it wasn't appending -l lib
# and we got CIBH::Dia not found.
__DATA__
<?xml version="1.0" encoding="UTF-8"?>
<dia:diagram xmlns:dia="http://www.lysator.liu.se/~alla/dia/">
  <dia:diagramdata>
    <dia:attribute name="background">
      <dia:color val="#ffffff"/>
    </dia:attribute>
    <dia:attribute name="pagebreak">
      <dia:color val="#000099"/>
    </dia:attribute>
    <dia:attribute name="paper">
      <dia:composite type="paper">
        <dia:attribute name="name">
          <dia:string>#A4#</dia:string>
        </dia:attribute>
        <dia:attribute name="tmargin">
          <dia:real val="2.8222000598907471"/>
        </dia:attribute>
        <dia:attribute name="bmargin">
          <dia:real val="2.8222000598907471"/>
        </dia:attribute>
        <dia:attribute name="lmargin">
          <dia:real val="2.8222000598907471"/>
        </dia:attribute>
        <dia:attribute name="rmargin">
          <dia:real val="2.8222000598907471"/>
        </dia:attribute>
        <dia:attribute name="is_portrait">
          <dia:boolean val="true"/>
        </dia:attribute>
        <dia:attribute name="scaling">
          <dia:real val="1"/>
        </dia:attribute>
        <dia:attribute name="fitto">
          <dia:boolean val="false"/>
        </dia:attribute>
      </dia:composite>
    </dia:attribute>
    <dia:attribute name="grid">
      <dia:composite type="grid">
        <dia:attribute name="width_x">
          <dia:real val="1"/>
        </dia:attribute>
        <dia:attribute name="width_y">
          <dia:real val="1"/>
        </dia:attribute>
        <dia:attribute name="visible_x">
          <dia:int val="1"/>
        </dia:attribute>
        <dia:attribute name="visible_y">
          <dia:int val="1"/>
        </dia:attribute>
        <dia:composite type="color"/>
      </dia:composite>
    </dia:attribute>
    <dia:attribute name="color">
      <dia:color val="#d8e5e5"/>
    </dia:attribute>
    <dia:attribute name="guides">
      <dia:composite type="guides">
        <dia:attribute name="hguides"/>
        <dia:attribute name="vguides"/>
      </dia:composite>
    </dia:attribute>
  </dia:diagramdata>
  <dia:layer name="Background" visible="true" active="true">
    <dia:object type="Flowchart - Box" version="0" id="O0">
      <dia:attribute name="obj_pos">
        <dia:point val="3.85,19.5"/>
      </dia:attribute>
      <dia:attribute name="obj_bb">
        <dia:rectangle val="3.8,19.45;12.7062,25.1"/>
      </dia:attribute>
      <dia:attribute name="elem_corner">
        <dia:point val="3.85,19.5"/>
      </dia:attribute>
      <dia:attribute name="elem_width">
        <dia:real val="8.8062000014901134"/>
      </dia:attribute>
      <dia:attribute name="elem_height">
        <dia:real val="5.5500000000000016"/>
      </dia:attribute>
      <dia:attribute name="border_width">
        <dia:real val="0.10000000149011612"/>
      </dia:attribute>
      <dia:attribute name="inner_color">
        <dia:color val="#0000ff"/>
      </dia:attribute>
      <dia:attribute name="show_background">
        <dia:boolean val="true"/>
      </dia:attribute>
      <dia:attribute name="padding">
        <dia:real val="0.5"/>
      </dia:attribute>
      <dia:attribute name="text">
        <dia:composite type="text">
          <dia:attribute name="string">
            <dia:string>#SHINY#</dia:string>
          </dia:attribute>
          <dia:attribute name="font">
            <dia:font family="sans" style="0" name="Helvetica"/>
          </dia:attribute>
          <dia:attribute name="height">
            <dia:real val="0.80000000000000004"/>
          </dia:attribute>
          <dia:attribute name="pos">
            <dia:point val="8.2531,21.67"/>
          </dia:attribute>
          <dia:attribute name="color">
            <dia:color val="#000000"/>
          </dia:attribute>
          <dia:attribute name="alignment">
            <dia:enum val="1"/>
          </dia:attribute>
        </dia:composite>
      </dia:attribute>
    </dia:object>
    <dia:object type="Standard - Line" version="0" id="O1">
      <dia:attribute name="obj_pos">
        <dia:point val="8.15,11.85"/>
      </dia:attribute>
      <dia:attribute name="obj_bb">
        <dia:rectangle val="8.09933,11.7993;8.30377,19.5507"/>
      </dia:attribute>
      <dia:attribute name="conn_endpoints">
        <dia:point val="8.15,11.85"/>
        <dia:point val="8.2531,19.5"/>
      </dia:attribute>
      <dia:attribute name="numcp">
        <dia:int val="1"/>
      </dia:attribute>
      <dia:attribute name="line_color">
        <dia:color val="#00ff00"/>
      </dia:attribute>
      <dia:connections>
        <dia:connection handle="0" to="O3" connection="13"/>
        <dia:connection handle="1" to="O0" connection="2"/>
      </dia:connections>
    </dia:object>
    <dia:object type="Standard - Text" version="1" id="O2">
      <dia:attribute name="obj_pos">
        <dia:point val="8.20155,15.675"/>
      </dia:attribute>
      <dia:attribute name="obj_bb">
        <dia:rectangle val="8.20155,15.08;17.5641,16.6251"/>
      </dia:attribute>
      <dia:attribute name="text">
        <dia:composite type="text">
          <dia:attribute name="string">
            <dia:string>#LINE TEXT#</dia:string>
          </dia:attribute>
          <dia:attribute name="font">
            <dia:font family="sans" style="0" name="Helvetica"/>
          </dia:attribute>
          <dia:attribute name="height">
            <dia:real val="0.80010001542891396"/>
          </dia:attribute>
          <dia:attribute name="pos">
            <dia:point val="8.20155,15.675"/>
          </dia:attribute>
          <dia:attribute name="color">
            <dia:color val="#000000"/>
          </dia:attribute>
          <dia:attribute name="alignment">
            <dia:enum val="0"/>
          </dia:attribute>
        </dia:composite>
      </dia:attribute>
      <dia:attribute name="valign">
        <dia:enum val="3"/>
      </dia:attribute>
      <dia:connections>
        <dia:connection handle="0" to="O1" connection="0"/>
      </dia:connections>
    </dia:object>
    <dia:object type="Flowchart - Box" version="0" id="O3">
      <dia:attribute name="obj_pos">
        <dia:point val="3.81875,6.6"/>
      </dia:attribute>
      <dia:attribute name="obj_bb">
        <dia:rectangle val="3.76875,6.55;12.5313,11.9"/>
      </dia:attribute>
      <dia:attribute name="elem_corner">
        <dia:point val="3.81875,6.6"/>
      </dia:attribute>
      <dia:attribute name="elem_width">
        <dia:real val="8.6624999999999996"/>
      </dia:attribute>
      <dia:attribute name="elem_height">
        <dia:real val="5.2500000000000044"/>
      </dia:attribute>
      <dia:attribute name="show_background">
        <dia:boolean val="true"/>
      </dia:attribute>
      <dia:attribute name="padding">
        <dia:real val="0.5"/>
      </dia:attribute>
      <dia:attribute name="text">
        <dia:composite type="text">
          <dia:attribute name="string">
            <dia:string>###
bb1-router
#&lt;map?file=bb1-router&gt;#</dia:string>
          </dia:attribute>
          <dia:attribute name="font">
            <dia:font family="sans" style="0" name="Helvetica"/>
          </dia:attribute>
          <dia:attribute name="height">
            <dia:real val="0.80000000000000004"/>
          </dia:attribute>
          <dia:attribute name="pos">
            <dia:point val="8.15,8.62"/>
          </dia:attribute>
          <dia:attribute name="color">
            <dia:color val="#000000"/>
          </dia:attribute>
          <dia:attribute name="alignment">
            <dia:enum val="1"/>
          </dia:attribute>
        </dia:composite>
      </dia:attribute>
    </dia:object>
    <dia:object type="Standard - Text" version="1" id="O4">
      <dia:attribute name="obj_pos">
        <dia:point val="3.1,-10.1"/>
      </dia:attribute>
      <dia:attribute name="obj_bb">
        <dia:rectangle val="3.1,-10.695;25.4975,-6.75"/>
      </dia:attribute>
      <dia:attribute name="text">
        <dia:composite type="text">
          <dia:attribute name="string">
            <dia:string>#Things to Solve:
How to do the clickmap
https://mail.gnome.org/archives/dia-list/2005-January/msg00065.html
http://fossies.org/dox/dia-0.97.2/imgmap_8py_source.html
#</dia:string>
          </dia:attribute>
          <dia:attribute name="font">
            <dia:font family="sans" style="0" name="Helvetica"/>
          </dia:attribute>
          <dia:attribute name="height">
            <dia:real val="0.80000000000000004"/>
          </dia:attribute>
          <dia:attribute name="pos">
            <dia:point val="3.1,-10.1"/>
          </dia:attribute>
          <dia:attribute name="color">
            <dia:color val="#000000"/>
          </dia:attribute>
          <dia:attribute name="alignment">
            <dia:enum val="0"/>
          </dia:attribute>
        </dia:composite>
      </dia:attribute>
      <dia:attribute name="valign">
        <dia:enum val="3"/>
      </dia:attribute>
    </dia:object>
  </dia:layer>
</dia:diagram>

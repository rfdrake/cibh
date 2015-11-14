use Test::More;
eval 'use Test::Spelling 0.20';
plan skip_all => 'Test::Spelling 0.20 required for testing POD coverage' if $@;

add_stopwords(<DATA>);
all_pod_files_spelling_ok();

__END__
AddAlias
AdjustBounds
AdjustForThickness
BottomTicks
BuildImage
BuildMap
BuildWindows
CanvasCoords
Convienence
DIA
DrawLines
EllipseBounds
EllipseMap
FigEllipse
FigImage
FigLines
FigText
FilledBox
FindExtremes
FirstValue
GetAliases
GetAliasesFromAddresses
GetAliasesFromDescriptions
GetBoundaries
GetColor
GetDayBoundaries
GetDeltas
GetFont
GetHourBoundaries
GetMonthBoundaries
GetNumericBoundaries
GetRecord
GetUnits
GetUtilization
GetValues
GetWeekBoundaries
Graphviz
GroupBounds
HandleString
HorizontalDemarks
IMGMAP
ImageMap
InfluxDB
LeftTicks
LineBounds
LineMap
MakePolygon
Maxvalue
NextRecord
NextValue
OpenTSDB
PrintText
ProcessColors
ReadFig
ReadLogs
RightTicks
SNMPData
SVG
SetStyle
Spikekiller
StoreMapping
StringLength
TextBounds
TimeBoundaries
TopTicks
VerticalDemarks
XAxis
XY
YAxis
bb
cibhrc
csImageMap
datasources
datastores
dir
getter
hashtable
mapurl
nextrecord
parseline
parselink
poller
recordnum
recordsize
rgb
shennanigans
snmp
sparc
ssImageMap
startx
stopx
str
timespan
uncompress
xfig
CIBHRC
GetFiles
TimeWarp
coord
datasource
datastore
grapher
usemin
CounterAppend
Datafile
Dia
GaugeAppend
SNMP
graphviz
norequire
svg
PNG
png
OctetsAppend
CIBH
RGB
dia
imgmap
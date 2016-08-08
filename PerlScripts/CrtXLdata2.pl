use strict;
use Win32::OLE;
use Win32::OLE::Const 'Microsoft Excel';

my $Excel = Win32::OLE->new("Excel.Application");
$Excel->{Visible} = 1;

my $Book = $Excel->Workbooks->Add;
my $Sheet = $Book->Worksheets(1);
my $Range = $Sheet->Range("A2:C7");
$Range->{Value} =
    [['Delivered', 'En route', 'To be shipped'],
     [504, 102, 86],
     [670, 150, 174],
     [891, 261, 201],
     [1274, 471, 321],
     [1563, 536, 241]];

my $Chart = $Excel->Charts->Add;
$Chart->{ChartType} = xlAreaStacked;
$Chart->SetSourceData({Source => $Range, PlotBy => xlColumns});
$Chart->{HasTitle} = 1;
$Chart->ChartTitle->{Text} = "Items delivered, en route and to be shipped";


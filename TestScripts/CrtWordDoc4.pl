#!perl -w
#

use strict;
use Win32::OLE;
use Win32::OLE::Const;

# --------------------------------------------------------------------

my($outputFile) = 'C:\evan\source\testdata\crtworddoc4.doc';
unlink($outputFile);

my($word) = Win32::OLE -> new('Word.Application', 'Quit');

$word -> {Visible} = 1;  # Watch what happens
my($doc) = $word -> Documents -> Add(); # Create a new document
my($range) = $doc -> {Content};

# here we add a first level heading
# ---> we still need to add outline numbering....

$range->{Style}=('Heading 1');
$range->{Text} = 'This will be the document heading';

# here we add a second level heading
# ---> we still need to add outline numbering....

$range->InsertParagraphAfter();
$range->{Style}=('Heading 2');
$range->{Text} = 'This will be the section heading';

# A paragraph or two added for documentation sake

$range->InsertParagraphAfter();
$range->{Style}=('Normal');
$range->{Text} = 'having said that let me say this - it is in the interest of every Australian that this whole final 8 fiasco be sorted out. Interesting that Denis Pagan should choose to coach carlton just when its getting its hand slapped by theAFL for breaches of the salary cap - perhaps well anyway - what he said, yeah';
$range->InsertParagraphAfter();
$range->{Style}=('Normal');
$range->{Text} = 'OK another paragraph following the first just to see what happens when we add a significant amount of text - next I am going to try and add a atable. I guess even if it doesnt all pan out perfectly that the main thingg is I can generat most of the document reasonably well';



#    ActiveDocument.Tables.Add Range:=Selection.Range, NumRows:=2, NumColumns:= 2
#    Selection.TypeText Text:="450"
#    Selection.MoveRight Unit:=wdCell
#    Selection.TypeText Text:="200"
#    Selection.MoveRight Unit:=wdCell
#    Selection.TypeText Text:="Evans great"
#    Selection.MoveRight Unit:=wdCell
#    Selection.TypeText Text:="perl script"
#    Selection.MoveRight Unit:=wdCell
#    Selection.TypeText Text:="add"
#    Selection.MoveRight Unit:=wdCell
#    Selection.TypeText Text:="a line"
#    Selection.MoveRight Unit:=wdCell
#    Selection.TypeText Text:="and "
#    Selection.MoveRight Unit:=wdCell
#    Selection.TypeText Text:="another"
#    Selection.MoveRight Unit:=wdCell

$doc -> SaveAs($outputFile);
$doc -> Close();
$word -> Quit();

# Success.
print "Success \n";
exit(0);

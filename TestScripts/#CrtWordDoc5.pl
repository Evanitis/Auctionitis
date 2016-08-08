#!perl -w
#

use strict;
use Win32::OLE;
use Win32::OLE::Const;
use Win32::OLE::Const 'Microsoft Word';

# --------------------------------------------------------------------

my $wd = Win32::OLE::Const->Load("Microsoft Word 10\.0 Object Library");
my($outputFile) = 'C:\evan\source\testdata\crtworddoc4.doc';
unlink($outputFile);

my($coachname) = "Wayne Brittain";

my($word) = Win32::OLE -> new('Word.Application', 'Quit');

$word -> {Visible} = 1;  # Watch what happens
my($doc) = $word -> Documents -> Add(); # Create a new document
my($range) = $doc -> {Content};

# here we add a first level heading
# ---> we still need to add outline numbering....

## ActiveDocument.Content.InsertParagraphAfter  <-- from word help text


$range->{Style}=('Heading 1');
$range->{Text} = "This will be the document heading";

# - try and set the document numbering stuff.....

$range->{ListFormat}->NumberFormat = ('%1');
$range->{ListFormat}->ApplyOutlineNumberDefault();


# insert blank line with normal text

$range->InsertParagraphAfter();
$range->Move({Unit => wdParagraph, Count => 1});
$range->{Style}=('Normal');
$range->{text} = "";

# here we add a second level heading
# ---> we still need to add outline numbering....

$range->InsertParagraphAfter();
$range->Move({Unit => wdParagraph, Count => 1});
$range->{Style}=('Heading 2');
$range->{text}="This will be the section heading";

# insert blank line with normal text

$range->InsertParagraphAfter();
$range->Move({Unit => wdParagraph, Count => 1});
$range->{Style}=('Normal');
$range->{text} = "";

# Add a paragraph of text

$range->InsertParagraphAfter();
$range->Move({Unit => wdParagraph, Count => 1});
$range->{Style}=('Normal');
$range->{text} = "having said that let me say this - it is in the interest of every Australian that this whole final 8 fiasco be sorted out. Interesting that $coachname should choose to coach carlton just when its getting its hand slapped by theAFL for breaches of the salary cap - perhaps well anyway - what he said, yeah";

# insert blank line with normal text

$range->InsertParagraphAfter();
$range->Move({Unit => wdParagraph, Count => 1});
$range->{Style}=('Normal');
$range->{text} = "";

# Add a paragraph of text

$range->InsertParagraphAfter();
$range->Move({Unit => wdParagraph, Count => 1});
$range->{Style}=('Normal');
$range->{Text} = "OK another paragraph following the first just to see what happens when we add a significant amount of text - next I am going to try and add a atable. I guess even if it doesnt all pan out perfectly that the main thingg is I can generat most of the document reasonably well";

# insert blank line with normal text

$range->InsertParagraphAfter();
$range->Move({Unit => wdParagraph, Count => 1});
$range->{Style}=('Normal');
$range->{text} = "";

# OK... now lets try and add a table.....

$range->InsertParagraphAfter();
$range->Move({Unit => wdParagraph, Count => 1});

my($table) = $doc->Tables->Add({Range => $range,  NumRows => 1, NumColumns => 2});

$range->{text} = "Name";
$range->Move({Unit => wdCell, Count => 1});
$range->{text} = "Surname";

$table->Rows->Add();
$range->Move({Unit => wdRow, Count => 1});
$range->{text} = "Evan";
$range->Move({Unit => wdCell, Count => 1});
$range->{text} = "Harris";

$table->Rows->Add();
$range->Move({Unit => wdCell, Count => 1});
$range->{text} = "Tracey MacKenzie";
$range->Move({Unit => wdCell, Count => 1});
$range->{text} = "Weaver";

$table->Rows->Add();
$range->Move({Unit => wdCell, Count => 1});
$range->{text} = "Skippy";
$range->Move({Unit => wdCell, Count => 1});
$range->{text} = "the environmental monitoring kangaroo";

$table->Rows->Add();
$range->Move({Unit => wdCell, Count => 1});
$range->{text} = "Dave";
$range->Move({Unit => wdCell, Count => 1});
$range->{text} = "Wombat White";

$table->Rows->Add();
$range->Move({Unit => wdCell, Count => 1});
$range->{text} = "Paul";
$range->Move({Unit => wdCell, Count => 1});
$range->{text} = "Weaver";

$table->Rows->Add();
$range->Move({Unit => wdCell, Count => 1});
$range->{text} = "Jonathon";
$range->Move({Unit => wdCell, Count => 1});
$range->{text} = "Scott";

$table->Rows->Add();
$range->Move({Unit => wdCell, Count => 1});
$range->{text} = "Marcus";
$range->Move({Unit => wdCell, Count => 1});
$range->{text} = "Finlay";

## This is all from the word macro generator for use as a template...
##   ActiveDocument.Tables.Add Range:=Selection.Range, NumRows:=2, NumColumns:= 2;
##   Selection.TypeText Text:="450";
##   Selection.MoveRight Unit:=wdCell;
##   Selection.TypeText Text:="200";
##   Selection.MoveRight Unit:=wdCell;
##   Selection.TypeText Text:="Evans great";
##   Selection.MoveRight Unit:=wdCell;
##   Selection.TypeText Text:="perl script";
##   Selection.MoveRight Unit:=wdCell;
##   Selection.TypeText Text:="add";
##   Selection.MoveRight Unit:=wdCell;
##   Selection.TypeText Text:="a line";
##   Selection.MoveRight Unit:=wdCell;
##   Selection.TypeText Text:="and ";
##   Selection.MoveRight Unit:=wdCell;
##   Selection.TypeText Text:="another";
##   Selection.MoveRight Unit:=wdCell;

print "$outputFile\n";

$doc->SaveAs({FileName=>"$outputFile"});
#$doc -> SaveAs($outputFile);
$doc -> Close();
$word -> Quit();

# Success.
print "Success \n";
exit(0);

#!perl -w
#

#use strict;
use Win32::OLE;
use Win32::OLE::Const;
use Win32::OLE::Const 'Microsoft Word';

# --------------------------------------------------------------------
my $paracount;
my $cancontinue;
my $restartnos;
my $true = 1;
my $wd = Win32::OLE::Const->Load("Microsoft Word 10\.0 Object Library");
my($outputFile) = 'C:\evan\source\testdata\crtworddoc4.doc';
unlink($outputFile);

my($coachname) = "Ebenezer Goode";

my($word) = Win32::OLE -> new('Word.Application', 'Quit');

$word -> {Visible} = 1;  # Watch what happens
my($doc) = $word -> Documents -> Add(); # Create a new document
my($range) = $doc -> {Content};
$paracount = $doc->{Paragraphs}->Count();
print "Paragraphs Count: $paracount \n";

# this is where we set the heading numbering values via the list template object
my($list) = $doc->ListTemplates->Add("True", "Evan");

#make the list template object an outline numbered list
$list->{OutlineNumbered}="True";
$list->ListLevels(1)->{NumberFormat}="%1";
$list->ListLevels(1)->{StartAt}="4";
$list->ListLevels(1)->{LinkedStyle}="Heading 1";

my $Continue = $list->ListLevels(1)->{ResetOnHigher};
print ">> Continue List Levels(1): $Continue \n";

$list->ListLevels(2)->{StartAt}="1";
$list->ListLevels(2)->{NumberFormat}="%1.%1";
$list->ListLevels(2)->{LinkedStyle}="Heading 2";

$Continue = $list->ListLevels(2)->{ResetOnHigher};
print ">> Continue List Levels(2): $Continue \n";

# print out all the list levels in the added level
my $levels = $list->{ListLevels}->count();
print ">> List Levels: $levels \n";

# here we add a first level heading
# ---> we still need to add outline numbering....

## ActiveDocument.Content.InsertParagraphAfter  <-- from word help text

$range->{Style}=('Heading 1');
$range->{Text} = "This will be the document heading";
# $range->Select();
$range->{ListFormat}->ApplyListTemplate({ListTemplate => "Evan", "True"});
$paracount = $doc->{Paragraphs}->Count();
print "Paragraphs Count: $paracount \n";
# insert blank line with normal text

$range->InsertParagraphAfter();
$range->Move({Unit => wdParagraph, Count => 1});
$range->{Style}=('Normal');
$range->{text} = "";
$paracount = $doc->{Paragraphs}->Count();
print "Paragraphs Count: $paracount \n";

# insert blank line with normal text

$range->InsertParagraphAfter();
$range->Move({Unit => wdParagraph, Count => 1});
$range->{Style}=('Normal');
$range->{text} = "";
$paracount = $doc->{Paragraphs}->Count();
print "Paragraphs Count: $paracount \n";

# Add a paragraph of text
# Note this is where the introductory paragraph would be
# We are doing this to test how indents will and should look

$range->InsertParagraphAfter();
$range->Move({Unit => wdParagraph, Count => 1});
$range->{Style}=('Normal');
$range->{text} = "Here I am going to introduce the topic. Its just an introduction but we will be able to establish just where the indents should go. A difficult subject in my experience as they end up being so far in that it starts too look funny. Maybe that is just one of those things you have to wear when you deal with multi-level documents";
$paracount = $doc->{Paragraphs}->Count();
print "Paragraphs Count: $paracount \n";
$doc->Paragraphs($paracount)->indent();
$doc->Paragraphs($paracount)->indent();

# insert blank line with normal text

$range->InsertParagraphAfter();
$range->Move({Unit => wdParagraph, Count => 1});
$range->{Style}=('Normal');
$range->{text} = "";
$paracount = $doc->{Paragraphs}->Count();
print "Paragraphs Count: $paracount \n";
# here we add a second level heading
# ---> we still need to add outline numbering....

$range->InsertParagraphAfter();
$range->Move({Unit => wdParagraph, Count => 1});
$range->{Style}=('Heading 2');
$range->{text}="This will be the section heading";
$range->{ListFormat}->ApplyListTemplate({ListTemplate => $list, True});
$paracount = $doc->{Paragraphs}->Count();
print "Paragraphs Count: $paracount \n";
$doc->Paragraphs($paracount)->indent();

# insert blank line with normal text

$range->InsertParagraphAfter();
$range->Move({Unit => wdParagraph, Count => 1});
$range->{Style}=('Normal');
$range->{text} = "";
$paracount = $doc->{Paragraphs}->Count();
print "Paragraphs Count: $paracount \n";

# Add a paragraph of text

$range->InsertParagraphAfter();
$range->Move({Unit => wdParagraph, Count => 1});
$range->{Style}=('Normal');
$range->{text} = "having said that let me say this - it is in the interest of every Australian that this whole final 8 fiasco be sorted out. Interesting that $coachname should choose to coach carlton just when its getting its hand slapped by theAFL for breaches of the salary cap - perhaps well anyway - what he said, yeah";
$paracount = $doc->{Paragraphs}->Count();
print "Paragraphs Count: $paracount \n";
$doc->Paragraphs($paracount)->indent();
$doc->Paragraphs($paracount)->indent();
$doc->Paragraphs($paracount)->indent();

# insert blank line with normal text

$range->InsertParagraphAfter();
$range->Move({Unit => wdParagraph, Count => 1});
$range->{Style}=('Normal');
$range->{text} = "";
$paracount = $doc->{Paragraphs}->Count();
print "Paragraphs Count: $paracount \n";

# Add a paragraph of text

$range->InsertParagraphAfter();
$range->Move({Unit => wdParagraph, Count => 1});
$range->{Style}=('Normal');
$range->{Text} = "OK another paragraph following the first just to see what happens when we add a significant amount of text - next I am going to try and add a atable. I guess even if it doesnt all pan out perfectly that the main thing is I can generate most of the document reasonably well. Actually I will add the table after I checkout the layout and heading numbering and indentation";
$paracount = $doc->{Paragraphs}->Count();
print "Paragraphs Count: $paracount \n";
$doc->Paragraphs($paracount)->indent();
$doc->Paragraphs($paracount)->indent();
#$doc->Paragraphs($paracount)->indent();

# insert blank line with normal text

$range->InsertParagraphAfter();
$range->Move({Unit => wdParagraph, Count => 1});
$range->{Style}=('Normal');
$range->{text} = "";
$paracount = $doc->{Paragraphs}->Count();
print "Paragraphs Count: $paracount \n";
# insert blank line with normal text

$range->InsertParagraphAfter();
$range->Move({Unit => wdParagraph, Count => 1});
$range->{Style}=('Normal');
$range->{text} = "";
$paracount = $doc->{Paragraphs}->Count();
print "Paragraphs Count: $paracount \n";
# here we add a second level heading
# ---> we still need to add outline numbering....

$range->InsertParagraphAfter();
$range->Move({Unit => wdParagraph, Count => 1});
$range->{Style}=('Heading 2');
$range->{text}="This will be the second section heading";
#$range->{ListFormat}->ApplyListTemplate({ListTemplate => $list});
$paracount = $doc->{Paragraphs}->Count();
print "Paragraphs Count: $paracount \n";
$doc->Paragraphs($paracount)->indent();

# insert blank line with normal text

$range->InsertParagraphAfter();
$range->Move({Unit => wdParagraph, Count => 1});
$range->{Style}=('Normal');
$range->{text} = "";
$paracount = $doc->{Paragraphs}->Count();
print "Paragraphs Count: $paracount \n";

# Add a paragraph of text

$range->InsertParagraphAfter();
$range->Move({Unit => wdParagraph, Count => 1});
$range->{Style}=('Normal');
$range->{text} = "having said that let me say this - it is in the interest of every Australian that this whole final 8 fiasco be sorted out. Interesting that $coachname should choose to coach carlton just when its getting its hand slapped by theAFL for breaches of the salary cap - perhaps well anyway - what he said, yeah";
$paracount = $doc->{Paragraphs}->Count();
print "Paragraphs Count: $paracount \n";
$doc->Paragraphs($paracount)->indent();
$doc->Paragraphs($paracount)->indent();
$doc->Paragraphs($paracount)->indent();

# insert blank line with normal text

$range->InsertParagraphAfter();
$range->Move({Unit => wdParagraph, Count => 1});
$range->{Style}=('Normal');
$range->{text} = "";
$paracount = $doc->{Paragraphs}->Count();
print "Paragraphs Count: $paracount \n";

# Add a paragraph of text

$range->InsertParagraphAfter();
$range->Move({Unit => wdParagraph, Count => 1});
$range->{Style}=('Normal');
$range->{Text} = "More crap. This paragraph has been inserted to see what happens when I am indenting things. Seems like the second paragraph after a heading gets lined up automatically, at least for one indent. I am going to leave off all the indents for this to start with, then add them back one by one as ncessary. Up above I took out one of the indents in the second paragraph, so we;'ll see if that lines up correctly";
$paracount = $doc->{Paragraphs}->Count();
print "Paragraphs Count: $paracount \n";
$doc->Paragraphs($paracount)->indent();
$doc->Paragraphs($paracount)->indent();
#$doc->Paragraphs($paracount)->indent();

$range->InsertParagraphAfter();
$range->Move({Unit => wdParagraph, Count => 1});
$range->{Style}=('Normal');
$range->{text} = "";
$paracount = $doc->{Paragraphs}->Count();
print "Paragraphs Count: $paracount \n";

# Add a paragraph of text

$range->InsertParagraphAfter();
$range->Move({Unit => wdParagraph, Count => 1});
$range->{Style}=('Normal');
$range->{Text} = "Well, I have established that leaving off one of the indents will cause the second paragraph under a heading to line up. I'm not sure why yet but no doubt all will become clear.";
$paracount = $doc->{Paragraphs}->Count();
print "Paragraphs Count: $paracount \n";
$doc->Paragraphs($paracount)->indent();
$doc->Paragraphs($paracount)->indent();
#$doc->Paragraphs($paracount)->indent();

# insert blank line with normal text

$range->InsertParagraphAfter();
$range->Move({Unit => wdParagraph, Count => 1});
$range->{Style}=('Normal');
$range->{text} = "";
$paracount = $doc->{Paragraphs}->Count();
print "Paragraphs Count: $paracount \n";

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

$paracount = $doc->{Paragraphs}->Count();
print "Paragraphs Count (after table): $paracount \n";
print "$outputFile\n";

$doc->SaveAs({FileName=>"$outputFile"});
#$doc -> SaveAs($outputFile);
$doc -> Close();
$word -> Quit();

# Success.
print "Success \n";
exit(0);

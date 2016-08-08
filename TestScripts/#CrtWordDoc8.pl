#!perl -w

use strict;
use Win32::OLE;
use Win32::OLE::Variant;
use Win32::OLE::Const;
use Win32::OLE::Const 'Microsoft Word';

my($true) = Variant(VT_BOOL, 1);
my($paracount);
my $wd = Win32::OLE::Const->Load("Microsoft Word 10\.0 Object Library");
my($outputFile) = 'C:\evan\source\testdata\crtworddoc5.doc';
unlink($outputFile);

my($word) = Win32::OLE -> new('Word.Application', 'Quit');

$word -> {Visible} = 1;  # Watch what happens

my($doc) = $word -> Documents -> Add(); # Create a new document

# Extract/Update the document properties I am interested in..
$word->{UserName} = "Evan Harris (Perl generated document)";
my($author) = $word->{UserName};
print "Written by: $author\n";

my($range) = $doc -> {Content};

# this is where I format any bullet lists I add to the document

my($bullets) = $word->ListGalleries(wdBulletGallery)->ListTemplates(3);

# this is where we set the heading numbering values via the list template object
# Nothing sophisticated - just using the standard default outline template

my($list) = $word->ListGalleries(wdOutlineNumberGallery)->ListTemplates(5);

# this line sets the heading level 1 numbering value

$list->ListLevels(1)->{StartAt}="4";

# here we add a first level heading

$range->{Style}=('Heading 1');
$range->{Text} = "This will be the document heading";
$range->{ListFormat}->ApplyListTemplate({ListTemplate => $list, ContinuePreviousList => $true});

# insert blank line with normal text
$range->InsertParagraphAfter();
$range->Move({Unit => wdParagraph, Count => 1});
$range->{Style}=('Normal');
$range->{text} = "";

# Add a paragraph of text
# Note this is where the introductory paragraph would be
# We are doing this to test how indents will and should look

$range->InsertParagraphAfter();
$range->Move({Unit => wdParagraph, Count => 1});
$range->{Style}=('Normal');
$paracount = $doc->{Paragraphs}->Count();
$doc->Paragraphs($paracount)->indent();
$range->{text} = <<EOD;
Here I am going to introduce the topic. Its just an introduction but we will be able to establish just where the indents should go. A difficult subject in my experience as they end up being so far in that it starts too look funny. Maybe that is just one of those things you have to wear when you deal with multi-level documents
EOD

# Add another paragraph
# with no spacing paragraph to see what happens

my($herevar)="This Word automation stuff is pretty clever";

$range->InsertParagraphAfter();
$range->Move({Unit => wdParagraph, Count => 1});
$range->{Style}=('Normal');
$paracount = $doc->{Paragraphs}->Count();
$doc->Paragraphs($paracount)->indent();
$range->{text} = <<EOD;
I don't have the hang of the indenting yet. It seems that the first level needs an extra indent and subsequent paragraphs and lines get it anyway. Bizarre to say the least. Now that I am using here documents for the paragraph data its a little easier to track what is being written - not to mention typing and reading it. This is a variable --> $herevar <-- that I have put in just for curiosity sake (or maybe demonstration purposes).
EOD

# insert blank line with normal text

$range->InsertParagraphAfter();
$range->Move({Unit => wdParagraph, Count => 1});
$range->{Style}=('Normal');
$range->{text} = "";

# here we add a second level heading (indented)

$range->InsertParagraphAfter();
$range->Move({Unit => wdParagraph, Count => 1});
$range->{Style}=('Heading 2');
$paracount = $doc->{Paragraphs}->Count();
$doc->Paragraphs($paracount)->indent();
$doc->Paragraphs($paracount)->indent();
$range->{text}="This will be the second section heading";
$range->{ListFormat}->ApplyListTemplate({ListTemplate => $list, ContinuePreviousList => $true});

# insert blank line with normal text
$range->InsertParagraphAfter();
$range->Move({Unit => wdParagraph, Count => 1});
$range->{Style}=('Normal');
$range->{text} = "";

# here we add another second level heading

$range->InsertParagraphAfter();
$range->Move({Unit => wdParagraph, Count => 1});
$range->{Style}=('Heading 2');
$range->{text}="Another section in the document";
$range->{ListFormat}->ApplyListTemplate({ListTemplate => $list, ContinuePreviousList => $true});;

#indent the second level heading

$paracount = $doc->{Paragraphs}->Count();
$doc->Paragraphs($paracount)->indent();

# insert blank line with normal text

$range->InsertParagraphAfter();
$range->Move({Unit => wdParagraph, Count => 1});
$range->{Style}=('Normal');
$range->{text} = "";

# here we add a third level heading

$range->InsertParagraphAfter();
$range->Move({Unit => wdParagraph, Count => 1});
$range->{Style}=('Heading 3');
$range->{text}="A document subsection";
$range->{ListFormat}->ApplyListTemplate({ListTemplate => $list, ContinuePreviousList => $true});;

#indent the third level heading

$paracount = $doc->{Paragraphs}->Count();
$doc->Paragraphs($paracount)->indent();
$doc->Paragraphs($paracount)->indent();
$doc->Paragraphs($paracount)->indent();

# insert blank line with normal text

$range->InsertParagraphAfter();
$range->Move({Unit => wdParagraph, Count => 1});
$range->{Style}=('Normal');
$range->{text} = "";

# now we stick in some bullet points

$range->InsertParagraphAfter();
$range->Move({Unit => wdParagraph, Count => 1});
$range->{Style}=('Normal');
$range->{text}="Bullets are cool";
$paracount = $doc->{Paragraphs}->Count();
$doc->Paragraphs($paracount)->indent();
$doc->Paragraphs($paracount)->indent();
$doc->Paragraphs($paracount)->indent();
$doc->Paragraphs($paracount)->indent();
$range->{ListFormat}->ApplyListTemplate({ListTemplate => $bullets});
$range->InsertParagraphAfter();
$range->Move({Unit => wdParagraph, Count => 1});
$range->{Style}=('Normal');
$range->{text}="More Bullets are even cooler";
$range->{ListFormat}->ApplyListTemplate({ListTemplate => $bullets});
$paracount = $doc->{Paragraphs}->Count();
$doc->Paragraphs($paracount)->indent();
$doc->Paragraphs($paracount)->indent();
$doc->Paragraphs($paracount)->indent();

# insert blank line with normal text

$range->InsertParagraphAfter();
$range->Move({Unit => wdParagraph, Count => 1});
$range->{Style}=('Normal');
$range->{text} = "";


# Save the document and exit
$doc->SaveAs({FileName=>"$outputFile"});
#$doc -> SaveAs($outputFile);
$doc -> Close();
$word -> Quit();

# Success.
print "Success \n";
exit(0);

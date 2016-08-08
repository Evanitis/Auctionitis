#!perl -w

use strict;
use WordLite;

my $doc = WordLite->new(filename => "C:\\evan\\source\\testdata\\simpleword.doc");

print "Filename being processed is: ", $doc->filename(), "\n";

my $list = WordLite->new_outline_list(5);

my $newlist = WordLite->new_list(gallery  => "wdOutlineNumberGallery",
                                 template => 5);
$doc->visible(1);
WordLite->Verbose(1);                                
                              
$doc->writeline(text => "Table of Cuntents",
                startpara => 1,
                font => "Arial",
                align => "centre",
                bold => 1,
                underline => 1,
                fontsize => 14);
            
$doc->write();

$doc->addtoc();

$doc->pagebreak();

$doc->write(text => "This is the document heading",
            style => "Heading 1");

$doc->write();

# Output the document statistics to test count functions

my $pcount = $doc->paragraphcount();
print "Paragraphs: $pcount\n";

my $tcount = $doc->tablecount();
print "Tables:     $tcount\n";

my $ccount = $doc->shapecount();
print "Charts:     $ccount\n";

$doc->header("How do I add a table pr underlining and nesting ?");
$doc->footer("New Footer text");

$doc->write();
$doc->indentlevel(1);
$doc->write("Begin document testing. Good progress is being made in the automated document processing program.");

$doc->write();

$doc->write("One more paragraph to try and sort out this here document/indenting thing (mode test data and evidence)");

$doc->write();

$doc->write(text => "Progress so far",
            style => "Heading 2",
            listformat => $list);
$doc->write();
$doc->indentlevel(3);
$doc->write(text => "I don't have the hang of the indenting yet. It seems that the first level needs an extra indent and subsequent paragraphs and lines get it anyway. Bizarre to say the least. Now that I am using here documents for the paragraph data its a little easier to track what is being written - not to mention typing and reading it. This is a variable --> Not here right now... <-- that I have put in just for curiosity sake (or maybe demonstration purposes).");

$doc->write();
$doc->indentlevel(1);

$doc->write(text => "My new Sub-Heading",
            style => "Heading 2");
$doc->write();
$doc->indentlevel(3);
$doc->write("[Indent level:".$doc->indentlevel()."] Here I am going to introduce the topic by use of a here document (didn't work - try again after checking how cgi.pm does it). Its just an introduction but we will be able to establish just where the indents should go. A difficult subject in my experience as they end up being so far in that it starts too look funny. Maybe that is just one of those things you have to wear when you deal with multi-level documents.");

$doc->write();

$doc->write("[Indent level: ". $doc->indentlevel()."]A paragraph in between the main paragraph and the end paragraph. The only question is will it be long enough ?!?!");

$doc->write("[Indent level: ".$doc->indentlevel()."]");
$doc->indentlevel(1);
$doc->write(text => "Table of contents has been added",
            style => "Heading 2");
$doc->write();
$doc->indentlevel(3);
$doc->write("[Indent level: ".$doc->indentlevel()."] Right now we are working on the indentation specifics of the free range paragraph.");

$doc->write();

#$doc->write(<<EOF);
#This is a here document (and it works !) Having said that let me say this #- it is in the interest of every Australian that this whole final 8 #fiasco be sorted out. Interesting that Dennis Pagan should choose to #coach carlton just when its getting its hand slapped by the AFL for #breaches of the salary cap - perhaps well anyway - what he said, yeah
# EOF

$doc->write("This was a here document - the old one is now commentedout while i get the indenting thing under control. Having said that let me say this - it is in the interest of every Australian that this whole final 8 fiasco be sorted out. Interesting that Dennis Pagan should choose to coach carlton just when its getting its hand slapped by the AFL for breaces of the salary cap - perhaps well anyway - what he said, yeah");

$doc->write();

$doc->write("[Indent level: ".$doc->indentlevel()."] Interestingly, HERE documents don't seem to indent; yet they don't disrupt the indent level as the susbequent paragraphs do indent. I need to check how many paramaters get passed with them. Subsequent paragraphs also indent an extra level as far as I can tell");

$doc->write();
$doc->indentlevel(1);
$doc->write(text => "Bits and pieces still to do",
            style => "Heading 2");
$doc->write();
$doc->indentlevel(3);
$doc->write("More work needed on the quitting process but the paragraph generator now works remarkably well. We will move on to adding tables shortly and refining the list options");

$doc->write();

$doc->write("One more paragraph to try and sort out this here document/indenting thing (mode test data and evidence)");

# Output the document statistics to test count functions

$pcount = $doc->paragraphcount();
print "Paragraphs: $pcount\n";

$tcount = $doc->tablecount();
print "Tables:     $tcount\n";

$ccount = $doc->shapecount();
print "Charts:     $ccount\n";
$doc->indentlevel(1);
$doc->write(text => "Demonstration of Table capability",
            style => "Heading 2");
$doc->write();
$doc->indentlevel(3);
my @tabledata = ("Heading", "data");
$doc->addtable(@tabledata);
@tabledata = ("Row 2", "crap");
$doc->writerow(@tabledata);
@tabledata = ("Row 3", "more crap");
$doc->writerow(@tabledata);
$doc->tableend();

# Output the document statistics to test count functions

$pcount = $doc->paragraphcount();
print "Paragraphs: $pcount\n";

$tcount = $doc->tablecount();
print "Tables:     $tcount\n";

$ccount = $doc->shapecount();
print "Charts:     $ccount\n";


$doc->save();

# Success.

print "procesing complete \n";
exit(0);

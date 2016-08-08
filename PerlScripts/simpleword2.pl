#!perl -w

use strict;
use WordLite;

WordLite->Verbose(0);

my $doc = WordLite->new(filename => "C:\\evan\\source\\testdata\\simpleword2.doc");

print "Filename being processed is: ", $doc->filename(), "\n";

$doc->insertdatefield();
$doc->write();

$doc->write(text => "This is the document heading",
            style => "Heading 1");
            
$doc->write();
$doc->writeline(text => "Alignment -> Centre",
                startpara => 1,
                font => "Arial",
                align => "centre",
                rubish => "bad parameter");
$doc->write();
$doc->writeline(text => "Alignment -> distribute",
                startpara => 1,
                font => "Arial",
                align => "distribute");
$doc->write();
$doc->writeline(text => "Alignm\ent -> justify",
                startpara => 1,
                font => "Arial",
                align => "justify");
                
                  
$doc->write();
$doc->writeline(text => "Alignment -> justify_hi",
                startpara => 1,
                font => "Arial",
                align => "justify_hi");
                  
$doc->write();
$doc->writeline(text => "Alignment -> justify_low",
                startpara => 1,
                font => "Arial",
                align => "justify_low");
                  
$doc->write();
$doc->writeline(text => "Alignment -> justify_med",
                startpara => 1,
                font => "Arial",
                align => "justify_med");
                  
$doc->write();
$doc->writeline(text => "Alignment -> left",
                startpara => 1,
                font => "Arial",
                align => "left");
                  
$doc->write();
$doc->writeline(text => "Alignment -> right",
                startpara => 1,
                font => "Arial",
                align => "right");
                  
$doc->write();
$doc->writeline(text => "Alignment -> thai_justify",
                startpara => 1,
                font => "Arial",
                align => "thai_justify");
                 


                
# Output the document statistics to test count functions

my $pcount = $doc->paragraphcount();
print "Paragraphs: $pcount\n";

my $tcount = $doc->tablecount();
print "Tables:     $tcount\n";

my $ccount = $doc->shapecount();
print "Charts:     $ccount\n";

$doc->indentlevel(1);

$doc->writeline(text =>"Begin document testing. Good progress is being made in the automated document processing program.",
color => "wdColorRed",
background => "wdColorBlack",
startpara => 1);
$doc->writeline(text =>"Continuation line in dark green (previous line was in red).",
color => "wdColorGreen");

$doc->write();

$doc->writeline(text => "One more paragraph to try and sort out this here document/indenting thing (mode test data and evidence). Should be in arial with a font size of 8.",
                font => "Arial",
                fontsize => 8);                


$doc->writeline(text =>"Test the write line function; with new para and underlines.",
                startpara => 1,
                color => "wdColorGold",
                background => "wdColorBlack",
                underline => 1);
$doc->writeline(text =>"And test it again (bolded only). Automatic color test as well.",
                background => "wdColorAutomatic",
                bold => 1);
$doc->writeline(text=>"And test it one last time, this time italicised.",
                italic => 1);
$doc->writeline(text=>"This line is bold AND italics.",
                italic => 1,
                bold => 1);
$doc->writeline(text=>"Last but not least Bold, Italics and underlined.",
                bold => 1,
                underline => 1,
                fontsize => 18,                
                italic => 1);
$doc->writeline(text=>"Now make a font change on the fly.",
                font => "Arial",
                fontsize => 12);                
                
$doc->writeline(text=>"No extra formatting to finish off with.");
$doc->write();     
$doc->write("I think I still need to think about background colour, foreground colour, table heading formatting, bullet points, fonts and font sizes.");     
$doc->write();                
$doc->writeline(text =>"Test the bolding function in the write line function.",
                startpara => 1);
$doc->writeline(text =>" This bits bold but the previous bit shouldn't have been",
                bold => 1);

$doc->write();

$doc->write(text => "Progress so far",
            style => "Heading 2");
$doc->write();
$doc->write(text => "I don't have the hang of the indenting yet. It seems that the first level needs an extra indent and subsequent paragraphs and lines get it anyway. Bizarre to say the least. Now that I am using here documents for the paragraph data its a little easier to track what is being written - not to mention typing and reading it. This is a variable --> Not here right now... <-- that I have put in just for curiosity sake (or maybe demonstration purposes).");



$doc->save();

# Success.

print "procesing complete \n";
exit(0);

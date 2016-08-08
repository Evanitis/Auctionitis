#!perl -w

use strict;
use WordLite;

my $doc = WordLite->open(filename => "C:\\evan\\source\\testdata\\simpleword.doc");

print "Filename being processed is: ", $doc->filename(), "\n";

my $paracount = $doc->paragraphcount();
print "Paragraphs: $paracount\n";

my $tablecount = $doc->tablecount();
print "Tables:     $tablecount\n";

my $chartcount = $doc->shapecount();
print "Charts:     $chartcount\n";

for (my $index=1; $index <= $paracount; $index++) {
     my $paradata = $doc->read($index);
     my $style = $doc->getstyle($index);
     my $istable = "No";
     if ($doc->istable($index)) {$istable = "Yes";}
     print "------------------------------------------------------------------------\n";
     print "Paragraph: $index\n";
     print "Style    : $style\n";
     print "Table ?  : $istable\n";
     print "Data     : \n";
     print "$paradata\n";
     print "------------------------------------------------------------------------\n";
    }

$doc->close();

# Success.

print "procesing complete \n";
exit(0);

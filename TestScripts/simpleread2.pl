#!perl -w

use strict;
use WordLite;

my $doc = WordLite->open(filename => "C:\\evan\\source\\testdata\\simpleword.doc");

print "Filename being processed is: ", $doc->filename(), "\n";

my $paracount = $doc->paragraphcount();
print "Paragraphs: $paracount\n";
my $index = 1;
print "------------------------------------------------------------------------\n";
while ($index <= $paracount) {
    print "Index: $index\n";
    if (not $doc->istable($index)) {
#        my $paradata = $doc->read($index);
#        print "$paradata\n";
#        print "------------------------------------------------------------------------\n";
        $index++
    } else {
        my @cells = $doc->read_row($index);
        print "Columns returned: $#cells\n";
        for my $e (@cells) {
            print "Data: $e\n";
            my @ascii = unpack("C*", $e);
            print "ASCII: ".join(", ", @ascii)."\n";
        }
        print "\|\t".join("\| \t", @cells)."\t\|\n";
        $index = $#cells + 1 + $index;
        print "------------------------------------------------------------------------\n";
    }
}
$doc->close();

# Success.

print "procesing complete \n";
exit(0);

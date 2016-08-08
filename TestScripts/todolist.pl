#!perl -w

use strict;
use WordLite;

my $doc = WordLite->new(filename => "C:\\evan\\source\\testdata\\todolist.doc");
my $bullets = WordLite->bulletlist();
$doc->write(text => "To-Do list",
            style => "Heading 1");
$doc->write();

todo("Add document defaults to class");
todo("Identify and fix indent problem");
todo("Improve addition of charts");
todo("Test Perl2exe utility");

$doc->save();

# Success.

print "procesing complete \n";
exit(0);

sub todo {
my $todoitem = shift;
$doc->writeline(text       => $todoitem,
                startpara  => 1,
                listformat => $bullets);
}


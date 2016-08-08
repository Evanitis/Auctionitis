#!perl -w

use strict;
use WordLite;

my $doc = WordLite->new(filename => "C:\\evan\\source\\testdata\\simplerror.doc");

# test unknown function or method error message (remove comment symbol)

#my $error = $doc->unknown();

$doc->writeline(text =>"Test the write line function, with new para and underlines.",
                startpara => 1,
                underline => 1);
my $stylename = "Heading 1";
my $style = $doc->isstyle($stylename);
print "Style: $stylename is a style: $style \n";
$stylename = "Normal";
$style = $doc->isstyle($stylename);
print "Style: $stylename is a style: $style \n";
$stylename = "Signature";
$style = $doc->isstyle($stylename);
print "Style: $stylename is a style: $style \n";
$stylename = "TOA Heading";
$style = $doc->isstyle($stylename);
print "Style: $stylename is a style: $style \n";
$stylename = "Subtitle";
$style = $doc->isstyle($stylename);
print "Style: $stylename is a style: $style \n";
$stylename = "bullshit";
$style = $doc->isstyle($stylename);
print "Style: $stylename is a style: $style \n";


if ($doc->isstyle("Normal")) {
    print "isstyle() worked\n";
    } else {
    print "isstyle() failed\n";
    }

if ($doc->isfont("Arial")) {
    print "isfont() worked\n";
    } else {
    print "isfont() failed\n";
    }
if ($doc->isfont("Webdings")) {
    print "isfont() worked\n";
    } else {
    print "isfont() failed\n";
    }
if ($doc->isfont("Bullshit")) {
    print "isfont() worked\n";
    } else {
    print "isfont() failed\n";
    }

if ($doc->iscolor("wdColorBlack")) {
    print "iscolor() worked\n";
    } else {
    print "iscolor() failed\n";
    }
if ($doc->iscolor("wdColorDarkRed")) {
    print "iscolor() worked\n";
    } else {
    print "iscolor() failed\n";
    }
if ($doc->iscolor("wdBlue")) {
    print "iscolor() worked\n";
    } else {
    print "iscolor() failed\n";
    }
if ($doc->iscolor("baloney")) {
    print "iscolor() worked\n";
    } else {
    print "iscolor() failed\n";
    }


my $oldauthor = $doc->author();
print "Old author name: $oldauthor \n";
my $newauthor = "iRobot Pty Ltd";
$doc->author($newauthor);
print "New author name: ".$doc->author()."\n";

$doc->save();

# Success.

print "procesing complete \n";
exit(0);

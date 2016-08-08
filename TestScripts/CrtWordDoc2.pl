#!perl -w
#
# Name:
#   ole-word-demo-1.pl
#
# Purpose:
#   Demonstrate how to create an MS Word document from Perl.
#
# Note:
#   Works with Word 97 & Word 2000.
#
# Author:
#   Ron Savage <ron@savage.net.au>
#   and Brent Saunders offered a clever suggestion
#
# Home:
#   http://savage.net.au/Perl-tutorials.html#tut-7
#
# Version
#   1.00    1-Nov-1999
#
# Licence:
#   Copyright (c) 1999 Ron Savage.
#   All Programs in this package are free software; you can redistribute
#   them and/or modify them under the same terms as Perl itself.
#   Perl's Artistic License is available at:
#   See licence.txt.

use strict;

use Win32::OLE;
use Win32::OLE::Const;

# --------------------------------------------------------------------

my(@line) = (
   'Line 1',
   'Line 2',
);

my $wd = Win32::OLE::Const->Load("Microsoft Word 9.0 Object Library");
my($outputFile) = 'D:\HomePage\Perl-tutorials\tut-07\ole-word-demo-1.doc';
unlink($outputFile);

my($word) = Win32::OLE -> new('Word.Application', 'Quit');

$word -> {Visible} = 1;  # Watch what happens
my($doc) = $word -> Documents -> Add(); # Create a new document
my($range) = $doc -> {Content};

$range -> {Text} = $line[0];
my($i);
for ($i=1; $i <= $#line; $i++) {
   $range -> InsertParagraphAfter();
   $range -> InsertAfter($line[$i]);
}

my($paragraphCount) = $doc -> Paragraphs -> Count();
print "paragraphCount=$paragraphCount\n";
print "Paragraphs:\n";
for ($i=1; $i <= $paragraphCount; $i++) {
   print "$i: ", $doc -> Paragraphs($i) -> Range -> {Text}, "\n";
}

$doc -> SaveAs($outputFile);
$doc -> Close();
$word -> Quit();

# Success.
print "Success \n";
exit(0);

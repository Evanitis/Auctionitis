#!/usr/local/bin/perl -w
#
# FILE:     ole.pl.
# PURPOSE:  Read an MS Word doc and extract each paragraph. 
#

use strict;
use Win32::OLE qw(in with);

my ($file) = 'ftp.doc';
$file = Win32::GetCwd() . "/$file" if $file !~ /^(\w:)?[\/\\]/;
die "File $file does not exist" unless -f $file;

my ($word) = Win32::OLE->new('Word.Application', 'Quit') || 
              die "Couldn't run Word";
my ($doc)  = $word->Documents->Open($file);

my($index) = 0;

for my $paragraph (in $doc->Paragraphs)
{
    $index++;
    # Remove trailing ^M (the paragraph marker) from Range.
    my($text) = substr($paragraph->Range->Text, 0, -1);
    print "Paragraph: $index. Text: <$text>\n\n";
}

$doc->{Saved} = 1;
$doc->Close;


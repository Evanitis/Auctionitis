#! perl -w
#
# Open word document and output styles and paragraph data to text file
# Data is saved from the word document (first parameter) into the second
# file named as the second parameter
#
use strict;
use Win32::OLE;
use Win32::OLE::Enum;
use Getopt::Std;

# Variable declarations
#-----------------------
my ($infile, $outfile, $document, $paragraphs, $paragraph, $enumerate, $style, $text);
my (%parm, $ABEND);

# Abend here document

$ABEND = <<EOD;
Parameter missing or incorrect;
The format for the command is:

ReadWordDoc2 -i <Input word doc name> -o <output text file name>

All parameters are required for processing
EOD
# End of abend here document

# perform parameter checking; required parameters are:
# -i Input file -o output file

getopt("io", \%parm);

if  ($parm{i}) {
    $infile = $parm{i};
} else {
    die $ABEND;
}
if  ($parm{o}) {
    $outfile = $parm{o};
} else {
    die $ABEND;
}

$document = Win32::OLE->GetObject($infile);
open (FH,">$outfile");

print "Extracting Text....\n";

$paragraphs = $document->Paragraphs();
$enumerate = new Win32::OLE::Enum($paragraphs);

while(defined($paragraph = $enumerate->Next())) {
    $style = $paragraph->{style}->{NameLocal};
    print FH "+$style\n";
    $text = $paragraph->{Range}->{Text};
    $text =~ s/[\n\r]//g;
    $text =~ s/\x0b/\n/g;
    print FH "=$text\n";
    }
    
print "Done...\n";

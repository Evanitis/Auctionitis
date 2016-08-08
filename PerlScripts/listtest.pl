#!perl -w

use strict;
use WordLite;

my $doc = WordLite->new();
print "Filename being processed is: ", $doc->filename() || "none", "\n";
$doc->filename("C:\\evan\\source\\testdata\\crtworddoc7.doc");
print "Filename being processed is: ", $doc->filename() , "\n";
#set the document visibility: 0 for off, 1 for on (debugging aid)
$doc->visible(0);

my $visibility = $doc->visible();

print "Visibility factor: $visibility\n";
print "Filename being processed is: ", $doc->filename(), "\n";

# test list styles functions

my @array = $doc->list_styles();

    foreach my $style (@array) {
        print "Style: $style\n";
    }

# test list fonts functions 

@array = $doc->list_fonts();

    foreach my $font (@array) {
        print "Font: $font \n";
    }

# test list colors functions 

@array = $doc->list_colors();
    foreach my $color (@array) {
        print "Color: $color \n";
    }

# test list functions declared as closures

@array = $doc->list_color();
    print "Processing list color closure\n";
    foreach my $color (@array) {
        print "Color: $color \n";
    }

@array = $doc->list_underline();
    print "Processing underline color closure\n";
    foreach my $underline (@array) {
        print "Underline: $underline \n";
    }

@array = $doc->list_fieldType();
    print "Processing field type closure\n";
    foreach my $ftype (@array) {
        print "Field Type: $ftype \n";
    }

# Visible method/property test

$doc->visible(1);
$visibility = $doc->visible();
print "Visibility factor: $visibility\n";

# Success.

print "Processing complete \n";
exit(0);

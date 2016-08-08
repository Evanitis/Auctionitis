#-----------------------------------------------------------------------
# Extract_Form_Data.pl
#
# To run: perl Extract_Form_Data.pl "input_file.txt" > "output_file.txt"
#
# NOTE THE QUOTES AROUND THE FILE NAMES TO HANDLE EMBEDDED BLANKS !
#
# Script to strip out formfields and input fields from HTML page
#-----------------------------------------------------------------------
#!perl -w

use strict;

my $input = shift;

print "Input from file $input\n\n";

local $/;                                                      #slurp mode (undef)
local *F;                                                      #create local filehandle

open(F, "< $input\0") || return;

my $text = <F>;                                                #read whole file

close(F);                                                      # ignore retval

while ( $text =~ m/(<Form|<Input|<Textarea|<Select|<Option)(.+?)(>)/sig ) {

    print $1.$2.$3."\n";
}

# Done!
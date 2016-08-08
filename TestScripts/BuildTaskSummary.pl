#!perl -w
#---------------------------------------------------------------------------------------------
# Copyright 2002, Evan Harris.  All rights reserved.
# 
# What the program will do:
# BuildAuctionitis
#---------------------------------------------------------------------------------------------

use strict;



my $in       =   "TMLoader.pm";                          
my $out      =   "FunctionSum.txt";                          

open(IN,    "< $in")    || return;                                  
open(OUT,   "> $out")   || return;                                    

while (<IN>) {                                                  

    if ( m/(sub)(\s+?)(.+?)(\s+)(\{)/ ) {
        print OUT "Method: $3\n";
    }    

    if ( m/(AddTask\(")(.+?)("\))/ ) {
        print OUT "  Task: $2\n";
    }    

}

close(IN);                                                     
close(OUT);  
print "Done\n";

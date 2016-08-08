#!perl -w
#--------------------------------------------------------------------
# DumpObjectAttributes
# Copyright 2002, Evan Harris.  All rights reserved.
# This program will dump all the attributes of an object
# Built as a debugging tool but probably useful of itself
# This version presume the returned object is a hash
# Change the program to USE the require package
# Create new object as required by the package [TradeMe uses login()]
# Print the object to see what kind of object it is
# Dereference it and loop through the hash....
#--------------------------------------------------------------------

use strict;
use TradeMe;


my $tm = TradeMe->new();

print "Returned Object: $tm\n\n";    # this will show the type of reference

my %trademe = %$tm;                  # dereference back to hash here

my ($key, $value); 
# report formatting stuff...

format STDOUT_TOP =
Attribute            Value
-------------------- -----------------------------------------
.

format STDOUT =
@<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$key,                $value
.


$^ = "STDOUT_TOP";

# print the hash key/value pairs using formatted output

    while (($key, $value) = each(%trademe)) {
        # print "$key\t $value\n";
        write;
}

# Success.

print "\nDone\n";
exit(0);

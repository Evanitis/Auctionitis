#!perl -w
#--------------------------------------------------------------------

#--------------------------------------------------------------------
use strict;

open my $log,  "> c:\\evan\\source\\testdata\\winkywankywoo.log." or die "Cannot open winkywankywoo.log: $!";

# Write the email from Eudora into the log file

while (<>) {
    print $log "$_\n";
}

# Success.
print "Success \n";

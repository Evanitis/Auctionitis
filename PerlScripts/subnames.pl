#!perl -w
# This script extracts the sub names from a perl module and formats them into a string
# made up of all the names separated by a space.
# Used to extract all names for Autoload validity checking purposes
# WARNING: Take care as it does very little error checking; Verify that it got
# all the names you want !!!! You have been warned !

open (my $fh, "< c:\\evan\\source\\perl\\wordlite.pm");
my($substring)="";
while (<$fh>) {
    if ($_ =~ /^sub *([a-z\_]+)/i) {
        print "$1\n";
        $substring = $substring." ".$1;
    }
}
print "$substring\n";

# Success.
print "Success \n";
exit(0);

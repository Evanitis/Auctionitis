#!perl -w
#--------------------------------------------------------------------
# test_get_DVD_search_list.pl 
# perl script to test the Auctionitis get_movie_search_list method
#
# to run the script: perl.exe test_get_DVD_search_list.pl fair  or
# perl.exe test_get_DVD_search_list.pl fair > test_get_DVD_Search_List.log
# To obtaing a log of the output
#
# run the test from C:\evan\Auctionitis103
#
# Other program notes:
#--------------------------------------------------------------------

use strict;
use Auctionitis;

my $searchstring;

foreach my $i (@ARGV) {

    print "$i\n";

    if ( $searchstring eq "") {
    
        $searchstring = $i;
    }
    else {
        
        $searchstring = $searchstring." ".$i;
    }
}

print "Entered searchstring was: $searchstring\n";

# Success.

print "Done\n";
exit(0);

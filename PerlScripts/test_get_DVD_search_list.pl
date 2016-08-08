#!perl -w
#--------------------------------------------------------------------
# test_get_DVD_search_list.pl 
# perl script to test the Auctionitis get_movie_search_list method
#
# to run the script: perl.exe test_get_DVD_search_list.pl  or
# perl.exe test_get_DVD_search_list.pl > test_get_DVD_Search_List.log
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

my $tm = Auctionitis->new();

$tm->initialise(Product => "Auctionitis");  # Initialise the product
$tm->DBconnect();                           # Connect to the database
$tm->login();

my $HTMLPage = $tm->get_movie_search_list($searchstring);

if (not $tm->{ErrorStatus}) {

    print $HTMLPage."\n";;
}
else {
    print "Message : ".$tm->{ ErrorStatus   }."\n";
    print "Message : ".$tm->{ ErrorMessage  }."\n";
    print "Message : ".$tm->{ ErrorDetail   }."\n";
}
# Success.

exit(0);

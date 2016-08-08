#!perl -w
#--------------------------------------------------------------------
# gettmdata.pl retrieve data from trademe for analysis and automation
# to run the script: perl.exe c:\evan\trademe\gettmdata.pl 
#
# Other program notes:
#--------------------------------------------------------------------

use strict;
use Auctionitis;


my $tm = Auctionitis->new();
$tm->initialise( Product => "Auctionitis" );  # Initialise the product
$tm->{ ErrorMessage } ? ( print "ERROR: ".$tm->{ ErrorMessage }."\n" ) : ();
$tm->DBconnect();                          # Connect to the database
$tm->{ ErrorMessage } ? ( print "ERROR: ".$tm->{ ErrorMessage }."\n" ) : ();

$tm->login();
$tm->{ ErrorMessage } ? ( print "ERROR: ".$tm->{ ErrorMessage }."\n" ) : ();

print $tm->{ UserName }."\n";

my $sold = $tm->new_get_sold_listings();
print "Sold last 7 days: ".scalar( @$sold )."\n";

foreach my $auction ( @$sold ) {
    #print $auction."\n";
    print "Auction: ".$auction->{ AuctionRef }."; Sold by ".$auction->{ Sale_Type }." for ".$auction->{ Sale_Price }."\n";
    print "Start  : ".$auction->{ Start_Date }."; Sold ".$auction->{ Sold_Date }."\n";
}


# Success.

print "Done\n";
exit(0);

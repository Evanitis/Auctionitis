#!perl -w
#--------------------------------------------------------------------
# gettmdata.pl retrieve data from trademe for analysis and automation
# to run the script: perl.exe c:\evan\trademe\gettmdata.pl 
#
# Other program notes:
#--------------------------------------------------------------------

use strict;
use Auctionitis;
use HTML::TokeParser;

my $tm = Auctionitis->new();
$tm->initialise( Product => "Auctionitis" );    # Initialise the product
$tm->DBconnect( "TestAuctionitis" );            # Connect to the test database

my $auctions;

$tm->login(
    TradeMeID   =>  'Topmaq1'                       ,
    UserID      =>  'tmsales@discoverconcord.com'   ,
    Password    =>  'trainersgay'                   ,
);

my $start = time();

$auctions = $tm->get_current_auctions();

my $end = time();
my $elapsed = $end - $start;

print "Started: $start\n";
print "Ended: $end\n";
print "Elapsed: $elapsed\n";

print scalar( @$auctions )." Current Auctions\n";
print "-----------------------------------------\n";

my $counter = 0;

foreach my $a ( @$auctions ) {

    print $a->{ AuctionRef }." Loaded: ".$a->{ Start_Date }." at: ".$a->{ Start_Time }."\n";
    print "            Ends: ".$a->{ End_Date }." at: ".$a->{ End_Time }."\n";
    print "            Fees: ".$a->{ Listing_Fee }." Promo: ".$a->{ Promotion_Fee }."\n";

    $ counter++;

    exit if $counter > 10;

}

# Success.

print "Done\n";
exit(0);

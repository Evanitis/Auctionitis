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
$tm->initialise(Product => "Auctionitis");  # Initialise the product
$tm->DBconnect();                          # Connect to the database

my $offers;

if ( ( $tm->{ OfferSold } eq "1" ) and ( $tm->{ OfferUnsold } eq "1" ) ) {

    print "Retrieving Pending offers for ALL auctions\n";

    $offers = $tm->get_pending_offers( "ALL" );
}

elsif ( ( $tm->{ OfferSold } eq "1" ) and ( $tm->{ OfferUnsold } eq "0" ) ) {

    print "Retrieving Pending offers for SOLD auctions\n";

    $offers = $tm->get_pending_offers( "SOLD" );
}

elsif ( ( $tm->{ OfferSold } eq "0" ) and ( $tm->{ OfferUnsold } eq "1" ) ) {

    print "Retrieving Pending offers for UNSOLD auctions\n";

    $offers = $tm->get_pending_offers( "UNSOLD" );
}

foreach my $auction ( @$offers ) {
    #print $auction."\n";
    print "Auction: ".$auction->{ AuctionRef }."; Status: ".$auction->{ AuctionStatus }."; Offer Price: ".$auction->{ OfferPrice }."\n";
}

# Success.

print "Done\n";
exit(0);

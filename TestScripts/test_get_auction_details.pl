#!perl -w
#--------------------------------------------------------------------
# gettmdata.pl retrieve data from trademe for analysis and automation
# to run the script: perl.exe c:\evan\trademe\gettmdata.pl 
#
# Other program notes:
#--------------------------------------------------------------------

use strict;
use Auctionitis;

my $auction = shift;

my $tm = Auctionitis->new();

$tm->initialise(Product => "Auctionitis");

$tm->login();

my %auction = $tm->get_auction_details($auction);

if     ($auction{Status} eq "Current") {

        print "Sts msg: $tm->{StatusMessage}\n";
        print "Status : $auction{Status}\n";
        print "Cl Time: $auction{CloseTime}\n";
        print "Cl Date: $auction{CloseDate}\n";
        print "Rsv met: $auction{ReserveMet}\n";
        print "Current: $auction{CurrentBid}\n";
        print "Buy now: $auction{BuyNowprice}\n";
        print "Start  : $auction{StartingPrice}\n";
        print "Reserve: $auction{ReservePrice}\n";
        print "Br New : $auction{BrandNew}\n";
        print "A-Extnd: $auction{AutoExtend}\n";
        print "PhotoID: $auction{PhotoID}\n";
        #print "Desc   : \n$auction{Description}\n";
        print "Bids   : $auction{Bids}\n";
        print "High ID: $auction{HighBidderID}\n";
        print "H Name : $auction{HighBidder}\n";
        print "Rating : $auction{HighBidderRating}\n";              
        print "Cat    : $auction{Category}\n";              
} else {

        print "Sts msg: $tm->{StatusMessage}\n";
        print "Status : $auction{Status}\n";
        print "Cl Time: $auction{CloseTime}\n";
        print "Cl Date: $auction{CloseDate}\n";
        print "Rsv met: $auction{ReserveMet}\n";
        print "Relist : $auction{Relisted}\n";
        print "Current: $auction{CurrentBid}\n";
        print "Br New : $auction{BrandNew}\n";
        print "PhotoID: $auction{PhotoID}\n";
        #print "Desc   : \n$auction{Description}\n";
        print "Bids   : $auction{Bids}\n";
        print "High ID: $auction{HighBidderID}\n";
        print "H Name : $auction{HighBidder}\n";
        print "Rating : $auction{HighBidderRating}\n";              
        print "Cat    : $auction{Category}\n";              
}


# Success.

print "Done\n";
exit(0);

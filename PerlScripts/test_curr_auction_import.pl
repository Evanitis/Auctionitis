#!perl -w
#--------------------------------------------------------------------
# gettmdata.pl retrieve data from trademe for analysis and automation
# to run the script: perl.exe c:\evan\trademe\gettmdata.pl 
#
# Other program notes:
#--------------------------------------------------------------------

use strict;
use Auctionitis;

my @current;
my @complete;
my $counter = 1;

my $tm = Auctionitis->new();

$tm->login();

@current = $tm->get_curr_listings();
print "$#current Current listings:\n";

foreach my $auction (@current) {
        my %auctiondata = $tm->get_auction_details($auction);
        if     (not $tm->is_DBauction($auction)) {
                print "Adding $auction: $counter of $#current current auctions\n";
                $tm->insert_DBauction(AuctionRef        =>  $auction,
                                      Title             =>  $auctiondata{Title},
                                      Description       =>  $auctiondata{Description},
                                      CategoryID        =>  $auctiondata{Category},
                                      Status            =>  $auctiondata{Status},
                                      CloseTime         =>  $auctiondata{CloseTime},
                                      CloseDate         =>  $auctiondata{CloseDate},
                                      ReserveMet        =>  $auctiondata{ReserveMet},
                                      BidAmount         =>  $auctiondata{CurrentBid},
                                      BuyNowPrice       =>  $auctiondata{BuyNowprice},
                                      StartPrice        =>  $auctiondata{StartingPrice},
                                      ReservePrice      =>  $auctiondata{ReservePrice},
                                      IsNew             =>  $auctiondata{BrandNew},
                                      Questions         =>  $auctiondata{Questions},
                                      AutoExtend        =>  $auctiondata{AutoExtend},
                                      SafeTrader        =>  $auctiondata{SafeTrader},
                                      BidCount          =>  $auctiondata{Bids},
                                      HighBidderID      =>  $auctiondata{HighBidderID},
                                      HighBidder        =>  $auctiondata{HighBidder},
                                      HighBidderRating  =>  $auctiondata{HighBidderRating});
        } else {
                print "Updating $auction: $counter of $#current current auctions\n";
                $tm->update_DBauction(AuctionRef        =>  $auction,
                                      Status            =>  $auctiondata{Status},
                                      CloseTime         =>  $auctiondata{CloseTime},
                                      CloseDate         =>  $auctiondata{CloseDate},
                                      ReserveMet        =>  $auctiondata{ReserveMet},
                                      Questions         =>  $auctiondata{Questions},
                                      BidAmount         =>  $auctiondata{CurrentBid},
                                      BidCount          =>  $auctiondata{Bids},
                                      HighBidderID      =>  $auctiondata{HighBidderID},
                                      HighBidder        =>  $auctiondata{HighBidder},
                                      HighBidderRating  =>  $auctiondata{HighBidderRating});
        }
        $counter++
        
}

@complete = $tm->get_comp_listings();

foreach my $auction (@complete) {
        my %auctiondata = $tm->get_auction_details($auction);
        if     (not $tm->is_DBauction($auction)) {
                print "Adding $auction: $counter of $#complete complete auctions\n";
                $tm->insert_DBauction(AuctionRef        =>  $auction,
                                      Title             =>  $auctiondata{Title},
                                      Description       =>  $auctiondata{Description},
                                      CategoryID        =>  $auctiondata{Category},
                                      Status            =>  $auctiondata{Status},
                                      CloseTime         =>  $auctiondata{CloseTime},
                                      CloseDate         =>  $auctiondata{CloseDate},
                                      ReserveMet        =>  $auctiondata{ReserveMet},
                                      BidAmount         =>  $auctiondata{CurrentBid},
                                      BuyNowPrice       =>  $auctiondata{BuyNowprice},
                                      StartPrice        =>  $auctiondata{StartingPrice},
                                      ReservePrice      =>  $auctiondata{ReservePrice},
                                      IsNew             =>  $auctiondata{BrandNew},
                                      Questions         =>  $auctiondata{Questions},
                                      AutoExtend        =>  $auctiondata{AutoExtend},
                                      SafeTrader        =>  $auctiondata{SafeTrader},
                                      BidCount          =>  $auctiondata{Bids},
                                      HighBidderID      =>  $auctiondata{HighBidderID},
                                      HighBidder        =>  $auctiondata{HighBidder},
                                      HighBidderRating  =>  $auctiondata{HighBidderRating});
        } else {
                print "Updating $auction: $counter of $#complete complete auctions\n";
                $tm->update_DBauction(AuctionRef        =>  $auction,
                                      Status            =>  $auctiondata{Status},
                                      CloseTime         =>  $auctiondata{CloseTime},
                                      CloseDate         =>  $auctiondata{CloseDate},
                                      ReserveMet        =>  $auctiondata{ReserveMet},
                                      Questions         =>  $auctiondata{Questions},
                                      BidAmount         =>  $auctiondata{CurrentBid},
                                      BidCount          =>  $auctiondata{Bids},
                                      HighBidderID      =>  $auctiondata{HighBidderID},
                                      HighBidder        =>  $auctiondata{HighBidder},
                                      HighBidderRating  =>  $auctiondata{HighBidderRating});
        }
        $counter++
        
}

# print "$tm->{StatusMessage}\n";

# Success.

print "Done\n";
exit(0);

#!perl -w

use strict;
use Auctionitis;

my $tm = Auctionitis->new();

$tm->initialise( Product => "Auctionitis" );  # Initialise the product
$tm->DBconnect();
$tm->login();

my $ar =  "170082315";
my $oa =  49.99;
my $od =  3;

my $offer = $tm->make_offer(
    AuctionRef          =>  $ar             ,
    OfferAmount         =>  $oa             ,
    OfferDuration       =>  $od             ,
    UseHighestBid       =>  1               ,
    AVOnly              =>  0               ,
    WatchersOnly        =>  0               ,
    BiddersOnly         =>  0               ,
    AuthenticatedOnly   =>  0               ,
    FeedbackMinimum     =>  0               ,
);

$tm->add_offer_record(
    Offer_Date          => $tm->datenow()           ,
    Auction_Ref         => $ar                      ,
    Offer_Amount        => $oa                      ,
    Offer_Duration      => $od                      ,
    Highest_Bid         => $offer->{ HighBid      } ,
    Offer_Reserve       => $offer->{ Reserve      } ,
    Actual_Offer        => $offer->{ OfferPrice   } ,
    Bidder_Count        => $offer->{ BidderCount  } ,
    Watcher_Count       => $offer->{ WatcherCount } ,
    Offer_Count         => $offer->{ OfferCount   } ,
    Offer_Successful    => 0                        ,
    Offer_Type          => "SOLD"                   ,
);

# Success

print "Done\n";
exit(0);

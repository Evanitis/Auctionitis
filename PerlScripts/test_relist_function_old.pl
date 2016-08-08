#!perl -w
#--------------------------------------------------------------------
# function to test the auction relist process
# Other program notes:
#--------------------------------------------------------------------

use strict;
use Auctionitis;

my $auction = 29774636

my $tm = Auctionitis->new();

$tm->initialise(Product => "Auctionitis");  # Initialise the product

$tm->DBconnect();                           # Connect to the database

my $auctionrcd = $tm->get_auction_record($tm->get_auction_key($auction));


if (not $tm->{ErrorStatus}) {

    print "Title  : $auctionrcd->{Title}\n";
    print "Desc   : \n$auctionrcd->{Description}\n";
    print "Cat    : $auctionrcd->{Category}\n";
    print "Status : $auctionrcd->{AuctionStatus}\n";
    print "is New : $auctionrcd->{IsNew}\n";
    print "Start  : $auctionrcd->{StartPrice}\n";
    print "Reserve: $auctionrcd->{ReservePrice}\n";
    print "Buy now: $auctionrcd->{BuyNowPrice}\n";
    print "A-Extnd: $auctionrcd->{AutoExtend}\n";
    print "Closed : $auctionrcd->{ClosedAuction}\n";
    print "Hours  : $auctionrcd->{DurationHours}\n";
    print "S Trade: $auctionrcd->{SafeTrader}\n";
    print "Free NZ: $auctionrcd->{FreeShippingNZ}\n"; 
    print "ShipInf: $auctionrcd->{ShippingInfo}\n";

    $tm->login();
    
    print "User ID:  $tm->{UserID}\n";
    print "Password: $tm->{Password}\n";
    
    if (not $tm->{ErrorStatus}) {

        my $Newauction = $tm->relist_auction(   AuctionRef      =>   $auction->{ AuctionRef     },
                                                Category        =>   $auction->{ Category       },
                                                Title           =>   $auction->{ Title          },
                                                Description     =>   $auction->{ Description    },
                                                IsNew           =>   $auction->{ IsNew          },
                                                DurationHours   =>   $auction->{ DurationHours  },
                                                StartPrice      =>   $auction->{ StartPrice     },
                                                ReservePrice    =>   $auction->{ ReservePrice   },
                                                BuyNowPrice     =>   $auction->{ BuyNowPrice    },
                                                ClosedAuction   =>   $auction->{ ClosedAuction  },
                                                AutoExtend      =>   $auction->{ AutoExtend     },
                                                Cash            =>   $auction->{ Cash           },
                                                Cheque          =>   $auction->{ Cheque         },
                                                BankDeposit     =>   $auction->{ BankDeposit    },
                                                PaymentInfo     =>   $auction->{ PaymentInfo    },
                                                FreeShippingNZ  =>   $auction->{ FreeShippingNZ },
                                                ShippingInfo    =>   $auction->{ ShippingInfo   },
                                                SafeTrader      =>   $auction->{ SafeTrader     },
                                                Featured        =>   $auction->{ Featured       },
                                                Gallery         =>   $auction->{ Gallery        },
                                                BoldTitle       =>   $auction->{ BoldTitle      },
                                                FeaturedCombo   =>   $auction->{ Featured       },
                                                HomePage        =>   $auction->{ HomePage       },
                                                Permanent       =>   $auction->{ Permanent      },
                                                MovieRating     =>   $auction->{ MovieRating    },
                                                MovieConfirm    =>   $auction->{ MovieConfirm   },
                                                TMATT104        =>   $auction->{ TMATT104       },
                                                TMATT104_2      =>   $auction->{ TMATT104_2     },
                                                TMATT106        =>   $auction->{ TMATT106       },
                                                TMATT106_2      =>   $auction->{ TMATT106_2     },
                                                TMATT108        =>   $auction->{ TMATT108       },
                                                TMATT108_2      =>   $auction->{ TMATT108_2     },
                                                TMATT111        =>   $auction->{ TMATT111       },
                                                TMATT112        =>   $auction->{ TMATT112       },
                                                TMATT115        =>   $auction->{ TMATT115       },
                                                TMATT117        =>   $auction->{ TMATT117       },
                                                TMATT118        =>   $auction->{ TMATT118       });
                                                      
    
            print "Auction relisted as $NewAuction\n";

    } else {print "Error Message: $tm->{ErrorStatus}"; }            


} else { print "Error Status: $tm->{ErrorStatus}\n"; }




# Success.

print "Done\n";
exit(0);

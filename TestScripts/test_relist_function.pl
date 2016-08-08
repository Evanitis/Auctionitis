#!perl -w
#--------------------------------------------------------------------
# function to test the auction relist process
# Other program notes:
#--------------------------------------------------------------------

use strict;
use Auctionitis;

my $ref = 66233926;

my $tm = Auctionitis->new();

$tm->initialise(Product => "Auctionitis");  # Initialise the product

$tm->DBconnect();                           # Connect to the database
$tm->login();

my $auction = $tm->get_auction_record( $tm->get_auction_key( $ref ) );

my $dopt = $tm->get_shipping_details( AuctionKey => $auction->{ AuctionKey } );

print "Title   : ".$auction->{ Title }."\n";
print "Subtitle: ".$auction->{ Subitle }."\n";

foreach my $key (keys %$auction) {
    print "$key \t: $auction->{ $key } \n";
}

foreach my $d ( @$dopt ) {
    print "Cost $d->{ Shipping_Details_Cost }\n";
    print "Text $d->{ Shipping_Details_Text }\n";
}

if ( not $tm->{ ErrorStatus } ) {

    my $newauction = $tm->relist_auction(
        AuctionRef                      =>  $auction->{ AuctionRef     },
        Category                        =>  $auction->{ Category       },
        Title                           =>  $auction->{ Title          },
        Subtitle                        =>  $auction->{ Subtitle       },
        Description                     =>  $auction->{ Description    },
        IsNew                           =>  $auction->{ IsNew          },
        TMBuyerEmail                    =>  $auction->{ TMBuyerEmail   },
        !($auction->{ ShippingOption }) ?   (   FreeShippingNZ  =>  $auction->{ FreeShippingNZ          }   )   :   ()  ,
        !($auction->{ ShippingOption }) ?   (   ShippingInfo    =>  $auction->{ ShippingInfo            }   )   :   ()  ,           
        $auction->{ PickupOption    }   ?   (   PickupOption    =>  $auction->{ PickupOption            }   )   :   ()  ,
        $auction->{ ShippingOption  }   ?   (   ShippingOption  =>  $auction->{ ShippingOption          }   )   :   ()  ,
        $dopt->[0]                      ?   (   DCost1          =>  $dopt->[0]->{ Shipping_Details_Cost }   )   :   ()  ,
        $dopt->[0]                      ?   (   DText1          =>  $dopt->[0]->{ Shipping_Details_Text }   )   :   ()  ,
        $dopt->[1]                      ?   (   DCost2          =>  $dopt->[1]->{ Shipping_Details_Cost }   )   :   ()  ,
        $dopt->[1]                      ?   (   DText2          =>  $dopt->[1]->{ Shipping_Details_Text }   )   :   ()  ,
        $dopt->[2]                      ?   (   DCost3          =>  $dopt->[2]->{ Shipping_Details_Cost }   )   :   ()  ,  
        $dopt->[2]                      ?   (   DText3          =>  $dopt->[2]->{ Shipping_Details_Text }   )   :   ()  ,
        $dopt->[3]                      ?   (   DCost4          =>  $dopt->[3]->{ Shipping_Details_Cost }   )   :   ()  ,
        $dopt->[3]                      ?   (   DText4          =>  $dopt->[3]->{ Shipping_Details_Text }   )   :   ()  ,
        $dopt->[4]                      ?   (   DCost5          =>  $dopt->[4]->{ Shipping_Details_Cost }   )   :   ()  ,
        $dopt->[4]                      ?   (   DText5          =>  $dopt->[4]->{ Shipping_Details_Text }   )   :   ()  ,
        $dopt->[5]                      ?   (   DCost6          =>  $dopt->[5]->{ Shipping_Details_Cost }   )   :   ()  ,
        $dopt->[5]                      ?   (   DText6          =>  $dopt->[5]->{ Shipping_Details_Text }   )   :   ()  ,
        $dopt->[6]                      ?   (   DCost7          =>  $dopt->[6]->{ Shipping_Details_Cost }   )   :   ()  ,
        $dopt->[6]                      ?   (   DText7          =>  $dopt->[6]->{ Shipping_Details_Text }   )   :   ()  ,
        $dopt->[7]                      ?   (   DCost8          =>  $dopt->[7]->{ Shipping_Details_Cost }   )   :   ()  ,
        $dopt->[7]                      ?   (   DText8          =>  $dopt->[7]->{ Shipping_Details_Text }   )   :   ()  ,
        $dopt->[8]                      ?   (   DCost9          =>  $dopt->[8]->{ Shipping_Details_Cost }   )   :   ()  ,
        $dopt->[8]                      ?   (   DText9          =>  $dopt->[8]->{ Shipping_Details_Text }   )   :   ()  ,
        $dopt->[9]                      ?   (   DCost10         =>  $dopt->[9]->{ Shipping_Details_Cost }   )   :   ()  ,
        $dopt->[9]                      ?   (   DText10         =>  $dopt->[9]->{ Shipping_Details_Text }   )   :   ()  ,
        DurationHours   =>   $auction->{ DurationHours  },
        StartPrice      =>   $auction->{ StartPrice     },
        ReservePrice    =>   $auction->{ ReservePrice   },
        BuyNowPrice     =>   $auction->{ BuyNowPrice    },
        ClosedAuction   =>   $auction->{ ClosedAuction  },
        AutoExtend      =>   $auction->{ AutoExtend     },
        BankDeposit     =>   $auction->{ BankDeposit    },
        CreditCard      =>   $auction->{ CreditCard     },
        SafeTrader      =>   $auction->{ SafeTrader     },
        PaymentInfo     =>   $auction->{ PaymentInfo    },
        FreeShippingNZ  =>   $auction->{ FreeShippingNZ },
        ShippingInfo    =>   $auction->{ ShippingInfo   },
        Featured        =>   $auction->{ Featured       },
        Gallery         =>   $auction->{ Gallery        },
        BoldTitle       =>   $auction->{ BoldTitle      },
        Featured        =>   $auction->{ Featured       },
        FeatureCombo    =>   $auction->{ FeatureCombo   },
        HomePage        =>   $auction->{ HomePage       },
        MovieRating     =>   $auction->{ MovieRating    },
        MovieConfirm    =>   $auction->{ MovieConfirm   },
        AttributeName   =>   $auction->{ AttributeName  },
        AttributeValue  =>   $auction->{ AttributeValue },
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
        TMATT118        =>   $auction->{ TMATT118       },
    );

    print "Auction relisted as $newauction\n";
}


# Success.

print "Done\n";
exit(0);

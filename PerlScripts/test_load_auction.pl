#!perl -w
#--------------------------------------------------------------------
# Use this program to test loading an auction from the database
# enter a record number (Auction key) as the input parameter
#--------------------------------------------------------------------

use strict;
use Auctionitis;

my $tm = Auctionitis->new();
   
$tm->initialise(Product => "Auctionitis");  # Initialise the product
$tm->DBconnect();                           # Initialise the product
$tm->login();

my $keys        =   shift;
my $counter     =   1;
my $dopt;

my $auctions = $tm->get_auction_records($keys);
print "Auctions: $auctions\n";

foreach my $auction (@$auctions) {

    print "Auction: $auction\n";

    if ( $auction->{ AuctionStatus } eq 'PENDING' ) {

        my ($PhotoID1, $PhotoID2, $PhotoID3);

        if ( $auction->{ PictureKey1 } ) {
            my $photo = $tm->get_picture_record($auction->{PictureKey1});
            $PhotoID1 = $photo->{PhotoId};
        }

        else { 
            $PhotoID1 = 0;
        }

        if ( $auction->{ PictureKey2 } ) {
            my $photo = $tm->get_picture_record($auction->{PictureKey2});
            $PhotoID2 = $photo->{PhotoId};
        }

        else { 
            $PhotoID2 = 0;
        }

        if ( $auction->{ PictureKey3 } ) {
            my $photo = $tm->get_picture_record($auction->{PictureKey3});
            $PhotoID3 = $photo->{PhotoId};
        }

        else { 
            $PhotoID3 = 0;
        }

        # if a shipping option is specified retrieve the delivery options

        if ( $auction->{ ShippingOption } ) {
            "Print retrieving shipping details\n";
            $dopt = $tm->get_shipping_details( AuctionKey => $auction->{ AuctionKey } );
            print "$dopt\n";
        }

        my $copies_loaded = 0;

        while ( $copies_loaded < $auction->{ CopyCount } ) {

            # Check whether the Free Listing Limit has been exceeded if abort property is true

            foreach my $k (sort keys %$auction) {
                if ( $k ne 'Description' ) {
                    print "$k \t: $auction->{ $k }\n";
                }
            }

            my $newauction = $tm->load_new_auction(
                CategoryID                      =>  $auction->{ Category        }   ,
                Title                           =>  $auction->{ Title           }   ,
                Subtitle                        =>  $auction->{ Subtitle        }   ,
                Description                     =>  $auction->{ Description     }   ,
                IsNew                           =>  $auction->{ IsNew           }   ,
                TMBuyerEmail                    =>  $auction->{ TMBuyerEmail    }   ,
                EndType                         =>  $auction->{ EndType         }   ,
                DurationHours                   =>  $auction->{ DurationHours   }   ,
                EndDays                         =>  $auction->{ EndDays         }   ,
                EndTime                         =>  $auction->{ EndTime         }   ,
                !($auction->{ ShippingOption }) ?   (   FreeShippingNZ  =>  $auction->{ FreeShippingNZ          }   )   :   ()  ,
                !($auction->{ ShippingOption }) ?   (   ShippingInfo    =>  $auction->{ ShippingInfo            }   )   :   ()  ,
                $auction->{ PickupOption    }   ?   (   PickupOption    =>  $auction->{ PickupOption            }   )   :   ()  ,
                $auction->{ ShippingOption  }   ?   (   ShippingOption  =>  $auction->{ ShippingOption          }   )   :   ()  ,
#                $dopt->[0]                      ?   (   DCost1          =>  $dopt->[0]->{ Shipping_Details_Cost }   )   :   ()  ,
#                $dopt->[0]                      ?   (   DText1          =>  $dopt->[0]->{ Shipping_Details_Text }   )   :   ()  ,
#                $dopt->[1]                      ?   (   DCost2          =>  $dopt->[1]->{ Shipping_Details_Cost }   )   :   ()  ,
#                $dopt->[1]                      ?   (   DText2          =>  $dopt->[1]->{ Shipping_Details_Text }   )   :   ()  ,
#                $dopt->[2]                      ?   (   DCost3          =>  $dopt->[2]->{ Shipping_Details_Cost }   )   :   ()  ,
#                $dopt->[2]                      ?   (   DText3          =>  $dopt->[2]->{ Shipping_Details_Text }   )   :   ()  ,
#                $dopt->[3]                      ?   (   DCost4          =>  $dopt->[3]->{ Shipping_Details_Cost }   )   :   ()  ,
#                $dopt->[3]                      ?   (   DText4          =>  $dopt->[3]->{ Shipping_Details_Text }   )   :   ()  ,
#                $dopt->[4]                      ?   (   DCost5          =>  $dopt->[4]->{ Shipping_Details_Cost }   )   :   ()  ,
#                $dopt->[4]                      ?   (   DText5          =>  $dopt->[4]->{ Shipping_Details_Text }   )   :   ()  ,
#                $dopt->[5]                      ?   (   DCost6          =>  $dopt->[5]->{ Shipping_Details_Cost }   )   :   ()  ,
#                $dopt->[5]                      ?   (   DText6          =>  $dopt->[5]->{ Shipping_Details_Text }   )   :   ()  ,
#                $dopt->[6]                      ?   (   DCost7          =>  $dopt->[6]->{ Shipping_Details_Cost }   )   :   ()  ,
#                $dopt->[6]                      ?   (   DText7          =>  $dopt->[6]->{ Shipping_Details_Text }   )   :   ()  ,
#                $dopt->[7]                      ?   (   DCost8          =>  $dopt->[7]->{ Shipping_Details_Cost }   )   :   ()  ,
#                $dopt->[7]                      ?   (   DText8          =>  $dopt->[7]->{ Shipping_Details_Text }   )   :   ()  ,
#                $dopt->[8]                      ?   (   DCost9          =>  $dopt->[8]->{ Shipping_Details_Cost }   )   :   ()  ,
#                $dopt->[8]                      ?   (   DText9          =>  $dopt->[8]->{ Shipping_Details_Text }   )   :   ()  ,
#                $dopt->[9]                      ?   (   DCost10         =>  $dopt->[9]->{ Shipping_Details_Cost }   )   :   ()  ,
#                $dopt->[9]                      ?   (   DText10         =>  $dopt->[9]->{ Shipping_Details_Text }   )   :   ()  ,
                StartPrice                      =>  $auction->{ StartPrice      }   ,
                ReservePrice                    =>  $auction->{ ReservePrice    }   ,
                BuyNowPrice                     =>  $auction->{ BuyNowPrice     }   ,
                ClosedAuction                   =>  $auction->{ ClosedAuction   }   ,
                AutoExtend                      =>  $auction->{ AutoExtend      }   ,
                BankDeposit                     =>  $auction->{ BankDeposit     }   ,
                CreditCard                      =>  $auction->{ CreditCard      }   ,
                CashOnPickup                    =>  $auction->{ CashOnPickup    }   ,
                Paymate                         =>  $auction->{ Paymate         }   ,
                SafeTrader                      =>  $auction->{ SafeTrader      }   ,
                PaymentInfo                     =>  $auction->{ PaymentInfo     }   ,
                $PhotoID1                       ?   (  PhotoID1        =>  $PhotoID1                               )   :   ()  ,
                $PhotoID2                       ?   (  PhotoID2        =>  $PhotoID2                               )   :   ()  ,
                $PhotoID3                       ?   (  PhotoID3        =>  $PhotoID3                               )   :   ()  ,
                Gallery                         =>  $auction->{ Gallery         }   ,
                BoldTitle                       =>  $auction->{ BoldTitle       }   ,
                Featured                        =>  $auction->{ Featured        }   ,
                FeatureCombo                    =>  $auction->{ FeatureCombo    }   ,
                HomePage                        =>  $auction->{ HomePage        }   ,
                Permanent                       =>  $auction->{ Permanent       }   ,
                MovieRating                     =>  $auction->{ MovieRating     }   ,
                MovieConfirm                    =>  $auction->{ MovieConfirm    }   ,
                AttributeName                   =>  $auction->{ AttributeName   }   ,
                AttributeValue                  =>  $auction->{ AttributeValue  }   ,
                TMATT104                        =>  $auction->{ TMATT104        }   ,
                TMATT104_2                      =>  $auction->{ TMATT104_2      }   ,
                TMATT106                        =>  $auction->{ TMATT106        }   ,
                TMATT106_2                      =>  $auction->{ TMATT106_2      }   ,
                TMATT108                        =>  $auction->{ TMATT108        }   ,
                TMATT108_2                      =>  $auction->{ TMATT108_2      }   ,
                TMATT111                        =>  $auction->{ TMATT111        }   ,
                TMATT112                        =>  $auction->{ TMATT112        }   ,
                TMATT115                        =>  $auction->{ TMATT115        }   ,
                TMATT117                        =>  $auction->{ TMATT117        }   ,
                TMATT118                        =>  $auction->{ TMATT118        }   ,
            );

            if (not defined $newauction) {

                $tm->update_auction_record(
                    AuctionKey       =>  $auction->{AuctionKey},
                    DateLoaded       =>  "01/01/01",
                    CloseDate        =>  "00:00:00",
                    CloseTime        =>  "00:00:00",
                );

                $tm->update_log("*** Error loading auction to TradeMe - Auction not Loaded");
                $copies_loaded = $auction->{CopyCount};

            }

            else {

                my ($closetime, $closedate);

                if ( $auction->{ EndType } eq "DURATION" ) {

                    $closedate = $tm->closedate( $auction->{ DurationHours } );
                    $closetime = $tm->closetime( $auction->{ DurationHours } );
                }

                if ( $auction->{ EndType } eq "FIXEDEND" ) {

                    $closedate = $tm->fixeddate( $auction->{ EndDays } );
                    $closetime = $tm->fixedtime( $auction->{ EndTime } );
                }

                $tm->update_log("Auction Uploaded to Trade me as Auction $newauction");

                if  ($copies_loaded == 0 )  {                 #First copy of auction

                    $tm->update_auction_record(
                        AuctionKey       =>  $auction->{ AuctionKey }                       ,
                        AuctionStatus    =>  "CURRENT"                                      ,
                        AuctionRef       =>  $newauction                                    ,
                        DateLoaded       =>  $tm->datenow()                                 ,
                        CloseDate        =>  $closedate                                     ,
                        CloseTime        =>  $closetime                                     ,
                    );

                } 

                else {

                    $tm->copy_auction_record(
                        AuctionKey       =>  $auction->{ AuctionKey }                       ,
                        AuctionStatus    =>  "CURRENT"                                      ,
                        AuctionRef       =>  $newauction                                    ,
                        DateLoaded       =>  $tm->datenow()                                 ,
                        CloseDate        =>  $closedate                                     ,
                        CloseTime        =>  $closetime                                     ,
                    );
                }

                $copies_loaded++;
            }
            print "Loaded new auction: $newauction ($auction->{Title})\n";

            sleep 3;
            $counter++;
        }
    }
}


# Success.

print "Done\n";
exit(0);
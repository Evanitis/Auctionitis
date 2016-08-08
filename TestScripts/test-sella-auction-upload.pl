#!perl -w

use strict;
use Auctionitis;

my $auctionkey = shift;

unless ( $auctionkey ) { print "You must supply an Aucion Key to be loaded\n"; exit; }

my $tm = Auctionitis->new();
$tm->initialise( Product => "Auctionitis" );  # Initialise the product
$tm->DBconnect();
$tm->connect_to_sella();

my $a = $tm->get_auction_record( $auctionkey );

print "AuctionUpload: Loading auction $a->{ Title } (Record $a->{ AuctionKey })\n";

if ( $a->{ AuctionStatus } eq 'PENDING' ) {

    my $terms       = $tm->get_standard_terms( AuctionSite => "SELLA" );
    my $description = $a->{ Description }."\n\n".$terms;

    my $maxlength = 3465;

    if ( length( $description ) > $maxlength ) {
        $description = $a->{ Description };
    }

    # Set the message field to blank and load the auction...                

    my $message = "";

    my $newauction = $tm->load_sella_auction(
        AuctionKey                      =>  $a->{ AuctionKey            }   ,
        Category                        =>  $a->{ Category              }   ,
        Title                           =>  $a->{ Title                 }   ,
        Subtitle                        =>  $a->{ Subtitle              }   ,
        Description                     =>  $description                    ,
        IsNew                           =>  $a->{ IsNew                 }   ,
        EndType                         =>  $a->{ EndType               }   ,
        DurationHours                   =>  $a->{ DurationHours         }   ,
        EndDays                         =>  $a->{ EndDays               }   ,
        EndTime                         =>  $a->{ EndTime               }   ,
        PickupOption                    =>  $a->{ PickupOption          }   ,
        ShippingOption                  =>  $a->{ ShippingOption        }   ,
        ShippingInfo                    =>  $a->{ ShippingInfo          }   ,
        StartPrice                      =>  $a->{ StartPrice            }   ,
        ReservePrice                    =>  $a->{ ReservePrice          }   ,
        BuyNowPrice                     =>  $a->{ BuyNowPrice           }   ,
        RestrictAddress                 =>  $tm->{ RestrictAddress      }   ,
        RestrictPhone                   =>  $tm->{ RestrictPhone        }   ,
        RestrictRating                  =>  $tm->{ RestrictRating       }   ,
        BankDeposit                     =>  $a->{ BankDeposit           }   ,
        CreditCard                      =>  $a->{ CreditCard            }   ,
        CashOnPickup                    =>  $a->{ CashOnPickup          }   ,
        EFTPOS                          =>  $a->{ EFTPOS                }   ,
        Quickpay                        =>  $a->{ Quickpay              }   ,
        AgreePayMethod                  =>  $a->{ AgreePayMethod        }   ,
        PaymentInfo                     =>  $a->{ PaymentInfo           }   ,
        DelayedActivate                 =>  0                               ,
    );

    if ( not defined $newauction ) {
    
        $tm->update_auction_record(
            AuctionKey       =>  $a->{ AuctionKey } ,
            DateLoaded       =>  "01/01/01"         ,
            CloseDate        =>  "00:00:00"         ,
            CloseTime        =>  "00:00:00"         ,
        );

        print "*** Error loading auction to Sella - Auction not Loaded\n";
    }
    else {

        my ($closetime, $closedate);

        if ( $a->{ EndType } eq "DURATION" ) {
        
            $closedate = $tm->closedate( $a->{ DurationHours } );
            $closetime = $tm->closetime( $a->{ DurationHours } );
        }

        if ( $a->{ EndType } eq "FIXEDEND" ) {
        
            $closedate = $tm->fixeddate( $a->{ EndDays } );
            $closetime = $tm->fixedtime( $a->{ EndTime } );
        }

        $tm->update_log("Auction Uploaded to Sella as Auction $newauction");

        $tm->update_auction_record(
            AuctionKey       =>  $a->{ AuctionKey }                       ,
            #AuctionStatus    =>  "CURRENT"                                      ,
            AuctionStatus    =>  "DRAFT"            ,
            AuctionRef       =>  $newauction                                    ,
            DateLoaded       =>  $tm->datenow()                                 ,
            CloseDate        =>  $closedate                                     ,
            CloseTime        =>  $closetime                                     ,
        );
        print "Auction Uploaded to Sella as Auction $newauction\n";
    }
}
else {
    print "Auction $a->{Title} (Record $a->{AuctionKey}) not loaded: Invalid Auction Status ($a->{AuctionStatus})\n";
}        


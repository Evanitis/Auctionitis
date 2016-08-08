use strict;
use Auctionitis;
use Win32::OLE;

my ($tm, $pb, $estruct, $abend);

    my $auctions;

    $tm = Auctionitis->new();
    $tm->initialise(Product => "Auctionitis");  # Initialise the product

    $pb = Win32::OLE->new('MultiPB.clsMultiPB') or die;

    ### insert some text into the window header

    $pb->InitialiseMultiBar();
    $pb->{ SetWindowTitle       }   =   "Auctionitis: Import All Auctions";
    
    $pb->AddTask("Import Current Auction Data");
    $pb->AddTask("Import Sold Auction Data");
    $pb->AddTask("Import Unsold Auction Data");

    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    $tm->DBconnect();                          # Connect to the database

    $tm->login();

    #-----------------------------------------------------------------------------------------
    # Task 1 - Process Current Auctions
    #-----------------------------------------------------------------------------------------

    $pb->{ SetCurrentTask       }   =   1;
    $pb->{ SetCurrentOperation  }   =   "Retrieving Current Auction Data";
    $pb->{ SetTaskAction        }   =   "Adding TradeMe auction:";
    
    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    $auctions = $tm->get_curr_listings(\&UpdateStatusBar);

    if ( defined(@$auctions) ) {
        ImportAuctions($auctions, "CURRENT");
    }

    $pb->MarkTaskCompleted(1);
    $pb->UpdateMultiBar();
    
    #-----------------------------------------------------------------------------------------
    # Task 2 - Process Sold Auctions
    #-----------------------------------------------------------------------------------------

    $pb->{ SetCurrentTask       }   =   2;
    $pb->{ SetCurrentOperation  }   =   "Retrieving Sold Auction Data";
    $pb->{ SetTaskAction        }   =   "Adding TradeMe auction:";
    
    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    $auctions = $tm->get_sold_listings(\&UpdateStatusBar);

    if ( defined(@$auctions) ) {
         ImportAuctions($auctions, "SOLD");
    }

    $pb->MarkTaskCompleted(2);
    $pb->UpdateMultiBar();

    #-----------------------------------------------------------------------------------------
    # Task 3 - Process Unsold Auctions
    #-----------------------------------------------------------------------------------------

    $pb->{ SetCurrentTask       }   =   3;
    $pb->{ SetCurrentOperation  }   =   "Retrieving Unsold Auction Data";
    $pb->{ SetTaskAction        }   =   "Adding TradeMe auction:";
    
    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    $auctions = $tm->get_unsold_listings(\&UpdateStatusBar);
    
    if ( defined(@$auctions) ) {
        ImportAuctions($auctions, "UNSOLD");
    }

    $pb->MarkTaskCompleted(3);
    $pb->UpdateMultiBar();

    sleep 2;
    $pb->QuitMultiBar();
    
#=============================================================================================
# ImportAuctions - Subroutine to do the actual Import processing
#=============================================================================================

sub ImportAuctions {

    my $auctions    = shift;
    my $status      = shift;

    $pb->{ SetProgressTotal     }   =   @$auctions;
    $pb->UpdateMultiBar();

    my $counter = 1;

    # Update current auction data from list of auctions
    
    my($dd, $mm, $yy)   = (localtime(time))[3,4,5];
    my $now = $dd."/".($mm + 1)."/".($yy + 1900);

    my $ImportMessage = "Imported from TradeMe on $now";

    foreach my $auction (@$auctions) {

        $pb->{ SetProgressCurrent   }   =   $counter;
        $pb->UpdateMultiBar();

        if     (not $tm->is_DBauction_104($auction->{ AuctionRef } )) {

                my %data        = $tm->import_auction_details($auction->{ AuctionRef } , $status);
                my %details     = $tm->get_auction_details($auction->{ AuctionRef } );

                $pb->{ SetCurrentOperation } = "Adding auction ".$auction->{ AuctionRef } .": ".$data{Title};

                if     (not $data{ Permanent } ) {

                        $tm->insert_DBauction_104(
                              AuctionRef                =>  $auction->{ AuctionRef }  ,
                              ($status eq "CURRENT" )   ?   (AuctionStatus  =>  "CURRENT")  : ()                  ,
                              ($status eq "SOLD"    )   ?   (AuctionStatus  =>  "SOLD")     : ()                  ,
                              ($status eq "UNSOLD"  )   ?   (AuctionStatus  =>  "UNSOLD")   : ()                  ,
                              ($status eq "SOLD")       ?   (AuctionSold    =>  1)          : (AuctionSold =>  0) ,
                              AuctionSite               =>  "TRADEME"                 ,
                              Title                     =>  $data{ Title             },
                              IsNew                     =>  $data{ IsNew             },
                              Category                  =>  $data{ Category          },
                              MovieConfirmation         =>  $data{ MovieConfirmation },
                              MovieRating               =>  $data{ MovieRating       },
                              AttributeName             =>  $data{ AttributeName     },
                              AttributeValue            =>  $data{ AttributeValue    },
                              ClosedAuction             =>  $data{ ClosedAuction     },
                              AutoExtend                =>  $data{ AutoExtend        },
                              BuyNowPrice               =>  $data{ BuyNowPrice       },
                              StartPrice                =>  $data{ StartPrice        },
                              ReservePrice              =>  $data{ ReservePrice      },
                              Cash                      =>  $data{ Cash              },
                              Cheque                    =>  $data{ Cheque            },
                              BankDeposit               =>  $data{ BankDeposit       },
                              PaymentInfo               =>  $data{ PaymentInfo       },
                              FreeShipNZ                =>  $data{ FreeShipNZ        },
                              ShippingInfo              =>  $data{ ShippingInfo      },
                              SafeTrader                =>  $data{ SafeTrader        },
                              DurationHours             =>  $data{ DurationHours     },
                              ClosedDate                =>  $details{ CloseDate      },
                              Message                   =>  $ImportMessage            ,
                              Description               =>  $data{ Description       });
                        
                        sleep 3;
                }
        } else {

                $pb->{SetCurrentOperation} = "Auction ".$auction->{ AuctionRef }. " not added - record already exists in database";
        }

        $counter++;

    }
}

#=============================================================================================
# UpdateStatusBar - Update the Status Bar Text
#=============================================================================================

sub UpdateStatusBar {

    my $text = shift;

    $pb->{SetCurrentOperation} = $text;
    $pb->UpdateMultiBar();

}


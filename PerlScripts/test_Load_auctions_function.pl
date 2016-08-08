#!perl -w
#--------------------------------------------------------------------
# function to test the auction load process
# Other program notes:
#--------------------------------------------------------------------

use strict;
use Auctionitis;
use Win32::OLE;

my $debug = 0;

my $pb = Win32::OLE->new('MultiPB.clsMultiPB') or die;
my $returncode = 0;

### insert some text into the window header

$pb->InitialiseMultiBar();
$pb->{SetWindowTitle} = "Auctionitis: Task Progress Meter";
$pb->AddTask("Load All Pending auctions");
$pb->{SetCurrentTask} = 1;
$pb->{SetCurrentOperation} = "Retrieving Auctions requiring upload";
$pb->{SetTaskAction} = "Loading auctions to TradeMe:";
$pb->UpdateMultiBar();

$pb->ShowMultiBar();

my $tm = Auctionitis->new();
$tm->initialise(Product => "Auctionitis");  # Initialise the product
$tm->DBconnect("Auctionitis103");           # Connect to the database

$pb->UpdateMultiBar();

my $auctions =  $tm->get_pending_auctions();

$pb->UpdateMultiBar();
sleep 3;

$pb->{SetProgressTotal} = @$auctions;
$pb->UpdateMultiBar();

my $counter = 1;

$pb->{SetCurrentOperation} = "Logging on to TradeMe";
$pb->UpdateMultiBar();
$tm->login();

foreach my $auction (@$auctions) {

    my ($PhotoID1, $PhotoID2, $PhotoID3);

    $pb->{SetProgressCurrent} = $counter;
    $pb->UpdateMultiBar();

    $pb->{SetCurrentOperation} = "Loading ".$auction->{Title};

    if  ($auction->{PictureKey1}) {
         my $photo = $tm->get_picture_record($auction->{PictureKey1});
         $PhotoID1 = $photo->{PhotoId};
    }

    if  ($auction->{PictureKey2}) {
         my $photo = $tm->get_picture_record($auction->{PictureKey2});
         $PhotoID2 = $photo->{PhotoId};
    }

    if  ($auction->{PictureKey3}) {
         my $photo = $tm->get_picture_record($auction->{PictureKey3});
         $PhotoID3 = $photo->{PhotoId};
    }

    $debug ? (print "Category     :   $auction->{Category      }\n") :();
    $debug ? (print "Title        :   $auction->{Title         }\n") :();
    $debug ? (print "Description  :   $auction->{Description   }\n") :();
    $debug ? (print "Is New       :   $auction->{IsNew         }\n") :();
    $debug ? (print "Duration     :   $auction->{DurationHours }\n") :();
    $debug ? (print "Start Price  :   $auction->{StartPrice    }\n") :();
    $debug ? (print "Reserve Price:   $auction->{ReservePrice  }\n") :();
    $debug ? (print "Buy Now Price:   $auction->{BuyNowPrice   }\n") :();
    $debug ? (print "Closed       :   $auction->{ClosedAuction }\n") :();
    $debug ? (print "Auto Extend  :   $auction->{AutoExtend    }\n") :();
    $debug ? (print "Cash         :   $auction->{Cash          }\n") :();
    $debug ? (print "Cheque       :   $auction->{Cheque        }\n") :();
    $debug ? (print "Bank Deposit :   $auction->{BankDeposit   }\n") :();
    $debug ? (print "Payment Info :   $auction->{PaymentInfo   }\n") :();
    $debug ? (print "Free Ship NZ :   $auction->{FreeShippingNZ}\n") :();
    $debug ? (print "Shipping Info:   $auction->{ShippingInfo  }\n") :();
    $debug ? (print "Safe Trader  :   $auction->{SafeTrader    }\n") :();
    $debug ? (print "Photo 1      :   $PhotoID1\n") :();
    $debug ? (print "Photo 2      :   $PhotoID2\n") :();
    $debug ? (print "Photo 3      :   $PhotoID3\n") :();
    $debug ? (print "Featured     :   $auction->{Featured      }\n") :();
    $debug ? (print "Gallery      :   $auction->{Gallery       }\n") :();
    $debug ? (print "Bold Title   :   $auction->{BoldTitle     }\n") :();
    $debug ? (print "Feature Combo:   $auction->{Featured      }\n") :();
    $debug ? (print "Home Page    :   $auction->{HomePage      }\n") :();
    $debug ? (print "Permanent    :   $auction->{Permanent     }\n") :();
    $debug ? (print "Movie Rating :   $auction->{MovieRating   }\n") :();
    $debug ? (print "Movie Confirm:   $auction->{MovieConfirm  }\n") :();

    my $newauction = $tm->load_new_auction( CategoryID      =>   $auction->{Category      },
                                            Title           =>   $auction->{Title         },
                                            Description     =>   $auction->{Description   },
                                            IsNew           =>   $auction->{IsNew         },
                                            DurationHours   =>   $auction->{DurationHours },
                                            StartPrice      =>   $auction->{StartPrice    },  
                                            ReservePrice    =>   $auction->{ReservePrice  },
                                            BuyNowPrice     =>   $auction->{BuyNowPrice   },
                                            ClosedAuction   =>   $auction->{ClosedAuction },
                                            AutoExtend      =>   $auction->{AutoExtend    },
                                            Cash            =>   $auction->{Cash          },
                                            Cheque          =>   $auction->{Cheque        },
                                            BankDeposit     =>   $auction->{BankDeposit   },
                                            PaymentInfo     =>   $auction->{PaymentInfo   },
                                            FreeShippingNZ  =>   $auction->{FreeShippingNZ},
                                            ShippingInfo    =>   $auction->{ShippingInfo  },
                                            SafeTrader      =>   $auction->{SafeTrader    },
                                            PhotoID1        =>   $PhotoID1,
                                            PhotoID2        =>   $PhotoID2,
                                            PhotoID3        =>   $PhotoID3,
                                            Featured        =>   $auction->{Featured      },
                                            Gallery         =>   $auction->{Gallery       },
                                            BoldTitle       =>   $auction->{BoldTitle     },
                                            FeaturedCombo   =>   $auction->{Featured      },
                                            HomePage        =>   $auction->{HomePage      },
                                            Permanent       =>   $auction->{Permanent     },
                                            MovieRating     =>   $auction->{MovieRating   },
                                            MovieConfirm    =>   $auction->{MovieConfirm  });

    print "Loaded auction: $newauction\n";

    $tm->update_auction_record(AuctionKey       =>  $auction->{AuctionKey},
                               AuctionStatus    =>  "LOADED",
                               AuctionRef       =>  $newauction);
    sleep 3;

    $counter++;

    if ($pb->{Cancelled}) {
        $pb->QuitMultiBar();        
        exit;
    }

}

$pb->MarkTaskCompleted(1);
$pb->UpdateMultiBar();
sleep 2;
$pb->QuitMultiBar();

# Success.

print "Done\n";
exit(0);

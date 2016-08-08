use strict;
use Auctionitis;
use Win32::OLE;

my $debug = 0;

my $pb = Win32::OLE->new('MultiPB.clsMultiPB') or die;
my $returncode = 0;

### insert some text into the window header

$pb->InitialiseMultiBar();
$pb->{SetWindowTitle} = "Auctionitis: Task Progress Meter";
$pb->AddTask("Import Current Auction Data");
$pb->{SetCurrentTask} = 1;
$pb->{SetCurrentOperation} = "Retrieving Current Auction Data";
$pb->{SetTaskAction} = "Adding TradeMe auction:";
$pb->UpdateMultiBar();

$pb->ShowMultiBar();

my $tm = Auctionitis->new();
$tm->initialise(Product => "Auctionitis");  # Initialise the product
$tm->DBconnect( "Auctionitis103" );           # Connect to the database
$tm->login();

$pb->UpdateMultiBar();

my @auctions = $tm->get_curr_listings();

$pb->{SetProgressTotal} = $#auctions + 1;
$pb->UpdateMultiBar();

my $counter = 1;

# Update current auction data from list of auctions

foreach my $auction (@auctions) {

    $pb->{SetProgressCurrent} = $counter;
    $pb->UpdateMultiBar();

    if     (not $tm->is_DBauction_104($auction)) {

            my %data = $tm->import_auction_details($auction, "CURRENT");

            $pb->{SetCurrentOperation} = "Adding auction ".$auction.": ".$data{Title};

            $tm->insert_DBauction_104(AuctionRef        =>  $auction                  ,              
                                      AuctionStatus     =>  "LOADED"                  ,
                                      AuctionSite       =>  "TRADEME"                 ,
                                      Title             =>  $data{ Title             },
                                      IsNew             =>  $data{ IsNew             },
                                      Category          =>  $data{ Category          },
                                      MovieConfirmation =>  $data{ MovieConfirmation },
                                      MovieRating       =>  $data{ MovieRating       },
                                      AttributeName     =>  $data{ AttributeName     },
                                      AttributeValue    =>  $data{ AttributeValue    },
                                      ClosedAuction     =>  $data{ ClosedAuction     },
                                      AutoExtend        =>  $data{ AutoExtend        },
                                      BuyNowPrice       =>  $data{ BuyNowPrice       },
                                      StartPrice        =>  $data{ StartPrice        },
                                      ReservePrice      =>  $data{ ReservePrice      },
                                      Cash              =>  $data{ Cash              },
                                      Cheque            =>  $data{ Cheque            },
                                      BankDeposit       =>  $data{ BankDeposit       },
                                      PaymentInfo       =>  $data{ PaymentInfo       },
                                      FreeShipNZ        =>  $data{ FreeShipNZ        },
                                      ShippingInfo      =>  $data{ ShippingInfo      },
                                      SafeTrader        =>  $data{ SafeTrader        },
                                      DurationHours     =>  $data{ DurationHours     },
                                      Description       =>  $data{ Description       });

    } else {
            $pb->{SetCurrentOperation} = "Auction ".$auction. " not added - record already exists in database";
    }
    
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

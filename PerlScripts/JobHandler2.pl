#! perl -w

use strict;
use Auctionitis;
use IO::Socket;
use IO::Select;

my $message;
my $masterq;
my $slaveq;
my $select;
my @ready;
my $shutdown;


initialise();
wait_for_job();

sub initialise {

    # Set up the master and slave sockets for messaging

    $slaveq = IO::Socket::INET->new(
        LocalPort => '15556'    ,
        Proto       =>  'udp'   , 
    );
    # die "Could not create socket: $@\n" unless $masterq;
    print $slaveq."\n";

    $masterq  = IO::Socket::INET->new( 
        PeerPort    => '15555'      , 
        PeerAddr    => '127.0.0.1'  ,
        Proto       => 'udp'        ,
    );

    $select = IO::Select->new();
    $select->add( $masterq );

    send_msg_to_master( 'READY' );

}

##############################################################################################
# 
#  M E S S A G I N G    S U B R O U T I N E S
# 
##############################################################################################


sub read_msg_from_master {

    print "Invoked Method: ".(caller(0))[3]."\n";

    print "reading from SLAVE queue\n";

    while ( my $msg = $slaveq->deq() ) {
        print $msg."\n";
        if ( $msg =~ m/CANCEL/i ) {
            return 'CANCEL';
        }
    }
}

sub send_message {

    my $msg = shift;

    $masterq->send( $msg."\n" );
}

sub msg_waiting {
    @ready = $select->can_read();
    if ( fileno( @ready[0] ) == fileno( $masterq ) ) {
        return 1;
    }
    else {
        return 0;
    }
}

##############################################################################################
# 
#  J O B   S U B R O U T I N E S
# 
##############################################################################################

sub QueueStub {

    print "Invoked Method: ".(caller(0))[3]."\n";

    send_msg_to_master( "JOBSTART" );

    # Signal End of job
    
    send_msg_to_master( 'JOBEND' );
}

sub justatest {

    print "Invoked Method: ".(caller(0))[3]."\n";

    print "just a test now executing...\n";

    # Main Processing Loop

    my $loops = 1;

    while ( $loops <= 6 ) {

        my $msg = read_msg_from_master();

        # Check for termination request and exit processing loop if received

        if ( ( $msg ) and ( $msg =~ m/CANCEL/i ) ) {
            send_msg_to_master( 'JOBEND' );
            return;
        }

        send_msg_to_master( "justatest Iteration: $loops" );
        $loops ++;
        sleep 20;
        print "finished sleeping\n";
    }

    # End the job

    send_msg_to_master( 'JOBEND' );

    sleep 1; # Allow time for resources to be reclaimed gracefully.


}

sub justatest2 {

    print "Invoked Method: ".(caller(0))[3]."\n";

    print "just a test 2 now executing...\n";
    send_msg_to_master( 'justatest 2 going to sleep' );

    sleep 125;

   send_master_msg( 'JOBEND' );
}

sub GetTMBalance {

    print "Invoked Method: ".(caller(0))[3]."\n";

    send_msg_to_master( 'JOBSTART' );

    # Connect to the Auctionitis object

    my $tm = Auctionitis->new();
    $tm->initialise( Product => "Auctionitis" );
    $tm->DBconnect();
    $tm->login();
    
    if ( $tm->{ ErrorMessage } ) {
        send_msg_to_master( 'ERROR: '.$tm->{ ErrorMessage } );
        send_msg_to_master( 'JOBEND' );
        return;
    }
    
    my $balance = $tm->get_account_balance();
    
   send_msg_to_master( "Account Balance for ".$tm->{ TradeMeID }." is: ".$balance );

    # Signal End of job
    
    send_msg_to_master( 'JOBEND' );
}

#=============================================================================================
# load_sella_images - Load all images that have not been loaded to Sella
#=============================================================================================

sub load_sella_images {

    print "Invoked Method: ".(caller(0))[3]."\n";

    send_msg_to_master( "JOBSTART" );

    # Connect to the Auctionitis object

    my $tm = Auctionitis->new();
    $tm->initialise( Product => "Auctionitis" );
    $tm->DBconnect();
    $tm->update_log("Connecting to Sella");
    $tm->connect_to_sella();

    # if login was not OK update error structure and return

    if ( $tm->{ ErrorStatus } ) {
        send_msg_to_master( 'ERROR: '.$tm->{ ErrorMessage } );
        send_msg_to_master( 'JOBEND' );
        return;
    }    

    $tm->update_log("Started: Load New Sella Images");

    my $images =  $tm->get_unloaded_pictures( AuctionSite => "SELLA" );

    if ( scalar( @$images ) ne 0 ) {

        # Check for termination request and exit processing loop if received

        if ( read_msg_from_master() =~ m/CANCEL/i ) {
            $tm->update_log( "Sella Image Upload Cancelled by User" );
            send_msg_to_master( 'JOBEND' );
            return;
        }

        my $counter = 1;

        foreach my $pic ( @$images ) {

            send_msg_to_master( "Loading Images to Sella: ".$counter." of ".scalar( @$images ) );

            my $sellaid = $tm->load_sella_image_from_DB( 
                PictureKey  =>  $pic->{ PictureKey  }   ,
                ImageName   =>  $pic->{ ImageName   }   ,
            );

            if ( not defined $sellaid ) {
                $tm->update_log( "Error uploading File $pic->{ PictureFileName } to Sella (record $pic->{ PictureKey })" );
            }
            else {
                $tm->update_picture_record( 
                    PictureKey       =>  $pic->{ PictureKey }   ,
                    SellaID          =>  $sellaid               ,
                );
                $tm->update_log( "Loaded File $pic->{ PictureFileName } to Sella as $sellaid (record $pic->{ PictureKey })" );
            }
            sleep 1;    # Sleep for 1 second
            $counter++;
        }
    }
    send_msg_to_master( 'JOBEND' );
}

#=============================================================================================
# LoadAll - Load all Pending Auctions
#=============================================================================================

sub load_sella_auctions {

    print "Invoked Method: ".(caller(0))[3]."\n";

    send_msg_to_master( "JOBSTART" );

    # Connect to the Auctionitis object

    my $tm = Auctionitis->new();
    $tm->initialise( Product => "Auctionitis" );
    $tm->DBconnect();
    $tm->update_log("Connecting to Sella");
    $tm->connect_to_sella();

    # if login was not OK update error structure and return

    if ( $tm->{ ErrorStatus } ) {
    }    

    # Task 1 - Clone auctions
    
    $tm->update_log( "Started: Clone Auctions for upload" );

    my $clones =   $tm->get_clone_auctions( AuctionSite => "SELLA" );

    my @clonekeys;

    foreach my $clone ( @$clones ) {

        my $newkey = $tm->copy_auction_record(
            AuctionKey       =>  $clone->{ AuctionKey } ,
            AuctionStatus    =>  "PENDING"              ,
        );

        push ( @clonekeys, $newkey );    # Store the key of the new clone record

        $tm->update_log( "Cloned Auction $clone->{AuctionTitle} (Record $clone->{AuctionKey})");
    }
    
    $tm->update_log( "Completed: Clone Auctions for upload" );

    # Task 2 - Load All Pending Autions

    $tm->update_log( "Started: Load all Pending auctions" );

    my $auctions = $tm->get_pending_auctions( AuctionSite =>  "SELLA" );

    if ( scalar( @$auctions ) > 0 ) {

        my $Counter = 1;

        foreach my $a ( @$auctions ) {

            send_msg_to_master( "Loading Auctionss to Sella: ".$counter." of ".scalar( @$auctions ) );

            $tm->update_log("AuctionUpload: Loading auction $a->{ Title } (Record $a->{ AuctionKey })");

            # Append the Standard terms to the Auction Desription

            my $terms       = $tm->get_standard_terms( AuctionSite => "SELLA" );
            my $description = $a->{ Description }."\n\n".$terms;

            my $maxlength = 3465;

            if ( length( $description ) > $maxlength ) {
                $description = $a->{ Description };
                $tm->update_log( "Auction $a->{ Title } (Record $a->{ AuctionKey }) - standard terms not applied.");
                $tm->update_log( "Combined length of standard terms and description would exceed allowable length");
                $tm->update_log( "Description [".length( $description )."] Terms [".length( $description )."] Threshold [".$maxlength."]");
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
                DelayedActivate                 =>  1                               ,
            );

            if ( not defined $newauction ) {
                $tm->update_log("*** Error loading auction to Sella - Auction not Loaded");
            }
            else {

                $tm->update_log("Auction Uploaded to Sella as DRAFT Auction $newauction");

                $tm->update_auction_record(
                    AuctionKey       =>  $a->{ AuctionKey } ,
                    AuctionStatus    =>  "DRAFT"            ,
                    AuctionRef       =>  $newauction        ,
                );
            }

            # Test whether the upload has been cancelled
            # Exit the loop BUT NOT THE ENTIRE PROCESS as there is housekeeping to do for the clones

            if ( read_msg_from_master() =~ m/CANCEL/i ) {
                $tm->update_log( "Sella Image Upload Cancelled by User" );
                last;
            }

            sleep 1;

            $counter++;
        }
    }

    # Housekeeping for any clones that have been created but not loaded

    if ( scalar( @clonekeys) > 0 ) {

        foreach my $clonekey ( @clonekeys ) {

            my $clonedata = $tm->get_auction_record( $clonekey );
            
            if ( $clonedata->{ AuctionStatus } eq "PENDING" ) {
                $tm->delete_auction_record( $clonekey );
                $tm->update_log("Deleted Cloned Auction $clonedata->{ AuctionTitle } (Record $clonekey) - Auction did not load");
            }
        }
    }
    send_msg_to_master( 'JOBEND' );
}

sub activate_sella_auctions {

    print "Invoked Method: ".(caller(0))[3]."\n";

    # Main Processing Loop

    my $loops = 1;

    while ( $loops <= 6 ) {

        # Check for termination request and exit processing loop if received

        if ( read_msg_from_master() =~ m/CANCEL/i ) {
            send_msg_to_master( 'JOBEND' );
            sleep 1;
            last;
        }

        send_msg_to_master( "justatest Iteration: $loops" );
        $loops ++;
        sleep 20;
    }

    # End the job

    send_msg_to_master( 'JOBEND' );

}

1;

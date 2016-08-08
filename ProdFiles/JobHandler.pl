#! perl -w

use strict;
use Auctionitis;
use Win32::Console;
use IO::Socket;
use IO::Select;
require Exporter;

my $console;
my $consoleactive = 0;
my $message;
my $masterq;
my $slaveq;
my $select;
my $shutdown;
my $debug = 1;
my $job_cancelled_flag = 0;
my $tm;
our $AUTOLOAD;

our @EXPORT = qw(
    Z_DELETE Z_NOSTOCK Z_REMOVE Z_CANLIST Z_NEWITEM Z_EXCLUDE Z_SLOW Z_DEAD
    STS_CLONE STS_TEMPLATE STS_CURRENT STS_SOLD STS_UNSOLD STS_RELISTED
    SITE_TRADEME SITE_SELLA SITE_TANDE SITE_ZILLION
    INFO DEBUG VERBOSE
);

use constant {
    MINIMUM_BALANCE_REACHED            => 'MINIMUM_BALANCE_REACHED'   ,
    CURRENT_BALANCE_CHANGED            => 'CURRENT_BALANCE_CHANGED'   ,
};

initialise();
run_job();

sub initialise {

    check_for_console();

    console_msg( "Job Handler process started\n" );

    # Set up the master and slave sockets for messaging

    console_msg( "Creating Sockets for JobHandler (Slave)\n" );

    $slaveq = IO::Socket::INET->new(
        LocalPort   => '15556'  ,
        Proto       =>  'udp'   , 
    );

    $masterq  = IO::Socket::INET->new( 
        PeerPort    => '15555'      , 
        PeerAddr    => '127.0.0.1'  ,
        Proto       => 'udp'        ,
    );

    console_msg( 'Master: '.$masterq."\n" );
    console_msg( ' Slave: '.$slaveq."\n" );

    $select = IO::Select->new();
    $select->add( $slaveq );

    send_message( 'READY' );
}

sub check_for_console {

    # Connect to the Auctionitis object

    $tm = Auctionitis->new();
    $tm->initialise( Product => "Auctionitis" );

    if ( $tm->{ HandlerConsole } ) {
        $consoleactive = 1;
        $console = new Win32::Console( STD_OUTPUT_HANDLE );
        $console->Alloc();
        $console->Display();
        $console->Title( "Auctionitis Job Handler Console Log" );
        $console->Attr( $FG_YELLOW | $BG_BLACK );
        console_msg( "Beginning JobHandler Log Output...\n\n" );
    }

}

sub console_msg {

    my $msg = shift;

    if ( $consoleactive ) {
        $console->Write( $msg );
        $console->Display();
    }
}

sub run_job {

    my $jobname = get_jobname();

    my $jobs = {
        'update_db'         =>  \&update_db         ,
        'update_db_sella'   =>  \&update_db_sella   ,
        'load_images_tm'    =>  \&load_images_tm    ,
        'load_images_sella' =>  \&load_images_sella ,
        'load_trademe'      =>  \&load_trademe      ,
        'load_sella'        =>  \&load_sella        ,
        'load_clones_sella' =>  \&load_clones_sella ,
        'activate_sella'    =>  \&activate_sella    ,
        'offer_trademe'     =>  \&offer_trademe     ,
        'offer_sella'       =>  \&offer_sella       ,
        'relist_trademe'    =>  \&relist_trademe    ,
        'relist_sella'      =>  \&relist_sella      ,
        'get_balance_tm'    =>  \&get_balance_tm    ,
        'update_categories' =>  \&update_categories ,
        'test1'             =>  \&test1             ,
        'test2'             =>  \&test2             ,
        'test3'             =>  \&test3             ,
    };

    # Translate the name to lower case to be safe

    $jobname =~ tr/[A-Z]/[a-z]/;

    if ( $jobs->{ $jobname } ) {
        $jobs->{ $jobname }->( Jobname => $jobname );
    }
    else {
        job_unknown( Jobname => $jobname );
    }
}

##############################################################################################
# 
#  M E S S A G I N G    S U B R O U T I N E S
# 
##############################################################################################

sub get_jobname {

    my $loops = 0;

    while ( $loops < 120 ) {
        if ( msg_waiting() ) {
            my $msgs = receive_messages();
            foreach my $msg ( @$msgs ) {
                console_msg( "Received Message: ".$msg );
                $msg =~ tr/\n//d;                            # strip out new lines
                if ( $msg =~ m/JOBNAME:(.*)/i ) {

                    console_msg( "Received Job: $1\n" );
                    return $1;
                }
                else  {
                    console_msg( "Unexpected Message received from Job Server\n" );
                }
            }
        }
        else {
            sleep 1;
        }
        console_msg( "Waiting for job...\n" );
        $loops++;
    }
    return;    # No Job Name received - effectively a timeout failure....
}

sub wait_for_ok_to_end {

    my $loops = 0;

    while ( $loops < 120 ) {
        if ( msg_waiting() ) {
            my $msgs = receive_messages();
            foreach my $msg ( @$msgs ) {
                console_msg( "Received Message: ".$msg );
                $msg =~ tr/\n//d;                            # strip out new lines
                if ( $msg =~ m/OK2END(.*)/i ) {
                    console_msg( "Confirmation received for end of job\n" );
                    sleep 2;
                    return 1;
                }
            }
        }
        else {
            sleep 1;
        }
        console_msg( "Waiting for end of job confirmation...\n" );
        $loops++;
    }
    return;    # No Job Name received - effectively a timeout failure....
}

sub job_cancelled {

    if ( msg_waiting() ) {

        my $msgs = receive_messages();

        foreach my $msg ( @$msgs ) {
            $msg = tr/\n//d;                            # strip out new lines
            if ( $msg =~ m/CANCEL/i ) {
                console_msg( "Cancel request Received for Job\n" );
                $job_cancelled_flag = 1;                # Set global cancellation flag
                return 1;
            }
        }
    }
    return 0;    # No Job Name received - effectively a timeout failure....
}

sub receive_messages {

    my ( $msgs, $msg );
        
    while ( msg_waiting() ) {
        my $peer = $slaveq->recv( $msg, 2048 );
        console_msg( $msg );
        push( @$msgs, $msg );
    }
    return $msgs;
}

sub send_message {

    my $msg = shift;

    $msg.="\n";

    $masterq->send( $msg );
}

sub msg_waiting {
    if ( my @ready = $select->can_read( 0 ) ) {
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

sub job_stub {

    my $p = { @_ };

    # Signal Start of job

    send_message( 'JOBSTART' );
    send_message( 'Starting job '.$p->{ Jobname } );

    $tm = Auctionitis->new();
    $tm->initialise( Product => "Auctionitis" );
    $tm->update_log("Invoked Method: ".( caller(0) )[3] ); 

    if ( not defined( $tm->{ TradeMeID } ) ) {
        $tm->update_log( 'TradeMe ID not defined - request cannot be processed' );
        send_message( 'JOBLOG:TradeMe ID not defined - request cannot be processed' );
        send_message( 'STATUS:TradeMe ID not defined - request cannot be processed' );
        send_message( 'JOBEND' );   # Signal End of job
        wait_for_ok_to_end();
        return;
    }

    if ( not defined( $tm->{ UserID } ) ) {
        $tm->update_log( 'Trade Me Account Name not defined - request cannot be processed' );
        send_message( 'JOBLOG:Trade Me Account Name not defined - request cannot be processed' );
        send_message( 'STATUS:Trade Me Account Name not defined - request cannot be processed' );
        send_message( 'JOBEND' );   # Signal End of job
        wait_for_ok_to_end();
        return;
    }

    if ( not defined( $tm->{ Password } ) ) {
        $tm->update_log( 'Trade Me Account Password not defined - request cannot be processed' );
        send_message( 'JOBLOG:Trade Me Account Password not defined - request cannot be processed' );
        send_message( 'STATUS:Trade Me Account Password not defined - request cannot be processed' );
        send_message( 'JOBEND' );   # Signal End of job
        wait_for_ok_to_end();
        return;
    }

    if ( not defined( $tm->{ SellaEmail } ) ) {
        $tm->update_log( 'Sella Log-in Name not defined - request cannot be processed' );
        send_message( 'JOBLOG:Sella Log-in Name not defined - request cannot be processed' );
        send_message( 'STATUS:Sella Log-in Name not defined - request cannot be processed' );
        send_message( 'JOBEND' );   # Signal End of job
        wait_for_ok_to_end();
        return;
    }

    if ( not defined( $tm->{ SellaPassword } ) ) {
        $tm->update_log( 'Sella Password not defined - request cannot be processed' );
        send_message( 'JOBLOG:Sella Password not defined - request cannot be processed' );
        send_message( 'STATUS:Sella Password not defined - request cannot be processed' );
        send_message( 'JOBEND' );   # Signal End of job
        wait_for_ok_to_end();
        return;
    }

    my $dbok = $tm->DBconnect();

    if ( not $dbok ) {
        $tm->update_log( 'Database not found or does not exist' );
        send_message( 'JOBLOG:Database not found or does not exist' );
        send_message( 'STATUS:Database not found or does not exist' );
        send_message( 'JOBEND' );   # Signal End of job
        wait_for_ok_to_end();
        return;
    }

    $tm->update_log("Connecting to Trade Me");
    $tm->login();

    $tm->update_log("Connecting to Sella");
    $tm->connect_to_sella();

    # Check for job cancellation

    if ( job_cancelled() ) {
        $tm->update_log( "Sella Image Upload Cancelled by User" );
        send_message( 'Job Cancelled by User Request' );
        send_message( 'JOBEND' );   # Signal End of job
        wait_for_ok_to_end();
        return;
    }
    send_message( 'JOBEND' );   # Signal End of job
    wait_for_ok_to_end();
}

sub AUTOLOAD {

    my $p = { @_ };

    console_msg( "Job: $p->{ Jobname }\n" );
    console_msg( "Entered the AUTOLOAD subroutine\n" );

    sleep 1;

    send_message( 'JOBSTART' );
    send_message( 'Starting job '.$p->{ Jobname } );
    send_message( 'Unknown Job '.$p->{ Jobname }.' received for processing - job ended immediately ');
    send_message( 'JOBEND' );   # Signal End of job
    wait_for_ok_to_end();

}

#=============================================================================================
# get_tm_balance - Get Account Balance from Trade Me
#=============================================================================================

sub get_balance_tm {

    my $p = { @_ };

    send_message( 'JOBSTART' );
    send_message( 'Starting job '.$p->{ Jobname } );

    # Connect to the Auctionitis object

    $tm = Auctionitis->new();
    $tm->initialise( Product => "Auctionitis" );
    $tm->update_log( "Invoked Method: ".( caller(0) )[3] ); 

    if ( not defined( $tm->{ TradeMeID } ) ) {
        $tm->update_log( 'TradeMe ID not defined - request cannot be processed' );
        send_message( 'JOBLOG:TradeMe ID not defined - request cannot be processed' );
        send_message( 'STATUS:TradeMe ID not defined - request cannot be processed' );
        send_message( 'JOBEND' );   # Signal End of job
        wait_for_ok_to_end();
        return;
    }

    if ( not defined( $tm->{ UserID } ) ) {
        $tm->update_log( 'Trade Me Account Name not defined - request cannot be processed' );
        send_message( 'JOBLOG:Trade Me Account Name not defined - request cannot be processed' );
        send_message( 'STATUS:Trade Me Account Name not defined - request cannot be processed' );
        send_message( 'JOBEND' );   # Signal End of job
        wait_for_ok_to_end();
        return;
    }

    if ( not defined( $tm->{ Password } ) ) {
        $tm->update_log( 'Trade Me Account Password not defined - request cannot be processed' );
        send_message( 'JOBLOG:Trade Me Account Password not defined - request cannot be processed' );
        send_message( 'STATUS:Trade Me Account Password not defined - request cannot be processed' );
        send_message( 'JOBEND' );   # Signal End of job
        wait_for_ok_to_end();
        return;
    }

    my $dbok = $tm->DBconnect();

    if ( not $dbok ) {
        $tm->update_log( 'Database not found or does not exist' );
        send_message( 'JOBLOG:Database not found or does not exist' );
        send_message( 'STATUS:Database not found or does not exist' );
        send_message( 'JOBEND' );   # Signal End of job
        wait_for_ok_to_end();
        return;
    }

    $tm->login();

    if ( $tm->{ ErrorMessage } ) {
        send_message( 'JOBLOG:'.$tm->{ ErrorMessage } );
        send_message( 'STATUS:'.$tm->{ ErrorMessage } );
        send_message( 'JOBEND' );   # Signal End of job
        wait_for_ok_to_end();
        return;
    }

    my $oldbalance = $tm->get_current_balance();
    my $newbalance = $tm->get_account_balance();

    $tm->set_current_balance( Balance => $newbalance );

    $tm->update_log( "Updated Trade Me account balance; Old Balance: ".$oldbalance."; New Balance: ".$newbalance );

    if ( $oldbalance ne $newbalance ) {
        send_message( 'EVENT:'.CURRENT_BALANCE_CHANGED );
    }

    if ( defined( $tm->{ TMBalanceMinimum } ) and $newbalance < $tm->{ TMBalanceMinimum }  ) {
        send_message( 'EVENT:'.MINIMUM_BALANCE_REACHED );
    }

    send_message( "JOBLOG:Account Balance for ".$tm->{ TradeMeID }." is: ".$newbalance );

    send_message( 'JOBEND' );   # Signal End of job

    wait_for_ok_to_end();
}

#=============================================================================================
# load_sella_images - Load all images that have not been loaded to Sella
#=============================================================================================

sub load_images_sella {

    my $p = { @_ };

    send_message( 'JOBSTART' );
    send_message( 'Starting job '.$p->{ Jobname } );

    # Connect to the Auctionitis object

    $tm = Auctionitis->new();
    $tm->initialise( Product => "Auctionitis" );
    $tm->update_log("Invoked Method: ".( caller(0) )[3] ); 

    if ( not defined( $tm->{ SellaEmail } ) ) {
        $tm->update_log( 'Sella Log-in Name not defined - request cannot be processed' );
        send_message( 'JOBLOG:Sella Log-in Name not defined - request cannot be processed' );
        send_message( 'STATUS:Sella Log-in Name not defined - request cannot be processed' );
        send_message( 'JOBEND' );   # Signal End of job
        wait_for_ok_to_end();
        return;
    }

    if ( not defined( $tm->{ SellaPassword } ) ) {
        $tm->update_log( 'Sella Password not defined - request cannot be processed' );
        send_message( 'JOBLOG:Sella Password not defined - request cannot be processed' );
        send_message( 'STATUS:Sella Password not defined - request cannot be processed' );
        send_message( 'JOBEND' );   # Signal End of job
        wait_for_ok_to_end();
        return;
    }

    my $dbok = $tm->DBconnect();

    if ( not $dbok ) {
        $tm->update_log( 'Database not found or does not exist' );
        send_message( 'JOBLOG:Database not found or does not exist' );
        send_message( 'STATUS:Database not found or does not exist' );
        send_message( 'JOBEND' );   # Signal End of job
        wait_for_ok_to_end();
        return;
    }

    $tm->update_log("Connecting to Sella");
    $tm->connect_to_sella();

    # if login was not OK update error structure and return

    if ( $tm->{ ErrorStatus } ) {
        send_message( 'ERROR:'.$tm->{ ErrorMessage } );
        send_message( 'JOBEND' );   # Signal End of job
        wait_for_ok_to_end();
        return;
    }    

    $tm->update_log("Started: Load New Sella Images");

    my $images =  $tm->get_unloaded_pictures( AuctionSite => 'SELLA' );

    if ( scalar( @$images ) ne 0 ) {

        my $counter = 1;

        foreach my $pic ( @$images ) {

            send_message( 'STATUS:Loading Image to Sella: '.$counter.' of '.scalar( @$images ) );

            my $sellaid = $tm->load_sella_image_from_DB( 
                PictureKey  =>  $pic->{ PictureKey  }   ,
                ImageName   =>  $pic->{ ImageName   }   ,
            );

            if ( not defined $sellaid ) {
                send_message( "JOBLOG:Error uploading File $pic->{ PictureFileName } to Sella (record $pic->{ PictureKey })" );
                $tm->update_log( "Error uploading File $pic->{ PictureFileName } to Sella (record $pic->{ PictureKey })" );
            }
            else {
                $tm->update_picture_record( 
                    PictureKey       =>  $pic->{ PictureKey }   ,
                    SellaID          =>  $sellaid               ,
                );
                send_message( "JOBLOG:Loaded File $pic->{ PictureFileName } to Sella as $sellaid (record $pic->{ PictureKey })" );
                $tm->update_log( "Loaded File $pic->{ PictureFileName } to Sella as $sellaid (record $pic->{ PictureKey })" );
            }

            # Check for termination request and exit processing loop if received

            if ( job_cancelled() ) {
                $tm->update_log( "Sella Image Upload Cancelled by User" );
                send_message( 'JOBLOG:Job Cancelled by User Request' );
                send_message( 'STATUS:Job Cancelled by User Request' );
                last;
            }
            sleep 1;    # Sleep for 1 second
            $counter++;
        }
    }
    send_message( 'JOBEND' );   # Signal End of job
    wait_for_ok_to_end();
}

#=============================================================================================
# load_images_tm - Load all images that have not been loaded to Trade me
#=============================================================================================

sub load_images_tm {

    my $p = { @_ };

    send_message( 'JOBSTART' );
    send_message( 'Starting job '.$p->{ Jobname } );

    # Connect to the Auctionitis object

    $tm = Auctionitis->new();
    $tm->initialise( Product => "Auctionitis" );
    $tm->update_log("Invoked Method: ".( caller(0) )[3] ); 

    if ( not defined( $tm->{ TradeMeID } ) ) {
        $tm->update_log( 'TradeMe ID not defined - request cannot be processed' );
        send_message( 'JOBLOG:TradeMe ID not defined - request cannot be processed' );
        send_message( 'STATUS:TradeMe ID not defined - request cannot be processed' );
        send_message( 'JOBEND' );   # Signal End of job
        wait_for_ok_to_end();
        return;
    }

    if ( not defined( $tm->{ UserID } ) ) {
        $tm->update_log( 'Trade Me Account Name not defined - request cannot be processed' );
        send_message( 'JOBLOG:Trade Me Account Name not defined - request cannot be processed' );
        send_message( 'STATUS:Trade Me Account Name not defined - request cannot be processed' );
        send_message( 'JOBEND' );   # Signal End of job
        wait_for_ok_to_end();
        return;
    }

    if ( not defined( $tm->{ Password } ) ) {
        $tm->update_log( 'Trade Me Account Password not defined - request cannot be processed' );
        send_message( 'JOBLOG:Trade Me Account Password not defined - request cannot be processed' );
        send_message( 'STATUS:Trade Me Account Password not defined - request cannot be processed' );
        send_message( 'JOBEND' );   # Signal End of job
        wait_for_ok_to_end();
        return;
    }

    my $dbok = $tm->DBconnect();

    if ( not $dbok ) {
        $tm->update_log( 'Database not found or does not exist' );
        send_message( 'JOBLOG:Database not found or does not exist' );
        send_message( 'STATUS:Database not found or does not exist' );
        send_message( 'JOBEND' );   # Signal End of job
        wait_for_ok_to_end();
        return;
    }

    $tm->update_log("Connecting to Trade Me");
    $tm->login();

    # if login was not OK update error structure and return

    if ( $tm->{ ErrorStatus } ) {
        send_message( 'ERROR:'.$tm->{ ErrorMessage } );
        send_message( 'JOBEND' );   # Signal End of job
        wait_for_ok_to_end();
        return;
    }    

    $tm->update_log( "Started: Load New Trade Me Images" );

    my $images =  $tm->get_unloaded_pictures( AuctionSite => 'TRADEME' );

    if ( scalar( @$images ) ne 0 ) {

        my $counter = 1;

        foreach my $pic ( @$images ) {

            send_message( 'STATUS:Loading Image to Trade Me: '.$counter.' of '.scalar( @$images ) );

            my $photoid = $tm->load_picture_from_DB( 
                PictureKey  =>  $pic->{ PictureKey  }   ,
                ImageName   =>  $pic->{ ImageName   }   ,
            );

            if ( not defined $photoid ) {
                send_message( "JOBLOG:Error uploading File $pic->{ PictureFileName } to Trade Me (record $pic->{ PictureKey })" );
                $tm->update_log( "Error uploading File $pic->{ PictureFileName } to Trade Me (record $pic->{ PictureKey })" );
            }
            else {

                # Update Picture Record with retrieved ID

                $tm->update_picture_record( 
                    PictureKey       =>  $pic->{ PictureKey }   ,
                    PhotoId          =>  $photoid               ,
                );

                send_message( "JOBLOG:Loaded File $pic->{ PictureFileName } to Trade Me as $photoid (record $pic->{ PictureKey })" );
                $tm->update_log( "Loaded File $pic->{ PictureFileName } to Trade Me as $photoid (record $pic->{ PictureKey })" );

                # Increment the Trade Me Picture count value in the database

                $tm->set_DB_property(
                    Property_Name       => "TMPictureCount" ,
                    Property_Value      => $tm->get_DB_property( Property_Name => "TMPictureCount", Property_Default => 0 ) + 1,
                );
            }

            # Check for termination request and exit processing loop if received

            if ( job_cancelled() ) {
                $tm->update_log( "Trade Me Image Upload Cancelled by User" );
                send_message( 'JOBLOG:Job Cancelled by User Request' );
                send_message( 'STATUS:Job Cancelled by User Request' );
                last;
            }
            sleep 1;    # Sleep for 1 second
            $counter++;
        }
    }

    $tm->update_log( "Completed: Load New Trade Me Images" );

    # If the job was not cancelled continue with checking expiored pictures

    unless ( $job_cancelled_flag ) {
    
        # Process Expired Pictures
    
        $tm->update_log("Started: Check Picture Files on TradeMe");
    
        # Compare the TradeMe picture count with the Auctionitis picture count
    
        my $TMPictotal  = $tm->get_TM_photo_count();
        my $DBPictotal  = $tm->get_DB_property(Property_Name => "TMPictureCount", Property_Default => 0);
        
        $tm->update_log( "Picture Total on TradeMe  - $TMPictotal" );
        $tm->update_log( "Calculated Picture total  - $DBPictotal" );
    
        # If the database total equals the TM picture total there are no expired pics (in theory...)
        
        if ( $DBPictotal eq $TMPictotal ) {
            $tm->update_log( "Picture Totals reconciled - processing complete" );
        }
        else {
    
            # Get list of Images currently on Trade me and create look up table keed on Trade Me photo ID
    
            my @TMPictures = $tm->get_photo_list();
    
            my %TMPictable;
    
            foreach my $PhotoId ( @TMPictures ) {
                $TMPictable{ $PhotoId } = 1;
            }
    
            # Get details of all pictures in the local database
    
            my $currentpictures = $tm->get_all_pictures();
    
            my @expiredpics;
    
            # If the Trade Me Photo Id stored locally is not found in the Current Trade Me picture lookup table created above store for reloading
    
            foreach my $picture ( @$currentpictures ) {
                if ( not defined $TMPictable{ $picture->{ PhotoId } } ) {
                    $tm->update_log( "Located expired Photo $picture->{ PictureFileName } (Record $picture->{ PictureKey })" );
                    push( @expiredpics, $picture->{ PictureKey } );
                }
            }

            my $counter = 1;

            # If any expired pics are encountered upload them to TradeMe
    
            if ( scalar( @expiredpics ) > 0 ) {
    
                my $pictures =  $tm->get_picture_records( @expiredpics );
    
                foreach my $pic ( @$pictures ) {
    
                    send_message( 'STATUS:Loading Expired Image to Trade Me: '.$counter.' of '.scalar( @expiredpics ) );
    
                    my $photoid = $tm->load_picture_from_DB( 
                        PictureKey  =>  $pic->{ PictureKey  }   ,
                        ImageName   =>  $pic->{ ImageName   }   ,
                    );
    
                    if ( not defined $photoid ) {
                        send_message( "JOBLOG:Error uploading File $pic->{ PictureFileName } to Trade Me (record $pic->{ PictureKey })" );
                        $tm->update_log( "Error uploading File $pic->{ PictureFileName } to Trade Me (record $pic->{ PictureKey })" );
                    }
                    else {
    
                        # Update Picture Record with retrieved ID
    
                        $tm->update_picture_record( 
                            PictureKey       =>  $pic->{ PictureKey }   ,
                            PhotoId          =>  $photoid               ,
                        );
    
                        send_message( "JOBLOG:Loaded Expired Image $pic->{ PictureFileName } to Trade Me as $photoid (record $pic->{ PictureKey })" );
                        $tm->update_log( "Loaded File $pic->{ PictureFileName } to Trade Me as $photoid (record $pic->{ PictureKey })" );
                    }
    
                    # Check for termination request and exit processing loop if received
    
                    if ( job_cancelled() ) {
                        $tm->update_log( "Trade Me Image Upload Cancelled by User" );
                        send_message( 'JOBLOG:Job Cancelled by User Request' );
                        send_message( 'STATUS:Job Cancelled by User Request' );
                        last;
                    }
                    sleep 1;    # Sleep for 1 second
                    $counter++;
                }
            }
        }
        $tm->update_log("Completed: Check Picture Files on TradeMe");
    }

    #set the picture total in the database properties file

    my $TMPictotal  = $tm->get_TM_photo_count();

    $tm->set_DB_property(
        Property_Name       => "TMPictureCount" ,
        Property_Value      => $TMPictotal,
    );            

    send_message( 'JOBEND' );   # Signal End of job
    wait_for_ok_to_end();
}

#=============================================================================================
# load_sella - Load all sella PENDING auctions 
#=============================================================================================

sub load_sella {

    my $p = { @_ };

    send_message( 'JOBSTART' );
    send_message( 'Starting job '.$p->{ Jobname } );

    # Connect to the Auctionitis object

    $tm = Auctionitis->new();
    $tm->initialise( Product => "Auctionitis" );
    $tm->update_log("Invoked Method: ".( caller(0) )[3] ); 

    if ( not defined( $tm->{ SellaEmail } ) ) {
        $tm->update_log( 'Sella Log-in Name not defined - request cannot be processed' );
        send_message( 'JOBLOG:Sella Log-in Name not defined - request cannot be processed' );
        send_message( 'STATUS:Sella Log-in Name not defined - request cannot be processed' );
        send_message( 'JOBEND' );   # Signal End of job
        wait_for_ok_to_end();
        return;
    }

    if ( not defined( $tm->{ SellaPassword } ) ) {
        $tm->update_log( 'Sella Password not defined - request cannot be processed' );
        send_message( 'JOBLOG:Sella Password not defined - request cannot be processed' );
        send_message( 'STATUS:Sella Password not defined - request cannot be processed' );
        send_message( 'JOBEND' );   # Signal End of job
        wait_for_ok_to_end();
        return;
    }

    my $dbok = $tm->DBconnect();

    if ( not $dbok ) {
        $tm->update_log( 'Database not found or does not exist' );
        send_message( 'JOBLOG:Database not found or does not exist' );
        send_message( 'STATUS:Database not found or does not exist' );
        send_message( 'JOBEND' );   # Signal End of job
        wait_for_ok_to_end();
        return;
    }

    $tm->update_log("Connecting to Sella");
    $tm->connect_to_sella();

    # if login was not OK update error structure and return

    if ( $tm->{ ErrorStatus } ) {
        send_message( 'ERROR:'.$tm->{ ErrorMessage } );
        send_message( 'JOBEND' );   # Signal End of job
        wait_for_ok_to_end();
        return;
    }    

    $tm->update_log( "Started: Load all PENDING auctions to Sella" );

    my ( $auctions, $cycleauctions );

    $auctions = $tm->get_pending_auctions( AuctionSite => "SELLA" ) if $tm->{ LoadAll };

    if ( $tm->{ LoadCycle } ) {
        $cycleauctions   =  $tm->get_cycle_auctions(
            AuctionSite     =>  "SELLA"                 ,
            AuctionCycle    =>  $tm->{ LoadCycleName }  ,
        )  ;
    }

    push( @$auctions, @$cycleauctions );    # Append the cycle auctions to the standard auctions for loading

    if ( scalar( @$auctions ) > 0 ) {

        my $counter = 1;

        foreach my $a ( @$auctions ) {

            send_message( "STATUS:Loading Auction to Sella: ".$counter." of ".scalar( @$auctions ) );
            send_message( "JOBLOG:Loading Auction $a->{ Title } (Record $a->{ AuctionKey }) - $counter of ".scalar( @$auctions ) );
            $tm->update_log( "AuctionUpload: Loading auction $a->{ Title } (Record $a->{ AuctionKey }) - $counter of ".scalar( @$auctions ) );

            # Append the Standard terms to the Auction Desription

            my $terms       = $tm->get_standard_terms( AuctionSite => "SELLA" );
            my $description = $a->{ Description }."\n\n".$terms;

            my $maxlength = 3465;

            if ( length( $description ) > $maxlength ) {
                $description = $a->{ Description };
                $tm->update_log( "Auction $a->{ Title } (Record $a->{ AuctionKey }) - standard terms not applied.");
                $tm->update_log( "Combined length of standard terms and description would exceed allowable length");
                $tm->update_log( "Description [".length( $description )."] Terms [".length( $description )."] Threshold [".$maxlength."]");

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
                send_message( "JOBLOG:Error Loading auction to Sella - Auction not Loaded");
            }
            else {

                $tm->update_log("Auction Uploaded to Sella as INACTIVE Auction $newauction");
                send_message( "JOBLOG:Auction Uploaded to Sella as INACTIVE Auction $newauction");

                $tm->update_auction_record(
                    AuctionKey       =>  $a->{ AuctionKey } ,
                    AuctionStatus    =>  "INACTIVE"         ,
                    AuctionRef       =>  $newauction        ,
                );
            }

            # Test whether the upload has been cancelled
            # Exit the loop BUT NOT THE ENTIRE PROCESS as there is housekeeping to do for the clones

            if ( job_cancelled() ) {
                send_message( 'STATUS:Job Cancelled by User Request' );
                send_message( 'JOBLOG:Job Cancelled by User Request' );
                $tm->update_log( "Sella Auction Upload Cancelled by User" );
                last;
            }

            sleep 1;

            $counter++;
        }
    }
    else {
        $tm->update_log( "No PENDING Sella Auctions found" );
        send_message( "STATUS:No PENDING Sella Auctions found" );
        send_message( "JOBLOG:No PENDING Sella Auctions found" );
    }
    send_message( 'JOBEND' );   # Signal End of job
    wait_for_ok_to_end();
}

#=============================================================================================
# load_sella_clones - Load all sella CLONE auctions
#=============================================================================================

sub load_clones_sella {

    my $p = { @_ };
    my @clonekeys;

    send_message( 'JOBSTART' );
    send_message( 'Starting job '.$p->{ Jobname } );

    # Connect to the Auctionitis object

    $tm = Auctionitis->new();
    $tm->initialise( Product => "Auctionitis" );
    $tm->update_log("Invoked Method: ".( caller(0) )[3] ); 

    if ( not defined( $tm->{ SellaEmail } ) ) {
        $tm->update_log( 'Sella Log-in Name not defined - request cannot be processed' );
        send_message( 'JOBLOG:Sella Log-in Name not defined - request cannot be processed' );
        send_message( 'STATUS:Sella Log-in Name not defined - request cannot be processed' );
        send_message( 'JOBEND' );   # Signal End of job
        wait_for_ok_to_end();
        return;
    }

    if ( not defined( $tm->{ SellaPassword } ) ) {
        $tm->update_log( 'Sella Password not defined - request cannot be processed' );
        send_message( 'JOBLOG:Sella Password not defined - request cannot be processed' );
        send_message( 'STATUS:Sella Password not defined - request cannot be processed' );
        send_message( 'JOBEND' );   # Signal End of job
        wait_for_ok_to_end();
        return;
    }

    my $dbok = $tm->DBconnect();

    if ( not $dbok ) {
        $tm->update_log( 'Database not found or does not exist' );
        send_message( 'JOBLOG:Database not found or does not exist' );
        send_message( 'STATUS:Database not found or does not exist' );
        send_message( 'JOBEND' );   # Signal End of job
        wait_for_ok_to_end();
        return;
    }

    $tm->update_log("Connecting to Sella");
    $tm->connect_to_sella();

    # if login was not OK update error structure and return

    if ( $tm->{ ErrorStatus } ) {
        send_message( 'ERROR:'.$tm->{ ErrorMessage } );
        send_message( 'JOBEND' );   # Signal End of job
        wait_for_ok_to_end();
        return;
    }    


    my $day = ( localtime )[6];             # Day value is 0 based 
    $tm->set_Schedule_properties( $day );
    
    if ( $tm->{ LoadAll } ) {

        # Clone auctions with no Auction cycle

        $tm->update_log( "Started: Clone Auctions for upload to Sella" );
        send_message( 'STATUS:Clone auctions for Upload to Sella' );
    
        my $clones =   $tm->get_clone_auctions( AuctionSite => "SELLA" );
    
        foreach my $clone ( @$clones ) {
    
            my $newkey = $tm->copy_auction_record(
                AuctionKey       =>  $clone->{ AuctionKey } ,
                AuctionStatus    =>  "PENDING"              ,
            );
    
            push ( @clonekeys, $newkey );    # Store the key of the new clone record
    
            $tm->update_log( "Cloned Auction $clone->{AuctionTitle} (Record $clone->{AuctionKey})");
            send_message( "STATUS:Cloned Auction $clone->{AuctionTitle} (Record $clone->{AuctionKey})" );
        }
     
        $tm->update_log( "Successfully Cloned ".scalar( @$clones )." auctions for upload" );
        send_message( "STATUS:Successfully Cloned ".scalar( @$clones ). " auctions for upload" );
        send_message( "JOBLOG:Successfully Cloned ".scalar( @$clones ). " auctions for upload" );
    }
    
    if ( $tm->{ LoadCycle } ) {

        # Clone auctions with Auction cycle

        $tm->update_log( "Started: Clone Auctions for upload to Sella (Auction Cycle ".$tm->{ LoadCycleName }.")" );
        send_message( 'STATUS:Clone auctions for Upload to Sella' );
    
        my $clones =   $tm->get_clone_auctions(
            AuctionSite => "SELLA"                      ,
            AuctionCycle    => $tm->{ LoadCycleName }   ,
        );
    
        foreach my $clone ( @$clones ) {
    
            my $newkey = $tm->copy_auction_record(
                AuctionKey       =>  $clone->{ AuctionKey } ,
                AuctionStatus    =>  "PENDING"              ,
            );
    
            push ( @clonekeys, $newkey );    # Store the key of the new clone record
    
            $tm->update_log( "Cloned Auction $clone->{ AuctionTitle } (Record $clone->{ AuctionKey })");
            send_message( "STATUS:Cloned Auction $clone->{ AuctionTitle } (Record $clone->{ AuctionKey })" );
        }
     
        $tm->update_log( "Successfully Cloned ".scalar( @$clones )." auctions for upload" );
        send_message( "STATUS:Successfully Cloned ".scalar( @$clones ). " auctions for upload" );
        send_message( "JOBLOG:Successfully Cloned ".scalar( @$clones ). " auctions for upload" );
    }


    # Task 2 - Load All Pending Autions

    $tm->update_log( "Started: Load all Pending auctions to Sella" );

    my $auctions = $tm->get_pending_auctions( AuctionSite =>  "SELLA" );

    my $cycleauctions;

    if ( $tm->{ LoadCycle } ) {
        $cycleauctions   =  $tm->get_cycle_auctions(
            AuctionSite     =>  "SELLA"               ,
            AuctionCycle    =>  $tm->{ LoadCycleName }  ,
        )  ;
    }

    push( @$auctions, @$cycleauctions );    # Append the cycle auctions to the standard auctions for loading

    if ( scalar( @$auctions ) > 0 ) {

        my $counter = 1;

        foreach my $a ( @$auctions ) {

            send_message( "STATUS:Loading Auctions to Sella: ".$counter." of ".scalar( @$auctions ) );
            send_message( "JOBLOG:Loading auction $a->{ Title } (Record $a->{ AuctionKey })");
            $tm->update_log("AuctionUpload: Loading auction $a->{ Title } (Record $a->{ AuctionKey })");

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

                $tm->update_log("Auction Uploaded to Sella as INACTIVE Auction $newauction");

                $tm->update_auction_record(
                    AuctionKey       =>  $a->{ AuctionKey } ,
                    AuctionStatus    =>  "INACTIVE"         ,
                    AuctionRef       =>  $newauction        ,
                );
            }

            # Test whether the upload has been cancelled
            # Exit the loop BUT NOT THE ENTIRE PROCESS as there is housekeeping to do for the clones

            if ( job_cancelled() ) {
                $tm->update_log( "Sella Auction Upload Cancelled by User" );
                send_message( 'STATUS:Job Cancelled by User Request' );
                send_message( 'JOBLOG:Job Cancelled by User Request' );
                last;
            }
            sleep 1;
            $counter++;
        }
    }
    else {
        $tm->update_log( "No PENDING Sella Auctions found" );
        send_message( "STATUS:No PENDING Sella Auctions found" );
        send_message( "JOBLOG:No PENDING Sella Auctions found" );
    }

    # Housekeeping for any clones that have been created but not loaded

    if ( scalar( @clonekeys) > 0 ) {
        foreach my $clonekey ( @clonekeys ) {
            my $clonedata = $tm->get_auction_record( $clonekey );
            if ( $clonedata->{ AuctionStatus } eq "PENDING" ) {
                $tm->delete_auction_record( $clonekey );
                $tm->update_log("Deleted Cloned Auction $clonedata->{ AuctionTitle } (Record $clonekey) - Auction did not load to Sella");
                send_message( "JOBLOG:Deleted Cloned Auction $clonedata->{ AuctionTitle } (Record $clonekey) - Auction did not load to Sella" );
            }
        }
    }
    send_message( 'JOBEND' );   # Signal End of job
    wait_for_ok_to_end();
}

sub activate_sella {

    my $p = { @_ };

    send_message( 'JOBSTART' );
    send_message( 'Starting job '.$p->{ Jobname } );

    # Connect to the Auctionitis object

    $tm = Auctionitis->new();
    $tm->initialise( Product => "Auctionitis" );
    $tm->update_log("Invoked Method: ".( caller(0) )[3] ); 

    if ( not defined( $tm->{ SellaEmail } ) ) {
        $tm->update_log( 'Sella Log-in Name not defined - request cannot be processed' );
        send_message( 'JOBLOG:Sella Log-in Name not defined - request cannot be processed' );
        send_message( 'STATUS:Sella Log-in Name not defined - request cannot be processed' );
        send_message( 'JOBEND' );   # Signal End of job
        wait_for_ok_to_end();
        return;
    }

    if ( not defined( $tm->{ SellaPassword } ) ) {
        $tm->update_log( 'Sella Password not defined - request cannot be processed' );
        send_message( 'JOBLOG:Sella Password not defined - request cannot be processed' );
        send_message( 'STATUS:Sella Password not defined - request cannot be processed' );
        send_message( 'JOBEND' );   # Signal End of job
        wait_for_ok_to_end();
        return;
    }

    my $dbok = $tm->DBconnect();

    if ( not $dbok ) {
        $tm->update_log( 'Database not found or does not exist' );
        send_message( 'JOBLOG:Database not found or does not exist' );
        send_message( 'STATUS:Database not found or does not exist' );
        send_message( 'JOBEND' );   # Signal End of job
        wait_for_ok_to_end();
        return;
    }

    $tm->update_log("Connecting to Sella");
    $tm->connect_to_sella();

    # if login was not OK update error structure and return

    if ( $tm->{ ErrorStatus } ) {
        send_message( 'ERROR:'.$tm->{ ErrorMessage } );
        send_message( 'JOBEND' );   # Signal End of job
        wait_for_ok_to_end();
        return;
    }    

    my $day = ( localtime )[6];             # Day value is 0 based 
    $tm->set_Schedule_properties( $day );
    
    # Clone auctions for Upload
    
    if ( $tm->{ LoadAll } or $tm->{ LoadCycle }  ) {

        $tm->update_log( "Started: Activate all INACTIVE auctions on Sella" );
    
        my $listings = $tm->sella_api_listing_get_ids_by_status( Status => 'draft' );
    
        if ( scalar( @$listings ) > 0 ) {
    
            my $counter = 1;
    
            foreach my $auctionref ( @$listings ) {
    
                send_message( "STATUS:Activating Sella Listings: ".$counter." of ".scalar( @$listings ) );
    
                if ( not $tm->is_DBauction_104( $auctionref )  ) {
                    send_message( "JOBLOG:Sella Auction reference $auctionref not found in Auction database - not activated" );
                    next;
                }
    
                send_message( "JOBLOG:Activating Auction Reference $auctionref on Sella - ".$counter." of ".scalar( @$listings ) );
                $tm->update_log( "Activating Auction Reference $auctionref on Sella - ".$counter." of ".scalar( @$listings ) );
    
                # Activate the auction
    
                $tm->sella_activate_listing( AuctionRef   =>  $auctionref );
    
                # Update the Auction Database STatus to CURRENT
    
                $tm->update_auction_record(
                    AuctionKey       =>  $tm->get_auction_key( $auctionref )    ,
                    AuctionStatus    =>  "CURRENT"                           ,
                );
    
                # Test whether the upload has been cancelled
                # Exit the loop BUT NOT THE ENTIRE PROCESS as there is housekeeping to do for the clones
    
                if ( job_cancelled() ) {
                    send_message( 'STATUS:Job Cancelled by User Request' );
                    send_message( 'JOBLOG:Job Cancelled by User Request' );
                    $tm->update_log( "Sella Auction Upload Cancelled by User" );
                    last;
                }
                sleep 1;
                $counter++;
            }
        }
        else {
            $tm->update_log( "No INACTIVE Sella Auctions found" );
            send_message( "STATUS:No INACTIVE Sella Auctions found" );
            send_message( "JOBLOG:No INACTIVE Sella Auctions found" );
        }
    
        $tm->update_log( "Completed: Activate all INACTIVE auctions on Sella" );
    }

    send_message( 'JOBEND' );   # Signal End of job
    wait_for_ok_to_end();
}

sub relist_sella {

    my $p = { @_ };

    send_message( 'JOBSTART' );
    send_message( 'Starting job '.$p->{ Jobname } );

    # Connect to the Auctionitis object

    $tm = Auctionitis->new();
    $tm->initialise( Product => "Auctionitis" );
    $tm->update_log("Invoked Method: ".( caller(0) )[3] ); 

    if ( not defined( $tm->{ SellaEmail } ) ) {
        $tm->update_log( 'Sella Log-in Name not defined - request cannot be processed' );
        send_message( 'JOBLOG:Sella Log-in Name not defined - request cannot be processed' );
        send_message( 'STATUS:Sella Log-in Name not defined - request cannot be processed' );
        send_message( 'JOBEND' );   # Signal End of job
        wait_for_ok_to_end();
        return;
    }

    if ( not defined( $tm->{ SellaPassword } ) ) {
        $tm->update_log( 'Sella Password not defined - request cannot be processed' );
        send_message( 'JOBLOG:Sella Password not defined - request cannot be processed' );
        send_message( 'STATUS:Sella Password not defined - request cannot be processed' );
        send_message( 'JOBEND' );   # Signal End of job
        wait_for_ok_to_end();
        return;
    }

    my $dbok = $tm->DBconnect();

    if ( not $dbok ) {
        $tm->update_log( 'Database not found or does not exist' );
        send_message( 'JOBLOG:Database not found or does not exist' );
        send_message( 'STATUS:Database not found or does not exist' );
        send_message( 'JOBEND' );   # Signal End of job
        wait_for_ok_to_end();
        return;
    }

    $tm->update_log("Connecting to Sella");
    $tm->connect_to_sella();

    # if login was not OK update error structure and return

    if ( $tm->{ ErrorStatus } ) {
        send_message( 'ERROR:'.$tm->{ ErrorMessage } );
        send_message( 'JOBEND' );   # Signal End of job
        wait_for_ok_to_end();
        return;
    }    

    my $day = ( localtime )[6];             # Day value is 0 based 
    $tm->set_Schedule_properties( $day );

    if ( $tm->{ RelistAll } ) {

        # Process auctions elgible for relists
    
        $tm->update_log( "Started: Relist Elegible SELLA Auctions" );
    
        my $auctions = $tm->get_relist_auctions( AuctionSite => "SELLA" );
    
        if ( scalar( @$auctions ) > 0 ) {
    
            my $counter = 1;
    
            foreach my $a ( @$auctions ) {
    
                send_message( "JOBLOG:Relisting Auction Reference $a->{ AuctionRef } on Sella - ".$counter." of ".scalar( @$auctions ) );
                $tm->update_log( "Relisting Auction Reference $a->{ AuctionRef } on Sella - ".$counter." of ".scalar( @$auctions ) );
    
                # Relist the auction
    
                my $newauction = $tm->relist_sella_auction( AuctionRef => $a->{ AuctionRef } );

                if ( not defined $newauction ) {
                    send_message( "JOBLOG:Auction $a->{ AuctionRef } not relisted" );
                    $tm->update_log( "Error relisting Auction $a->{ AuctionRef } on Sella" );
                }
                else {

                    $tm->update_log( "Auction $a->{ AuctionRef } relisted on Sella as $newauction" );

                    # Create a new auction record by copying the old record and updating the required details

                    my $message = "Auction relisted from auction ".$a->{ AuctionRef };

                    my ( $closetime, $closedate );

                    if ( $a->{ EndType } eq "DURATION" ) {

                        $closedate = $tm->closedate( $a->{ DurationHours } );
                        $closetime = $tm->closetime( $a->{ DurationHours } );
                    }

                    if ( $a->{ EndType } eq "FIXEDEND" ) {

                        $closedate = $tm->fixeddate( $a->{ EndDays } );
                        $closetime = $tm->fixedtime( $a->{ EndTime } );
                    }

                    $tm->copy_auction_record(
                        AuctionKey       =>  $a->{ AuctionKey }                    ,
                        AuctionStatus    =>  "CURRENT"                             ,
                        AuctionRef       =>  $newauction                           ,
                        AuctionSold      =>  0                                     ,
                        OfferProcessed   =>  0                                     ,
                        RelistStatus     =>  $a->{ RelistStatus }                  ,
                        DateLoaded       =>  $tm->datenow()                        ,
                        CloseDate        =>  $closedate                            ,
                        CloseTime        =>  $closetime                            ,
                        Message          =>  $message                              ,
                    );

                    # Delete from Auctionitis if delete from database flag set to True, otherwise update existing record 

                    if  ( $tm->{ RelistDBDelete } ) {

                        $tm->delete_auction_record(
                            AuctionKey          =>  $a->{ AuctionKey }      ,
                        );
                        $tm->update_log( "Auction $a->{ AuctionRef}  (record $a->{ AuctionKey }) deleted from Auctionitis database" );

                    }
                    else {

                        $message = "Auction relisted as $newauction";
                        $tm->update_auction_record(
                            AuctionKey           =>  $a->{AuctionKey}       ,
                            AuctionStatus        =>  "RELISTED"             ,
                            Message              =>  $message               ,
                        );
                    }
                }
                
                # Test whether the upload has been cancelled
                # Exit the loop BUT NOT THE ENTIRE PROCESS as there is housekeeping to do for the clones
    
                if ( job_cancelled() ) {
                    send_message( 'STATUS:Job Cancelled by User Request' );
                    send_message( 'JOBLOG:Job Cancelled by User Request' );
                    $tm->update_log( "Sella Auction Upload Cancelled by User" );
                    last;
                }
                sleep 1;
                $counter++;
            }
        }
        else {
            $tm->update_log( "No Sella Auctions requiring relist found" );
            send_message( "STATUS:No Sella Auctions requiring relist found" );
            send_message( "JOBLOG:No Sella Auctions requiring relist found" );
        }

        $tm->update_log( scalar( @$auctions )." found for relist processing" );
        $tm->update_log( "Completed: Relist Elegible SELLA Auctions" );

    }

    $tm->DBdisconnect();                                        # disconnect from the database

    send_message( 'JOBEND' );   # Signal End of job
    wait_for_ok_to_end();
}

#=============================================================================================
# category_update
#=============================================================================================

sub update_categories {

    my $p = { @_ };

    send_message( 'JOBSTART' );
    send_message( 'Starting job '.$p->{ Jobname } );

    $tm = Auctionitis->new();
    $tm->initialise(Product => "Auctionitis");  # Initialise the product
    $tm->update_log("Invoked Method: ".( caller(0) )[3] ); 

    my $dbok = $tm->DBconnect();

    if ( not $dbok ) {
        $tm->update_log( 'Database not found or does not exist' );
        send_message( 'JOBLOG:Database not found or does not exist' );
        send_message( 'STATUS:Database not found or does not exist' );
        send_message( 'JOBEND' );   # Signal End of job
        wait_for_ok_to_end();
        return;
    }

    # Retrieve the category service dates and compare them;
    # If they are not the same, perform a category update

    if ( $tm->get_local_service_date() ne $tm->get_remote_service_date() ) {

        send_message( 'JOBLOG:Category Update Required' );
        send_message( 'JOBLOG:Local Category Service Date: '.$tm->get_local_service_date() );
        send_message( 'JOBLOG:Remote Category Service Date: '.$tm->get_remote_service_date() );
        send_message( 'STATUS:Performing Category Update' );

        # Reload the category table
    
        $tm->clear_category_table();
        
        my $categories = $tm->get_remote_category_table();

        # Save the old autocommit value and then explicitly set autocommit off.

        my $oldcommitval = $tm->{ DBH }->{ AutoCommit  };
        $tm->{ DBH }->{ AutoCommit  } = 0;

        foreach my $record ( @$categories ) {
    
            $tm->update_log("Adding Category:\t".$record->{ Category }."\t(".$record->{Description}.")");
    
            $tm->insert_category_record(
                Description     => $record->{ Description     },
                Category        => $record->{ Category        },
                Parent          => $record->{ Parent          },
                Sequence        => $record->{ Sequence        },
            );
        }

        # Commit the changes to the database & Restore the Autocommit property to its previous value

        $tm->{ DBH }->commit();
        $tm->{ DBH }->{ AutoCommit  } = $oldcommitval;

        # Task 2 - Get Service dates
    
        $tm->update_log( "Checking for Category Service Updates; Local Service Date: ".$tm->get_local_service_date() );
    
        my $servicedates = $tm->get_service_dates( $tm->get_local_service_date() );
    
        # Process Service updates
    
        foreach my $record ( @$servicedates ) {
     
            send_message( "JOBLOG:Processing Service Update data for : ".$record->{ ServiceDate } );
            $tm->update_log( "Processing Service Update data for : ".$record->{ ServiceDate } );
            $tm->update_log( "Retrieving Service Update data from: ".$record->{ ServiceURL  } );

            my $retries = 0;
            my $mapdata;

            while ( $retries lt 5 ) {

                $mapdata = $tm->get_remapping_data( $record->{ ServiceURL } );
        
                if ( $tm->{ ErrorStatus } ) {
                    $retries++;
                    sleep 3;

                    if ( $retries eq 5 ) {
                        send_message( 'JOBLOG:'.$tm->{ ErrorMessage } );
                        $tm->update_log( $tm->{ ErrorMessage } );
                        send_message( 'JOBEND' );   # Signal End of job
                        wait_for_ok_to_end();
                        return;
                    }
                }
                else {
                    $retries = 5;
                }
            }
    
            foreach my $update ( @$mapdata ) {
                send_message( "JOBLOG:Converting: ".$update->{ OldCategory }."->".$update->{ NewCategory }."\t(".$update->{ Description }.")" );
                $tm->update_log( "Converting: ".$update->{ OldCategory }."->".$update->{ NewCategory }."\t(".$update->{ Description }.")" );
                $tm->convert_category( $update->{ OldCategory }, $update->{ NewCategory });
            }
        }
    
        # Get Category Readme document
        
        my $FH;
        my $readmefile = $tm->{ DataDirectory }."\\readme.txt";
        my $readmedata = $tm->get_category_readme();

        my $retries = 1;

        if ( $tm->{ ErrorStatus } ) {
            $retries++;
            sleep 3;

            if ( $retries eq 5 ) {
                send_message( 'JOBLOG:Could not retrieve Category ReadMe file' );
                $tm->update_log( 'Could not retrieve Category ReadMe file' );
            }
        }
        else {
            unlink $readmefile;
            open( $FH, "> $readmefile" );
            print $FH $readmedata;
        }

        # Update Category Service Data in database

        $tm->set_DB_property(
            Property_Name       =>  "CategoryServiceDate"           ,
            Property_Default    =>  $tm->get_remote_service_date()  ,
        );
    }

    $tm->DBdisconnect();        # disconnect from the database
    send_message( 'JOBEND' );   # Signal End of job
    wait_for_ok_to_end();
}

#=============================================================================================
# update_db
#=============================================================================================

sub update_db {

    my $p = { @_ };

    send_message( 'JOBSTART' );
    send_message( 'Starting job '.$p->{ Jobname } );

    my ( $current, $sold, $unsold, $closed, $items, $open );

    $tm = Auctionitis->new();
    $tm->initialise(Product => "Auctionitis");  # Initialise the product
    $tm->update_log("Invoked Method: ".( caller(0) )[3] ); 

    if ( not defined( $tm->{ TradeMeID } ) ) {
        $tm->update_log( 'TradeMe ID not defined - request cannot be processed' );
        send_message( 'JOBLOG:TradeMe ID not defined - request cannot be processed' );
        send_message( 'STATUS:TradeMe ID not defined - request cannot be processed' );
        send_message( 'JOBEND' );   # Signal End of job
        wait_for_ok_to_end();
        return;
    }

    if ( not defined( $tm->{ UserID } ) ) {
        $tm->update_log( 'Trade Me Account Name not defined - request cannot be processed' );
        send_message( 'JOBLOG:Trade Me Account Name not defined - request cannot be processed' );
        send_message( 'STATUS:Trade Me Account Name not defined - request cannot be processed' );
        send_message( 'JOBEND' );   # Signal End of job
        wait_for_ok_to_end();
        return;
    }

    if ( not defined( $tm->{ Password } ) ) {
        $tm->update_log( 'Trade Me Account Password not defined - request cannot be processed' );
        send_message( 'JOBLOG:Trade Me Account Password not defined - request cannot be processed' );
        send_message( 'STATUS:Trade Me Account Password not defined - request cannot be processed' );
        send_message( 'JOBEND' );   # Signal End of job
        wait_for_ok_to_end();
        return;
    }

    my $dbok = $tm->DBconnect();

    if ( not $dbok ) {
        $tm->update_log( 'Database not found or does not exist' );
        send_message( 'JOBLOG:Database not found or does not exist' );
        send_message( 'STATUS:Database not found or does not exist' );
        send_message( 'JOBEND' );   # Signal End of job
        wait_for_ok_to_end();
        return;
    }
    
    $tm->login();

    if ( $tm->{ ErrorMessage } ) {
        send_message( 'JOBLOG:'.$tm->{ ErrorMessage } );
        send_message( 'STATUS:'.$tm->{ ErrorMessage } );
        send_message( 'JOBEND' );
        wait_for_ok_to_end();
        return;
    }

    $sold = $tm->new_get_sold_listings();

    # Process Sold Auctions

    $tm->update_log( "Started: Update Sold Auctions" );

    _update_sold_auctions( $sold, ) if scalar( $sold ) gt 0;

    $tm->update_log( "Completed: Update Sold Auctions" );

    # Check for job cancellation

    if ( job_cancelled() ) {
        $tm->update_log( "Update Database from Trade Me Cancelled by User" );
        send_message( 'STATUS:Job Cancelled by User Request' );
        send_message( 'JOBLOG:Job Cancelled by User Request' );
        send_message( 'JOBEND' );
        wait_for_ok_to_end();
        return;
    }

    # Process Unsold Auctions

    $tm->update_log( "Started: Update Unsold Auctions" );

    # Get the list of items marked as CURRENT in the database and the items that are current on Trade Me
    # Items in the list of current items from the database that are not in the list of current items on Trade Me
    # are UNSOLD (no longer current but not marked as SOLD)

    # Get list of current listings from Trade Me and converted to a hash keyed on auction number

    $current = $tm->get_current_auctions();
    $tm->update_log( "Retrieved ".scalar( @$current )." CURRENT auction records from TradeMe website" );

    if ( scalar( @$current ) > 0 ) {
        foreach my $a ( @$current ) {
            $open->{ $a->{ AuctionRef } } = 1;
        }
    }

    _update_current_auctions( $current ) if scalar( $current ) gt 0;

    $tm->update_log( "Stored ".scalar( keys %$open )." CURRENT records in hash table" );

    # Get list of current items from database and check whether they appear in the hash just created
    # If not in the hash the items is not current on TradeMe so push it into the Unsold array

    $items = $tm->get_open_listings( AuctionSite =>  'TRADEME' );
    $tm->update_log( "Retrieved ".scalar( @$items )." CURRENT auction records from Auctionitis database" );

    if ( scalar( @$items ) gt 0 ) {
        foreach my $i ( @$items ) {
            push( @$unsold, { AuctionRef => $i->{ AuctionRef } } ) unless $open->{ $i->{ AuctionRef } };
        }
    }

    $tm->update_log( "Updating ".scalar( @$unsold )." auction records with status UNSOLD" );

    _update_unsold_auctions( $unsold ) if scalar( $unsold ) gt 0;

    $tm->update_log( "Completed: Update Unsold Auctions" );
    
    # All Tasks comnpleted - cleanup and return

    $tm->DBdisconnect();                          # disconnect from the database
    $tm->update_log( "Completed: Update DataBase procedure" );
    
    send_message( 'JOBEND' );   # Signal End of job
    wait_for_ok_to_end();
}

#=============================================================================================
#  updatedb_sella
#=============================================================================================

sub update_db_sella {

    my $p = { @_ };

    send_message( 'JOBSTART' );
    send_message( 'Starting job '.$p->{ Jobname } );

    $tm = Auctionitis->new();
    $tm->initialise(Product => "Auctionitis");  # Initialise the product
    $tm->update_log("Invoked Method: ".( caller(0) )[3] ); 

    if ( not defined( $tm->{ SellaEmail } ) ) {
        $tm->update_log( 'Sella Log-in Name not defined - request cannot be processed' );
        send_message( 'JOBLOG:Sella Log-in Name not defined - request cannot be processed' );
        send_message( 'STATUS:Sella Log-in Name not defined - request cannot be processed' );
        send_message( 'JOBEND' );   # Signal End of job
        wait_for_ok_to_end();
        return;
    }

    if ( not defined( $tm->{ SellaPassword } ) ) {
        $tm->update_log( 'Sella Password not defined - request cannot be processed' );
        send_message( 'JOBLOG:Sella Password not defined - request cannot be processed' );
        send_message( 'STATUS:Sella Password not defined - request cannot be processed' );
        send_message( 'JOBEND' );   # Signal End of job
        wait_for_ok_to_end();
        return;
    }

    my $dbok = $tm->DBconnect();

    if ( not $dbok ) {
        $tm->update_log( 'Database not found or does not exist' );
        send_message( 'JOBLOG:Database not found or does not exist' );
        send_message( 'STATUS:Database not found or does not exist' );
        send_message( 'JOBEND' );   # Signal End of job
        wait_for_ok_to_end();
        return;
    }

    $tm->update_log( "Logging in to Sella" );
    $tm->connect_to_sella();
    
    # if login was not OK update error structure and return

    if ( $tm->{ ErrorMessage } ) {
        send_message( 'JOBLOG:'.$tm->{ ErrorMessage } );
        send_message( 'STATUS:'.$tm->{ ErrorMessage } );
        send_message( 'JOBEND' );   # Signal End of job
        wait_for_ok_to_end();
        return;
    }

    # Task 1: Retrieve Sella Auction Data

    $tm->update_log( "Started: Retrieve Sella Auction Data" );

    my $items = $tm->get_open_listings( 
        AuctionSite =>  'SELLA'         ,
    );

    # Get Auction state date for items in the list of open auctions

    my @listings;

    if ( scalar( $items ) > 0 ) {
        foreach my $i ( @$items ) {

            my $state = $tm->sella_get_listing_state( AuctionRef => $i->{ AuctionRef } );

            if ( defined( $state ) ) {
                $state->{ AuctionKey } = $i->{ AuctionKey };

                if ( not $state->{ active } ) {
                    $state->{ CloseDate } = $tm->format_sella_close_date(
                        CloseDate   =>  $state->{ date_closed } ,
                        Format      =>  'DATE'                  ,
                    );
                    $state->{ CloseTime } = $tm->format_sella_close_date(
                        CloseDate   =>  $state->{ date_closed } ,
                        Format      =>  'TIME'                  ,
                    );
                    if ( $state->{ purchased_price } > 0 ) {
                        $state->{ Status } = 'SOLD';
                    }
                    else {
                        $state->{ Status } = 'UNSOLD';
                    }
                    push ( @listings, $state );
                }
            }
        }
    }

    $tm->update_log( "Completed: Retrieve Sella Auction Data" );

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ( job_cancelled() ) {
        $tm->update_log( "Update Database from Sella Cancelled by User" );
        send_message( 'STATUS:Job Cancelled by User Request' );
        send_message( 'JOBLOG:Job Cancelled by User Request' );
        send_message( 'JOBEND' );   # Signal End of job
        wait_for_ok_to_end();
        return;
    }

    # Update Sella Auction Status

    $tm->update_log( "Started: Update Sella Auction Status" );

    if ( scalar( @listings ) > 0 ) {

        my $counter = 1;

        # Save the old autocommit value and then explicitly set autocommit off.

        my $oldcommitval = $tm->{ DBH }->{ AutoCommit  };
        $tm->{ DBH }->{ AutoCommit  } = 0;

        foreach my $l ( @listings ) {

            my $r = $tm->get_auction_record( $l->{ AuctionKey } );

            send_message( "STATUS:Updating auction ".$r->{ AuctionRef }." [$l->{ Status }]: ".$r->{ Title } );
            send_message( "JOBLOG:Updating auction ".$r->{ AuctionRef }." [$l->{ Status }]: ".$r->{ Title } );

            $tm->update_log( "Updating auction ".$r->{ AuctionRef }." [$l->{ Status }]: ".$r->{ Title } );

            # Check if the auction has finished and if it has mark it sold or unsold based
            # on whether there is a purchase price greater than 0

            if ( $l->{ Status } eq 'SOLD' ) {

                # If auction has status of CURRENT Decrement StockOnHand if StockOnHand > 0 
                # The Status test is to ensure the stock is only reduced once

                if ( $r->{ AuctionStatus } eq 'CURRENT' ) {
                    if ( $r->{ StockOnHand } > 0 )   { 
                        $r->{ StockOnHand }--; 
                        if (  $r->{ ProductCode } ne '' ) {
                            $tm->update_stock_on_hand(
                                ProductCode =>  $r->{ ProductCode } ,
                                StockOnHand =>  $r->{ StockOnHand } ,
                            );
                        }
                    }
                }

                $tm->update_log("Updating: AuctionKey       $l->{ AuctionKey }  ");
                $tm->update_log("          AuctionStatus    SOLD                ");
                $tm->update_log("          StockOnHand      $r->{ StockOnHand } ");
                $tm->update_log("          CloseDate        $l->{ CloseDate }   ");
                $tm->update_log("          CloseTime        $l->{ CloseTime }   ");

                $tm->update_auction_record(
                    AuctionKey      =>  $l->{ AuctionKey }     ,
                    AuctionStatus   =>  'SOLD'                 ,
                    AuctionSold     =>  1                      ,
                    StockOnHand     =>  $r->{ StockOnHand }    ,
                    CloseDate       =>  $l->{ CloseDate }      ,
                    CloseTime       =>  $l->{ CloseTime }      ,
                );
            }
            elsif ( $l->{ Status } eq 'UNSOLD' ) {
    
                $tm->update_log("Updating: AuctionKey       $l->{ AuctionKey }  ");
                $tm->update_log("          AuctionStatus    UNSOLD              ");
                $tm->update_log("          CloseDate        $l->{ CloseDate }   ");
                $tm->update_log("          CloseTime        $l->{ CloseTime }   ");

                $tm->update_auction_record(
                    AuctionKey      =>  $l->{ AuctionKey }     ,
                    AuctionStatus   =>  'UNSOLD'               ,
                    AuctionSold     =>  0                      ,
                    CloseDate       =>  $l->{ CloseDate }      ,
                    CloseTime       =>  $l->{ CloseTime }      ,
                );
            }
            $counter++;
        }

        # Commit the changes to the database & Restore the Autocommit property to 

        $tm->{ DBH }->commit();
        $tm->{ DBH }->{ AutoCommit  } = $oldcommitval;
    }

    $tm->update_log("Completed: Update Sella Auction Status");

    # All Tasks comnpleted - cleanup and return

    $tm->DBdisconnect();                          # disconnect from the database

    $tm->update_log("Completed: Update DataBase procedure");
    
    send_message( 'JOBEND' );   # Signal End of job
    wait_for_ok_to_end();
}

#=============================================================================================
# offer_trademe
#=============================================================================================

sub offer_trademe {

    my $p = { @_ };

    send_message( 'JOBSTART' );
    send_message( 'Starting job '.$p->{ Jobname } );

    my ( $current, $sold, $unsold, $closed, $items, $open );

    $tm = Auctionitis->new();
    $tm->initialise(Product => "Auctionitis");  # Initialise the product
    $tm->update_log("Invoked Method: ".( caller(0) )[3] ); 

    if ( not defined( $tm->{ TradeMeID } ) ) {
        $tm->update_log( 'TradeMe ID not defined - request cannot be processed' );
        send_message( 'JOBLOG:TradeMe ID not defined - request cannot be processed' );
        send_message( 'STATUS:TradeMe ID not defined - request cannot be processed' );
        send_message( 'JOBEND' );   # Signal End of job
        wait_for_ok_to_end();
        return;
    }

    if ( not defined( $tm->{ UserID } ) ) {
        $tm->update_log( 'Trade Me Account Name not defined - request cannot be processed' );
        send_message( 'JOBLOG:Trade Me Account Name not defined - request cannot be processed' );
        send_message( 'STATUS:Trade Me Account Name not defined - request cannot be processed' );
        send_message( 'JOBEND' );   # Signal End of job
        wait_for_ok_to_end();
        return;
    }

    if ( not defined( $tm->{ Password } ) ) {
        $tm->update_log( 'Trade Me Account Password not defined - request cannot be processed' );
        send_message( 'JOBLOG:Trade Me Account Password not defined - request cannot be processed' );
        send_message( 'STATUS:Trade Me Account Password not defined - request cannot be processed' );
        send_message( 'JOBEND' );   # Signal End of job
        wait_for_ok_to_end();
        return;
    }

    my $dbok = $tm->DBconnect();

    if ( not $dbok ) {
        $tm->update_log( 'Database not found or does not exist' );
        send_message( 'JOBLOG:Database not found or does not exist' );
        send_message( 'STATUS:Database not found or does not exist' );
        send_message( 'JOBEND' );   # Signal End of job
        wait_for_ok_to_end();
        return;
    }
    
    $tm->login();

    if ( $tm->{ ErrorMessage } ) {
        send_message( 'JOBLOG:'.$tm->{ ErrorMessage } );
        send_message( 'STATUS:'.$tm->{ ErrorMessage } );
        send_message( 'JOBEND' );   # Signal End of job
        wait_for_ok_to_end();
        return;
    }

    my $day = ( localtime )[6];             # Day value is 0 based 
    $tm->set_Schedule_properties( $day );

    if ( $tm->{ OfferAll } ) {
    
        # process all Eligible Offers
    
        $tm->update_log("Started: Process All Offers");
        
        # Get the list auctions to be offered from the database
        # Select list type based on what kind of offers have been selected
    
        my $offers;
    
        if ( ( $tm->{ OfferSold } eq "1" ) and ( $tm->{ OfferUnsold } eq "1" ) ) {
            $offers = $tm->get_pending_offers( "ALL" );
        }
    
        if ( ( $tm->{ OfferSold } eq "1" ) and ( $tm->{ OfferUnsold } eq "0" ) ) {
            $offers = $tm->get_pending_offers( "SOLD" );
        }
    
        if ( ( $tm->{ OfferSold } eq "0" ) and ( $tm->{ OfferUnsold } eq "1" ) ) {
            $offers = $tm->get_pending_offers( "UNSOLD" );
        }
    
        $tm->update_log( scalar( @$offers )." Pending Offers Retrieved from database" );
    
        # If offers were retrieved from the database then process them
    
        if ( scalar( @$offers ) gt 0 ) {
    
            my $counter     =   1;
    
            send_message( "STATUS:Trade Me Offer Processing ".$counter.' of '.scalar( @$offers ) );
            send_message( "JOBLOG:Offer Processing for Auction $a->{ AuctionRef } - $a->{ Title } (Record $a->{ AuctionKey }) - ".$counter.' of '.scalar( @$offers ) );
    
            $tm->update_log( "Settings for Offer Processing" );
            $tm->update_log( "-----------------------------" );
            $tm->update_log( "OfferDuration       : ".$tm->{ OfferDuration         } );
            $tm->update_log( "OfferHighBid        : ".$tm->{ OfferHighBid          } );
            $tm->update_log( "OfferAV             : ".$tm->{ OfferAV               } );
            $tm->update_log( "OfferWatchers       : ".$tm->{ OfferWatchers         } );
            $tm->update_log( "OfferBidders        : ".$tm->{ OfferBidders          } );
            $tm->update_log( "OfferAuthenticated  : ".$tm->{ OfferAuthenticated    } );
            $tm->update_log( "OfferFeedbackMinimum: ".$tm->{ OfferFeedbackMinimum  } );
    
            foreach my $o ( @$offers ) {
    
                # If Status is not sold or unsold log message and move to next record
    
                unless ( ( $o->{ AuctionStatus } eq 'SOLD'   ) or ( $o->{ AuctionStatus } eq 'UNSOLD' ) ) {
                    send_message( "JOBLOG:Auction ".$o->{ Title }." (Record ".$o->{ AuctionKey }.") not Offered - Invalid Auction Status" );
                    $tm->update_log( "Auction ".$o->{ Title }." Record ".$o->{ AuctionKey }." not Offered - Invalid Auction Status" );
                    $counter++;
                    next;
                }
    
                # If record has no offer amount log message and move to next record
    
                unless ( $o->{ OfferPrice } > 0 ) {
                    send_message( "JOBLOG:Auction ".$o->{ Title }." Record ".$o->{ AuctionKey }." not Offered - No Offer price specified" );
                    $tm->update_log( "Auction ".$o->{ Title }." Record ".$o->{ AuctionKey }." not Offered - No Offer price specified" );
                    $counter++;
                    next;
                }
    
                my $offer = $tm->make_offer(
                    AuctionRef          => $o->{ AuctionRef             } ,
                    OfferPrice          => $o->{ OfferPrice             } ,
                    OfferDuration       => $tm->{ OfferDuration         } ,
                    UseHighestBid       => $tm->{ OfferHighBid          } ,
                    AVOnly              => $tm->{ OfferAV               } ,
                    OfferWatchers       => $tm->{ OfferWatchers         } ,
                    OfferBidders        => $tm->{ OfferBidders          } ,
                    AuthenticatedOnly   => $tm->{ OfferAuthenticated    } ,
                    FeedbackMinimum     => $tm->{ OfferFeedbackMinimum  } ,
                );
    
                $tm->add_offer_record(
                    Offer_Date          => $tm->datenow()                 ,
                    AuctionRef          => $o->{ AuctionRef             } ,
                    Offer_Amount        => $o->{ OfferAmount            } ,
                    Offer_Duration      => $tm->{ OfferDuration         } ,
                    Highest_Bid         => $offer->{ HighBid            } ,
                    Offer_Reserve       => $offer->{ Reserve            } ,
                    Actual_Offer        => $offer->{ OfferPrice         } ,
                    Bidder_Count        => $offer->{ BidderCount        } ,
                    Watcher_Count       => $offer->{ WatcherCount       } ,
                    Offer_Count         => $offer->{ OfferCount         } ,
                    Offer_Type          => $o->{ AuctionStatus          } ,
                    Offer_Successful    => 0                              ,
                );
    
                $tm->update_auction_record(
                    AuctionKey           =>  $o->{ AuctionKey           } ,
                    OfferProcessed       =>  1                            ,
                );
                sleep 2;
                $counter++;
    
                # Test whether the upload has been cancelled
                # Exit the loop BUT NOT THE ENTIRE PROCESS as there is housekeeping to do for the clones
    
                if ( job_cancelled() ) {
                    $tm->update_log( "Trade Me Offer process Cancelled by User" );
                    send_message( 'STATUS:Job Cancelled by User Request' );
                    send_message( 'JOBLOG:Job Cancelled by User Request' );
                    last;
                }
            }
        }
    
        $tm->update_log("Completed: Process All Offers");
    }

    $tm->DBdisconnect();                          # disconnect from the database
    
    send_message( 'JOBEND' );   # Signal End of job
    wait_for_ok_to_end();
}

#=============================================================================================
# load_trademe
#=============================================================================================

sub load_trademe {

    my $p = { @_ };
    my @clonekeys;

    send_message( 'JOBSTART' );
    send_message( 'Starting job '.$p->{ Jobname } );

    $tm = Auctionitis->new();
    $tm->initialise( Product => "Auctionitis" );                # Initialise the product
    $tm->update_log( "Invoked Method: ".( caller(0) )[3] ); 

    if ( not defined( $tm->{ TradeMeID } ) ) {
        $tm->update_log( 'TradeMe ID not defined - request cannot be processed' );
        send_message( 'JOBLOG:TradeMe ID not defined - request cannot be processed' );
        send_message( 'STATUS:TradeMe ID not defined - request cannot be processed' );
        send_message( 'JOBEND' );   # Signal End of job
        wait_for_ok_to_end();
        return;
    }

    if ( not defined( $tm->{ UserID } ) ) {
        $tm->update_log( 'Trade Me Account Name not defined - request cannot be processed' );
        send_message( 'JOBLOG:Trade Me Account Name not defined - request cannot be processed' );
        send_message( 'STATUS:Trade Me Account Name not defined - request cannot be processed' );
        send_message( 'JOBEND' );   # Signal End of job
        wait_for_ok_to_end();
        return;
    }

    if ( not defined( $tm->{ Password } ) ) {
        $tm->update_log( 'Trade Me Account Password not defined - request cannot be processed' );
        send_message( 'JOBLOG:Trade Me Account Password not defined - request cannot be processed' );
        send_message( 'STATUS:Trade Me Account Password not defined - request cannot be processed' );
        send_message( 'JOBEND' );   # Signal End of job
        wait_for_ok_to_end();
        return;
    }

    my $dbok = $tm->DBconnect();

    if ( not $dbok ) {
        $tm->update_log( 'Database not found or does not exist' );
        send_message( 'JOBLOG:Database not found or does not exist' );
        send_message( 'STATUS:Database not found or does not exist' );
        send_message( 'JOBEND' );   # Signal End of job
        wait_for_ok_to_end();
        return;
    }

    # Determine day of week and set appropriate schedule values

    my $day = ( localtime )[6];             # Day value is 0 based 
    $tm->set_Schedule_properties( $day );

    if ( $tm->{ LoadAll } ) {

        # Clone auctions with no cycle

        $tm->update_log("Started: Clone Auctions for upload");

        my $clones  =   $tm->get_clone_auctions( AuctionSite => "TRADEME" );
        my $counter =   0;

        foreach my $clone ( @$clones ) {

            my $newkey = $tm->copy_auction_record(
                AuctionKey       =>  $clone->{ AuctionKey } ,
                AuctionStatus    =>  "PENDING"              ,
            );
    
            push ( @clonekeys, $newkey );    # Store the key of the new clone record
    
            $tm->update_log( "Cloned Auction $clone->{ AuctionTitle } (Record $clone->{ AuctionTitle })" );
    
            $counter++;
        }
        $tm->update_log("Completed: Clone Auctions for upload");
    }
    
    if ( $tm->{ LoadCycle } ) {

        # Clone auctions with a cycle spcified

        $tm->update_log("Started: Clone Auctions for Auction Cycle ".$tm->{ LoadCycleName });

        my $clones = $tm->get_clone_auctions(
            AuctionSite     => "TRADEME"                ,
            AuctionCycle    => $tm->{ LoadCycleName }   ,
        );

        foreach my $clone ( @$clones ) {

                my $newkey = $tm->copy_auction_record(
                    AuctionKey       =>  $clone->{ AuctionKey } ,
                    AuctionStatus    =>  "PENDING"              ,
                );

                push ( @clonekeys, $newkey );    # Store the key of the new clone record

                $tm->update_log("Cloned Auction $clone->{AuctionTitle} (Record $clone->{auctionTitle})");
        }
        $tm->update_log("Completed: Clone Auctions for Auction Cycle ".$tm->{ LoadCycleName });
    }

    if ( $tm->{ LoadAll } or $tm->{ LoadCycle } ) {

        # load all the pending auctions

        $tm->update_log( "Started: Load all Pending auctions" );

        $tm->login();

        if ( $tm->{ ErrorMessage } ) {
            send_message( 'JOBLOG:'.$tm->{ ErrorMessage } );
            send_message( 'STATUS:'.$tm->{ ErrorMessage } );
            send_message( 'JOBEND' );   # Signal End of job
            wait_for_ok_to_end();
            return;
        }

        my ( $auctions, $cycleauctions );

        $auctions = $tm->get_pending_auctions( AuctionSite =>  "TRADEME" ) if $tm->{ LoadAll };

        if ( $tm->{ LoadCycle } ) {
            $cycleauctions   =  $tm->get_cycle_auctions(
                AuctionSite     =>  "TRADEME"               ,
                AuctionCycle    =>  $tm->{ LoadCycleName }  ,
            )  ;
        }

        push( @$auctions, @$cycleauctions );    # Append the cycle auctions to the standard auctions for loading

        _auction_upload( $auctions ) if scalar( @$auctions ) gt 0;

        $tm->update_log("Completed: Load all Pending auctions");
    }

    # Housekeeping for any clones that have been created but not loaded

    if ( scalar( @clonekeys ) > 0 ) {

        foreach my $clonekey ( @clonekeys ) {

            my $clonedata = $tm->get_auction_record( $clonekey );
            
            if ( $clonedata->{ AuctionStatus } eq "PENDING" ) {
                $tm->delete_auction_record( $clonekey );
                $tm->update_log("Deleted Cloned Auction $clonedata->{ AuctionTitle } (Record $clonekey) - Aution did not load");
            }
        }
    }

    # All Tasks completed

    $tm->DBdisconnect();                          # disconnect from the database
    
    send_message( 'JOBEND' );   # Signal End of job
    wait_for_ok_to_end();
}

#=============================================================================================
# relist_trademe
#=============================================================================================

sub relist_trademe {

    $tm = Auctionitis->new();
    $tm->initialise(Product => "Auctionitis");  # Initialise the product
    $tm->update_log("Invoked Method: ".( caller(0) )[3] ); 

    if ( not defined( $tm->{ TradeMeID } ) ) {
        $tm->update_log( 'TradeMe ID not defined - request cannot be processed' );
        send_message( 'JOBLOG:TradeMe ID not defined - request cannot be processed' );
        send_message( 'STATUS:TradeMe ID not defined - request cannot be processed' );
        send_message( 'JOBEND' );   # Signal End of job
        wait_for_ok_to_end();
        return;
    }

    if ( not defined( $tm->{ UserID } ) ) {
        $tm->update_log( 'Trade Me Account Name not defined - request cannot be processed' );
        send_message( 'JOBLOG:Trade Me Account Name not defined - request cannot be processed' );
        send_message( 'STATUS:Trade Me Account Name not defined - request cannot be processed' );
        send_message( 'JOBEND' );   # Signal End of job
        wait_for_ok_to_end();
        return;
    }

    if ( not defined( $tm->{ Password } ) ) {
        $tm->update_log( 'Trade Me Account Password not defined - request cannot be processed' );
        send_message( 'JOBLOG:Trade Me Account Password not defined - request cannot be processed' );
        send_message( 'STATUS:Trade Me Account Password not defined - request cannot be processed' );
        send_message( 'JOBEND' );   # Signal End of job
        wait_for_ok_to_end();
        return;
    }

    my $dbok = $tm->DBconnect();

    if ( not $dbok ) {
        $tm->update_log( 'Database not found or does not exist' );
        send_message( 'JOBLOG:Database not found or does not exist' );
        send_message( 'STATUS:Database not found or does not exist' );
        send_message( 'JOBEND' );   # Signal End of job
        wait_for_ok_to_end();
        return;
    }
    
    $tm->login();

    if ( $tm->{ ErrorMessage } ) {
        send_message( 'JOBLOG:'.$tm->{ ErrorMessage } );
        send_message( 'STATUS:'.$tm->{ ErrorMessage } );
        send_message( 'JOBEND' );   # Signal End of job
        wait_for_ok_to_end();
        return;
    }

    my $day = ( localtime )[6];             # Day value is 0 based 
    $tm->set_Schedule_properties( $day );

    if ( $tm->{ RelistAll } ) {

        # Process auctions elgible for relists
    
        $tm->update_log( "Started: Relist Elegible Auctions" );
    
        my $auctions = $tm->get_relist_auctions( AuctionSite => "TRADEME" );
    
        _auction_relist( $auctions ) if scalar( @$auctions ) gt 0;

        $tm->update_log( scalar( @$auctions )." found for relist processing" );
        $tm->update_log( "Completed: Relist Elegible Auctions" );

    }

    $tm->DBdisconnect();                                        # disconnect from the database
    
    send_message( 'JOBEND' );   # Signal End of job
    wait_for_ok_to_end();
}

#=============================================================================================
# _update_sold_auctions - Perform specific updates on auctions during UpdateDB processing
#=============================================================================================

sub _update_sold_auctions {

    my $solddata    = shift;
    my $status      = 'SOLD';

    $tm->update_log( "Invoked Method: ".( caller(0) )[3] ); 

    # Save the old autocommit value and then explicitly set autocommit off.

    my $oldcommitval = $tm->{ DBH }->{ AutoCommit  };
    $tm->{ DBH }->{ AutoCommit  } = 0;

    # Set a commit limit unless a CommitLimit is already defined

    $tm->{ CommitLimit } = 100 unless $tm->{ CommitLimit };

    # Set processing counters

    my $counter = 1;
    my $commitcount = 1;

    # Update current auction data from list of auctions

    foreach my $s ( @$solddata ) {

        # Next record if auction ref not found in database

        if ( not $tm->is_DBauction_104( $s->{ AuctionRef } ) ) {

            send_message( "STATUS:Auction ".$s->{ AuctionRef } . " not updated - record not found in database" );
            send_message( "JOBLOG:Auction ".$s->{ AuctionRef } . " not updated - record not found in database" );
            $tm->update_log( "Auction ".$s->{ AuctionRef } . " not updated - record not found in database" );
            next;
        }

        # Get the auction key for the auction & saletype; If no key found for auction & sale type
        #  get key matching auction reference only as auction has not had a sales txn as yet

        my $auctionkey = $tm->get_auction_key_by_saletype(
            AuctionRef  => $s->{ AuctionRef  } ,
            SaleType    => $s->{ Sale_Type   } ,
        );

        $auctionkey = $tm->get_auction_key( $s->{ AuctionRef } ) unless defined $auctionkey;

        # Get the auction krecord for the retrieved key 

        my $a = $tm->get_auction_record( $auctionkey );

        send_message( "STATUS:Processing auction ".$s->{ AuctionRef }."(".$auctionkey.") [$status]: ".$a->{ Title }." - ".$counter." of ".scalar ( @$solddata ) );
        send_message( "JOBLOG:processing auction ".$s->{ AuctionRef }."(".$auctionkey.")  [$status]: ".$a->{ Title } );

        if ( $a->{ AuctionStatus } eq 'RELISTED' ) {

            $tm->update_log("Update Shipping Amount for RELISTED record             ");
            $tm->update_log("Updating: AuctionKey       $auctionkey                 ");
            $tm->update_log("          ShippingAmount   $s->{ Selected_Ship_Cost }  ");

            $tm->update_auction_record(
                AuctionKey                  =>   $auctionkey                            ,
                ShippingAmount              =>   $s->{ Selected_Ship_Cost }             ,
                SuccessFee                  =>   $s->{ Success_Fee }                    ,
                PromotionFee                =>   $s->{ Promotion_Fee }                  ,
                ListingFee                  =>   $s->{ Listing_Fee }                    ,
                CurrentBid                  =>   $s->{ Sale_Price }                     ,

            );
        }

        # If the saletype in the sales update file is the same as the auction record sales type 
        # then update shipping amount only; all other actions processed when sale txn first received

        elsif ( $a->{ SaleType } eq $s->{ Sale_Type } ) {

            $tm->update_log("Update Shipping Amount for EXISTING sales record       ");
            $tm->update_log("Updating: AuctionKey       $auctionkey                 ");
            $tm->update_log("          ShippingAmount   $s->{ Selected_Ship_Cost }  ");

            $tm->update_auction_record(
                AuctionKey                  =>   $auctionkey                            ,
                ShippingAmount              =>   $s->{ Selected_Ship_Cost }             ,
                SuccessFee                  =>   $s->{ Success_Fee }                    ,
                PromotionFee                =>   $s->{ Promotion_Fee }                  ,
                ListingFee                  =>   $s->{ Listing_Fee }                    ,
                CurrentBid                  =>   $s->{ Sale_Price }                     ,
            );
        }

        # If the auction hasnt been sold before (AuctionSold = 0 and SaleType = BLANK) then update
        # the auction record with the sales details and reduce stock onhand value for product code

        elsif ( $a->{ AuctionSold } == 0 ) {

            $tm->update_log("Update EXISTING Auction Record with NEW sales data     ");
            $tm->update_log("Updating: AuctionKey       $auctionkey                 ");
            $tm->update_log("          SaleType         $s->{ Sale_Type }           ");
            $tm->update_log("          AuctionStatus    SOLD                        ");
            $tm->update_log("          AuctionSold      1                           ");
            $tm->update_log("          SuccessFee       $s->{ Success_Fee }         ");
            $tm->update_log("          PromotionFee     $s->{ Promotion_Fee }       ");
            $tm->update_log("          ListingFee       $s->{ Listing_Fee }         ");
            $tm->update_log("          CurrentBid       $s->{ Sale_Price }          ");
            $tm->update_log("          ShippingAmount   $s->{ Selected_Ship_Cost }  ");
            $tm->update_log("          WasPayNow        $s->{ PayNow }              ");
            $tm->update_log("          CloseDate        $s->{ Sold_Date }           ");
            $tm->update_log("          CloseTime        $s->{ Sold_Time }           ");
            $tm->update_log("  Current StockOnHand      $a->{ StockOnHand }         ");

            $tm->update_auction_record(
                  AuctionKey                =>   $auctionkey                            ,
                  AuctionStatus             =>   "SOLD"                                 ,
                  AuctionSold               =>   1                                      ,
                  SuccessFee                =>   $s->{ Success_Fee }                    ,
                  PromotionFee              =>   $s->{ Promotion_Fee }                  ,
                  ListingFee                =>   $s->{ Listing_Fee }                    ,
                  CurrentBid                =>   $s->{ Sale_Price }                     ,
                  SaleType                  =>   $s->{ Sale_Type }                      ,
                  WasPayNow                 =>   $s->{ PayNow }                         ,
                  ShippingAmount            =>   $s->{ Selected_Ship_Cost }             ,
                  StockOnHand               =>   $a->{ StockOnHand }                    ,
                  DateLoaded                =>   $s->{ Start_Date    }                  ,
                ( $s->{ Sold_Date }  )      ?  ( CloseDate  => $s->{ Sold_Date } ) : () ,
                ( $s->{ Sold_Time }  )      ?  ( CloseTime  => $s->{ Sold_Time } ) : () ,
            );

            # IF stock on hand greater than 0, then decrement it; If The auction record 
            # has a product code set stock on hand to the new value for all product codes

            if ( $a->{ StockOnHand } > 0 )   { 
                $a->{ StockOnHand }--;

                $tm->update_log(" Adjusted StockOnHand      $a->{ StockOnHand }         ");

                $tm->update_auction_record(
                      AuctionKey                =>   $auctionkey                            ,
                      StockOnHand               =>   $a->{ StockOnHand }                    ,
                );

                if ( $a->{ ProductCode } ne '' ) {
                    $tm->update_log("Set StockOnHand value for Product Code $a->{ ProductCode }");
                    $tm->update_stock_on_hand(
                        ProductCode =>  $a->{ ProductCode } ,
                        StockOnHand =>  $a->{ StockOnHand } ,
                    );
                }
            }

        }

        # LEGACY support - Handle auctions previously flagged as sold but WITHOUT a Sale type
        # If the auction is SOLD but not Saletype exists, then the sale type was not updated
        # Add the saletype, fees etc to the existing record but DO NOT update stock as this
        # will already have been done when the records was marked as SOLD

        elsif ( $a->{ AuctionSold } == 1 and $a->{ SaleType } eq '' ) {

            $tm->update_log("UPDATE EXISTING Sold record with Sale Details          ");
            $tm->update_log("Updating: AuctionKey       $auctionkey                 ");
            $tm->update_log("          SaleType         $s->{ Sale_Type }           ");
            $tm->update_log("          SuccessFee       $s->{ Success_Fee }         ");
            $tm->update_log("          PromotionFee     $s->{ Promotion_Fee }       ");
            $tm->update_log("          ListingFee       $s->{ Listing_Fee }         ");
            $tm->update_log("          CurrentBid       $s->{ Sale_Price }          ");
            $tm->update_log("          ShippingAmount   $s->{ Selected_Ship_Cost }  ");
            $tm->update_log("          WasPayNow        $s->{ PayNow }              ");
            $tm->update_log("          CloseDate        $s->{ Sold_Date }           ");
            $tm->update_log("          CloseTime        $s->{ Sold_Time }           ");
            $tm->update_log("  Current StockOnHand      $a->{ StockOnHand }         ");

            $tm->update_auction_record(
                  AuctionKey                =>   $auctionkey                            ,
                  SuccessFee                =>   $s->{ Success_Fee }                    ,
                  PromotionFee              =>   $s->{ Promotion_Fee }                  ,
                  ListingFee                =>   $s->{ Listing_Fee }                    ,
                  CurrentBid                =>   $s->{ Sale_Price }                     ,
                  SaleType                  =>   $s->{ Sale_Type }                      ,
                  WasPayNow                 =>   $s->{ PayNow }                         ,
                  ShippingAmount            =>   $s->{ Selected_Ship_Cost }             ,
                  StockOnHand               =>   $a->{ StockOnHand }                    ,
                  DateLoaded                =>   $s->{ Start_Date    }                  ,
                ( $s->{ Sold_Date }  )      ?  ( CloseDate  => $s->{ Sold_Date } ) : () ,
                ( $s->{ Sold_Time }  )      ?  ( CloseTime  => $s->{ Sold_Time } ) : () ,
            );
        }

        # If the auction record has a different sales type than the sales record it is a new sale so 
        # add a NEW auction record with the NEW sales details and reduce stock onhand value for product code

        elsif ( $a->{ SaleType } ne $s->{ Sale_Type } ) {

            # Add new record by copying existing auction record

            $tm->update_log("ADD NEW Auction Record for NEW sales transaction      ");

            my $newkey = $tm->copy_auction_record(
                  AuctionKey                =>   $auctionkey                            ,
                  AuctionStatus             =>   "SOLD"                                 ,
                  AuctionSold               =>   1                                      ,
                  SuccessFee                =>   $s->{ Success_Fee }                    ,
                  PromotionFee              =>   $s->{ Promotion_Fee }                  ,
                  ListingFee                =>   $s->{ Listing_Fee }                    ,
                  CurrentBid                =>   $s->{ Sale_Price }                     ,
                  SaleType                  =>   $s->{ Sale_Type }                      ,
                  WasPayNow                 =>   $s->{ PayNow }                         ,
                  ShippingAmount            =>   $s->{ Selected_Ship_Cost }             ,
                  StockOnHand               =>   $a->{ StockOnHand }                    ,
                  DateLoaded                =>   $s->{ Start_Date    }                  ,
                ( $s->{ Sold_Date }  )      ?  ( CloseDate  => $s->{ Sold_Date } ) : () ,
                ( $s->{ Sold_Time }  )      ?  ( CloseTime  => $s->{ Sold_Time } ) : () ,
            );

            $tm->update_log("Adding    AuctionKey       $newkey                     ");
            $tm->update_log("          SaleType         $s->{ Sale_Type }           ");
            $tm->update_log("          AuctionStatus    SOLD                        ");
            $tm->update_log("          AuctionSold      1                           ");
            $tm->update_log("          SuccessFee       $s->{ Success_Fee }         ");
            $tm->update_log("          PromotionFee     $s->{ Promotion_Fee }       ");
            $tm->update_log("          ListingFee       $s->{ Listing_Fee }         ");
            $tm->update_log("          CurrentBid       $s->{ Sale_Price }          ");
            $tm->update_log("          ShippingAmount   $s->{ Selected_Ship_Cost }  ");
            $tm->update_log("          WasPayNow        $s->{ PayNow }              ");
            $tm->update_log("          CloseDate        $s->{ Sold_Date }           ");
            $tm->update_log("          CloseTime        $s->{ Sold_Time }           ");
            $tm->update_log("  Current StockOnHand      $a->{ StockOnHand }         ");

            # IF stock on hand greater than 0, then decrement it; If The auction record 
            # has a product code set stock on hand to the new value for all product codes

            if ( $a->{ StockOnHand } > 0 )   { 
                $a->{ StockOnHand }--;

                if ( $a->{ ProductCode } ne '' ) {
                    $tm->update_stock_on_hand(
                        ProductCode =>  $a->{ ProductCode } ,
                        StockOnHand =>  $a->{ StockOnHand } ,
                    );
                }
            }

        }
               
        $counter++;
        $commitcount++;
    
        if ( $commitcount > $tm->{ CommitLimit } ) {
            $tm->{ DBH }->commit();
            $commitcount = 1;
        }
    }

    # Commit the changes to the database & Restore the Autocommit property to 

    $tm->{ DBH }->commit();
    $tm->{ DBH }->{ AutoCommit  } = $oldcommitval;
}

#=============================================================================================
# _update_unsold_auctions - Perform specific updates on auctions during UpdateDB processing
#=============================================================================================

sub _update_unsold_auctions {

    my $unsdata = shift;
    my $status  = 'UNSOLD';

    $tm->update_log("Invoked Method: ".( caller(0) )[3] ); 

    # Save the old autocommit value and then explicitly set autocommit off.

    my $oldcommitval = $tm->{ DBH }->{ AutoCommit  };
    $tm->{ DBH }->{ AutoCommit  } = 0;

    # Set a commit limit unless a CommitLimit is already defined
    
    $tm->{ CommitLimit } = 100 unless $tm->{ CommitLimit };
    
    # Set processing counters
    
    my $counter = 1;
    my $commitcount = 1;

    # Update current auction data from list of auctions

    foreach my $unsold ( @$unsdata ) {

        if ( $tm->is_DBauction_104( $unsold->{ AuctionRef } ) ) {

            my $auctionkey = $tm->get_auction_key( $unsold->{ AuctionRef } );
    
            my $DBrecord = $tm->get_auction_record( $auctionkey );
            
            if ( $DBrecord->{ AuctionStatus } ne "RELISTED" ) {
    
                send_message( "STATUS:Updating auction ".$unsold->{ AuctionRef }."(".$auctionkey.")  [$status]: ".$DBrecord->{ Title }." - ".$counter." of ".scalar ( @$unsdata ) );
                send_message( "JOBLOG:Updating auction ".$unsold->{ AuctionRef }."(".$auctionkey.")  [$status]: ".$DBrecord->{ Title } );
            
                $tm->update_log("Updating auction ".$unsold->{ AuctionRef }."(".$auctionkey.")  [$status]: ".$DBrecord->{ Title });
    
                $tm->update_auction_record(
                      AuctionKey                  =>   $auctionkey                                                       ,
                      AuctionStatus               =>   $status                                                           ,
                      AuctionSold                 =>   0                                                                 ,
                    ( $unsold->{ CloseDate }   )  ?  ( CloseDate     => $unsold->{ CloseDate } ) : ()                    ,
                    ( $unsold->{ CloseTime }   )  ?  ( CloseTime     => $unsold->{ CloseTime } ) : ()                    );
            }
        }
        else {
            send_message( "STATUS:Auction ".$unsold->{ AuctionRef } . " not updated - record not found in database" );
            send_message( "JOBLOG:Auction ".$unsold->{ AuctionRef } . " not updated - record not found in database" );

            $tm->update_log( "Auction ".$unsold->{ AuctionRef } . " not updated - record not found in database" );
        }
        $counter++;
        $commitcount++;
        
        if ( $commitcount > $tm->{ CommitLimit } ) {
            $tm->{ DBH }->commit();
            $commitcount = 1;
        }
    }

    # Commit the changes to the database & Restore the Autocommit property to 

    $tm->{ DBH }->commit();
    $tm->{ DBH }->{ AutoCommit  } = $oldcommitval;
}

#=============================================================================================
# _update_current_auctions - Perform specific updates on auctions during UpdateDB processing
#=============================================================================================

sub _update_current_auctions {

    my $curdata = shift;
    my $status  = 'CURRENT';

    $tm->update_log("Invoked Method: ".( caller(0) )[3] ); 

    # Save the old autocommit value and then explicitly set autocommit off.

    my $oldcommitval = $tm->{ DBH }->{ AutoCommit  };
    $tm->{ DBH }->{ AutoCommit  } = 0;
    
    # Set a commit limit unless a CommitLimit is already defined
    
    $tm->{ CommitLimit } = 100 unless $tm->{ CommitLimit };
    
    # Set processing counters
    
    my $counter = 1;
    my $commitcount = 1;

    # Update current auction data from list of auctions

    foreach my $current ( @$curdata ) {

        if ( $tm->is_DBauction_104( $current->{ AuctionRef } ) ) {

            my $auctionkey = $tm->get_auction_key( $current->{ AuctionRef } );
    
            send_message( "STATUS:Updating auction ".$current->{ AuctionRef }."(".$auctionkey.")  [$status]: ".$current->{ Title }." - ".$counter." of ".scalar ( @$curdata ) );
            send_message( "JOBLOG:Updating auction ".$current->{ AuctionRef }."(".$auctionkey.")  [$status]: ".$current->{ Title } );
        
            $tm->update_log( "Updating auction ".$current->{ AuctionRef }."(".$auctionkey.")  [$status]: ".$current->{ Title });

            $tm->update_auction_record(
                  AuctionKey                    =>   $auctionkey                                        ,
                  AuctionStatus                 =>   $status                                            ,
                  OfferProcessed                =>   0                                                  ,
                  PromotionFee                  =>   $current->{ Promotion_Fee   }                      ,
                  ListingFee                    =>   $current->{ Listing_Fee     }                      ,
                  CurrentBid                    =>   $current->{ Max_Bid_Amount  }                      ,
                  DateLoaded                    =>   $current->{ Start_Date      }                      ,
                ( $current->{ End_Date }   )    ?  ( CloseDate     => $current->{ End_Date } ) : ()     ,
                ( $current->{ End_Time }   )    ?  ( CloseTime     => $current->{ End_Time } ) : ()     ,
            );
        }
        else {
            send_message( "STATUS:Auction ".$current->{ AuctionRef } . " not updated - record not found in database" );
            send_message( "JOBLOG:Auction ".$current->{ AuctionRef } . " not updated - record not found in database" );

            $tm->update_log( "Auction ".$current->{ AuctionRef } . " not updated - record not found in database" );
        }
        $counter++;
        $commitcount++;
        
        if ( $commitcount > $tm->{ CommitLimit } ) {
            $tm->{ DBH }->commit();
            $commitcount = 1;
        }
    }

    # Commit the changes to the database & Restore the Autocommit property to 

    $tm->{ DBH }->commit();
    $tm->{ DBH }->{ AutoCommit  } = $oldcommitval;

}

#=============================================================================================
# AuctionUpload - Subroutine to do the actual upload work
#=============================================================================================

sub _auction_upload {

    my $auctions    =   shift;
    my $dopt;
    
    $tm->update_log("Invoked Method: ". (caller(0))[3]); 

    # Set Auction loading delay values to a minimum of 5 seconds
    # Multiply the retrieved delay value * 60 to convert to seconds

    my $delay   =   $tm->{ DripFeedInterval };
    $delay      =   $delay * 60;
    
    $delay = 2 if $delay == 0;

    my $counter = 1;

    foreach my $a ( @$auctions ) {

        send_message( "STATUS:Trade Me Auction Upload Processing - ".$counter." of ".scalar ( @$auctions ) );

        # Check whether the Free Listing Limit has been exceeded and abort if true

        if ( $tm->{ ListLimitAbort } and over_listing_limit() ) {
            send_message( 'STATUS:Process aborted - Free Listing Limit Exceeded' );
            send_message( 'JOBLOG:Process aborted - Free Listing Limit Exceeded' );
            $tm->update_log( "Process aborted - Listing Limit Exceeded" );
            last;
        }

        send_message( "JOBLOG:Loading auction $a->{ Title } (Record $a->{ AuctionKey }) - ".$counter." of ".scalar ( @$auctions )  );
        $tm->update_log( "Loading auction $a->{ Title } (Record $a->{ AuctionKey }) - ".$counter." of ".scalar ( @$auctions )  );

        if ( $a->{ AuctionStatus } eq 'PENDING' ) {

            # if a shipping option is specified retrieve the delivery options
            
            if ( $a->{ ShippingOption } ) {
                $dopt = $tm->get_shipping_details( AuctionKey => $a->{ AuctionKey } );

                $tm->update_log( "Delivery Options specified on Auction: ".scalar( @$dopt ) );

                # Format the number fields to have a decimal point - TM appears not to like 0 as a single number

                foreach my $o ( @$dopt ) {
                    $o->{ Shipping_Details_Cost } = sprintf "%.2f", $o->{ Shipping_Details_Cost };
                    $tm->{ Debug } ge "1" ? $tm->update_log( "Shipping: ".$o->{ Shipping_Details_Text }." @ ".$o->{ Shipping_Details_Cost } ) : ();
                }
            }

            # If the auction is not the first auction and
            # if the delay is greater then 2 seconds log in for each auction
            # this is to ensure the session is not disconnected while waiting
            # as usual we test that the connection is oK before proceeding

            if ( $counter > 1 ) {

                sleep $delay;

                if ( $delay > 5 ) {     # If delay is greater than 5 then it is at least 1 minute

                    $tm->login();

                    if ( $tm->{ ErrorMessage } ) {
                        send_message( 'JOBLOG:'.$tm->{ ErrorMessage } );
                        send_message( 'STATUS:'.$tm->{ ErrorMessage } );
                        send_message( 'JOBEND' );   # Signal End of job
                        wait_for_ok_to_end();
                        return;
                    }
                }
            }

            if  ( $tm->{ Debug } ge "1" ) {    
                foreach my $k ( sort keys %$a ) {
                    my $spacer = " " x ( 25 - length( $k ) ) ;

                    if ( $k ne 'Description' ) {
                        $tm->update_log( $k." ".$spacer.$a->{ $k } );
                    }
                }
            }

            # Append the Standard terms to the Auction Desription

            my $terms       = $tm->get_standard_terms( AuctionSite => "TRADEME" );
            my $description = $a->{ Description }."\n\n".$terms;

            my $maxlength = 2018;

            if ( length( $description ) > $maxlength ) {
                $description = $a->{ Description };
                $tm->update_log( "Auction $a->{ Title } ( Record $a->{ AuctionKey }) - standard terms not applied." );
                $tm->update_log( "Combined length of standard terms and description would exceed allowable length");
                $tm->update_log( "Description [".length( $description )."] Terms [".length( $description )."] Threshold [".$maxlength."]");

                $description = $a->{ Description };
            }

            # Set the message field to blank and load the auction...                

            my $message = "";

            my $newauction = $tm->load_new_auction(
                AuctionKey                      =>  $a->{ AuctionKey      }   ,
                CategoryID                      =>  $a->{ Category        }   ,
                Title                           =>  $a->{ Title           }   ,
                Subtitle                        =>  $a->{ Subtitle        }   ,
                Description                     =>  $description                    ,
                IsNew                           =>  $a->{ IsNew           }   ,
                TMBuyerEmail                    =>  $a->{ TMBuyerEmail    }   ,
                EndType                         =>  $a->{ EndType         }   ,
                DurationHours                   =>  $a->{ DurationHours   }   ,
                EndDays                         =>  $a->{ EndDays         }   ,
                EndTime                         =>  $a->{ EndTime         }   ,
                !($a->{ ShippingOption }) ?   (   FreeShippingNZ  =>  $a->{ FreeShippingNZ          }   )   :   ()  ,
                !($a->{ ShippingOption }) ?   (   ShippingInfo    =>  $a->{ ShippingInfo            }   )   :   ()  ,
                $a->{ PickupOption    }   ?   (   PickupOption    =>  $a->{ PickupOption            }   )   :   ()  ,
                $a->{ ShippingOption  }   ?   (   ShippingOption  =>  $a->{ ShippingOption          }   )   :   ()  ,
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
                StartPrice                      =>  $a->{ StartPrice      }   ,
                ReservePrice                    =>  $a->{ ReservePrice    }   ,
                BuyNowPrice                     =>  $a->{ BuyNowPrice     }   ,
                ClosedAuction                   =>  $a->{ ClosedAuction   }   ,
                AutoExtend                      =>  $a->{ AutoExtend      }   ,
                BankDeposit                     =>  $a->{ BankDeposit     }   ,
                CreditCard                      =>  $a->{ CreditCard      }   ,
                CashOnPickup                    =>  $a->{ CashOnPickup    }   ,
                Paymate                         =>  $a->{ Paymate         }   ,
                Pago                            =>  $a->{ Pago            }   ,
                SafeTrader                      =>  $a->{ SafeTrader      }   ,
                PaymentInfo                     =>  $a->{ PaymentInfo     }   ,
                Gallery                         =>  $a->{ Gallery         }   ,
                BoldTitle                       =>  $a->{ BoldTitle       }   ,
                Featured                        =>  $a->{ Featured        }   ,
                FeatureCombo                    =>  $a->{ FeatureCombo    }   ,
                HomePage                        =>  $a->{ HomePage        }   ,
                Permanent                       =>  $a->{ Permanent       }   ,
                MovieRating                     =>  $a->{ MovieRating     }   ,
                MovieConfirm                    =>  $a->{ MovieConfirm    }   ,
                TMATT038                        =>  $a->{ TMATT038        }   ,
                TMATT163                        =>  $a->{ TMATT163        }   ,
                TMATT164                        =>  $a->{ TMATT164        }   ,
                AttributeName                   =>  $a->{ AttributeName   }   ,
                AttributeValue                  =>  $a->{ AttributeValue  }   ,
                TMATT104                        =>  $a->{ TMATT104        }   ,
                TMATT104_2                      =>  $a->{ TMATT104_2      }   ,
                TMATT106                        =>  $a->{ TMATT106        }   ,
                TMATT106_2                      =>  $a->{ TMATT106_2      }   ,
                TMATT108                        =>  $a->{ TMATT108        }   ,
                TMATT108_2                      =>  $a->{ TMATT108_2      }   ,
                TMATT111                        =>  $a->{ TMATT111        }   ,
                TMATT112                        =>  $a->{ TMATT112        }   ,
                TMATT115                        =>  $a->{ TMATT115        }   ,
                TMATT117                        =>  $a->{ TMATT117        }   ,
                TMATT118                        =>  $a->{ TMATT118        }   ,
            );

            # TODO: Add code to check if new auction already exists in database and log a severe error

            if ( not defined $newauction ) {
                send_message( "JOBLOG:Auction $a->{ Title } not loaded: Invalid Auction Status ($a->{ AuctionStatus })" );
                $tm->update_log("*** Error loading auction to TradeMe - Auction not Loaded");
            }
            
            else {

                my ( $closetime, $closedate );

                if ( $a->{ EndType } eq "DURATION" ) {
                
                    $closedate = $tm->closedate( $a->{ DurationHours } );
                    $closetime = $tm->closetime( $a->{ DurationHours } );
                }

                if ( $a->{ EndType } eq "FIXEDEND" ) {
                
                    $closedate = $tm->fixeddate( $a->{ EndDays } );
                    $closetime = $tm->fixedtime( $a->{ EndTime } );
                }

                $tm->update_log("Auction Uploaded to Trade me as Auction $newauction");

                $tm->update_auction_record(
                    AuctionKey       =>  $a->{ AuctionKey }                       ,
                    AuctionStatus    =>  "CURRENT"                                      ,
                    AuctionRef       =>  $newauction                                    ,
                    DateLoaded       =>  $tm->datenow()                                 ,
                    CloseDate        =>  $closedate                                     ,
                    CloseTime        =>  $closetime                                     ,
                );
            }
        }
        else {
            $tm->update_log( "Auction $a->{ Title } (Record $a->{ AuctionKey }) not loaded: Invalid Auction Status ($a->{ AuctionStatus })" );
        }

        # Check for termination request and exit processing loop if received

        if ( job_cancelled() ) {
            send_message( 'STATUS:Job Cancelled by User Request' );
            send_message( 'JOBLOG:Job Cancelled by User Request' );
            $tm->update_log( "Trade Me Auction Upload Process Cancelled by User" );
            last;
        }
        sleep $delay;
        $counter++;
    }
}

#=============================================================================================
# _auction_relist - Function to do the actual relist on TradeMe
#=============================================================================================

sub _auction_relist {

    my $auctions = shift;
    my $dopt;

    $tm->update_log( "Invoked Method: ". ( caller(0) )[3] ); 

    my $counter = 1;

    foreach my $a ( @$auctions ) {

        send_message( "STATUS:Trade Me Relist processing - ".$counter.' of '.scalar( @$auctions ) );

        # Check whether the Free Listing Limit has been exceeded if abort property is true

        if ( $tm->{ ListLimitAbort } and over_listing_limit() ) {
            send_message( 'STATUS:Process aborted - Free Listing Limit Exceeded' );
            send_message( 'JOBLOG:Process aborted - Free Listing Limit Exceeded' );
            $tm->update_log( "Process aborted - Listing Limit Exceeded" );

            last;
        }

        send_message( "JOBLOG:Relisting Auction $a->{ AuctionRef } - $a->{ Title } (Record $a->{ AuctionKey }) - ".$counter.' of '.scalar( @$auctions ) );
        $tm->update_log( "Relisting Auction $a->{ AuctionRef } - $a->{ Title } (Record $a->{ AuctionKey }) - ".$counter.' of '.scalar( @$auctions ) );

        if  ( $tm->{ Debug } ge "1" ) {    
            foreach my $k ( sort keys %$a ) {
                my $spacer = " " x ( 25 - length( $k ) ) ;

                if ( $k ne 'Description' ) {
                    $tm->update_log( $k." ".$spacer.$a->{ $k } );
                }
            }
        }

        my $message = "";

        # If a template has been specified retrieve the template record and override the old auction values
        # with the values from the template record
        
        if ( $a->{ UseTemplate } ) {
        
            $tm->update_log( "Applying Template $a->{ TemplateKey }" );

            my $t = $tm->get_auction_record($a->{ TemplateKey });
                
            $a->{ Category       }    =   $t->{ Category       };
            $a->{ Title          }    =   $t->{ Title          };
            $a->{ Subtitle       }    =   $t->{ Subtitle       };
            $a->{ Description    }    =   $t->{ Description    };
            $a->{ IsNew          }    =   $t->{ IsNew          };
            $a->{ TMBuyerEmail   }    =   $t->{ TMBuyerEmail   };
            $a->{ DurationHours  }    =   $t->{ DurationHours  };
            $a->{ StartPrice     }    =   $t->{ StartPrice     };
            $a->{ ReservePrice   }    =   $t->{ ReservePrice   };
            $a->{ BuyNowPrice    }    =   $t->{ BuyNowPrice    };
            $a->{ ClosedAuction  }    =   $t->{ ClosedAuction  };
            $a->{ AutoExtend     }    =   $t->{ AutoExtend     };
            $a->{ BankDeposit    }    =   $t->{ BankDeposit    };
            $a->{ CreditCard     }    =   $t->{ CreditCard     };
            $a->{ SafeTrader     }    =   $t->{ SafeTrader     };
            $a->{ PaymentInfo    }    =   $t->{ PaymentInfo    };
            $a->{ FreeShippingNZ }    =   $t->{ FreeShippingNZ };
            $a->{ ShippingInfo   }    =   $t->{ ShippingInfo   };
            $a->{ ShippingOption }    =   $t->{ ShippingOption };
            $a->{ PickupOption   }    =   $t->{ PickupOption   };
            $a->{ Featured       }    =   $t->{ Featured       };
            $a->{ Gallery        }    =   $t->{ Gallery        };
            $a->{ BoldTitle      }    =   $t->{ BoldTitle      };
            $a->{ Featured       }    =   $t->{ Featured       };
            $a->{ FeatureCombo   }    =   $t->{ FeatureCombo   };
            $a->{ HomePage       }    =   $t->{ HomePage       };
            $a->{ Permanent      }    =   $t->{ Permanent      };
            $a->{ MovieRating    }    =   $t->{ MovieRating    };
            $a->{ MovieConfirm   }    =   $t->{ MovieConfirm   };
            $a->{ AttributeName  }    =   $t->{ AttributeName  };
            $a->{ AttributeValue }    =   $t->{ AttributeValue };
            $a->{ TMATT104       }    =   $t->{ TMATT104       };
            $a->{ TMATT104_2     }    =   $t->{ TMATT104_2     };
            $a->{ TMATT106       }    =   $t->{ TMATT106       };
            $a->{ TMATT106_2     }    =   $t->{ TMATT106_2     };
            $a->{ TMATT108       }    =   $t->{ TMATT108       };
            $a->{ TMATT108_2     }    =   $t->{ TMATT108_2     };
            $a->{ TMATT111       }    =   $t->{ TMATT111       };
            $a->{ TMATT112       }    =   $t->{ TMATT112       };
            $a->{ TMATT115       }    =   $t->{ TMATT115       };
            $a->{ TMATT117       }    =   $t->{ TMATT117       };
            $a->{ TMATT118       }    =   $t->{ TMATT118       };

            # if a shipping option is specified retrieve the delivery options

            $dopt = $tm->get_shipping_details( AuctionKey => $a->{ TemplateKey } ) if ( $a->{ ShippingOption } );
        }
        else {
        
            # if a shipping option is specified retrieve the delivery options
            
            if ( $a->{ ShippingOption } ) {
                $dopt = $tm->get_shipping_details( AuctionKey => $a->{ AuctionKey } );

                $tm->update_log( "Delivery Options specified on Auction: ".scalar( @$dopt ) );

                # Format the number fields to have a decimal point - TM appears not to like 0 as a single number

                foreach my $o ( @$dopt ) {
                    $o->{ Shipping_Details_Cost } = sprintf "%.2f", $o->{ Shipping_Details_Cost };
                    $tm->{ Debug } ge "1" ? $tm->update_log( "Shipping: ".$o->{ Shipping_Details_Text }." @ ".$o->{ Shipping_Details_Cost } ) : ();
                }
            }

        }
        
        if ( ( $a->{ AuctionStatus } eq 'SOLD' ) or ( $a->{ AuctionStatus } eq 'UNSOLD' ) ) {

            # Append the Standard terms to the Auction Desription

            my $terms       = $tm->get_standard_terms( AuctionSite => "TRADEME" );
            my $description = $a->{ Description }."\n\n".$terms;

            my $maxlength = 2018;

            if ( length( $description ) > $maxlength ) {
                $description = $a->{ Description };
                $tm->update_log( "Auction $a->{ Title } (Record $a->{ AuctionKey }) - standard terms not applied.");
                $tm->update_log( "Combined length of standard terms and description would exceed allowable length");
                $tm->update_log( "Description [".length( $description )."] Terms [".length( $description )."] Threshold [".$maxlength."]");

                $description = $a->{ Description };
            }

            my $newauction = $tm->relist_auction(
                AuctionKey                      =>  $a->{ AuctionKey     },
                AuctionRef                      =>  $a->{ AuctionRef     },
                AuctionRef                      =>  $a->{ AuctionRef     },
                Category                        =>  $a->{ Category       },
                Title                           =>  $a->{ Title          },
                Subtitle                        =>  $a->{ Subtitle       },
                Description                     =>  $description          ,
                IsNew                           =>  $a->{ IsNew          },
                TMBuyerEmail                    =>  $a->{ TMBuyerEmail   },
                !($a->{ ShippingOption }) ?   (   FreeShippingNZ  =>  $a->{ FreeShippingNZ          }   )   :   ()  ,
                !($a->{ ShippingOption }) ?   (   ShippingInfo    =>  $a->{ ShippingInfo            }   )   :   ()  ,           
                $a->{ PickupOption    }   ?   (   PickupOption    =>  $a->{ PickupOption            }   )   :   ()  ,
                $a->{ ShippingOption  }   ?   (   ShippingOption  =>  $a->{ ShippingOption          }   )   :   ()  ,
                $dopt->[0]                ?   (   DCost1          =>  $dopt->[0]->{ Shipping_Details_Cost }   )   :   ()  ,
                $dopt->[0]                ?   (   DText1          =>  $dopt->[0]->{ Shipping_Details_Text }   )   :   ()  ,
                $dopt->[1]                ?   (   DCost2          =>  $dopt->[1]->{ Shipping_Details_Cost }   )   :   ()  ,
                $dopt->[1]                ?   (   DText2          =>  $dopt->[1]->{ Shipping_Details_Text }   )   :   ()  ,
                $dopt->[2]                ?   (   DCost3          =>  $dopt->[2]->{ Shipping_Details_Cost }   )   :   ()  ,  
                $dopt->[2]                ?   (   DText3          =>  $dopt->[2]->{ Shipping_Details_Text }   )   :   ()  ,
                $dopt->[3]                ?   (   DCost4          =>  $dopt->[3]->{ Shipping_Details_Cost }   )   :   ()  ,
                $dopt->[3]                ?   (   DText4          =>  $dopt->[3]->{ Shipping_Details_Text }   )   :   ()  ,
                $dopt->[4]                ?   (   DCost5          =>  $dopt->[4]->{ Shipping_Details_Cost }   )   :   ()  ,
                $dopt->[4]                ?   (   DText5          =>  $dopt->[4]->{ Shipping_Details_Text }   )   :   ()  ,
                $dopt->[5]                ?   (   DCost6          =>  $dopt->[5]->{ Shipping_Details_Cost }   )   :   ()  ,
                $dopt->[5]                ?   (   DText6          =>  $dopt->[5]->{ Shipping_Details_Text }   )   :   ()  ,
                $dopt->[6]                ?   (   DCost7          =>  $dopt->[6]->{ Shipping_Details_Cost }   )   :   ()  ,
                $dopt->[6]                ?   (   DText7          =>  $dopt->[6]->{ Shipping_Details_Text }   )   :   ()  ,
                $dopt->[7]                ?   (   DCost8          =>  $dopt->[7]->{ Shipping_Details_Cost }   )   :   ()  ,
                $dopt->[7]                ?   (   DText8          =>  $dopt->[7]->{ Shipping_Details_Text }   )   :   ()  ,
                $dopt->[8]                ?   (   DCost9          =>  $dopt->[8]->{ Shipping_Details_Cost }   )   :   ()  ,
                $dopt->[8]                ?   (   DText9          =>  $dopt->[8]->{ Shipping_Details_Text }   )   :   ()  ,
                $dopt->[9]                ?   (   DCost10         =>  $dopt->[9]->{ Shipping_Details_Cost }   )   :   ()  ,
                $dopt->[9]                ?   (   DText10         =>  $dopt->[9]->{ Shipping_Details_Text }   )   :   ()  ,
                EndType         =>   $a->{ EndType        },
                DurationHours   =>   $a->{ DurationHours  },
                EndDays         =>   $a->{ EndDays        },
                EndTime         =>   $a->{ EndTime        },
                StartPrice      =>   $a->{ StartPrice     },
                ReservePrice    =>   $a->{ ReservePrice   },
                BuyNowPrice     =>   $a->{ BuyNowPrice    },
                ClosedAuction   =>   $a->{ ClosedAuction  },
                AutoExtend      =>   $a->{ AutoExtend     },
                BankDeposit     =>   $a->{ BankDeposit    },
                CreditCard      =>   $a->{ CreditCard     },
                CashOnPickup    =>   $a->{ CashOnPickup   },
                Paymate         =>   $a->{ Paymate        },
                Pago            =>   $a->{ Pago           },
                SafeTrader      =>   $a->{ SafeTrader     },
                PaymentInfo     =>   $a->{ PaymentInfo    },
                FreeShippingNZ  =>   $a->{ FreeShippingNZ },
                ShippingInfo    =>   $a->{ ShippingInfo   },
                Featured        =>   $a->{ Featured       },
                Gallery         =>   $a->{ Gallery        },
                BoldTitle       =>   $a->{ BoldTitle      },
                Featured        =>   $a->{ Featured       },
                FeatureCombo    =>   $a->{ FeatureCombo   },
                HomePage        =>   $a->{ HomePage       },
                MovieRating     =>   $a->{ MovieRating    },
                MovieConfirm    =>   $a->{ MovieConfirm   },
                TMATT038        =>   $a->{ TMATT038       },
                TMATT163        =>   $a->{ TMATT163       },
                TMATT164        =>   $a->{ TMATT164       },
                AttributeName   =>   $a->{ AttributeName  },
                AttributeValue  =>   $a->{ AttributeValue },
                TMATT104        =>   $a->{ TMATT104       },
                TMATT104_2      =>   $a->{ TMATT104_2     },
                TMATT106        =>   $a->{ TMATT106       },
                TMATT106_2      =>   $a->{ TMATT106_2     },
                TMATT108        =>   $a->{ TMATT108       },
                TMATT108_2      =>   $a->{ TMATT108_2     },
                TMATT111        =>   $a->{ TMATT111       },
                TMATT112        =>   $a->{ TMATT112       },
                TMATT115        =>   $a->{ TMATT115       },
                TMATT117        =>   $a->{ TMATT117       },
                TMATT118        =>   $a->{ TMATT118       },
            );

            if (not defined $newauction) {
                send_message( "JOBLOG:Auction $a->{ AuctionRef } not relisted: Invalid Auction Status ($a->{ AuctionStatus })" );
                $tm->update_log( "Error relisting Auction $a->{ AuctionRef } on TradeMe" );
            }
            else {

                $tm->update_log( "Auction $a->{ AuctionRef } relisted on TradeMe as $newauction" );

                # Create a new auction record by copying the old record and updating the required details

                $message = "Auction relisted from auction ".$a->{ AuctionRef };

                my ( $closetime, $closedate );

                if ( $a->{ EndType } eq "DURATION" ) {

                    $closedate = $tm->closedate( $a->{ DurationHours } );
                    $closetime = $tm->closetime( $a->{ DurationHours } );
                }

                if ( $a->{ EndType } eq "FIXEDEND" ) {

                    $closedate = $tm->fixeddate( $a->{ EndDays } );
                    $closetime = $tm->fixedtime( $a->{ EndTime } );
                }

                $tm->copy_auction_record(
                    AuctionKey       =>  $a->{ AuctionKey }                    ,
                    AuctionStatus    =>  "CURRENT"                             ,
                    AuctionRef       =>  $newauction                           ,
                    AuctionSold      =>  0                                     ,
                    PromotionFee     =>  0                                     ,
                    ListingFee       =>  0                                     ,
                    SuccessFee       =>  0                                     ,
                    CurrentBid       =>  0                                     ,
                    ShippingAmount   =>  0                                     ,
                    OfferProcessed   =>  0                                     ,
                    RelistCount      =>  $a->{ RelistCount  }++                ,
                    RelistStatus     =>  $a->{ RelistStatus }                  ,
                    DateLoaded       =>  $tm->datenow()                        ,
                    CloseDate        =>  $closedate                            ,
                    CloseTime        =>  $closetime                            ,
                    Message          =>  $message                              ,
                );

                # Delete from Auctionitis if delete from database flag set to True, otherwise update existing record 

                if  ( $tm->{ RelistDBDelete } ) {

                    $tm->delete_auction_record(
                        AuctionKey          =>  $a->{ AuctionKey }      ,
                    );
                    $tm->update_log( "Auction $a->{ AuctionRef}  (record $a->{ AuctionKey }) deleted from Auctionitis database" );

                }
                else {

                    $message = "Auction relisted as $newauction";
                    $tm->update_auction_record(
                        AuctionKey           =>  $a->{AuctionKey}  ,
                        AuctionStatus        =>  "RELISTED"              ,
                        Message              =>  $message                ,
                    );
                }

                # Delete from TradeMe if delete from TradeMe flag set to True 

                if ( $tm->{ RelistTMDelete } ) {

                    $tm->delete_auction( AuctionRef => $a->{ AuctionRef } );
                    $tm->update_log( "Auction $a->{ AuctionRef } (record $a->{ AuctionKey }) deleted from TradeMe" );
                }
            }
        }
        else {
            send_message( "JOBLOG:Auction $a->{ AuctionRef } not relisted: Invalid Auction Status ($a->{ AuctionStatus })" );
            $tm->update_log( "Auction $a->{ AuctionRef } not relisted: Invalid Auction Status ($a->{ AuctionStatus })" );
        }

        # Check for termination request and exit processing loop if received

        if ( job_cancelled() ) {
            send_message( 'STATUS:Job Cancelled by User Request' );
            send_message( 'JOBLOG:Job Cancelled by User Request' );
            $tm->update_log( "Trade Me Relist Process Cancelled by User" );
            last;
        }

        sleep 2;
        $counter++;
    }
}

sub over_listing_limit {

    $tm->{ ListLimitAllowance } = 0 if $tm->{ ListLimitAllowance } eq "";

    my $ca = $tm->get_current_auction_count();
    my $ll = $tm->get_free_listing_limit() + $tm->{ ListLimitAllowance };

    send_message( "JOBLOG:Check Listing Limit - Current Auctions: ".$ca." Free Limit: ".$ll." Includes Allowance: ".$tm->{ ListLimitAllowance } );
    $tm->update_log( "Check Listing Limit - Current Auctions: ".$ca." Free Limit: ".$ll." Includes Allowance: ".$tm->{ ListLimitAllowance } );

    if ( $ca >= $ll ) {
        return 1;
    }
    else {
        return 0;
    }
}
1;

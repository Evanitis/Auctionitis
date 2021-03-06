#! perl -w

use strict;
use Auctionitis;
use Win32::API;
use threads;
use threads::shared;
use Thread::Queue;
use PerlTray;

my $message;
my $counter = 0;
my $consoleactive = 0;

my $queueheld   = "N";
my %config;
my $con_handle;
my $msgid;
my @jobq;
my $ticks       = 0;
my $tooltip;
my $pid;
my $activejob = 0;
my $activejobid = 0;

my $masterq;
my $slaveq;

my $jobs; # Array of hashes with job data

# Running interactively. It seems like STDOUT is not being flushed by
# the exit(1) call, so turn on autoflush.

$|=1; 

for my $arg ( @ARGV ) {
    # Process the command line parameters...
}

initialise();
register_messages();

sub initialise {

    SetTimer("00:60");
    show_balloon(
        Message     => "Initialising Tray Tool Settings"    ,
        Severity    => "Info"                               ,
    );

    $tooltip = "Auctionitis Tray Tool";

    # Set up the job parameters using the jobs file bound into the application

    initialise_job(
        JobName     => 'LOAD_TRADEME'                   ,
        JobText     => 'Load Auctions to Trade Me'      ,
        Frequency   =>  -1                              ,
        Priority    =>  1                               ,
        Callback    =>  \&todo                          ,
    );

    initialise_job(
        JobName     => 'LOAD_SELLA'                     ,
        JobText     => 'Load Auctions to Sella'         ,
        Frequency   =>  -1                              ,
        Priority    =>  1                               ,
        Callback    =>  \&todo                          ,
    );

    initialise_job(
        JobName     => 'UPDATE_DB'                      ,
        JobText     => 'Update Auction Database'        ,
        Frequency   =>  60                              ,
        Priority    =>  2                               ,
        Callback    =>  \&todo                          ,
    );

    initialise_job(
        JobName     => 'LOAD_IMAGES'                    ,
        JobText     => 'Upload Auction Images'          ,
        Frequency   =>  30                              ,
        Priority    =>  3                               ,
        Callback    =>  \&todo                          ,
    );

    initialise_job(
        JobName     => 'MAKE_OFFERS'                    ,
        JobText     => 'Make Fixed price Offers'        ,
        Frequency   =>  60                              ,
        Priority    =>  4                               ,
        Callback    =>  \&todo                          ,
    );

    initialise_job(
        JobName     => 'RELIST'                         ,
        JobText     => 'List Completed Auctions again'  ,
        Frequency   =>  60                              ,
        Priority    =>  5                               ,
        Callback    =>  \&todo                          ,
    );

    initialise_job(
        JobName     => 'GET_BALANCE'                    ,
        JobText     => 'Get Trade Me Account Balance'   ,
        Frequency   =>  15                              ,
        Priority    =>  6                               ,
        Callback    =>  \&todo                          ,
    );

    initialise_job(
        JobName     => 'JUSTATEST'                      ,
        JobText     => 'Just a test item'               ,
        Frequency   =>  2                               ,
        Priority    =>  9                               ,
        Callback    =>  \&justatest                     ,
    );

    initialise_job(
        JobName     => 'JUSTATEST2'                     ,
        JobText     => 'Just a test item'               ,
        Frequency   =>  30                              ,
        Priority    =>  9                               ,
        Callback    =>  \&justatest2                    ,
    );

    # Set up the master and slave message queues

    $slaveq  = Thread::Queue->new();
    $masterq = Thread::Queue->new();
}

sub show_balloon {

    my $p = { @_ };

    unless( defined( $p->{ Message } ) ) {
        Balloon( "No Message", "show_balloon", "Info", 10 );        
        return;
    }

    if ( not defined( $p->{ Severity } ) ) {
        $p->{ Severity } = 'INFO';
    }

    if ( uc( $p->{ Severity } ) eq 'INFO' ) {
        Balloon(
            $p->{ Message }         , 
            "Auctionitis Tray Tool" ,
            "info"                  ,
            10                      ,
        );
    }
    elsif ( uc( $p->{ Severity } ) eq 'ERROR' ) {
        Balloon(
            $p->{ Message }         , 
            "Auctionitis Tray Tool" ,
            "error"                 ,
            10                      ,
        );
    }
    elsif ( uc( $p->{ Severity } ) eq 'WARN' ) {
        Balloon(
            $p->{ Message }         , 
            "Auctionitis Tray Tool" ,
            "warning"               ,
            10                      ,
        );
    }
}

sub ToolTip { $tooltip }

sub PopupMenu {

    my $consolemsg;

    # Check whether the console is active or not do enable/disable the send console message option

    $consoleactive ? ( $consolemsg = \&ConsoleMsg ) : ( $consolemsg = '' );

    print "Consolemsg ".$consolemsg."\n";

    return [
        ["Auctionitis Website"  , "Execute 'http://www.auctionitis.co.nz'"      ],
        [ "--------"                                                            ],

        [ "Cancel Current Job"  , \&CancelCurrentJob                            ],
        [ "*View Job Status"    , \&JobStatus                                   ],
        [ "View Queue Status"   , \&QueueStatus                                 ],
        [ "Active Job Status"   , \&ActiveJobStatus                             ],
        [ "_ Pause processing"  , \&ToggleQueue, $queueheld eq "Y"              ],
        [ "Queue State"         , \&QueueState                                  ],

        [ "--------"                                                            ],
        ["  E&xit"              , \&QuitMe                                      ],
    ];
}

sub Timer {

    $ticks++;
    $tooltip = "Auctionitis Tray Tool (".$ticks.")";
    Balloon( "Tick", "Timer", "Info", 1 );        

    # Check the job array and see if any jobs need to be placed on the queue

    foreach my $job ( @$jobs ) {
        $job->{ Counter }++;
        if ( ( $job->{ Counter } == $job->{ Frequency } ) 
        and  ( $job->{ Status  } eq 'JOBWAIT'          ) ) {
            add_job( $job );
            $job->{ Status  } = 'QUEUED';
            $job->{ Counter } = 0;
        }
    }

    # check the job queue and execute the first job on the queue IF no jobs already active
    # only execute the *first* job so we get another loop through the time at job end

    if ( scalar( @jobq ) > 0 ) {

        $activejob ? ( print "Active job flag TRUE\n" ) : ( print "Active job flag FALSE\n" );
        print "Current job queue depth ".scalar( @jobq )."\n";

        if ( $activejob ) {
            print "Job ".$jobs->[ $activejobid ]->{ JobName }." currently active - waiting jobs delayed\n";
        }
        else {
            my $job = shift( @jobq );
            print "Job ".$job->{ JobName }." Submitted for processing\n";
            run_job( $job );
        }
    }
    else {
        print "No jobs currently queued for processing\n";
    }

    # If there are active jobs check for messages

    if ( $activejob ) {
        read_msg_from_slave();
    }
}

sub ConsoleMsg { 

    print "Console Message Function Initiated\n";

    my $sendMessage_lParam_as_number = Win32::API->new(
        'user32'        ,
        'SendMessage'   ,
        'NNNN'          ,
        'N'             ,
    );
    $sendMessage_lParam_as_number->Call(
        $con_handle     ,
        $msgid          ,
        0               ,
        0               ,
    );
}

sub QueueStatus {

    my $flags = MB_OK | MB_ICONINFORMATION;
    my $text = "Status of queued jobs:\n\n";
    my $item = 1;

    if ( scalar( @jobq ) > 0 ) {
        foreach my $job ( @jobq ) {
            $text .= $item++.". ".$job->{ JobName }.": ".$job->{ Status }."\n";
        }
    }
    else {
        $text .= "No jobs currently queued\n"
    }

    MessageBox( $text, "Auctionitis Tray Tool", $flags );

}

sub JobStatus {

    my $flags = MB_OK | MB_ICONINFORMATION;
    my $text = "Job Status Information:\n\n";
    my $item = 1;

    foreach my $job ( @$jobs ) {
        $text .= $item++.". ".$job->{ JobText }." - ".$job->{ JobName }." (".$job->{ Index }."): ".$job->{ Status }."\n";
    }

    MessageBox( $text, "Auctionitis Tray Tool", $flags );

}

sub ActiveJobStatus {

    my $flags = MB_OK | MB_ICONINFORMATION;
    my $text = "Active Job Status:\n\n";


    if ( $activejob ) {
        my $job = $jobs->[ $activejobid ];
        foreach my $key ( sort keys %$job ) {
            $text .= $key.": ".$job->{ $key }."\n";
        }
    }
    else {
        $text .= "No job currently active\n"
    }

    MessageBox( $text, "Auctionitis Tray Tool", $flags );

}

sub ToggleQueue {

    if ( $queueheld eq "Y" ) {
        $queueheld = "N";
    }
    else {
        $queueheld = "Y";
    }
}

sub QueueState {

    my $flags = MB_OK | MB_ICONQUESTION;
    my $msgtext;

    if ( $queueheld eq "Y" ) {
        $msgtext = "Queue State: Held";
    }
    else {
        $msgtext = "Queue State: Released";
    }

    MessageBox( $msgtext, "Auctionitis Tray Tool", $flags );

}

sub QuitMe {

    my $flags = MB_YESNO | MB_ICONQUESTION | MB_DEFBUTTON2;
    my $msgtext = "Are you sure you want to halt processing ?\n";
    $msgtext .= "Auctions will not load while the Auctionitis Tray tool is not running";
    my $ans = MessageBox( $msgtext, "Auctionitis Tray Tool", $flags );
    if ($ans == IDYES) {
        exit;
    }

}

sub Singleton {

    # This procedure is called if the Tray application is compiled with option "SINGLETON" Set
    # Basically Singleton signifies That only one instance can run at a time
    # If a second instance is started the contents of the command line are passed into the program
    # and the Singleton subroutine is called to allow something to happen

    my $newmessage = "";

    for my $arg ( @_ ) {
        if ( $arg ne "--" ) {
            $newmessage = $newmessage." ".$arg;
        }
    }

    if ( $_[1] eq "HANDLE" ) {
        $con_handle = $_[2];
        print "Handle: $con_handle\n";
    }

    if ( $_[1] eq "MSGID" ) {
        $msgid = $_[2];
        print "MSGID: $msgid\n";
    }

    Balloon( $newmessage, "Shit Received", "Info", 10 );

    $message = $newmessage;

}

sub CancelCurrentJob {

    if ( $activejob ) {
        print "Sending Cancel Request to Current Job...\n";
       send_slave_msg( 'CANCEL' );
    }
    else {
        my $flags = MB_OK | MB_ICONERROR;
        my $text = "No job currently active:\n\n";
        $text .= "Cancel Request ignored\n";
        return;
    }
}


sub register_messages {

    my $RegisterWindowMessage = Win32::API->new(
        'user32'                    ,
        'RegisterWindowMessage'     ,
        'P'                         ,
        'N'                         ,
    );

    my $MSG_AUCTIONITIS_EVENT = "AUCT_TMBALANCE_CHANGE";    # Trade Me balance has changed

    my $result = $RegisterWindowMessage->Call(
        $MSG_AUCTIONITIS_EVENT      ,
    );

    $MSG_AUCTIONITIS_EVENT = "AUCT_TRADEME_LOAD_DONE";      # Trade Me Load Process completed

    $result = $RegisterWindowMessage->Call(
        $MSG_AUCTIONITIS_EVENT      ,
    );

    $MSG_AUCTIONITIS_EVENT = "AUCT_SELLA_LOAD_DONE";        # Sella Load Proces completed

    $result = $RegisterWindowMessage->Call(
        $MSG_AUCTIONITIS_EVENT      ,
    );

}

sub initialise_job {

    my $p = { @_ };

    push( @$jobs,
        {   JobName     => $p->{ JobName    }   ,
            JobText     => $p->{ JobText    }   ,
            Frequency   => $p->{ Frequency  }   ,
            Priority    => $p->{ Priority   }   ,
            Callback    => $p->{ Callback   }   ,
            Counter     => 0                    ,
            Index       => scalar( @$jobs )     ,
            Status      => 'JOBWAIT'            ,
        }
    );

}

sub add_job {

    my $job = shift;

    print "Adding Job ".$job->{ JobName }." to Jobqueue\n";

    # Check if job on job queue and if not already queued add it to the queue

    push( @jobq, $job )
}

sub run_job {

    my $job = shift;

    if ( $pid = fork ) {

        send_msg_to_slave( 'MASTER CHANNEL' );

        print "Executing Job: ".$job->{ JobName }."\n";
    
        # Set the task status to Running, update the Job Active flag and the ActiveJobID variables
    
        $jobs->[ $job->{ Index } ]->{ Status } = 'RUNNING';
    
        $activejob = 1;
        $activejobid = $job->{ Index };

        send_msg_to_slave( 'HELLO' );

        print "Parent PID: $pid or $$\n";
    }
    else {

        send_msg_to_master( 'SLAVE CHANNEL' );

        print "Child PID: $pid or $$\n";

        $job->{ Callback }();

        exit;
    }
}

sub justatest {

    print "just a test now executing...\n";

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

    sleep 1;
}

sub justatest2 {

    print "just a test 2 now executing...\n";
    send_msg_to_master( 'justatest 2 going to sleep' );

    sleep 125;

   send_master_msg( 'JOBEND' );
}

sub read_msg_from_slave {

    if ( $activejob ) {

        print "reading from MASTER queue\n";
        print "Items on queue: ".$masterq->pending()."\n";

        while ( $masterq->pending() > 0 ) {
            my $msg = $masterq->dequeue();
            print $msg."\n";
            if ( $msg =~ m/JOBEND/ ) {
                print "Job ".$jobs->[ $activejobid ]->{ JobName }." Ended Normally\n";
                $jobs->[ $activejobid ]->{ Status    } = 'JOBWAIT';
                $jobs->[ $activejobid ]->{ Counter   } = 0;
                $activejob      = 0;
                $activejobid    = 0;
            }
        }
    }
    else {
        print "nothing active right now\n";
    }
}

sub send_msg_to_slave {

    my $message = shift;

    $slaveq->enqueue( $message );
}

sub read_msg_from_master {

    print "reading from SLAVE queue\n";
    print "Items on queue: ".$slaveq->pending()."\n";

    while ( $slaveq->pending() > 0 ) {
        my $msg = $slaveq->dequeue();
        print $msg."\n";
        if ( $msg =~ m/CANCEL/ ) {
            return 'CANCEL';
        }
    }
}

sub send_msg_to_master {

    my $message = shift;

    $masterq->enqueue( $message );
}



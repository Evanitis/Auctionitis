#! perl -w

use strict;
use Win32::API;
use Win32::Console;
use IO::Socket;
use IO::Select;
use PerlTray;
use Auctionitis;
use Date::Calc qw ( Delta_Days Delta_DHMS );

use constant {
    MINIMUM_BALANCE_REACHED            => 'MINIMUM_BALANCE_REACHED'   ,
    CURRENT_BALANCE_CHANGED            => 'CURRENT_BALANCE_CHANGED'   ,
};

my $initialising = 1;
my $console;
my $consoleactive = 0;
my $message;
my $masterq;
my $slaveq;
my $select;
my $shutdown;
my $counter = 0;

my $startup = 1;            # Initialise to 1 and then turn off when initialisation message displayed
my $unlicensed = 0;         # Flag to indicate whether license message has already been displayed
my $queueheld = "N";        # Flag to indicate whether prcoessing queue is held
my $showballoons = undef;   # Flag to indicate whether baloon message sshould be displayed for each job
my %config;
my $con_handle;
my $msgid;
my @jobq;
my @joblog;
my $ticks = 0;
my $tooltip;
my $activejob = 0;
my $activejobid = 0;
my $lastjobid = 0;

my $jobs;                   # Array of hashes with job data
my $jobtable;               # Hash of job names with Job index

my $today;
my $logfile;
my @days = qw( Sunday Monday Tuesday Wednesday Thursday Friday Saturday );


# Running interactively. It seems like STDOUT is not being flushed by
# the exit(1) call, so turn on autoflush.

$|=1; 

for my $arg ( @ARGV ) {
    exit if $arg =~ m/-QUIT|-RELOADJOBS|-LOADTM|-LOADSELLA/ ;
}

initialise();

# register_messages();

sub initialise {

    my $parms = shift;


    # Set up the today value for controlling log file name and log rolling 

    $today = ( localtime )[6];
    $logfile = 'AuctionTray-'.$days[ $today ].'.log';

    # Set the date now

    my $nowdate = (localtime)[3]."-".(localtime)[4]."-".(localtime)[5];
    my $logdate = $nowdate;

    # Retrieve the creation time of the log date and overwrite the date now
    # If the log file does not exist the date will be the same as now and 
    # no attempt will be made to roll the logs
    
    my @stat = stat( $logfile );

    if ( @stat ) {
        my ( $secs, $mins, $hrs, $dd, $mm, $yy, $dow, $jul, $isdst ) = localtime( $stat[8] );
        $logdate = "$dd-$mm-$yy";
    }

    # check whether date on log file is same as today and roll logs if not

    if ( $nowdate ne $logdate ) {
        unlink( $logfile );
    }

    # open the logfile

    open ( LOGFILE, ">> $logfile" );

    $tooltip = "Auctionitis AuctionTray";

    # Connect to the Auctionitis object

    my $tm = Auctionitis->new();
    $tm->initialise( Product => "Auctionitis" );

    # IF DOS console window flag set in registry display the console output

    if ( $tm->{ TrayConsole } ) {
        $consoleactive = 1;
        $console = new Win32::Console( STD_OUTPUT_HANDLE );
        $console->Alloc();
        $console->Title( "Auctionitis Auction Tray Console Log" );
        $console->Attr( $FG_LIGHTGREEN | $BG_BLACK );
        $console->Display();
        $console->Write( "Write Beginning AuctionTray Log Output...\n\n" );
    }
    else {
        $console = new Win32::Console();
        $console->Free();
    }

    $tm->DBconnect();

    # Set up the job parameters using the jobs file bound into the application

    my $tasks = $tm->get_active_tasks();

    foreach my $t ( @$tasks ) {
        initialise_job(
            JobName     => $t->{ TaskName           }   ,
            JobText     => $t->{ TaskDescription    }   ,
            Frequency   => $t->{ TaskFrequency      }   ,
            Priority    => $t->{ TaskPriority       }   ,
        );
    }

    # Set up the master and slave sockets for messaging

    write_log( "Creating Sockets for Auction Tray (Master)" );

    $masterq = IO::Socket::INET->new(
        LocalPort   => '15555'    ,
        Proto       =>  'udp'       , 
    );

    $slaveq  = IO::Socket::INET->new( 
        PeerPort    => '15556'      , 
        PeerAddr    => '127.0.0.1'  ,
        Proto       => 'udp'        ,
    );

    write_log( 'Master: '.$masterq );
    write_log( ' Slave: '.$slaveq );

    $select = IO::Select->new();
    $select->add( $masterq );

    write_log( "Initialisation complete" );

    $initialising = 0;

    sleep 5;

    SetTimer("00:60");

}

sub show_balloon {

    my $p = { @_ };

    unless( defined( $p->{ Message } ) ) {
        return;
    }

    if ( not defined( $p->{ Severity } ) ) {
        $p->{ Severity } = 'INFO';
    }

    if ( not defined( $p->{ Title } ) ) {
        $p->{ Title } = 'Auctionitis AuctionTray';
    }

    if ( uc( $p->{ Severity } ) eq 'INFO' ) {
        Balloon(
            $p->{ Message   }       , 
            $p->{ Title     }       ,
            "info"                  ,
            10                      ,
        );
    }
    elsif ( uc( $p->{ Severity } ) eq 'WARN' ) {
        Balloon(
            $p->{ Message   }       , 
            $p->{ Title     }       ,
            "warning"               ,
            30                      ,
        );
    }
    elsif ( uc( $p->{ Severity } ) eq 'ERROR' ) {
        Balloon(
            $p->{ Message   }       , 
            $p->{ Title     }       ,
            "error"                 ,
        );
    }
}

sub ToolTip { $tooltip }

sub PopupMenu {

    my ( $action, $msgoption );

    $queueheld eq 'Y'       ? ( $action = 'Start' ) : ( $action = 'Stop' );

    my $advancedmenu = [
        [ "Reload Job Table"    , \&ReloadJobTable                              ],
        [ "Clear Job Queue"     , \&ClearJobQueue                               ],
        [ "Check Job Status"    , \&is_job_alive                                ],
    ];

    return [
        [ "Auctionitis Website" , "Execute 'http://www.auctionitis.co.nz'"      ],
        [ "v Show Messages"     , \$showballoons,                               ],
        [ "Advanced"            , $advancedmenu                                 ],
        [ "--------"                                                            ],
        [ "Cancel Current Job"  , \&CancelCurrentJob                            ],
        [ "*View Job Status"    , \&JobStatus                                   ],
        [ "View Queue Status"   , \&QueueStatus                                 ],
        [ "Active Job Status"   , \&ActiveJobStatus                             ],
        [ "View Job Log"        , \&ViewJobLog                                  ],
        [ "$action processing"  , \&ToggleQueue                                 ],
        [ "--------"                                                            ],
        [ "Exit"                , \&QuitMe                                      ],
    ];

}

sub Timer {

    # Connect to the Auctionitis object

    my $tm = Auctionitis->new();
    $tm->initialise( Product => "Auctionitis" );

    # Test that the license is valid
    # the valid_license method returns '1' if the license is in error
    # If the license is invalid hold the queue

    $tm->valid_license();

    if ( $tm->{ ErrorStatus } eq '1' ) {
        ClearJobQueue();
        $queueheld = 'Y';
        write_log( "Auctionitis License Error:" );
        write_log( $tm->{ ErrorMessage } );
        write_log( "Release the processing queue when the license has been entered correctly" );
        if ( not $unlicensed ) {
            show_balloon(
                Message     => 'Processing Held - Invalid License',
                Severity    => 'WARN',
            );
            $unlicensed = 1;
        }
    }
    else {
        if ( $unlicensed ) {
            $queueheld = 'N';
            write_log( "Auctionitis License Validated:" );
            write_log( $tm->{ ErrorMessage } );
            write_log( "Processing queue has been released" );
            show_balloon(
                Message     => 'Processing Released - License validated',
                Severity    => 'INFO',
            );
        }
        $unlicensed = 0;
    }

    # Don't do any job processing if process has been paused = Queuestate = Y

    if ( $queueheld eq 'N' ) {
    
        # Check the job array and see if any jobs need to be placed on the queue

        write_log( "Current job queue depth ".scalar( @jobq ) );

        foreach my $job ( @$jobs ) {

            write_log( "Checking Job: ".$job->{ JobName }." Counter: ".$job->{ Counter }." Frequency: ".$job->{ Frequency } );

            $job->{ Counter }++;

            if ( ( $job->{ Counter   } >  $job->{ Frequency }   ) 
            and  ( $job->{ Frequency } >  0                     ) 
            and  ( $job->{ Status    } eq 'WAITING'             ) ) {
                write_log( "Add Job: ".$job->{ JobName }." to job queue" );
                add_job( $job );
            }
        }

        write_log( "Queue depth after job checking: ".scalar( @jobq ) );
    
        # check the job queue and execute the first job on the queue IF no jobs already active
        # only execute the *first* job so we get another loop through the time at job end
    
        if ( scalar( @jobq ) > 0 ) {
    
            $activejob ? ( write_log( "Active job flag TRUE" ) ) : ( write_log( "Active job flag FALSE" ) );
    
            if ( $activejob ) {
                write_log( "Job ".$jobs->[ $activejobid ]->{ JobName }." currently active - new job not started" );
            }
            else {
                my $job = shift( @jobq );
                write_log( "Job ".$job->{ JobName }." Submitted for processing from job queue" );
                run_job( $job );
            }
        }
        else {
            write_log( "No jobs currently queued for processing" );
            recalibrate_jobs();
        }
    }
    else {
        write_log( "Queue Held - All processing Ignored" );
    }


    # If there are active jobs check for messages

    if ( $activejob ) {
        process_messages();

        if ( not is_job_alive() ) {

            write_log( "Job Ended Abnormally ".$jobs->[ $activejobid ]->{ JobName } );
            $jobs->[ $activejobid ]->{ Status       } = 'WAITING';
            $jobs->[ $activejobid ]->{ LastStart    } = $jobs->[ $activejobid ]->{ StartTime };
            $jobs->[ $activejobid ]->{ LastEnd      } = datenow()." ".timenow();
            $jobs->[ $activejobid ]->{ Joblog       } = \@joblog;
            delete( $jobs->[ $activejobid ]->{ StartTime } );

            $activejob      = 0;
            $lastjobid      = $activejobid;
            $activejobid    = 0;

        }
    }
}

sub write_log {

    my $msg = shift;

    # Check whether the today value has changed and roll the logs

    if ( $today ne ( localtime )[6] ) {
        $today = ( localtime )[6];
        $logfile = 'AuctionTray-'.$days[ $today ].'.log';
        close( LOGFILE );
        open( LOGFILE, "> $logfile" );

    }

    # If the console is active write it to the console

    if ( $consoleactive ) {
        my $text = $msg."\n";
        $console->Write( $text );
        $console->Display();
    }

    # if the message is a Status message then exit

    return if $msg =~ m/Status:/i ;

    # Append a carriage return

    $msg .= "\n";

    print LOGFILE datenow()." ".timenow()." ".$msg;
}

sub ReloadJobTable {

    $#$jobs = -1;    # Clear the jobs array

    # Connect to the Auctionitis object

    my $tm = Auctionitis->new();
    $tm->initialise( Product => "Auctionitis" );
    $tm->DBconnect();
    my $tasks = $tm->get_active_tasks();

    foreach my $t ( @$tasks ) {
        initialise_job(
            JobName     => $t->{ TaskName           }   ,
            JobText     => $t->{ TaskDescription    }   ,
            Frequency   => $t->{ TaskFrequency      }   ,
            Priority    => $t->{ TaskPriority       }   ,
        );
    }
}

sub ClearJobQueue {

    # Rest the status & counters for all jobs currently queued

    foreach my $job ( @jobq ) {
        $jobs->[ $job->{ Index } ]->{ Status  } = 'WAITING';
        $jobs->[ $job->{ Index } ]->{ Counter } = 0;
    }

    # Clear the jobq array

    $#jobq = -1;    
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

    MessageBox( $text, "Auctionitis AuctionTray", $flags );

}

sub JobStatus {

    my $flags = MB_OK | MB_ICONINFORMATION;
    my $text = "Job Status Information:\n\n";
    my $item = '01';

    # List Running Job(s)

    foreach my $job ( @$jobs ) {
        if ( $job->{ Frequency } ne -1 ) {
            if ( $job->{ Status } eq 'RUNNING' ) {
                $text .= $item++.".  ".$job->{ Status }."  ".$job->{ JobText }."  (".$job->{ JobName }.");  Started:  ".( $jobs->[ $activejobid ]->{ StartTime } )."\n";
            }
        }
    }

    # List Queued Job(s)

    my $pos = 1;

    if ( scalar( @jobq ) > 0 ) {
        foreach my $job ( @jobq ) {
            $text .= $item++.".  ".$job->{ Status }."  ".$job->{ JobText }."  (".$job->{ JobName }.");  Queue Position:  ".$pos++."\n";
        }
    }

    # List Waiting Job(s)

    foreach my $job ( @$jobs ) {
        if ( $job->{ Frequency } ne -1 ) {
            if ( $job->{ Status } eq 'WAITING' ) {
                $text .= $item++.".  ".$job->{ Status }."  ".$job->{ JobText }."  (".$job->{ JobName }.");  Due in ".( $job->{ Frequency }-$job->{ Counter } )." minutes\n";
            }
        }
    }

    MessageBox( $text, "Auctionitis AuctionTray", $flags );

}

sub ActiveJobStatus {

    my $flags = MB_OK | MB_ICONINFORMATION;
    my $text = "Active Job Status:\n\n";


    if ( $activejob ) {
        my $job = $jobs->[ $activejobid ];
        foreach my $key ( sort keys %$job ) {
            $text .= $key.": ".$job->{ $key }."\n" unless $key eq "Joblog";
        }
    }
    else {
        $text .= "No job currently active\n"
    }

    MessageBox( $text, "Auctionitis AuctionTray", $flags );

}

sub ViewJobLog {

    my $flags = MB_OK | MB_ICONINFORMATION;
    my $text = "Job Log Information \n\n";
    if ( $activejob ) {
        $text .= "Job: ".$jobs->[ $activejobid ]->{ JobText }."\n";
        $text .= "Name: ".$jobs->[ $activejobid ]->{ JobName }."\n";
        $text .= "Status: "..$jobs->[ $activejobid ]->{ Status }.")\n";
        $text .= "Started: ".$jobs->[ $activejobid ]->{ StartTime }."\n\n";
        $text .= "Job Data: ".$jobs->[ $lastjobid ]->{ LastEnd   }."\n\n";
    }
    else {
        $text .= "Job: ".$jobs->[ $lastjobid ]->{ JobText }."\n";
        $text .= "Name: ".$jobs->[ $lastjobid ]->{ JobName }."\n";
        $text .= "Status: ".$jobs->[ $lastjobid ]->{ Status }."\n";
        $text .= "Started: ".$jobs->[ $lastjobid ]->{ LastStart }."\n";
        $text .= "Ended: ".$jobs->[ $lastjobid ]->{ LastEnd   }."\n\n";
        $text .= "Job Data: ".$jobs->[ $lastjobid ]->{ LastEnd   }."\n\n";
    }

    if ( scalar( @joblog ) > 0 ) {
        foreach my $msg ( @joblog ) {
            $text .= "->".$msg."\n";
        }
        $text .= "End of Job Log Information\n"
    }
    else {
        $text .= "No job log information available\n"
    }

    MessageBox( $text, "Auctionitis AuctionTray", $flags );

}

sub ToggleQueue {

    if ( $queueheld eq "Y" ) {
        $queueheld = "N";
        $unlicensed = 0;
        ReloadJobTable();
    }
    else {
        $queueheld = "Y";
        ClearJobQueue();
    }
}

sub QuitMe {

    my $flags = MB_YESNO | MB_ICONQUESTION | MB_DEFBUTTON2;
    my $msgtext = "Are you sure you want to halt processing ?\n";
    $msgtext .= "Auctions will not automatically load if the Auctionitis AuctionTray is not running";
    my $ans = MessageBox( $msgtext, "Auctionitis AuctionTray", $flags );
    if ($ans == IDYES) {
        exit;
    }
}

sub Singleton {

    # This procedure is called if the Tray application is compiled with option "SINGLETON" Set
    # Basically Singleton signifies That only one instance can run at a time
    # If a second instance is started the contents of the command line are passed into the program
    # and the Singleton subroutine is called to allow something to happen

    # The SINGLETON command gets passed in with a preceding "--" array element which must be stripped
    # out to get the actual data.

    my $command;

    for my $arg ( @_ ) {
        if ( $arg ne "--" ) {
            $command = $command." ".uc( $arg );
        }
    }

    # Write the command to the log

    write_log( 'Command Received from Auctionitis Client: '.$command );

    # Show the command as a ballon message

    show_balloon(
        Title       => 'Command Received',
        Message     => "Command Instruction: ".$command ,
        Severity    => 'Info'   ,
    );

    # Select processing based on command payload

    if ( $command =~ m/-QUIT/ ) {
        QuitMe();
    }
    elsif ( $command =~ m/-CHG_SCHEDULE/  ) {
    }
    elsif ( $command =~ m/-LOADTM/      ) {
    }
    elsif ( $command =~ m/-LOADSELLA/   ) {
    }
    else {
        show_balloon(
            Title       => 'Command Received',
            Message     => "No Asociated Instruction" ,
            Severity    => 'Warn'   ,
        );
        write_log( 'Unknown Instruction: '.$command );
    }
}

sub CancelCurrentJob {

    if ( $activejob ) {
        write_log( "Sending Cancel Request to Current Job..." );
        send_message( 'CANCEL' );
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

##############################################################################################
# 
#  J O B   C O N T R O L    S U B R O U T I N E S
# 
##############################################################################################

sub initialise_job {

    my $p = { @_ };

    push( @$jobs,
        {   JobName     => $p->{ JobName    }   ,
            JobText     => $p->{ JobText    }   ,
            Frequency   => $p->{ Frequency  }   ,
            Priority    => $p->{ Priority   }   ,
            Index       => scalar( @$jobs )     ,
            Status      => 'WAITING'            ,
        }
    );

    my $tm = Auctionitis->new();
    $tm->initialise( Product => "Auctionitis" );

    # Store the array index to the job by jobname in the job table
    # this allows dependent jobs to be added using the jobtable name

    $jobtable->{ $p->{ JobName } } = scalar( @$jobs ) - 1;

    # For the Jobs with start times set in the Auctionitis Console, retrieve
    # the start time and then calculate the minutes elapsed from that time until now
    # This allows the Job Counter to count down the remaining minutes as usual

    if (  $p->{ JobName } eq 'LOAD_TRADEME' ) {

        my ( $start, $hh, $mm );
        $tm->{ LoadStartTM } ? ( $start = $tm->{ LoadStartTM } ) : ( $start = '19:30' );
        $start =~ m/(.*):(.*)/;
        $hh = $1;
        $mm = $2;

        my $jobcounter = 1440 - minutes_until( Hours => $hh, Minutes => $mm );

        write_log( $p->{ JobName }                                                          );
        write_log( "- Scheduled Start Time: ".$hh." ".$mm                                   );
        write_log( "- Due In: ".minutes_until( Hours => $hh, Minutes => $mm )." minutes"    );
        write_log( "- Last Run: ".$jobcounter." minutes ago"                                );

        $jobs->[ scalar( @$jobs ) - 1 ]->{ Counter } = $jobcounter;
    }

    elsif (  $p->{ JobName } eq 'ACTIVATE_SELLA' ) {

        my ( $start, $hh, $mm );
        $tm->{ LoadStartSella } ? ( $start = $tm->{ LoadStartSella } ) : ( $start = '20:00' );
        $start =~ m/(.*):(.*)/;
        $hh = $1;
        $mm = $2;

        my $jobcounter = 1440 - minutes_until( Hours => $hh, Minutes => $mm );

        write_log( $p->{ JobName }                                                          );
        write_log( "- Scheduled Start Time: ".$hh." ".$mm                                   );
        write_log( "- Due In: ".minutes_until( Hours => $hh, Minutes => $mm )." minutes"    );
        write_log( "- Last Run: ".$jobcounter." minutes ago"                                );

        $jobs->[ scalar( @$jobs ) - 1 ]->{ Counter } = $jobcounter;
    }

    elsif (  $p->{ JobName } eq 'UPDATE_CATEGORIES' ) {

        my ( $start, $hh, $mm );
        $tm->{ CategoryUpdateStart } ? ( $start = $tm->{ CategoryUpdateStart } ) : ( $start = '03:00' );
        $start =~ m/(.*):(.*)/;
        $hh = $1;
        $mm = $2;

        my $jobcounter = 1440 - minutes_until( Hours => $hh, Minutes => $mm );

        write_log( $p->{ JobName }                                                          );
        write_log( "- Scheduled Start Time: ".$hh." ".$mm                                   );
        write_log( "- Due In: ".minutes_until( Hours => $hh, Minutes => $mm )." minutes"    );
        write_log( "- Last Run: ".$jobcounter." minutes ago"                                );

        $jobs->[ scalar( @$jobs ) - 1 ]->{ Counter } = $jobcounter;
    }

    # Set the Get Balance job counter to the job frequency so it runs straight away

    elsif (  $p->{ JobName } eq 'GET_BALANCE_TM' ) {

        $jobs->[ scalar( @$jobs ) - 1 ]->{ Counter } = $p->{ Frequency  } - 1;
    }

    else {
        $jobs->[ scalar( @$jobs ) - 1 ]->{ Counter } = 0;
    }
}

sub recalibrate_jobs {

    my $tm = Auctionitis->new();
    $tm->initialise( Product => "Auctionitis" );


    foreach my $j ( @$jobs ) {
    
    
        # For the Jobs with start times set in the Auctionitis Console, retrieve
        # the start time and then calculate the minutes elapsed from that time until now
        # This allows the Job Counter to count down the remaining minutes as usual
    
        if (  $j->{ JobName } eq 'LOAD_TRADEME' ) {
    
            my ( $start, $hh, $mm );
            $tm->{ LoadStartTM } ? ( $start = $tm->{ LoadStartTM } ) : ( $start = '19:30' );
            $start =~ m/(.*):(.*)/;
            $hh = $1;
            $mm = $2;
    
            my $jobcounter = 1440 - minutes_until( Hours => $hh, Minutes => $mm );

            if ( $j->{ Counter } ne $jobcounter ) {
                display_job_message( "CALIBRATING" );
                write_log( "Recalibrating ".$j->{ JobName }." Job Counter from ".$j->{ Counter }." to ".$jobcounter );
                $j->{ Counter } = $jobcounter;
            }
        }
    
        elsif (  $j->{ JobName } eq 'ACTIVATE_SELLA' ) {
    
            my ( $start, $hh, $mm );
            $tm->{ LoadStartSella } ? ( $start = $tm->{ LoadStartSella } ) : ( $start = '20:00' );
            $start =~ m/(.*):(.*)/;
            $hh = $1;
            $mm = $2;
    
            my $jobcounter = 1440 - minutes_until( Hours => $hh, Minutes => $mm );

            if ( $j->{ Counter } ne $jobcounter ) {
                display_job_message( "CALIBRATING" );
                write_log( "Recalibrating ".$j->{ JobName }." Job Counter from ".$j->{ Counter }." to ".$jobcounter );
                $j->{ Counter } = $jobcounter;
            }
        }
    
        elsif (  $j->{ JobName } eq 'UPDATE_CATEGORIES' ) {
    
            my ( $start, $hh, $mm );
            $tm->{ CategoryUpdateStart } ? ( $start = $tm->{ CategoryUpdateStart } ) : ( $start = '03:00' );
            $start =~ m/(.*):(.*)/;
            $hh = $1;
            $mm = $2;
    
            my $jobcounter = 1440 - minutes_until( Hours => $hh, Minutes => $mm );

            if ( $j->{ Counter } ne $jobcounter ) {
                display_job_message( "CALIBRATING" );
                write_log( "Recalibrating ".$j->{ JobName }." Job Counter from ".$j->{ Counter }." to ".$jobcounter );
                $j->{ Counter } = $jobcounter;
            }
        }
    }
}

sub add_job {

    my $job = shift;
    
    write_log( "Adding Job ".$job->{ JobName }." to Jobqueue" );

    if ( $job->{ JobName } eq 'LOAD_TRADEME' ) {

        if ( $jobs->[ $jobtable->{ 'LOAD_IMAGES_TM' } ]->{ Status } eq 'WAITING' ) {
            enqueue_job( $jobs->[ $jobtable->{ 'LOAD_IMAGES_TM' } ] );
        }
        else {
            write_log( "Job LOAD_IMAGES_TM not queued; current status is ".$jobs->[ $jobtable->{ 'LOAD_IMAGES_TM' } ]->{ Status } );
        }
        enqueue_job( $job );
    }
    elsif ( $job->{ JobName } eq 'RELIST_TRADEME' ) {

        if ( $jobs->[ $jobtable->{ 'UPDATE_DB' } ]->{ Status } eq 'WAITING' ) {
            enqueue_job( $jobs->[ $jobtable->{ 'UPDATE_DB' } ] );
        }
        else {
            write_log( "Job UPDATE_DB not queued; current status is ".$jobs->[ $jobtable->{ 'UPDATE_DB' } ]->{ Status } );
        }

        if ( $jobs->[ $jobtable->{ 'OFFER_TRADEME' } ]->{ Status } eq 'WAITING' ) {
            enqueue_job( $jobs->[ $jobtable->{ 'OFFER_TRADEME' } ] );
        }
        else {
            write_log( "Job OFFER_TRADEME not queued; current status is ".$jobs->[ $jobtable->{ 'OFFER_TRADEME' } ]->{ Status } );
        }

        enqueue_job( $job );
    }
    elsif ( $job->{ JobName } eq 'LOAD_SELLA' ) {

        if ( $jobs->[ $jobtable->{ 'LOAD_IMAGES_SELLA' } ]->{ Status } eq 'WAITING' ) {
            enqueue_job( $jobs->[ $jobtable->{ 'LOAD_IMAGES_SELLA' } ] );
        }
        else {
            write_log( "Job LOAD_IMAGES_SELLA not queued; current status is ".$jobs->[ $jobtable->{ 'LOAD_IMAGES_SELLA' } ]->{ Status } );
        }

        enqueue_job( $job );
    }
    elsif ( $job->{ JobName } eq 'ACTIVATE_SELLA' ) {

        if ( $jobs->[ $jobtable->{ 'LOAD_IMAGES_SELLA' } ]->{ Status } eq 'WAITING' ) {
            enqueue_job( $jobs->[ $jobtable->{ 'LOAD_IMAGES_SELLA' } ] );
        }
        else {
            write_log( "Job LOAD_IMAGES_SELLA not queued; current status is ".$jobs->[ $jobtable->{ 'LOAD_IMAGES_SELLA' } ]->{ Status } );
        }

        if ( $jobs->[ $jobtable->{ 'LOAD_CLONES_SELLA' } ]->{ Status } eq 'WAITING' ) {
            enqueue_job( $jobs->[ $jobtable->{ 'LOAD_CLONES_SELLA' } ] );
        }
        else {
            write_log( "Job LOAD_CLONES_SELLA not queued; current status is ".$jobs->[ $jobtable->{ 'LOAD_CLONES_SELLA' } ]->{ Status } );
        }

        enqueue_job( $job );
    }
    elsif ( $job->{ JobName } eq 'RELIST_SELLA' ) {

        if ( $jobs->[ $jobtable->{ 'UPDATE_DB_SELLA' } ]->{ Status } eq 'WAITING' ) {
            enqueue_job( $jobs->[ $jobtable->{ 'UPDATE_DB_SELLA' } ] );
        }
        else {
            write_log( "Job UPDATE_DB_SELLA not queued; current status is ".$jobs->[ $jobtable->{ 'UPDATE_DB_SELLA' } ]->{ Status } );
        }

        if ( $jobs->[ $jobtable->{ 'OFFER_SELLA' } ]->{ Status } eq 'WAITING' ) {
            enqueue_job( $jobs->[ $jobtable->{ 'OFFER_SELLA' } ] );
        }
        else {
            write_log( "Job OFFER_SELLA not queued; current status is ".$jobs->[ $jobtable->{ 'OFFER_SELLA' } ]->{ Status } );
        }

        enqueue_job( $job );
    }
    else {
        enqueue_job( $job );
    }
}

sub enqueue_job {

    my $job = shift;
    
    write_log( "Enqueuing Job ".$job->{ JobName }." to Jobqueue" );

    # Read the jobqueue until a job with a higher priority is located
    # insert the new job before the job with the higher priority

    if ( scalar( @jobq ) gt 0  ) {

        my $insertpos = 0;

        while ( $insertpos lt ( scalar( @jobq ) ) ) {
            if ( $job->{ Priority } lt $jobq[ $insertpos ]->{ Priority } ) {
                write_log( "Located job ".$jobq[ $insertpos ]->{ JobName }." on queue with higher prority than new job ".$job->{ JobName } );
                last;
            }
            $insertpos++;
        }
        splice( @jobq, $insertpos, 0, $job );
        write_log( "Added job ".$job->{ JobName }." to jobqueue at position ".$insertpos );
    }
    else {
        push( @jobq, $job );
        write_log( "Added job ".$job->{ JobName }." to jobqueue (jobqueue empty)" );
    }

    $jobs->[ $job->{ Index } ]->{ Status    } = 'QUEUED';
    $jobs->[ $job->{ Index } ]->{ Counter   } = 0;
}

sub run_job {

    my $job = shift;

    display_job_message( $job->{ JobName } );

    # Set the task status to Running, update the Job Active flag and the ActiveJobID variables
    
    system( 'start JobHandler.exe' );

    if ( job_handler_is_ready() ) {

        send_message( "JOBNAME:".$job->{ JobName } );

        write_log( "Executing Job: ".$job->{ JobName } );

        # Set the task status to Running, update the Job Active flag and the ActiveJobID variables

        $jobs->[ $job->{ Index } ]->{ Status    } = 'RUNNING';
        $jobs->[ $job->{ Index } ]->{ StartTime } = datenow()." ".timenow();

        @joblog = undef;
        $activejob = 1;
        $activejobid = $job->{ Index };
    }
    else {
        write_log( "Job Handler did not signal ready state - job ".$job->{ JobName }." not executed" );
    }
}

sub display_job_message {

    my $job = shift;

    my $message = '';

    # Balloon( $newmessage, "Request Received", "Info", 10 );

    if ( $job eq 'UPDATE_DB' ) {
        $message = 'Updating Database with Trade Me data';
    }
    elsif ( $job eq 'LOAD_IMAGES_TM' ) {
        $message = 'Sending Images to Trade Me';
    }
    elsif ( $job eq 'LOAD_TRADEME' ) {
        $message = 'Sending auctions to Trade Me';
    }
    elsif ( $job eq 'OFFER_TRADEME' ) {
        $message = 'Processing Offers on Trade Me';
    }
    elsif ( $job eq 'RELIST_TRADEME' ) {
        $message = 'Relisting Auctions on Trade Me';
    }
    elsif ( $job eq 'GET_BALANCE_TM' ) {
        $message = 'Retrieving account balance from Trade Me';
    }
    elsif ( $job eq 'UPDATE_DB_SELLA' ) {
        $message = 'Updating Database with Sella data';
    }
    elsif ( $job eq 'LOAD_IMAGES_SELLA' ) {
        $message = 'Sending Images to Sella';
    }
    elsif ( $job eq 'LOAD_SELLA' ) {
        $message = 'Sending auctions to Sella';
    }
    elsif ( $job eq 'LOAD__CLONES_SELLA' ) {
        $message = 'Sending CLONE auctions to Sella';
    }
    elsif ( $job eq 'ACTIVATE_SELLA' ) {
        $message = 'Activating auctions on Sella';
    }
    elsif ( $job eq 'OFFER_SELLA' ) {
        $message = 'Processing Offers on Sella';
    }
    elsif ( $job eq 'RELIST_SELLA' ) {
        $message = 'Relisting Auctions on Sella';
    }
    elsif ( $job eq 'UPDATE_CATEGORIES' ) {
        $message = 'Checking for category updates';
    }
    elsif ( $job eq 'CALIBRATING' ) {
        $message = 'Recalibrating Job Counters';
    }
    else {
        $message = 'Now running job '.$job;
    }

    # Display the Balloon message if display message option selected

    if ( defined( $showballoons ) ) {
        show_balloon(
            Title       => 'Auctionitis Processing' ,
            Message     => $message                 ,
            Severity    => 'Info'                   ,
        );
    }

    # Set the tool tip value

    $tooltip = $message;
}

sub event_handler {

    my $event = shift;
    
    if ( $event eq CURRENT_BALANCE_CHANGED ) {

    }

    elsif ( $event eq MINIMUM_BALANCE_REACHED ) {

        my $msg = 'Check Trade Me Account Balance';

        show_balloon(
            Title       => 'Warning',
            Message     => $msg     ,
            Severity    => 'Warn'   ,
        );

        # Set the alert icon for the tray to ON
    }
}

sub is_job_alive {

    # Check whether submitted slave job is actually active
    # This procedure is intended to assist in troubleshooting

    # Define a socket the same as the slave sockets for messaging
    # If we can actually create the socket then the job has abended
    # otherwise the job is alive and (presumably) doing something

    my $testq = IO::Socket::INET->new(
    LocalPort => '15556'    ,
    Proto       =>  'udp'   , 
    );

    if ( defined( $testq ) ) {
        $testq->close();
        return 0;
    }
    else {
        return 1;
    }
}

#=============================================================================================
# Method    : datenow
# Input     : -
# Returns   : String formatted as data in dd-mm-ccyy format including padded zeros
#=============================================================================================

sub datenow {

    my ( $date, $day, $month, $year );

    # Set the day value

    if   ( (localtime)[3] < 10 )        { $day = "0".(localtime)[3]; }
    else                                { $day = (localtime)[3]; }

    # Set the month value
    
    if   ( ((localtime)[4]+1) < 10 )    { $month = "0".((localtime)[4]+1); }
    else                                { $month = ((localtime)[4]+1) ; }

    # Set the century/year value

    $year = ((localtime)[5]+1900);

    $date = $day."-".$month."-".$year;
    
    return $date;
}

#=============================================================================================
# Method    : timenow
# Input     : -
# Returns   : String formatted as time in hh:mm:ss format including padded zeros
#=============================================================================================

sub timenow {

    my ( $time, $hour, $min, $sec );

    # Set the hour value

    if   ( (localtime)[2] < 10 )                    { $hour = "0".(localtime)[2]; }
    else                                            { $hour = (localtime)[2] ; }
    
    # Set the minute value
    
    if   ( (localtime)[1] < 10 )                    { $min = "0".(localtime)[1]; }
    else                                            { $min = (localtime)[1] ; }

    # Set the second value

    if   ( (localtime)[0] < 10 )                    { $sec = "0".(localtime)[0]; }
    else                                            { $sec = (localtime)[0] ; }


    $time = $hour.":".$min.":".$sec;
    
    return $time;
}

#=============================================================================================
# Method    : Minutes Until
# Input     : Hash Values - Hours, Minutes
# Returns   : String formatted as time in hh:mm:ss format including padded zeros
#=============================================================================================

sub minutes_until {

    my $p = { @_ };

    my $hours_now   = ( localtime )[2];
    my $minutes_now = ( localtime )[1];

    my @begtim      = ( 1960, 4, 16, $hours_now     , $minutes_now      , 0 );
    my @endtim      = ( 1960, 4, 16, $p->{ Hours }  , $p->{ Minutes }   , 0 );
    
    my @timedif     = Delta_DHMS( @begtim, @endtim );

    my $elapsed     = $timedif[1]*60 + $timedif[2];

    $elapsed        = $elapsed + 1440 if $elapsed lt 0;

    return $elapsed;
}

##############################################################################################
# 
#  M E S S A G I N G    S U B R O U T I N E S
# 
##############################################################################################

sub job_handler_is_ready {

    my $loops = 0;

    while ( $loops < 120 ) {

        if ( msg_waiting() ) {

            my $msgs = receive_messages();
    
            foreach my $msg ( @$msgs ) {
                write_log( "Received Message: ".$msg );

                $msg =~ tr/\n//d;                            # strip out new lines
                if ( $msg =~ m/READY/i ) {
                    write_log( "READY Signal received from Job Handler" );
                    return 1;
                }
                else  {
                    write_log( "Unexpected Message received from Job ".$jobs->[ $activejobid ]->{ JobName } );
                }
            }
        }
        else {
            sleep 1;
        }
        $loops++;
    }
    return 0;    # No Ready Signal received - effectively a timeout failure....
}

sub process_messages {

    if ( msg_waiting() ) {

        my $msgs = receive_messages();

        foreach my $msg ( @$msgs ) {

            $msg =~ tr/\n//d;                            # strip out new lines

            push( @joblog, $msg );

            if ( $msg =~ m/JOBSTART/i ) {
                write_log( "Job Started: ".$jobs->[ $activejobid ]->{ JobName } );
            }
            elsif ( $msg =~ m/JOBEND/i ) {
                send_message( 'OK2END' );
                write_log( "Job Ended Normally ".$jobs->[ $activejobid ]->{ JobName } );
                $jobs->[ $activejobid ]->{ Status       } = 'WAITING';

                # TODO: Modify program to recalculate counter for LOAD_SELLA and LOAD_TRADEME jobs [DONE]
                # This should allows these tasks to be initiated "on demand" from the Auctionitis client

                $jobs->[ $activejobid ]->{ Counter      } = 0;

                $jobs->[ $activejobid ]->{ LastStart    } = $jobs->[ $activejobid ]->{ StartTime };
                $jobs->[ $activejobid ]->{ LastEnd      } = datenow()." ".timenow();
                $jobs->[ $activejobid ]->{ Joblog       } = \@joblog;
                delete( $jobs->[ $activejobid ]->{ StartTime } );

                $activejob      = 0;
                $lastjobid      = $activejobid;
                $activejobid    = 0;
                last;
            }
            elsif ( $msg =~ m/(STATUS:)(.+$)/i ) {
                write_log( "Status: $2" );
                $jobs->[ $activejobid ]->{ LastMessage } = $2;
            }
            elsif ( $msg =~ m/(JOBLOG:)(.+$)/i ) {
                write_log( "Joblog: $2" );
                push( @joblog, $2);
            }
            elsif ( $msg =~ m/(EVENT:)(.+$)/i ) {
                event_handler( $2 );
            }
            else  {
                $jobs->[ $activejobid ]->{ LastMessage} = $msg;
            }
        }
    }
    else {
        write_log( "No Messages Received from JobHandler" );
    }
}

sub receive_messages {

    write_log( "Reading messages from JobHandler" );
    my ( $msgs, $msg );

    while ( msg_waiting() ) {
        my $peer = $masterq->recv( $msg, 2048 );
        push( @$msgs, $msg );
    }
    return $msgs;
}

sub send_message {

    my $msg = shift;

    $msg.="\n";

    $slaveq->send( $msg );
}

sub msg_waiting {
    if ( my @ready = $select->can_read( 0 ) ) {
        return 1;
    }
    else {
        return 0;
    }
}

1;

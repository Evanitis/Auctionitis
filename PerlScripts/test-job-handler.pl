#! perl -w

use strict;
use Win32::API;
use IO::Socket;
use IO::Select;

my $message;
my $masterq;
my $slaveq;
my $select;

my $job = shift;

print "Creating Sockets...\n";

$masterq = IO::Socket::INET->new(
    LocalPort   => '15555'    ,
    Proto       =>  'udp'       , 
);

$slaveq  = IO::Socket::INET->new( 
    PeerPort    => '15556'      , 
    PeerAddr    => '127.0.0.1'  ,
    Proto       => 'udp'        ,
);

print 'AT '.$masterq."\n";
print 'AT '.$slaveq."\n";

$select = IO::Select->new();
$select->add( $masterq );
print "Initialisation complete\n";


system( 'start JobHandler.exe' );

if ( job_handler_is_ready() ) {

    send_message( "JOBNAME:".$job );

    print "Executing Job: ".$job."\n";

    # Set the task status to Running, update the Job Active flag and the ActiveJobID variables

}
else {
    print "Job Handler did not signal ready state - job ".$job." not executed\n";
    exit;
}

while ( is_job_alive() ) {
    process_messages();
    sleep 10;
}


#----------------------------------------------
#  S U B R O U T I N E S
#----------------------------------------------

sub job_handler_is_ready {

    my $loops = 0;

    while ( $loops < 120 ) {

        if ( msg_waiting() ) {

            my $msgs = receive_messages();
    
            foreach my $msg ( @$msgs ) {
                print "Received Message: ".$msg;

                $msg =~ tr/\n//d;                            # strip out new lines
                if ( $msg =~ m/READY/i ) {
                    print "READY Signal received from Job Handler\n";
                    return 1;
                }
                else  {
                    print "Unexpected Message received from Job ".$job."\n";
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

            if ( $msg =~ m/JOBSTART/i ) {
                print "Job Started: ".$job."\n";
            }
            elsif ( $msg =~ m/JOBEND/i ) {
                send_message( 'OK2END' );
                print "Job Ended Normally ".$job."\n";
                last;
            }
            elsif ( $msg =~ m/(STATUS:)(.+$)/i ) {
                print "STATUS: $2\n";
            }
            elsif ( $msg =~ m/(JOBLOG:)(.+$)/i ) {
                print "JOBLOG: $2\n";
            }
            elsif ( $msg =~ m/(EVENT:)(.+$)/i ) {
                print " EVENT: $2\n";
            }
            else  {
                print " OTHER: $msg\n";
            }
        }
    }
    else {
        print "No Messages Received from JobHandler\n"
    }
}

sub receive_messages {

    print "reading from MASTER queue\n";
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
1;

#! perl -w

use strict;
use IO::Socket;
use IO::Select;
my $message;

my $masterq;
my $slaveq;
my $select;

initialise();
send_ready_message();
send_repeating_message();
print "DOne!\n";

sub initialise {

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
    $select->add( $slaveq );

    send_msg_to_master( 'JOBSTART' );

}

sub send_ready_message {
    send_msg_to_master( 'READY' );
}

sub send_repeating_message {

    my $counter = 1;
    my $wait = 5;

    while ( $counter < 200 ) {
        send_msg_to_master( 'Message Number '.$counter );
        $counter++;
        sleep $wait;
        $wait == 5 ? ( $wait = 45 ) : ( $wait = 5 );
    }
    send_msg_to_master( 'JOBEND' );

}

sub read_msg_from_slave {

}

sub send_msg_to_slave {

}

sub read_msg_from_master {

}

sub send_msg_to_master {

    my $msg = shift;

    $masterq->send( $msg."\n" );

}



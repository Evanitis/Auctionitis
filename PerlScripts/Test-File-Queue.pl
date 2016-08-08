#! perl -w

use strict;
use File::Queue;

my $message;

my $masterq;
my $slaveq;

initialise();
send_message_to_master( 'Yeah right as if this will work' );
receive_message_from_master();

sub initialise {

    $slaveq  = new File::Queue (
        File        => './slaveq'   ,
        Separator   => '|'          ,
    );
    $masterq = new File::Queue (
        File        => './masterq'  ,
        Separator   => '|'          ,
    );
}

sub read_msg_from_slave {

    print "reading from MASTER queue\n";

    while ( my $msg = $masterq->deq() ) {
        print "Incoming: ".$msg."\n";
    }
}

sub send_msg_to_slave {

    my $message = shift;
    $slaveq->enq( $message );
}

sub read_msg_from_master {

    print "reading from SLAVE queue\n";

    while ( my $msg = $slaveq->deq() ) {
        print $msg."\n";
        if ( $msg =~ m/CANCEL/ ) {
            return 'CANCEL';
        }
    }
}

sub send_msg_to_master {

    my $message = shift;
    $masterq->enq( $message );
}


#! perl -w

use strict;
use IO::Socket;
use IO::Select;

my $message;

my $masterq;
my $slaveq;
my $select;
my @ready;
my $shutdown;

initialise();
mainline();
print "done!\n";

sub initialise {

    $masterq = IO::Socket::INET->new(
        LocalPort => '15555'    ,
        Proto       =>  'udp'   , 
    );
    # die "Could not create socket: $@\n" unless $masterq;
    print $masterq."\n";

    $slaveq  = IO::Socket::INET->new( 
        PeerPort    => '15556'      , 
        PeerAddr    => 'localhost'  ,
        Proto       => 'udp'        ,

    );
    print $slaveq."\n";

    $select = IO::Select->new();
    $select->add( $masterq );

    # die "Could not create socket: $@\n" unless $slaveq;

    #system( 'perl test-tcp-client.pl' );
    #print "started other process\n";
}

sub mainline {
    while ( not $shutdown ) {
        read_slave_messages();
        do_something_else();
    }
}

sub do_something_else {
    print "Right now Im off doing something else (sleeping actually)\n";
    sleep 30;
}

sub read_slave_messages {

    my $loops = 0;
    my ( $msgs, $msg );

    while ( $loops < 120 ) {
        $msgs = read_msg_from_slave();
        if ( scalar( $msgs ) gt 0 ) {
            print "messages received\n";
        }
        $loops++;
    }
    return 0;
}

sub read_msg_from_slave {

    print "reading from MASTER queue\n";
    my ( $msgs, $msg );

    if ( msg_from_slave_waiting() ) {
        while ( msg_from_slave_waiting() ) {
            my $peer = $masterq->recv( $msg, 2048 );
            print "Incoming: ".$msg."\n";
            if ( $msg =~ m/JOBSTART/ ) {
                print "Start of new job\n";
            }
            elsif ( $msg =~ m/JOBEND/ ) {
                print "End of Job - Shutting down\n";
                $shutdown = 1;
                last;
            }
            else {
                push( @$msgs, $msg );
            }
        }
    }
    else {
        print "No messages from slave\n";
    }
    return $msgs;
}


sub msg_from_slave_waiting {
    @ready = $select->can_read();
    if ( fileno( @ready[0] ) == fileno( $masterq ) ) {
        return 1;
    }
    else {
        return 0;
    }
}

sub send_msg_to_slave {

}

sub read_msg_from_master {

}

sub send_msg_to_master {

}


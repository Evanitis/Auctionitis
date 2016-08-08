#!/usr/bin/perl -w
use strict;
use HTTP::Daemon;
use HTTP::Status;

my $d = HTTP::Daemon->new( 
        LocalAddr => 'ehserver',
        LocalPort => 8080) || die;
print "Please contact me at: <URL:", $d->url, ">\n";
while (my $c = $d->accept) {
    $c->send_file_response("c:/evan/mofoweb/mofoindex.html");
    while (my $r = $c->get_request) {
            $c->send_status_line("","Hello you bunch of cunts");
            print "Connection: $c\n";
            my $r = $c->reason;
            print "Reason: $r\n";
            my $b = $c->read_buffer;
            print "Buffer: $b\n";
            my $o = $c->get_request;
            print "Request: $o\n";
        }
    $c->close;
    undef($c);
}

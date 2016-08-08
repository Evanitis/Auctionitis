#!/usr/bin/perl -w
use strict;
use HTTP::Daemon;
use HTTP::Status;

my $d = HTTP::Daemon->new( 
        LocalAddr => 'ehserver',
        LocalPort => 8080) || die;
print "Please contact me at: <URL:", $d->url, ">\n";
while (my $c = $d->accept) {
    while (my $r = $c->get_request) {
            $c->send_file_response("c:/evan/mofoweb/mofoindex.html");
            $c->send_status_line("","Hello you bunch of cunts");
            my $o = $c->get_request;
            print "$o\n";}
    $c->close;
    undef($c);
}

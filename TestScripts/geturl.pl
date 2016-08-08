#!perl -w

use strict;
use LWP::UserAgent;
use HTTP::Request;
use HTTP::Response;
use URI::Heuristic;

my $raw_url = shift  or die "Usage: $0 <url>\n"; 
my $url = URI::Heuristic::uf_urlstr($raw_url);
$| = 1; #t flush next line
printf "%s =>\n\t", $url;

my $ua = LWP::UserAgent->new();
$ua->agent("Mofo Extracter/V1.0");
my $req = HTTP::Request->new(GET => $url);
$req->referrer("http://www.dr-mofo.co.nz"); #used for log traffic analysis on remote site

my $response = $ua->request($req); #get the page (I guess)

if ($response->is_error()) {
    printf " %s\n", $response->status_line;
} else {
    my $count;
    my $bytes;
    my $content = $response->content();
    $bytes = length $content;
    $count = ($content =~ tr/\n/\nn/);
    printf "%s (%d lines, %d bytes)\n", $response->title(), $count, $bytes;
    # write it to a file    
    my $filename = "c:\\evan\\source\\testdata\\urldata.log";
    open my $urldata,  "> $filename" or die "Cannot open $filename: $!";
    print $urldata $response->content();}

use strict;
use LWP::Simple;
use LWP::UserAgent;
use URI::URL;
use URI::Escape;
use HTTP::Request;
use HTTP::Response;
use HTTP::Headers;
use HTTP::Response;
use HTTP::Cookies;
use HTTP::Request::Common qw(POST);
use HTML::TokeParser;

# class variables

my ($ua, $url, $req, $response, $content);

my $userid   = "tracey\@irobot.co.nz";
my $password = "wicked99";

my $auctionref = shift;

# Set up the user agent pseudo-browser

$ua = LWP::UserAgent->new();
$ua->agent("Auctionitis/V1.0");
push @{$ua->requests_redirectable}, 'POST';  # Added 29/04/05
$ua->cookie_jar(HTTP::Cookies->new(file       => "lwpcookies.txt",
                                   autosave   => 1));
                                       

# log-in to Trademe

$url = "http://www.trademe.co.nz/Members/Login.aspx";                   
$req = POST $url, [url            =>  '/DEFAULT.ASP?'   ,
#                   test_auto      =>  ''               ,
                   email          =>  $userid           ,
                   password       =>  $password         ,
                   login_attempts =>  0                 ,
                   submitted      =>  'Y'               ];

$content = $ua->request($req)->as_string; # posts the data to the remote site i.e. logs in

# get the Sell similar item data page

my $auctionstatus = "CURRENT";

$url="http://www.trademe.co.nz/MyTradeMe/AuctionDetailCommand.aspx";        # 21/05.2006

$req = POST $url, [
    "id"                             =>   $auctionref,
    ($auctionstatus eq "CURRENT"  )   ?   ("cmdSellSimilarItem"      => 'Sell similar item')    : () ,
    ($auctionstatus eq "SOLD"     )   ?   ("cmdSellSimilarItemSold"  => 'Sell similar item')    : () ,
    ($auctionstatus eq "UNSOLD"   )   ?   ("cmdSellSimilarItemSold"  => 'Sell similar item')    : () ,
];

# Submit the auction details to TradeMe (HTTP POST operation) 

$content = $ua->request($req)->as_string;

# parse the data using the toke parser module

my $stream = new HTML::TokeParser(\$content);

while ( my $token = $stream->get_token() ) {

    if ( $token->[0] eq 'S' and $token->[1] eq 'input' ) {
        print "Extracted tag: ".$token->[2]{ 'name' }."\t Value: $token->[2]{ 'value' }\n";
    }
}

while ( my $token = $stream->get_token() ) {

    if ( $token->[0] eq 'S' and $token->[1] eq 'select' ) {
        print "Extracted tag: ".$token->[2]{ 'name' }."\t Value: $token->[2]{ 'value' }\n";
    }
}

while ( my $token = $stream->get_token() ) {

    if ( $token->[0] eq 'S' and $token->[1] eq 'option' ) {
        print "Extracted tag: ".$token->[2]{ 'name' }."\t Value: $token->[2]{ 'value' }\n";
    }
}

while ( my $token = $stream->get_token() ) {

    if ( $token->[0] eq 'S' and $token->[1] eq 'option' ) {
        print "Extracted tag: ".$token->[2]{ 'name' }."\t Value: $token->[2]{ 'value' }\n";
    }
}

while ( my $token = $stream->get_token() ) {

    if ( $token->[0] eq 'S' and $token->[1] eq 'checkbox' ) {
        print "Extracted tag: ".$token->[2]{ 'name' }."\t Value: $token->[2]{ 'value' }\n";
    }
}

while ( my $token = $stream->get_token() ) {

    if ( $token->[0] eq 'S' and $token->[1] eq 'textarea' ) {
        print "Extracted tag: ".$token->[2]{ 'name' }."\t Value: $token->[2]{ 'value' }\n";
    }
}
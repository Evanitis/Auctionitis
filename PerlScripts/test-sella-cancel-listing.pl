#!perl -w

use strict;
use Auctionitis;

my $auctionref = shift;

unless ( $auctionref ) { print "You must supply an Aucion Reference to be cancelled\n"; exit; }

my $tm = Auctionitis->new();
$tm->initialise( Product => "Auctionitis" );  # Initialise the product
$tm->DBconnect();
$tm->connect_to_sella();

my $state = $tm->sella_get_listing_state(
    AuctionRef   =>  $auctionref ,
);

print $state."\n";

$tm->sella_cancel_listing(
    AuctionRef   =>  $auctionref ,
);
        


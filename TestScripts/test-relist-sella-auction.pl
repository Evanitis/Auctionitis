#!perl -w

use strict;
use Auctionitis;

my $auctionref = shift;

unless ( $auctionref ) { print "You must supply an Aucion Ref to be relisted\n"; exit; }

my $tm = Auctionitis->new();
$tm->initialise( Product => "Auctionitis" );  # Initialise the product
$tm->DBconnect();
$tm->connect_to_sella();

my $state = $tm->sella_get_listing_state(
    AuctionRef   =>  $auctionref,
);

print $state."\n";

my $newid = $tm->relist_sella_auction(
    AuctionRef   =>  $auctionref ,
);

if ( $newid ) {
    print "Auction relisted as ".$newid."\n";
}
else {
    print $tm->{ ErrorMessage }."\n";
}
        


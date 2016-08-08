#!perl -w

use strict;
use Auctionitis;

my $tm = Auctionitis->new();

$tm->initialise( Product => "Auctionitis" );  # Initialise the product

$tm->login();

my $auctions = $tm->get_sold_listings();

my $count = scalar( @$auctions );
print "Processing SOLD Auctions - Count $count\n";

foreach my $auction ( @$auctions ) {
    $tm->make_offer( $auction->{ AuctionRef } );
}

$auctions = $tm->get_unsold_listings();

$count = scalar( @$auctions );
print "\nProcessing UNSOLD Auctions $count\n";

foreach my $auction ( @$auctions ) {
    $tm->make_offer( $auction->{ AuctionRef } );
}

# Success.

print "Done\n";
exit(0);

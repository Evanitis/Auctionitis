#!perl -w

use strict;
use Auctionitis;

my $tm = Auctionitis->new();
$tm->initialise( Product => "Auctionitis" );  # Initialise the product
$tm->DBconnect();
$tm->connect_to_sella();

my $listings = $tm->sella_api_listing_get_ids_by_status( Status => 'draft' );

if ( scalar( @$listings ) > 0 ) {

    foreach my $auctionref ( @$listings ) {
        print "Retrived draft auction $auctionref\n";
    }
}
else {
    print "nothing returned!\n"
}

        


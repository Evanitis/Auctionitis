#!perl -w

use strict;
use Auctionitis;

my $status = shift;
unless ( $status ) { print "You must supply a status to be retrieved\n"; exit; }

unless ( $status =~ m/in-progress|sold|draft|closed/ ) { 
    print "Invalid Listing Status requested - status must be in-progress, sold, draft or closed\n";
    exit;
}

my $tm = Auctionitis->new();
$tm->initialise( Product => "Auctionitis" );  # Initialise the product
$tm->DBconnect();
$tm->connect_to_sella();

my $listings = $tm->sella_api_listing_get_ids_by_status( Status => $status );

$tm->{ ErrorMessage } ? ( print "ERROR: ".$tm->{ ErrorMessage }."\n" ) : ();

print $listings."\n";

if ( scalar $listings gt 0 ) {
    foreach my $item ( @$listings ) {
        print "ID: ".$item."\n";
    }
}

        


#!perl -w

use strict;
use Auctionitis;

my $auctionref = shift;

unless ( $auctionref ) { print "You must supply an Aucion Ref to be retrieved\n"; exit; }

my $tm = Auctionitis->new();
$tm->initialise( Product => "Auctionitis" );  # Initialise the product
$tm->DBconnect();
$tm->connect_to_sella();

my $data = $tm->sella_listing_get_by_id(
    AuctionRef   =>  $auctionref,
);

foreach my $property ( sort keys %$data ) {
      my $spacer = " " x ( 40-length( $property ) );

      # update the log with the  output

      print $property.": ".$spacer.$data->{ $property }."\n";
}
        


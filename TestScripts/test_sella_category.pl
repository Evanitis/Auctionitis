#!perl -w

use strict;
use Auctionitis;

my $cat = shift;

my $tm = Auctionitis->new();
$tm->initialise( Product => "Auctionitis" );  # Initialise the product
$tm->connect_to_sella();

if ( defined( $tm->{ SellaCategories }->{ $cat } ) ) {
    print "Its a category !\n";
}
else {
    print "Its NOT a category\n";
}
exit(0);

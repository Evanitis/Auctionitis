use strict;
use Auctionitis;

my $tm;

my $copykey = shift;

$tm = Auctionitis->new();
$tm->initialise(Product => "Auctionitis");  # Initialise the product
$tm->DBconnect();                          # Connect to the database
$tm->copy_auction_record(   AuctionKey       =>  $copykey );

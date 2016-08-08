#!perl -w
#--------------------------------------------------------------------

use strict;
use Auctionitis;

my $tm;

$tm = Auctionitis->new();
$tm->initialise(Product => "Auctionitis");  # Initialise the product
$tm->DBconnect(); 

my $lk = $tm->get_last_auction_key();

print "Returned Value is: ".$lk."\n";

# Success.

print "Done\n";
exit(0);

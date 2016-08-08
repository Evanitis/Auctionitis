#!perl -w
#--------------------------------------------------------------------
# function to test the auction load process
# Other program notes:
#--------------------------------------------------------------------

use strict;
use Auctionitis;

my $tm = Auctionitis->new();
$tm->initialise( Product => "Auctionitis" );  # Initialise the product
$tm->DBconnect();

my $balance = '53.97';

$tm->set_current_balance( Balance => $balance );

        
# Success.

print "Done\n";
exit(0);

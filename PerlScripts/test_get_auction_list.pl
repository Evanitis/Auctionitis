#!perl -w
#--------------------------------------------------------------------
# gettmdata.pl retrieve data from trademe for analysis and automation
# to run the script: perl.exe c:\evan\trademe\gettmdata.pl 
#
# Other program notes:
#--------------------------------------------------------------------

use strict;
use Auctionitis;

my @inarray = (100000, 200000, 300000, 400000, 5000, 600000);

my $tm = Auctionitis->new();

$tm->initialise(Product => "Auctionitis");  # Initialise the product
$tm->DBconnect("Auctionitis103");           # Connect to the database

$tm->get_auction_records(@inarray);

# Success.

print "Done\n";
exit(0);

#!perl -w
#--------------------------------------------------------------------
# gettmdata.pl retrieve data from trademe for analysis and automation
# to run the script: perl.exe c:\evan\trademe\gettmdata.pl 
#
# Other program notes:
#--------------------------------------------------------------------

use strict;
use Auctionitis;

my ($loaded);

my $tm = Auctionitis->new();
$tm->initialise(Product => "Auctionitis");  # Initialise the product
$tm->DBconnect();                          # Connect to the database

$loaded = $tm->get_uploaded_auctions();

foreach my $auction ( @$loaded ) {
            print " Auction Key: \t$auction->{ AuctionKey }  Auction Key: \t$auction->{ AuctionRef }\n";
            $tm->set_auction_closed(AuctionKey => $auction->{ AuctionKey });
}

# Success.

print "Done\n";
exit(0);

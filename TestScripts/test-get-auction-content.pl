#!perl -w
#--------------------------------------------------------------------
# gettmdata.pl retrieve data from trademe for analysis and automation
# to run the script: perl.exe c:\evan\trademe\gettmdata.pl 
#
# Other program notes:
#--------------------------------------------------------------------

use strict;
use Auctionitis;

my $tm = Auctionitis->new();
$tm->initialise( Product => "Auctionitis" );  # Initialise the product

my $auctionref = '923901215';
                           
$tm->login(
    TradeMeID   => 'ToyPlanet'                  ,
    UserID      => 'trademe1@toyplanet.co.nz'   ,
    Password    => 'hfd67wqe'                   ,
);

$tm->{ Debug } = "1";

my $auctiondata = $tm->get_auction_content( AuctionRef => $auctionref );

if ( defined( $auctiondata ) ) {
    print "Auction Page Content\n";
    print "--------------------\n";
    print $auctiondata."\n";
}
else {
    print "No auction data found\n";
    print $tm->{ ErrorStatus }."\n";
    print $tm->{ ErrorMessage }."\n";
}

print "Done\n";
exit(0);

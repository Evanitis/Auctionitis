#!perl -w
#--------------------------------------------------------------------
# gettmdata.pl retrieve data from trademe for analysis and automation
# to run the script: perl.exe c:\evan\trademe\gettmdata.pl 
#
# Other program notes:
#--------------------------------------------------------------------

use strict;
use Auctionitis;

my $testref = shift;

my $tm = Auctionitis->new();
$tm->initialise( Product => "Auctionitis" );    # Initialise the product

#$tm->login(
#    TradeMeID   =>  'Topmaq1'                       ,
#    UserID      =>  'tmsales@discoverconcord.com'   ,
#    Password    =>  'trainersgay'                   ,
#);

$tm->login(
    TradeMeID   =>  'TopRank'                       ,
    UserID      =>  'traceymackenzie@irobot.co.nz'  ,
    Password    =>  'jaymz94'                       ,
);


my $auctions = $tm->get_current_auctions_hashref();


my $counter = 0;

foreach my $a ( sort keys %$auctions ) {


    print "Current Auction: ".$a."\n";

    $counter++;

}

print "\nRetrieved $counter CURRENT auctions\n\n";

if ( exists( $auctions->{ $testref } ) ) {
    print "\nAuction $testref is current\n";
}
else {
    print "\nAuction $testref is NOT current\n";
}

# Success.

print "Done\n";
exit(0);

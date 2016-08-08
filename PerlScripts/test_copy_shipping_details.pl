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

$tm->initialise(Product => "Auctionitis");
$tm->DBconnect();                           # Connect to the database

$tm->copy_shipping_details_records(
    FromAuctionKey  =>  3 ,
    ToAuctionKey    =>  2 ,
);

print "$tm->{StatusMessage}\n";

# Success.

print "Done\n";
exit(0);

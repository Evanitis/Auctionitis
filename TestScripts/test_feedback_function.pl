#--------------------------------------------------------------------
# gettmdata.pl retrieve data from trademe for analysis and automation
# to run the script: perl.exe c:\evan\trademe\gettmdata.pl 
#
# Other program notes:
#--------------------------------------------------------------------

use strict;
use Tradar;

my $tm = Tradar->new();

$tm->login(
    UserID      =>  "buy.tiles\@gmail.com"  ,
    Password    =>  "buymore tiles"         ,
);

$tm->put_feedback(
    AuctionRef  => "150656231"  ,
    SaleType    => "Auction"    ,
    BidderID    => "473217"     ,
    Feedback    => "Good trade, everything A1 - recommended",
);

print "Done\n";
exit(0);


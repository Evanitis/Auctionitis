#!perl -w

use strict;

my $auctionref = "123456789";
my $req = "";
my $url = "http://www.TradeMe.co.nz/MyTradeMe/MakeAnOffer.aspx";
my $hasbidders = "1";
my $haswatchers = "1";
my $offerduration = "1";
my $offeramount = "\$20.00";

my $code = <<EOD; 
$req = POST $url,
[  "id"              =>  $auctionref,
"status"             =>  'data',
"offer_price"        =>  $offeramount,
"hasBidders"         =>  $hasbidders,
"hasWatchers"        =>  $haswatchers,
"valid_for"          =>  $offerduration,
"bidder_id_1534562"  =>  'on',
EOD
print $code."\n\n";

$code .= "\"bidder_id_1534563\"  =>  'on',\n";
$code .= "\"bidder_id_1534563\"  =>  'on',\n";
$code .= "\"bidder_id_1534565\"  =>  'on',\n";
$code .= "\"bidder_id_1534566\"  =>  'on',\n";
$code .= "]";

$offeramount = "30.00";

print $code."\n\n";

# Success.

print "Done\n";
exit(0);

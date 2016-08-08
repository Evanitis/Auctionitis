#--------------------------------------------------------------------
# gettmdata.pl retrieve data from trademe for analysis and automation
# to run the script: perl.exe c:\evan\trademe\gettmdata.pl 
#
# Other program notes:
#--------------------------------------------------------------------

use strict;
use Auctionitis;

my $tm = Auctionitis->new();
$tm->initialise( Product => "Auctionitis" );    # Initialise the product


$tm->login(
    TradeMeID   => 'Auctionitis'                ,
    UserID      => 'evan@auctionitis.co.nz'     ,
    Password    => 'runestaff'                  ,
);

# Set the Dbug level to 2

$tm->{ Debug } = "2";

$tm->put_trademe_comment(
    AuctionRef  => '227442932'  ,
    Comment     => 'I can put a quarto one up for you if you are after one - just ask another question' ,
);

print "Done\n";
exit(0);


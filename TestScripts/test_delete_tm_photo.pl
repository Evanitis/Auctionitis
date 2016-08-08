#!perl -w
#--------------------------------------------------------------------
# gettmdata.pl retrieve data from trademe for analysis and automation
# to run the script: perl.exe c:\evan\trademe\gettmdata.pl 
#
# Other program notes:
#--------------------------------------------------------------------

use strict;
use Auctionitis;

my @photos;

my $tm = Auctionitis->new();

$tm->initialise(Product => "Auctionitis");
$tm->DBconnect();                           # Connect to the database

$tm->login();

$tm->delete_tm_photo(13392163);

# Success.

print "Done\n";
exit(0);

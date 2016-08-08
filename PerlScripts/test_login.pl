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
$tm->login(
    TradeMeID   =>  "auctionitis"               ,
    UserID      =>  "evan\@auctionitis.co.nz"   ,
    Password    =>  "runestaff"                 ,
);

print "$tm->{ StatusMessage }\n";
print "LogIn ID: $tm->{ LoggedInID}\n";
print "Member #: $tm->{ MemberID  }\n";

# Success.

print "Done\n";
exit(0);

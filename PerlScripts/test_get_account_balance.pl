#!perl -w
#--------------------------------------------------------------------
# gettmdata.pl retrieve data from trademe for analysis and automation
# to run the script: perl.exe c:\evan\trademe\gettmdata.pl 
#
# Other program notes:
#--------------------------------------------------------------------

use strict;
use Auctionitis;

my $auction = shift;

my $tm = Auctionitis->new();

$tm->initialise(Product => "Auctionitis");

$tm->login();

if ( $tm->{ ErrorMessage } ne "" ) {
    print "$tm->{ ErrorMessage }\n";
}

my $balance = $tm->get_account_balance();

print "Account Balance for $tm->{ TradeMeID } is: $balance\n";              

# Success.

print "Done\n";
exit(0);


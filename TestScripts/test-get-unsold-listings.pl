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
$tm->initialise( Product => "Auctionitis" );    # Initialise the product
$tm->DBconnect();                               # Connect to the database

$tm->login();

my $unsold = $tm->get_unsold_listings();
print scalar( @$unsold )." Unsold listings:\n";

foreach my $a ( @$unsold ) {
    print " Unsold: $a->{AuctionRef } Closes $a->{ CloseDate } at $a->{ CloseTime }\n";
}


# Success.

print "Done\n";
exit(0);

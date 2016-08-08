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

$tm->initialise( Product => "Auctionitis" );

$tm->login(
    TradeMeID   =>  'Topmaq1'                       ,
    UserID      =>  'tmsales@discoverconcord.com'   ,
    Password    =>  'trainersgay'                   ,
);

print "$tm->{ ErrorMessage }\n";

$tm->{ ListLimitAllowance } = 0 if not defined( $tm->{ ListLimitAllowance } );

my $limit = $tm->get_free_listing_limit();

my $ccount = $tm->get_current_auction_count();

my $available = $tm->get_free_listing_limit() - $tm->get_current_auction_count();

print "Limit for $tm->{TradeMeID} is: $limit\n";              
# print "Calculated auction count is: $auctions\n";              
print "Current auction count is: $ccount\n";              
print "Free listings left      : $available\n";              
print "List Limit Allowance    : $tm->{ ListLimitAllowance }\n";
print "Limit test val: ".( $tm->{free_listing_limit} + $tm->{ ListLimitAllowance } )."\n";

sleep 10;

while ( $ccount < $limit ) {

    if ( $ccount  ge ( $limit + $tm->{ ListLimitAllowance } ) ) {
        print "C: $ccount L: $limit A: $tm->{ ListLimitAllowance }\n";
        print "Failed\n";
    }
    else {
        print "C: $ccount L: $limit A: $tm->{ ListLimitAllowance }\n";
        print "Passed\n";
    }
    $ccount++;
}

# Success.

print "Done\n";
exit(0);


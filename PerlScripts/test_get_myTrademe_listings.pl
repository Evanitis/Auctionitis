#!perl -w
#--------------------------------------------------------------------
# gettmdata.pl retrieve data from trademe for analysis and automation
# to run the script: perl.exe c:\evan\trademe\gettmdata.pl 
#
# Other program notes:
#--------------------------------------------------------------------

use strict;
use Auctionitis;

my (@current, @sold, @unsold, %TMauctions, $auction, $loaded, @closed);

my $tm = Auctionitis->new();
$tm->initialise(Product => "Auctionitis");  # Initialise the product
$tm->DBconnect();                          # Connect to the database

$tm->login();

@current = $tm->get_curr_listings();
print scalar(@current)." current listings:\n";

foreach $auction ( @current ) {
    $TMauctions{ $auction } = 1;
#    print "Current: $auction\n";
}

@sold = $tm->get_sold_listings();
print scalar(@sold)."Sold listings:\n";

foreach $auction ( @sold ) {
    $TMauctions{ $auction } = 1;
#    print "  Sold: $auction\n";
}

@unsold = $tm->get_unsold_listings();
print scalar(@unsold)." Unsold listings:\n";

foreach $auction ( @unsold ) {
    $TMauctions{ $auction } = 1;
#    print " Unsold: $auction\n";
}

$loaded = $tm->get_uploaded_auctions();
print scalar(@$loaded)." Uploaded listings:\n";

# load up a hash with all auctions currently  on TradeMe

foreach $auction ( @current ) {
    $TMauctions{ $auction } = 1;
    print " Current: $auction\n";
}

foreach my $auction ( @current ) {
    if (not defined %TMauctions->{ $auction } ) {
            print " Current Auction $auction not stored in Hash \n";
    }
}

foreach $auction ( @sold ) {
    $TMauctions{ $auction } = 1;
    print " Sold: $auction\n";
}

foreach my $auction ( @sold ) {
    if (not defined %TMauctions->{ $auction } ) {
            print " Sold Auction $auction not stored in Hash \n";
    }
}

foreach $auction ( @unsold ) {
    $TMauctions{ $auction } = 1;
    print " Unsold: $auction\n";
}

foreach my $auction ( @unsold ) {
    if (not defined %TMauctions->{ $auction } ) {
            print " Unsold Auction $auction not stored in Hash \n";
    }
}

$loaded = $tm->get_uploaded_auctions();

my $known = 0;
my $unknown = 0;

foreach my $auction ( @$loaded ) {

    if (not defined %TMauctions->{ $auction->{ AuctionRef } } ) {
            print " Unknown: $auction->{ AuctionRef } \n";
            $known++;
    } else {
            print " Known: $auction->{ AuctionRef } \n";
            $unknown++;
    }
}

print "Known: $known Unknown: $unknown\n";

# Success.

print "Done\n";
exit(0);

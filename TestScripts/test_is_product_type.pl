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
$tm->initialise(Product => "Auctionitis");  # Initialise the product
$tm->DBconnect();                          # Connect to the database


my $PT = "Tracey";
my $AC = "Tracey";

if ( not $tm->is_product_type( $PT ) ) {

    print "Adding Product Type $PT\n";
    $tm->add_product_type( $PT );
    print "Added Product Type $PT\n";
    
}
else {
    print "Product Type $PT already exists\n";

}

if ( not $tm->is_product_type( $PT ) ) {

    print "Adding Product Type $PT\n";
    $tm->add_product_type( $PT );
    print "Added Product Type $PT\n";
    
}
else {
    print "Product Type $PT already exists\n";

}

if ( not $tm->is_auction_cycle( $AC ) ) {

    print "Adding Auction Cycle $AC\n";
    $tm->add_auction_cycle( $AC );
    print "Added Auction Cycle $AC\n";
    
}
else {
    print "Auction Cycle $AC already exists\n";

}

if ( not $tm->is_auction_cycle( $AC ) ) {

    print "Adding Auction Cycle $AC\n";
    $tm->add_auction_cycle( $AC );
    print "Added Auction Cycle $AC\n";
    
}
else {
    print "Auction Cycle $AC already exists\n";

}

# Success.

print "Done\n";
exit(0);

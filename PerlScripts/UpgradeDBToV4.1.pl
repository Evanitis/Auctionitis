#!perl -w

use strict;
use DBI;
use Auctionitis;

#------------------------------------------------------------------------------------------------------------
# SQL Statements for Columns to be added
#------------------------------------------------------------------------------------------------------------

my $dbSQL01 = qq { UPDATE Auctions SET SaleType = NULL WHERE SaleType NOT IN('FPOFFER', 'BUYNOW', 'AUCTION') };

my $dbDef01 = qq { ALTER TABLE Auctions ADD COLUMN PromotionFee     CURRENCY NOT NULL DEFAULT 0 };
my $dbDef02 = qq { ALTER TABLE Auctions ADD COLUMN ListingFee       CURRENCY NOT NULL DEFAULT 0 };
my $dbDef03 = qq { ALTER TABLE Auctions ADD COLUMN SuccessFee       CURRENCY NOT NULL DEFAULT 0 };
my $dbDef04 = qq { ALTER TABLE Auctions ADD COLUMN CurrentBid       CURRENCY NOT NULL DEFAULT 0 };
my $dbDef05 = qq { ALTER TABLE Auctions ADD COLUMN ItemCost         CURRENCY NOT NULL DEFAULT 0 };
my $dbDef06 = qq { ALTER TABLE Auctions ADD COLUMN ShippingAmount   CURRENCY NOT NULL DEFAULT 0 };
my $dbDef07 = qq { ALTER TABLE Auctions ADD COLUMN DeliveryCost     CURRENCY NOT NULL DEFAULT 0 };
my $dbDef08 = qq { ALTER TABLE Auctions ADD COLUMN WasPayNow        LOGICAL  NOT NULL DEFAULT 0 };

my $tm = Auctionitis->new();
$tm->initialise( Product => "Auctionitis" );    # Initialise the product
$tm->DBconnect( ConnectOnly => 1 );             # Connect to the database

# Set all SaleType Values to NULL

my $sth = $tm->{ DBH }->do( $dbSQL01 ) || print "Error Setting SaleType Column to NULL:\n$DBI::errstr\n";

# Add the new columns i fthey don't exist

if ( not $tm->DBColumn_exists( Table => 'Auctions', Column => 'PromotionFee' ) ) {
    print "Adding Column Promotion Fee\n";
    my $sth = $tm->{ DBH }->do( $dbDef01 ) || print "Error adding Column PromotionFee to table Auctions:\n$DBI::errstr\n";
}
else {
    print "Column Promotion Fee already exists\n";
}

if ( not $tm->DBColumn_exists( Table => 'Auctions', Column => 'ListingFee' ) ) {
    print "Adding Column Listing Fee\n";
    my $sth = $tm->{ DBH }->do( $dbDef02 ) || print "Error adding Column ListingFee to table Auctions:\n$DBI::errstr\n";
}
else {
    print "Column Listing Fee already exists\n";
}

if ( not $tm->DBColumn_exists( Table => 'Auctions', Column => 'SuccessFee' ) ) {
    print "Adding Column Success Fee\n";
    my $sth = $tm->{ DBH }->do( $dbDef03 ) || print "Error adding Column SuccessFee to table Auctions:\n$DBI::errstr\n";
}
else {
    print "Column Success Fee already exists\n";
}

if ( not $tm->DBColumn_exists( Table => 'Auctions', Column => 'CurrentBid' ) ) {
    print "Adding Column Current Bid\n";
    my $sth = $tm->{ DBH }->do( $dbDef04 ) || print "Error adding Column CurrentBid to table Auctions:\n$DBI::errstr\n";
}
else {
    print "Column Current Bid already exists\n";
}

if ( not $tm->DBColumn_exists( Table => 'Auctions', Column => 'ItemCost' ) ) {
    print "Adding Column Item Cost\n";
    my $sth = $tm->{ DBH }->do( $dbDef05 ) || print "Error adding Column ItemCost to table Auctions:\n$DBI::errstr\n";
}
else {
    print "Column Item Cost already exists\n";
}

if ( not $tm->DBColumn_exists( Table => 'Auctions', Column => 'ShippingAmount' ) ) {
    print "Adding Column Shipping Amount\n";
    my $sth = $tm->{ DBH }->do( $dbDef06 ) || print "Error adding Column ShippingAmount to table Auctions:\n$DBI::errstr\n";
}
else {
    print "Column Current Bid already exists\n";
}

if ( not $tm->DBColumn_exists( Table => 'Auctions', Column => 'DeliveryCost' ) ) {
    print "Adding Column DeliveryCost\n";
    my $sth = $tm->{ DBH }->do( $dbDef07 ) || print "Error adding Column DeliveryCost to table Auctions:\n$DBI::errstr\n";
}
else {
    print "Column Current Bid already exists\n";
}

if ( not $tm->DBColumn_exists( Table => 'Auctions', Column => 'WasPayNow' ) ) {
    print "Adding Column WasPayNow\n";
    my $sth = $tm->{ DBH }->do( $dbDef08 ) || print "Error adding Column WasPayNow to table Auctions:\n$DBI::errstr\n";
}
else {
    print "Column Current Bid already exists\n";
}

print "Done\n";
exit(0);

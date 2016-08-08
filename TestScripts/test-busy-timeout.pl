use strict;
use Auctionitis;

my $tm = Auctionitis->new();
$tm->initialise(Product => "Auctionitis");  # Initialise the product
$tm->DBconnect();                          # Connect to the database

# Create Statemen to update product types

my $SQL = $tm->{ DBH }->prepare( qq { 
    UPDATE      Auctions 
    SET         ProductType = 'NOT-EVAN'
} );

print $tm->timenow." Begin Executing SQL\n";

$SQL->execute();

print $tm->timenow." SQL Execution Complete\n";


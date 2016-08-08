#!perl -w

use strict;
use Auctionitis;

my $tm = Auctionitis->new();

$tm->initialise( Product => "Auctionitis" );
$tm->DBconnect();                           # Connect to the database

my $ref  = 324374859;
my $type = 'AUCTION';

my $key = $tm->get_auction_key_by_saletype(
    AuctionRef  =>  $ref  ,
    SaleType    =>  $type ,
);

print $tm->{ ErrorMessage }."\n" if $tm->{ ErrorStatus };
print "Auction Key $key for Auction $ref sale type $type found\n" if defined( $key );
print "Auction Key for Auction $ref sale type $type NOT found\n" if not defined( $key );

$key = $tm->get_auction_key( $ref ) if not defined( $key );

print $tm->{ ErrorMessage }."\n" if $tm->{ ErrorStatus };
print "Auction Key $key for Auction $ref found\n" if defined( $key );
print "Auction Key for Auction $ref NOT found\n" if not defined( $key );

# Success.

print "Done\n";
exit(0);

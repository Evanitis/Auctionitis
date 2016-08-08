use strict;
use Auctionitis;

my $tm;

my $copykey = shift;

$tm = Auctionitis->new();
$tm->initialise(Product => "Auctionitis");  # Initialise the product
$tm->DBconnect();                          # Connect to the database
        $tm->insert_category_record( Description     => 'Description'   ,
                                     Category        => 1234            ,
                                     Parent          => 0,
                                     Sequence        => 1,
        );

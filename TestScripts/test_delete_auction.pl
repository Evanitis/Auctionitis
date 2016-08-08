
use Auctionitis;

my $tm = Auctionitis->new();

$tm->initialise(Product => "Auctionitis");
$tm->login();
    
$tm->delete_auction(AuctionRef => "65559319");

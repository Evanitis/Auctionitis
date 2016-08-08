
use Auctionitis;

my $tm = Auctionitis->new();

$tm->initialise(Product => "Auctionitis");
$tm->DBconnect();

my $SQL="SELECT * FROM Auctions";

$tm->export_data( SQL => $SQL );
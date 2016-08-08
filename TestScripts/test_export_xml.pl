
use Auctionitis;

my $tm = Auctionitis->new();

$tm->initialise(Product => "Auctionitis");
$tm->DBconnect();

my $SQL="SELECT * FROM Auctions";

$tm->export_XML( Outfile => "C:\\Program Files\\Auctionitis\\Output\\Evan.xml", SQL => $SQL);

use Auctionitis;

my $tm = Auctionitis->new();

$tm->initialise(Product => "Auctionitis");
$tm->DBconnect();

my $categories = $tm->get_remote_category_table();

foreach my $record (@$categories) {

    print "Category $record->{ Description } $record->{ Category } Parent: $record->{ Parent } Sequence: $record->{ Sequence }\n";

}

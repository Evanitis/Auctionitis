#!perl -w
#--------------------------------------------------------------------
use Auctionitis;

my ($c,$v,$h);

my $tm = Auctionitis->new();
$tm->initialise(Product => "Auctionitis");  # Initialise the product
$tm->DBconnect();                          # Connect to the database

$h="0";
$v="0";

$c="10";

$v = $tm->is_valid_category($c);
$h = $tm->has_children($c);

print "Category: $c\n";
print "   Valid: $v\n";
print "Children: $h\n";

print "\nDone\n";


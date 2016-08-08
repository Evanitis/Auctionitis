
use Auctionitis;

my $tm = Auctionitis->new();

$tm->initialise(Product => "Auctionitis");

my $FH;
my $readmefile = $tm->{ DataDirectory }."\\readme.txt";
my $readmedata = $tm->get_category_readme();

print $readmedata;

unlink $readmefile;

open($FH, "> $readmefile");

print $FH $readmedata;

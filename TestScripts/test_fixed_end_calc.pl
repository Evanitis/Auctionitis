#!perl -w
#--------------------------------------------------------------------
use Auctionitis;

my $days = shift;
my $ints = shift;

my $tm = Auctionitis->new();

$tm->initialise(Product => "Auctionitis");  # Initialise the product
$tm->DBconnect();                          # Connect to the database

$startd = $tm->datenow();
$startt = $tm->timenow();
$closed = $tm->fixeddate($days);
$closet = $tm->fixedtime($ints);
$fixedd = $tm->TMFixedEndDate($days);
$fixedt = $tm->TMFixedEndTime($ints);

print "\nAuctionitis values\n";
print "     End Days: $days\n";
print "     End Time: $ints\n";
print "   Start Date: $startd\n";
print "         Time: $startt\n";
print "DB Close Date: $closed\n";
print "         Time: $closet\n";
print "TM Close Date: $fixedd\n";
print "         Time: $fixedt\n";



print "\nDone...\n";

sleep 5;

exit(0);

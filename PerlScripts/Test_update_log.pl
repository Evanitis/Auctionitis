use strict;
use Auctionitis;

my $LogText = shift;

my $tm = Auctionitis->new();
print "Created new Auctionitis object\n";
$tm->initialise(Product => "Auctionitis");
print "Product initialised\n";
$tm->update_log($LogText);
print "Updating log\n";

# Success.

print "Done\n";
exit(0);

use strict;
use Auctionitis;

my $tm = Auctionitis->new();

my $day = shift;

$tm->initialise(Product => "Auctionitis");  # Initialise the product
$tm->DBconnect();                          # Connect to the database

$tm->set_Schedule_properties($day);

print "         Load All: $tm->{ LoadAll            }\n";
print "       Load Cycle: $tm->{ LoadCycle          }\n";
print "  Load Cycle Name: $tm->{ LoadCycleName      }\n";
print "       Relist All: $tm->{ RelistAll          }\n";
print "     Relist Cycle: $tm->{ RelistCycle        }\n";
print "Relist Cycle Name: $tm->{ RelistCycleName    }\n";

# Success.

print "Done\n";
exit(0);

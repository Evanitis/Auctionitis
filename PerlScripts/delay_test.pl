#!perl -w
#--------------------------------------------------------------------
# Bulk_load.pl Program to bulk load auctios from the auction input
# database
# Other program notes:
#--------------------------------------------------------------------

use strict;
use Auctionitis;

my $tm = Auctionitis->new();
my $delay = $tm->load_interval();

print "$delay\n";

$delay = $delay * 60;

print "$delay\n";


print "Done\n";

exit(0);
#!perl -w
#--------------------------------------------------------------------
# gettmdata.pl retrieve data from trademe for analysis and automation
# to run the script: perl.exe c:\evan\trademe\gettmdata.pl 
#
# Other program notes:
#--------------------------------------------------------------------

use strict;
use Auctionitis;

my $tm = Auctionitis->new();
$tm->initialise(Product => "Auctionitis");  # Initialise the product
my $current;
my @completed;

$tm->login();


$current = $tm->get_curr_listings();

my $count = scalar(@$current);
print "Count $count\n";

foreach my $auction (@$current) {

    print "Auction: $auction->{AuctionRef} Closes: $auction->{CloseDate} at $auction->{CloseTime}\n";
}

$current = $tm->get_sold_listings();

$count = scalar(@$current);
print "Count $count\n";

foreach my $auction (@$current) {

    print "Auction: $auction->{AuctionRef} Closed: $auction->{CloseDate} at $auction->{CloseTime}\n";
}

$current = $tm->get_unsold_listings();

$count = scalar(@$current);
print "Count $count\n";

foreach my $auction (@$current) {

    print "Auction: $auction->{AuctionRef} Closed: $auction->{CloseDate} at $auction->{CloseTime}\n";
}

print "$tm->{StatusMessage}\n";

# Success.

print "Done\n";
exit(0);

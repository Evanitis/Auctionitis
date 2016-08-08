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
my $today;

$tm->login();

$current = $tm->get_curr_listings();
$today = $tm->datenow();

my $count = scalar(@$current);
print "Count: $count\n";
print "Today: $today\n";

# Convert month number into character string to match sold listing format

$today =~ m/(.+?)-(.+?)-(.+)/;

my $mm;

if      ( $2 ==  1) { $mm = 'Jan'; }
elsif   ( $2 ==  2) { $mm = 'Feb'; }
elsif   ( $2 ==  3) { $mm = 'Mar'; }
elsif   ( $2 ==  4) { $mm = 'Apr'; }
elsif   ( $2 ==  5) { $mm = 'May'; }
elsif   ( $2 ==  6) { $mm = 'Jun'; }
elsif   ( $2 ==  7) { $mm = 'Jul'; }
elsif   ( $2 ==  8) { $mm = 'Aug'; }
elsif   ( $2 ==  9) { $mm = 'Sep'; }
elsif   ( $2 == 10) { $mm = 'Oct'; }
elsif   ( $2 == 11) { $mm = 'Nov'; }
elsif   ( $2 == 12) { $mm = 'Dec'; }

$today = $1."-".$mm."-".$3;
print "Today: $today\n";

$today = "28-Mar-2006";

my $now = time_in_seconds( $tm->timenow() );

print "Now: $now Timenow: $tm->timenow() \n";

foreach my $auction (@$current) {

    if ( $auction->{CloseDate} eq $today ) {
        my $waitsecs = time_in_seconds($auction->{CloseTime}) - $now;
        print "Auction: $auction->{AuctionRef} Closes: $auction->{CloseDate} at $auction->{CloseTime} ($waitsecs Seconds away)\n";
    }
}

print "$tm->{StatusMessage}\n";

# Success.

print "Done\n";
exit(0);


sub time_in_seconds {

    my $timeval = shift;
    
    $timeval =~ m/(.+?):(.+?):(.+)/;
    
    my $seconds = ($1*60*60)+($2*60)+$3;

    return $seconds;
}
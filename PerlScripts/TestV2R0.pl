#!perl -w
#
# test function script for get current listings, get sold listings, get unsold listings

use Test::More "no_plan";

use Auctionitis;

#--------------------------------------------
# tests start here - profile 1
#--------------------------------------------

my $tm = Auctionitis->new();

isa_ok($tm, "Auctionitis");

# execute the initialise method and then check the proprties that are set by this method

$tm->initialise(Product => "Auctionitis");

is($tm->{Product},                      "AUCTIONITIS",                  "Test Product name property");     
is($tm->{Profile},                      "Default",                      "Test Profile property");     

is($tm->{UserID},                       "evan\@auctionitis\.co\.nz",       "Test User ID property");       
is($tm->{Password},                     "crusher66",                      "Test Password property");     
is($tm->{load_interval},                "0",                            "Test drip feed  interval property");     
is($tm->{LogDirectory},                 "C:\\Program Files\\Auctionitis", "Test Log directory value");     

print "Delaying 10 seconds...";
sleep 10;
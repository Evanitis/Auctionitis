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

is($tm->{UserID},                       "tracey\@irobot\.co\.nz",       "Test User ID property");       
is($tm->{Password},                     "wicked1",                      "Test Password property");     
is($tm->{load_interval},                "0",                            "Test drip feed  interval property");     

is($tm->CurrencyFormat(1001266.52),     "\$1,001,266.52",               "Test Currency formatting function");

is($tm->{is_connected},                 "0",                            "Test Connection property before log in");     

# execute the login method and then check the proprties that are set by this method

$tm->login();

is($tm->{is_connected},                 "1",                            "Test Connection property after log in");     
is($tm->{MemberID},                     "37935",                        "Check member ID extraction regexp");        # Traceys ID

# execute the get current listings method and then check the proeprties that are set by this method
# also check that the returned array matches the proprty values set by the method

my @current = $tm->get_curr_listings();

is($tm->{curr_listings},                "207",                          "Check retrieve current listings function");
is($tm->{curr_listings_pp},             "25",                           "Check listings per page calculation");
is($tm->{curr_pages},                   "9",                            "Check number of current auction pages function");

# Check count of items in returned array

my $number = $#current + 1;
is($number,                             "207",                          "Check number of elements in returned current listing array");

# Check sold listings retieve function

@current = $tm->get_curr_listings();

is($tm->{sold_listings},                "207",                          "Check retrieve sold listings function");
is($tm->{sold_listings_pp},             "25",                           "Check sold listings per page calculation");
is($tm->{sold_pages},                   "9",                            "Check number of sold auction pages function");

# Check count of items in returned array

$number = $#current + 1;
is($number,                             "207",                          "Check number of elements in returned current listing array");

# check unsold auctions retrieval function

@current = $tm->get_curr_listings();

is($tm->{unsold_listings},              "207",                          "Check retrieve unsold listings function");
is($tm->{unsold_listings_pp},           "25",                           "Check unsold listings per page calculation");
is($tm->{unsold_pages},                 "9",                            "Check number of unsold auction pages function");

$number = $#current + 1;
is($number,                             "207",                          "Check number of elements in returned current listing array");

# Test statistics retrieval functions

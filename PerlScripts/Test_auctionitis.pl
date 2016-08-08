#!perl -w

use Test::More "no_plan";

use Auctionitis;

#--------------------------------------------
# tests start here - profile 1
#--------------------------------------------

my $tm = Auctionitis->new();

isa_ok($tm, "Auctionitis");

# execute the initialise method and then check the proprties that are set by this method

$tm->initialise(Product => "Auctionitis");

is( $tm->{ Product          },          "AUCTIONITIS",                  "Test Product name property");     
is( $tm->{ Profile          },          "Default",                      "Test Profile property");     
is( $tm->{ UserID           },          "tracey\@irobot\.co\.nz",       "Test User ID property");       
is( $tm->{ Password         },          "wicked1",                      "Test Password property");     
is( $tm->{ load_interval    },          "4",                            "Test drip feed interval property");     
is( $tm->CurrencyFormat(1001266.52),    "\$1,001,266.52",               "Test Currency formatting function");

is( $tm->{is_connected},                "0",                            "Test Connection property before log in");     

# execute the login method and then check the proprties that are set by this method

$tm->login();

is( $tm->{ is_connected     },          "1",                            "Test Connection property after log in");     
is( $tm->{ MemberID},                   "37935",                        "Check member ID extraction regexp");        # Traceys ID
# is($tm->{MemberID},                     "457799",                       "Check member ID extraction regexp");        # Evans ID

is($tm->{LoggedInID},                   "TopRank",                      "Check member ID extraction regexp");        # 

# test the get bidder id function

my @bidderid   = $tm->get_bidder_id(auctionref    => "20111752",
                                    buyerid       => "dianaluvselvis");

is($bidderid[0],                        "824984",                                       "Check Extraction of Bidder ID"); 
is($bidderid[1],                        "successful_bidder",                            "Check Extraction of Bidder Role"); 

# Test the get auction details function

my %auctiondata = $tm->get_auction_details(22368345);

print "Auction Description:\n$auctiondata{Description}\n";

is($auctiondata{Title},                 "2.5ct Dark Blue Sapphire & Sterling Silver Ring",  "Check Auction Title");
is($auctiondata{Category},              "1700",                                         "Check Category");
is($auctiondata{Status},                "CURRENT",                                      "Check Status");
is($auctiondata{ReserveMet},            "0",                                            "Check Reserve Met");
is($auctiondata{CurrentBid},            "0",                                            "Check Current Bid");
is($auctiondata{BuyNowPrice},           "37.99",                                        "Check Buy Now Price");
is($auctiondata{StartingPrice},         "19.99",                                        "Check Starting Price");
is($auctiondata{ReservePrice},          "34.99",                                        "Check Reserve Price");
is($auctiondata{BrandNew},              "1",                                            "Check Brand New Flag");
is($auctiondata{Questions},             "0",                                            "Check Questions");
is($auctiondata{AutoExtend},            "1",                                            "Check AutoExtend");
is($auctiondata{SafeTrader},            "3",                                            "Check Safe Trader");
is($auctiondata{Bids},                  "0",                                            "Check Bids");
is($auctiondata{HighBidderID},          "",                                             "Check High Bidder ID");
is($auctiondata{HighBidder},            "",                                             "Check High Bidder");
is($auctiondata{HighBidderRating},      "0",                                            "Check High Bidder Rating");

# execute the get current listings method and then check the proeprties that are set by this method
# also check that the returned array matches the proprty values set by the method

my @current = $tm->get_curr_listings();

is($tm->{curr_listings},                "207",                          "Check retrieve current listings function");
is($tm->{curr_listings_pp},             "25",                           "Check listings per page calculation");
is($tm->{curr_pages},                   "9",                            "Check number of current auction pages function");

my $number = $#current + 1;

is($number,                             "207",                          "Check number of elements in returned current listing array");

# Test statistics retrieval functions

my %tmstats = $tm->get_TMStats();

is($tmstats{LoggedIn},                  "12487",                                        "Check Logged In total");
is($tmstats{Auctions},                  "216763",                                       "Check Auctions Total");

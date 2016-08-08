#!perl -w

use Test::More "no_plan";

use Auctionitis;

my $message;
my $detail;

#--------------------------------------------
# tests start here - profile 1
#--------------------------------------------

my $tm = Auctionitis->new();

isa_ok($tm, "Auctionitis");

$tm->initialise(Product => "Jafa");

is($tm->{Product},          "JAFA",                         "Product name property set correctly");     
is($tm->{Profile},          "Default",                      "Profile property set correctly");     

# is($tm->{UserID},           "evan\@auctionitis\.co\.nz",    "User ID property set correctly");       
# is($tm->{Password},         "crusher66",                    "Password property set correctly");     
is($tm->{UserID},           "tracey\@irobot\.co\.nz",       "User ID property set correctly");       
is($tm->{Password},         "wicked1",                      "Password property set correctly");     
is($tm->{DataDirectory},    "C:\\Evan\\jafa\\data",         "Data Directory property set correctly");
is($tm->{ResponseFile},     "feedline\.txt",                "Response file property set correctly"); 
is($tm->{InputFile},        "input-data\.txt",              "Input file property set correctly");    
is($tm->{TrustWeb},         "1",                            "TrustWeb property set correctly");     

$tm->login();

is($tm->{ErrorStatus},      "0",                            "Error Status  test 1");     
is($tm->{ErrorMessage},     "",                             "Error Message test 1");     
is($tm->{ErrorDetail},      "",                             "Error Detail  test 1");     

my @bidderid   = $tm->get_bidder_id(auctionref    => "20539411",
                                    buyerid       => "kazzy205");

is($bidderid[0],            "848670",                       "Test Extraction of Bidder ID   1"); 
is($bidderid[1],            "successful_bidder",            "Test Extraction of Bidder Role 1"); 

is($tm->{ErrorStatus},      "0",                            "Error Status  test 2");     
is($tm->{ErrorMessage},     "",                             "Error Message test 2");     
is($tm->{ErrorDetail},      "",                             "Error Detail  test 2");     

@bidderid   = $tm->get_bidder_id(auctionref       => "20539411",
                                    buyerid       => "maeva1");

is($bidderid[0],            "776808",                       "Test Extraction of Bidder ID   2"); 
is($bidderid[1],            "offer_recipient",              "Test Extraction of Bidder Role 2"); 

is($tm->{ErrorStatus},      "0",                            "Error Status  test 3");     
is($tm->{ErrorMessage},     "",                             "Error Message test 3");     
is($tm->{ErrorDetail},      "",                             "Error Detail  test 3");     

@bidderid   = $tm->get_bidder_id(auctionref       => "205394109",
                                    buyerid       => "evan");
                                    
$message = "Auction 205394109 does not appear to be a valid auction number";
$detail  = "";

is($tm->{ErrorStatus},      "1",                            "Error Status  test 4");     
is($tm->{ErrorMessage},     $message,                       "Error Message test 4");
is($tm->{ErrorDetail},      $detail,                        "Error Detail  test 4");     

@bidderid   = $tm->get_bidder_id(auctionref       => "20539411",
                                    buyerid       => "auctionitis");

$message = "Reference to buyer auctionitis not found for auction 20539411";
$detail  = "";

is($tm->{ErrorStatus},      "1",                            "Error Status  test 5");     
is($tm->{ErrorMessage},     $message,                       "Error Message test 5");
is($tm->{ErrorDetail},      $detail,                        "Error Detail  test 5");     

@bidderid   = $tm->get_bidder_id(auctionref       => "20564975",
                                    buyerid       => "mymoko");

$message = "Feedback already placed for mymoko on auction 20564975";
$detail  = "";

is($tm->{ErrorStatus},      "1",                            "Error Status  test 6");     
is($tm->{ErrorMessage},     $message,                       "Error Message test 6");
is($tm->{ErrorDetail},      $detail,                        "Error Detail  test 6");     

#--------------------------------------------
# tests start here - profile 1
#--------------------------------------------

my $tm2 = Auctionitis->new();

isa_ok($tm2, "Auctionitis");

$tm2->initialise(Product => "Jafa",
                 Profile => "Evan");

is($tm2->{Product},         "JAFA",                         "Product name property set correctly");     
is($tm2->{Profile},         "Evan",                         "Profile property set correctly");     
is($tm2->{UserID},          "personality2",                 "User ID property set correctly");       
is($tm2->{Password},        "password2",                    "Password property set correctly");     
is($tm2->{DataDirectory},   "C:\\Evan\\Jafa",               "Data Directory property set correctly");
is($tm2->{ResponseFile},    "feedline\.txt",                "Response file property set correctly"); 
is($tm2->{InputFile},       "FEEDBACK\.CSV",                "Input file property set correctly");    
is($tm2->{TrustWeb},        "1",                            "TrustWeb property set correctly");     

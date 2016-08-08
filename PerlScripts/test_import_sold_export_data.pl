use Auctionitis;

use strict;

my $days = shift;

if ( not defined($days) ) {
    $days = 7;
}

my $tm = Auctionitis->new();

$tm->initialise( Product => "Auctionitis" );

print $tm->{ ErrorMessage }."\n";

print " User ID:".$tm->{ UserID   }."\n";
print "Password:".$tm->{ Password }."\n";


$tm->login();

print $tm->{ ErrorMessage }."\n";

print "Begin Retrieving Sales data from TradeMe (".$tm->timenow().")\n";

my $salesdata = $tm->get_TM_sold_export_data();

print "Completed Retrieving Sales data from TradeMe (".$tm->timenow().")\n";

print "Retrieved Data:\n";

foreach my $record ( @$salesdata ) {

    print "Auction_Ref   : ". $record->{ Auction_Ref      }."\n";
    print "Title         : ". $record->{ Title            }."\n";
    print "Category      : ". $record->{ Category         }."\n";
    print "Sold_Date     : ". $record->{ Sold_Date        }."\n";
    print "Sold_Time     : ". $record->{ Sold_Time        }."\n";
    print "Sale_Type     : ". $record->{ Sale_Type        }."\n";
    print "Sale_Price    : ". $record->{ Sale_Price       }."\n";
    print "Ship_Cost1    : ". $record->{ Ship_Cost1       }."\n";
    print "Ship_Text1    : ". $record->{ Ship_Text1       }."\n";
    print "Ship_Cost2    : ". $record->{ Ship_Cost2       }."\n";
    print "Ship_Text2    : ". $record->{ Ship_Text2       }."\n";
    print "Ship_Cost3    : ". $record->{ Ship_Cost3       }."\n";
    print "Ship_Text3    : ". $record->{ Ship_Text3       }."\n";
    print "Ship_Cost4    : ". $record->{ Ship_Cost4       }."\n";
    print "Ship_Text4    : ". $record->{ Ship_Text4       }."\n";
    print "Ship_Cost5    : ". $record->{ Ship_Cost5       }."\n";
    print "Ship_Text5    : ". $record->{ Ship_Text5       }."\n";
    print "Ship_Cost6    : ". $record->{ Ship_Cost6       }."\n";
    print "Ship_Text6    : ". $record->{ Ship_Text6       }."\n";
    print "Ship_Cost7    : ". $record->{ Ship_Cost7       }."\n";
    print "Ship_Text7    : ". $record->{ Ship_Text7       }."\n";
    print "Ship_Cost8    : ". $record->{ Ship_Cost8       }."\n";
    print "Ship_Text8    : ". $record->{ Ship_Text8       }."\n";
    print "Ship_Cost9    : ". $record->{ Ship_Cost9       }."\n";
    print "Ship_Text9    : ". $record->{ Ship_Text9       }."\n";
    print "Ship_Cost10   : ". $record->{ Ship_Cost10      }."\n";
    print "Ship_Text10   : ". $record->{ Ship_Text10      }."\n";
    print "Pickup_Text   : ". $record->{ Pickup_Text      }."\n";
    print "Buyer_Name    : ". $record->{ Buyer_Name       }."\n";
    print "Buyer_Email   : ". $record->{ Buyer_Email      }."\n";
    print "Buyer_Address : ". $record->{ Buyer_Address    }."\n";
    print "Buyer_Postcode: ". $record->{ Buyer_Postcode   }."\n";
    print "Buyer_Message : ". $record->{ Buyer_Message    }."\n";
    print "Listing_Fee   : ". $record->{ Listing_Fee      }."\n";
    print "Promo_Fee     : ". $record->{ Promo_Fee        }."\n";
    print "Success_Fee   : ". $record->{ Success_Fee      }."\n";
    print "Refund_Status : ". $record->{ Refund_Status    }."\n";
    print "Start_Price   : ". $record->{ Start_Price      }."\n";
    print "Reserve_Price : ". $record->{ Reserve_Price    }."\n";
    print "BuyNow_Price  : ". $record->{ BuyNow_Price     }."\n";
    print "Start_Date    : ". $record->{ Start_Date       }."\n";
    print "Start_Time    : ". $record->{ Start_Time       }."\n";
    print "Duration      : ". $record->{ Duration         }."\n";
    print "Restrictions  : ". $record->{ Restrictions     }."\n";
    print "Featured      : ". $record->{ Featured         }."\n";
    print "Gallery       : ". $record->{ Gallery          }."\n";
    print "Bold          : ". $record->{ Bold             }."\n";
    print "Homepage      : ". $record->{ Homepage         }."\n";
    print "Extra_Photos  : ". $record->{ Extra_Photos     }."\n";
    print "Scheduled_End : ". $record->{ Scheduled_End    }."\n";
    print "Notes         : ". $record->{ Notes            }."\n";
    print "PayNow        : ". $record->{ PayNow           }."\n";
 
}

print "Done !\n";

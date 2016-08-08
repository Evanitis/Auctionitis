use strict;
use DBI;
use Win32::TieRegistry;

my ( $sth, $SQL );

my $dbh=DBI->connect('dbi:ODBC:Auctionitis') 
   || die "Error opening Auctions database: $DBI::errstr\n";
   $dbh->{ LongReadLen } = 65555;            # caters for retrieval of memo fields


#------------------------------------------------------------------------------------------------------------
# Test to determine whether the update has already been processed
#------------------------------------------------------------------------------------------------------------

$SQL = qq { SELECT COUNT(*) FROM DeliveryOptions WHERE Delivery_Option_Site = 'SELLA' AND Delivery_Option_Seq = 4 };

my $SQL_test_delivery_options = $dbh->prepare( $SQL );

$SQL_test_delivery_options->execute();
my $updated = $SQL_test_delivery_options->fetchrow_array;

if ( $updated ) {
    print "Sella Custom shipping option already applied\n";
    $SQL_test_delivery_options->finish();
    $dbh->disconnect;
    exit;
}

#------------------------------------------------------------------------------------------------------------
# SQL statements for changes to Auctionitis tables
#------------------------------------------------------------------------------------------------------------

# SQL statement to Add a delivery option

$SQL = qq { 
    INSERT INTO     DeliveryOptions     
                  ( Delivery_Option_Site    ,
                    Delivery_Option_Seq     ,
                    Delivery_Option_Text    ,
                    Delivery_Option_Value   )
    VALUES          ( ?, ?, ?, ? )     
};

my $SQL_add_delivery_option = $dbh->prepare( $SQL );

# Delete all Sella Delivery Options

$SQL = qq { DELETE FROM DeliveryOptions WHERE Delivery_Option_Site = 'SELLA' };

my $SQL_delete_delivery_options = $dbh->prepare( $SQL );

$SQL_delete_delivery_options->execute();

$SQL_add_delivery_option->execute( "SELLA",     0,  "Not Selected",                             "Not Sent to Sella"     );
$SQL_add_delivery_option->execute( "SELLA",     1,  "Free Shipping",                            "free"                  );
$SQL_add_delivery_option->execute( "SELLA",     2,  "Organise With Buyer",                      "org"                   );
$SQL_add_delivery_option->execute( "SELLA",     3,  "Specify Shipping Costs",                   "custom"                );
$SQL_add_delivery_option->execute( "SELLA",     4,  "Other",                                    "other"                 );

# Update existing auctions from shipping option 3 to 4

$SQL = qq {
    UPDATE  Auctions
    SET     ShippingOption  = 4
    WHERE   AuctionSite     = 'SELLA'
    AND     ShippingOption  = 3
};

my $SQL_update_auction_shipping_options = $dbh->prepare( $SQL );
$SQL_update_auction_shipping_options->execute();

#------------------------------------------------------------------------------------------------------------
# SQL complete so disconnect .... after this use Auctionitis native methods
#------------------------------------------------------------------------------------------------------------

$SQL_update_auction_shipping_options->finish();
$SQL_delete_delivery_options->finish();
$SQL_add_delivery_option->finish();
$SQL_test_delivery_options->finish();
$dbh->disconnect;

#------------------------------------------------------------------------------------------------------------
# Update Registry Key for Sella delivery options specifyinh other
#------------------------------------------------------------------------------------------------------------

my $pound = $Registry->Delimiter("/");

# Delete the existing ShipInfo defaults

if ( exists( $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities"} ) ) {

    my $key = $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities"};
    
    foreach my $subkey ( $key->SubKeyNames ) {
        print "Checking Auctionitis Defaults Set ".$subkey."\n";
        my $site = $Registry->{ "HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities/".$subkey."/Defaults/AuctionSite" };
        print "Site: ".$site."\n";
        if ( $site eq 'Sella' ) {
            my $option = $Registry->{ "HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities/".$subkey."/Defaults/DeliveryOption" };
            print "Option: ".$option."\n";
            if ( $option eq "3" ) {
                print "Modifying Auctionitis Defaults Set ".$subkey."\n";
                $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities/".$subkey."/Defaults/DeliveryOption"} = "4";
            }
        }
    }
}


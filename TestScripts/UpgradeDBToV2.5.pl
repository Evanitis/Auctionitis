use strict;
use DBI;
use Win32::TieRegistry;

my ($sth, $SQL);

my $dbh=DBI->connect('dbi:ODBC:Auctionitis') 
   || die "Error opening Auctions database: $DBI::errstr\n";
   $dbh->{ LongReadLen } = 65555;            # caters for retrieval of memo fields

#------------------------------------------------------------------------------------------------------------
# Test whether to proceed or not... PROPERTIES table MUST exist if procedure is to run
#------------------------------------------------------------------------------------------------------------

my $exists = 1;

$SQL =  qq { SELECT COUNT(*) FROM DBProperties };

$sth = $dbh->prepare($SQL);

eval { $sth->execute() || die $exists = 0; };

unless ( $exists ) {
    print "Properties table does not exist - incorrect database version\n";
    $sth->finish;
    $dbh->disconnect;
    exit;
}

#------------------------------------------------------------------------------------------------------------
# Test whether to proceed or not... Database version must be 2.2 to continue
#------------------------------------------------------------------------------------------------------------

$SQL =  qq { SELECT Property_Value FROM DBProperties WHERE Property_Name = 'DatabaseVersion' };

$sth = $dbh->prepare($SQL);

$sth->execute();
my $property = $sth->fetchrow_hashref;

if ( $property->{ Property_Value } eq "2.5" ) {
    print "Update bypassed - database already at Version 2.5\n";
    $sth->finish;
    $dbh->disconnect;
    exit;
}

if ( $property->{ Property_Value } ne "2.4" ) {
    print "Update bypassed - database must be at Version 2.4 to upgrade\n";
    $sth->finish;
    $dbh->disconnect;
    exit;
}

sleep 15;

#------------------------------------------------------------------------------------------------------------
# SQL table definition commands
#------------------------------------------------------------------------------------------------------------

#------------------------------------------------------------------------------------------------------------
# Define the Offers table
#------------------------------------------------------------------------------------------------------------

my $dbDef1 = qq {
    CREATE TABLE    Offers 
    (   Offer_ID              COUNTER       ,
        Offer_Date            DATETIME      ,
        AuctionRef            TEXT(10)      ,
        Offer_Duration        LONG          ,
        Offer_Amount          CURRENCY      ,
        Highest_Bid           CURRENCY      ,
        Offer_Reserve         CURRENCY      ,
        Actual_Offer          CURRENCY      ,
        Bidder_Count          LONG          ,
        Watcher_Count         LONG          ,
        Offer_Count           LONG          ,
        Offer_Successful      LOGICAL       ,
        Offer_Type            TEXT(10)      )      
};

#------------------------------------------------------------------------------------------------------------
# SQL statements for changes to Auctions table
#------------------------------------------------------------------------------------------------------------

my $dbDef2 = qq { ALTER TABLE Auctions ADD COLUMN OfferPrice     CURRENCY  };
my $dbDef3 = qq { ALTER TABLE Auctions ADD COLUMN OfferProcessed LOGICAL   };
my $dbDef4 = qq { ALTER TABLE Auctions ADD COLUMN SaleType       TEXT(10)  };
my $dbDef5 = qq { ALTER TABLE Auctions ALTER COLUMN ProductCode  TEXT(50)  };
my $dbDef6 = qq { ALTER TABLE Auctions ALTER COLUMN ProductCode2 TEXT(50)  };
my $dbDef7 = qq { ALTER TABLE Auctions ALTER COLUMN SupplierRef  TEXT(50)  };
my $dbDef8 = qq { ALTER TABLE Auctions ALTER COLUMN SellerRef    TEXT(50)  };

#------------------------------------------------------------------------------------------------------------
# SQL Statements for updating New Columns
#------------------------------------------------------------------------------------------------------------

my $dbUpdate1 = qq {
    UPDATE  Auctions
    SET     OfferProcessed  = -1
    WHERE   AuctionStatus   = ?     };


my $dbUpdate2 = qq {
    UPDATE  Auctions
    SET     OfferPrice     = 0     };

#------------------------------------------------------------------------------------------------------------
# SQL Statement to Set Database version property
#------------------------------------------------------------------------------------------------------------

my $SetDBVersionSQL = qq {
    UPDATE  DBProperties
    SET     Property_Value  = '2.5'
    WHERE   Property_Name   = 'DatabaseVersion'
};

#------------------------------------------------------------------------------------------------------------
# Add the new columns to the Auctions table
#------------------------------------------------------------------------------------------------------------

$sth = $dbh->do( $dbDef1 )              || print "Error creating table OFFERS: $DBI::errstr\n";
$sth = $dbh->do( $dbDef2 )              || print "Error adding Column OfferPrice: $DBI::errstr\n";
$sth = $dbh->do( $dbDef3 )              || print "Error adding Column OfferProcessed: $DBI::errstr\n";
$sth = $dbh->do( $dbDef4 )              || print "Error adding Column SaleType: $DBI::errstr\n";
$sth = $dbh->do( $dbDef5 )              || print "Altering Column Size ProductCode - Error executing statement: $DBI::errstr\n";
$sth = $dbh->do( $dbDef6 )              || print "Altering Column Size ProductCode2 - Error executing statement: $DBI::errstr\n";
$sth = $dbh->do( $dbDef7 )              || print "Altering Column Size SupplierRef - Error executing statement: $DBI::errstr\n";
$sth = $dbh->do( $dbDef8 )              || print "Altering Column Size SellerRef - Error executing statement: $DBI::errstr\n";

#------------------------------------------------------------------------------------------------------------
# Set Offer Processed to True for completed auction status types
#------------------------------------------------------------------------------------------------------------

$sth = $dbh->prepare( $dbUpdate1 )  || die "Error preparing statement\n: $DBI::errstr\n";

$sth->execute( "CLOSED"     )       || die "Offer Processed CLOSED - Error executing statement: $DBI::errstr\n";
$sth->execute( "SOLD"       )       || die "Offer Processed SOLD - Error executing statement: $DBI::errstr\n";
$sth->execute( "UNSOLD"     )       || die "Offer Processed UNSOLD - Error executing statement: $DBI::errstr\n";
$sth->execute( "RELISTED"   )       || die "Offer Processed RELISTED - Error executing statement: $DBI::errstr\n";

#------------------------------------------------------------------------------------------------------------
# Set Offer Amount = 0 for all auction records
#------------------------------------------------------------------------------------------------------------

$sth = $dbh->prepare($dbUpdate2)    || die "Error preparing statement\n: $DBI::errstr\n";
$sth->execute()                     || die "UpdateNewValues - Error executing statement: $DBI::errstr\n";

#------------------------------------------------------------------------------------------------------------
# Update the datbase version
#------------------------------------------------------------------------------------------------------------

$sth = $dbh->prepare($SetDBVersionSQL)  || print "Error preparing statement\n: $DBI::errstr\n";
$sth->execute()                         || print "Updating DBVersion - Error executing statement: $DBI::errstr\n";

#------------------------------------------------------------------------------------------------------------
# SQL complete so disconnect .... after this use Auctionitis native methods
#------------------------------------------------------------------------------------------------------------

$sth->finish;
$dbh->disconnect;

#------------------------------------------------------------------------------------------------------------
# Add basic registry keys for FPO Configuration
#------------------------------------------------------------------------------------------------------------

my $pound= $Registry->Delimiter("/");
$Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Options/AlwaysOffer"         } = 0;
$Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Options/OfferAuthenticated"  } = 0;
$Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Options/OfferAV"             } = 0;
$Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Options/OfferBasePrice"      } = 0;
$Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Options/OfferBidders"        } = 0;
$Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Options/OfferDuration"       } = 1;
$Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Options/OfferFactor"         } = 0;
$Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Options/OfferFeedbackMinimum"} = 0;
$Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Options/OfferHighBid"        } = 0;
$Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Options/OfferHighBid"        } = 0;
$Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Options/OfferRounding"       } = 0;
$Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Options/OfferSold"           } = 0;
$Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Options/OfferUnsold"         } = 0;
$Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Options/OfferWatchers"       } = 0;


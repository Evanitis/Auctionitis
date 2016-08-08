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
# Test whether to proceed or not... Database version must be 2.5 to continue
#------------------------------------------------------------------------------------------------------------

$SQL =  qq { SELECT Property_Value FROM DBProperties WHERE Property_Name = 'DatabaseVersion' };

$sth = $dbh->prepare($SQL);

$sth->execute();
my $property = $sth->fetchrow_hashref;

if ( $property->{ Property_Value } eq "3.0" ) {
    print "Update bypassed - database already at Version3.0\n";
    $sth->finish;
    $dbh->disconnect;
    exit;
}

if ( $property->{ Property_Value } ne "2.5" ) {
    print "Update bypassed - database must be at Version 2.4 to upgrade\n";
    $sth->finish;
    $dbh->disconnect;
    exit;
}

#------------------------------------------------------------------------------------------------------------
# SQL table definition commands
#------------------------------------------------------------------------------------------------------------


#------------------------------------------------------------------------------------------------------------
# SQL statements for changes to Auctionit6is tables
#------------------------------------------------------------------------------------------------------------

# Define the Images table

my $dbDef01 = qq {
    CREATE TABLE    AuctionImages 
                  ( Image_Key             COUNTER       ,
                    PictureKey            LONG          ,
                    AuctionKey            LONG          ,
                    ImageSequence         LONG          )      
};

# Modify the Pictures table

my $dbDef02 = qq { ALTER TABLE Pictures ADD COLUMN SellaID        TEXT(10)  };

# Modify the Auctions table

my $dbDef11 = qq { ALTER TABLE Auctions ALTER   COLUMN Subtitle         TEXT(60)    };
my $dbDef13 = qq { ALTER TABLE Auctions ALTER   COLUMN ShippingInfo     TEXT(75)    };
my $dbDef03 = qq { ALTER TABLE Auctions ADD     COLUMN EFTPOS           LOGICAL     };
my $dbDef04 = qq { ALTER TABLE Auctions ADD     COLUMN AgreePayMethod   LOGICAL     };
my $dbDef05 = qq { ALTER TABLE Auctions DROP    COLUMN Paymate                      };
my $dbDef06 = qq { ALTER TABLE Auctions DROP    COLUMN Pago                         };

# Drop and Create the Durations table

my $dbDef07 = qq { DROP TABLE AuctionDurations };
my $dbDef08 = qq {
    CREATE TABLE    AuctionDurations 
                  ( AuctionSite         TEXT(10)    ,
                    DurationSequence    LONG        ,
                    DurationText        TEXT(15)    ,
                    DurationValue       LONG        )      
};

$SQL = qq { 
    INSERT INTO     AuctionDurations 
                  ( AuctionSite         ,
                    DurationSequence    ,
                    DurationText        ,
                    DurationValue       )      
    VALUES          ( ?, ?, ?, ? )     
};

my $SQL_add_duration = $dbh->prepare( $SQL );

# Drop and Create the Delivery options table

my $dbDef09 = qq { DROP TABLE DeliveryOptions };
my $dbDef10 = qq {
    CREATE TABLE    DeliveryOptions 
                  ( Delivery_Option_Key     COUNTER     ,
                    Delivery_Option_Site    TEXT(10)    ,
                    Delivery_Option_Seq     LONG        ,
                    Delivery_Option_Text    TEXT(50)    ,
                    Delivery_Option_Value   TEXT(20)    )
};

$SQL = qq { 
    INSERT INTO     DeliveryOptions     
                  ( Delivery_Option_Site    ,
                    Delivery_Option_Seq     ,
                    Delivery_Option_Text    ,
                    Delivery_Option_Value   )
    VALUES          ( ?, ?, ?, ? )     
};

my $SQL_add_delivery_option = $dbh->prepare( $SQL );

# Populate the Auction Sites Table

my $dbDef12 = qq { DELETE * FROM AuctionSites };

$SQL = qq {
    INSERT INTO     AuctionSites        ( 
                    AuctionSite         ,
                    AuctionSiteName     ,
                    AuctionSiteURL      )      
    VALUES          ( ?, ?, ? )     
};

my $SQL_add_auction_site = $dbh->prepare( $SQL );

# SQL index creation commands
                             
my $dbIndex01   = qq { CREATE UNIQUE INDEX  PrimaryKey  ON AuctionDurations ( AuctionSite, DurationSequence )   WITH PRIMARY     };
my $dbIndex02   = qq { CREATE UNIQUE INDEX  PrimaryKey  ON DeliveryOptions  ( Delivery_Option_Key    )          WITH PRIMARY     };
my $dbIndex03   = qq { DROP INDEX           PhotoID     ON Pictures                                                              };
my $dbIndex04   = qq { CREATE INDEX         PhotoID     ON Pictures         ( PhotoID )                         WITH IGNORE NULL };
my $dbIndex05   = qq { CREATE INDEX         SellaID     ON Pictures         ( SellaID )                         WITH IGNORE NULL };

#------------------------------------------------------------------------------------------------------------
# SQL Statements for updating New Columns
#------------------------------------------------------------------------------------------------------------

my $dbUpdate1 = qq {
    UPDATE  Auctions
    SET     EFTPOS          = 0
};


my $dbUpdate2 = qq {
    UPDATE  Auctions
    SET     AgreePayMethod  = 0
};

my $dbUpdate3 = qq {
    UPDATE  Auctions
    SET     ShippingInfo    = ''
};

my $dbUpdate3 = qq {
    UPDATE  Auctions
    SET     AuctionSite    = 'TRADEME'
};


#------------------------------------------------------------------------------------------------------------
# SQL Statements for building new image table
#------------------------------------------------------------------------------------------------------------

$SQL = qq {
    SELECT      AuctionKey, PictureKey1, PictureKey2, PictureKey3
    FROM        Auctions
    ORDER BY    AuctionKey
};

my $SQL_get_picture_keys = $dbh->prepare( $SQL );

$SQL = qq { 
    INSERT INTO     AuctionImages    
                  ( PictureKey              ,
                    AuctionKey              ,
                    ImageSequence           )
    VALUES          ( ?, ?, ? )     
};

my $SQL_add_auction_image = $dbh->prepare( $SQL );

#------------------------------------------------------------------------------------------------------------
# SQL Statement to Set Database version property
#------------------------------------------------------------------------------------------------------------

my $SetDBVersionSQL = qq {
    UPDATE  DBProperties
    SET     Property_Value  = '3.0'
    WHERE   Property_Name   = 'DatabaseVersion'
};

#------------------------------------------------------------------------------------------------------------
# Add the new columns to the Auctions table
#------------------------------------------------------------------------------------------------------------

$sth = $dbh->do( $dbDef01 )             || print "Error creating table AuctionImages: $DBI::errstr\n";

$sth = $dbh->do( $dbDef02 )             || print "Error adding Column SellaID to table Pictures: $DBI::errstr\n";
$sth = $dbh->do( $dbIndex03 )           || print "Error dropping index PhotoID on table Pictures: $DBI::errstr\n";
$sth = $dbh->do( $dbIndex04 )           || print "Error adding index PhotoID on table Pictures: $DBI::errstr\n";
$sth = $dbh->do( $dbIndex05 )           || print "Error adding index SellaID on table Pictures: $DBI::errstr\n";

$sth = $dbh->do( $dbDef11 )             || print "Error modifying Column Subtitle: $DBI::errstr\n";
$sth = $dbh->do( $dbDef13 )             || print "Error modifying Column ShippingInfo: $DBI::errstr\n";
$sth = $dbh->do( $dbDef03 )             || print "Error adding Column EFTPOS: $DBI::errstr\n";
$sth = $dbh->do( $dbDef04 )             || print "Error adding Column AgreePayMethod: $DBI::errstr\n";
$sth = $dbh->do( $dbDef06 )             || print "Error removing Column Paymate: $DBI::errstr\n";
$sth = $dbh->do( $dbDef06 )             || print "Error removing Column Pago: $DBI::errstr\n";

$sth = $dbh->do( $dbUpdate1 )           || print "Error setting column EFTPOS to 0: $DBI::errstr\n";
$sth = $dbh->do( $dbUpdate2 )           || print "Error setting column AgreePayMethod to 0: $DBI::errstr\n";
$sth = $dbh->do( $dbUpdate3 )           || print "Error setting column ShippingInfo to blank: $DBI::errstr\n";

$sth = $dbh->do( $dbDef07 )             || print "Error dropping table AuctionDurations: $DBI::errstr\n";
$sth = $dbh->do( $dbDef08 )             || print "Error creating table AuctionDurations: $DBI::errstr\n";
$sth = $dbh->do( $dbIndex01 )           || print "Error creating index Primary on AuctionDurations: $DBI::errstr\n";

$SQL_add_duration->execute( "TRADEME",   1,  "2 Days",   2880    );
$SQL_add_duration->execute( "TRADEME",   2,  "3 Days",   4320    );
$SQL_add_duration->execute( "TRADEME",   3,  "4 Days",   5760    );
$SQL_add_duration->execute( "TRADEME",   4,  "5 Days",   7200    );
$SQL_add_duration->execute( "TRADEME",   5,  "6 Days",   8640    );
$SQL_add_duration->execute( "TRADEME",   6,  "7 Days",   10080   );
$SQL_add_duration->execute( "TRADEME",   7,  "10 Days",  14400   );

$SQL_add_duration->execute( "SELLA",     1,  "1 Day",    1       );
$SQL_add_duration->execute( "SELLA",     2,  "2 Day",    2       );
$SQL_add_duration->execute( "SELLA",     3,  "3 Day",    3       );
$SQL_add_duration->execute( "SELLA",     4,  "4 Day",    4       );
$SQL_add_duration->execute( "SELLA",     5,  "5 Day",    5       );
$SQL_add_duration->execute( "SELLA",     6,  "6 Day",    6       );
$SQL_add_duration->execute( "SELLA",     7,  "7 Day",    7       );
$SQL_add_duration->execute( "SELLA",     8,  "8 Day",    8       );
$SQL_add_duration->execute( "SELLA",     9,  "9 Day",    9       );
$SQL_add_duration->execute( "SELLA",     10, "10 Day",   10      );

$sth = $dbh->do( $dbDef09 )             || print "Error dropping table DeliveryOptions: $DBI::errstr\n";
$sth = $dbh->do( $dbDef10 )             || print "Error creating table DeliveryOptions: $DBI::errstr\n";
$sth = $dbh->do( $dbIndex02 )           || print "Error creating index Primary on DeliveryOptions: $DBI::errstr\n";

$SQL_add_delivery_option->execute( "TRADEME",   0,  "Not Selected",                             "Not Sent to TradeMe"   );
$SQL_add_delivery_option->execute( "TRADEME",   1,  "I don\'t know the shipping costs yet",     "Undecided"             );
$SQL_add_delivery_option->execute( "TRADEME",   2,  "Free shipping within New Zealand",         "Free"                  );
$SQL_add_delivery_option->execute( "TRADEME",   3,  "Specify shipping costs",                   "Custom"                );

$SQL_add_delivery_option->execute( "SELLA",     0,  "Not Selected",                             "Not Sent to Sella"     );
$SQL_add_delivery_option->execute( "SELLA",     1,  "Free Shipping",                            "free"                  );
$SQL_add_delivery_option->execute( "SELLA",     2,  "Organise With Buyer",                      "org"                   );
$SQL_add_delivery_option->execute( "SELLA",     3,  "Other",                                    "other"                 );

$sth = $dbh->do( $dbDef12 )             || print "Error clearing table AuctionSites: $DBI::errstr\n";
$SQL_add_auction_site->execute( "TRADEME",  "Trade Me",     "http://www.trademe.co.nz"    );
$SQL_add_auction_site->execute( "SELLA",    "Sella",        "http://www.sella.co.nz"    );

#------------------------------------------------------------------------------------------------------------
# Build the Auction Images table
#------------------------------------------------------------------------------------------------------------

$SQL_get_picture_keys->execute();
my $auctions = $SQL_get_picture_keys->fetchall_arrayref({});
foreach my $a ( @$auctions ) {
    my $seq = 1;
    if ( $a->{ PictureKey1 } > 0 ) {
        $SQL_add_auction_image->execute(
            $a->{ PictureKey1   }   ,
            $a->{ AuctionKey    }   ,
            $seq                    ,
        );
        $seq++;
    }
    if ( $a->{ PictureKey2 } > 0 ) {
        $SQL_add_auction_image->execute(
            $a->{ PictureKey2   }   ,
            $a->{ AuctionKey    }   ,
            $seq                    ,
        );
        $seq++;
    }
    if ( $a->{ PictureKey3 } > 0 ) {
        $SQL_add_auction_image->execute(
            $a->{ PictureKey3   }   ,
            $a->{ AuctionKey    }   ,
            $seq                    ,
        );
        $seq++;
    }
}

#------------------------------------------------------------------------------------------------------------
# Update the datbase version
#------------------------------------------------------------------------------------------------------------

$sth = $dbh->prepare( $SetDBVersionSQL )    || print "Error preparing statement\n: $DBI::errstr\n";
$sth->execute()                             || print "Updating DBVersion - Error executing statement: $DBI::errstr\n";

#------------------------------------------------------------------------------------------------------------
# SQL complete so disconnect .... after this use Auctionitis native methods
#------------------------------------------------------------------------------------------------------------

$sth->finish;
$dbh->disconnect;

#------------------------------------------------------------------------------------------------------------
# Add Registry Key for Sella API URL
#------------------------------------------------------------------------------------------------------------

my $pound= $Registry->Delimiter("/");
my $url = "http://www.sella.co.nz/services/rpc/input-xml/output-xml/";
$Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Properties/SellaAPIURL"} = $url;

# Delete the existing ShipInfo defaults

if ( exists( $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities"} ) ) {

    my $key = $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities"};
    
    foreach my $subkey ( $key->SubKeyNames ) {
        delete $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities".$subkey."/Defaults/ShipInfo"};
    }
}


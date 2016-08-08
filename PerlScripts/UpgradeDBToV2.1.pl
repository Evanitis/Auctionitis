use strict;
use Auctionitis;
use DBI;
use File::Copy;
use Win32::TieRegistry;

my ($sth, $auction, $stdtext, $oldauctions, $oldstdtext, $PicKey);

my $dbh=DBI->connect('dbi:ODBC:Auctionitis') 
   || die "Error opening Auctions database: $DBI::errstr\n";
   $dbh->{LongReadLen} = 65555;            # caters for retrieval of memo fields

#------------------------------------------------------------------------------------------------------------
# Test whether to proceed or not... PROPERTIES table must not exist if procedure is to run
#------------------------------------------------------------------------------------------------------------

my $exists = 1;

my $SQL =  qq { SELECT COUNT(*) FROM DBProperties };

$sth = $dbh->prepare($SQL);

eval { $sth->execute() || die $exists = 0; };

if ( $exists ) {
    print "Properties table already exists - incorrect datbase version\n";
    exit;
}

#------------------------------------------------------------------------------------------------------------
# SQL table definition commands
#------------------------------------------------------------------------------------------------------------

# Define the New auctions table

my $dbDef1 = qq {
    CREATE TABLE    Auctions
        (   AuctionKey              COUNTER     ,
            Title                   TEXT(50)    ,
            Subtitle                TEXT(50)    ,
            Description             MEMO        ,
            ProductType             TEXT(20)    ,
            ProductCode             TEXT(20)    ,
            ProductCode2            TEXT(20)    ,
            SupplierRef             TEXT(20)    ,
            LoadSequence            LONG        ,
            Held                    LOGICAL     ,
            AuctionCycle            TEXT(20)    ,
            AuctionStatus           TEXT(10)    ,
            StockOnHand             LONG        ,
            RelistStatus            LONG        ,
            AuctionSold             LOGICAL     ,
            RelistCount             LONG        ,
            NotifyWatchers          LOGICAL     ,
            UseTemplate             LOGICAL     ,
            TemplateKey             LONG        ,
            AuctionRef              TEXT(10)    ,
            SellerRef               TEXT(20)    ,
            DateLoaded              DATETIME    ,
            CloseDate               DATETIME    ,
            CloseTime               DATETIME    ,
            Category                TEXT(5)     ,
            MovieRating             LONG        ,
            MovieConfirm            LOGICAL     ,
            AttributeCategory       LONG        ,
            AttributeName           TEXT(20)    ,
            AttributeValue          TEXT(20)    ,
            TMATT104                TEXT(5)     ,
            TMATT104_2              TEXT(5)     ,
            TMATT106                TEXT(5)     ,
            TMATT106_2              TEXT(5)     ,
            TMATT108                TEXT(5)     ,
            TMATT108_2              TEXT(5)     ,
            TMATT111                TEXT(25)    ,
            TMATT112                TEXT(25)    ,
            TMATT115                TEXT(5)     ,
            TMATT117                TEXT(5)     ,
            TMATT118                TEXT(5)     ,
            IsNew                   LOGICAL     ,
            TMBuyerEmail            LOGICAL     ,
            StartPrice              CURRENCY    ,
            ReservePrice            CURRENCY    ,
            BuyNowPrice             CURRENCY    ,
            DurationHours           LONG        ,
            ClosedAuction           LOGICAL     ,
            BankDeposit             LOGICAL     ,
            CreditCard              LOGICAL     ,
            SafeTrader              LOGICAL     ,
            PaymentInfo             TEXT(70)    ,
            FreeShippingNZ          LOGICAL     ,
            ShippingInfo            TEXT(50)    ,
            PickupOption            LONG        ,
            ShippingOption          LONG        ,
            Featured                LOGICAL     ,
            Gallery                 LOGICAL     ,
            BoldTitle               LOGICAL     ,
            FeatureCombo            LOGICAL     ,
            HomePage                LOGICAL     ,
            CopyCount               LONG        ,
            Message                 TEXT(50)    ,
            PictureKey1             LONG        ,
            PictureKey2             LONG        ,
            PictureKey3             LONG        ,
            AuctionSite             TEXT(10)    ,
            UserDefined01           TEXT(30)    ,
            UserDefined02           TEXT(30)    ,
            UserDefined03           TEXT(30)    ,
            UserDefined04           TEXT(30)    ,
            UserDefined05           TEXT(30)    ,
            UserDefined06           TEXT(30)    ,
            UserDefined07           TEXT(30)    ,
            UserDefined08           TEXT(30)    ,
            UserDefined09           TEXT(30)    ,
            UserDefined10           TEXT(30)    ,
            UserStatus              TEXT(10)    ,
            UserNotes               MEMO        ) 
};

# Define the Database properties table

my $dbDef2 = qq {
    CREATE TABLE    DBProperties
        (   Property_Name           TEXT(30)    ,
            Property_Value          TEXT(30)    )
};

# Define the Delivery Options table

my $dbDef3 = qq {
    CREATE TABLE    DeliveryOptions
        (   Delivery_Option_Key     LONG        ,
            Delivery_Option_Seq     LONG        ,
            Delivery_Option_Text    TEXT(50)    ,
            Delivery_Option_Value   TEXT(20)    )
};

# Define the Pick-up Options table

my $dbDef4 = qq {
    CREATE TABLE    PickupOptions
        (   Pickup_Option_Key       LONG        ,
            Pickup_Option_Seq       LONG        ,
            Pickup_Option_Text      TEXT(50)    ,
            Pickup_Option_Value     TEXT(20)    )
};

# Define the Shipping options table

my $dbDef5 = qq {
    CREATE TABLE    ShippingOptions
        (   Shipping_Option_Key     COUNTER     ,
            Shipping_Option_Seq     LONG        ,
            Shipping_Option_Code    TEXT(3)     ,
            Shipping_Option_Cost    CURRENCY    ,
            Shipping_Option_Text    TEXT(50)    )
};

# Define the Shipping Details table

my $dbDef6 = qq {
    CREATE TABLE    ShippingDetails
        (   Shipping_Details_Key    COUNTER     ,
            Shipping_Details_Seq    LONG        ,
            Shipping_Details_Cost   CURRENCY    ,
            Shipping_Details_Text   TEXT(50)    ,
            AuctionKey              LONG        ,
            Shipping_Option_Code    TEXT(3)     )
};

# SQL index creation commands
                             
my $dbIndex01   = qq { CREATE  UNIQUE   INDEX   PrimaryKey      ON Auctions         ( AuctionKey            ) };
my $dbIndex02   = qq { CREATE  UNIQUE   INDEX   AuctionKey      ON Auctions         ( AuctionKey            ) };
my $dbIndex03   = qq { CREATE           INDEX   AuctionRef      ON Auctions         ( AuctionRef            ) };
my $dbIndex04   = qq { CREATE           INDEX   CategoryID      ON Auctions         ( Category              ) };
my $dbIndex05   = qq { CREATE           INDEX   ProductCode     ON Auctions         ( ProductCode           ) };
my $dbIndex06   = qq { CREATE           INDEX   ProductType     ON Auctions         ( ProductType           ) };
my $dbIndex07   = qq { CREATE           INDEX   AuctionCycle    ON Auctions         ( AuctionCycle          ) };
my $dbIndex08   = qq { CREATE           INDEX   LoadSeq         ON Auctions         ( LoadSequence          ) };

my $dbIndex09   = qq { CREATE  UNIQUE   INDEX   PrimaryKey      ON DBProperties     ( Property_Name         ) };

my $dbIndex10   = qq { CREATE  UNIQUE   INDEX   PrimaryKey      ON DeliveryOptions  ( Delivery_Option_Key   ) };

my $dbIndex11   = qq { CREATE  UNIQUE   INDEX   PrimaryKey      ON PickupOptions    ( Pickup_Option_Key     ) };

my $dbIndex12   = qq { CREATE  UNIQUE   INDEX   PrimaryKey      ON ShippingDetails  ( Shipping_Details_Key  ) };
my $dbIndex13   = qq { CREATE           INDEX   AuctionKey      ON ShippingDetails  ( AuctionKey            ) };

my $dbIndex13   = qq { CREATE  UNIQUE   INDEX   PrimaryKey      ON ShippingOptions  ( Shipping_Option_Key   ) };

# SQL Database copy commands

my $dbCopy1     = qq { SELECT * FROM Auctions };

# SQL delete table commands

my $dbDrop1 = qq { DROP TABLE Auctions };

# Prepare the Insert Statements for the new look up tables

my $dbInsert1 = qq {
    INSERT INTO DeliveryOptions
            (   Delivery_Option_Key     ,
                Delivery_Option_Seq     ,
                Delivery_Option_Text    , 
                Delivery_Option_Value   )
    VALUES      (?,?,?,?                )
};

my $dbInsert2 = qq {
    INSERT INTO PickupOptions
            (   Pickup_Option_Key       ,
                Pickup_Option_Seq       ,
                Pickup_Option_Text      , 
                Pickup_Option_Value     )
    VALUES      (?,?,?,?                )
};

#------------------------------------------------------------------------------------------------------------
# SQL Statement for updating the allow editing file
#------------------------------------------------------------------------------------------------------------

my $dbUpdate1 = qq {
    UPDATE  AuctionStatuses
    SET     AllowEdit       = 1
    WHERE   AuctionStatus   = ?     };

#------------------------------------------------------------------------------------------------------------
# Copy the old auction table into a temporary hash reference
#------------------------------------------------------------------------------------------------------------

$sth = $dbh->prepare( $dbCopy1 )    || die "Error preparing statement: $DBI::errstr\n";
$sth->execute                       || die "Error Extracting Auction data: $DBI::errstr\n";

$oldauctions = $sth->fetchall_arrayref({});

#------------------------------------------------------------------------------------------------------------
# Delete the version 2.0 Auction table
#------------------------------------------------------------------------------------------------------------

$sth = $dbh->prepare( $dbDrop1 )    || die "Error preparing statement: $DBI::errstr\n";
$sth->execute                       || die "Error converting from backup table: $DBI::errstr\n";

#------------------------------------------------------------------------------------------------------------
# Create the version 2.1 Auction tables & Indexes
#------------------------------------------------------------------------------------------------------------

$sth = $dbh->do( $dbDef1 )          || die "Error creating Auctions table: $DBI::errstr\n";
$sth = $dbh->do( $dbDef2 )          || die "Error creating DBProperties table: $DBI::errstr\n";
$sth = $dbh->do( $dbDef3 )          || die "Error creating DeliveryOptions table: $DBI::errstr\n";
$sth = $dbh->do( $dbDef4 )          || die "Error creating PickupOptions table: $DBI::errstr\n";
$sth = $dbh->do( $dbDef5 )          || die "Error creating ShippingOptions table: $DBI::errstr\n";
$sth = $dbh->do( $dbDef6 )          || die "Error creating ShippingDetails table: $DBI::errstr\n";

$sth = $dbh->do( $dbIndex01 )       || die "Error creating Index: $DBI::errstr\n";
$sth = $dbh->do( $dbIndex02 )       || die "Error creating Index: $DBI::errstr\n";
$sth = $dbh->do( $dbIndex03 )       || die "Error creating Index: $DBI::errstr\n";
$sth = $dbh->do( $dbIndex04 )       || die "Error creating Index: $DBI::errstr\n";
$sth = $dbh->do( $dbIndex05 )       || die "Error creating Index: $DBI::errstr\n";
$sth = $dbh->do( $dbIndex06 )       || die "Error creating Index: $DBI::errstr\n";
$sth = $dbh->do( $dbIndex07 )       || die "Error creating Index: $DBI::errstr\n";
$sth = $dbh->do( $dbIndex08 )       || die "Error creating Index: $DBI::errstr\n";
$sth = $dbh->do( $dbIndex09 )       || die "Error creating Index: $DBI::errstr\n";
$sth = $dbh->do( $dbIndex10 )       || die "Error creating Index: $DBI::errstr\n";
$sth = $dbh->do( $dbIndex11 )       || die "Error creating Index: $DBI::errstr\n";
$sth = $dbh->do( $dbIndex12 )       || die "Error creating Index: $DBI::errstr\n";
$sth = $dbh->do( $dbIndex13 )       || die "Error creating Index: $DBI::errstr\n";

#------------------------------------------------------------------------------------------------------------
# Insert required value sinto new lookup tables
#------------------------------------------------------------------------------------------------------------

# Delivery options

$sth = $dbh->prepare( $dbInsert1 )  || die "Error preparing statement: $DBI::errstr\n";

$sth->execute(
    0                                       ,
    0                                       ,
    "Not Selected"                          ,
    "Not Sent to TradeMe"                   ,
);

$sth->execute(
    1                                       ,
    1                                       ,
    "I don't know the shipping costs yet"   ,
    "Undecided"                             ,
);

$sth->execute(
    2                                       ,
    2                                       ,
    "Free shipping within New Zealand"      ,
    "Free"                                  ,
);

$sth->execute(
    3                                       ,
    3                                       ,
    "Specify shipping costs"                ,
    "Custom"                                ,
);

# Pickup options

$sth = $dbh->prepare( $dbInsert2 )  || die "Error preparing statement: $DBI::errstr\n";

$sth->execute(
    0                                       ,
    0                                       ,
    "Not Selected"                          ,
    "Not Sent to TradeMe"                   ,
);

$sth->execute(
    1                                       ,
    1                                       ,
    "Buyer can pick-up"                     ,
    "Allow"                                 ,
);

$sth->execute(
    2                                       ,
    2                                       ,
    "Buyer must pick-up"                    ,
    "Demand"                                ,
);

$sth->execute(
    3                                       ,
    3                                       ,
    "No pick-ups"                           ,
    "Forbid"                                ,
);

#------------------------------------------------------------------------------------------------------------
# Insert required value sinto new lookup tables
#------------------------------------------------------------------------------------------------------------

$sth = $dbh->prepare($dbUpdate1) || die "Error preparing statement\n: $DBI::errstr\n";

$sth->execute( "CURRENT"    )   || die "UpdateAllowEdit - Error executing statement: $DBI::errstr\n";
$sth->execute( "SOLD"       )   || die "UpdateAllowEdit - Error executing statement: $DBI::errstr\n";
$sth->execute( "UNSOLD"     )   || die "UpdateAllowEdit - Error executing statement: $DBI::errstr\n";

#------------------------------------------------------------------------------------------------------------
# SQL complete so disconnect .... after this use Auctionitis native methods
#------------------------------------------------------------------------------------------------------------

$sth->finish;
$dbh->disconnect;

#------------------------------------------------------------------------------------------------------------
# Set up an Auctionitis object 
#------------------------------------------------------------------------------------------------------------

my $tm = Auctionitis->new();

$tm->initialise(Product => "AUCTIONITIS");
$tm->DBconnect();
$tm->login();

#------------------------------------------------------------------------------------------------------------
# Update the new auction database with the auction details
# for each record in the backup data base, insert the required fields into the new database and set
# defaults for new fields where appropriate.
#------------------------------------------------------------------------------------------------------------

# Add all the auctions to the database & build a cross reference for old key/new key

my %keyxref;

foreach $auction (@$oldauctions) {
    
    print "Adding auction from old key $auction->{ AuctionKey }\n";
    
    my $newauction = $tm->add_auction_record_201(
        Title                   =>  $auction->{ Title               },         
        Description             =>  $auction->{ Description         },
        ProductType             =>  $auction->{ ProductType         },
        ProductCode             =>  $auction->{ ProductCode         },
        Held                    =>  $auction->{ Held                },
        AuctionCycle            =>  $auction->{ AuctionCycle        },
        AuctionStatus           =>  $auction->{ AuctionStatus       },
        RelistStatus            =>  $auction->{ RelistStatus        },
        AuctionSold             =>  $auction->{ AuctionSold         },
        StockOnHand             =>  $auction->{ StockOnHand         },
        RelistCount             =>  $auction->{ RelistCount         },
        NotifyWatchers          =>  $auction->{ NotifyWatchers      },
        UseTemplate             =>  $auction->{ UseTemplate         },
        TemplateKey             =>  $auction->{ TemplateKey         },
        AuctionRef              =>  $auction->{ AuctionRef          },
        SellerRef               =>  $auction->{ SellerRef           },
        DateLoaded              =>  $auction->{ DateLoaded          },
        CloseDate               =>  $auction->{ CloseDate           },
        CloseTime               =>  $auction->{ CloseTime           },
        Category                =>  $auction->{ Category            },
        MovieRating             =>  $auction->{ MovieRating         },
        MovieConfirm            =>  $auction->{ MovieConfirm        },
        AttributeCategory       =>  $auction->{ AttributeCateg      },
        AttributeName           =>  $auction->{ AttributeName       },
        AttributeValue          =>  $auction->{ AttributeValue      },
        TMATT104                =>  $auction->{ TMATT104            },
        TMATT104_2              =>  $auction->{ TMATT104_2          },
        TMATT106                =>  $auction->{ TMATT106            },
        TMATT106_2              =>  $auction->{ TMATT106_2          },
        TMATT108                =>  $auction->{ TMATT108            },
        TMATT108_2              =>  $auction->{ TMATT108_2          },
        TMATT111                =>  $auction->{ TMATT111            },
        TMATT112                =>  $auction->{ TMATT112            },
        TMATT115                =>  $auction->{ TMATT115            },
        TMATT117                =>  $auction->{ TMATT117            },
        TMATT118                =>  $auction->{ TMATT118            },
        IsNew                   =>  $auction->{ IsNew               },
        TMBuyerEmail            =>  $auction->{ TMBuyerEmail        },
        StartPrice              =>  $auction->{ StartPrice          },
        ReservePrice            =>  $auction->{ ReservePrice        },
        BuyNowPrice             =>  $auction->{ BuyNowPrice         },
        DurationHours           =>  $auction->{ DurationHours       },
        ClosedAuction           =>  $auction->{ ClosedAuction       },
        BankDeposit             =>  $auction->{ BankDeposit         },
        $tm->{ CashFlagSet }    ? ( CreditCard  => $auction->{ Cash }) : ( CreditCard  => "0"),
        CreditCard              =>  $auction->{ Cash                },
        SafeTrader              =>  0                               ,
        PaymentInfo             =>  $auction->{ PaymentInfo         },
        FreeShippingNZ          =>  $auction->{ FreeShippingNZ      },
        ShippingInfo            =>  $auction->{ ShippingInfo        },
        Featured                =>  $auction->{ Featured            },
        Gallery                 =>  $auction->{ Gallery             },
        BoldTitle               =>  $auction->{ BoldTitle           },
        FeatureCombo            =>  $auction->{ FeatureCombo        },
        HomePage                =>  $auction->{ HomePage            },
        CopyCount               =>  $auction->{ CopyCount           },
        Message                 =>  $auction->{ Message             },
        PictureKey1             =>  $auction->{ PictureKey1         },
        PictureKey2             =>  $auction->{ PictureKey2         },
        PictureKey3             =>  $auction->{ PictureKey3         },
        AuctionSite             =>  $auction->{ AuctionSite         },
    );                              

    $keyxref{ $auction->{ AuctionKey } } = $newauction;

}

# Update old template keys with the converted records new key value

foreach $auction (@$oldauctions) {

    if ( $auction->{ TemplateKey } ) {

        print "Updating auction template key for $auction->{ AuctionKey }\n";

        $tm->update_auction_record(
            AuctionKey       =>  $keyxref{ $auction->{ AuctionKey   } }    ,
            TemplateKey      =>  $keyxref{ $auction->{ TemplateKey  } }    ,
        );
    }
}

# Set the database properties we are using

$tm->set_DB_property(
    Property_Name   =>  "DatabaseVersion"                   ,
    Property_Value  =>  "2.1"                               ,
);

$tm->set_DB_property(
    Property_Name   =>  "TMPictureCount"                    ,
    Property_Value  =>  $tm->get_TM_photo_count()           ,
);

my $pound= $Registry->Delimiter("/");
my $csd = $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Properties/CategoryServiceDate"};

if ( $csd ) {

    $tm->set_DB_property(
        Property_Name   =>  "CategoryServiceDate"               ,
        Property_Value  =>  $csd                                ,
    );
}

else {

    $tm->set_DB_property(
        Property_Name   =>  "CategoryServiceDate"               ,
        Property_Value  =>  "01-01-2006"                        ,
    );
}

$csd = delete $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Properties/CategoryServiceDate"};

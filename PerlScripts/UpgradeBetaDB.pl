use strict;
use DBI;

my $dbh=DBI->connect('dbi:ODBC:Auctionitis') 
   || die "Error opening Auctions database: $DBI::errstr\n";
   $dbh->{LongReadLen} = 65555;            # caters for retrieval of memo fields

# Define New version of the Auctions table table so it can be created

my $dbDef = qq { CREATE TABLE Auctions  (   AuctionKey        COUNTER       ,
                                            Title             TEXT      (50),
                                            Description       MEMO          ,
                                            ProductType       TEXT      (20),
                                            ProductCode       TEXT      (20),
                                            Held              LOGICAL       ,
                                            AuctionCycle      TEXT      (20),
                                            AuctionStatus     TEXT      (10),
                                            RelistStatus      LONG          ,
                                            AuctionSold       LOGICAL       ,
                                            StockOnHand       LONG          ,
                                            RelistCount       LONG          ,
                                            NotifyWatchers    LOGICAL       ,
                                            UseTemplate       LOGICAL       ,
                                            TemplateKey       LONG          ,
                                            AuctionRef        TEXT      (10),
                                            SellerRef         TEXT      (20),
                                            DateLoaded        DATETIME      ,
                                            CloseDate         DATETIME      ,
                                            CloseTime         DATETIME      ,
                                            AuctionLoaded     LOGICAL       ,
                                            Category          TEXT       (5),
                                            MovieRating       LONG          ,
                                            MovieConfirm      LOGICAL       ,
                                            AttributeCategory LONG          ,
                                            AttributeName     TEXT      (20),
                                            AttributeValue    TEXT      (20),
                                            TMATT104          TEXT       (5),
                                            TMATT104_2        TEXT       (5),
                                            TMATT106          TEXT       (5),
                                            TMATT106_2        TEXT       (5),
                                            TMATT108          TEXT       (5),
                                            TMATT108_2        TEXT       (5),
                                            TMATT111          TEXT      (25),
                                            TMATT112          TEXT      (25),
                                            TMATT115          TEXT       (5),
                                            TMATT117          TEXT       (5),
                                            TMATT118          TEXT       (5),
                                            IsNew             LOGICAL       ,
                                            TMBuyerEmail      LOGICAL       ,
                                            StartPrice        CURRENCY      ,
                                            ReservePrice      CURRENCY      ,
                                            BuyNowPrice       CURRENCY      ,
                                            DurationHours     LONG          ,
                                            ClosedAuction     LOGICAL       ,
                                            AutoExtend        LOGICAL       ,
                                            Cash              LOGICAL       ,
                                            Cheque            LOGICAL       ,
                                            BankDeposit       LOGICAL       ,
                                            PaymentInfo       TEXT      (70),
                                            FreeShippingNZ    LOGICAL       ,
                                            ShippingInfo      TEXT      (50),
                                            SafeTrader        LONG          ,
                                            Featured          LOGICAL       ,
                                            Gallery           LOGICAL       ,
                                            BoldTitle         LOGICAL       ,
                                            FeatureCombo      LOGICAL       ,
                                            HomePage          LOGICAL       ,
                                            CopyCount         LONG          ,
                                            Message           TEXT      (50),
                                            PictureKey1       LONG          ,
                                            PictureKey2       LONG          ,
                                            PictureKey3       LONG          ,
                                            AuctionSite       TEXT      (10) ) } ;
                                            
print "$dbDef\n";

# SQL index creation commands
                             
my $dbIndex1 = qq { CREATE UNIQUE   INDEX   PrimaryKey  ON Auctions (AuctionKey) };
my $dbIndex2 = qq { CREATE          INDEX   Category    ON Auctions (Category)   };
my $dbIndex3 = qq { CREATE UNIQUE   INDEX   AuctionKey  ON Auctions (AuctionKey) };

# SQL table copy commands

my $dbCopy1 = qq {  SELECT * INTO   AuctionBackup   FROM    Auctions        };
my $dbCopy2 = qq {  SELECT * FROM   AuctionBackup                           };
my $dbCopy3 = qq {  INSERT   INTO   Auctions        (       Title               ,
                                                            Description         ,
                                                            ProductType         ,
                                                            ProductCode         ,
                                                            Held                ,
                                                            AuctionCycle        ,
                                                            AuctionStatus       ,
                                                            RelistStatus        ,
                                                            AuctionSold         ,
                                                            StockOnHand         ,
                                                            RelistCount         ,
                                                            NotifyWatchers      ,
                                                            UseTemplate         ,
                                                            TemplateKey         ,
                                                            AuctionRef          ,
                                                            SellerRef           ,
                                                            DateLoaded          ,
                                                            CloseDate           ,
                                                            CloseTime           ,
                                                            AuctionLoaded       ,
                                                            Category            ,
                                                            MovieRating         ,
                                                            MovieConfirm        ,
                                                            AttributeCategory   ,
                                                            AttributeName       ,
                                                            AttributeValue      ,
                                                            TMATT104            ,
                                                            TMATT104_2          ,
                                                            TMATT106            ,
                                                            TMATT106_2          ,
                                                            TMATT108            ,
                                                            TMATT108_2          ,
                                                            TMATT111            ,
                                                            TMATT112            ,
                                                            TMATT115            ,
                                                            TMATT117            ,
                                                            TMATT118            ,
                                                            IsNew               ,
                                                            TMBuyerEmail        ,
                                                            StartPrice          ,
                                                            ReservePrice        ,
                                                            BuyNowPrice         ,
                                                            DurationHours       ,
                                                            ClosedAuction       ,
                                                            AutoExtend          ,
                                                            Cash                ,
                                                            Cheque              ,
                                                            BankDeposit         ,
                                                            PaymentInfo         ,
                                                            FreeShippingNZ      ,
                                                            ShippingInfo        ,
                                                            SafeTrader          ,
                                                            Featured            ,
                                                            Gallery             ,
                                                            BoldTitle           ,
                                                            FeatureCombo        ,
                                                            HomePage            ,
                                                            CopyCount           ,
                                                            Message             ,
                                                            PictureKey1         ,
                                                            PictureKey2         ,
                                                            PictureKey3         ,
                                                            AuctionSite         )
                    VALUES                          (       ?,?,?,?,?,?,?,?,?,?,
                                                            ?,?,?,?,?,?,?,?,?,?,
                                                            ?,?,?,?,?,?,?,?,?,?,
                                                            ?,?,?,?,?,?,?,?,?,?,
                                                            ?,?,?,?,?,?,?,?,?,?,
                                                            ?,?,?,?,?,?,?,?,?,?,?,?,?   ) } ;                

# SQL delete table commands

my $dbDrop1 = qq { DROP TABLE Auctions };
my $dbDrop2 = qq { DROP TABLE AuctionBackup };

# Make a copy of the Auctions Table

my $sth = $dbh->prepare( $dbCopy1 ) || die "Error preparing statement: $DBI::errstr\n";
$sth->execute                       || die "Error creating backup table: $DBI::errstr\n";

# Drop the The existing Auctions database

$sth = $dbh->prepare( $dbDrop1 )    || die "Error preparing statement: $DBI::errstr\n";
$sth->execute                       || die "Error Deleting old table: $DBI::errstr\n";

# Create the new Auctions database

$sth = $dbh->prepare( $dbDef )      || die "Error preparing statement: $DBI::errstr\n";
$sth->execute                       || die "Error Creating database: $DBI::errstr\n";

$sth = $dbh->prepare( $dbIndex1 )   || die "Error preparing statement: $DBI::errstr\n";
$sth->execute                       || die "Error Creating Primary Key: $DBI::errstr\n";

$sth = $dbh->prepare( $dbIndex2 )   || die "Error preparing statement: $DBI::errstr\n";
$sth->execute                       || die "Error Creating CategoryID index: $DBI::errstr\n";

$sth = $dbh->prepare( $dbIndex3 )   || die "Error preparing statement: $DBI::errstr\n";
$sth->execute                       || die "Error Creating PhotoID index: $DBI::errstr\n";

# Copy the backup Auctions Table into the new database

$sth = $dbh->prepare( $dbCopy2 )    || die "Error preparing statement: $DBI::errstr\n";
$sth->execute                       || die "Error converting from backup table: $DBI::errstr\n";

my $inputdata = $sth->fetchall_arrayref({});

foreach my $auction (@$inputdata) {

# for each record in the backup data base, insert the required fields into the new database and set
# defaults for new fields where appropriate.

        $sth = $dbh->prepare($dbCopy3) || die "Error preparing statement: $DBI::errstr\n";

        $sth->bind_param(2, $sth, DBI::SQL_LONGVARCHAR);

        $auction->{ AttributeValue      } =~ tr/ //d;

        $sth->execute("$auction->{ Title                  }",
                      "$auction->{ Description            }",
                      "$auction->{ ProductType            }",
                      "$auction->{ ProductCode            }",
                       $auction->{ Held                   },
                      "$auction->{ AuctionCycle           }",
                      "$auction->{ AuctionStatus          }",
                       $auction->{ RelistStatus           },
                       $auction->{ AuctionSold            },
                       $auction->{ StockOnHand            },
                       $auction->{ RelistCount            },
                       $auction->{ NotifyWatchers         },
                       $auction->{ UseTemplate            },
                       $auction->{ TemplateKey            },
                      "$auction->{ AuctionRef             }",
                      "$auction->{ SellerRef              }",
                       $auction->{ DateLoaded             },
                       $auction->{ CloseDate              },
                       $auction->{ CloseTime              },
                       $auction->{ AuctionLoaded          },
                      "$auction->{ Category               }",
                       $auction->{ MovieRating            },
                       $auction->{ MovieConfirm           },
                       $auction->{ AttributeCategory      },
                      "$auction->{ AttributeName          }",
                      "$auction->{ AttributeValue         }",
                      "$auction->{ TMATT104               }",
                      "$auction->{ TMATT104_2             }",
                      "$auction->{ TMATT106               }",
                      "$auction->{ TMATT106_2             }",
                      "$auction->{ TMATT108               }",
                      "$auction->{ TMATT108_2             }",
                      "$auction->{ TMATT111               }",
                      "$auction->{ TMATT112               }",
                      "$auction->{ TMATT115               }",
                      "$auction->{ TMATT117               }",
                      "$auction->{ TMATT118               }",
                       $auction->{ IsNew                  },
                       $auction->{ TMBuyerEmail           },
                       $auction->{ StartPrice             },
                       $auction->{ ReservePrice           },
                       $auction->{ BuyNowPrice            },
                       $auction->{ DurationHours          },
                       $auction->{ ClosedAuction          },
                       $auction->{ AutoExtend             },
                       $auction->{ Cash                   },
                       $auction->{ Cheque                 },
                       $auction->{ BankDeposit            },
                      "$auction->{ PaymentInfo            }",
                       $auction->{ FreeShippingNZ         },
                      "$auction->{ ShippingInfo           }",
                       $auction->{ SafeTrader             },
                       $auction->{ Featured               },
                       $auction->{ Gallery                },
                       $auction->{ BoldTitle              },
                       $auction->{ FeatureCombo           },
                       $auction->{ HomePage               },
                       $auction->{ CopyCount              },
                      "$auction->{ Message                }",
                       $auction->{ PictureKey1            },
                       $auction->{ PictureKey2            },
                       $auction->{ PictureKey3            },
                      "$auction->{ AuctionSite            }")
        || die "Error executing statement: $DBI::errstr\n";
}

# Drop the the backup Auctions database

$sth = $dbh->prepare($dbDrop2) || die "Error preparing statement: $DBI::errstr\n";
$sth->execute        || die "Error Deleting backup table: $DBI::errstr\n";

sleep 5; 

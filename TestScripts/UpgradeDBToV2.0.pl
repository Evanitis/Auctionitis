use strict;
use DBI;
use File::Copy;

my ($sth, $auction, $stdtext, $oldauctions, $oldstdtext, $PicKey);

my $dbh=DBI->connect('dbi:ODBC:Auctionitis') 
   || die "Error opening Auctions database: $DBI::errstr\n";
   $dbh->{LongReadLen} = 65555;            # caters for retrieval of memo fields

#------------------------------------------------------------------------------------------------------------
# SQL table copy commands
#------------------------------------------------------------------------------------------------------------

my $dbCopy1 = qq {  SELECT * FROM   StandardText                            };

my $dbCopy2 = qq {  SELECT * FROM   Auctions                                };

my $dbCopy3 = qq {  INSERT   INTO   StandardText    (       StdName         ,
                                                            StdText         )
                    VALUES                          (       ?,?             ) } ;                
                    
my $dbCopy4 = qq {  INSERT   INTO   Pictures        (       PictureFileName ,
                                                            PhotoID         )
                    VALUES                          (       ?,?             ) } ;                

my $dbCopy6 = qq {  INSERT   INTO   Pictures        (       PictureFileName )
                    VALUES                          (       ?               ) } ;                


my $dbCopy5 = qq {  INSERT   INTO   Auctions        (       Title               ,
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
                                                            ?,?,?,?,?,?,?,?,?,?,?,?  ) } ;                

#------------------------------------------------------------------------------------------------------------
# Clear Table SQL Statements
#------------------------------------------------------------------------------------------------------------

my $dbClear1 = qq {  DELETE * FROM   StandardText                            };

my $dbClear2 = qq {  DELETE * FROM   Auctions                                };

#------------------------------------------------------------------------------------------------------------
# Picture key value SQL STatement
#------------------------------------------------------------------------------------------------------------

my $FindKey = qq {  SELECT PictureKey FROM Pictures WHERE PictureFileName = ? };

#------------------------------------------------------------------------------------------------------------
# Copy the old standard text table into a temporary hash reference
#------------------------------------------------------------------------------------------------------------

$sth = $dbh->prepare( $dbCopy1 )    || die "Error preparing statement: $DBI::errstr\n";
$sth->execute                       || die "Error converting from backup table: $DBI::errstr\n";

$oldstdtext = $sth->fetchall_arrayref({});

#------------------------------------------------------------------------------------------------------------
# Copy the old auction table into a temporary hash reference
#------------------------------------------------------------------------------------------------------------

$sth = $dbh->prepare( $dbCopy2 )    || die "Error preparing statement: $DBI::errstr\n";
$sth->execute                       || die "Error converting from backup table: $DBI::errstr\n";

$oldauctions = $sth->fetchall_arrayref({});

#------------------------------------------------------------------------------------------------------------
# Delete the old database (we already have a backup) and rename the new database to match the ODBC DSN
#------------------------------------------------------------------------------------------------------------

$dbh->disconnect;

unlink("auctionitis.mdb");
# system("del auctionitis.mdb");
move("auctionitis2.mdb","auctionitis.mdb");

my $dbh=DBI->connect('dbi:ODBC:Auctionitis') 
   || die "Error opening Auctions database: $DBI::errstr\n";
   $dbh->{LongReadLen} = 65555;            # caters for retrieval of memo fields

#------------------------------------------------------------------------------------------------------------
# Clear the standard text table then Update it with the data from the old database
#------------------------------------------------------------------------------------------------------------

$sth = $dbh->prepare($dbClear1)     || die "Error preparing statement: $DBI::errstr\n";
$sth->execute                       || die "Error converting from backup table: $DBI::errstr\n";

$sth = $dbh->prepare($dbCopy3)      || die "Error preparing statement: $DBI::errstr\n";
$sth->bind_param(2, $sth, DBI::SQL_LONGVARCHAR);

foreach $stdtext (@$oldstdtext) {

        $sth->execute("$stdtext->{ StdName }",
                      "$stdtext->{ StdText }")
        || die "Error executing statement: $DBI::errstr\n";

}

#------------------------------------------------------------------------------------------------------------
# Update the picture file with all pictures from old auctions that used pictures
#------------------------------------------------------------------------------------------------------------



my %loadedpics;

foreach $auction (@$oldauctions) {


        if ( $auction->{ PictureName } ne "" ) {
        
            if (not exists($loadedpics{"$auction->{ PictureName }"})) {
            
                if ( $auction->{ PhotoID     } ) {

                    $sth = $dbh->prepare($dbCopy4)              || die "Error preparing statement: $DBI::errstr\n";
                    $sth->execute("$auction->{ PictureName }",
                                  "$auction->{ PhotoID     }")  || die "Error executing statement: $DBI::errstr\n";
             
                } else {
                
                    $sth = $dbh->prepare($dbCopy6)              || die "Error preparing statement: $DBI::errstr\n";
                    $sth->execute("$auction->{ PictureName }")  || die "Error executing statement: $DBI::errstr\n";
                
                }
                
                $loadedpics{"$auction->{ PictureName }"} = 1;
            }
        }
}

#------------------------------------------------------------------------------------------------------------
# Update the old auction records with the new picture key details
#------------------------------------------------------------------------------------------------------------

$sth = $dbh->prepare($FindKey)      || die "Error preparing statement: $DBI::errstr\n";

foreach $auction (@$oldauctions) {

        if ( $auction->{ PictureName } ne "" ) {

            $sth->execute( "$auction->{ PictureName }" ) || die "Error executing statement: $DBI::errstr\n";
            
            my $PicData= $sth->fetchall_arrayref({});
            $PicKey = $PicData->[0];
            $auction->{ PictureKey1 } = $PicKey->{ PictureKey };
            
            print "$auction->{TradeMeRef}\t$auction->{PhotoID}\t$auction->{ PictureKey1 } ($PicKey)\n";
        }
}

#------------------------------------------------------------------------------------------------------------
# Update the new auction database with the auction details
# for each record in the backup data base, insert the required fields into the new database and set
# defaults for new fields where appropriate.
#------------------------------------------------------------------------------------------------------------

$sth = $dbh->prepare($dbCopy5) || die "Error preparing statement: $DBI::errstr\n";
$sth->bind_param(2, $sth, DBI::SQL_LONGVARCHAR);

# Calculate the close date using the date loaded and duration values;

my $closedate = "01/01/01";

foreach $auction (@$oldauctions) {

        if ( $auction->{ AuctionLoaded } ) {
            my $timecalc  = time + ($auction->{ DurationHours } * 60);
            my($cdd, $cmm, $cyy)   = (localtime($timecalc))[3,4,5];
            $closedate = $cdd."/".($cmm + 1)."/".($cyy + 1900);
        }

        $sth->execute("$auction->{ Title          }     ",     
                      "$auction->{ Description    }     ",     
                       ""                               ,      
                       ""                               ,      
                       $auction->{ AuctionHeld    }     ,      
                       ""                               ,      
                       $auction->{ AuctionLoaded  }     ? ("CURRENT") : ("PENDING") ,      
                       0                                ,      
                       0                                ,      
                       0                                ,      
                       0                                ,      
                       0                                ,      
                       0                                ,      
                       0                                ,      
                      "$auction->{ TradeMeRef           }",     
                       ""                               ,      
                       $auction->{ DateLoaded           },      
                      "$closedate"                      ,      
                      "00:00:00"                        ,      
                      "$auction->{ CategoryID           }",     
                       $auction->{ MovieRating          },      
                       $auction->{ MovieConfirm         },      
                       $auction->{ AttributeCategory    },     
                      "$auction->{ AttributeName        }",     
                      "$auction->{ AttributeValue       }", 
                      "$auction->{ TMATT104             }",
                      "$auction->{ TMATT104_2           }",
                      "$auction->{ TMATT106             }",
                      "$auction->{ TMATT106_2           }",
                      "$auction->{ TMATT108             }",
                      "$auction->{ TMATT108_2           }",
                      "$auction->{ TMATT111             }",
                      "$auction->{ TMATT112             }",
                      "$auction->{ TMATT115             }",
                      "$auction->{ TMATT117             }",
                      "$auction->{ TMATT118             }",
                       $auction->{ IsNew          }     ,      
                       0                                ,      
                       $auction->{ StartPrice     }     ,      
                       $auction->{ ReservePrice   }     ,      
                       $auction->{ BuyNowPrice    }     ,      
                       $auction->{ DurationHours  }     ,      
                       $auction->{ ClosedAuction  }     ,      
                       $auction->{ AutoExtend     }     ,      
                       $auction->{ Cash           }     ,      
                       $auction->{ Cheque         }     ,      
                       $auction->{ BankDeposit    }     ,      
                      "$auction->{ PaymentInfo    }     ",     
                       $auction->{ FreeShippingNZ }     ,      
                      "$auction->{ ShippingInfo   }     ",     
                       $auction->{ SafeTrader     }     ,      
                       $auction->{ Featured       }     ,      
                       $auction->{ Gallery        }     ,      
                       $auction->{ BoldTitle      }     ,      
                       $auction->{ FeatureCombo   }     ,      
                       $auction->{ HomePage       }     ,      
                       $auction->{ CopyCount      }     ,      
                      "$auction->{ Message        }     ",     
                       $auction->{ PictureKey1    }     ,      
                       0                                ,      
                       0                                ,      
                       "TRADEME"                        )      
                       || die "Error executing statement: $DBI::errstr\n";
}

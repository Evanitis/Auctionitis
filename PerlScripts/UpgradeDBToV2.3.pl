use strict;
use DBI;
use Term::ReadKey;

my ($sth, $SQLStmt, $TMATT038);

my $dbh=DBI->connect('dbi:ODBC:Auctionitis') 
   || die "Error opening Auctions database: $DBI::errstr\n";
   $dbh->{LongReadLen} = 65555;            # caters for retrieval of memo fields

#------------------------------------------------------------------------------------------------------------
# Test whether to proceed or not... PROPERTIES table MUST exist if procedure is to run
#------------------------------------------------------------------------------------------------------------

my $exists = 1;

my $SQL =  qq { SELECT COUNT(*) FROM DBProperties };

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

my $SQL =  qq { SELECT Property_Value FROM DBProperties WHERE Property_Name = 'DatabaseVersion' };

$sth = $dbh->prepare($SQL);

$sth->execute();
my $property = $sth->fetchrow_hashref;

unless ( $property->{ Property_Value } eq "2.2" ) {
    print "Update bypassed - incorrect database version\n";
    $sth->finish;
    $dbh->disconnect;
    exit;
}

sleep 15;

#------------------------------------------------------------------------------------------------------------
# SQL table definition commands
#------------------------------------------------------------------------------------------------------------

#------------------------------------------------------------------------------------------------------------
# Add Columns to the3 auctions table
#------------------------------------------------------------------------------------------------------------

my $dbDef1 = qq { ALTER TABLE Auctions  ADD COLUMN      TMATT038        TEXT(10)    };
my $dbDef2 = qq { ALTER TABLE Auctions  ADD COLUMN      TMATT163        TEXT(5)     };
my $dbDef3 = qq { ALTER TABLE Auctions  ADD COLUMN      TMATT164        TEXT(25)    };
my $dbDef4 = qq { ALTER TABLE Auctions  ADD COLUMN      Pago            LOGICAL     };

#------------------------------------------------------------------------------------------------------------
# Define the Movie Ratings table
#------------------------------------------------------------------------------------------------------------

my $dbDef5 = qq {
    CREATE TABLE    MovieRatings 
    (   MovieRating                 LONG        ,
        MovieRatingText             TEXT(15)    ,
        MovieRatingDescription      TEXT(50)    )
};

#------------------------------------------------------------------------------------------------------------
# Define the Movie Ratings table
#------------------------------------------------------------------------------------------------------------

my $dbDef6 = qq {
    CREATE TABLE    MovieGenres 
    (   Genre_Seq                   LONG        ,
        Genre_Name                  TEXT(25)    ,
        Genre_Value                 TEXT(25)    )
};

# SQL index creation commands
                             
my $dbIndex01   = qq { CREATE  UNIQUE   INDEX   PrimaryKey      ON MovieRatings     ( MovieRating           ) };
my $dbIndex02   = qq { CREATE  UNIQUE   INDEX   PrimaryKey      ON MovieGenres      ( Genre_Seq             ) };

# SQL delete table commands

my $dbDrop1     = qq { DROP TABLE MovieRatings  };
my $dbDrop2     = qq { DROP TABLE MovieGenres   };

#------------------------------------------------------------------------------------------------------------
# SQL to get list of auctions from data base
#------------------------------------------------------------------------------------------------------------

my $GetAuctionsSQL = qq { 
    SELECT  AuctionKey,
            Category
    FROM    Auctions  
};

#------------------------------------------------------------------------------------------------------------
# SQL to Update DVD fields in Auction record
#------------------------------------------------------------------------------------------------------------

$SQLStmt = qq { 
    UPDATE  Auctions  
    SET     Category            = ?,
            AttributeCategory   = ?,
            TMATT038            = ?,
            TMATT163            = ?,
            TMATT164            = ?
    WHERE   AuctionKey          = ? 
};

my $ConvertDVDSQL = $dbh->prepare( $SQLStmt );

#------------------------------------------------------------------------------------------------------------
# SQL Statement to Set Database version property
#------------------------------------------------------------------------------------------------------------

my $SetDBVersionSQL = qq {
    UPDATE  DBProperties
    SET     Property_Value  = '2.3'
    WHERE   Property_Name   = 'DatabaseVersion'
};

#------------------------------------------------------------------------------------------------------------
# SQL Statement for deleting the DVD Movie category values
#------------------------------------------------------------------------------------------------------------

my $DeleteDVDSQL = qq {  
    DELETE  
    FROM    TMCategories
    WHERE   Parent  = 365 
};

#------------------------------------------------------------------------------------------------------------
# SQL Statement for getting the parent category value
#------------------------------------------------------------------------------------------------------------

$SQLStmt = qq {  
    SELECT  Parent
    FROM    TMCategories
    WHERE   Category  = ? 
};

my $GetParentSQL = $dbh->prepare( $SQLStmt );

#------------------------------------------------------------------------------------------------------------
# Add the new columns to the Auctions table
#------------------------------------------------------------------------------------------------------------

$sth = $dbh->do( $dbDef1 )          || print "Error adding Column TMATT038: $DBI::errstr\n";
$sth = $dbh->do( $dbDef2 )          || print "Error adding Column TMATT163: $DBI::errstr\n";
$sth = $dbh->do( $dbDef3 )          || print "Error adding Column TMATT164: $DBI::errstr\n";
$sth = $dbh->do( $dbDef4 )          || print "Error adding Column Pago: $DBI::errstr\n";

# Delete the Movie Ratings table if it exists then re-create it

$sth = $dbh->prepare( $dbDrop1 )    || print "Error preparing statement: $DBI::errstr\n";
$sth->execute                       || print "Error converting from backup table: $DBI::errstr\n";

$sth = $dbh->do( $dbDef5 )          || print "Error creating Movie Ratings table: $DBI::errstr\n";
$sth = $dbh->do( $dbIndex01 )       || print "Error creating Index: $DBI::errstr\n";

# Delete the Movie Genres table if it exists then re-create it

$sth = $dbh->prepare( $dbDrop2 )    || print "Error preparing statement: $DBI::errstr\n";
$sth->execute                       || print "Error converting from backup table: $DBI::errstr\n";

$sth = $dbh->do( $dbDef6 )          || print "Error creating Movie Genres table: $DBI::errstr\n";
$sth = $dbh->do( $dbIndex02 )       || print "Error creating Index: $DBI::errstr\n";

#------------------------------------------------------------------------------------------------------------
# Show input screen for selection of DVD Condition
#------------------------------------------------------------------------------------------------------------

get_condition();

#------------------------------------------------------------------------------------------------------------
# Get the list of Auctions and place them in an arry; 
# Read all auctions and update the DVD attributes as required
#------------------------------------------------------------------------------------------------------------

$sth = $dbh->prepare( $GetAuctionsSQL ) || die "Error preparing statement: $DBI::errstr\n";
$sth->execute                           || die "Error Extracting Auction data: $DBI::errstr\n";

my $auctions = $sth->fetchall_arrayref({});

foreach my $auction (@$auctions) {

    if ( get_parent( $auction->{ Category } ) eq "365" ) {
    
        convert_DVD( $auction->{ AuctionKey }, $auction->{ Category }, $TMATT038 );
    }
    
    else {
    
        my $pc = get_parent( $auction->{ Category } );

        if ( get_parent( $pc ) eq "365" ) {
        
            convert_DVD( $auction->{ AuctionKey }, $pc, $TMATT038 );
        }


    }

}


#------------------------------------------------------------------------------------------------------------
# Delete DVD Movie subcategories
#------------------------------------------------------------------------------------------------------------

my $sth = $dbh->prepare($DeleteDVDSQL)  ||  die "Error preparing statement: $DBI::errstr\n";
$sth->execute  ||  die "Error exexecuting statement: $DBI::errstr\n";


#------------------------------------------------------------------------------------------------------------
# Update the datbase version
#------------------------------------------------------------------------------------------------------------

$sth = $dbh->prepare($SetDBVersionSQL)  || die "Error preparing statement\n: $DBI::errstr\n";
$sth->execute()                         || die "UpdatingDBVersion - Error executing statement: $DBI::errstr\n";

#------------------------------------------------------------------------------------------------------------
# SQL complete so disconnect .... after this use Auctionitis native methods
#------------------------------------------------------------------------------------------------------------

$sth->finish;
$GetParentSQL->finish;
$ConvertDVDSQL->finish;
$dbh->disconnect;

#------------------------------------------------------------------------------------------------------------
# Subroutines
#------------------------------------------------------------------------------------------------------------

sub get_parent {

    my $cat = shift;

    $GetParentSQL->execute($cat);

    my $record = $GetParentSQL->fetchrow_hashref;
    my $parent = $record->{ Parent };

    return $parent;

}

sub convert_DVD {

    my $a = shift;                      # Auction
    my $g = shift;                      # Genre
    
    if    ( length($g) le 3 )   { $g = "0003-0365-0".$g."-"; }
    else                        { $g = "0003-0365-".$g."-";  }

    $ConvertDVDSQL->execute( "365", "365", "$TMATT038", "1,", "$g", $a );

}

sub get_condition {

    my $choice = 0;

    system('cls');
    print "Setup for New DVD Fields\n\n";
    print "Select Default Value for DVD Condition:\n\n";
    print "1 = Brand New\n";
    print "2 = As New\n";
    print "3 = Good\n";
    print "4 = Poor\n\n";

    while ($choice == 0) {

        $choice = get_choice();
        if ($choice == 1)       { $TMATT038 = "Brand New";    }
        elsif ($choice == 2)    { $TMATT038 = "As New";       }
        elsif ($choice == 3)    { $TMATT038 = "Good";         }
        elsif ($choice == 4)    { $TMATT038 = "Poor";         }
        else { 
            system('cls');
            print "Setup for New DVD Fields\n\n";
            print "Select Default Value for DVD Condition:\n\n";
            print "1 = Brand New\n";
            print "2 = As New\n";
            print "3 = Good\n";
            print "4 = Poor\n\n";
            print "$choice is not one of the available options - please make another selection\n\n";
            $choice = 0;                
        }
    }
}

sub get_choice {

    ReadMode 'cbreak';
    my $key = ReadKey(0);
    ReadMode 'normal';
    
    return $key;

}
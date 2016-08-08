use strict;
use DBI;

my ($sth, $SQL);

my $dbh=DBI->connect('dbi:ODBC:Auctionitis') 
   || die "Error opening Auctions database: $DBI::errstr\n";
   $dbh->{ LongReadLen } = 65555;            # caters for retrieval of memo fields

#------------------------------------------------------------------------------------------------------------
# SQL statements for changes to Auctionitis tables
#------------------------------------------------------------------------------------------------------------

my $dbDef01 = qq { ALTER TABLE Pictures ADD     COLUMN OldPhotoID   TEXT(10)    };
my $dbDef02 = qq { ALTER TABLE Pictures DROP    COLUMN PhotoID                  };
my $dbDef03 = qq { ALTER TABLE Pictures ADD     COLUMN PhotoId      TEXT(10)    };
my $dbDef04 = qq { ALTER TABLE Pictures DROP    COLUMN OldPhotoID               };

my $dbIndex01   = qq { DROP   INDEX     PhotoID ON Pictures                                 };
my $dbIndex02   = qq { CREATE INDEX     PhotoID ON Pictures ( PhotoId ) WITH IGNORE NULL    };

my $dbUpdate1 = qq {
    UPDATE  Pictures
    SET     OldPhotoID = PhotoID
};

my $dbUpdate2 = qq {
    UPDATE  Pictures
    SET     PhotoId = OldPhotoID
};


#------------------------------------------------------------------------------------------------------------
# Add the new columns to the Auctions table
#------------------------------------------------------------------------------------------------------------

# Add the old photo column to store the phtoo id in temporarily

$sth = $dbh->do( $dbIndex01 )         || print "Error dropping index PhotoID on table Pictures: $DBI::errstr\n";
$sth = $dbh->do( $dbDef01 )           || print "Error adding Column OldPhotoID on table Pictures: $DBI::errstr\n";

# Set the old photo ID value to the photo ID value

$sth = $dbh->do( $dbUpdate1 )           || print "Error dropping Table OldAuctionDurations: $DBI::errstr\n";

# Drop the PhotoID column then add the PhotoId column (effectively renaming it with a little d)

$sth = $dbh->do( $dbDef02 )           || print "Error dropping Column PhotoID on table Pictures: $DBI::errstr\n";
$sth = $dbh->do( $dbDef03 )           || print "Error adding Column PhotoId on table Pictures: $DBI::errstr\n";
$sth = $dbh->do( $dbIndex02 )           || print "Error adding index PhotoID on table Pictures: $DBI::errstr\n";

# Set the photo ID value back to the old photo ID value

$sth = $dbh->do( $dbUpdate2 )           || print "Error dropping Table OldDeliveryOptions: $DBI::errstr\n";

# Drop the old phto ID column

$sth = $dbh->do( $dbDef04 )           || print "Error dropping Column OldPhotoID on table Pictures: $DBI::errstr\n";

#------------------------------------------------------------------------------------------------------------
# SQL complete so disconnect .... after this use Auctionitis native methods
#------------------------------------------------------------------------------------------------------------

$dbh->disconnect;


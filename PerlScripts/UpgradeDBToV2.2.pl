use strict;
use DBI;
use Win32::TieRegistry;

my ($sth);

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
# Test whether to proceed or not... Database version must be 2.1 to continue
#------------------------------------------------------------------------------------------------------------

my $exists = 1;

my $SQL =  qq { SELECT Property_Value FROM DBProperties WHERE Property_Name = 'DatabaseVersion' };

$sth = $dbh->prepare($SQL);

$sth->execute();
my $property = $sth->fetchrow_hashref;

unless ( $property->{ Property_Value } eq "2.1" ) {
    print "Update bypassed - incorrect database version\n";
    $sth->finish;
    $dbh->disconnect;
    exit;
}

#------------------------------------------------------------------------------------------------------------
# SQL table definition commands
#------------------------------------------------------------------------------------------------------------

# Define the New auctions table

my $dbDef1 = qq { ALTER TABLE Auctions  ADD COLUMN      EndType         TEXT(10)    };
my $dbDef2 = qq { ALTER TABLE Auctions  ADD COLUMN      EndDays         LONG        };
my $dbDef3 = qq { ALTER TABLE Auctions  ADD COLUMN      EndTime         LONG        };
my $dbDef4 = qq { ALTER TABLE Auctions  ADD COLUMN      CashOnPickup    LOGICAL     };
my $dbDef5 = qq { ALTER TABLE Auctions  ADD COLUMN      Paymate         LOGICAL     };
my $dbDef6 = qq { ALTER TABLE Auctions  ALTER COLUMN    PaymentInfo     TEXT(40)    };

#------------------------------------------------------------------------------------------------------------
# SQL Statement for updating the allow editing file
#------------------------------------------------------------------------------------------------------------

my $dbUpdate1 = qq {
    UPDATE  AuctionStatuses
    SET     AllowEdit       = 1
    WHERE   AuctionStatus   = ?
};

#------------------------------------------------------------------------------------------------------------
# SQL Statement to set value of new fields
#------------------------------------------------------------------------------------------------------------

my $dbUpdate2 = qq {
    UPDATE  Auctions
    SET     EndType         = 'DURATION'    ,
            EndDays         = 0             ,      
            EndTime         = 0             ,      
            CashOnPickup    = 0             ,
            Paymate         = 0
};      

#------------------------------------------------------------------------------------------------------------
# SQL Statement for updating the allow editing file
#------------------------------------------------------------------------------------------------------------

my $dbUpdate3 = qq {
    UPDATE  DBProperties
    SET     Property_Value  = '2.2'
    WHERE   Property_Name   = 'DatabaseVersion'
};


#------------------------------------------------------------------------------------------------------------
# Add the new columns to the Auctions table
#------------------------------------------------------------------------------------------------------------

$sth = $dbh->do( $dbDef1 )          || die "Error adding Column EndType: $DBI::errstr\n";
$sth = $dbh->do( $dbDef2 )          || die "Error adding Column EndDays: $DBI::errstr\n";
$sth = $dbh->do( $dbDef3 )          || die "Error adding Column EndTime: $DBI::errstr\n";
$sth = $dbh->do( $dbDef4 )          || die "Error adding Column CashOnPickup: $DBI::errstr\n";
$sth = $dbh->do( $dbDef5 )          || die "Error adding Column Paymate: $DBI::errstr\n";
$sth = $dbh->do( $dbDef6 )          || die "Error modifying Column PaymentInfo: $DBI::errstr\n";

#------------------------------------------------------------------------------------------------------------
# Make sure editing is allowed for the other auction status types
#------------------------------------------------------------------------------------------------------------

$sth = $dbh->prepare($dbUpdate1)    || die "Error preparing statement\n: $DBI::errstr\n";

$sth->execute( "CURRENT"    )       || die "UpdateAllowEdit - Error executing statement: $DBI::errstr\n";
$sth->execute( "SOLD"       )       || die "UpdateAllowEdit - Error executing statement: $DBI::errstr\n";
$sth->execute( "UNSOLD"     )       || die "UpdateAllowEdit - Error executing statement: $DBI::errstr\n";

#------------------------------------------------------------------------------------------------------------
# Update the new field values
#------------------------------------------------------------------------------------------------------------

$sth = $dbh->prepare($dbUpdate2)    || die "Error preparing statement\n: $DBI::errstr\n";
$sth->execute()                     || die "UpdateNewValues - Error executing statement: $DBI::errstr\n";

#------------------------------------------------------------------------------------------------------------
# Update the datbase version
#------------------------------------------------------------------------------------------------------------

$sth = $dbh->prepare($dbUpdate3)    || die "Error preparing statement\n: $DBI::errstr\n";
$sth->execute()                     || die "UpdatingDBVersion - Error executing statement: $DBI::errstr\n";

#------------------------------------------------------------------------------------------------------------
# SQL complete so disconnect .... after this use Auctionitis native methods
#------------------------------------------------------------------------------------------------------------

$sth->finish;
$dbh->disconnect;

my $pound= $Registry->Delimiter("/");
my $key = $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities"};

foreach my $subkey (  $key->SubKeyNames  ) {

    my $pn = $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities/".$subkey."/Defaults/PictureName"};

    $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities/".$subkey."/Defaults/PicturePath"} = $pn;
}

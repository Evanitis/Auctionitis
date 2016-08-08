use strict;
use DBI;
use Win32::TieRegistry;

my ($sth, $SQLStmt);

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

if ( $property->{ Property_Value } eq "2.4" ) {
    print "Update bypassed - database already at Version 2.4\n";
    $sth->finish;
    $dbh->disconnect;
    exit;
}

sleep 15;

#------------------------------------------------------------------------------------------------------------
# SQL table definition commands
#------------------------------------------------------------------------------------------------------------

#------------------------------------------------------------------------------------------------------------
# Define the Views table
#------------------------------------------------------------------------------------------------------------

my $dbDef1 = qq {
    CREATE TABLE    Views 
    (   View_ID                         COUNTER     ,
        View_Name                       TEXT(20)    ,
        View_Description                TEXT(255)   ,
        View_Foreground                 LONG        ,
        View_Background                 LONG        ,
        View_Alt_Background             LONG        ,
        View_FontName                   TEXT(50)    ,
        View_FontSize                   DOUBLE      ,
        View_Title_Foreground           LONG        ,
        View_Title_Background           LONG        ,
        View_Title_FontName             TEXT(50)    ,
        View_Title_FontSize             DOUBLE      ,
        View_Sort_Column                LONG        ,
        View_Sort_Direction             LONG        )
};

#------------------------------------------------------------------------------------------------------------
# Define the View Columns table
#------------------------------------------------------------------------------------------------------------

my $dbDef2 = qq {
    CREATE TABLE    ViewColumns 
    (   Column_ID                       COUNTER     ,
        View_Name                       TEXT(20)    ,
        Column_Name                     TEXT(30)    ,
        Column_Sequence                 LONG        ,
        Column_Title                    TEXT(25)    ,
        Column_ToolTip                  TEXT(30)    ,
        Column_Autosize                 LOGICAL     ,
        Column_Width                    LONG        )
};

#------------------------------------------------------------------------------------------------------------
# SQL Statement to Set Database version property
#------------------------------------------------------------------------------------------------------------

my $SetDBVersionSQL = qq {
    UPDATE  DBProperties
    SET     Property_Value  = '2.4'
    WHERE   Property_Name   = 'DatabaseVersion'
};

#------------------------------------------------------------------------------------------------------------
# Add the new columns to the Auctions table
#------------------------------------------------------------------------------------------------------------

$sth = $dbh->do( $dbDef1 )              || print "Error creating table VIEWS: $DBI::errstr\n";
$sth = $dbh->do( $dbDef2 )              || print "Error creating table VIEWCOLUMNS: $DBI::errstr\n";

#------------------------------------------------------------------------------------------------------------
# Update the datbase version
#------------------------------------------------------------------------------------------------------------

$sth = $dbh->prepare($SetDBVersionSQL)  || die "Error preparing statement\n: $DBI::errstr\n";
$sth->execute()                         || die "UpdatingDBVersion - Error executing statement: $DBI::errstr\n";

#------------------------------------------------------------------------------------------------------------
# SQL complete so disconnect .... after this use Auctionitis native methods
#------------------------------------------------------------------------------------------------------------

$sth->finish;
$dbh->disconnect;

#------------------------------------------------------------------------------------------------------------
# dd  one to Current Sort Column to allow for addition of photo column
#------------------------------------------------------------------------------------------------------------

my $pound= $Registry->Delimiter("/");
my $key = $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Preferences"};

if  ( defined( $key ) ) {
 
    my $data = $key->{"/SortColumn" };
    $data++;
    $key->{"/SortColumn" } = $data;
}

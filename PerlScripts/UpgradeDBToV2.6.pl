use strict;
use DBI;

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
# Test whether to proceed or not... Database version must be 2.6 to continue
#------------------------------------------------------------------------------------------------------------

$SQL =  qq { SELECT Property_Value FROM DBProperties WHERE Property_Name = 'DatabaseVersion' };

$sth = $dbh->prepare($SQL);

$sth->execute();
my $property = $sth->fetchrow_hashref;

if ( $property->{ Property_Value } eq "2.6" ) {
    my $SetDBVersionSQL = qq {
        UPDATE  DBProperties
        SET     Property_Value  = '3.0'
        WHERE   Property_Name   = 'DatabaseVersion'
    };

    $sth = $dbh->prepare( $SetDBVersionSQL )    || print "Error preparing statement\n: $DBI::errstr\n";
    $sth->execute()                             || print "Updating DBVersion - Error executing statement: $DBI::errstr\n";

    $sth->finish;
    $dbh->disconnect;

    exit;
}


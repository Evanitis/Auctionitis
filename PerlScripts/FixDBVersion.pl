# test_SQL.pl

use DBI;

my $dbh=DBI->connect('dbi:ODBC:Auctionitis', {AutoCommit => 1} ) 
     || die "Error opening Auctions database: $DBI::errstr\n";

$dbh->{LongReadLen} = 65555;            # cater for retrieval of memo fields

$exists = 1;

my $SQL =  qq { SELECT COUNT(Paymate) FROM Auctions };

$sth = $dbh->prepare($SQL);

eval { $sth->execute() || die $exists = 0; };

if ( $exists ) {

    my $dbUpdate3 = qq {
        UPDATE  DBProperties
        SET     Property_Value  = '2.2'
        WHERE   Property_Name   = 'DatabaseVersion'
    };

    $sth = $dbh->prepare($dbUpdate3)    || die "Error preparing statement\n: $DBI::errstr\n";
    $sth->execute()                     || die "UpdatingDBVersion - Error executing statement: $DBI::errstr\n";
}

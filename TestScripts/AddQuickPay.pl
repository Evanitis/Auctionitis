use strict;
use Auctionitis;
use DBI;

my ( $sth, $SQL );

my $dbh=DBI->connect('dbi:ODBC:Auctionitis') 
   || die "Error opening Auctions database: $DBI::errstr\n";
   $dbh->{LongReadLen} = 65555;            # caters for retrieval of memo fields

#------------------------------------------------------------------------------------------------------------
# Test whether to proceed or not... PROPERTIES table must not exist if procedure is to run
#------------------------------------------------------------------------------------------------------------

my $exists = 1;

my $SQL =  qq { SELECT COUNT(Quickpay) FROM Auctions };

$sth = $dbh->prepare($SQL);

eval { $sth->execute() || die $exists = 0; };

if ( $exists ) {
    print "Quickpay column already exists - Table already already altered\n";
    exit;
}

#------------------------------------------------------------------------------------------------------------
# SQL Statement for Modifying the Auctions table
#------------------------------------------------------------------------------------------------------------

$SQL = qq { ALTER TABLE Auctions ADD COLUMN Quickpay LOGICAL };

$sth = $dbh->do( $SQL )          || die "Error adding Quickpay column to Auctions table: $DBI::errstr\n";

$dbh->disconnect;



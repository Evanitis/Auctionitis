# test_SQL.pl

use DBI;

my $dbh=DBI->connect('dbi:ODBC:Auctionitis', {AutoCommit => 1} ) 
     || die "Error opening Auctions database: $DBI::errstr\n";


my $SQL = qq {
    UPDATE  AuctionStatuses
    SET     AllowEdit       = 1
    WHERE   AuctionStatus   = ?     };

my $sth = $dbh->prepare($SQL) || die "Error preparing statement $SQL\n: $DBI::errstr\n";

$sth->execute( "CURRENT"    )   || die "UpdateAllowEdit - Error executing statement: $DBI::errstr\n";
$sth->execute( "SOLD"       )   || die "UpdateAllowEdit - Error executing statement: $DBI::errstr\n";
$sth->execute( "UNSOLD"     )   || die "UpdateAllowEdit - Error executing statement: $DBI::errstr\n";

$sth->finish;

print "Done.\n";
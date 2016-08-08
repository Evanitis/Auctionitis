# test_SQL.pl

use DBI;

my $dbh=DBI->connect('dbi:ODBC:AuctionitisDEV', {AutoCommit => 1} ) 
     || die "Error opening Auctions database: $DBI::errstr\n";

$dbh->{LongReadLen} = 65555;            # cater for retrieval of memo fields

my $SQL = qq { ALTER TABLE Auctions RENAME COLUMN ProductCode2 TO ProductCode3 };

my $sth = $dbh->prepare( $SQL );

$sth->execute();


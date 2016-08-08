use strict;
use DBI;

my ($sth, $SQL);

my $dbh=DBI->connect('dbi:ODBC:Auctionitis') 
   || die "Error opening Auctions database: $DBI::errstr\n";
   $dbh->{ LongReadLen } = 65555;            # caters for retrieval of memo fields


my $dbUpdate1 = qq {
    UPDATE  Pictures
    SET     SellaID = ''
};

$sth = $dbh->do( $dbUpdate1 )           || print "Error setting column EFTPOS to 0: $DBI::errstr\n";

$dbh->disconnect;



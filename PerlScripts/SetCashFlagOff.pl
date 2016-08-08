use strict;
use DBI;

#  Connect to the Auctions database to get input data

my $dbh=DBI->connect('dbi:ODBC:Auctionitis')  ||  die "Error opening Auctions database: $DBI::errstr\n";


# Create SQL Statement string

my $SQLstmt = qq {
    UPDATE          Auctions
    SET             Cash    = 0
};

my $sth = $dbh->prepare($SQLstmt) || die "Error preparing statement: $DBI::errstr\n";

$sth->execute()   || die "Error exexecuting statement: $DBI::errstr\n";

$sth->finish;


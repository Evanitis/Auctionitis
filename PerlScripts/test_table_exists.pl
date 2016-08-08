# test_SQL.pl

use DBI;

my $dbh=DBI->connect('dbi:ODBC:Auctionitis', {AutoCommit => 1} ) 
     || die "Error opening Auctions database: $DBI::errstr\n";

$dbh->{LongReadLen} = 65555;            # cater for retrieval of memo fields

my ($exists, $table);
my $SQL =  qq { SELECT COUNT(*) FROM  };

$table = "Auctions";
$exists = 1;

my $sth = $dbh->prepare($SQL.$table);

eval { $sth->execute() || die $exists = 0; };

if ( $exists ) {

    print "Table $table exists\n";
}
else {
    print "Table $table does not exist\n";
}

#

$table = "Properties";

$sth = $dbh->prepare($SQL.$table);

eval { $sth->execute() || die $exists = 0; };

if ( $exists ) {

    print "Table $table exists\n";
}
else {
    print "Table $table does not exist\n";
}


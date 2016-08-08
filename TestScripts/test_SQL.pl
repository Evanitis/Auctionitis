# test_SQL.pl

use DBI;

my $dbh=DBI->connect('dbi:ODBC:Auctionitis', {AutoCommit => 1} ) 
     || die "Error opening Auctions database: $DBI::errstr\n";

$dbh->{LongReadLen} = 65555;            # cater for retrieval of memo fields

# my $SQL =  qq { SELECT * FROM Auctions WHERE AuctionStatus IN('SOLD') };
# my $SQL =  qq { SELECT * FROM Auctions };
# my $SQL =  qq { SELECT MAX(AuctionCycleSequence) FROM AuctionCycles };

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

$table = "Properties";
$exists = 1;

$sth = $dbh->prepare($SQL.$table);

eval { $sth->execute() || die $exists = 0; };

if ( $exists ) {

    print "Table $table exists\n";
}
else {
    print "Table $table does not exist\n";
}

# this was to test the MAX function value being returned

# $data = $sth->fetchrow_array;

# print "Result: $data\n";

# my $value = @data->[0]+10;

# print "Returned data: @data\n";
# print "Returned data: $value\n";

# This is to test the other SQL stuff

# my $data = $sth->fetchall_arrayref({});

# my $counter = 0;

# foreach my $auction (@$data) {
#     print "Retrieved Auction: ".$auction->{ Title }."\n";
#    $counter++;
# }

# print "\nRetrieved $counter Auctions\n";

# test_SQL.pl

use DBI;

my $dbh=DBI->connect('dbi:ODBC:Auctionitis', {AutoCommit => 1} ) 
     || die "Error opening Auctions database: $DBI::errstr\n";

$dbh->{LongReadLen} = 65555;            # cater for retrieval of memo fields

my ($SQL, $solumn, $exists, $table);


$column = "Evan";
$table  = "Auctions";

$SQL =  qq { SELECT COUNT(Evan) FROM $table };

$exists = 1;

my $sth = $dbh->prepare($SQL);

eval { $sth->execute() || die $exists = 0; };

if ( $exists ) {

    print "Column $column in Table $table exists\n";
}
else {
    print "Column $column in Table $table  does not exist\n";
}

#

$exists = 1;

$column = "AuctionRef";
$table  = "Auctions";

$SQL =  qq { SELECT COUNT(Paymate) FROM Auctions };

$sth = $dbh->prepare($SQL);

eval { $sth->execute() || die $exists = 0; };

if ( $exists ) {

    print "Column $column in Table $table exists\n";
}
else {
    print "Column $column in Table $table does not exist\n";
}


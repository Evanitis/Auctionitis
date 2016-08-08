use strict;
use DBI;

my $column = shift;

# Check that a column name has been provided

unless ( defined( $column ) ) {
    print "A column name must be specified to hold the description length\n";
    exit;
}

#  Connect to the Auctions database to get input data

my $dbh=DBI->connect('dbi:ODBC:Auctionitis')  ||  die "Error opening Auctions database: $DBI::errstr\n";

# Check that the provided column name is actually valid

my $SQL =  qq { SELECT TOP 1 $column FROM AUCTIONS };

my $columntest = $dbh->prepare( $SQL );

my $missing;

eval { $columntest->execute() || die $missing = 1; };

if ( $missing ) {
    print "\n\nColumn $column not found in table AUCTIONS; specify a valid column name and try again\n";
    exit;
}

exit;

# Create SQL record selection string

$SQL = qq {
    SELECT          AuctionKey
    FROM            Auctions
};

my $select = $dbh->prepare( $SQL ) || die "Error preparing SELECT statement: $DBI::errstr\n";

# Create SQL update statement

$SQL = qq {
    UPDATE          Auctions
    SET             $column     =   LEN( Description )
    WHERE           AuctionKey  =   ?
};

print $SQL."\n";

# Get the list of auctions to be updated

my $update = $dbh->prepare( $SQL ) || die "Error preparing UPDATE statement: $DBI::errstr\n";

$select->execute();

my $keys = $select->fetchall_arrayref( {} );

# Update the auction with the length of the description in the specified column

foreach my $k ( @$keys ) {
    $update->execute( $k->{ AuctionKey } )   || die "Error executing UPDATE statement: $DBI::errstr\n";
}

print "Done!\n";




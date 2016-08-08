use strict;
use DBI;

my ( $SQLStmt, $fixcount );

my $dbh=DBI->connect('dbi:ODBC:Auctionitis') 
   || die "Error opening Auctions database: $DBI::errstr\n";
   $dbh->{LongReadLen} = 65555;            # caters for retrieval of memo fields

# SQL to get list of auctions from data base

$SQLStmt = qq { 
    SELECT  AuctionKey,
            Title,
            Description
    FROM    Auctions  
};

my $SQLSelect = $dbh->prepare( $SQLStmt );

# SQL to Update Desciption fields in Auction record

$SQLStmt = qq { 
    UPDATE  Auctions  
    SET     Description         = ?
    WHERE   AuctionKey          = ? 
};

my $SQLUpdate = $dbh->prepare( $SQLStmt );
$SQLUpdate->bind_param( 1, $SQLUpdate, DBI::SQL_LONGVARCHAR );   

# Retrieve the list of auctions

$SQLSelect->execute();

my $auctions = $SQLSelect->fetchall_arrayref( {} );

# Process each auction

$fixcount = 0;

foreach my $auction ( @$auctions ) {

    if ( $auction-> { Description } =~ m/FREE Shipping you on EVERY single item/ ) {

        print "Fixing Auction: ".$auction->{ Title }."\n";

        $auction-> { Description } =~ s/FREE Shipping you on EVERY single item/FREE Shipping on EVERY single item/ ;

        $SQLUpdate->execute( $auction-> { Description }, $auction-> { AuctionKey } );

        $fixcount++;
        
    }
}

print "\nCompleted. Fixed ".$fixcount." Auctions.\n\n";
print "pausing for 10 seconds . . .\n";
sleep 10;
print "Bye!\n";


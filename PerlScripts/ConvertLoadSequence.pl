use strict;
use DBI;

my ($sth, $auction, $auctions, @sortedpc);

my $dbh=DBI->connect('dbi:ODBC:Auctionitis') 
   || die "Error opening Auctions database: $DBI::errstr\n";
   $dbh->{LongReadLen} = 65555;            # caters for retrieval of memo fields

#------------------------------------------------------------------------------------------------------------
# SQL Statement definitions
#------------------------------------------------------------------------------------------------------------

# SQL commands

my $ListPC = qq {
    SELECT      DISTINCT        ProductCode
    FROM        Auctions
    WHERE     ( ProductCode     <> ''       )  
    ORDER BY  ( ProductCode                 )  
};

my $UpdateLS = qq {
    UPDATE      Auctions
    SET         LoadSequence    = ?
    WHERE       ProductCode     = ?
};

#------------------------------------------------------------------------------------------------------------
# Get the list of product code and place them in an arry; sort the array
#------------------------------------------------------------------------------------------------------------

$sth = $dbh->prepare( $ListPC )     || die "Error preparing statement: $DBI::errstr\n";
$sth->execute                       || die "Error Extracting Auction data: $DBI::errstr\n";

my $pcodes = $sth->fetchall_arrayref({});

$sth = $dbh->prepare( $UpdateLS )   || die "Error preparing statement: $DBI::errstr\n";

my $tot = scalar( @$pcodes );

my $seq = 10;

foreach my $pcode (@$pcodes) {

    print "Converting Product Code: ".$pcode->{ ProductCode }." (".($seq/10)." of $tot )\n";

    $sth->execute(
        $seq                    ,
        $pcode->{ ProductCode } ,
    );
    
    $seq = $seq + 10;
    
}

$sth->finish;

print "Done!\n";
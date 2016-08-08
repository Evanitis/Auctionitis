use strict;
use DBI;
use Win32::TieRegistry;

my ($sth, $SQL);

my $dbh=DBI->connect('dbi:ODBC:Auctionitis') 
   || die "Error opening Auctions database: $DBI::errstr\n";
   $dbh->{ LongReadLen } = 65555;            # caters for retrieval of memo fields

#------------------------------------------------------------------------------------------------------------
# Test whether to proceed or not... Check Trade Me web site name in AuctionSites Table
#------------------------------------------------------------------------------------------------------------

$SQL =  qq { SELECT COUNT(*) FROM AuctionSites WHERE AuctionSiteName = 'TradeMe' };

$sth = $dbh->prepare($SQL);
$sth->execute();

my $found = $sth->fetchrow_array;

unless ( $found ) {
    print "Trade Me Auction Site name value is OK - fix not run\n";
    $sth->finish;
    $dbh->disconnect;
    exit;
}

#------------------------------------------------------------------------------------------------------------
# Fix the database
#------------------------------------------------------------------------------------------------------------

my $dbUpdate1 = qq {
    UPDATE  AuctionSites
    SET     AuctionSiteName = 'Trade Me'
    WHERE   AuctionSite     = 'TRADEME'
};

$sth = $dbh->do( $dbUpdate1 )           || print "Error setting column EFTPOS to 0: $DBI::errstr\n";

$sth->finish;
$dbh->disconnect;

#------------------------------------------------------------------------------------------------------------
# Fix the Registry
#------------------------------------------------------------------------------------------------------------

my $pound= $Registry->Delimiter("/");

# Set the default Auction Site value 

if ( exists( $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities"} ) ) {

    my $key = $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities"};
    
    foreach my $subkey ( $key->SubKeyNames ) {
        if ( ( exists( $Registry->{ "HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities".$subkey."/Defaults/AuctionSite" } ) )
            and ( $Registry->{ "HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities".$subkey."/Defaults/AuctionSite" } eq 'TradeMe' ) ) {
            $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities".$subkey."/Defaults/AuctionSite"} = 'Trade Me';
        }
    }
}


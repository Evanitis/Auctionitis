use strict;
use DBI;
use Win32::TieRegistry;

my ( $sth, $SQL );

my $dbh=DBI->connect('dbi:ODBC:Auctionitis') 
   || die "Error opening Auctions database: $DBI::errstr\n";
   $dbh->{ LongReadLen } = 65555;            # caters for retrieval of memo fields

#------------------------------------------------------------------------------------------------------------
# Test to determine whether the update has already been processed
# 
# This is done in the installer by testing the prsence of the registry key we add at the end.
#------------------------------------------------------------------------------------------------------------


#------------------------------------------------------------------------------------------------------------
# SQL statements for changes to Auctionitis tables
#------------------------------------------------------------------------------------------------------------

# Reset CLOSED Sella Auctions to CURRENT

$SQL = qq {
    UPDATE  Auctions
    SET     AuctionStatus   = 'CURRENT'
    WHERE   AuctionSite     = 'SELLA'
    AND     AuctionStatus   = 'CLOSED'
};

my $SQL_update_auction_status = $dbh->prepare( $SQL );
$SQL_update_auction_status->execute();

#------------------------------------------------------------------------------------------------------------
# SQL complete so disconnect .... after this use Auctionitis native methods
#------------------------------------------------------------------------------------------------------------

$SQL_update_auction_status->finish();
$dbh->disconnect;

#------------------------------------------------------------------------------------------------------------
# Update Registry Key for Sella delivery options specifyinh other
#------------------------------------------------------------------------------------------------------------

my $pound = $Registry->Delimiter("/");

# Delete the existing ShipInfo defaults

$Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Properties/ReopenSellaAuctions"} = "1";

print "Reopen Sella Auctions...\n";
sleep 5;


use strict;
use DBI;

my ($sth, $SQL);

my $dbh=DBI->connect('dbi:ODBC:Auctionitis') 
   || die "Error opening Auctions database: $DBI::errstr\n";
   $dbh->{ LongReadLen } = 65555;            # caters for retrieval of memo fields

$SQL =  qq { DROP VIEW Auction_Site_Sella };

$sth = $dbh->do( $SQL );

$SQL =  qq { CREATE VIEW  Auction_Site_Sella AS
             SELECT *
             FROM   Auctions
             WHERE  AuctionSite = 'SELLA'
};

$sth = $dbh->do( $SQL );

$SQL =  qq { DROP VIEW Auction_Site_TradeMe };

$sth = $dbh->do( $SQL );

$SQL =  qq { CREATE VIEW  Auction_Site_TradeMe AS
             SELECT *
             FROM   Auctions
             WHERE  AuctionSite = 'TRADEME'
};

$sth = $dbh->do( $SQL );

$SQL =  qq { DROP VIEW Auction_Status_Current };

$sth = $dbh->do( $SQL );

$SQL =  qq { CREATE VIEW Auction_Status_Current AS
             SELECT *
             FROM   Auctions
             WHERE  AuctionStatus = 'CURRENT'
};

$sth = $dbh->do( $SQL );

$SQL =  qq { DROP VIEW Auction_Status_Sold };

$sth = $dbh->do( $SQL );

$SQL =  qq { CREATE VIEW Auction_Status_Sold AS
             SELECT *
             FROM   Auctions
             WHERE  AuctionStatus = 'SOLD'
};

$sth = $dbh->do( $SQL );

$SQL =  qq { DROP VIEW Auction_Status_Unsold };

$sth = $dbh->do( $SQL );

$SQL =  qq { CREATE VIEW Auction_Status_Unsold AS
             SELECT *
             FROM   Auctions
             WHERE  AuctionStatus = 'UNSOLD'
};

$sth = $dbh->do( $SQL );

$SQL =  qq { DROP VIEW Auction_Status_Template };

$sth = $dbh->do( $SQL );

$SQL =  qq { CREATE VIEW Auction_Status_Template AS
             SELECT *
             FROM   Auctions
             WHERE  AuctionStatus = 'TEMPLATE'
};

$sth = $dbh->do( $SQL );

$sth = $dbh->do( $SQL );

$SQL =  qq { DROP VIEW Auction_Status_Clone };

$sth = $dbh->do( $SQL );

$SQL =  qq { CREATE VIEW Auction_Status_Clone AS
             SELECT *
             FROM   Auctions
             WHERE  AuctionStatus = 'CLONE'
};

$sth = $dbh->do( $SQL );

$sth = $dbh->do( $SQL );

$SQL =  qq { DROP VIEW Auction_Status_Pending };

$sth = $dbh->do( $SQL );

$SQL =  qq { CREATE VIEW Auction_Status_Pending AS
             SELECT *
             FROM   Auctions
             WHERE  AuctionStatus = 'PENDING'
};

$sth = $dbh->do( $SQL );

$sth = $dbh->do( $SQL );

$SQL =  qq { DROP VIEW Auction_Status_Closed };

$sth = $dbh->do( $SQL );

$SQL =  qq { CREATE VIEW Auction_Status_Closed AS
             SELECT *
             FROM   Auctions
             WHERE  AuctionStatus = 'CLOSED'
};

$sth = $dbh->do( $SQL );

#------------------------------------------------------------------------------------------------------------
# SQL complete so disconnect .... after this use Auctionitis native methods
#------------------------------------------------------------------------------------------------------------

$dbh->disconnect;



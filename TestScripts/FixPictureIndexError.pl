use strict;
use DBI;

my ($sth, $SQL);

my $dbh=DBI->connect('dbi:ODBC:Auctionitis') 
   || die "Error opening Auctions database: $DBI::errstr\n";
   $dbh->{ LongReadLen } = 65555;            # caters for retrieval of memo fields

#------------------------------------------------------------------------------------------------------------
# SQL statements for changes to Auctionitis tables
#------------------------------------------------------------------------------------------------------------

my $dbIndex01   = qq { DROP   INDEX     PhotoID ON Pictures                                 };
my $dbIndex02   = qq { DROP   INDEX     SellaID ON Pictures                                 };
my $dbIndex03   = qq { CREATE INDEX     PhotoID ON Pictures ( PhotoId ) WITH IGNORE NULL    };
my $dbIndex04   = qq { CREATE INDEX     SellaID ON Pictures ( SellaID ) WITH IGNORE NULL    };

my $dbClean01   = qq { DROP   TABLE     OldAuctionDurations                                 };
my $dbClean02   = qq { DROP   TABLE     OldDeliveryOptions                                  };

#------------------------------------------------------------------------------------------------------------
# Add the new columns to the Auctions table
#------------------------------------------------------------------------------------------------------------

$sth = $dbh->do( $dbIndex01 )           || print "Error dropping index PhotoID on table Pictures: $DBI::errstr\n";
$sth = $dbh->do( $dbIndex02 )           || print "Error dropping index SellaID on table Pictures: $DBI::errstr\n";
$sth = $dbh->do( $dbIndex03 )           || print "Error adding index PhotoID on table Pictures: $DBI::errstr\n";
$sth = $dbh->do( $dbIndex04 )           || print "Error adding index SellaID on table Pictures: $DBI::errstr\n";

$sth = $dbh->do( $dbClean01 )           || print "Error dropping Table OldAuctionDurations: $DBI::errstr\n";
$sth = $dbh->do( $dbClean02 )           || print "Error dropping Table OldDeliveryOptions: $DBI::errstr\n";

#------------------------------------------------------------------------------------------------------------
# SQL complete so disconnect .... after this use Auctionitis native methods
#------------------------------------------------------------------------------------------------------------

$dbh->disconnect;



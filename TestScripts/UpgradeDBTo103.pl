use strict;
use DBI;

my $dbh=DBI->connect('dbi:ODBC:Conversion') 
   || die "Error opening Auctions database: $DBI::errstr\n";
   $dbh->{LongReadLen} = 65555;            # caters for retrieval of memo fields

# Define New version of the Auctions table table so it can be created

my $dbDef = qq { CREATE TABLE Auctions
                             (AuctionKey        COUNTER,
                              Title             TEXT(50),
                              Description       MEMO,
                              IsNew             LOGICAL,
                              AuctionLoaded     LOGICAL,
                              AuctionHeld       LOGICAL,
                              TradeMeRef        TEXT(10),
                              DateLoaded        DATETIME,
                              TradeMeFees       CURRENCY,
                              CategoryID        TEXT(5),
                              MovieRating       LONG,
                              MovieConfirm      LOGICAL,
                              StartPrice        CURRENCY,
                              ReservePrice      CURRENCY,
                              BuyNowPrice       CURRENCY,
                              DurationHours     LONG,
                              ClosedAuction     LOGICAL,
                              AutoExtend        LOGICAL,
                              Cash              LOGICAL,
                              Cheque            LOGICAL,
                              BankDeposit       LOGICAL,
                              PaymentInfo       TEXT(50),
                              FreeShippingNZ    LOGICAL,
                              ShippingInfo      TEXT(50),
                              SafeTrader        LONG,
                              PictureName       TEXT(128),
                              PhotoID           TEXT(10),
                              Featured          LOGICAL,
                              Gallery           LOGICAL,
                              BoldTitle         LOGICAL,
                              FeatureCombo      LOGICAL,
                              HomePage          LOGICAL,
                              Permanent         LOGICAL,
                              CopyCount         LONG,
                              Message           TEXT(50)) } ;

# SQL index creation commands
                             
my $dbIndex1 = qq { CREATE UNIQUE INDEX PrimaryKey on Auctions (AuctionKey) };
my $dbIndex2 = qq { CREATE INDEX CategoryID on Auctions (CategoryID) };
my $dbIndex3 = qq { CREATE INDEX PhotoID on Auctions (PhotoID) };
my $dbIndex4 = qq { CREATE UNIQUE INDEX AuctionKey on Auctions (AuctionKey) };

# SQL table copy commands

my $dbCopy1 = qq { SELECT * INTO AuctionBackup FROM Auctions };
my $dbCopy2 = qq { SELECT * FROM AuctionBackup } ;
my $dbCopy3 = qq { INSERT INTO   Auctions
                                (Title,
                                 Description,
                                 IsNew,
                                 AuctionLoaded,
                                 AuctionHeld,
                                 TradeMeRef,
                                 DateLoaded,
                                 TradeMeFees,
                                 CategoryID,
                                 MovieRating,
                                 MovieConfirm,
                                 StartPrice,
                                 ReservePrice,
                                 BuyNowPrice,
                                 DurationHours,
                                 ClosedAuction,
                                 AutoExtend,
                                 Cash,
                                 Cheque,
                                 BankDeposit,
                                 PaymentInfo,
                                 FreeShippingNZ,
                                 ShippingInfo,
                                 SafeTrader,
                                 PictureName,
                                 PhotoID,
                                 Featured,
                                 Gallery,
                                 BoldTitle,
                                 FeatureCombo,
                                 HomePage,
                                 Permanent,
                                 CopyCount,
                                 Message)
                   VALUES      ( ?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,
                                 ?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,? ) } ;                

# SQL delete table commands

my $dbDrop1 = qq { DROP TABLE Auctions };
my $dbDrop2 = qq { DROP TABLE AuctionBackup };

# Make a copy of the Auctions Table

my $sth = $dbh->prepare($dbCopy1) || die "Error preparing statement: $DBI::errstr\n";
$sth->execute        || die "Error creating backup table: $DBI::errstr\n";

# Drop the The existing Auctions database

$sth = $dbh->prepare($dbDrop1) || die "Error preparing statement: $DBI::errstr\n";
$sth->execute        || die "Error Deleting old table: $DBI::errstr\n";

# Create the new Auctions database

$sth = $dbh->prepare($dbDef) || die "Error preparing statement: $DBI::errstr\n";
$sth->execute        || die "Error Creating database: $DBI::errstr\n";

$sth = $dbh->prepare($dbIndex1) || die "Error preparing statement: $DBI::errstr\n";
$sth->execute        || die "Error Creating Primary Key: $DBI::errstr\n";

$sth = $dbh->prepare($dbIndex2) || die "Error preparing statement: $DBI::errstr\n";
$sth->execute        || die "Error Creating CategoryID index: $DBI::errstr\n";

$sth = $dbh->prepare($dbIndex3) || die "Error preparing statement: $DBI::errstr\n";
$sth->execute        || die "Error Creating PhotoID index: $DBI::errstr\n";

$sth = $dbh->prepare($dbIndex4) || die "Error preparing statement: $DBI::errstr\n";
$sth->execute        || die "Error Creating AuctionKey index: $DBI::errstr\n";

# Copy the backup Auctions Table into the new database

$sth = $dbh->prepare($dbCopy2) || die "Error preparing statement: $DBI::errstr\n";
$sth->execute        || die "Error converting from backup table: $DBI::errstr\n";

my $inputdata = $sth->fetchall_arrayref();
foreach my $auction (@$inputdata) {

# for each record in the backup data base, insert the required fields into the new database and set
# defaults for new fields where appropriate.


        $sth = $dbh->prepare($dbCopy3) || die "Error preparing statement: $DBI::errstr\n";
        $sth->bind_param(2, $sth, DBI::SQL_LONGVARCHAR);
        print "Auction $auction->[1] \n";
        $sth->execute("$auction->[1]",
                      "$auction->[2]",
                       $auction->[10],
                       $auction->[3],
                       $auction->[4],
                      "$auction->[5]",
                       $auction->[6],
                       $auction->[7],
                      "$auction->[8]",
                       0,
                       0,
                       $auction->[10],
                       $auction->[11],
                       $auction->[12],
                       $auction->[13],
                       $auction->[15],
                       $auction->[16],
                       $auction->[17],
                       $auction->[18],
                       $auction->[19],
                      "$auction->[20]",
                       $auction->[21],
                      "$auction->[22]",
                       $auction->[23],
                      "$auction->[24]",
                      "$auction->[25]",
                       $auction->[26],
                       $auction->[27],
                       $auction->[28],
                       $auction->[29],
                       $auction->[30],
                       $auction->[31],
                       $auction->[33],
                      "$auction->[34]")
        || die "Error executing statement: $DBI::errstr\n";
}

# Drop the the backup Auctions database

$sth = $dbh->prepare($dbDrop2) || die "Error preparing statement: $DBI::errstr\n";
$sth->execute        || die "Error Deleting backup table: $DBI::errstr\n";

sleep 5; 
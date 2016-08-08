use DBI;
use Win32::ODBC;



#    $dbh=DBI->connect('dbi:ODBC:'.$DB) 
#         || die "Error opening Auctions database: $DBI::errstr\n";

    my $db=new Win32::ODBC( "Driver=ODBC;DBQ=C:\\Evan\\Auctionitis103\\auctionitis.mdb;FIL=MS Access");

        
    my $SQL =  qq { SELECT *
                    FROM      Auctions
                    WHERE ( ( AuctionStatus =  'PENDING') 
                    AND     ( Held          =  0        ) )        };

    print $SQL;

    $db->Sql("SELECT * FROM Auctions");

    while ($db->FetchRow()) {
        my(%data) = $db->DataHash();
        print "$auction->{AuctionRef} $auction->{Description} \n";
    }

    $db->Close();


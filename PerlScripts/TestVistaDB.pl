use DBI;
use DBD::ADO;


    # my $dsn="Provider=VistaDB;DatabaseName=C:\evan\auctionitis103\trauctionitis.vdb;";
    
    my $dsn = "Provider=VistaDBOLEDB20.VistaDBOLEDB;;Access Mode=Local;Database Name=trauctionitis.vdb";
    my $dbh = DBI->connect("dbi:ADO:$dsn") or die $DBI::errstr;
        
    my $SQL =  qq { SELECT *
                    FROM      Auctions
                    WHERE ( ( AuctionStatus =  'CURRENT') 
                    AND     ( Held          =  False   ) )        };

    print $SQL;

    my $start = time;

    my $sth = $dbh->prepare($SQL);
    $sth->execute();

    my $data = $sth->fetchall_arrayref({});

    foreach my $auction (@$data) {
        print "Auction: ".$auction->{ AuctionRef }."\n";
    }

    my $end = time;
    
    my $elapsed = $end - $start;
    
    print "Vista DB SQL Duration: $elapsed\n";


use DBD::ADO;


# my $dsn="Provider=VistaDB;DatabaseName=C:\evan\auctionitis103\trauctionitis.vdb;";

    my $dsn = "trauctionitis";
    $dbh=DBI->connect('dbi:ODBC:'.$dsn) 
         || die "Error opening Auctions database: $DBI::errstr\n";
        
    $dbh->{LongReadLen} = 65555;            # cater for retrieval of memo fields


    my $SQL =  qq { SELECT *
                    FROM      Auctions
                    WHERE ( ( AuctionStatus =  'CURRENT') 
                    AND     ( Held          =  0   ) )        };

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

    print "Access DB SQL Duration: $elapsed\n";


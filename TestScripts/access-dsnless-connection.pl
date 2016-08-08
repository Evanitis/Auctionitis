my $server = shift;

    my $DSN     =   "driver={Microsoft Access Driver (*.mdb)};";    # Driver Name
    $DSN        .=  "DBQ=\\\\".$server;                                                  # Server name
    $DSN        .=  "\\Auctionitis\\Auctionitis.mdb";                           # File Name

    $dbh        =   DBI->connect("dbi:ODBC:$DSN",'','');

    $dbh->{ LongReadLen } = 65555;                                                  # cater for retrieval of memo fields
}

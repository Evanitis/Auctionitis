use strict;
use DBI;
use Win32::TieRegistry;

my $dbh=DBI->connect('dbi:ODBC:Auctionitis') 
   || die "Error opening Auctions database: $DBI::errstr\n";


#------------------------------------------------------------------------------------------------------------
# Check whether to continue by attempting to extract an obsolete value from the Duration table
#------------------------------------------------------------------------------------------------------------

my $SQL = qq {  
        SELECT  COUNT(*)
        FROM    AuctionDurations
        WHERE   DurationHours  = 1440
};

my $sth = $dbh->prepare($SQL) 
   || die "Error preparing statement: $DBI::errstr\n";

$sth->execute() 
      || die "Error exexecuting statement: $DBI::errstr\n";

my $found=$sth->fetchrow_array;

unless ( $found ) {
    print "Data already converted - ending immediately\n";
    $sth->finish;
    $dbh->disconnect;
    exit;
}

#------------------------------------------------------------------------------------------------------------
# SQL Statement for deleting the obsolete Auction Durations from the Durations table
#------------------------------------------------------------------------------------------------------------

$SQL = qq {  
    DELETE  
    FROM    AuctionDurations
    WHERE   DurationHours  = ? 
};

$sth = $dbh->prepare($SQL) 
   || die "Error preparing statement: $DBI::errstr\n";

$sth->execute( 360 );
$sth->execute( 720 );
$sth->execute( 1440 );

#------------------------------------------------------------------------------------------------------------
# SQL Statement to convert durations of all auctions with obsolete durations
#------------------------------------------------------------------------------------------------------------

$SQL = qq {
    UPDATE  Auctions
    SET     DurationHours   = 1440
    WHERE   DurationHours   = ?
};

$sth = $dbh->prepare($SQL) 
   || die "Error preparing statement: $DBI::errstr\n";

$sth->execute( 360 );
$sth->execute( 720 );
$sth->execute( 1440 );

#------------------------------------------------------------------------------------------------------------
# Alter the default duration values stored in the registry (store as value not combo box list index)
#------------------------------------------------------------------------------------------------------------

my $pound= $Registry->Delimiter("/");
my $key = $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities"};

foreach my $subkey (  $key->SubKeyNames  ) {

    if ( $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities/".$subkey."/Defaults/AuctionDuration"} eq "360" ) {
        $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities/".$subkey."/Defaults/AuctionDuration"} = "2880";
    }
    elsif ( $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities/".$subkey."/Defaults/AuctionDuration"} eq "720" ) {
        $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities/".$subkey."/Defaults/AuctionDuration"} = "2880";
    }
    elsif ( $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities/".$subkey."/Defaults/AuctionDuration"} eq "720" ) {
        $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities/".$subkey."/Defaults/AuctionDuration"} = "2880";
    }
}

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
        WHERE   DurationHours  = 120
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

$sth->execute( 120 );
$sth->execute( 180 );

#------------------------------------------------------------------------------------------------------------
# SQL Statement to convert durations of all auctions with obsolete durations
#------------------------------------------------------------------------------------------------------------

$SQL = qq {
    UPDATE  Auctions
    SET     DurationHours   = 360
    WHERE   DurationHours   = ?
};

$sth = $dbh->prepare($SQL) 
   || die "Error preparing statement: $DBI::errstr\n";

$sth->execute( 120 );
$sth->execute( 180 );

#------------------------------------------------------------------------------------------------------------
# Alter the default duration values stored in the registry (store as value not combo box list index)
#------------------------------------------------------------------------------------------------------------

my $pound= $Registry->Delimiter("/");
my $key = $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities"};

foreach my $subkey (  $key->SubKeyNames  ) {

    if ( $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities/".$subkey."/Defaults/AuctionDuration"} eq "0" ) {
        $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities/".$subkey."/Defaults/AuctionDuration"} = "360";
    }
    elsif ( $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities/".$subkey."/Defaults/AuctionDuration"} eq "1" ) {
        $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities/".$subkey."/Defaults/AuctionDuration"} = "360";
    }
    elsif ( $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities/".$subkey."/Defaults/AuctionDuration"} eq "2" ) {
        $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities/".$subkey."/Defaults/AuctionDuration"} = "360";
    }
    elsif ( $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities/".$subkey."/Defaults/AuctionDuration"} eq "3" ) {
        $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities/".$subkey."/Defaults/AuctionDuration"} = "720";
    }
    elsif ( $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities/".$subkey."/Defaults/AuctionDuration"} eq "4" ) {
        $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities/".$subkey."/Defaults/AuctionDuration"} = "1440";
    }
    elsif ( $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities/".$subkey."/Defaults/AuctionDuration"} eq "5" ) {
        $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities/".$subkey."/Defaults/AuctionDuration"} = "2880";
    }
    elsif ( $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities/".$subkey."/Defaults/AuctionDuration"} eq "6" ) {
        $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities/".$subkey."/Defaults/AuctionDuration"} = "4320";
    }
    elsif ( $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities/".$subkey."/Defaults/AuctionDuration"} eq "7" ) {
        $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities/".$subkey."/Defaults/AuctionDuration"} = "5760";
    }
    elsif ( $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities/".$subkey."/Defaults/AuctionDuration"} eq "8" ) {
        $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities/".$subkey."/Defaults/AuctionDuration"} = "7200";
    }
    elsif ( $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities/".$subkey."/Defaults/AuctionDuration"} eq "9" ) {
        $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities/".$subkey."/Defaults/AuctionDuration"} = "8640";
    }
    elsif ( $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities/".$subkey."/Defaults/AuctionDuration"} eq "10" ) {
        $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities/".$subkey."/Defaults/AuctionDuration"} = "14400";
    }
}

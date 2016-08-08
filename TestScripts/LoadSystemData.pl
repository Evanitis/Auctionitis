#!C:\perl\bin\perl.exe -w
#LoadSystemData.plx

use strict;
use DBI;

my ($system, $manager, $CPU_1, $CPU_2, $CPU_3, $CPU_4, $CPU_5);
my ($dbh, $sth); 

# Connection variables - remove to another script or the environment at some stage
    local $ENV{"DBI_DRIVER"} = "mysql";
    local $ENV{"DBI_DSN"} = "InterSect";
    local $ENV{"DBI_USER"} = "DrMofo";
    local $ENV{"DBI_PASS"} = "Manson";

    $dbh=DBI->connect('dbi:mysql:InterSect') || die "Error opening database: $DBI::errstr\n";

# Skeleton SQL prepare statement....
#   $sth = $dbh->prepare( qq { INSERT INTO managed_systems (SYSTEM_NAME, SYSTEM_MANAGER_ID, CPU_DATA_1, CPU_DATA_2, CPU_DATA_3, CPU_DATA_4, CPU_DATA_5) Values(?,?,?,?,?,?,?)}) || die "Error preparing statement: $DBI::errstr\n";

    #-----------------------------------------
    # Set values for each system and process....
    #-----------------------------------------
    $system = "S100D14M";
    $manager = "Evan Harris";
    $CPU_1 = "Batch";
    $CPU_2 = "Interactive";
    $CPU_3 = "System";
    $sth = $dbh->prepare( qq { INSERT INTO managed_systems (SYSTEM_NAME, SYSTEM_MANAGER_ID, CPU_DATA_1, CPU_DATA_2, CPU_DATA_3) Values(?,?,?,?,?)}) || die "Error preparing statement: $DBI::errstr\n";
    $sth->execute($system, $manager, $CPU_1, $CPU_2, $CPU_3) || die "Error executing statement: $DBI::errstr\n";

    #-----------------------------------------
    # Set values for each system and process....
    #-----------------------------------------
    $system = "SUN1";
    $manager = "Marcus Finlay";
    $CPU_1 = "%usr";
    $CPU_2 = "%sys";
    $CPU_3 = "%wio";
    $CPU_4 = "%idle";
    $sth = $dbh->prepare( qq { INSERT INTO managed_systems (SYSTEM_NAME, SYSTEM_MANAGER_ID, CPU_DATA_1, CPU_DATA_2, CPU_DATA_3, CPU_DATA_4) Values(?,?,?,?,?,?)}) || die "Error preparing statement: $DBI::errstr\n";
    $sth->execute($system, $manager, $CPU_1, $CPU_2, $CPU_3, $CPU_4) || die "Error executing statement: $DBI::errstr\n";

    #-----------------------------------------
    # End of data end updates
    #-----------------------------------------
    $dbh->disconnect || die "Error disconnecting: $DBI::errstr\n";

    

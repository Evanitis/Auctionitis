#!C:\perl\bin\perl.exe -w
#LoadGraphData.plx

use strict;
use DBI;

my ($year, $month, $day, $batch_CPU, $int_CPU, $sys_CPU, $storage);
 
 # Connection variables - remove to another script or the environment at some stage
    local $ENV{"DBI_DRIVER"} = "mysql";
    local $ENV{"DBI_DSN"} = "Reports";
    local $ENV{"DBI_USER"} = "DrMofo";
    local $ENV{"DBI_PASS"} = "Manson";
    my ($dbh, $sth);
    $dbh=DBI->connect('dbi:mysql:Reports') || die "Error opening database: $DBI::errstr\n";

    $sth = $dbh->prepare( qq { INSERT INTO Performance_stats (PYear, PMonth, PDay, batch_CPU, int_CPU, sys_CPU, storage) Values(?,?,?,?,?,?,?)}) || die "Error preparing statement: $DBI::errstr\n";
    
    $year=2002;
    $month=2;
    
    # Set values for each day and process....
    
    #-----------------------------------------
    $day=1;
    
    $batch_CPU=12;
    $int_CPU=15;
    $sys_CPU=9;
    $storage=80.45;
    
    $sth->execute($year, $month, $day, $batch_CPU, $int_CPU, $sys_CPU, $storage) || die "Error executing statement: $DBI::errstr\n";
    #-----------------------------------------
    $day=2;
    
    $batch_CPU=16.5;
    $int_CPU=15.2;
    $sys_CPU=19.4;
    $storage=82.87;
    
    $sth->execute($year, $month, $day, $batch_CPU, $int_CPU, $sys_CPU, $storage) || die "Error executing statement: $DBI::errstr\n";
    #-----------------------------------------
    $day=3;
    
    $batch_CPU=13.25;
    $int_CPU=28.92;
    $sys_CPU=12.67;
    $storage=73.21;
    
    $sth->execute($year, $month, $day, $batch_CPU, $int_CPU, $sys_CPU, $storage) || die "Error executing statement: $DBI::errstr\n";
    #-----------------------------------------
    $day=4;
    
    $batch_CPU=45.76;
    $int_CPU=25.04;
    $sys_CPU=16.43;
    $storage=78.83;
    
    $sth->execute($year, $month, $day, $batch_CPU, $int_CPU, $sys_CPU, $storage) || die "Error executing statement: $DBI::errstr\n";
    #-----------------------------------------
    $day=5;
    
    $batch_CPU=18.24;
    $int_CPU=40.67;
    $sys_CPU=12.56;
    $storage=80.23;
    
    $sth->execute($year, $month, $day, $batch_CPU, $int_CPU, $sys_CPU, $storage) || die "Error executing statement: $DBI::errstr\n";
    #-----------------------------------------
    $day=6;
    
    $batch_CPU=17.5;
    $int_CPU=21.4;
    $sys_CPU=9.8;
    $storage=85.26;
    
    $sth->execute($year, $month, $day, $batch_CPU, $int_CPU, $sys_CPU, $storage) || die "Error executing statement: $DBI::errstr\n";
    #-----------------------------------------
    $day=7;
    
    $batch_CPU=34.1;
    $int_CPU=42.8;
    $sys_CPU=14.9;
    $storage=92.05;
    
    $sth->execute($year, $month, $day, $batch_CPU, $int_CPU, $sys_CPU, $storage) || die "Error executing statement: $DBI::errstr\n";
    #-----------------------------------------
    $day=8;
    
    $batch_CPU=12;
    $int_CPU=15;
    $sys_CPU=9;
    $storage=90.45;
    
    $sth->execute($year, $month, $day, $batch_CPU, $int_CPU, $sys_CPU, $storage) || die "Error executing statement: $DBI::errstr\n";
    #-----------------------------------------
    $day=9;
    
    $batch_CPU=12;
    $int_CPU=15;
    $sys_CPU=9;
    $storage=87.45;
    
    $sth->execute($year, $month, $day, $batch_CPU, $int_CPU, $sys_CPU, $storage) || die "Error executing statement: $DBI::errstr\n";
    #-----------------------------------------
    $day=10;
    
    $batch_CPU=12;
    $int_CPU=15;
    $sys_CPU=9;
    $storage=86.45;
    
    $sth->execute($year, $month, $day, $batch_CPU, $int_CPU, $sys_CPU, $storage) || die "Error executing statement: $DBI::errstr\n";
    #-----------------------------------------
    $day=11;
    
    $batch_CPU=12;
    $int_CPU=15;
    $sys_CPU=9;
    $storage=85.45;
    
    $sth->execute($year, $month, $day, $batch_CPU, $int_CPU, $sys_CPU, $storage) || die "Error executing statement: $DBI::errstr\n";
    #-----------------------------------------
    $day=12;
    
    $batch_CPU=12;
    $int_CPU=15;
    $sys_CPU=9;
    $storage=83.45;
    
    $sth->execute($year, $month, $day, $batch_CPU, $int_CPU, $sys_CPU, $storage) || die "Error executing statement: $DBI::errstr\n";
    #-----------------------------------------
    $day=13;
    
    $batch_CPU=12;
    $int_CPU=15;
    $sys_CPU=9;
    $storage=77.45;
    
    $sth->execute($year, $month, $day, $batch_CPU, $int_CPU, $sys_CPU, $storage) || die "Error executing statement: $DBI::errstr\n";
    #-----------------------------------------
    $day=14;
    
    $batch_CPU=12;
    $int_CPU=15;
    $sys_CPU=9;
    $storage=72.45;
    
    $sth->execute($year, $month, $day, $batch_CPU, $int_CPU, $sys_CPU, $storage) || die "Error executing statement: $DBI::errstr\n";
    #-----------------------------------------
    $day=15;
    
    $batch_CPU=12;
    $int_CPU=15;
    $sys_CPU=9;
    $storage=74.45;
    
    $sth->execute($year, $month, $day, $batch_CPU, $int_CPU, $sys_CPU, $storage) || die "Error executing statement: $DBI::errstr\n";
    #-----------------------------------------
    $day=16;
    
    $batch_CPU=12;
    $int_CPU=15;
    $sys_CPU=9;
    $storage=75.45;
    
    $sth->execute($year, $month, $day, $batch_CPU, $int_CPU, $sys_CPU, $storage) || die "Error executing statement: $DBI::errstr\n";
    #-----------------------------------------
    $day=17;
    
    $batch_CPU=12;
    $int_CPU=15;
    $sys_CPU=9;
    $storage=75.45;
    
    $sth->execute($year, $month, $day, $batch_CPU, $int_CPU, $sys_CPU, $storage) || die "Error executing statement: $DBI::errstr\n";
    #-----------------------------------------
    $day=18;
    
    $batch_CPU=12;
    $int_CPU=15;
    $sys_CPU=9;
    $storage=76.45;
    
    $sth->execute($year, $month, $day, $batch_CPU, $int_CPU, $sys_CPU, $storage) || die "Error executing statement: $DBI::errstr\n";
    #-----------------------------------------
    $day=19;
    
    $batch_CPU=12;
    $int_CPU=15;
    $sys_CPU=9;
    $storage=79.45;
    
    $sth->execute($year, $month, $day, $batch_CPU, $int_CPU, $sys_CPU, $storage) || die "Error executing statement: $DBI::errstr\n";
    #-----------------------------------------
    $day=20;
    
    $batch_CPU=12;
    $int_CPU=15;
    $sys_CPU=9;
    $storage=88.45;
    
    $sth->execute($year, $month, $day, $batch_CPU, $int_CPU, $sys_CPU, $storage) || die "Error executing statement: $DBI::errstr\n";
    #-----------------------------------------
    $day=21;
    
    $batch_CPU=12;
    $int_CPU=15;
    $sys_CPU=9;
    $storage=80.45;
    
    $sth->execute($year, $month, $day, $batch_CPU, $int_CPU, $sys_CPU, $storage) || die "Error executing statement: $DBI::errstr\n";
    #-----------------------------------------
    $day=22;
    
    $batch_CPU=12;
    $int_CPU=15;
    $sys_CPU=9;
    $storage=81.45;
    
    $sth->execute($year, $month, $day, $batch_CPU, $int_CPU, $sys_CPU, $storage) || die "Error executing statement: $DBI::errstr\n";
    #-----------------------------------------
    $day=23;
    
    $batch_CPU=12;
    $int_CPU=15;
    $sys_CPU=9;
    $storage=82.45;
    
    $sth->execute($year, $month, $day, $batch_CPU, $int_CPU, $sys_CPU, $storage) || die "Error executing statement: $DBI::errstr\n";
    #-----------------------------------------
    $day=24;
    
    $batch_CPU=12;
    $int_CPU=15;
    $sys_CPU=9;
    $storage=81.45;
    
    $sth->execute($year, $month, $day, $batch_CPU, $int_CPU, $sys_CPU, $storage) || die "Error executing statement: $DBI::errstr\n";
    #-----------------------------------------
    $day=25;
    
    $batch_CPU=12;
    $int_CPU=15;
    $sys_CPU=9;
    $storage=82.45;
    
    $sth->execute($year, $month, $day, $batch_CPU, $int_CPU, $sys_CPU, $storage) || die "Error executing statement: $DBI::errstr\n";
    #-----------------------------------------
    $day=26;
    
    $batch_CPU=12;
    $int_CPU=15;
    $sys_CPU=9;
    $storage=83.45;
    
    $sth->execute($year, $month, $day, $batch_CPU, $int_CPU, $sys_CPU, $storage) || die "Error executing statement: $DBI::errstr\n";
    #-----------------------------------------
    $day=27;
    
    $batch_CPU=12;
    $int_CPU=15;
    $sys_CPU=9;
    $storage=82.45;
    
    $sth->execute($year, $month, $day, $batch_CPU, $int_CPU, $sys_CPU, $storage) || die "Error executing statement: $DBI::errstr\n";
    #-----------------------------------------
    $day=28;
    
    $batch_CPU=12;
    $int_CPU=15;
    $sys_CPU=9;
    $storage=78.45;
    
    $sth->execute($year, $month, $day, $batch_CPU, $int_CPU, $sys_CPU, $storage) || die "Error executing statement: $DBI::errstr\n";
    #-----------------------------------------
    # End of data end updates
    
    $dbh->disconnect || die "Error disconnecting: $DBI::errstr\n";

    

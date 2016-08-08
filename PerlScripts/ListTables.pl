#!C:\perl\bin\perl.exe
#AddChgControl.plx

use strict;
use warnings;
use DBI;

# Connection variables - remove to another script or the environment at some stage

local $ENV{"DBI_DRIVER"} = "ODBC";
local $ENV{"DBI_DSN"} = "DRMofoCD";
local $ENV{"DBI_USER"} = "";
local $ENV{"DBI_PASS"} = "";

my ($dbh, $sth);
    
$dbh=DBI->connect('dbi:ODBC:DrMofoCD') || die "Error opening database: $DBI::errstr\n";

# $dbh->func(xxx, GetInfo)
$sth = $dbh->tables;
my $matches=$sth->rows();
unless ($matches) {
    print "No records returned by selection\n";
} else {
    print "$matches records returned by selection:\n";
        while (my @row = $sth ->fetchrow_array) {
            print "@row\n";
        }
}        

$sth->finish;

$dbh->disconnect  || die "Failed to disconnect: $DBI::errstr\n";
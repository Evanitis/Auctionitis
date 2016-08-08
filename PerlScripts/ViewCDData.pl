#!C:\perl\bin\perl.exe
#ViewCDData.plx

use strict;
use warnings;
use DBI;

local $ENV{"DBI_DRIVER"} = "ODBC";
local $ENV{"DBI_DSN"} = "DrMofoCD";
local $ENV{"DBI_USER"} = "";
local $ENV{"DBI_PASS"} = "";

my $dbh=DBI->connect('dbi:ODBC:DrMofoCD') || die "Error opening database: $DBI::errstr\n";    
my $sth=$dbh->prepare ("PROCEDURE SHOW TABLES");
$sth->execute();

$dbh->disconnect  || die "Failed to disconnect: $DBI::errstr\n";
#!C:\perl\bin\perl.exe
#dbtest.plx

use strict;
use warnings;
use DBI;

local $ENV{"DBI_DRIVER"} = "mysql";
local $ENV{"DBI_DSN"} = "ChangeControl";
local $ENV{"DBI_USER"} = "DrMofo";
local $ENV{"DBI_PASS"} = "Manson";

my $dbh=DBI->connect('dbi:mysql:ChangeControl', 'DrMofo', 'Manson') || die "Error opening database: $DBI::errstr\n";    
#my $sth=$dbh->prepare ("PROCEDURE SHOW TABLES");

my $sth=$dbh->prepare("SHOW TABLES");

$sth->execute();

my $matches=$sth->rows();
unless ($matches) {
    print "No records returned...\n";
}   else {
    print "Table list:\n";
        while (my @row = $sth->fetchrow_array) {
            print "@row\n";
        }
}

$sth->finish();

$dbh->disconnect  || die "Failed to disconnect: $DBI::errstr\n";
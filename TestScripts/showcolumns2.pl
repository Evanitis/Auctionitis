#!C:\perl\bin\perl.exe
#dbtest.plx

use strict;
use warnings;
use DBI;

my ($dbh, $sth, $matches, $table, @rowvalue);

local $ENV{"DBI_DRIVER"} = "mysql";
local $ENV{"DBI_DSN"} = "ChangeControl";
local $ENV{"DBI_USER"} = "DrMofo";
local $ENV{"DBI_PASS"} = "Manson";

$dbh=DBI->connect("dbi:mysql:ChangeControl", "DrMofo", "Manson") || die "Error opening database: $DBI::errstr\n";    

$table="change_control_detail";

$sth=$dbh->prepare("DESCRIBE $table");

$sth->execute();

$matches=$sth->rows();
unless ($matches) {
    print "No records returned...\n";
}   else {
    print "$matches Columns returned:\n";
        while (@rowvalue = $sth->fetchrow_array) {
            print "@rowvalue\n";
        }
}

$sth->finish();

$dbh->disconnect  || die "Failed to disconnect: $DBI::errstr\n";
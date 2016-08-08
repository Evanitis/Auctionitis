#!C:\perl\bin\perl.exe
#dbtest.plx

use strict;
use warnings;
use DBI;

my ($table, $database, $dbh, $sth, $matches, @row);

local $ENV{"DBI_DRIVER"} = "mysql";
#local $ENV{"DBI_DSN"} = "CDDataBase";
local $ENV{"DBI_USER"} = "DrMofo";
local $ENV{"DBI_PASS"} = "Manson";

# Set database and table to values entered on command line
$database = $ARGV[0];
$table    = $ARGV[1];

$dbh=DBI->connect("dbi:mysql:$database", "DrMofo", "Manson") || die "Error opening database: $DBI::errstr\n";    

$sth=$dbh->prepare("DESCRIBE $table");

$sth->execute();

$matches=$sth->rows();
unless ($matches) {
    print "No records returned...\n";
}   else {
    print "$matches Columns returned:\n";
        while (@row = $sth->fetchrow_array) {
            print join(", ", map {defined $_ ? $_ : "(null)"} @row), "\n";
        }
}

$sth->finish();

$dbh->disconnect  || die "Failed to disconnect: $DBI::errstr\n";
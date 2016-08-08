#!C:\perl\bin\perl.exe
#dbtest.plx

use strict;
use warnings;
use DBI;
    
my $dbh=DBI->connect('dbi:mysql:ChangeControl', 'DrMofo', 'Manson') || die "Error opening database";
print "hello\n";
$dbh->disconnect || die "Failed to Disconnect\n";
print "goodbye\n";
#!C:\perl\bin\perl.exe
#dbtest.plx

use strict;
use warnings;
use DBI;

local $ENV{"DBI_DRIVER"} = "mysql";
local $ENV{"DBI_DSN"} = "ChangeControl";
local $ENV{"DBI_USER"} = "DrMofo";
local $ENV{"DBI_PASS"} = "Manson";
    
my $dbh=DBI->connect('dbi::') || die "Error opening database: $DBI::errstr\n";
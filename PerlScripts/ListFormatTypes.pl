#!C:\perl\bin\perl.exe
#TfrFormatTypes.plx

use strict;
use warnings;
use DBI;

# Connection variables - remove to another script or the environment at some stage

local $ENV{"DBI_DRIVER"} = "ODBC";
local $ENV{"DBI_DSN"} = "DRMofoCD";
local $ENV{"DBI_USER"} = "";
local $ENV{"DBI_PASS"} = "";

#connection & SQL variables
my ($dbh, $sth,$dbh2,$sth2,$rows2);
#Variables to hold data
my ($FormatTypeID, $FormatType, $FormatTypeDescription);
#Table name
my $TABLENAME="Format Types";
    
$dbh=DBI->connect('dbi:ODBC:DrMofoCD') || die "Error opening DrMofoCD database: $DBI::errstr\n";

# Read the Dr Mofo data into discrete variables

$sth=$dbh->prepare("SELECT FormatTypeID, FormatType, FormatTypeDescription
                                    FROM [Format Types]")
    || die "DrMofoCD Prepare failed: $DBI::errstr\n";
    
$sth->execute()
    || die "Couldn't execute DrMofoCD query: $DBI::errstr\n";   

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

$dbh->disconnect  || die "DrMofoCD Failed to disconnect: $DBI::errstr\n";

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

my $TABLENAME="Format Types";
    
$dbh=DBI->connect('dbi:ODBC:DrMofoCD') || die "Error opening DrMofoCD database: $DBI::errstr\n";
$dbh2=DBI->connect('dbi:mysql:CDDataBase') || die "Error opening CDDataBase database: $DBI::errstr\n";

# Read the Dr Mofo data into discrete variables

$sth=$dbh->prepare("SELECT * FROM [Format Types]")
    || die "DrMofoCD Prepare failed: $DBI::errstr\n";
    
$sth->execute()
    || die "Couldn't execute DrMofoCD query: $DBI::errstr\n";   

$sth->bind_col(1,\$FormatTypeID);
$sth->bind_col(2,\$FormatType);
$sth->bind_col(3,\$FormatTypeDescription);

print "message to earth.. message to earth...\n";
print "$FormatTypeID\n";
print "$FormatType\n";
print "$FormatTypeDescription\n";

# Write the MySQL CD Database records

$rows2=$dbh2->do
    ("INSERT INTO [RecordingFormat] (FormatTypeID, FormatType, FormatTypeDescription)
      VALUES                                     ($FormatTypeID,$FormatType, $FormatTypeDescription)") 
    || die "Couldn't write CDDataBase records: $DBI::errstr\n";   
    
print "$rows2 row(s) added to table [Recording Format]\n";

$sth->finish;

$dbh->disconnect  || die "DrMofoCD Failed to disconnect: $DBI::errstr\n";
$dbh2->disconnect  || die "CDDatabase Failed to disconnect: $DBI::errstr\n";
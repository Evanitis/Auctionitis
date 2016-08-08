#------------------------------------------------------------------------------------------------------------
# This program is used to update the attribute table with the latest attribute data.
#
# Created   : 19/09/06
# Input     : Attribute update file name
# 
# Command line format: CreateAttributeUpdateFile <outputfilename>
#
# Name Format of the attribute file is AttributeDataVx.x.html  (where x.x is the new version number)
#
# This is used to create the input file for the UpdateAttributeData script.
#
#------------------------------------------------------------------------------------------------------------
use strict;
use DBI;

my $outfile = shift;

unless ( $outfile ) { die "An output file must be specified"; }
    
local *O;
open(O, "> $outfile") || return;

#  Connect to the Auctions database to get input data

my $dbh=DBI->connect('dbi:ODBC:MasterCopy')  ||  die "Error opening Auctions database: $DBI::errstr\n";

# Select the attribute data

my $sth = $dbh->prepare( qq { SELECT * FROM Attributes})  ||  die "Error preparing statement: $DBI::errstr\n";

$sth->execute  ||  die "Error exexecuting statement: $DBI::errstr\n";


print O "<HTML><HEAD><TITLE>Category Attribute Data</TITLE></HEAD><BODY>\n";

print O "<H2>Category Attribute Data</H2><BR>\n";

print O "<TABLE>\n";

print O "<TR>";
print O "<TH>Name       </TH>";
print O "<TH>Field      </TH>";
print O "<TH>Category   </TH>";
print O "<TH>Sequence   </TH>";
print O "<TH>Text       </TH>";
print O "<TH>Value      </TH>";
print O "<TH>Combo      </TH>";
print O "<TH>Procedure  </TH>";
print O "</TR>\n";

# read all the categories and load them into the catory data table

my $indata = $sth->fetchall_arrayref({});

# Read through the categories array and calculate the checksum value for the categories table
# This is the sum of all the category values and is used to check the integrity of the client category table

foreach my $record (@$indata) {

    print O "<TR>";
    print O "<TD>".$record->{ AttributeName          }."</TD>";
    print O "<TD>".$record->{ AttributeField         }."</TD>";
    print O "<TD>".$record->{ AttributeCategory      }."</TD>";
    print O "<TD>".$record->{ AttributeSequence      }."</TD>";
    print O "<TD>".$record->{ AttributeText          }."</TD>";
    print O "<TD>".$record->{ AttributeValue         }."</TD>";
    print O "<TD>".$record->{ AttributeCombo         }."</TD>";
    print O "<TD>".$record->{ AttributeProcedure     }."</TD>";
    print O "</TR>\n";
}

print O "</TABLE>\n";

# Close the Attribute data file document

print O "</BODY></HTML>\n";

print "Done\n";

#------------------------------------------------------------------------------------------------------------
# This program is used to Create the Movie Ratings table input data file.
#
# Created   : 23/04/07
# Input     : Attribute update file name
# 
# Command line format: CreatMovieRatingsFile <outputfilename>
#
# Name Format of the attribute file is MovieRatingsDataVx.x.html  (where x.x is the new version number)
#
# This is used to create the input file for the UpdateMovieRatingsData script.
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

my $sth = $dbh->prepare( qq { SELECT * FROM MovieRatings } )  ||  die "Error preparing statement: $DBI::errstr\n";

$sth->execute  ||  die "Error exexecuting statement: $DBI::errstr\n";


print O "<HTML><HEAD><TITLE>Movie Rating Data</TITLE></HEAD><BODY>\n";

print O "<H2>Movie Ratings Data</H2><BR>\n";

print O "<TABLE>\n";

print O "<TR>";
print O "<TH>Movie Rating       </TH>";
print O "<TH>Movie Rating Text  </TH>";
print O "<TH>Description         </TH>";
print O "</TR>\n";

# read all the categories and load them into the catory data table

my $indata = $sth->fetchall_arrayref({});

# Read through the categories array and calculate the checksum value for the categories table
# This is the sum of all the category values and is used to check the integrity of the client category table

foreach my $record (@$indata) {

    print O "<TR>";
    print O "<TD>".$record->{ MovieRating            }."</TD>";
    print O "<TD>".$record->{ MovieRatingText        }."</TD>";
    print O "<TD>".$record->{ MovieRatingDescription }."</TD>";
    print O "</TR>\n";
}

print O "</TABLE>\n";

# Close the Attribute data file document

print O "</BODY></HTML>\n";

print "Done\n";

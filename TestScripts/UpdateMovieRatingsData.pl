#------------------------------------------------------------------------------------------------------------
# This program is used to update the attribute table with the latest attribute data.
#
# Created   : 19/09/06
# Input     : Update version number, Attribute update file name
# 
# Command line format: UpdateAttributeData <x.x> <inputfilename>
#
# Attribute data should be first created using the CreateAttributeUpdateFile,pl script
# Name Format of the attribute file is AttributeDataVx.x.html  (where x.x is the new version number)
#
# This program first retrieves the Attribute version from the DBProperties table and compares it to the
# version number of the current release.
#
# If the update version number is less than the databse update version number the procedure is aborted,
# otherwise, the input file is reead and applied to the attributes database.
# 
# if the update is run the attributes version number is updated in the Auctionitis properties file
#
#------------------------------------------------------------------------------------------------------------
use strict;
use DBI;
use Auctionitis;

my ($sth);

my $upd_version = shift;
my $infile = shift;

#------------------------------------------------------------------------------------------------------------
# Set up an Auctionitis object 
#------------------------------------------------------------------------------------------------------------

my $tm = Auctionitis->new();

#------------------------------------------------------------------------------------------------------------
# retrieve the current attributes version
#------------------------------------------------------------------------------------------------------------

$tm->initialise(Product => "AUCTIONITIS");
$tm->DBconnect();

my $att_version = $tm->get_DB_property(
    Property_Name       =>  'MovieRatingsVersion'   ,
    Property_Default    =>  0                       ,
);

#------------------------------------------------------------------------------------------------------------
# Check the current Movie Ratings version - if update version less than or equal to current release then exit
#------------------------------------------------------------------------------------------------------------

if ( $upd_version <= $att_version ) {
    print "Update bypassed - not required for current version ($att_version)\n";
    exit;
}

#------------------------------------------------------------------------------------------------------------
# Perform the refresh procedure using the input file parameter
#------------------------------------------------------------------------------------------------------------

local *I;
open(I, "< $infile") || return;

#  Connect to the Auctions database to get input data

my $dbh=DBI->connect('dbi:ODBC:Auctionitis')  ||  die "Error opening Auctions database: $DBI::errstr\n";

# Delete movie ratings data

my $sth = $dbh->prepare( qq { DELETE * FROM MovieRatings } )  ||  die "Error preparing statement: $DBI::errstr\n";

$sth->execute  ||  die "Error exexecuting statement: $DBI::errstr\n";

# Prepare the insert statement for the new records

my $update = qq {   INSERT   INTO     MovieRatings
                                    ( MovieRating               ,
                                      MovieRatingText           ,
                                      MovieRatingDescription    )
                    VALUES          ( ?,?,?                     ) } ;                

$sth = $dbh->prepare($update)  ||  die "Error preparing statement: $DBI::errstr\n";

# read the input file (name passed in from the command line)

while (<I>) {

       if ( m/(<TR><TD>)(.*?)(<\/TD><TD>)(.*?)(<\/TD><TD>)(.*?)(<\/TD><\/TR)/ ) {

       $sth->execute( $2, "$4", "$6" )
                        
       || die "Error executing statement: $DBI::errstr\n";
       }
}

# SQL complete so disconnect .... after this use Auctionitis native methods

$sth->finish;
$dbh->disconnect;

#------------------------------------------------------------------------------------------------------------
# Set the attribute version number to the current release
#------------------------------------------------------------------------------------------------------------

$tm->set_DB_property(
    Property_Name       =>  'MovieRatingsVersion'   ,
    Property_Value      =>  $upd_version            ,
);


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
# This program does NOT the current attributes version property but forces a refresh.
# 
# if the update is run the attributes version number is updated in the Auctionitis properties file
#
#------------------------------------------------------------------------------------------------------------
use strict;
use DBI;
use Win32::TieRegistry;
use Auctionitis;

my ($sth);

my $upd_version = shift;
my $infile = shift;

#------------------------------------------------------------------------------------------------------------
# Perform the refresh procedure using the input file parameter
#------------------------------------------------------------------------------------------------------------

local *I;
open(I, "< $infile") || return;

#  Connect to the Auctions database to get input data

my $dbh=DBI->connect('dbi:ODBC:Auctionitis')  ||  die "Error opening Auctions database: $DBI::errstr\n";

# Delete attribute data

my $sth = $dbh->prepare( qq { DELETE * FROM Attributes})  ||  die "Error preparing statement: $DBI::errstr\n";

$sth->execute  ||  die "Error exexecuting statement: $DBI::errstr\n";

# Prepare the insert statement for the new records

my $update = qq {   INSERT   INTO     Attributes
                                    ( AttributeName         ,
                                      AttributeField        ,
                                      AttributeCategory     ,
                                      AttributeSequence     ,
                                      AttributeText         ,
                                      AttributeValue        ,
                                      AttributeCombo        ,
                                      AttributeProcedure    )
                    VALUES          ( ?,?,?,?,?,?,?,?       ) } ;                

$sth = $dbh->prepare($update)  ||  die "Error preparing statement: $DBI::errstr\n";

# read the input file (name passed in from the command line)

while (<I>) {

       if ( m/(<TR><TD>)(.*?)(<\/TD><TD>)(.*?)(<\/TD><TD>)(.*?)(<\/TD><TD>)(.*?)(<\/TD><TD>)(.*?)(<\/TD><TD>)(.*?)(<\/TD><TD>)(.*?)(<\/TD><TD>)(.*?)(<\/TD><\/TR)/ ) {

       $sth->execute(   "$2"      ,
                        "$4"      ,
                         $6      ,
                         $8      ,
                        "$10"     ,
                        "$12"     ,
                        $14     ,
                        "$16"     )
                        
       || die "Error executing statement: $DBI::errstr\n";
       }
}

# SQL complete so disconnect .... after this use Auctionitis native methods

$sth->finish;
$dbh->disconnect;

#------------------------------------------------------------------------------------------------------------
# Set the attribute version number to the current release
#------------------------------------------------------------------------------------------------------------

my $tm = Auctionitis->new();
$tm->initialise(Product => "AUCTIONITIS");
$tm->DBconnect();

$tm->set_DB_property(
    Property_Name       =>  'AttributeVersion'  ,
    Property_Value      =>  $upd_version        ,
);


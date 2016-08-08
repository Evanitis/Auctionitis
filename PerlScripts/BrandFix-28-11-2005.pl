use strict;
use DBI;

my $dbh=DBI->connect('dbi:ODBC:Auctionitis') 
   || die "Error opening Auctions database: $DBI::errstr\n";

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
                    

my $sth = $dbh->prepare($update) 
   || die "Error preparing statement: $DBI::errstr\n";

$sth->execute( "Brand", 116, 3444,  1, "Canon"          , "Canon"          , "1", "EnableDigicams" );
$sth->execute( "Brand", 116, 3444,  2, "Casio"          , "Casio"          , "1", "EnableDigicams" );
$sth->execute( "Brand", 116, 3444,  3, "Fuji"           , "Fuji"           , "1", "EnableDigicams" );
$sth->execute( "Brand", 116, 3444,  4, "Kodak"          , "Kodak"          , "1", "EnableDigicams" );
$sth->execute( "Brand", 116, 3444,  5, "Konica-Minolta" , "Konica-Minolta" , "1", "EnableDigicams" );
$sth->execute( "Brand", 116, 3444,  6, "Leica"          , "Leica"          , "1", "EnableDigicams" );
$sth->execute( "Brand", 116, 3444,  7, "Nikon"          , "Nikon"          , "1", "EnableDigicams" );
$sth->execute( "Brand", 116, 3444,  8, "Olympus"        , "Olympus"        , "1", "EnableDigicams" );
$sth->execute( "Brand", 116, 3444,  9, "Panasonic"      , "Panasonic"      , "1", "EnableDigicams" );
$sth->execute( "Brand", 116, 3444, 10, "Pentax"         , "Pentax"         , "1", "EnableDigicams" );
$sth->execute( "Brand", 116, 3444, 11, "Ricoh"          , "Ricoh"          , "1", "EnableDigicams" );
$sth->execute( "Brand", 116, 3444, 12, "Samsung"        , "Samsung"        , "1", "EnableDigicams" );
$sth->execute( "Brand", 116, 3444, 13, "Sony"           , "Sony"           , "1", "EnableDigicams" );
$sth->execute( "Brand", 116, 3444, 14, "Other"          , "Other"          , "1", "EnableDigicams" );


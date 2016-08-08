#------------------------------------------------------------------------------------------------------------
#!perl -w
# 
# Database:     Database file containing the target table
# FileName:     Name of file containigng input
# ClearTable:   Whether to clear the table before input data or not
# Version:      Version of export file - if required, otherwise leave blank or use 0.0  ** UNUSED
# Usage:        update-from-html-export.pl <Database> <FileName> <ClearTable> <Version> 
# example:      perl update-from-html-export.pl "Auctionitis.db3" "test-html-export.html" 1

use strict;
use DBI;

# Get the table name to process from the command line

my $database    = shift;        # Input Database name
my $filename    = shift;        # import file name
my $cleartable  = shift;        # clear the table before import 1 or 0 (True or False)
my $version     = shift;        # table version - optional

print "CT ".$cleartable."\n";

die "You must supply an input database name\n"          unless ( $database      );
die "You must supply an import file name\n"             unless ( $filename      );
die "You must set the clear table flag\n"               unless ( $cleartable    );

# Check that the database exists

my @exists = stat( $database );

die "Specified database $database not found\n" unless @exists;

# Other variables

my ( $SQL, $dbh, $sth, $coldata, $colnams, $colcount, $rowdata, $rowcount, $tablerow );

# Open the input file 

local *FH;
open ( FH, "< $filename" );

# Read the table and extract the processing metadata, the column names and the column values

my $metadata    = 0;
my $tabledata   = 0;
my $property;              # import property hash reference

while (<FH>) {

    # Set processing flag using class associated with start of table

    if ( m/<TABLE class=metadata>/ ) {
        print "Begin Metadata\n";
        $metadata = 1;
        next;
    }

    if ( m/<TABLE class=tabledata>/ ) {
        print "Begin Tabledata\n";
        $tabledata = 1;
        next;
    }

    if ( $metadata ) {
        $property->{ $1 } = $2 if m/<TR><TD>(.*?)<\/TD><TD>(.*?)<\/TD><\/TR>/;
    }

    # Unset processing flag when end of table encountered


    if ( m/<\/TABLE>/ ) {

        print "matched end table pattern\n";

        if ( $metadata ) {
            print "End Metadata\n";
            $metadata = 0;
            next;
        }

        if ( $tabledata ) {
            print "End Tabledata\n";
            $tabledata = 0;
            next;
        }
    }

    if ( $tabledata ) {

        # If the header row is matched extract the column names and store in column array

         if ( m/<TR>(<TH>.*?)<\/TR>/ ) {

             my $data = $1;
             while ( $data =~ m/<TH>(.+?)<\/TH>/g ) {
                 print $1."\n";
                 push( @$colnams, $1 );
             }
             next;
         }


         # If a data row is matched extract the column values and store in tablerow data array
         # Once we've got all the columnn values push them onto the rowdata collection array 
         # and clear the tablerow data for use with the next row

         if ( m/<TR>(<TD>.*?)<\/TR/ ) {

             my $data = $1;
             while ( $data =~ m/<TD>(.+?)<\/TD>/g ) {
                 push( @$tablerow, $1 );
             }
             push( @$rowdata, [ @$tablerow ] );
             $#$tablerow = -1;
             next;
         }
    }
}

close FH;

print "Imported Row count: ".scalar( @$rowdata )."\n";

# connect using SQL Lite database driver

$dbh = DBI->connect( "dbi:SQLite:dbname=$database","","" );

die "could not connect to database $database\n" unless $dbh;

# Check that the target import table actually exists

$sth = $dbh->table_info( undef, '', '', $property->{ Tablename }, 'TABLE' );
my $tableexists = $sth->fetchall_arrayref();
die "Table name $property->{ Tablename } not found in database $database" unless defined( $tableexists );

# Set auto commit to off for performance

$dbh->{ AutoCommit } = 0;

# Delete all records in table if flag to clear table set

if ( $cleartable ) {
    $SQL = 'DELETE FROM '.$property->{ Tablename };
    print $SQL."\n";
    $sth = $dbh->prepare( $SQL )  ||  die "Error preparing statement: $DBI::errstr\n";
    $sth->execute();
    $dbh->commit();
}

# Create the SQL INSERT Statement

$SQL = 'INSERT INTO '.$property->{ Tablename }.' ( '.join( ',', @$colnams )." )\n";
$SQL .= 'VALUES ( '.join( ',', ( '?' ) x scalar( @$colnams ) ).' )';

print $SQL."\n";

$sth = $dbh->prepare( $SQL )  ||  die "Error preparing statement: $DBI::errstr\n";

my $commitcount = 1;
my $commitlimit = 500;

print 'ROW # '.scalar( @$rowdata )."\n";

foreach my $row ( @$rowdata ) {

    $sth->execute( @$row );

    $commitcount++;

    if ( $commitcount > $commitlimit ) {
        $dbh->commit();
        $commitcount = 1;
    }

}

$dbh->commit();

# SQL complete so disconnect .... after this use Auctionitis native methods

$sth->finish;
$dbh->disconnect;


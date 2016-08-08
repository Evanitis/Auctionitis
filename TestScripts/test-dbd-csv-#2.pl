#!/usr/bin/perl
use strict;
use DBI;

# Connect to the directory as a substitute for the database

my $dir = "C:\\2sellit\\TheNile";

my $dbh = DBI->connect( "DBI:CSV:f_dir=C:\\2Sellit\\TheNile\\" )
        or die "Cannot connect: " . $DBI::errstr;

# chdir $dir;
# Tie the table name to the filename

$dbh->{ 'csv_tables' }->{ 'TheNile' } = { 'file' => 'TheNileS.CSV' };
# Read the table

my $sth = $dbh->prepare( 'SELECT * FROM TheNile' );
$sth->execute();

# Place the data in an array of hashes

my $csvdata = $sth->fetchall_arrayref( {} );

# read the array

foreach my $rec ( @$csvdata ) {

    print "## ".$rec->{ Product_ID }."\n";
}


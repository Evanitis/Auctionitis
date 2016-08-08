#!/usr/bin/perl
use strict;
use DBI;

# Connect to the directory as a substitute for the database

my $dbh = DBI->connect( "DBI:CSV:f_dir=C:\\Evan\\AuctionitisBase" )
        or die "Cannot connect: " . $DBI::errstr;

# Tie the table name to the filename

$dbh->{'csv_tables'}->{'Sold'} = { 'file' => 'sold.txt'};

# Read the table

my $sth = $dbh->prepare( 'SELECT  message_from_buyer FROM Sold');
$sth->execute();

# Place the data in an array of hashes

my $csvdata = $sth->fetchall_arrayref( {} );

# read the array

foreach my $rec ( @$csvdata ) {

    print "## ".$rec->{ message_from_buyer }."\n";
}


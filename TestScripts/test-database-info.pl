#!perl -w
# 
# Database:     Database file to test
# TableName:    Name of Table to test

use strict;
use DBI;

# Other variables

my ( $SQL, $dbh, $sth, $coldata, $colnames, $colcount, $rowdata, $rowcount, $tablerow );

# Get the table name to process from the command line

my $database    = shift;
my $tablename   = shift;
my $columnname  = shift;

die "You must supply a database name\n" unless ( $database  );
die "You must supply a table name\n"    unless ( $tablename );
die "You must supply a column name\n"   unless ( $columnname  );

# Check that the database exists

print "\nTEST DATABASE EXISTENCE\n";
print "-----------------------\n";

my @exists = stat( $database );

if ( @exists ) {
    print "Specified database $database exists\n";
}
else {
    print "Specified database $database not found\n";
}

# connect using SQL Lite database driver

$dbh = DBI->connect( "dbi:SQLite:dbname=$database","","" );

die "could not connect to database $database\n" unless $dbh;

# Check that the table exists in the database

print "\nTEST TABLE EXISTENCE\n";
print "--------------------\n";

$sth = $dbh->table_info( undef, '', $tablename, 'TABLE' );
my $tbldata = $sth->fetchrow_hashref( );
print $tbldata->{ TABLE_NAME }."\n";

my $tableexists = 1 if defined( $tbldata->{ TABLE_NAME } );

if ( defined( $tableexists ) ) {
    print "Table name $tablename found in database $database\n";
}
else {
    print "Table name $tablename not found in database $database\n";
}

# Check that the column exists in the table

print "\nTEST COLUMN EXISTENCE\n";
print "---------------------\n";

# Extract the column names
# 

$sth = $dbh->prepare( "SELECT * FROM $tablename LIMIT 1" );
$sth->execute();
$colcount   = $sth->{ NUM_OF_FIELDS };
$coldata    = $sth->{ NAME };
my $found = 0;

print "Columns in table $tablename: $colcount\n";

foreach my $name ( @$coldata ) {
    if ( $name eq $columnname ) { 
        $found = 1;
        last;
    }
}

print "Table found flag: $found\n";

print "Done\n";
exit(0);

#!perl -w
# 
# Database:     Database file to extract data from
# TableName:    Name of Table to dump data from
# FileName:     Name of file to output
# Version:      Version of export file - if required, otherwise leave blank or use 0.0   
# Ignorecolumn: Column in database to ignore - usually ID Column if key generated automatically
# Usage:        create-html-export-table.pl <Database> <Table> <FileName> <Version> <IgnoreColumn>
# example:      perl create-html-export-table.pl "Auctionitis.db3" "TMCategories" "test-html-export.html"
#               perl create-html-export-table.pl "Auctionitis.db3" "TMCategories" "test-html-export.html" "0.0" "Category"

use strict;
use DBI;
use MIME::Base64;

# Get the table name to process from the command line

my $database    = shift;        # Input Database name
my $tablename   = shift;        # Table name to be exported
my $filename    = shift;        # export file name
my $version     = shift;        # table version - optional
my $ignorecol   = shift;        # column to ignore - usually ID Column if key generated automatically

die "You must supply an input database name\n"          unless ( $database  );
die "You must supply a table name to be exported\n"     unless ( $tablename );
die "You must supply an export file name\n"             unless ( $filename  );

# Check that the database exists

my @exists = stat( $database );

die "Specified database $database not found\n" unless @exists;

# Open the output file 

local *FH;
open ( FH, "> $filename" );

# Other variables

my ( $SQL, $dbh, $sth, $coldata, $colnames, $colcount, $rowdata, $rowcount, $tablerow );

# connect using SQL Lite database driver

$dbh = DBI->connect( "dbi:SQLite:dbname=$database","","" );

die "could not connect to database $database\n" unless $dbh;

# Set auto commit to off for performance

$dbh->{ AutoCommit } = 0;

# Check that the export table actually exists

$sth = $dbh->table_info( undef, '', '', $tablename, 'TABLE' );
my $tableexists = $sth->fetchall_arrayref();
die "Table name $tablename not found in database $database" unless defined( $tableexists );

# Extract the column names

$sth = $dbh->prepare( "SELECT * FROM $tablename LIMIT 1" );
$sth->execute();
$colcount   = $sth->{ NUM_OF_FIELDS };
$coldata    = $sth->{ NAME };

foreach my $name ( @$coldata ) {
    push( @$colnames, $name ) unless uc( $name ) eq uc( $ignorecol) ;
}

# Build the SQL statement using the extracted column names 
# Building the statement using the column names allows us to ensure 
# the data is extracted in the same sequence as the column names
# It also allows us to ignore the speficied IGNORE column if provided

$SQL = 'SELECT';

my $sep = ' ';

foreach my $col ( @$colnames ) {
    next if uc( $col ) eq uc( $ignorecol );
    $SQL =  $SQL.$sep.$col;
    $sep = ', '
}

$SQL = $SQL."\nFROM   ".$tablename;

$sth = $dbh->prepare( $SQL );

$sth->execute();

$rowdata = $sth->fetchall_arrayref( {} );
$rowcount  = scalar( @$rowdata );

$sth->finish();

$dbh->disconnect();

# provide input summary before continuing

my $dashes = '-' x 78;

$ignorecol  = 'NONE'    unless $ignorecol;
$version    = '0.0'     unless $version;

print "Input Database: ".$database."\n";
print "    Table Name: ".$tablename."\n";
print "   Output File: ".$filename."\n";
print " Ignore Column: ".$ignorecol."\n"    if $ignorecol;
print "       Version: ".$version."\n"      if $version;
print " Table Columns: ".$colcount."\n";
print "    Table Rows: ".$rowcount."\n";
print "SQL Selection Statement\n";
print $dashes."\n";
print $SQL."\n";
print $dashes."\n";

# Print HTML Header lines and metadata to import document

print FH "<HTML><HEAD><TITLE>Auctionitis HTML Data Export</TITLE>\n";
print FH "<STYLE type=\"text/css\">\n";
print FH "TABLE       {   border-width:       1px;          \n";
print FH "                border-Style:       solid;        \n";
print FH "                border-color:       black;        \n";
print FH "                border-collapse:    collapse;     \n";
print FH "                padding:            5px;          \n";
print FH "                border-spacing:     10px;   	}   \n";
print FH "TH          {   border-width:       1px;          \n";
print FH "                padding:            2px;          \n";
print FH "                padding-left:       5px;          \n";
print FH "                border-style:       inset;        \n";
print FH "                border-color:       #B0C4DE;      \n";
print FH "                vertical-align:     top;          \n";
print FH "                height:             19px;         \n";
print FH "                font-size:          10pt;         \n";
print FH "                font-weight:        bold;         \n";
print FH "                color:              Black;        \n";
print FH "                background-color:   #B0C4DE;    } \n";
print FH "TD          {   border-width:       1px;          \n";
print FH "                padding:            2px;          \n";
print FH "                padding-left:       5px;          \n";
print FH "                border-style:       inset;        \n";
print FH "                border-color:       #B0C4DE;      \n";
print FH "                font-size:          9pt;          \n";
print FH "                height:             17px;         \n";
print FH "                vertical-align:     top;          \n";
print FH "                background-color:   transparent;  \n";
print FH "                color :             Black;      } \n";
print FH "</STYLE>\n";
print FH "</HEAD>\n";
print FH "<BODY>\n";

# Output the Metadata table

print FH "<TABLE class=metadata>\n";
print FH "<TR><TD>Published</TD><TD>".datenow()."</TD></TR>\n";
print FH "<TR><TD>Database</TD><TD>$database</TD></TR>\n";
print FH "<TR><TD>Tablename</TD><TD>$tablename</TD></TR>\n";
print FH "<TR><TD>Output</TD><TD>$filename</TD></TR>\n";
print FH "<TR><TD>Ignored</TD><TD>$ignorecol</TD></TR>\n";
print FH "<TR><TD>Version</TD><TD>$version</TD></TR>\n";
print FH "<TR><TD>Columns</TD><TD>$colcount</TD></TR>\n";
print FH "<TR><TD>Rows</TD><TD>$rowcount</TD></TR>\n";
print FH "<TR><TD>SQL</TD><TD>$SQL</TD></TR>\n";
print FH "</TABLE>\n";
print FH "<BR><BR>\n";

# Output the Tabledata table

print FH "<TABLE class=tabledata>\n";

# Print Import table row header data

$tablerow = "<TR>";

foreach my $col ( @$colnames ) {
    next if uc( $col ) eq uc( $ignorecol );
    $tablerow .= "<TH>".$col."</TH>";
}

$tablerow .= "</TR>";

print FH $tablerow."\n";

# Print Import table data rows

foreach my $row ( @$rowdata ) {

    $tablerow = "<TR>";

    foreach my $col ( @$colnames ) {
        $tablerow .= "<TD>".$row->{ $col }."</TD>";
    }
    
    $tablerow .= "</TR>";

    print FH $tablerow."\n";
}

# Ckose the table and the file

print FH "</TABLE>\n";
print FH "</BODY></HTML>\n";

close $filename;

print "Done!";

sub datenow {

    my $self   = shift;
    my ($date, $day, $month, $year);

    # Set the day value

    if   ( (localtime)[3] < 10 )        { $day = "0".(localtime)[3]; }
    else                                { $day = (localtime)[3]; }

    # Set the month value
    
    if   ( ((localtime)[4]+1) < 10 )    { $month = "0".((localtime)[4]+1); }
    else                                { $month = ((localtime)[4]+1) ; }

    # Set the century/year value

    $year = ((localtime)[5]+1900);

    $date = $day."-".$month."-".$year;
    
    return $date;
}


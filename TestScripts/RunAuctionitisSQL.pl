use strict;
use DBI;
use Auctionitis;

my $sqlfile = shift;                             # Get input file name from commmand line

my $tm = Auctionitis->new();
$tm->initialise( Product => "Auctionitis" );    # Initialise the product
$tm->DBconnect( ConnectOnly => 1 );             # Connect to the database 

$tm->update_log( "SQL Input file required - enter the name of a file containing SQL commands" ) unless $sqlfile;
die "SQL Input file required - enter the name of a file containing SQL commands\n" unless $sqlfile;

my @exists = stat( $sqlfile );

$tm->update_log( "SQL Input file not found - $sqlfile does not exist or could not be found" ) unless $sqlfile;
die "SQL Input file not found - $sqlfile does not exist or could not be found\n" unless @exists;

# Read the SQL input file

$tm->update_log( "Processing SQL Statements from file:\n$sqlfile" );

$/ = ";\n";                                     # Set the record separator to read whole SQL statements

open ( SQLFILE, "< $sqlfile");                  # Open file for input

while ( defined ( my $SQL = <SQLFILE> ) ) {

    next if $SQL =~ m/$\s+^/;                   # Next statement if whole statement is whitespace

    $tm->update_log( "Extracted SQL Statement:" );
    $tm->update_log( "$SQL" );

    my $sth = $tm->{ DBH }->do( $SQL ) || print "Error processing SQL Statement:\n$DBI::errstr\n";

}

close( SQLFILE );                                     # ignore retval

$tm->update_log( "Completed SQL Processing" );


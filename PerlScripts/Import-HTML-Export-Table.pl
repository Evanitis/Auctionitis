#!perl -w

use DBI;
use Win32::Clipboard;

# Get the table name to process from the command line

my $database    = shift;
my $tablename   = shift;

# set up an empty clipboard buffer to receive the generated code

Win32::Clipboard->Empty();
my $CLIP = "";
tie $CLIP, 'Win32::Clipboard';

# SQL statements

my ( $SQL, $dbfile, $dbh, $sth );

#SQL Lite database driver

$dbfile = "C:\\evan\\auctionitissqlite\\auctionitis.db3";
$dbh = DBI->connect( "dbi:SQLite:dbname=$dbfile","","" );

# Set auto commit to off for performance

$dbh->{ AutoCommit } = 0;

# Extract the column definitions
# $sth = $dbh->column_info( $catalog, $schema, $table, $column );

$sth = $dbh->column_info( "", "", $tablename, "%" );

my $columns = $sth->fetchall_arrayref( {} );
my $coltot  = scalar( @$columns );

$dbh->disconnect();

# Variable to add to list of SQL statments

$CLIP .=  "    # SQL to insert row into table: $tablename\n";
$CLIP .=  "\n";
$CLIP .=  "    my \$sql_add_".$tablename."_record;\n";
$CLIP .=  "\n";

# code to create & prepare SQL statement

$CLIP .=  "    # SQL to insert row into table: $tablename\n";
$CLIP .=  "\n";
$CLIP .=  "    \$SQL = qq {\n";
$CLIP .=  "        INSERT INTO $tablename (\n";

my $colcount = 1;
my $valclause = "        VALUES    ( ";

foreach my $t ( @$columns ) {
    $CLIP .=  "                    $t->{ COLUMN_NAME }";
    $colcount < $coltot ? ( $CLIP .=  " ,\n"            ) : ( $CLIP .=  " )\n"              );
    $colcount < $coltot ? ( $valclause .= "\?, "    ) : ( $valclause .= "\? )"      );
    $colcount++;
}

$CLIP .=  "$valclause\n";
$CLIP .=  "    };\n";
$CLIP .=  "\n";
$CLIP .=  "    \$sql_add_".$tablename."_record = \$dbh->prepare( \$SQL ) || die \"Error preparing statement: \$DBI::errstr\\n\";\n";
$CLIP .=  "\n";
$CLIP .=  "\n";

# Code to create subroutine

$CLIP .=  "#=============================================================================================\n";
$CLIP .=  "# add_".$tablename."_record\n";
$CLIP .=  "#=============================================================================================\n";
$CLIP .=  "\n";
$CLIP .=  "sub add_".$tablename."_record {\n";
$CLIP .=  "\n";
$CLIP .=  "    my \$input = {\@_};\n";
$CLIP .=  "\n";
$CLIP .=  "    \$sql_add_".$tablename."_record->execute(\n"; 

foreach my $t ( @$columns ) {
    $CLIP .=  "        \$input->{ $t->{ COLUMN_NAME } } ,\n";
}

$CLIP .=  "    ) || die \"add_".$tablename."_record - Error executing statement: \$DBI::errstr\\n\";\n";
$CLIP .=  "\n";
$CLIP .=  "    # Return the key of the newly added Record\n";
$CLIP .=  "\n";
$CLIP .=  "    my \$lr = \$dbh->last_insert_id(\"\", \"\", \"\", \"\" ); \n";
$CLIP .=  "    return \$lr;\n";
$CLIP .=  "}\n";
$CLIP .=  "\n";

print "Done!";

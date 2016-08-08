#!perl -w

use DBI;

# SQL statements

my ( $SQL, $dbfile, $dbh, $sth );

#SQL Lite database driver

$dbfile = "C:\\evan\\auctionitissqlite\\auctionitis.db3";
$dbh = DBI->connect( "dbi:SQLite:dbname=$dbfile","","" );

# Set auto commit to off for performance

$dbh->{ AutoCommit } = 0;

# $sth = $dbh->table_info( $catalog, $schema, $table, $type );
$sth = $dbh->table_info( "", "", "%", "TABLE" );
my $tables = $sth->fetchall_arrayref( {} );

foreach my $t ( @$tables ) {
    print $t->{ TABLE_NAME }."\n";
}

# $sth = $dbh->column_info( $catalog, $schema, $table, $column );
$sth = $dbh->column_info( "", "", "Auctions", "%" );
my $columns = $sth->fetchall_arrayref( {} );
foreach my $t ( @$columns ) {
    my $text =  'Column: '      .$t->{ COLUMN_NAME      };
    $text .=    ' Type: '       .$t->{ TYPE_NAME        };
    $text .=    ' Nullable: '   .$t->{ IS_NULLABLE      };
    if ( defined ( $t->{ COLUMN_DEF } ) ) {
        $text .= ' Default: '   .$t->{ COLUMN_DEF       };
    }
    $text .= "\n";
    print $text;

$dbh->disconnect();

#    foreach my $property ( sort keys %$t ) {
#          my $spacer = " " x ( 20-length( $property ) ) ;
#          print $property.":".$spacer.$t->{ $property }."\n";
#    }
#    exit;
}



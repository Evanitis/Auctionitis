#!perl -w
# Usage: perl RefreshCategoryData.pl "C:\Evan\Auctionitis103\Auctionitis-Blank-Copy.db3"
use strict;
use DBI;

# SQL statements

my $SQL;
my $sql_get_new_category_records;
my $sql_clear_category_table;
my $sql_add_category_record;

# Get target database from command line

my $dbfile = shift;

$dbfile = "C:\\Evan\\Auctionitis\\Auctionitis.db3" unless defined( $dbfile );

# Check that the database exists

my @exists = stat( $dbfile );

die "Specified database $dbfile not found\n" unless @exists;

#SQL Lite database driver

my $dbh = DBI->connect( "dbi:SQLite:dbname=$dbfile","","" );

# Set auto commit to off for performance

$dbh->{ AutoCommit } = 0;

# assign larger than normal cache for performance during conversion

print "Assigning DB Cache\n";
$dbh->do( "PRAGMA cache_size = 500000" );

# ODBC Driver for access databases

my $mdb = DBI->connect('dbi:ODBC:CategoryDB', { AutoCommit => 0 } ) || die "Error opening Auctions database: $DBI::errstr\n";
$mdb->{ LongReadLen } = 65555;            # cater for retrieval of memo fields

# Initialise the SQL statements

initialise();
convert_category_records();

exit(0);

##############################################################################################
#                S U B R O U T I N E S 
##############################################################################################

sub initialise {

    # Prepare the SQL statement

    $sql_add_category_record = $dbh->prepare( qq { 
        INSERT INTO TMCategories 
        (   Description   ,     
            Category      ,     
            Parent        ,                
            Sequence      )
        VALUES  ( ?, ?, ?, ? )
    } );    

    $sql_clear_category_table = $dbh->prepare( qq { 
        DELETE  FROM    TMCategories 
    } );

}

sub convert_category_records {

   
    # Get the old records from the Auctionitis Access database
    
    my $records = get_new_category_records();

    # clear the target category table
    
    clear_category_table();

    # Load the retrieved records into the SQLite database
    
    my $current     = 0;
    my $commitcount = 1;
    my $commitlimit = 500;
    
    foreach my $r ( @$records ) {

        add_category_record( %$r );
    
        $current++;
        $commitcount++;
    
        if ( $commitcount > $commitlimit ) {
            $dbh->commit();
            $commitcount = 1;
        }
    }

    $dbh->commit();

    print "Database refreshed with $current category records\n";

} 

#=============================================================================================
# get_old_auction_records - Get records from the old access database
#=============================================================================================

sub get_new_category_records {

    my $p = { @_ };
    my $returndata;

    $SQL = qq {
        SELECT      *
        FROM        TMCategories
        ORDER BY    Category
    };

    my $sth = $mdb->prepare( $SQL );

    $sth->execute();

    $returndata = $sth->fetchall_arrayref( {} );

    if ( defined( $returndata ) ) {    
        return $returndata;
    } 
    else {
        return undef;
    }
}

sub clear_category_table {

    my $p = { @_ };

    # insert the updated record into the database
    
    $sql_clear_category_table->execute( )  || die "Error clearing category table statement: $DBI::errstr\n";

}

sub add_category_record {

    my $p = { @_ };
    my $record;

    # insert the updated record into the database
    
    $sql_add_category_record->execute(  
        $p->{ Description   },           
        $p->{ Category      },              
        $p->{ Parent        },              
        $p->{ Sequence      },
    )  || die "Error inserting category record statement: $DBI::errstr\n";

}


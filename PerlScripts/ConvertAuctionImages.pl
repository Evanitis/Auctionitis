#!perl -w

use strict;
use DBI;

# SQL statements

my $SQL;
my $sql_add_AuctionImages_record;
my $sql_clear_AuctionImages_table;
my $sql_get_old_AuctionImages_records;
my $sql_get_record_count;

# Open the Conversion Log file

open my $log, "> Auctionitis-3.1-Conversion.log";

#SQL Lite database driver

my $dbfile = "auctionitis.db3";
my $dbh = DBI->connect( "dbi:SQLite:dbname=$dbfile","","" );

# Set auto commit to off for performance

$dbh->{ AutoCommit } = 0;

# ODBC Driver for access databases

my $mdb = DBI->connect('dbi:ODBC:Auctionitis', {AutoCommit => 1} ) || die "Error opening Auctions database: $DBI::errstr\n";
$mdb->{ LongReadLen } = 65555;            # cater for retrieval of memo fields

# Initialise the SQL statements

initialise();
convert_AuctionImages_records();
print "Done!\n";

1;

sub convert_AuctionImages_records {

    print $log "\n--------------------------------------------------------------------------------------------\n";
    print $log "   Convert Table: AuctionImages\n";
    print $log "--------------------------------------------------------------------------------------------\n";

    # Remove all records from the target table

    clear_AuctionImages_table();

    # Get the list of auctionkeys in the in the auctions table
    
    my $auctions = get_auction_list();

    my $counter = 0;
    my $nopictotal = 0;

    foreach my $a ( @$auctions ) {

        # Get the old records from the Auctionitis Access database

        my $i;
        my $x;

        my $recs = get_old_AuctionImages_records( AuctionKey => $a->{ AuctionKey } );

        if ( scalar( @$recs ) == 0 ) {
            print "No AuctionImage Records found for AuctionKey: ".$a->{ AuctionKey }."\n";
            $nopictotal++;
        }

        for ( $i = scalar( @$recs ) - 1; $i >= 0; $i-- ) {

            if ( $recs->[ $i ]->{ ImageSequence } == 1 ) {

                my $imageseq       = 1;
                my $imagelist;

                for ( $x = $i; $x <= scalar( @$recs ) - 1; $x++ ) {

                    if ( $imagelist->{ $recs->[ $x ]->{ PictureKey } } )   {
                        next;
                    }
                    else {
                        $imagelist->{ $recs->[ $x ]->{ PictureKey } } = 1;

                        my $newkey = add_AuctionImages_record(
                            PictureKey      =>  $recs->[ $x ]->{ PictureKey } ,
                            AuctionKey      =>  $recs->[ $x ]->{ AuctionKey } ,
                            ImageSequence   =>  $imageseq                   ,
                        );
                        $imageseq++;
                        $counter++;
                    }
                }
            $i = 0;
            $dbh->commit();
            }
        }
    }


    my $newtot = get_record_count( TableName => 'AuctionImages' );

    print $log "\nConversion Summary for Table: AuctionImages:\n";
    # print $log "Records in Source Table: ".$oldtot."\n";
    print $log "Records in Target Table: ".$counter."\n";
    print $log "Auctions without associated images: ".$nopictotal."\n\n";

    # if ( $newtot == $oldtot )   { print $log "Table Conversion SUCCESSFUL\n"; } 
    # else                        { print $log " *** SEVERE ERROR OCCURRED Table Conversion UNSUCCESSFUL***\n"; }

} 

##############################################################################################
#                H E L P E R   &   I N T E R N A L   R O U T I N E S 
##############################################################################################

sub initialise {

    # Prepare the SQL statement

    # SQL To clear the AuctionImages Table

    $SQL = qq {
        DELETE      
        FROM        AuctionImages
    };

    $sql_clear_AuctionImages_table = $dbh->prepare( $SQL ) || die "Error preparing statement: $DBI::errstr\n";

    # SQL to insert row into table: AuctionImages

    $SQL = qq {
        INSERT INTO AuctionImages (
                    PictureKey ,
                    AuctionKey ,
                    ImageSequence )
        VALUES    ( ?, ?, ? )
    };

    $sql_add_AuctionImages_record = $dbh->prepare( $SQL ) || die "Error preparing statement: $DBI::errstr\n";

    # get Auction Image picturekey for an auction/sequence record
    # *** Note MDB Handle to retrieve records from old database

    $SQL = qq {
        SELECT      *
        FROM        AuctionImages
        WHERE       AuctionKey      = ?      
        ORDER BY    Image_Key
    };

    $sql_get_old_AuctionImages_records = $mdb->prepare( $SQL ) || die "Error preparing statement: $DBI::errstr\n";

}

#=============================================================================================
# add_AuctionImages_record
#=============================================================================================

sub add_AuctionImages_record {

    my $input = {@_};

    $sql_add_AuctionImages_record->execute(
        $input->{ PictureKey } ,
        $input->{ AuctionKey } ,
        $input->{ ImageSequence } ,
    ) || die "add_AuctionImages_record - Error executing statement: $DBI::errstr\n";

    # Return the key of the newly added Record

    my $lr = $dbh->last_insert_id("", "", "", "" ); 
    return $lr;
}

#=============================================================================================
# clear_AuctionImages_table   
#=============================================================================================

sub clear_AuctionImages_table  {

    $sql_clear_AuctionImages_table->execute() || die "Error exexecuting statement: $DBI::errstr\n";

}


#=============================================================================================
# get_record_count
#=============================================================================================

sub get_record_count {

    my $input = { @_ };

    # SQL to get Record count from specified Table

    $SQL = qq { SELECT COUNT(*) FROM $input->{ TableName } };

    $sql_get_record_count = $dbh->prepare( $SQL ) || die "Error preparing statement: $DBI::errstr\n";
    $sql_get_record_count->execute() || die "get_record_count - Error executing statement: $DBI::errstr\n";

    my $count   =   $sql_get_record_count->fetchrow_array;

    $sql_get_record_count->finish();    

    return $count;
}

#=============================================================================================
# get_AuctionImages_records    
#=============================================================================================

sub get_old_AuctionImages_records {

    my $input = { @_ };
    my $returndata;

    $sql_get_old_AuctionImages_records->execute(
        $input->{ AuctionKey    } ,
    ) || die "Error exexecuting statement: $DBI::errstr\n";

    $returndata = $sql_get_old_AuctionImages_records->fetchall_arrayref( {} );

    if ( defined( $returndata ) ) {    
        return $returndata;
    } 
    else {
        return undef;
    }
}

#=============================================================================================
# get_AuctionImages_records    
#=============================================================================================

sub get_auction_list {

    my $returndata;

    $SQL = qq {
        SELECT      AuctionKey
        FROM        Auctions
        ORDER BY    AuctionKey
    };

    my $sth = $dbh->prepare( $SQL );

    $sth->execute();

    $returndata = $sth->fetchall_arrayref( {} );

    if ( defined( $returndata ) ) {    
        return $returndata;
    } 
    else {
        return undef;
    }
}




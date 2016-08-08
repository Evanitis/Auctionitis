#!perl -w

use strict;
use DBI;

# SQL statements

my $SQL;
my $sql_add_Auctions_record;
my $sql_exists_Auction_record;
my $sql_add_Pictures_record;
my $sql_exists_Picture_record;
my $sql_add_AuctionImages_record;
my $sql_delete_AuctionImages_records;
my $sql_exists_AuctionImages_record;
my $sql_get_auction_image_picturekey;
my $sql_update_auction_image_picturekey;
my $sql_add_ShippingDetails_record;
my $sql_add_AuctionCycles_record;
my $sql_exists_DBProperties_record;
my $sql_add_DBProperties_record;
my $sql_add_Offers_record;
my $sql_add_ProductTypes_record;
my $sql_add_ShippingOptions_record;
my $sql_add_StandardText_record;
my $sql_add_Views_record;
my $sql_add_ViewColumns_record;
my $sql_get_record_count;
my $sql_get_old_AuctionImages_records;

# Get datbase and log file path from command line

my $path = shift;
$path = "C:\\Program Files\\Auctionitis" unless defined( $path );

# Pass in a debug level from the command line; if nothing passed in set to 0

my $debug = shift;
$debug = 0 unless defined( $debug );

# Open the Conversion Log file

open my $log, ">> $path\\Auctionitis-4.0-Conversion.log";

#SQL Lite database driver

my $dbfile = "$path\\auctionitis.db3";
my $dbh = DBI->connect( "dbi:SQLite:dbname=$dbfile","","" );

# Set auto commit to off for performance

$dbh->{ AutoCommit } = 0;

# assign larger than normal cache for performance during conversion

print "Assigning DB Cache\n";
$dbh->do( "PRAGMA cache_size = 500000" );

# ODBC Driver for access databases

my $mdb = DBI->connect('dbi:ODBC:Auctionitis', { AutoCommit => 0 } ) || die "Error opening Auctions database: $DBI::errstr\n";
$mdb->{ LongReadLen } = 65555;            # cater for retrieval of memo fields

# Initialise the SQL statements

initialise();
convert_Auctions_records();
convert_Pictures_records();
convert_AuctionImages_records();
convert_ShippingDetails_records();
convert_AuctionCycles_records();
convert_DBProperties_records();
convert_Offers_records();
convert_ProductTypes_records();
convert_ShippingOptions_records();
convert_StandardText_records();
convert_Views_records();
convert_ViewColumns_records();

exit(0);

##############################################################################################
#                 T A B L E   C O N V E R S I O N    R O U T I N E S 
##############################################################################################

sub convert_Auctions_records {

    print $log "\n------------------------------------------------------------------------\n";
    print $log "   Convert Table: Auctions\n";
    print $log "------------------------------------------------------------------------\n";
    print      "\n------------------------------------------------------------------------\n";
    print      "   Convert Table: Auctions\n";
    print      "------------------------------------------------------------------------\n";
    
    # Get the old records from the Auctionitis Access database
    
    my $records = get_old_Auctions_records();
    
    # Load the retrieved records into the SQLite database
    
    my $oldtot      = scalar( @$records );
    my $current     = 1;
    my $commitcount = 1;
    my $commitlimit = 500;
    
    foreach my $r ( @$records ) {
        my $newkey = add_Auctions_record( %$r );

        print "Adding ".$newkey." ".$r->{ Title }." ".$current." of ".$oldtot."\n";

        $debug ne 0 ? ( print $log "Adding ".$newkey." ".$r->{ Title }." ".$current." of ".$oldtot."\n" ) : () ;

        if ( $newkey ne $r->{ AuctionKey } ) {
            print $log "\n*** SEVERE ERROR OCCURRED - Auction Key Modified during database insert ***\n";
            exit(1);
        }
    
        $current++;
        $commitcount++;
    
        if ( $commitcount > $commitlimit ) {
            $dbh->commit();
            $commitcount = 1;
        }
    }
    
    $dbh->commit();

    my $newtot = get_record_count( TableName => 'Auctions' );

    print $log "\nConversion Summary for Table: Auctions:\n";
    print $log "Records in Source Table: ".$oldtot."\n";
    print $log "Records in Target Table: ".$newtot."\n\n";
    if ( $newtot == $oldtot )   { print $log "Table Conversion SUCCESSFUL\n"; } 
    else                        { print $log " *** SEVERE ERROR OCCURRED Table Conversion UNSUCCESSFUL***\n"; }

} 

sub convert_Pictures_records {

    print $log "\n------------------------------------------------------------------------\n";
    print $log "   Convert Table: Pictures\n";
    print $log "------------------------------------------------------------------------\n";

    print      "\n------------------------------------------------------------------------\n";
    print      "   Convert Table: Pictures\n";
    print      "------------------------------------------------------------------------\n";

    # Get the old records from the Auctionitis Access database
    
    my $records = get_old_Pictures_records();
    
    # Load the retrieved records into the SQLite database

   
    my $oldtot      = scalar( @$records );
    my $current     = 1;
    my $commitcount = 1;
    my $commitlimit = 500;
    
    foreach my $r ( @$records ) {
        my $newkey = add_Pictures_record( %$r );

        print "Adding ".$newkey." ".$r->{ PictureFileName }." ".$current." of ".$oldtot."\n";

        $debug ne 0 ? ( print $log "Adding ".$newkey." ".$r->{ PictureFileName }." ".$current." of ".$oldtot."\n" ) : ();

        if ( $newkey ne $r->{ PictureKey } ) {
            print $log "\n*** SEVERE ERROR OCCURRED - Picture Key Modified during database insert ***\n";
            exit(1);
        }
    
        $current++;
        $commitcount++;
    
        if ( $commitcount > $commitlimit ) {
            $dbh->commit();
            $commitcount = 1;
        }
    }
    
    $dbh->commit();

    my $newtot = get_record_count( TableName => 'Pictures' );

    print $log "\nConversion Summary for Table: Pictures:\n";
    print $log "Records in Source Table: ".$oldtot."\n";
    print $log "Records in Target Table: ".$newtot."\n\n";
    if ( $newtot == $oldtot )   { print $log "Table Conversion SUCCESSFUL\n"; } 
    else                        { print $log " *** SEVERE ERROR OCCURRED Table Conversion UNSUCCESSFUL***\n"; }

}

sub convert_AuctionImages_records {

    print $log "\n------------------------------------------------------------------------\n";
    print $log "   Convert Table: AuctionImages\n";
    print $log "------------------------------------------------------------------------\n";

    print      "\n------------------------------------------------------------------------\n";
    print      "   Convert Table: AuctionImages\n";
    print      "------------------------------------------------------------------------\n";

    # Get the list of auctionkeys in the in the auctions table
    
    my $auctions    = get_auction_list();

    my $counter     = 0;
    my $nopictotal  = 0;
    my $commitcount = 1;
    my $commitlimit = 500;

    foreach my $a ( @$auctions ) {

        # Get the old records from the Auctionitis Access database

        my $i;
        my $x;

        my $recs = get_old_AuctionImages_records( AuctionKey => $a->{ AuctionKey } );

        print "Processing Auction Key ".$a->{ AuctionKey }." - ".$counter." of ".scalar( @$auctions )."\n";

        $debug ne 0 ? ( print $log "Processing Auction Key ".$a->{ AuctionKey }." ".$counter." of ".scalar( $recs )."\n" ) : () ;

        if ( scalar( @$recs ) == 0 ) {

            $debug ne 0 ? ( print $log "No AuctionImage Records found for AuctionKey: ".$a->{ AuctionKey }."\n" ) : ();
            $nopictotal++;
            next;
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
            }
        }
        $commitcount++;
    
        if ( $commitcount > $commitlimit ) {
            print "Committing AuctionImage records...\n";
            $dbh->commit();
            $commitcount = 1;
        }

    }
    $dbh->commit();

    my $newtot = get_record_count( TableName => 'AuctionImages' );

    print $log "\nConversion Summary for Table: AuctionImages:\n";
    print $log "Records in Target Table: ".$counter."\n";
    print $log "Auctions without associated images: ".$nopictotal."\n\n";

} 

sub convert_ShippingDetails_records {

    print $log "\n------------------------------------------------------------------------\n";
    print $log "   Convert Table: ShippingDetails\n";
    print $log "------------------------------------------------------------------------\n";

    print      "\n------------------------------------------------------------------------\n";
    print      "   Convert Table: ShippingDetails\n";
    print      "------------------------------------------------------------------------\n";

    # Get the old records from the Auctionitis Access database
    
    my $records = get_old_ShippingDetails_records();
    
    # Load the retrieved records into the SQLite database
    
    my $oldtot      = scalar( @$records );
    my $current     = 1;
    my $skipcount   = 0;
    my $commitcount = 1;
    my $commitlimit = 500;
    
    foreach my $r ( @$records ) {

        if ( exists_auction_record( AuctionKey => $r->{ AuctionKey } ) ) {
            my $newkey = add_ShippingDetails_record( %$r );

            print "Adding ".$newkey." ".$current." of ".$oldtot."\n";

            $debug ne 0 ? ( print $log "Adding ".$newkey." ".$current." of ".$oldtot."\n" ) : ();
    
            if ( $newkey ne $r->{ Shipping_Details_Key } ) {
                print $log "\n*** SEVERE ERROR OCCURRED - Shipping Details Key Modified during database insert ***\n";
                exit(1);
            }
        
            $current++;
            $commitcount++;
        
            if ( $commitcount > $commitlimit ) {
                $dbh->commit();
                $commitcount = 1;
            }
        }
        else { 
            $skipcount++;
        }
    }

    $dbh->commit();

    my $newtot = get_record_count( TableName => 'ShippingDetails' );
    my $cnvtot = $oldtot - $skipcount;

    print $log "\nConversion Summary for Table: ShippingDetails:\n";
    print $log "Records in Source Table: ".$oldtot."\n";
    print $log "Unmatched auction count: ".$skipcount."\n";
    print $log "Records in Target Table: ".$newtot."\n\n";
    if ( $newtot == $cnvtot )   { print $log "Table Conversion SUCCESSFUL\n"; } 
    else                        { print $log " *** SEVERE ERROR OCCURRED Table Conversion UNSUCCESSFUL***\n"; }

} 

sub convert_AuctionCycles_records {

    print $log "\n------------------------------------------------------------------------\n";
    print $log "   Convert Table: AuctionCycles\n";
    print $log "------------------------------------------------------------------------\n";

    print      "\n------------------------------------------------------------------------\n";
    print      "   Convert Table: AuctionCycles\n";
    print      "------------------------------------------------------------------------\n";

    # Get the old records from the Auctionitis Access database

    my $records = get_old_AuctionCycles_records();
    
    # Load the retrieved records into the SQLite database
    
    my $oldtot = scalar( @$records );
    my $current = 1;
    my $commitcount = 1;
    my $commitlimit = 500;
    
    foreach my $r ( @$records ) {
        my $newkey = add_AuctionCycles_record( %$r );

        print $log "Adding ".$newkey." ".$r->{ AuctionCycle }." ".$current." of ".$oldtot."\n";

        $debug ne 0 ? ( print $log "Adding ".$newkey." ".$r->{ AuctionCycle }." ".$current." of ".$oldtot."\n" ) : ();
    
        $current++;
        $commitcount++;
    
        if ( $commitcount > $commitlimit ) {
            $dbh->commit();
            $commitcount = 1;
        }
    }

    $dbh->commit();

    my $newtot = get_record_count( TableName => 'AuctionCycles' );

    print $log "\nConversion Summary for Table: AuctionCycles:\n";
    print $log "Records in Source Table: ".$oldtot."\n";
    print $log "Records in Target Table: ".$newtot."\n\n";
    if ( $newtot == $oldtot )   { print $log "Table Conversion SUCCESSFUL\n"; } 
    else                        { print $log " *** SEVERE ERROR OCCURRED Table Conversion UNSUCCESSFUL***\n"; }

} 

sub convert_DBProperties_records {

    print $log "\n------------------------------------------------------------------------\n";
    print $log "   Convert Table: DBProperties\n";
    print $log "------------------------------------------------------------------------\n";

    print      "\n------------------------------------------------------------------------\n";
    print      "   Convert Table: DBProperties\n";
    print      "------------------------------------------------------------------------\n";

    # Get the old records from the Auctionitis Access database

    my $records = get_old_DBProperties_records();
    
    # Load the retrieved records into the SQLite database
    
    my $oldtot      = scalar( @$records );
    my $proccount   = 0;
    my $skipcount   = 0;
    my $commitcount = 1;
    my $commitlimit = 500;
    
    foreach my $r ( @$records ) {

        if ( exists_DBProperties_record( Property_Name => $r->{ Property_Name } ) ) {

            print $log "Skipping DBProperty ".$r->{ Property_Name }." - already exists\n";
            print      "Skipping DBProperty ".$r->{ Property_Name }." - already exists\n";
            $skipcount++;

            if ( $r->{ Property_Name } eq 'CategoryServiceDate' ) {
                update_category_service_date( CategoryServiceDate => $r->{ Property_Value } );
                print $log "*** Setting CategoryServiceDate: ".$r->{ Property_Value }."\n";
                print      "*** Setting CategoryServiceDate: ".$r->{ Property_Value }."\n";
            }
        }
        else {
    
            print $log "Adding DBProperty ".$r->{ Property_Name }." [ ".$r->{ Property_Value }." ]\n";
            print      "Adding DBProperty ".$r->{ Property_Name }." [ ".$r->{ Property_Value }." ]\n";

            my $newkey = add_DBProperties_record( %$r );
    
            print $log "New Record Key ".$newkey."\n";
            print      "New Record Key ".$newkey."\n";

            $proccount++;
        }
    
        $commitcount++;
    
        if ( $commitcount > $commitlimit ) {
            $dbh->commit();
            $commitcount = 1;
        }
    }

    $dbh->commit();

    my $newtot = get_record_count( TableName => 'DBProperties' );

    print $log "\nConversion Summary for Table: DBProperties:\n";
    print $log "Records skipped in processing: ".$skipcount."\n";
    print $log "Records added to Target Table: ".$proccount."\n";
    print $log "      Records in Source Table: ".$oldtot."\n";
    print $log "      Records in Target Table: ".$newtot."\n\n";
    if ( $newtot == $oldtot )   { print $log "Table Conversion SUCCESSFUL\n"; } 
    else                        { print $log " *** SEVERE ERROR OCCURRED Table Conversion UNSUCCESSFUL***\n"; }
} 

sub convert_Offers_records {

    print $log "\n------------------------------------------------------------------------\n";
    print $log "   Convert Table: Offers\n";
    print $log "------------------------------------------------------------------------\n";

    print      "\n------------------------------------------------------------------------\n";
    print      "   Convert Table: Offers\n";
    print      "------------------------------------------------------------------------\n";

    # Get the old records from the Auctionitis Access database
    
    my $records = get_old_Offers_records();
    
    # Load the retrieved records into the SQLite database
    
    my $oldtot = scalar( @$records );
    my $current = 1;
    my $skipcount   = 0;
    my $commitcount = 1;
    my $commitlimit = 500;
    
    foreach my $r ( @$records ) {
        if ( exists_auction_record( AuctionKey => $r->{ AuctionKey } ) ) {
            my $newkey = add_Offers_record( %$r );

            print $log "Adding ".$newkey." ".$current." of ".$oldtot."\n";

            $debug ne 0 ? ( print $log "Adding ".$newkey." ".$current." of ".$oldtot."\n" ) : ();
        
            $current++;
            $commitcount++;
        
            if ( $commitcount > $commitlimit ) {
                $dbh->commit();
                $commitcount = 1;
            }
        }
        else { 
            $skipcount++;
        }
    }

    $dbh->commit();

    my $newtot = get_record_count( TableName => 'Offers' );
    my $cnvtot = $oldtot - $skipcount;

    print $log "\nConversion Summary for Table: Offers:\n";
    print $log "Records in Source Table: ".$oldtot."\n";
    print $log "Unmatched auction count: ".$skipcount."\n";
    print $log "Records in Target Table: ".$newtot."\n\n";
    if ( $newtot == $cnvtot )   { print $log "Table Conversion SUCCESSFUL\n"; } 
    else                        { print $log " *** SEVERE ERROR OCCURRED Table Conversion UNSUCCESSFUL***\n"; }

} 

sub convert_ProductTypes_records {

    print $log "\n------------------------------------------------------------------------\n";
    print $log "   Convert Table: ProductTypes\n";
    print $log "------------------------------------------------------------------------\n";

    print      "\n------------------------------------------------------------------------\n";
    print      "   Convert Table: ProductTypes\n";
    print      "------------------------------------------------------------------------\n";

    # Get the old records from the Auctionitis Access database

    my $records = get_old_ProductTypes_records();
    
    # Load the retrieved records into the SQLite database
    
    my $oldtot = scalar( @$records );
    my $current = 1;
    my $commitcount = 1;
    my $commitlimit = 500;
    
    foreach my $r ( @$records ) {
        my $newkey = add_ProductTypes_record( %$r );

        print $log "Adding ".$newkey." ".$r->{ ProductType }." ".$current." of ".$oldtot."\n";

        $debug ne 0 ? ( print $log "Adding ".$newkey." ".$r->{ ProductType }." ".$current." of ".$oldtot."\n" ) : ();
    
        $current++;
        $commitcount++;
    
        if ( $commitcount > $commitlimit ) {
            $dbh->commit();
            $commitcount = 1;
        }
    }

    $dbh->commit();

    my $newtot = get_record_count( TableName => 'ProductTypes' );

    print $log "\nConversion Summary for Table: ProductTypes:\n";
    print $log "Records in Source Table: ".$oldtot."\n";
    print $log "Records in Target Table: ".$newtot."\n\n";
    if ( $newtot == $oldtot )   { print $log "Table Conversion SUCCESSFUL\n"; } 
    else                        { print $log " *** SEVERE ERROR OCCURRED Table Conversion UNSUCCESSFUL***\n"; }

} 

sub convert_ShippingOptions_records {

    print $log "\n------------------------------------------------------------------------\n";
    print $log "   Convert Table: ShippingOptions\n";
    print $log "------------------------------------------------------------------------\n";

    print      "\n------------------------------------------------------------------------\n";
    print      "   Convert Table: ShippingOptions\n";
    print      "------------------------------------------------------------------------\n";

    # Get the old records from the Auctionitis Access database

    my $records = get_old_ShippingOptions_records();
    
    # Load the retrieved records into the SQLite database
    
    my $oldtot = scalar( @$records );
    my $current = 1;
    my $commitcount = 1;
    my $commitlimit = 500;
    
    foreach my $r ( @$records ) {
        my $newkey = add_ShippingOptions_record( %$r );

        print $log "Adding ".$newkey." ".$current." of ".$oldtot."\n";

        $debug ne 0 ? ( print $log "Adding ".$newkey." ".$current." of ".$oldtot."\n" ) : ();

        if ( $newkey ne $r->{ Shipping_Option_Key } ) {
            print $log "\n*** SEVERE ERROR OCCURRED - Shipping Options Key Modified during database insert ***\n";
            exit(1);
        }
    
        $current++;
        $commitcount++;
    
        if ( $commitcount > $commitlimit ) {
            $dbh->commit();
            $commitcount = 1;
        }
    }

    $dbh->commit();

    my $newtot = get_record_count( TableName => 'ShippingOptions' );

    print $log "\nConversion Summary for Table: ShippingOptions:\n";
    print $log "Records in Source Table: ".$oldtot."\n";
    print $log "Records in Target Table: ".$newtot."\n\n";
    if ( $newtot == $oldtot )   { print $log "Table Conversion SUCCESSFUL\n"; } 
    else                        { print $log " *** SEVERE ERROR OCCURRED Table Conversion UNSUCCESSFUL***\n"; }

} 

sub convert_StandardText_records {

    print $log "\n------------------------------------------------------------------------\n";
    print $log "   Convert Table: StandardText\n";
    print $log "------------------------------------------------------------------------\n";

    print      "\n------------------------------------------------------------------------\n";
    print      "   Convert Table: StandardText\n";
    print      "------------------------------------------------------------------------\n";

    # Get the old records from the Auctionitis Access database

    my $records = get_old_StandardText_records();
    
    # Load the retrieved records into the SQLite database
    
    my $oldtot = scalar( @$records );
    my $current = 1;
    my $commitcount = 1;
    my $commitlimit = 500;
    
    foreach my $r ( @$records ) {
        my $newkey = add_StandardText_record( %$r );

        print $log "Adding ".$newkey." ".$r->{ StdName }." ".$current." of ".$oldtot."\n";

        $debug ne 0 ? ( print $log "Adding ".$newkey." ".$r->{ StdName }." ".$current." of ".$oldtot."\n" ) : ();
    
        $current++;
        $commitcount++;
    
        if ( $commitcount > $commitlimit ) {
            $dbh->commit();
            $commitcount = 1;
        }
    }

    $dbh->commit();

    my $newtot = get_record_count( TableName => 'StandardText' );

    print $log "\nConversion Summary for Table: StandardText:\n";
    print $log "Records in Source Table: ".$oldtot."\n";
    print $log "Records in Target Table: ".$newtot."\n\n";
    if ( $newtot == $oldtot )   { print $log "Table Conversion SUCCESSFUL\n"; } 
    else                        { print $log " *** SEVERE ERROR OCCURRED Table Conversion UNSUCCESSFUL***\n"; }

} 

sub convert_Views_records {

    print $log "\n------------------------------------------------------------------------\n";
    print $log "   Convert Table: Views\n";
    print $log "------------------------------------------------------------------------\n";

    print      "\n------------------------------------------------------------------------\n";
    print      "   Convert Table: Views\n";
    print      "------------------------------------------------------------------------\n";

    # Get the old records from the Auctionitis Access database

    my $records = get_old_Views_records();
    
    # Load the retrieved records into the SQLite database
    
    my $oldtot = scalar( @$records );
    my $current = 1;
    my $commitcount = 1;
    my $commitlimit = 500;
    
    foreach my $r ( @$records ) {
        my $newkey = add_Views_record( %$r );

        print $log "Adding ".$newkey." ".$r->{ View_Name }." ".$current." of ".$oldtot."\n";

        $debug ne 0 ? ( print $log "Adding ".$newkey." ".$r->{ View_Name }." ".$current." of ".$oldtot."\n" ) : ();

        if ( $newkey ne $r->{ View_ID } ) {
            print $log "\n*** SEVERE ERROR OCCURRED - Views Key Modified during database insert ***\n";
            exit(1);
        }
    
        $current++;
        $commitcount++;
    
        if ( $commitcount > $commitlimit ) {
            $dbh->commit();
            $commitcount = 1;
        }
    }

    $dbh->commit();

    my $newtot = get_record_count( TableName => 'Views' );

    print $log "\nConversion Summary for Table: Views:\n";
    print $log "Records in Source Table: ".$oldtot."\n";
    print $log "Records in Target Table: ".$newtot."\n\n";
    if ( $newtot == $oldtot )   { print $log "Table Conversion SUCCESSFUL\n"; } 
    else                        { print $log " *** SEVERE ERROR OCCURRED Table Conversion UNSUCCESSFUL***\n"; }

} 

sub convert_ViewColumns_records {

    print $log "\n------------------------------------------------------------------------\n";
    print $log "   Convert Table: ViewColumns\n";
    print $log "------------------------------------------------------------------------\n";

    print      "\n------------------------------------------------------------------------\n";
    print      "   Convert Table: ViewColumns\n";
    print      "------------------------------------------------------------------------\n";

    # Get the old records from the Auctionitis Access database

    my $records = get_old_ViewColumns_records();
    
    # Load the retrieved records into the SQLite database
    
    my $oldtot = scalar( @$records );
    my $current = 1;
    my $commitcount = 1;
    my $commitlimit = 500;
    
    foreach my $r ( @$records ) {
        my $newkey = add_ViewColumns_record( %$r );

        print $log "Adding ".$newkey." ".$r->{ Column_Name }." ".$current." of ".$oldtot."\n";

        $debug ne 0 ? ( print $log "Adding ".$newkey." ".$r->{ Column_Name }." ".$current." of ".$oldtot."\n" ) : ();

        if ( $newkey ne $r->{ Column_ID } ) {
            print $log "\n*** SEVERE ERROR OCCURRED - ViewColumns Key Modified during database insert ***\n";
            exit(1);
        }
    
        $current++;
        $commitcount++;
    
        if ( $commitcount > $commitlimit ) {
            $dbh->commit();
            $commitcount = 1;
        }
    }

    $dbh->commit();

    my $newtot = get_record_count( TableName => 'ViewColumns' );

    print $log "\nConversion Summary for Table: ViewColumns:\n";
    print $log "Records in Source Table: ".$oldtot."\n";
    print $log "Records in Target Table: ".$newtot."\n\n";
    if ( $newtot == $oldtot )   { print $log "Table Conversion SUCCESSFUL\n"; } 
    else                        { print $log " *** SEVERE ERROR OCCURRED Table Conversion UNSUCCESSFUL***\n"; }

} 

##############################################################################################
#                H E L P E R   &   I N T E R N A L   R O U T I N E S 
##############################################################################################

sub initialise {

    # Prepare the SQL statement


    $SQL = qq {
        INSERT INTO     Auctions            (
                        AuctionKey          ,
                        Title               ,
                        Subtitle            ,
                        Description         ,
                        ProductType         ,
                        ProductCode         ,
                        ProductCode2        ,
                        SupplierRef         ,
                        LoadSequence        ,
                        Held                ,
                        AuctionCycle        ,
                        AuctionStatus       ,
                        RelistStatus        ,
                        AuctionSold         ,
                        StockOnHand         ,
                        RelistCount         ,
                        NotifyWatchers      ,
                        UseTemplate         ,
                        TemplateKey         ,
                        AuctionRef          ,
                        SellerRef           ,
                        DateLoaded          ,
                        CloseDate           ,
                        CloseTime           ,
                        Category            ,
                        MovieRating         ,
                        MovieConfirm        ,
                        AttributeCategory   ,
                        AttributeName       ,
                        AttributeValue      ,
                        TMATT038            ,
                        TMATT104            ,
                        TMATT104_2          ,
                        TMATT106            ,
                        TMATT106_2          ,
                        TMATT108            ,
                        TMATT108_2          ,
                        TMATT111            ,
                        TMATT112            ,
                        TMATT115            ,
                        TMATT117            ,
                        TMATT118            ,
                        TMATT163            ,
                        TMATT164            ,
                        IsNew               ,
                        TMBuyerEmail        ,
                        StartPrice          ,
                        ReservePrice        ,
                        BuyNowPrice         ,
                        EndType             ,
                        DurationHours       ,
                        EndDays             ,
                        EndTime             ,
                        ClosedAuction       ,
                        BankDeposit         ,
                        CreditCard          ,
                        CashOnPickup        ,
                        EFTPOS              ,
                        Quickpay            ,
                        AgreePayMethod      ,
                        SafeTrader          ,
                        PaymentInfo         ,
                        FreeShippingNZ      ,
                        ShippingInfo        ,
                        PickupOption        ,
                        ShippingOption      ,
                        Featured            ,
                        Gallery             ,
                        BoldTitle           ,
                        FeatureCombo        ,
                        HomePage            ,
                        CopyCount           ,
                        Message             ,
                        PictureKey1         ,
                        PictureKey2         ,
                        PictureKey3         ,
                        AuctionSite         ,
                        UserDefined01       ,
                        UserDefined02       ,
                        UserDefined03       ,
                        UserDefined04       ,
                        UserDefined05       ,
                        UserDefined06       ,
                        UserDefined07       ,
                        UserDefined08       ,
                        UserDefined09       ,
                        UserDefined10       ,
                        UserStatus          ,
                        UserNotes           ,
                        OfferPrice          ,
                        OfferProcessed      ,
                        SaleType            )
        VALUES        ( ?,?,?,?,?,?,?,?,?,?,     
                        ?,?,?,?,?,?,?,?,?,?,
                        ?,?,?,?,?,?,?,?,?,?,
                        ?,?,?,?,?,?,?,?,?,?,
                        ?,?,?,?,?,?,?,?,?,?,
                        ?,?,?,?,?,?,?,?,?,?,
                        ?,?,?,?,?,?,?,?,?,?,
                        ?,?,?,?,?,?,?,?,?,?,
                        ?,?,?,?,?,?,?,?,?,?,
                        ?, ?                ) 
    };

    $sql_add_Auctions_record = $dbh->prepare( $SQL ) || die "Error preparing statement: $DBI::errstr\n";

    # SQL to verify whether record already exists

    $SQL = qq {
        SELECT      COUNT(*)
                    FROM        Auctions
                    WHERE       AuctionKey      = ?      
    };

    $sql_exists_Auction_record = $dbh->prepare( $SQL ) || die "Error preparing statement: $DBI::errstr\n";

    # SQL to insert row into table: Pictures

    $SQL = qq {
        INSERT INTO Pictures (
                    PictureKey ,
                    PictureFileName ,
                    SellaID ,
                    PhotoId )
        VALUES    ( ?, ?, ?, ? )
    };

    $sql_add_Pictures_record = $dbh->prepare( $SQL ) || die "Error preparing statement: $DBI::errstr\n";

    # SQL to verify whether record already exists

    $SQL = qq {
        SELECT      COUNT(*)
                    FROM        Pictures
                    WHERE       PictureKey     = ?      
    };

    $sql_exists_Picture_record = $dbh->prepare( $SQL ) || die "Error preparing statement: $DBI::errstr\n";

    # SQL to insert row into table: AuctionImages

    $SQL = qq {
        INSERT INTO AuctionImages (
                    PictureKey ,
                    AuctionKey ,
                    ImageSequence )
        VALUES    ( ?, ?, ? )
    };

    $sql_add_AuctionImages_record = $dbh->prepare( $SQL ) || die "Error preparing statement: $DBI::errstr\n";

    # SQL To delete the AuctionImages record(s)

    $SQL = qq {
        DELETE      
        FROM        AuctionImages
        WHERE       AuctionKey      = ?
    };

    $sql_delete_AuctionImages_records = $dbh->prepare( $SQL ) || die "Error preparing statement: $DBI::errstr\n";

    # SQL to verify whether record already exists

    $SQL = qq {
        SELECT      COUNT(*)
                    FROM        AuctionImages
                    WHERE       AuctionKey      = ?      
                    AND         ImageSequence   = ?
    };

    $sql_exists_AuctionImages_record = $dbh->prepare( $SQL ) || die "Error preparing statement: $DBI::errstr\n";

    # get Auction Image picturekey for an auction/sequence record

    $SQL = qq {
        SELECT                  PictureKey
                    FROM        AuctionImages
                    WHERE       AuctionKey      = ?      
                    AND         ImageSequence   = ?
    };

    $sql_get_auction_image_picturekey = $dbh->prepare( $SQL ) || die "Error preparing statement: $DBI::errstr\n";

    # update picture key of Aution Image record for aution/sequence record

    $SQL = qq {
        UPDATE      AuctionImages
                    SET         PictureKey      = ?
                    WHERE       AuctionKey      = ?      
                    AND         ImageSequence   = ?
    };

    $sql_update_auction_image_picturekey = $dbh->prepare( $SQL ) || die "Error preparing statement: $DBI::errstr\n";

    # SQL to insert row into table: ShippingDetails

    $SQL = qq {
        INSERT INTO ShippingDetails (
                    Shipping_Details_Key ,
                    Shipping_Details_Seq ,
                    Shipping_Details_Cost ,
                    Shipping_Details_Text ,
                    AuctionKey ,
                    Shipping_Option_Code )
        VALUES    ( ?, ?, ?, ?, ?, ? )
    };


    $sql_add_ShippingDetails_record = $dbh->prepare( $SQL ) || die "Error preparing statement: $DBI::errstr\n";

    # SQL to insert row into table: AuctionCycles

    $SQL = qq {
        INSERT INTO AuctionCycles (
                    AuctionCycle ,
                    AuctionCycleSequence ,
                    AuctionCycleDescription )
        VALUES    ( ?, ?, ? )
    };

    $sql_add_AuctionCycles_record = $dbh->prepare( $SQL ) || die "Error preparing statement: $DBI::errstr\n";

    # SQL to verify whether record already exists

    $SQL = qq {
        SELECT      COUNT(*)
                    FROM        DBProperties
                    WHERE       Property_Name    = ?      
    };

    $sql_exists_DBProperties_record = $dbh->prepare( $SQL ) || die "Error preparing statement: $DBI::errstr\n";

    # SQL to insert row into table: DBProperties

    $SQL = qq {
        INSERT INTO DBProperties (
                    Property_Name ,
                    Property_Value )
        VALUES    ( ?, ? )
    };

    $sql_add_DBProperties_record = $dbh->prepare( $SQL ) || die "Error preparing statement: $DBI::errstr\n";

    # SQL to insert row into table: Offers

    $SQL = qq {
        INSERT INTO Offers (
                    Offer_Date ,
                    AuctionRef ,
                    Offer_Duration ,
                    Offer_Amount ,
                    Highest_Bid ,
                    Offer_Reserve ,
                    Actual_Offer ,
                    Bidder_Count ,
                    Watcher_Count ,
                    Offer_Count ,
                    Offer_Successful ,
                    Offer_Type )
        VALUES    ( ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ? )
    };

    $sql_add_Offers_record = $dbh->prepare( $SQL ) || die "Error preparing statement: $DBI::errstr\n";

    # SQL to insert row into table: ProductTypes

    $SQL = qq {
        INSERT INTO ProductTypes (
                    ProductType ,
                    ProductTypeSequence ,
                    ProductTypeDescription )
        VALUES    ( ?, ?, ? )
    };

    $sql_add_ProductTypes_record = $dbh->prepare( $SQL ) || die "Error preparing statement: $DBI::errstr\n";

    # SQL to insert row into table: ShippingOptions

    $SQL = qq {
        INSERT INTO ShippingOptions (
                    Shipping_Option_Key ,
                    Shipping_Option_Seq ,
                    Shipping_Option_Code ,
                    Shipping_Option_Cost ,
                    Shipping_Option_Text )
        VALUES    ( ?, ?, ?, ?, ? )
    };

    $sql_add_ShippingOptions_record = $dbh->prepare( $SQL ) || die "Error preparing statement: $DBI::errstr\n";

    # SQL to insert row into table: StandardText

    $SQL = qq {
        INSERT INTO StandardText (
                    StdName ,
                    StdText )
        VALUES    ( ?, ? )
    };

    $sql_add_StandardText_record = $dbh->prepare( $SQL ) || die "Error preparing statement: $DBI::errstr\n";
    # SQL to insert row into table: Views

    $SQL = qq {
        INSERT INTO Views (
                    View_ID ,
                    View_Name ,
                    View_Description ,
                    View_Foreground ,
                    View_Background ,
                    View_Alt_Background ,
                    View_FontName ,
                    View_FontSize ,
                    View_Title_Foreground ,
                    View_Title_Background ,
                    View_Title_FontName ,
                    View_Title_FontSize ,
                    View_Sort_Column ,
                    View_Sort_Direction )
        VALUES    ( ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ? )
    };

    $sql_add_Views_record = $dbh->prepare( $SQL ) || die "Error preparing statement: $DBI::errstr\n";

    # SQL to insert row into table: ViewColumns

    $SQL = qq {
        INSERT INTO ViewColumns (
                    Column_ID ,
                    View_Name ,
                    Column_Name ,
                    Column_Sequence ,
                    Column_Title ,
                    Column_ToolTip ,
                    Column_Autosize ,
                    Column_Width )
        VALUES    ( ?, ?, ?, ?, ?, ?, ?, ? )
    };

    $sql_add_ViewColumns_record = $dbh->prepare( $SQL ) || die "Error preparing statement: $DBI::errstr\n";

    # SQL to get old auction images records

    $SQL = qq {
        SELECT      *
        FROM        AuctionImages
        WHERE       AuctionKey  =   ?
        ORDER BY    ImageSequence
    };

    $sql_get_old_AuctionImages_records = $mdb->prepare( $SQL );


}

#=============================================================================================
# get_old_auction_records - Get records from the old access database
#=============================================================================================

sub get_old_Auctions_records {

    my $p = { @_ };
    my $returndata;

    $SQL = qq {
        SELECT      *
        FROM        Auctions
        ORDER BY    AuctionKey
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

#=============================================================================================
# get_old_picture_records - Get records from the old access database
#=============================================================================================

sub get_old_Pictures_records {

    my $p = { @_ };
    my $returndata;

    $SQL = qq {
        SELECT      *
        FROM        Pictures
        ORDER BY    PictureKey
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

#=============================================================================================
# get_old_auction_image_records - Get records from the old access database
#=============================================================================================

sub get_old_AuctionImages_records {

    my $p = { @_ };
    my $returndata;

    $sql_get_old_AuctionImages_records->execute( $p->{ AuctionKey } );

    $returndata = $sql_get_old_AuctionImages_records->fetchall_arrayref( {} );

    if ( defined( $returndata ) ) {    
        return $returndata;
    } 
    else {
        return undef;
    }
}

#=============================================================================================
# get_old_auction_image_records - Get records from the old access database
#=============================================================================================

sub get_old_ShippingDetails_records {

    my $p = { @_ };
    my $returndata;

    $SQL = qq {
        SELECT      *
        FROM        ShippingDetails
        ORDER BY    Shipping_Details_Key, Shipping_Details_Seq
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

#=============================================================================================
# get_old_auction_cycle_records - Get records from the old access database
#=============================================================================================

sub get_old_AuctionCycles_records {

    my $p = { @_ };
    my $returndata;

    $SQL = qq {
        SELECT      *
        FROM        AuctionCycles
        ORDER BY    AuctionCycle
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

#=============================================================================================
# get_old_DBProperties_records - Get records from the old access database
#=============================================================================================

sub get_old_DBProperties_records {

    my $p = { @_ };
    my $returndata;

    $SQL = qq {
        SELECT      *
        FROM        DBProperties
        ORDER BY    Property_Name
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

#=============================================================================================
# get_old_Offers_records - Get records from the old access database
#=============================================================================================

sub get_old_Offers_records {

    my $p = { @_ };
    my $returndata;

    $SQL = qq {
        SELECT      *
        FROM        Offers
        ORDER BY    Offer_ID
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

#=============================================================================================
# get_old_product_type_records - Get records from the old access database
#=============================================================================================

sub get_old_ProductTypes_records {

    my $p = { @_ };
    my $returndata;

    $SQL = qq {
        SELECT      *
        FROM        ProductTypes
        ORDER BY    ProductType
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

#=============================================================================================
# get_old_ShippingOptions_records - Get records from the old access database
#=============================================================================================

sub get_old_ShippingOptions_records {

    my $p = { @_ };
    my $returndata;

    $SQL = qq {
        SELECT      *
        FROM        ShippingOptions
        ORDER BY    Shipping_Option_Key
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

#=============================================================================================
# get_old_StandardText_records - Get records from the old access database
#=============================================================================================

sub get_old_StandardText_records {

    my $p = { @_ };
    my $returndata;

    $SQL = qq {
        SELECT      *
        FROM        StandardText
        ORDER BY    StdName
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

#=============================================================================================
# get_old_Views_records - Get records from the old access database
#=============================================================================================

sub get_old_Views_records {

    my $p = { @_ };
    my $returndata;

    $SQL = qq {
        SELECT      *
        FROM        Views
        ORDER BY    View_ID
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

#=============================================================================================
# get_old_ViewColumns_records - Get records from the old access database
#=============================================================================================

sub get_old_ViewColumns_records {

    my $p = { @_ };
    my $returndata;

    $SQL = qq {
        SELECT      *
        FROM        ViewColumns
        ORDER BY    Column_ID
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

#=============================================================================================
# Method    : insert_auction
# Added     : 31/07/05
# Input     : Hash containg filed/value pairs
# Returns   : Key of new record
#
# Add an Auction Record to the databaSe 
#=============================================================================================

sub add_Auctions_record {

    my $input = { @_ };

    # Format data/time formats appropriately;

    $input->{ CloseTime } =~ m/( )(\d+?)(:)(\d+?)(:)(\d+?)(.)/;
    $input->{ CloseTime } = $2.$3.$4.$5.$6;

    $sql_add_Auctions_record->execute(                                     
        $input->{ AuctionKey           } , 
        $input->{ Title                } , 
        $input->{ Subtitle             } , 
        $input->{ Description          } ,
        $input->{ ProductType          } ,
        $input->{ ProductCode          } ,
        $input->{ ProductCode2         } ,
        $input->{ SupplierRef          } ,
        $input->{ LoadSequence         } , 
        $input->{ Held                 } , 
        $input->{ AuctionCycle         } ,  
        $input->{ AuctionStatus        } ,  
        $input->{ RelistStatus         } ,  
        $input->{ AuctionSold          } ,  
        $input->{ StockOnHand          } ,  
        $input->{ RelistCount          } ,  
        $input->{ NotifyWatchers       } ,  
        $input->{ UseTemplate          } ,  
        $input->{ TemplateKey          } ,  
        $input->{ AuctionRef           } ,
        $input->{ SellerRef            } ,
        $input->{ DateLoaded           } ,
        $input->{ CloseDate            } ,
        $input->{ CloseTime            } ,
        $input->{ Category             } ,     
        $input->{ MovieRating          } ,    
        $input->{ MovieConfirm         } ,    
        $input->{ AttributeCategory    } ,    
        $input->{ AttributeName        } ,    
        $input->{ AttributeValue       } ,    
        $input->{ TMATT038             } ,    
        $input->{ TMATT104             } ,    
        $input->{ TMATT104_2           } ,    
        $input->{ TMATT106             } ,    
        $input->{ TMATT106_2           } ,    
        $input->{ TMATT108             } ,    
        $input->{ TMATT108_2           } ,    
        $input->{ TMATT111             } ,    
        $input->{ TMATT112             } ,    
        $input->{ TMATT115             } ,    
        $input->{ TMATT117             } ,    
        $input->{ TMATT118             } ,    
        $input->{ TMATT163             } ,    
        $input->{ TMATT164             } ,    
        $input->{ IsNew                } ,    
        $input->{ TMBuyerEmail         } ,    
        $input->{ StartPrice           } ,    
        $input->{ ReservePrice         } ,      
        $input->{ BuyNowPrice          } ,    
        $input->{ EndType              } ,    
        $input->{ DurationHours        } ,    
        $input->{ EndDays              } ,    
        $input->{ EndTime              } ,    
        $input->{ ClosedAuction        } ,    
        $input->{ BankDeposit          } ,    
        $input->{ CreditCard           } ,    
        $input->{ CashOnPickup         } ,    
        $input->{ EFTPOS               } ,    
        $input->{ Quickpay             } ,    
        $input->{ AgreePayMethod       } ,    
        $input->{ SafeTrader           } ,    
        $input->{ PaymentInfo          } ,    
        $input->{ FreeShippingNZ       } ,    
        $input->{ ShippingInfo         } ,    
        $input->{ PickupOption         } ,    
        $input->{ ShippingOption       } ,     
        $input->{ Featured             } ,    
        $input->{ Gallery              } ,    
        $input->{ BoldTitle            } ,    
        $input->{ FeatureCombo         } ,    
        $input->{ HomePage             } ,    
        $input->{ CopyCount            } ,    
        $input->{ Message              } ,    
        $input->{ PictureKey1          } ,    
        $input->{ PictureKey2          } ,    
        $input->{ PictureKey3          } ,    
        $input->{ AuctionSite          } ,
        $input->{ UserDefined01        } ,
        $input->{ UserDefined02        } ,
        $input->{ UserDefined03        } ,
        $input->{ UserDefined04        } ,
        $input->{ UserDefined05        } ,
        $input->{ UserDefined06        } ,
        $input->{ UserDefined07        } ,
        $input->{ UserDefined08        } ,
        $input->{ UserDefined09        } ,
        $input->{ UserDefined10        } ,
        $input->{ UserStatus           } ,
        $input->{ UserNotes            } ,
        $input->{ OfferPrice           } ,
        $input->{ OfferProcessed       } ,
        $input->{ SaleType             } ,
       ) || die "insert-auction - Error executing statement: $DBI::errstr\n";

    # Return the key of the newly added Record

    my $lr = $dbh->last_insert_id( "", "", "", "" );
    return $lr;
}

#=============================================================================================
# add_picture_record - add a new picture record
#=============================================================================================

sub add_Pictures_record {

    my $parms   = { @_ };
    my $record;
    
    # Set default values for new record
    # Key value AuctionKey is defined as Autonumber and will be generated by the database
    
    $record->{ PictureFileName } = ""  ;               

    # Read through the input values and alter the corresponding fields in the "Record" hash

    while ( ( my $key, my $value ) = each( %{ $parms } ) ) {
            $record->{ $key } = $value;
    }

    # Execute the SQL Statement           
    
    $sql_add_Pictures_record->execute(  
         $record->{ PictureKey          },
         $record->{ PictureFileName     },
         $record->{ SellaID             },
         $record->{ PhotoId             },
    ) 
    || die .((caller(0))[3])." - Error executing statement: $DBI::errstr\n";

    # Return the key of the newly added Record

    my $lr = $dbh->last_insert_id( "", "", "", "" );
    return $lr;
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

    my $lr = $dbh->last_insert_id( "", "", "", "" ); 
    return $lr;
}

#=============================================================================================
# add_ShippingDetails_record
#=============================================================================================

sub add_ShippingDetails_record {

    my $input = {@_};

    $sql_add_ShippingDetails_record->execute(
        $input->{ Shipping_Details_Key } ,
        $input->{ Shipping_Details_Seq } ,
        $input->{ Shipping_Details_Cost } ,
        $input->{ Shipping_Details_Text } ,
        $input->{ AuctionKey } ,
        $input->{ Shipping_Option_Code } ,
    ) || die "add_ShippingDetails_record - Error executing statement: $DBI::errstr\n";

    # Return the key of the newly added Record

    my $lr = $dbh->last_insert_id( "", "", "", "" ); 
    return $lr;
}

#=============================================================================================
# add_AuctionCycles_record
#=============================================================================================

sub add_AuctionCycles_record {

    my $input = {@_};

    $sql_add_AuctionCycles_record->execute(
        $input->{ AuctionCycle } ,
        $input->{ AuctionCycleSequence } ,
        $input->{ AuctionCycleDescription } ,
    ) || die "add_AuctionCycles_record - Error executing statement: $DBI::errstr\n";

    # Return the key of the newly added Record

    my $lr = $dbh->last_insert_id( "", "", "", "" ); 
    return $lr;
}

#=============================================================================================
# add_DBProperties_record
#=============================================================================================

sub add_DBProperties_record {

    my $input = {@_};

    $sql_add_DBProperties_record->execute(
        $input->{ Property_Name } ,
        $input->{ Property_Value } ,
    ) || die "add_DBProperties_record - Error executing statement: $DBI::errstr\n";

    # Return the key of the newly added Record

    my $lr = $dbh->last_insert_id( "", "", "", "" ); 
    return $lr;
}

#=============================================================================================
# add_Offers_record
#=============================================================================================

sub add_Offers_record {

    my $input = {@_};

    $sql_add_Offers_record->execute(
        $input->{ Offer_Date } ,
        $input->{ AuctionRef } ,
        $input->{ Offer_Duration } ,
        $input->{ Offer_Amount } ,
        $input->{ Highest_Bid } ,
        $input->{ Offer_Reserve } ,
        $input->{ Actual_Offer } ,
        $input->{ Bidder_Count } ,
        $input->{ Watcher_Count } ,
        $input->{ Offer_Count } ,
        $input->{ Offer_Successful } ,
        $input->{ Offer_Type } ,
    ) || die "add_Offers_record - Error executing statement: $DBI::errstr\n";

}

#=============================================================================================
# add_ProductTypes_record
#=============================================================================================

sub add_ProductTypes_record {

    my $input = {@_};

    $sql_add_ProductTypes_record->execute(
        $input->{ ProductType } ,
        $input->{ ProductTypeSequence } ,
        $input->{ ProductTypeDescription } ,
    ) || die "add_ProductTypes_record - Error executing statement: $DBI::errstr\n";

    # Return the key of the newly added Record

    my $lr = $dbh->last_insert_id( "", "", "", "" ); 
    return $lr;
}

#=============================================================================================
# add_ShippingOptions_record
#=============================================================================================

sub add_ShippingOptions_record {

    my $input = {@_};

    $sql_add_ShippingOptions_record->execute(
        $input->{ Shipping_Option_Key } ,
        $input->{ Shipping_Option_Seq } ,
        $input->{ Shipping_Option_Code } ,
        $input->{ Shipping_Option_Cost } ,
        $input->{ Shipping_Option_Text } ,
    ) || die "add_ShippingOptions_record - Error executing statement: $DBI::errstr\n";

    # Return the key of the newly added Record

    my $lr = $dbh->last_insert_id( "", "", "", "" ); 
    return $lr;
}


#=============================================================================================
# add_StandardText_record
#=============================================================================================

sub add_StandardText_record {

    my $input = {@_};

    $sql_add_StandardText_record->execute(
        $input->{ StdName } ,
        $input->{ StdText } ,
    ) || die "add_StandardText_record - Error executing statement: $DBI::errstr\n";

    # Return the key of the newly added Record

    my $lr = $dbh->last_insert_id( "", "", "", "" ); 
    return $lr;
}

#=============================================================================================
# add_Views_record
#=============================================================================================

sub add_Views_record {

    my $input = {@_};

    $sql_add_Views_record->execute(
        $input->{ View_ID } ,
        $input->{ View_Name } ,
        $input->{ View_Description } ,
        $input->{ View_Foreground } ,
        $input->{ View_Background } ,
        $input->{ View_Alt_Background } ,
        $input->{ View_FontName } ,
        $input->{ View_FontSize } ,
        $input->{ View_Title_Foreground } ,
        $input->{ View_Title_Background } ,
        $input->{ View_Title_FontName } ,
        $input->{ View_Title_FontSize } ,
        $input->{ View_Sort_Column } ,
        $input->{ View_Sort_Direction } ,
    ) || die "add_Views_record - Error executing statement: $DBI::errstr\n";

    # Return the key of the newly added Record

    my $lr = $dbh->last_insert_id( "", "", "", "" ); 
    return $lr;
}

#=============================================================================================
# add_ViewColumns_record
#=============================================================================================

sub add_ViewColumns_record {

    my $input = {@_};

    $sql_add_ViewColumns_record->execute(
        $input->{ Column_ID } ,
        $input->{ View_Name } ,
        $input->{ Column_Name } ,
        $input->{ Column_Sequence } ,
        $input->{ Column_Title } ,
        $input->{ Column_ToolTip } ,
        $input->{ Column_Autosize } ,
        $input->{ Column_Width } ,
    ) || die "add_ViewColumns_record - Error executing statement: $DBI::errstr\n";

    # Return the key of the newly added Record

    my $lr = $dbh->last_insert_id( "", "", "", "" ); 
    return $lr;
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
# exists_auction_record    
#=============================================================================================

sub exists_auction_record  {

    my $input = { @_ };
    
    $sql_exists_Auction_record->execute(
        $input->{ AuctionKey    } ,
    ) || die "Error exexecuting statement: $DBI::errstr\n";
    
    my $found   =   $sql_exists_Auction_record->fetchrow_array;

    return $found;

}

#=============================================================================================
# exists_picture_record    
#=============================================================================================

sub exists_picture_record  {

    my $p = { @_ };
    
    $sql_exists_Picture_record->execute( $p->{ PictureKey    } )
    || die "Error exexecuting statement: $DBI::errstr\n";
    
    my $found   =   $sql_exists_Picture_record->fetchrow_array;

    return $found;

}

#=============================================================================================
# exists_DBproperties_record    
#=============================================================================================

sub exists_DBProperties_record  {

    my $p = { @_ };
    
    $sql_exists_DBProperties_record->execute( $p->{ Property_Name } ) 
     || die "Error exexecuting statement: $DBI::errstr\n";
    
    my $found   =   $sql_exists_DBProperties_record->fetchrow_array;

    return $found;

}

#=============================================================================================
# exists_auction_image_record    
#=============================================================================================

sub exists_auction_image_record  {

    my $input = { @_ };
    
    $sql_exists_AuctionImages_record->execute(
        $input->{ AuctionKey    } ,
        $input->{ ImageSequence } ,
    ) || die "Error exexecuting statement: $DBI::errstr\n";
    
    my $found   =   $sql_exists_AuctionImages_record->fetchrow_array;

    return $found;

}


#=============================================================================================
# delete_AuctionImages_records   
#=============================================================================================

sub delete_AuctionImage_records  {

    my $input = { @_ };

    $sql_delete_AuctionImages_records->execute(
        $input->{ AuctionKey    } ,
    ) || die "Error exexecuting statement: $DBI::errstr\n";

}

#=============================================================================================
# get_auction_image_picturekey   
#=============================================================================================

sub get_auction_image_picturekey  {

    my $input = { @_ };
    
    $sql_get_auction_image_picturekey->execute(
        $input->{ AuctionKey    } ,
        $input->{ ImageSequence } ,
    ) || die "Error exexecuting statement: $DBI::errstr\n";
    
    my $key   =   $sql_get_auction_image_picturekey->fetchrow_array;

    return $key;

}

#=============================================================================================
# update_auction_image_picturekey    
#=============================================================================================

sub update_auction_image_picturekey  {

    my $input = { @_ };
    
    $sql_update_auction_image_picturekey->execute(
        $input->{ PictureKey    } ,
        $input->{ AuctionKey    } ,
        $input->{ ImageSequence } ,
    ) || die "Error exexecuting statement: $DBI::errstr\n";

}

#=============================================================================================
# get_auction_list 
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

sub update_category_service_date {

    my $p = { @_ };

    # update category service date

    my $SQL = qq {
        UPDATE      DBProperties
        SET         Property_Value  = ?
        WHERE       Property_Name   = 'CategoryServiceDate'
    };

    my $sql_update_category_service_date = $dbh->prepare( $SQL ) || die "Error preparing statement: $DBI::errstr\n";

    $sql_update_category_service_date->execute( $p->{ CategoryServiceDate } );

}

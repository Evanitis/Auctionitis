use strict;
use Auctionitis::AuctionMaintenance;
use IO::File;

###############################################################################
#                         V A R I A B L E S                                   #
###############################################################################

# Working/Global variables

my ( $am, $msg );

###############################################################################
#                            M A I N L I N E                                  #
###############################################################################

initialise();

# Get the data from the import file defined in the config file

$msg = "Get CSVDATA from local File System";
$am->update_log( $msg, INFO );

my $csvdata = get_price_data();

$msg = "Parse CSVDATA after retrieval";
$am->update_log( $msg, INFO );

# parse the csv file into an array of hashes
# pass the CSV data a a reference so it can be treated as a file
    
my $products    = $am->parse_csv_data(
    CSVData     => $csvdata                     ,
    HasHeader   => $am->{ AM_UDFileHasHeader }  ,
);

if ( defined $products ) {

    print " Product Column: ".$am->{ AM_UDUpdateProductCol  }."\n";
    print "    Data Column: ".$am->{ AM_UDUpdateInputName   }."\n";
    print "Update Col Name: ".$am->{ AM_UDUpdateColumn      }."\n";

    foreach my $p ( @$products ) {

        my $prd = $p->{ $am->{ AM_UDUpdateProductCol    }   };    # Product Code column
        my $udi = $p->{ $am->{ AM_UDUpdateInputName     }   };    # Input Column
        my $udc = $p->{ $am->{ AM_UDUpdateColumn        }   };    # Input Column

        print "Update column: ".$udc."; Product Code: ".$prd."; Data: ".$udi."\n";

        unless ( $prd =~ m/^\s*$/ ) {

            $msg  = "Processing  Product Code: ".$prd;
            $am->update_log( $msg );

            my $count = $am->get_auction_product_count(
                ProductCode     =>  $prd,
            );

            if ( $count == 0 ) {
                $msg = "No records found in Auction Table for this product code";
                $am->update_log( $msg );
                next;
            }

            # Update User defined column

            $am->update_userdefined_column(
                ColumnData      => $udi ,
                ProductCode     => $prd ,
            );

            $msg = $count." Auction records updated with Instore Price: ".$udi;
            $am->update_log( $msg );
        }
    }
}
else {

    # No products returned from csv import - log message to logfile

    $msg = "No Products to update or Input file not found";
    $am->update_log( $msg, INFO );
}

# End of processing - log normal completion message to log file

$msg = "Stock Update processing terminated normally";
$am->update_log( $msg, INFO );

###############################################################################
#                            S U B R O U T I N E S                            #
###############################################################################

sub initialise {

    $am = Auctionitis::AuctionMaintenance->new( );                  # Create object
    $am->initialise();                                              # Load Config/Initialise
}

sub get_price_data {

    my @exists = stat( $am->{ AM_UDUpdateFile } );
    
    if ( not @exists ) {
        $am->update_log( "Store Price File not found: ".$am->{ AM_UDUpdateFile } );
        return;
    }

    local $/;                                                      #slurp mode (undef)
    local *F;                                                      #create local filehandle
    open( F, "< $am->{ AM_UDUpdateFile }\0" ) || return;
    my $text = <F>;                                                #read whole file
    close(F);                                                      # ignore retval
    return $text
}


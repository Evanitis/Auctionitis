#!perl -w
#---------------------------------------------------------------------------------------------
# Copyright 2007, Evan Harris.  All rights reserved.
#---------------------------------------------------------------------------------------------

package Auctionitis::AuctionMaintenance;
use AuctionitisOld;
require Exporter;

our @ISA = qw( AuctionitisOld Exporter );

# Set the eport list to export constants defined in the Auctionitis base class

our @EXPORT = qw(
    Z_DELETE Z_NOSTOCK Z_REMOVE Z_CANLIST Z_NEWITEM Z_EXCLUDE Z_SLOW Z_DEAD
    STS_CLONE STS_TEMPLATE STS_CURRENT STS_SOLD STS_UNSOLD STS_RELISTED
    SITE_TRADEME SITE_SELLA SITE_TANDE SITE_ZILLION
    INFO DEBUG VERBOSE
);

use Fcntl qw(:DEFAULT :flock);                                # Supplies O_RDONLY and other constant file values
use DBI;
use Text::CSV_XS;
use strict;

my $VERSION = "0.001";
sub Version { $VERSION; }

# class variables

my ( $ua, $sa, $url, $req, $response, $content, $dbh, $msg, $column );

###############################################################################
#                    S Q L    S T A T E M E N T S                             #
###############################################################################

my $SQL_get_template_list;              # Get list of templates
my $SQL_exists_product_template;        # Check whether Auction Template record exists
my $SQL_get_product_template;           # Get the product template record
my $SQL_update_auction_cycle;           # Update auction cycle for a product code/Record type
my $SQL_update_auction_description;     # Update auction  descriptive text
my $SQL_update_product_pricing;         # Update Product pricing for Clones & Templates
my $SQL_update_userdefined_column;      # Update a particular user defined column for a product code
my $SQL_clear_text_changed_flag;        # Clear the Text Updated flag (Currently UserDefined10)
my $SQL_allow_text_change;              # Check the Allow Text changes flag (Currently UserDefined09)
my $SQL_exists_product_type;            # Check the product type exists
my $SQL_get_auction_product_count_sts;  # Get a count of all all auctions with specified status using the product code
my $SQL_get_auction_product_count_all;  # Get a count of all auctions using the product code
my $SQL_set_update_timestamp;           # Update selected column with Stock Update timestamp value
                                        
# Global Variables for Import function(s)

my $item;                               # Hash containing product properties
my $items;                              # Array containg product hashes for all products
my $variant;                            # Hash containing variant properties
my $variants;                           # Array containing variant hashes for a product
my $category;                           # Hash containing all category names and count of products
my $categories;                         # Array containing all category values from XML extract
my $e;                                  # stack to indicate current XML element type being processed
                                        # $e->[0] = current element, $e->[1] = previous element, etc. 

##############################################################################################
# --- Methods/Subroutines ---
##############################################################################################

#=============================================================================================
# Method    : new 
#=============================================================================================

# Inherited from Superclass

#=============================================================================================
# Method    :  _load_config
# Added     : 22/03/07
#
# Load configuration file data
# Internal routine only...
#=============================================================================================

sub _load_config {

    my $self  = shift;
    sysopen( CONFIG, $self->{ Config }, O_RDONLY) or die "Cannot open $self->{ Config } $!";
    
    while  (<CONFIG>) {
        chomp;                       # no newline
        s/#.*//;                     # no comments
        s/^\s+//;                    # no leading white
        s/\s+$//;                    # no trailing white
        next unless length;          # anything left ?
        my ($ parm, $value ) = split( /\s*=\s*/, $_, 2 );
    
        # Set the property from the configu file unless it was passed in withthe constructor methof
    
        $self->{ 'AM_'.$parm } = $value unless $self->{ 'AM_'.$parm };
    }
}

#=============================================================================================
# Method    :  initialise
# Added     : 22/03/07
#=============================================================================================

sub initialise {

    my $self  = shift;

    # INitialise the Auctoninitis object to get access to the broser and set other properties

    $self->AuctionitisOld::initialise( Product => "Auctionitis" );

    # Load the configuration file for the Product Maintenance Options

    $self->{ Config } = 'ProductMaintenance.config' unless $self->{ Config };

    $self->_load_config;

    # Set defualts for required value sifi not loaded

    $self->{ AM_DefaultCategory     } = '0'             unless $self->{ AM_DefaultCategory      };
    $self->{ AM_CategoryLookupCol   } = 'ProductType'   unless $self->{ AM_CategoryLookupCol    };
    $self->{ AM_DatabaseDSN         } = 'Auctionitis'   unless $self->{ AM_DatabaseDSN          };
    $self->{ AM_MinStock            } = 5               unless $self->{ AM_MinStock             };
    $self->{ AM_BasePrice           } = 0               unless $self->{ AM_BasePrice            };

    # Dump current object properties if Debug has been set

    $self->{ AM_DebugLevel } ge 0 ? $self->dump_properties() : ();

    # Connect to the database specified in the configuration file

    $self->DBconnect( $self->{ AM_DatabaseDSN } );

    # Set up SQL Statements required for Product Maintenance
    
    $msg = "Create SQL Statements";
    $self->update_log( $msg, INFO );

    # Build list of templates to check from auctions table

    $SQL_get_template_list          = $self->{ DBH }->prepare( qq { 
        SELECT      * 
        FROM        Auctions 
        WHERE       AuctionStatus   = 'TEMPLATE'
    } );

    # Prepare the other SQL statememnts

    $SQL_exists_product_template    = $self->{ DBH }->prepare( qq { 
        SELECT      COUNT(*)
        FROM        Auctions
        WHERE       ProductCode     = ? 
        AND         AuctionStatus   = 'TEMPLATE' 
    } );

    $SQL_get_product_template       = $self->{ DBH }->prepare( qq { 
        SELECT      *
        FROM        Auctions
        WHERE       ProductCode     = ? 
        AND         AuctionStatus   = 'TEMPLATE' 
    } );

    $SQL_update_auction_cycle       = $self->{ DBH }->prepare( qq { 
        UPDATE      Auctions
        SET         AuctionCycle    = ?
        WHERE       ProductCode     = ?
        AND         AuctionStatus   = ?
    } );

    $SQL_update_product_pricing     = $self->{ DBH }->prepare( qq { 
        UPDATE      Auctions
        SET         StartPrice      = ?,
                    ReservePrice    = ?,
                    BuyNowPrice     = ?,
                    OfferPrice      = ?
        WHERE       ProductCode     = ?
        AND         AuctionStatus   = ?
    } );

    $SQL_update_auction_description = $self->{ DBH }->prepare( qq { 
        UPDATE      Auctions
        SET         Description     = ?,
                    UserDefined10   = 'Y'
        WHERE       ProductCode     = ?
        AND         AuctionStatus   = 'TEMPLATE'
    } );

    $SQL_update_auction_description->bind_param( 1, $SQL_update_auction_description, DBI::SQL_LONGVARCHAR );   

    if ( $self->{ AM_UDUpdateColumn } ) {
    
        $column = $self->{ AM_UDUpdateColumn };
    
        $SQL_update_userdefined_column  = $self->{ DBH }->prepare( qq { 
            UPDATE      Auctions
            SET         $column         = ?
            WHERE       ProductCode     = ?
        } );
    }

    if ( $self->{ AM_MarkTextChangedCol } ) {

        $column = $self->{ AM_MarkTextChangedCol };
    
        $SQL_clear_text_changed_flag    = $self->{ DBH }->prepare( qq { 
            UPDATE      Auctions
            SET         $column         = ''
        } );
    }

    $SQL_allow_text_change          = $self->{ DBH }->prepare( qq { 
        SELECT      ?
        FROM        Auctions
        WHERE       ProductCode     = ?
        AND         AuctionStatus   = 'TEMPLATE'
    } );

    $SQL_exists_product_type        = $self->{ DBH }->prepare( qq { 
        SELECT      COUNT(*)
        FROM        ProductTypes
        WHERE       ProductType     = ? 
    } );

    $SQL_get_auction_product_count_sts  = $self->{ DBH }->prepare( qq { 
        SELECT      COUNT(*)
        FROM        Auctions
        WHERE       ProductCode     = ? 
        AND         AuctionStatus   = ? 
    } );

    $SQL_get_auction_product_count_all  = $self->{ DBH }->prepare( qq { 
        SELECT      COUNT(*)
        FROM        Auctions
        WHERE       ProductCode     = ? 
    } );

    if ( $self->{ AM_StockUpdateDateStampCol } ) {

        my $SQL = qq { 
            UPDATE      Auctions
            SET         $self->{ AM_StockUpdateDateStampCol } = ?
            WHERE       ProductCode = ? 
        };

        $msg = "Timestamp SQL Statement";
        $self->update_log( $msg, INFO );
        $self->update_log( $SQL, INFO );

        $SQL_set_update_timestamp = $self->{ DBH }->prepare( $SQL );
    }
}

#=============================================================================================
# Method    : parse_csv_data
# Input     : Hash
# Returns   : Array reference
#
# This method processes a csv file and returns an array of has references, 1 array element
# per record; hash keys are named for column names
#=============================================================================================

sub parse_csv_data {

    my $self    = shift;
    my $i       = { @_ };

    my $csvdata = $i->{ CSVData };

    $msg = "Parsing CSV Data";
    $self->update_log( $msg, INFO );

    my $io;
    open( $io, '<', \$csvdata ) || die;

    $msg = "IO object Openedfor input ";
    $self->update_log( $msg, DEBUG );

    # Create the CSV object
    
    my $csv = Text::CSV_XS->new( 
        { 
            binary              => 1    ,
            allow_whitespace    => 1    ,
        } 
    );

    # Read the first record of the file if the file has a header specified
    # After extracting the heading line us it to set the product hash key names
    # if EOF then exit

    if ( $i->{ HasHeader } ) {

        $msg = "Performing Column header extraction";
        $self->update_log( $msg, DEBUG );

        my $headings = $csv->getline( $io );

        $msg = "Headings: ", DEBUG;
        foreach my $col ( @$headings ) {
              $self->update_log( "- ".$col, DEBUG );
        }

        if ( $csv->eof() ) {

            # Nothing to process so return undef

            $msg = "Nothing to process - returning";
            $self->update_log( $msg, DEBUG );

            print $msg;

            return undef;
        }

        foreach my $col ( @$headings ) {
            print "Column name: ".$col."\n";
        }

        $csv->column_names( $headings );
    }

    # Priming Read for processing the rest of the file
    # Check for end of file so we know there is at least one record that will be returned
    # Read a record into a Hash and then test for end of file
    # IF not EOF add the hash into the products array and then read another record
    # When we get to end of file the loop will exit

    $msg = "Read first line of input (Priming Read)";
    $self->update_log( $msg, DEBUG );

    my $data = $csv->getline_hr( $io );

    if ( $csv->eof() ) {
        # Nothing to process so return undef

        $msg = "No data content to process - returning";
        $self->update_log( $msg, DEBUG );

        return undef;
    }

    # Create an array to hold the returned products

    my $products;

    my $reccount = 0;

    while ( not $csv->eof() ) {

        $msg = "Writing Record to Array - Record No: $reccount";
        $self->update_log( $msg, DEBUG );

        push ( @$products, $data );

        # Read the next record so the EOF test loop works

        $data = $csv->getline_hr( $io );

        $reccount++;
    }

    $msg = "No more csv records to process - return";
    $self->update_log( $msg, DEBUG );

    $msg = "Retrieved ".$reccount." records for processing from CSV file";
    $self->update_log( $msg, INFO );
    
    return $products;
}

#=============================================================================================
# Method    : add_import_column
# Input     : Hash - Source, NewName, Value
#
# Add new key to hash
#=============================================================================================

sub add_import_column {

    my $self    = shift;
    my $i       = { @_ };

    if ( defined  $i->{ Source }->{ $i->{ NewName } } ) {
        $msg = "Import Column ".$i->{ NewName }." not added ".$i->{ NewName }." - ALREADY EXISTS";
        $self->update_log( $msg, DEBUG );
    }

    $i->{ Source }->{ $i->{ NewName } } = $i->{ Value };
}

#=============================================================================================
# Method    : rename_import_column
# Input     : Hash - Source, NewName, OldName
#
# Rename key in hash to another key
#=============================================================================================

sub rename_import_column {

    my $self    = shift;
    my $i       = { @_ };

    if ( not defined  $i->{ Source }->{ $i->{ OldName } } ) {
        $msg = "Import Column ".$i->{ OldName }." not renamed to ".$i->{ NewName }." - NOT FOUND";
        $self->update_log( $msg, DEBUG );
    }

    $i->{ Source }->{ $i->{ NewName } } = delete( $i->{ Source }->{ $i->{ OldName } } );
}

#=============================================================================================
# Method    : copy_import_column
# Input     : Hash - Source, NewName, OldName
#
# Copy key in hash to another key
#=============================================================================================

sub copy_import_column {

    my $self    = shift;
    my $i       = { @_ };

    if ( not defined  $i->{ Source }->{ $i->{ OldName } } ) {
        $msg = "Import Column ".$i->{ OldName }." not copied to ".$i->{ NewName }." - NOT FOUND";
        $self->update_log( $msg, DEBUG );
    }

    if ( defined  $i->{ Source }->{ $i->{ NewName } } ) {
        $msg = "Import Column ".$i->{ OldName }." not copied to ".$i->{ NewName }." - ALREADY EXISTS";
        $self->update_log( $msg, DEBUG );
    }

    $i->{ Source }->{ $i->{ NewName } } = $i->{ Source }->{ $i->{ OldName } };
}

#=============================================================================================
# Method    : is_debug
# Added     : 22/03/07
#
# Retrieve connected status
#=============================================================================================

sub is_debug {

    my $self = shift;

    if ( $self->{ AM_DebugLevel } gt 0 ) { return 1; } else { return 0; }
}

sub update_log_header {

    my $self = shift;
    my $text = shift;


    $msg = "*--------------------------------------------------------------";
    $self->update_log( $msg, INFO );
    
    $msg = "* ".$text;
    $self->update_log( $msg, INFO );
    
    $msg = "*--------------------------------------------------------------";
    $self->update_log( $msg, INFO );

}

#=============================================================================================
# update_log
# update the product maintenance log file
#=============================================================================================

sub update_log {

    my $self = shift;

    my $msg = shift;
    my $sev = shift;

    unless( defined( $msg ) ) {
        return;
    }

    if ( not defined( $sev ) ) {
        $sev = INFO;
    }

    #### DO NOT ADD STANDARD DEBUGGING TO THIS METHOD I.E. UPDATE_LOG   ####
    #### AS IT WILL RESULT IN A RECURSIVE CALL                          ####    

    # IF the log file is not defined exit

    if ( not defined( $self->{ AM_LogFile } ) ) {
        $self->{ AM_DebugLevel } ge 1 ? ( print "No log file defined.\n" ) : ();
        return;
    }

    # Strip any new lines out before printing to log

    $msg =~ tr/\n//; 

    # Get todays date to Timestamp log entry
    
    my ($secs, $mins, $hrs, $dd, $mm, $yy, $dow, $jul, $isdst) = localtime;
    
    # open the logfile

    open ( LOGFILE, ">> $self->{ AM_LogFile }" );

    # format the retrieved date and time values

    $mm = $mm + 1;
    $yy = $yy + 1900;

    if ($secs < 10)   { $secs = "0".$secs; }
    if ($mins < 10)   { $mins = "0".$mins; }
    if ($dd   < 10)   { $dd   = "0".$dd;   }
    if ($mm   < 10)   { $mm   = "0".$mm;   }

    my $now = "$dd-$mm-$yy $hrs:$mins:$secs";

    # print to file based on 

    if ( uc( $sev )     eq INFO     and $self->{ AM_DebugLevel } ge 0 ) {
        $self->{ AM_Console }   ? ( print $msg."\n" ):();
        print LOGFILE $now." ".$msg."\n";
    }
    elsif ( uc( $sev )  eq DEBUG    and $self->{ AM_DebugLevel } ge 1 ) {
        $self->{ AM_Console }   ? ( print "DEBUG: ".$msg."\n" ):();
        print LOGFILE $now." DEBUG: ".$msg."\n";
    }
    elsif ( uc( $sev )  eq VERBOSE  and $self->{ AM_DebugLevel } ge 2 ) {
        $self->{ AM_Console }   ? ( print "DEBUG: ".$msg."\n" ):();
        print LOGFILE $now." DEBUG: ".$msg."\n";
    }

    close LOGFILE;
}

sub get_template_list {

    my $self = shift;

    $SQL_get_template_list->execute;
    my $templates = $SQL_get_template_list->fetchall_arrayref( {} );

    return $templates;
}

sub get_auction_product_count {

    my $self    = shift;
    my $i       = { @_ };

    # If the product count method is called with an AuctionStatus parameter
    # and the paramater is not ALL then execute the SQL that counts for a 
    # status otherwise call the SQL that gets a total

    if ( ( $i->{ AuctionStatus } ) and ( $i->{ AuctionStatus } ) ne 'ALL' ){

        $SQL_get_auction_product_count_sts->execute(
            "$i->{ ProductCode      }"  ,
            "$i->{ AuctionStatus    }"  ,
        ) || die "SQL in ".(caller(0))[3]." failed:\n $DBI::errstr\n";

        my $count = $SQL_get_auction_product_count_sts->fetchrow_array;
        return $count;  
    }
    else {

        $SQL_get_auction_product_count_all->execute(
            "$i->{ ProductCode      }"  ,
        ) || die "SQL in ".(caller(0))[3]." failed:\n $DBI::errstr\n";

        my $count = $SQL_get_auction_product_count_all->fetchrow_array;
        return $count;  
    }
}

sub exists_product_template {

    my $self    = shift;
    my $product = shift;

    $SQL_exists_product_template->execute( $product ) || die "SQL in ".(caller(0))[3]." failed:\n $DBI::errstr\n";
    
    my $found = $SQL_exists_product_template->fetchrow_array;

    return $found;  
}

sub get_product_template {

    my $self    = shift;
    my $product = shift;

    $SQL_get_product_template->execute( $product ) || die "SQL in ".(caller(0))[3]." failed:\n $DBI::errstr\n";
    
    my $record = $SQL_get_product_template->fetchrow_hashref;

    return $record;  
}

sub exists_product_type {

    my $self    = shift;
    my $type    = shift;

    $SQL_exists_product_type->execute( $type ) || die "SQL in ".(caller(0))[3]." failed:\n $DBI::errstr\n";
    
    my $found = $SQL_exists_product_type->fetchrow_array;

    return $found;  
}

sub update_auction_cycle {

    my $self    = shift;
    my $i       = { @_ };

    # Update the database with the new updated "Record" hash

    $SQL_update_auction_cycle->execute(
        "$i->{ AuctionCycle         }"  ,
        "$i->{ ProductCode          }"  ,
        "$i->{ AuctionStatus        }"  ,       
    ) || die "SQL in ".(caller(0))[3]." failed:\n $DBI::errstr\n";
}

sub update_product_pricing {

    my $self    = shift;
    my $i       = { @_ };

    # Update the database with the new updated "Record" hash

    $SQL_update_product_pricing->execute(
         $i->{ StartPrice           }   ,
         $i->{ ReservePrice         }   ,
         $i->{ BuyNowPrice          }   ,
         $i->{ OfferPrice           }   ,
        "$i->{ ProductCode          }"  ,
        "$i->{ AuctionStatus        }"       
    ) || die "SQL in ".(caller(0))[3]." failed:\n $DBI::errstr\n";
}

sub update_auction_description {

    my $self    = shift;
    my $i       = { @_ };

    # Update the database with the new updated "Record" hash

    $SQL_update_auction_description->execute(
        "$i->{ Description          }"  ,
        "$i->{ ProductCode          }"  ,
    ) || die "SQL in ".(caller(0))[3]." failed:\n $DBI::errstr\n";
}

sub update_userdefined_column {

    my $self    = shift;
    my $i       = { @_ };

    # Update the database with the new updated "Record" hash

    $SQL_update_userdefined_column->execute(
        "$i->{ ColumnData           }"  ,
        "$i->{ ProductCode          }"  ,
    ) || die "SQL in ".( caller(0) )[3]." failed:\n $DBI::errstr\n";
}

sub allow_text_change {

    my $self    = shift;
    my $product = shift;

    $SQL_allow_text_change->execute( $product ) || die "SQL in ".(caller(0))[3]." failed:\n $DBI::errstr\n";
    
    my $allowflag = $SQL_allow_text_change->fetchrow_array;

    if ( $allowflag eq "N" ) {
        return 0;
    }
    else {
        return 1;  
    }
}

sub clear_text_changed_flag {

    my $self    = shift;

    $SQL_clear_text_changed_flag->execute() || die "SQL in ".(caller(0))[3]." failed:\n $DBI::errstr\n";
}

sub exists_product_image {

    my $self    = shift;
    my $image   = shift;

    $self->update_log("Invoked Method: ".( caller( 0 ) )[3], DEBUG ); 

    # Check if the actual image file exists

    if ( -e $image ) {
        $msg = "Image ".$image." found";
        $self->update_log( $msg, DEBUG );
        return 1;
    }
    else {
        $msg = "Image ".$image." NOT found";
        $self->update_log( $msg, DEBUG );
        return 0;
    }
}

sub set_update_timestamp {

    my $self    = shift;
    my $i       = { @_ };

    $SQL_set_update_timestamp->execute(
        "$i->{ Datestamp    }", 
        "$i->{ ProductCode  }"
    ) || die "SQL in ".(caller(0))[3]." failed:\n $DBI::errstr\n";
}

#--------------------------------------------------------------------
# End of 2Sellit product Maintenance module
# Return true value so the module can actually be used
#--------------------------------------------------------------------

1;


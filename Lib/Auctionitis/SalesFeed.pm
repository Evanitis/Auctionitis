#!perl -w
#--------------------------------------------------------------------
# Create_Sales_Extract.pl 
#--------------------------------------------------------------------
# Copyright 2007, Evan Harris.  All rights reserved.
#--------------------------------------------------------------------

package Auctionitis::SalesFeed;

use strict;
use Auctionitis;
use Net::FTP;
require Exporter;

our @ISA    = qw( Auctionitis Exporter );

# Set the eport list to export constants defined in the Auctionitis base class

our @EXPORT = qw(
    Z_DELETE Z_NOSTOCK Z_REMOVE Z_CANLIST Z_NEWITEM Z_EXCLUDE Z_SLOW Z_DEAD
    STS_CLONE STS_TEMPLATE STS_CURRENT STS_SOLD STS_UNSOLD STS_RELISTED
    SITE_TRADEME SITE_SELLA SITE_TANDE SITE_ZILLION
    INFO DEBUG VERBOSE
);

# class variables

###############################################################################
#                         V A R I A B L E S                                   #
###############################################################################

my ( $server, $dbname, $username, $password );
my ( $msg, $extractpath, $extractname, $extractfile, $records, $q, $s );

# SQL statements

my $SQL_get_account_list;               # Get list of accounts to process
my $SQL_get_product_code;               # Get product code for auction reference
my $SQL_exists_sales_extract_record;    # Check whether Sales Extract record exists
my $SQL_get_sales_extract_by_key;       # Get Sales Extract Record by Primary Key
my $SQL_get_sales_extract_by_ref;       # Get Sales Extract Record by Reference Val
my $SQL_add_sales_extract_record;       # Add new Sales Extract record
my $SQL_update_sales_extract_record;    # Update Sales Extract Record
my $SQL_get_auction_product_code;       # Get Auction Product Code by Reference Val
my $SQL_clear_extract_action;           # Clear the Extract_Action column

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
    sysopen( CONFIG, $self->{ Config }, 0 ) or die "Cannot open $self->{ Config } $!";
    
    while  (<CONFIG>) {
        chomp;                       # no newline
        s/#.*//;                     # no comments
        s/^\s+//;                    # no leading white
        s/\s+$//;                    # no trailing white
        next unless length;          # anything left ?
        my ($ parm, $value ) = split( /\s*=\s*/, $_, 2 );
    
        # Set the property from the configuration file unless it was passed in with the constructor method
    
        $self->{ 'SF_'.$parm } = $value unless $self->{ 'SF_'.$parm };
    }
}


###############################################################################
#                            S U B R O U T I N E S                            #
###############################################################################

sub initialise {

    my $self  = shift;

    $self->Auctionitis::initialise( Product => "Auctionitis" );

    # Load the configuration file for the Product Maintenance Options

    unless ( defined $self->{ Config } ) {
        $self->{ Config } = 'SalesFeed.config';
    }

    $self->_load_config;

    # Set defualts for required value sifi not loaded

    $self->{ SF_ProductCodeCol  } = 'ProductCode' unless $self->{ SF_ProductCodeCol };

    $self->DBconnect( );

    $msg = "*--------------------------------------------------------------";
    $self->update_log( $msg, INFO );
    
    $msg = "* Start SALES EXTRACT Processing";
    $self->update_log( $msg, INFO );
    
    $msg = "*--------------------------------------------------------------";
    $self->update_log( $msg, INFO );

    # Initialise the quote variable and separator variable for use building the csv

    $q = '"';
    $s = ',';

    # Set up extract file name

    my $timestamp = $self->datenow()."-".$self->timenow();
    $timestamp =~ tr/:/-/;

    $extractpath = $self->{ SF_ExtractPath      };
    $extractname = $self->{ SF_ExtractFileName  }."-".$timestamp.".csv";

    $msg = "opening ".$extractpath."\\".$extractname;
    $self->update_log( $msg );

    open $extractfile, "> $extractpath\\$extractname";

    my $record  =   $q."Extract_ID".$q.$s;
    $record     .=  $q."Extract_Action".$q.$s;
    $record     .=  $q."Auction_Ref".$q.$s;
    $record     .=  $q."Auction_Title"."$q,";
    $record     .=  $q."Product_ID"."$q,";
    $record     .=  $q."Sales_Price"."$q,";
    $record     .=  $q."Sale_Type".$q.$s;
    $record     .=  $q."Was_PayNow".$q.$s;
    $record     .=  $q."Close_Date".$q.$s;
    $record     .=  $q."Buyer".$q.$s;
    $record     .=  $q."Buyer_Email".$q.$s;
    $record     .=  $q."Buyer_Address".$q.$s;
    $record     .=  $q."Buyer_Postcode".$q.$s;
    $record     .=  $q."Buyer_Message".$q.$s;
    $record     .=  $q."Selected_Ship_Cost".$q.$s;
    $record     .=  $q."Selected_Ship_Text".$q.$s;
    $record     .=  $q."Refund_Status".$q.$s;
    $record     .=  "\n";

    # Write the heading line to the extract fiile

    print $extractfile $record;

    $SQL_exists_sales_extract_record        = $self->{ DBH }->prepare( qq { 
        SELECT      COUNT(*)
        FROM        SalesExtract
        WHERE       Auction_Ref             = ? 
        AND         Sale_Type               = ?
    } );

    $SQL_get_sales_extract_by_ref           = $self->{ DBH }->prepare( qq { 
        SELECT      *
        FROM        SalesExtract
        WHERE       Auction_Ref             = ? 
        AND         Sale_Type               = ?
    } );

    $SQL_get_sales_extract_by_key           = $self->{ DBH }->prepare( qq { 
        SELECT      *
        FROM        SalesExtract
        WHERE       Extract_ID              = ? 
    } );

    $SQL_add_sales_extract_record           = $self->{ DBH }->prepare( qq { 
        INSERT INTO SalesExtract            (
                    Extract_Action          ,
                    Auction_Ref             ,
                    Auction_Title           ,
                    Product_Code            ,
                    Sale_Price              ,
                    Sale_Type               ,
                    Was_PayNow              ,
                    Close_Date              ,
                    Buyer                   ,
                    Buyer_Email             ,
                    Buyer_Address           ,
                    Buyer_Postcode          ,
                    Buyer_Message           ,
                    Selected_Ship_Cost      ,
                    Selected_Ship_Text      ,
                    Refund_Status           )
        VALUES    ( ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 
                    ?, ?, ?, ?, ?, ?         )
    } );

    $SQL_add_sales_extract_record->bind_param( 11, $SQL_add_sales_extract_record, DBI::SQL_LONGVARCHAR );
    $SQL_add_sales_extract_record->bind_param( 13, $SQL_add_sales_extract_record, DBI::SQL_LONGVARCHAR) ;

    $SQL_update_sales_extract_record         = $self->{ DBH }->prepare( qq { 
        UPDATE      SalesExtract
        SET         Extract_Action          = ?,
                    Auction_Ref             = ?,
                    Auction_Title           = ?,
                    Product_Code            = ?,
                    Sale_Price              = ?,
                    Sale_Type               = ?,
                    Was_PayNow              = ?,
                    Close_Date              = ?,
                    Buyer                   = ?,
                    Buyer_Email             = ?,
                    Buyer_Address           = ?,
                    Buyer_Postcode          = ?,
                    Buyer_Message           = ?,
                    Selected_Ship_Cost      = ?,
                    Selected_Ship_Text      = ?,
                    Refund_Status           = ?
        WHERE       Extract_ID              = ? 
    } );

    $SQL_update_sales_extract_record->bind_param( 11, $SQL_update_sales_extract_record, DBI::SQL_LONGVARCHAR );
    $SQL_update_sales_extract_record->bind_param( 13, $SQL_update_sales_extract_record, DBI::SQL_LONGVARCHAR );

    my $SQL =  qq { 
        SELECT      $self->{ SF_ProductCodeCol }
        FROM        Auctions
        WHERE       AuctionRef              = ? 
    };

    $msg = "SQL Statement for SQL_get_auction_product_code:";
    $self->{ SF_DebugLevel } > 0 ? ( $self->update_log( $msg ) ) : ();
    $msg = "-----------------------------------------------";
    $self->{ SF_DebugLevel } > 0 ? ( $self->update_log( $msg ) ) : ();
    $self->{ SF_DebugLevel } > 0 ? ( $self->update_log( $SQL ) ) : ();

    $SQL_get_auction_product_code = $self->{ DBH }->prepare( $SQL );

    # Clear the Extract_Action Column before processing is commenced
    # *** Note this statement is executed IMMEDIATELY by DO method

    $SQL_clear_extract_action               = $self->{ DBH }->do( qq { 
        UPDATE      SalesExtract
        SET         Extract_Action          = ''
    } );

    print "Clear Extract SQL Output\n $DBI::errstr\n"

}

sub update_sales_extract {

    my $self  = shift;

    $msg = "Produce Trade Me Sales Feed";
    $self->update_log( $msg );

    # Log in to Trade Me and get the Trade Me Sales data then log out

    $self->login();

    # Log the outcome of the Trade Me log in attempt

    if ( $self->{ ErrorStatus } eq "1" ) {
        $msg = "Unable to log into Trade Me - Verify connection is operational";
        $self->update_log( $msg );
        return
    }
    else { 
        $msg = "Successfully logged into Trade Me";
        $self->update_log( $msg );
    }

    my $sales = $self->new_get_sold_listings( Last_45_Days => 1 );

    # Log the outcome of the Trade Me log in attempt

    if ( not defined( $sales ) ) {
        $msg = "Error retrieving sales data from Trade Me";
        $self->update_log( $msg );
        $self->logout();
        return
    }

    $msg = "Retrieved ".scalar( @$sales )." records";
    $self->update_log( $msg );

    # Set record count to 0;

    $records = 0;

    # Process the TradeMe Sales data and update the Sales Extract file

    foreach my $s ( @$sales ) {
        
        my $modified = 0;

        if ( not defined( $s->{ Buyer_Address } ) ) {
            $s->{ Buyer_Address } = "";
        }

        if ( not defined( $s->{ Buyer_Postcode } ) ) { 
            $s->{ Buyer_Postcode } = "";
        }

        if ( not defined( $s->{ Selected_Ship_Cost } ) ) {
            $s->{ Selected_Ship_Cost } = "";
        }

        if ( not defined( $s->{ Selected_Ship_Text } ) ) {
            $s->{ Selected_Ship_Text } = "";
        }

        # Check if sale is already recorded - Check for changes if found

        if ( $self->exists_sales_extract_record( $s->{ AuctionRef } , $s->{ Sale_Type } ) ) {

            my $a = $self->get_sales_extract_by_ref( $s->{ AuctionRef } , $s->{ Sale_Type } );

            if ( ( sprintf( "%2.f", $s->{ Selected_Ship_Cost } ) ne sprintf( "%2.f", $a->{ Selected_Ship_Cost } ) ) 
            or   ( $s->{ Selected_Ship_Text } ne $a->{ Selected_Ship_Text } ) ) {

                $msg = "New:".$s->{ Selected_Ship_Cost };
                $self->update_log( $msg );
                $msg = "Old:".$a->{ Selected_Ship_Cost };
                $self->update_log( $msg );
                $msg = "New:".$s->{ Selected_Ship_Text };
                $self->update_log( $msg );
                $msg = "Old:".$a->{ Selected_Ship_Text };
                $self->update_log( $msg );

                $modified = 1;

                $msg = "Trade Me Auction ".$a->{ Auction_Ref }." (".$s->{ Sale_Type }.") - Selected Shipping has been modified";
                $self->update_log( $msg );
            }

            if (  $s->{ Buyer_Message } ne  $a->{ Buyer_Message } ) {
                $modified = 1;
                $msg = "Trade Me Auction ".$a->{ Auction_Ref }." (".$s->{ Sale_Type }.") - Buyer Message has been modified";
                $self->update_log( $msg );
                $msg = "New:".$s->{ Buyer_Message };
                $self->update_log( $msg );
                $msg = "Old:".$a->{ Buyer_Message };
                $self->update_log( $msg );
            }

            if (  $s->{ Buyer_Address } ne  $a->{ Buyer_Address } ) {
                $modified = 1;
                $msg = "Trade Me Auction ".$a->{ AuctionRef }." (".$s->{ Sale_Type }.") - Buyer Address has been modified";
                $self->update_log( $msg );
            }

            if (  $s->{ Refund_Status } ne  $a->{ Refund_Status } ) {
                $modified = 1;
                $msg = "Trade Me Auction ".$s->{ Auction_Ref }." (".$s->{ Sale_Type }.") - Refund Status has been modified";
                $self->update_log( $msg );
            }

            if (  $s->{ PayNow } ne  $a->{ Was_PayNow } ) {
                $modified = 1;
                $msg = "Trade Me Auction ".$s->{ Auction_Ref }." (".$s->{ Sale_Type }.") - PayNow Status has been modified";
                $self->update_log( $msg );
            }

            if ( $modified ) {
                $self->update_sales_extract_record(
                    Extract_Action          =>  'CHG'                           ,
                    Was_PayNow              =>  $s->{ PayNow                }   ,
                    Buyer_Address           =>  $s->{ Buyer_Address         }   ,
                    Buyer_Postcode          =>  $s->{ Buyer_Postcode        }   ,
                    Buyer_Message           => "$s->{ Buyer_Message         }"  ,
                    Refund_Status           =>  $s->{ Refund_Status         }   ,
                    Selected_Ship_Cost      =>  $s->{ Selected_Ship_Cost    }   ,
                    Selected_Ship_Text      =>  $s->{ Selected_Ship_Text    }   ,
                    Extract_ID              =>  $a->{ Extract_ID            }   ,
                );

                $self->write_sales_extract_file( $a->{ Extract_ID } );

                $records++;
            }
        }
        else {
            $self->add_sales_extract_record(
                Extract_Action          =>  'NEW'                           ,
                Auction_Ref             =>  $s->{ AuctionRef            }   ,
                Auction_Title           =>  $s->{ Title                 }   ,
                Product_Code            =>  $self->get_auction_product_code( $s->{ AuctionRef } ) ,
                Sale_Price              =>  $s->{ Sale_Price            }   ,
                Sale_Type               =>  $s->{ Sale_Type             }   ,
                Was_PayNow              =>  $s->{ PayNow                }   ,
                Close_Date              =>  $s->{ Sold_Date }." ".$s->{ Sold_Time }  ,
                Buyer                   =>  $s->{ Buyer_Name            }   ,
                Buyer_Email             =>  $s->{ Buyer_Email           }   ,
                Buyer_Address           =>  $s->{ Buyer_Address         }   ,
                Buyer_Postcode          =>  $s->{ Buyer_Postcode        }   ,
                Buyer_Message           => "$s->{ Buyer_Message         }"  , 
                Selected_Ship_Cost      =>  $s->{ Selected_Ship_Cost    }   ,
                Selected_Ship_Text      =>  $s->{ Selected_Ship_Text    }   ,
                Refund_Status           =>  $s->{ Refund_Status         }   ,
            );

            my $a = $self->get_sales_extract_by_ref( $s->{ AuctionRef } , $s->{ Sale_Type } );

            $self->write_sales_extract_file( $a->{ Extract_ID }  );

            $records++;
        }
    }

    close $extractfile;

    if ( $records > 0 ) {
        if ( $self->{ FW_TransmitFile } ) {
             $self->send_extract_file();
        }
        $msg = "Sales Extract file updated with $records records";
        $self->update_log( $msg );
    }
    else {
        $msg = "No sales Events identified.";
        $self->update_log( $msg );
    }

    $self->logout();
}

sub destroy_SQL {

    my $self  = shift;

    $SQL_exists_sales_extract_record->finish();
    $SQL_get_sales_extract_by_key->finish();
    $SQL_get_sales_extract_by_ref->finish();
    $SQL_add_sales_extract_record->finish();
    $SQL_update_sales_extract_record->finish();
    $SQL_get_auction_product_code->finish();

    $self->{ DBH }->disconnect    || warn "Disconnect in ".(caller(0))[3]." failed:\n $DBI::errstr\n";
}

sub exists_sales_extract_record {

    my $self  = shift;
    my $ref = shift;
    my $type = shift;

    $SQL_exists_sales_extract_record->execute( $ref, $type ) || die "SQL in ".(caller(0))[3]." failed:\n $DBI::errstr\n";
    
    my $found = $SQL_exists_sales_extract_record->fetchrow_array;

    return $found;  
}

sub get_sales_extract_by_ref {

    my $self  = shift;
    my $ref = shift;
    my $type = shift;

    $SQL_get_sales_extract_by_ref->execute( $ref, $type ) || die "SQL in ".(caller(0))[3]." failed:\n $DBI::errstr\n";
    
    my $record = $SQL_get_sales_extract_by_ref->fetchrow_hashref;

    return $record;  
}

sub get_sales_extract_by_key {

    my $self  = shift;
    my $key = shift;
    my $type = shift;

    $SQL_get_sales_extract_by_key->execute( $key ) || die "SQL in ".(caller(0))[3]." failed:\n $DBI::errstr\n";

    my $record = $SQL_get_sales_extract_by_key->fetchrow_hashref;

    return $record;  
}

sub add_sales_extract_record {

    my $self  = shift;
    my $i = { @_ };
    my $r;

    # Set default values for new record
    
    $r->{ Extract_Action        } = "";
    $r->{ Auction_Ref           } = "";
    $r->{ Auction_Title         } = "";
    $r->{ Product_Code          } = 0;
    $r->{ Sale_Price            } = 0;
    $r->{ Sale_Type             } = "";
    $r->{ Was_PayNow            } = 0;
    $r->{ Close_Date            } = "12-05-1955";
    $r->{ Buyer                 } = "";
    $r->{ Buyer_Email           } = "";
    $r->{ Buyer_Address         } = "";
    $r->{ Buyer_Postcode        } = "";
    $r->{ Buyer_Message         } = "";
    $r->{ Selected_Ship_Cost    } = 0;
    $r->{ Selected_Ship_Text    } = "";
    $r->{ Refund_Status         } = "";

    # Read through the input values and alter the corresponding fields in the "Record" hash

    while ( ( my $key, my $value ) = each( %{ $i } ) ) {
        $r->{ $key } = $value;
    }

    # insert the updated record into the database
    
    $SQL_add_sales_extract_record->execute( 
       "$r->{ Extract_Action        }"  ,
       "$r->{ Auction_Ref           }"  ,
       "$r->{ Auction_Title         }"  ,
       "$r->{ Product_Code          }"  ,
        $r->{ Sale_Price            }   ,
       "$r->{ Sale_Type             }"  ,
        $r->{ Was_PayNow            }   ,
        $r->{ Close_Date            }   ,
       "$r->{ Buyer                 }"  ,
       "$r->{ Buyer_Email           }"  ,
       "$r->{ Buyer_Address         }"  ,
       "$r->{ Buyer_Postcode        }"  ,
       "$r->{ Buyer_Message         }"  ,
        $r->{ Selected_Ship_Cost    }   ,
       "$r->{ Selected_Ship_Text    }"  ,
       "$r->{ Refund_Status         }"  ,
    ) || die "SQL in ".( caller(0) )[3]." failed:\n $DBI::errstr\n";
}

sub update_sales_extract_record {

    my $self  = shift;
    my $i = { @_ };

    # Retrieve the current record from the database and update "Record" data-Hash

    $SQL_get_sales_extract_by_key->execute( $i->{ Extract_ID } );

    my $r =  $SQL_get_sales_extract_by_key->fetchrow_hashref;

    # Read through the input record and alter the corresponding field in the "Record" hash

    while ( ( my $key, my $value ) = each( %{ $i } ) )  {
        $r->{ $key } = $value;
        # print $key." ".$value."\n";
    }

    # Update the database with the new updated "Record" hash

    $SQL_update_sales_extract_record->execute(
         $r->{ Extract_Action        }   ,
        "$r->{ Auction_Ref           }"  ,
        "$r->{ Auction_Title         }"  ,
        "$r->{ Product_Code          }"  ,
         $r->{ Sale_Price            }   ,
        "$r->{ Sale_Type             }"  ,
         $r->{ Was_PayNow            }   ,
         $r->{ Close_Date            }   ,
        "$r->{ Buyer                 }"  ,
        "$r->{ Buyer_Email           }"  ,
        "$r->{ Buyer_Address         }"  ,
        "$r->{ Buyer_Postcode        }"  ,
        "$r->{ Buyer_Message         }"  ,
         $r->{ Selected_Ship_Cost    }   ,
        "$r->{ Selected_Ship_Text    }"  ,
        "$r->{ Refund_Status         }"  ,
         $r->{ Extract_ID            }   ,
    ) || die "SQL in ".( caller(0) )[3]." failed:\n $DBI::errstr\n";
}

sub get_auction_product_code {

    my $self  = shift;
    my $auctionref = shift;

    $SQL_get_auction_product_code->execute( $auctionref ) || die "SQL in ".(caller(0))[3]." failed:\n $DBI::errstr\n";

    my $code     = $SQL_get_auction_product_code->fetchrow_array;

    if ( defined $code ) {    
        return $code;
    } 
    else {
        return "NOT FOUND";
    }

}

sub date_value {

    # indate format = Sep-dd-yyyy

    my $self  = shift;
    my $indate = shift;

    my ( $yy, $mm, $dd );

    $indate =~ m/(.+?)(-)(.+?)(-)(.*)/; 

    $dd = $3;

    if      ( $1 eq 'Jan' ) { $mm =  1; }
    elsif   ( $1 eq 'Feb' ) { $mm =  2; }
    elsif   ( $1 eq 'Mar' ) { $mm =  3; }
    elsif   ( $1 eq 'Apr' ) { $mm =  4; }
    elsif   ( $1 eq 'May' ) { $mm =  5; }
    elsif   ( $1 eq 'Jun' ) { $mm =  6; }
    elsif   ( $1 eq 'Jul' ) { $mm =  7; }
    elsif   ( $1 eq 'Aug' ) { $mm =  8; }
    elsif   ( $1 eq 'Sep' ) { $mm =  9; }
    elsif   ( $1 eq 'Oct' ) { $mm = 10; }
    elsif   ( $1 eq 'Nov' ) { $mm = 11; }
    elsif   ( $1 eq 'Dec' ) { $mm = 12; }

    $yy = $5;

    my $outdate = ( $yy * 10000 ) + ( $mm * 100 ) + ( $dd );
}

sub time_value {

    my $self  = shift;

    # indate format = hh:mm AM/PM

    my $intime = shift;

    my ( $hh, $mm );

    $intime =~ m/(.+?)(:)(.+?)( )(AM|PM)/; 

    $hh = $1;
    $mm = $3;

    if  ( ( $5 eq 'PM' ) and ( $hh < 12 ) ) {
        $hh += 12;
    }

    my $outtime = ( $hh * 100 ) + ( $mm );
}

sub format_date {

    my $self  = shift;

    # Format the date into a date suitable for posting to SQL Server
    # Date is intially Aug-24-2008 is reversed and converted into numbers

    my $date    = shift;

    my ($mm, $day);

    $date =~ m/^(.+?)-(.+?)-(.*)/;

    if      ( $1 eq 'Jan' ) { $mm = "01"; }
    elsif   ( $1 eq 'Feb' ) { $mm = "02"; }
    elsif   ( $1 eq 'Mar' ) { $mm = "03"; }
    elsif   ( $1 eq 'Apr' ) { $mm = "04"; }
    elsif   ( $1 eq 'May' ) { $mm = "05"; }
    elsif   ( $1 eq 'Jun' ) { $mm = "06"; }
    elsif   ( $1 eq 'Jul' ) { $mm = "07"; }
    elsif   ( $1 eq 'Aug' ) { $mm = "08"; }
    elsif   ( $1 eq 'Sep' ) { $mm = "09"; }
    elsif   ( $1 eq 'Oct' ) { $mm = "10"; }
    elsif   ( $1 eq 'Nov' ) { $mm = "11"; }
    elsif   ( $1 eq 'Dec' ) { $mm = "12"; }

    if ( $2 < 10 ) {
        $date = $3."-".$mm."-0".$2;
    }
    else {
        $date = $3."-".$mm."-".$2;
    }

    return $date;
}

sub write_sales_extract_file {

    my $self  = shift;
    my $extractid = shift;

    $SQL_get_sales_extract_by_key->execute( $extractid );
    my $i =  $SQL_get_sales_extract_by_key->fetchrow_hashref;

    my $record  =      $i->{ Extract_ID         }.$s;
    $record     .=  $q.$i->{ Extract_Action     }.$q.$s;
    $record     .=  $q.$i->{ Auction_Ref        }.$q.$s;
    $record     .=  $q.$i->{ Auction_Title      }.$q.$s;
    $record     .=  $q.$i->{ Product_Code       }.$q.$s;
    $record     .=     $i->{ Sale_Price         }.$s;
    $record     .=  $q.$i->{ Sale_Type          }.$q.$s;
    $record     .=     $i->{ Was_PayNow         }.$s;
    $record     .=  $q.$i->{ Close_Date         }.$q.$s;
    $record     .=  $q.$i->{ Buyer              }.$q.$s;
    $record     .=  $q.$i->{ Buyer_Email        }.$q.$s;
    $record     .=  $q.$i->{ Buyer_Address      }.$q.$s;
    $record     .=  $q.$i->{ Buyer_Postcode      }.$q.$s;
    $record     .=  $q.$i->{ Buyer_Message      }.$q.$s;
    $record     .=     $i->{ Selected_Ship_Cost }.$s;
    $record     .=  $q.$i->{ Selected_Ship_Text }.$q.$s;
    $record     .=  $q.$i->{ Refund_Status      }.$q.$s;
    $record     .=  "\n";

    print $extractfile $record;
}

sub format_time {

    my $self  = shift;

    # Format the time into a time suitable for posting to SQL Server
    # Time is intially 9:40 AM is reversed and converted into numbers

    my $time    = shift;

    my ($hh, $mm);

    $time =~ m/^(.+?):(.+?)( )(AM|PM)/;

    $hh = $1;
    $mm = $2;

    if ( ( $4 eq "PM" ) and ( $1 < 12 ) ) {
        $hh = $1 + 12;
    }

    if ( $hh < 10 ) {
        $time = "0".$hh.":".$mm.":00";
    }
    else {
        $time = $hh.":".$mm.":00";
    }

    return $time;
}

sub send_extract_file {

    my $self        = shift;
    my $username    = $self->{ SF_FTPUserName   };
    my $password    = $self->{ SF_FTPPassword   };
    my $host        = $self->{ SF_FTPHost       };
    my $ok;

    my $ftp         = Net::FTP->new( $host );
    
    # This is where the transfers occur

    $self->update_log( 'Logging into '.$host );    
    $ok = $ftp->login( $username, $password );

    if  ( $ok ) { $self->update_log( 'Logged in to Sales Feed FTP site succesfully' );            }
    else        { $self->update_log( 'Error encountered logging into Sales Feed FTP site: '.$@ ); }

    print 'Sending Sales Extract Update '."$extractname\n";    
    $ok         = $ftp->put( $extractpath."\\".$extractname, $extractname );

    if  ( $ok ) { $self->update_log( 'Sales Feed data File Transferred succesfully' );             }
    else        { $self->update_log( 'Error encountered Transferring Sales Feed data File: '.$@ ); }

    $ok         = $ftp->quit;
    unless ( $ok ) { $self->update_log( 'Error closing FTP Session: '.$@ );                        }

}

1;


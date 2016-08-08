#!perl -w
#---------------------------------------------------------------------------------------------
# 2SellIt automation and interaction package module
#
# Copyright 2007, Evan Harris.  All rights reserved.
#---------------------------------------------------------------------------------------------

package Auctionitis::ProductMaintenance;
use Auctionitis;
require Exporter;

our @ISA = qw( Auctionitis Exporter );

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

my ( $ua, $sa, $url, $req, $response, $content, $dbh, $sdb, $msg );

###############################################################################
#                    S Q L    S T A T E M E N T S                             #
###############################################################################

my $SQL_get_product_list;               # Get list of products to process
my $SQL_get_template_list;              # Get list of templates
my $SQL_exists_product_template;        # Check whether Auction Template record exists
my $SQL_exists_product_record;          # Check whether product master record exists
my $SQL_get_product_template;           # Get the product template record
my $SQL_update_auction_cycle;           # Update auction cycle for a product code/Record type
my $SQL_update_auction_description;     # Update auction  descriptive text
my $SQL_update_product_pricing;         # Update Product pricing for Clones & Templates
my $SQL_update_userdefined_column3;     # Update a particular user defined column for a product code
my $SQL_clear_text_changed_flag;        # Clear the Text Updated flag (Currently UserDefined10)
my $SQL_allow_text_change;              # Check the Allow Text changes flag (Currently UserDefined09)
my $SQL_get_lookup_category;            # Get the Trade Me category from the look-up Cross Reference
my $SQL_exists_product_type;            # Check the product type exists
my $SQL_get_product_type_text;          # Get the product text for a product type
my $SQL_get_product_type_category;      # Get Category assigned to Report Type
my $SQL_get_product_type_base_price;    # Get Base price assigned to Report Type
my $SQL_add_product_record;             # Add a product Record
my $SQL_get_product_record;             # Get the product record
my $SQL_update_product_record;          # Update a product Record
my $SQL_delete_product_records;         # Delete product Records
my $SQL_drop_old_products_table;        # Delete the Product Backup table
my $SQL_copy_all_product_records;       # Copy all product Records to new table
my $SQL_drop_old_auctions_table;        # Delete the Auction Backup table
my $SQL_copy_all_auction_records;       # Copy all auction Records to new table
my $SQL_is_excluded_product;            # This product code is excluded from processing
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
    
        $self->{ 'PM_'.$parm } = $value unless $self->{ 'PM_'.$parm };
    }
}

#=============================================================================================
# Method    :  initialise
# Added     : 22/03/07
#=============================================================================================

sub initialise {

    my $self  = shift;

    # INitialise the Auctoninitis object to get access to the broser and set other properties

    $self->Auctionitis::initialise( Product => "Auctionitis" );

    # Load the configuration file for the Product Maintenance Options

    $self->{ Config } = 'ProductMaintenance.config' unless $self->{ Config };

    $self->_load_config;

    # Set defaults for required values if not loaded from file

    $self->{ PM_DefaultCategory     } = '0'             unless $self->{ PM_DefaultCategory      };
    $self->{ PM_CategoryLookupCol   } = 'ProductType'   unless $self->{ PM_CategoryLookupCol    };
    $self->{ PM_DatabaseDSN         } = 'Auctionitis'   unless $self->{ PM_DatabaseDSN          };
    $self->{ PM_MinStock            } = 5               unless $self->{ PM_MinStock             };
    $self->{ PM_BasePrice           } = 0               unless $self->{ PM_BasePrice            };

    # Dump current object properties if Debug has been set

    $self->{ PM_DebugLevel } ge 0 ? $self->dump_properties() : ();

    # Connect to the database specified in the configuration file

    $self->DBconnect( $self->{ PM_DatabaseDSN } );

    # Set up SQL Statements required for Product Maintenance
    
    $msg = "Create SQL Statements";
    $self->update_log( $msg, INFO );

    # Build list of products to check from product master table

    $SQL_get_product_list           = $self->{ DBH }->prepare( qq { 
        SELECT      * 
        FROM        Products
    } );

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

    $SQL_exists_product_record      = $self->{ DBH }->prepare( qq { 
        SELECT      COUNT(*)
        FROM        Products
        WHERE       ProductCode     = ? 
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

    # Specify the column to be updated at run time

    $SQL_update_userdefined_column3 = $self->{ DBH }->prepare( qq { 
        UPDATE      Auctions
        SET         UserDefined03   = ?
        WHERE       ProductCode     = ?
    } );


    $SQL_update_auction_description->bind_param( 1, $SQL_update_auction_description, DBI::SQL_LONGVARCHAR );   

    $SQL_clear_text_changed_flag    = $self->{ DBH }->prepare( qq { 
        UPDATE      Auctions
        SET         ?               = ''
    } );

    $SQL_allow_text_change          = $self->{ DBH }->prepare( qq { 
        SELECT      ?
        FROM        Auctions
        WHERE       ProductCode     = ?
        AND         AuctionStatus   = 'TEMPLATE'
    } );

    $SQL_get_lookup_category        = $self->{ DBH }->prepare( qq { 
        SELECT      TradeMeCategory
        FROM        CategoryLookup
        WHERE       LookupValue     = ? 
    } );

    $SQL_exists_product_type        = $self->{ DBH }->prepare( qq { 
        SELECT      COUNT(*)
        FROM        ProductTypes
        WHERE       ProductType     = ? 
    } );

    $SQL_get_product_type_text      = $self->{ DBH }->prepare( qq { 
        SELECT      ProductTypeText
        FROM        ProductTypes
        WHERE       ProductType     = ? 
    } );

    $SQL_get_product_type_category  = $self->{ DBH }->prepare( qq { 
        SELECT      ProductTypeCategory
        FROM        ProductTypes
        WHERE       ProductType     = ? 
    } );

    $SQL_get_product_type_base_price = $self->{ DBH }->prepare( qq { 
        SELECT      ProductTypeBasePrice
        FROM        ProductTypes
        WHERE       ProductType     = ? 
    } );

    $SQL_delete_product_records     = $self->{ DBH }->prepare( qq { 
        DELETE  FROM    Products
    } );

    $SQL_add_product_record         = $self->{ DBH }->prepare( qq {
        INSERT INTO     Products            (
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
                        ?,?,?,?,?,?,?,?,?,? )
    } );

    $SQL_add_product_record->bind_param(  3, $SQL_add_product_record, DBI::SQL_LONGVARCHAR );   # Additional setup for field 3  (Description) as it is a memo field
    $SQL_add_product_record->bind_param( 78, $SQL_add_product_record, DBI::SQL_LONGVARCHAR );   # Additional setup for field 78 (Usernotes) as it is a memo field
    
    $SQL_update_product_record = $self->{ DBH }->prepare( qq { 

        UPDATE  Products   
        SET     Title                          = ?,          
                Subtitle                       = ?,
                Description                    = ?,
                ProductType                    = ?,
                ProductCode                    = ?,
                ProductCode2                   = ?,
                SupplierRef                    = ?,
                LoadSequence                   = ?,
                Held                           = ?,
                AuctionCycle                   = ?,
                AuctionStatus                  = ?,
                RelistStatus                   = ?,
                AuctionSold                    = ?,
                StockOnHand                    = ?,
                RelistCount                    = ?,
                NotifyWatchers                 = ?,
                UseTemplate                    = ?,
                TemplateKey                    = ?,
                AuctionRef                     = ?,
                SellerRef                      = ?,
                DateLoaded                     = ?,
                CloseDate                      = ?,
                CloseTime                      = ?,
                Category                       = ?,
                MovieRating                    = ?,
                MovieConfirm                   = ?,
                AttributeCategory              = ?,
                AttributeName                  = ?,
                AttributeValue                 = ?,
                TMATT038                       = ?,
                TMATT104                       = ?,
                TMATT104_2                     = ?,
                TMATT106                       = ?,
                TMATT106_2                     = ?,
                TMATT108                       = ?,
                TMATT108_2                     = ?,
                TMATT111                       = ?,
                TMATT112                       = ?,
                TMATT115                       = ?,
                TMATT117                       = ?,
                TMATT118                       = ?,
                TMATT163                       = ?,
                TMATT164                       = ?,
                IsNew                          = ?,
                TMBuyerEmail                   = ?,
                StartPrice                     = ?,
                ReservePrice                   = ?,
                BuyNowPrice                    = ?,
                EndType                        = ?,
                DurationHours                  = ?,
                EndDays                        = ?,
                EndTime                        = ?,
                ClosedAuction                  = ?,
                BankDeposit                    = ?,
                CreditCard                     = ?,
                CashOnPickup                   = ?,
                EFTPOS                         = ?,
                AgreePayMethod                 = ?,
                SafeTrader                     = ?,
                PaymentInfo                    = ?,
                FreeShippingNZ                 = ?,
                ShippingInfo                   = ?,
                PickupOption                   = ?,
                ShippingOption                 = ?,
                Featured                       = ?,
                Gallery                        = ?,
                BoldTitle                      = ?,
                FeatureCombo                   = ?,
                HomePage                       = ?,
                CopyCount                      = ?,
                Message                        = ?,       
                PictureKey1                    = ?, 
                PictureKey2                    = ?,          
                PictureKey3                    = ?,
                AuctionSite                    = ?,
                UserDefined01                  = ?,
                UserDefined02                  = ?,       
                UserDefined03                  = ?,
                UserDefined04                  = ?,       
                UserDefined05                  = ?,
                UserDefined06                  = ?,
                UserDefined07                  = ?,
                UserDefined08                  = ?,
                UserDefined09                  = ?,
                UserDefined10                  = ?,
                UserStatus                     = ?,
                UserNotes                      = ?, 
                OfferPrice                     = ?, 
                OfferProcessed                 = ?, 
                SaleType                       = ? 
        WHERE   ProductCode                    = ? 
    } );

    # Additional setup for field 2 (Description) as it is a memo field    
    
    $SQL_update_product_record->bind_param(  3, $SQL_update_product_record, DBI::SQL_LONGVARCHAR );   
    $SQL_update_product_record->bind_param( 78, $SQL_update_product_record, DBI::SQL_LONGVARCHAR );  

    $SQL_get_product_record             = $self->{ DBH }->prepare( qq { 
        SELECT *
        FROM   Products
        WHERE  ProductCode              = ?
    } );

    # Create the SQL statements to create backusp of the Products and Auctions table

    $SQL_drop_old_products_table        = $self->{ DBH }->prepare( qq { 
        DROP   TABLE OldProducts
    } );

    $SQL_copy_all_product_records       = $self->{ DBH }->prepare( qq { 
        SELECT *
        INTO   OldProducts
        FROM   Products
    } );

    $SQL_drop_old_auctions_table        = $self->{ DBH }->prepare( qq { 
        DROP   TABLE OldAuctions
    } );

    $SQL_copy_all_auction_records       = $self->{ DBH }->prepare( qq { 
        SELECT *
        INTO   OldAuctions
        FROM   Auctions
    } );

    $SQL_is_excluded_product            = $self->{ DBH }->prepare( qq { 
        SELECT      COUNT(*)
        FROM        ProductExclusions
        WHERE       ProductCode         = ? 
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

    if ( $self->{ PM_StockUpdateDateStampCol } ) {

        my $SQL = qq { 
            UPDATE      Auctions
            SET         $self->{ PM_StockUpdateDateStampCol } = ?
            WHERE       ProductCode = ? 
        };

        $msg = "Timestamp SQL Statement";
        $self->update_log( $msg, INFO );
        $self->update_log( $SQL, INFO );

        $SQL_set_update_timestamp = $self->{ DBH }->prepare( $SQL );
    }
}

#=============================================================================================
# Method    : process_product_updates
# Added     : 27/03/05
# Input     : Hash
# Returns   : 
#=============================================================================================

sub process_product_updates {

    my $self    = shift;
    my $i       = { @_ };

    $msg = "*--------------------------------------------------------------";
    $self->update_log( $msg, INFO );

    $msg = "* Start PRODUCT UPDATE Processing";
    $self->update_log( $msg, INFO );

    $msg = "*--------------------------------------------------------------";
    $self->update_log( $msg, INFO );

    # $p = product records
    # $a = auction records
    # 
    my $products = $self->get_product_list();

    foreach my $p ( @$products ) {

        # If the product code is found do the stock tests

        if ( $self->exists_product_template( $p->{ ProductCode } ) ) {

            my $a = $self->get_product_template( $p->{ ProductCode } );

            $msg = "EXISTING Product: ".$p->{ ProductCode }." (".$a->{ AuctionCycle}.") Old SOH: ".$a->{ StockOnHand }."; New SOH: ".$p->{ StockOnHand };
            $self->update_log( $msg, INFO );

            if (    ( $p->{ StockOnHand  } < $self->{ PM_MinimumStock }  )
                and ( $a->{ AuctionCycle } ne Z_NOSTOCK ) 
                and ( $a->{ AuctionCycle } ne Z_SLOW    ) 
                and ( $a->{ AuctionCycle } ne Z_DEAD    ) ) { 

                $msg = "Product was previously in stock and in circulation: REMOVE";
                $self->update_log( $msg, INFO );
                
                # If the NEW stock figure is less than the minimum stock figure, and the current TEMPLATE
                # is NOT marked as being out of stock, modify the TEMPLATE, CLONE and CURRENT records to 
                # assign Auction Cycle Z_REMOVE to flag them to be removed from loading AND TradeMe

                $self->update_auction_cycle(
                    AuctionCycle    =>  Z_REMOVE                ,
                    ProductCode     =>  $p->{ ProductCode  }    ,
                    AuctionStatus   =>  STS_TEMPLATE            ,
                );

                $self->update_auction_cycle(
                    AuctionCycle    =>  Z_REMOVE                ,
                    ProductCode     =>  $p->{ ProductCode  }    ,
                    AuctionStatus   =>  STS_CLONE               ,
                );

                $self->update_auction_cycle(
                    AuctionCycle    =>  Z_REMOVE                ,
                    ProductCode     =>  $p->{ ProductCode  }    ,
                    AuctionStatus   =>  STS_CURRENT             ,
                );

                # Set the Offer Price for CURRENT Records to ZERO so they don't get offered

                $self->update_product_pricing(
                    OfferPrice      =>  0                       ,
                    StartPrice      =>  $a->{ StartPrice    }   ,
                    ReservePrice    =>  $a->{ ReservePrice  }   ,
                    BuyNowPrice     =>  $a->{ BuyNowPrice   }   ,
                    ProductCode     =>  $p->{ ProductCode   }   ,
                    AuctionStatus   =>  STS_CURRENT             ,
                );
            }
            elsif ( ( $p->{ StockOnHand } >= $self->{ PM_MinimumStock } ) and $a->{ AuctionCycle} eq Z_NOSTOCK ) {

                $msg = "Product was previously NOT in stock: ADD";
                $self->update_log( $msg, INFO );

                # If the NEW stock figure is greater than or equal to the minimum stock figure, and the
                # current TEMPLATE is marked as being out of stock, modify the TEMPLATE records to assign
                # Auction Cycle Z_CANLIST to flag them to be added to the loading schedule

                $self->update_auction_cycle(
                    AuctionCycle    =>  Z_CANLIST               ,
                    ProductCode     =>  $p->{ ProductCode  }    ,
                    AuctionStatus   =>  STS_TEMPLATE            ,
                );
            }
            elsif ( ( $p->{ StockOnHand } >= $self->{ PM_MinimumStock } ) and $a->{ AuctionCycle} ne Z_NOSTOCK ) {
                $msg = "Product still has stock and is in circulation: KEEP LISTING";
                $self->update_log( $msg, INFO );
            }
            elsif ( ( $p->{ StockOnHand } <  $self->{ PM_MinimumStock } ) and $a->{ AuctionCycle} eq Z_NOSTOCK ) {
                $msg = "Product is still NOT in stock: LEAVE UNLISTED";
                $self->update_log( $msg, INFO );
            }

            # Update the stock on hand for all Records with the product code

            $self->update_stock_on_hand(
                StockOnHand =>  $p->{ StockOnHand   }   ,  
                ProductCode =>  $p->{ ProductCode   }   ,
            );

            # If price callbacks have been provided call them and set price values

            if ( defined $self->{ StartPrice_Handler } ) {
                 $p->{ StartPrice } = $self->{ StartPrice_Handler }->( %$p );
            }

            if ( defined $self->{ ReservePrice_Handler } ) {
                 $p->{ ReservePrice } = $self->{ ReservePrice_Handler }->( %$p );
            }

            if ( defined $self->{ BuyNowPrice_Handler } ) {
                 $p->{ BuyNowPrice } = $self->{ BuyNowPrice_Handler }->( %$p );
            }

            if ( defined $self->{ OfferPrice_Handler } ) {
                 $p->{ OfferPrice } = $self->{ OfferPrice_Handler }->( %$p );
            }

            # Then, Check if the pricing has changed and update it for the CLONE and TEMPLATE auctions if required

            if (   ( $p->{ StartPrice   } != $a->{ StartPrice   } ) 
                or ( $p->{ ReservePrice } != $a->{ ReservePrice } )
                or ( $p->{ BuyNowPrice  } != $a->{ BuyNowPrice  } )
                or ( $p->{ OfferPrice   } != $a->{ OfferPrice   } ) ) {
            

                $msg = "Start Price   - New: ".$p->{ StartPrice     }." Old: ".$a->{ StartPrice     };
                $self->update_log( $msg, INFO );
                $msg = "Reserve Price - New: ".$p->{ ReservePrice   }." Old: ".$a->{ ReservePrice   };
                $self->update_log( $msg, INFO );
                $msg = "Buy Now Price - New: ".$p->{ BuyNowPrice    }." Old: ".$a->{ BuyNowPrice    };
                $self->update_log( $msg, INFO );
                $msg = "Offer Price   - New: ".$p->{ OfferPrice     }." Old: ".$a->{ OfferPrice     };
                $self->update_log( $msg, INFO );

                $self->update_product_pricing(
                    StartPrice      =>  $p->{ StartPrice    }   ,
                    ReservePrice    =>  $p->{ ReservePrice  }   ,
                    BuyNowPrice     =>  $p->{ BuyNowPrice   }   ,
                    OfferPrice      =>  $p->{ OfferPrice    }   ,
                    ProductCode     =>  $p->{ ProductCode   }   ,
                    AuctionStatus   =>  STS_TEMPLATE            ,
                );

                $self->update_product_pricing(
                    StartPrice      =>  $p->{ StartPrice    }   ,
                    ReservePrice    =>  $p->{ ReservePrice  }   ,
                    BuyNowPrice     =>  $p->{ BuyNowPrice   }   ,
                    OfferPrice      =>  $p->{ OfferPrice    }   ,
                    ProductCode     =>  $p->{ ProductCode   }   ,
                    AuctionStatus   =>  STS_CLONE            ,
                );
            }
            else {
                $msg = "NO Price Update Required";
                $self->update_log( $msg, INFO );
            }

            # Check if the description has changed and update it for the TEMPLATE auctions if required & flag them as changed

            my $description = $self->{ Description_Handler }->( %$p );

            if ( $description ne $a->{ Description } ) {

                $self->update_auction_description(
                    Description     =>  $description            ,
                    ProductCode     =>  $p->{ ProductCode  }    ,
                );
                $msg = "Item Description modified and may require editing";
                $self->update_log( $msg, INFO );
            }
        }

        # otherwise add the product to the auction database as a new template
        
        else {

            $msg = "*** NEW Product: ".$p->{ ProductCode }." Opening SOH: ".$p->{ StockOnHand };
            $self->update_log( $msg, INFO );

            # Remove Stray Quotes from the Product Type column

            $p->{ ProductType } =~ tr/'//d;

            # Build the description abd prcing values using the supplied call back handlers

            $p->{ Description   } = $self->{ Description_Handler  }->( %$p );
            $p->{ StartPrice    } = $self->{ StartPrice_Handler   }->( %$p );
            $p->{ ReservePrice  } = $self->{ ReservePrice_Handler }->( %$p );
            $p->{ BuyNowPrice   } = $self->{ BuyNowPrice_Handler  }->( %$p );
            $p->{ OfferPrice    } = $self->{ OfferPrice_Handler   }->( %$p );

            # Set the Held flag if the item has no stock

            if  ( $p->{ StockOnHand } < $self->{ PM_MinimumStock } ) {
                $p->{ Held }        = -1;
                $p->{ OfferPrice }  = 0; 
            }
            else {
                $p->{ Held }        = 0;
            }
            
            # Add the new Auction Template for the new Product
    
            $p->{ AuctionKey } = $self->add_auction_record_202(
                AuctionSite             =>   SITE_TRADEME                   ,            
                AuctionStatus           =>   STS_TEMPLATE                   ,            
                AuctionCycle            =>   Z_NEWITEM                      ,            
                Title                   =>   $p->{ Title                }   ,           
                Subtitle                =>   $p->{ Subtitle             }   ,           
                Description             =>   $p->{ Description          }   ,          
                ProductType             =>   $p->{ ProductType          }   ,          
                ProductCode             =>   $p->{ ProductCode          }   ,          
                ProductCode2            =>   $p->{ ProductCode2         }   ,          
                SupplierRef             =>   $p->{ SupplierRef          }   ,          
                LoadSequence            =>   $p->{ LoadSequence         }   ,
                Held                    =>   $p->{ Held                 }   ,
                StockOnHand             =>   $p->{ StockOnHand          }   ,            
                RelistStatus            =>   $p->{ RelistStatus         }   ,            
                SellerRef               =>   $p->{ SellerRef            }   ,
                Category                =>   $p->{ Category             }   ,                
                IsNew                   =>   $p->{ IsNew                }   ,              
                TMBuyerEmail            =>   $p->{ TMBuyerEmail         }   ,              
                StartPrice              =>   $p->{ StartPrice           }   ,              
                ReservePrice            =>   $p->{ ReservePrice         }   ,                
                BuyNowPrice             =>   $p->{ BuyNowPrice          }   ,              
                OfferPrice              =>   $p->{ OfferPrice           }   ,
                EndType                 =>   $p->{ EndType              }   ,              
                DurationHours           =>   $p->{ DurationHours        }   ,              
                BankDeposit             =>   $p->{ BankDeposit          }   ,              
                CreditCard              =>   $p->{ CreditCard           }   ,              
                UserDefined01           =>   $p->{ UserDefined01        }   ,
                UserDefined02           =>   $p->{ UserDefined02        }   ,
            );

            if ( not $self->exists_product_image( $self->{ ImageName_Handler  }->( %$p ) ) ) {
                $self->import_product_image( %$p );
            }
            else {
                $self->add_auction_image( %$p );
            }
        }
    }
}

sub mark_templates_as_deleted {

    my $self    = shift;

    # $p = product records
    # $t = auction template records

    $msg = "Get Templates to identify deleted products";
    $self->update_log( $msg, INFO );

    my $templates = $self->get_template_list();

    $msg = "*--------------------------------------------------------------";
    $self->update_log( $msg, INFO );
    $msg = "* Start TEMPLATE Processing";
    $self->update_log( $msg, INFO );
    $msg = "*--------------------------------------------------------------";
    $self->update_log( $msg, INFO );
    

    foreach my $t ( @$templates ) {

        $msg = "Checking product code".$t->{ ProductCode };
        $self->update_log( $msg, INFO );

        # If the product code is NOT found in the product table mark it for deletion

        if ( not $self->exists_product_record( $t->{ ProductCode } ) ) {

            $msg = "Product ".$t->{ ProductCode }." not found in product table - DELETE";
            $self->update_log( $msg, INFO );

            $self->update_auction_cycle(
                AuctionCycle    =>  Z_DELETE                ,
                ProductCode     =>  $t->{ ProductCode }     ,
                AuctionStatus   =>  STS_TEMPLATE            ,
            );

            $self->update_auction_cycle(
                AuctionCycle    =>  Z_DELETE                ,
                ProductCode     =>  $t->{ ProductCode  }    ,
                AuctionStatus   =>  STS_CLONE               ,
            );
        }
        else {
            $msg = "Product ".$t->{ ProductCode }." found in product table - RETAIN";
            $self->update_log( $msg, INFO );
        }
    }
}

#=============================================================================================
# Method    : parse_csv_data
# Added     : 27/03/05
# Input     : Hash
# Returns   : Array reference
#
# This method processes a csv file and returns an array of has references, 1 array element
# per record; hash keys are named for column names
# 
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

        $msg = "Headings: $headings";
        $self->update_log( $msg, DEBUG );


        if ( $csv->eof() ) {

            # Nothing to process so return undef

            $msg = "Nothing to process - returning";
            $self->update_log( $msg, DEBUG );

            return undef;
        }

        $csv->column_names( $headings );
    }

    # Priming Read for procsssing the rest of the file
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
# Added     : 22/03/07
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
# Added     : 22/03/07
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
# Added     : 22/03/07
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

    if ( $self->{ PM_DebugLevel } gt 0 ) { return 1; } else { return 0; }
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

    if ( not defined( $self->{ PM_LogFile } ) ) {
        $self->{ PM_DebugLevel } ge 1 ? ( print "No log file defined.\n" ) : ();
        return;
    }

    # Strip any new lines out before printing to log

    $msg =~ tr/\n//; 

    # Get todays date to Timestamp log entry
    
    my ($secs, $mins, $hrs, $dd, $mm, $yy, $dow, $jul, $isdst) = localtime;
    
    # open the logfile

    open ( LOGFILE, ">> $self->{ PM_LogFile }" );

    # format the retrieved date and time values

    $mm = $mm + 1;
    $yy = $yy + 1900;

    if ($secs < 10)   { $secs = "0".$secs; }
    if ($mins < 10)   { $mins = "0".$mins; }
    if ($dd   < 10)   { $dd   = "0".$dd;   }
    if ($mm   < 10)   { $mm   = "0".$mm;   }

    my $now = "$dd-$mm-$yy $hrs:$mins:$secs";

    # print to file based on 

    if ( uc( $sev )     eq INFO     and $self->{ PM_DebugLevel } ge 0 ) {
        $self->{ PM_Console }   ? ( print $msg."\n" ):();
        print LOGFILE $now." ".$msg."\n";
    }
    elsif ( uc( $sev )  eq DEBUG    and $self->{ PM_DebugLevel } ge 1 ) {
        $self->{ PM_Console }   ? ( print "DEBUG: ".$msg."\n" ):();
        print LOGFILE $now." DEBUG: ".$msg."\n";
    }
    elsif ( uc( $sev )  eq VERBOSE  and $self->{ PM_DebugLevel } ge 2 ) {
        $self->{ PM_Console }   ? ( print "DEBUG: ".$msg."\n" ):();
        print LOGFILE $now." DEBUG: ".$msg."\n";
    }

    close LOGFILE;
}

sub get_product_list {

    my $self = shift;

    $SQL_get_product_list->execute;
    my $products = $SQL_get_product_list->fetchall_arrayref( {} );

    return $products;
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

sub get_product_type_text {

    my $self  = shift;
    my $type = shift;

    $SQL_get_product_type_text->execute( $type ) || die "SQL in ".(caller(0))[3]." failed:\n $DBI::errstr\n";

    my $text = $SQL_get_product_type_text->fetchrow_array;

    return $text;
}

sub get_product_type_category {

    my $self  = shift;
    my $type = shift;

    $SQL_get_product_type_category->execute( $type ) || die "SQL in ".(caller(0))[3]." failed:\n $DBI::errstr\n";

    my $category = $SQL_get_product_type_category->fetchrow_array;

    return $category;
}

sub get_product_type_base_price {

    my $self  = shift;
    my $type = shift;

    $SQL_get_product_type_base_price->execute( $type ) || die "SQL in ".(caller(0))[3]." failed:\n $DBI::errstr\n";

    my $base_price = $SQL_get_product_type_base_price->fetchrow_array;

    return $base_price;
}

sub get_lookup_category {

    my $self  = shift;
    my $value = shift;

    $SQL_get_lookup_category->execute( $value ) || die "SQL in ".(caller(0))[3]." failed:\n $DBI::errstr\n";

    my $category = $SQL_get_lookup_category->fetchrow_array;

    return $category;
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

sub update_userdefined_column3 {

    my $self    = shift;
    my $i       = { @_ };

    # Update the database with the new updated "Record" hash

    $SQL_update_userdefined_column3->execute(
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

sub import_product_image {

    my $self        = shift;
    my $p           = { @_ };

    # Get the image name using the Image Handler callback;

    my $image = $self->{ ImageName_Handler  }->( %$p );

    # Check configured Image directory exists and create it if required

    unless ( -d $self->{ PM_ImageDirectory } ) {
        system( "mkdir \"$self->{ ImageDirectory }\"" );
        $msg = "Created Image Directory ".$self->{ PM_ImageDirectory };
        $self->update_log( $msg, DEBUG );
    }
    else {
        $msg = "Image Directory ".$self->{ PM_ImageDirectory }." already exists";
        $self->update_log( $msg, DEBUG );
    }

    # Extract Image sub directory from name and create it if required
    
    $image =~ m/(^.*)(\\)/;

    unless ( -d $1 ) {
        system( "mkdir \"$1\"" );
        $msg = "Created Image Sub-Directory ".$1;
        $self->update_log( $msg, DEBUG );
    }
    else {
        $msg = "Image Sub Directory ".$1." already exists";
        $self->update_log( $msg, DEBUG );
    }

    $self->import_picture(
        URL         =>  $self->{ ImageURL_Handler   }->( %$p )  ,
        FileName    =>  $image                                  ,
    );

    $self->add_auction_image( %$p );
}

sub add_auction_image {

    my $self        = shift;
    my $p           = { @_ };

    # Check if the picture is in the picture table and add it if not found

    my $pickey = $self->get_picture_key( $self->{ ImageName_Handler  }->( %$p ) );        

    unless ( $pickey ) {
        $pickey = $self->add_picture_record( PictureFileName => $self->{ ImageName_Handler  }->( %$p ) );
    }

    $self->add_auction_images_record(
        AuctionKey      =>   $p->{ AuctionKey } ,        
        PictureKey      =>   $pickey            ,          
        ImageSequence   =>   1                  ,           
    );
}

#=============================================================================================
# Method    : get_product_record
# Added     : 27/03/05
# Input     : AuctionKey
# Returns   : Hash Reference
#
# This method returns the details for a specific auction record key in a referenced hash
#=============================================================================================

sub get_product_record {

    my $self    = shift;
    my $i       = { @_ };
    my $record;

    $SQL_get_product_record->execute( $i->{ ProductCode } );

    $record = $SQL_get_product_record->fetchrow_hashref;

    # If the record was found return the details otherwise populate the error structure

    if ( defined ( $record) ) {    
        return $record;
    } 
    else {
        return undef;
    }
}

sub delete_product_records {

    my $self    = shift;

    $msg = "Delete all records from Products table";
    $self->update_log( $msg, INFO );

    $SQL_delete_product_records->execute( ) || die "SQL in ".(caller(0))[3]." failed:\n $DBI::errstr\n";

    $SQL_delete_product_records->finish();

    $msg = "Finish SQL Statment - SQL_delete_product_records";
    $self->update_log( $msg, INFO );
}

sub exists_product_record {

    my $self    = shift;
    my $product = shift;

    $SQL_exists_product_record->execute( $product ) || die "SQL in ".(caller(0))[3]." failed:\n $DBI::errstr\n";
    
    my $found = $SQL_exists_product_record->fetchrow_array;

    return $found;  
}

sub is_excluded_product {

    my $self    = shift;
    my $product = shift;

    $SQL_is_excluded_product->execute( $product ) || die "SQL in ".(caller(0))[3]." failed:\n $DBI::errstr\n";
    
    my $found = $SQL_is_excluded_product->fetchrow_array;

    return $found;  
}

sub set_update_timestamp {

    my $self    = shift;
    my $i       = { @_ };

    $SQL_set_update_timestamp->execute(
        "$i->{ Datestamp    }", 
        "$i->{ ProductCode  }"
    ) || die "SQL in ".(caller(0))[3]." failed:\n $DBI::errstr\n";
}

#=============================================================================================
# Method    : add_product_record
#             Add a Product Record to the database 
#=============================================================================================

sub add_product_record {

    my $self    = shift;
    my $i       = { @_ };
    my $r;

    # Set default values for new record
    # Key value AuctionKey is defined as Autonumber and will be generated by the database
    
    $r->{ Title                }   = ""            ;               
    $r->{ Subtitle             }   = ""            ;               
    $r->{ Description          }   = ""            ;               
    $r->{ ProductType          }   = ""            ;               
    $r->{ ProductCode          }   = ""            ;               
    $r->{ ProductCode2         }   = ""            ;               
    $r->{ SupplierRef          }   = ""            ;               
    $r->{ LoadSequence         }   = 0             ;                
    $r->{ Held                 }   = 0             ;                
    $r->{ AuctionCycle         }   = ""            ;               
    $r->{ AuctionStatus        }   = ""            ;               
    $r->{ RelistStatus         }   = 0             ;               
    $r->{ AuctionSold          }   = 0             ;               
    $r->{ StockOnHand          }   = 0             ;                
    $r->{ RelistCount          }   = 0             ;                
    $r->{ NotifyWatchers       }   = 0             ;                
    $r->{ UseTemplate          }   = 0             ;                
    $r->{ TemplateKey          }   = 0             ;                
    $r->{ AuctionRef           }   = ""            ;               
    $r->{ SellerRef            }   = ""            ;               
    $r->{ DateLoaded           }   = "01/01/2000"  ;     
    $r->{ CloseDate            }   = "01/01/2000"  ;     
    $r->{ CloseTime            }   = "00:00:01"    ;       
    $r->{ Category             }   = ""            ;               
    $r->{ MovieRating          }   = 0             ;                
    $r->{ MovieConfirm         }   = 0             ;                
    $r->{ AttributeCategory    }   = 0             ;               
    $r->{ AttributeName        }   = ""            ;               
    $r->{ AttributeValue       }   = ""            ;               
    $r->{ TMATT038             }   = ""            ;               
    $r->{ TMATT104             }   = ""            ;               
    $r->{ TMATT104_2           }   = ""            ;               
    $r->{ TMATT106             }   = ""            ;               
    $r->{ TMATT106_2           }   = ""            ;               
    $r->{ TMATT108             }   = ""            ;               
    $r->{ TMATT108_2           }   = ""            ;               
    $r->{ TMATT111             }   = ""            ;               
    $r->{ TMATT112             }   = ""            ;               
    $r->{ TMATT115             }   = ""            ;               
    $r->{ TMATT117             }   = ""            ;               
    $r->{ TMATT118             }   = ""            ;               
    $r->{ TMATT163             }   = ""            ;               
    $r->{ TMATT164             }   = ""            ;               
    $r->{ IsNew                }   = 0             ;                
    $r->{ TMBuyerEmail         }   = 0             ;                
    $r->{ StartPrice           }   = 0             ;                
    $r->{ ReservePrice         }   = 0             ;                
    $r->{ BuyNowPrice          }   = 0             ;                
    $r->{ EndType              }   = ""            ;                
    $r->{ DurationHours        }   = 0             ;                
    $r->{ EndDays              }   = 0             ;                
    $r->{ EndTime              }   = 0             ;                
    $r->{ ClosedAuction        }   = 0             ;                
    $r->{ BankDeposit          }   = 0             ;                
    $r->{ CreditCard           }   = 0             ;                
    $r->{ CashOnPickup         }   = 0             ;                
    $r->{ EFTPOS               }   = 0             ;                
    $r->{ AgreePayMethod       }   = 0             ;                
    $r->{ SafeTrader           }   = 0             ;                
    $r->{ PaymentInfo          }   = ""            ;               
    $r->{ FreeShippingNZ       }   = 0             ;                
    $r->{ ShippingInfo         }   = ""            ;               
    $r->{ PickupOption         }   = 0             ;                
    $r->{ ShippingOption       }   = 0             ;                
    $r->{ Featured             }   = 0             ;                
    $r->{ Gallery              }   = 0             ;                
    $r->{ BoldTitle            }   = 0             ;                
    $r->{ FeatureCombo         }   = 0             ;                
    $r->{ HomePage             }   = 0             ;                
    $r->{ CopyCount            }   = 1             ;                
    $r->{ Message              }   = ""            ;               
    $r->{ PictureKey1          }   = 0             ;                
    $r->{ PictureKey2          }   = 0             ;                
    $r->{ PictureKey3          }   = 0             ;                
    $r->{ AuctionSite          }   = ""            ;               
    $r->{ UserDefined01        }   = ""            ;               
    $r->{ UserDefined02        }   = ""            ;               
    $r->{ UserDefined03        }   = ""            ;               
    $r->{ UserDefined04        }   = ""            ;               
    $r->{ UserDefined05        }   = ""            ;               
    $r->{ UserDefined06        }   = ""            ;               
    $r->{ UserDefined07        }   = ""            ;               
    $r->{ UserDefined08        }   = ""            ;               
    $r->{ UserDefined09        }   = ""            ;               
    $r->{ UserDefined10        }   = ""            ;               
    $r->{ UserStatus           }   = ""            ;               
    $r->{ UserNotes            }   = ""            ;               
    $r->{ OfferPrice           }   = 0             ;               
    $r->{ OfferProcessed       }   = 0             ;               
    $r->{ SaleType             }   = ""            ;               

    # Read through the input values and alter the corresponding fields in the "Record" hash

    while ( ( my $key, my $value ) = each( %{ $i } ) ) {
        $r->{ $key } = $value;
    }

    $SQL_add_product_record->execute(                                     
                   "$r->{ Title                }", 
                   "$r->{ Subtitle             }", 
                   "$r->{ Description          }",
                   "$r->{ ProductType          }",
                   "$r->{ ProductCode          }",
                   "$r->{ ProductCode2         }",
                   "$r->{ SupplierRef          }",
                    $r->{ LoadSequence         }, 
                    $r->{ Held                 }, 
                   "$r->{ AuctionCycle         }",  
                   "$r->{ AuctionStatus        }",  
                    $r->{ RelistStatus         },  
                    $r->{ AuctionSold          },  
                    $r->{ StockOnHand          },  
                    $r->{ RelistCount          },  
                    $r->{ NotifyWatchers       },  
                    $r->{ UseTemplate          },  
                    $r->{ TemplateKey          },  
                   "$r->{ AuctionRef           }",
                   "$r->{ SellerRef            }",
                   "$r->{ DateLoaded           }",
                   "$r->{ CloseDate            }",
                   "$r->{ CloseTime            }",
                   "$r->{ Category             }",     
                    $r->{ MovieRating          },    
                    $r->{ MovieConfirm         },    
                    $r->{ AttributeCategory    },    
                   "$r->{ AttributeName        }",    
                   "$r->{ AttributeValue       }",    
                   "$r->{ TMATT038             }",    
                   "$r->{ TMATT104             }",    
                   "$r->{ TMATT104_2           }",    
                   "$r->{ TMATT106             }",    
                   "$r->{ TMATT106_2           }",    
                   "$r->{ TMATT108             }",    
                   "$r->{ TMATT108_2           }",    
                   "$r->{ TMATT111             }",    
                   "$r->{ TMATT112             }",    
                   "$r->{ TMATT115             }",    
                   "$r->{ TMATT117             }",    
                   "$r->{ TMATT118             }",    
                   "$r->{ TMATT163             }",    
                   "$r->{ TMATT164             }",    
                    $r->{ IsNew                },    
                    $r->{ TMBuyerEmail         },    
                    $r->{ StartPrice           },    
                    $r->{ ReservePrice         },      
                    $r->{ BuyNowPrice          },    
                   "$r->{ EndType              }",    
                    $r->{ DurationHours        },    
                    $r->{ EndDays              },    
                    $r->{ EndTime              },    
                    $r->{ ClosedAuction        },    
                    $r->{ BankDeposit          },    
                    $r->{ CreditCard           },    
                    $r->{ CashOnPickup         },    
                    $r->{ EFTPOS               },    
                    $r->{ AgreePayMethod       },    
                    $r->{ SafeTrader           },    
                   "$r->{ PaymentInfo          }",    
                    $r->{ FreeShippingNZ       },    
                   "$r->{ ShippingInfo         }",    
                    $r->{ PickupOption         },    
                    $r->{ ShippingOption       },    
                    $r->{ Featured             },    
                    $r->{ Gallery              },    
                    $r->{ BoldTitle            },    
                    $r->{ FeatureCombo         },    
                    $r->{ HomePage             },    
                    $r->{ CopyCount            },    
                   "$r->{ Message              }",    
                    $r->{ PictureKey1          },    
                    $r->{ PictureKey2          },    
                    $r->{ PictureKey3          },    
                   "$r->{ AuctionSite          }",
                   "$r->{ UserDefined01        }",
                   "$r->{ UserDefined02        }",
                   "$r->{ UserDefined03        }",
                   "$r->{ UserDefined04        }",
                   "$r->{ UserDefined05        }",
                   "$r->{ UserDefined06        }",
                   "$r->{ UserDefined07        }",
                   "$r->{ UserDefined08        }",
                   "$r->{ UserDefined09        }",
                   "$r->{ UserDefined10        }",
                   "$r->{ UserStatus           }",
                   "$r->{ UserNotes            }",
                    $r->{ OfferPrice           },
                    $r->{ OfferProcessed       },
                   "$r->{ SaleType             }")

                    || die "add_product_record - Error executing statement: $DBI::errstr\n";
                    
}

#=============================================================================================
# Method    : update_product_record    
#             Add a Product Record to the databaSe 
#=============================================================================================

sub update_product_record {

    my $self    = shift;
    my $i       = { @_ };
    my $r;

    # Retrieve the current record from the database and update "Record" data-Hash

    $SQL_get_product_record->execute( $i->{ ProductCode } );

    $r = $SQL_get_product_record->fetchrow_hashref;

    # Read through the input record and alter the corresponding field in the "Record" hash

    while (  (my $key, my $value ) = each( %{ $i } ) ) {
        $r->{ $key } = $value;
    }
    
    $SQL_update_product_record->execute(
       "$r->{ Title                }",           
       "$r->{ Subtitle             }",           
       "$r->{ Description          }",          
       "$r->{ ProductType          }",          
       "$r->{ ProductCode          }",          
       "$r->{ ProductCode2         }",          
       "$r->{ SupplierRef          }",          
        $r->{ LoadSequence         },
        $r->{ Held                 },
       "$r->{ AuctionCycle         }",            
       "$r->{ AuctionStatus        }",            
        $r->{ RelistStatus         },            
        $r->{ AuctionSold          },            
        $r->{ StockOnHand          },            
        $r->{ RelistCount          },            
        $r->{ NotifyWatchers       },            
        $r->{ UseTemplate          },            
        $r->{ TemplateKey          },            
       "$r->{ AuctionRef           }",
       "$r->{ SellerRef            }",
       "$r->{ DateLoaded           }",
       "$r->{ CloseDate            }",
       "$r->{ CloseTime            }",
       "$r->{ Category             }",               
        $r->{ MovieRating          },              
        $r->{ MovieConfirm         },              
        $r->{ AttributeCategory    },              
       "$r->{ AttributeName        }",              
       "$r->{ AttributeValue       }",              
       "$r->{ TMATT038             }",              
       "$r->{ TMATT104             }",              
       "$r->{ TMATT104_2           }",              
       "$r->{ TMATT106             }",              
       "$r->{ TMATT106_2           }",              
       "$r->{ TMATT108             }",              
       "$r->{ TMATT108_2           }",              
       "$r->{ TMATT111             }",              
       "$r->{ TMATT112             }",              
       "$r->{ TMATT115             }",              
       "$r->{ TMATT117             }",              
       "$r->{ TMATT118             }",              
       "$r->{ TMATT163             }",              
       "$r->{ TMATT164             }",              
        $r->{ IsNew                },              
        $r->{ TMBuyerEmail         },              
        $r->{ StartPrice           },              
        $r->{ ReservePrice         },                
        $r->{ BuyNowPrice          },              
       "$r->{ EndType              }",              
        $r->{ DurationHours        },              
        $r->{ EndDays              },              
        $r->{ EndTime              },              
        $r->{ ClosedAuction        },              
        $r->{ BankDeposit          },              
        $r->{ CreditCard           },              
        $r->{ CashOnPickup         },              
        $r->{ EFTPOS               },              
        $r->{ AgreePayMethod       },              
        $r->{ SafeTrader           },              
       "$r->{ PaymentInfo          }",              
        $r->{ FreeShippingNZ       },              
       "$r->{ ShippingInfo         }",              
        $r->{ PickupOption         },              
        $r->{ ShippingOption       },              
        $r->{ Featured             },              
        $r->{ Gallery              },              
        $r->{ BoldTitle            },              
        $r->{ FeatureCombo         },              
        $r->{ HomePage             },              
        $r->{ CopyCount            },              
       "$r->{ Message              }",              
        $r->{ PictureKey1          },              
        $r->{ PictureKey2          },              
        $r->{ PictureKey3          },              
       "$r->{ AuctionSite          }",
       "$r->{ UserDefined01        }",
       "$r->{ UserDefined02        }",
       "$r->{ UserDefined03        }",
       "$r->{ UserDefined04        }",
       "$r->{ UserDefined05        }",
       "$r->{ UserDefined06        }",
       "$r->{ UserDefined07        }",
       "$r->{ UserDefined08        }",
       "$r->{ UserDefined09        }",
       "$r->{ UserDefined10        }",
       "$r->{ UserStatus           }",
       "$r->{ UserNotes            }",
        $r->{ OfferPrice           },
        $r->{ OfferProcessed       },
       "$r->{ SaleType             }",
        $r->{ AuctionKey           })     
        || die "update_product_record - Error executing statement: $DBI::errstr\n";
                             
}                            

sub drop_old_products_table {

    my $self    = shift;

    $msg = "DROP table OldProducts";
    $self->update_log( $msg, INFO );

    $SQL_drop_old_products_table->execute() || $self->update_log( "Unable to drop table OLDPRODUCTS: $DBI::errstr" );

    $SQL_drop_old_products_table->finish();

    $msg = "Finish SQL Statment - SQL_drop_old_products_table";
    $self->update_log( $msg, INFO );
}

sub copy_all_product_records {

    my $self    = shift;

    $msg = "Copy all Product records to table OldProducts";
    $self->update_log( $msg, INFO );

    $SQL_copy_all_product_records->execute() || $self->update_log( "Unable to Copy table PRODUCTS: $DBI::errstr" );

    $SQL_copy_all_product_records->finish();

    $msg = "Finish SQL Statment - SQL_copy_all_product_records";
    $self->update_log( $msg, INFO );
}

sub drop_old_auctions_table {

    my $self    = shift;

    $msg = "DROP table OldAuctions";
    $self->update_log( $msg, INFO );

    $SQL_drop_old_auctions_table->execute() || $self->update_log( "Unable to drop table OLDAUCTIONS: $DBI::errstr" );

    $SQL_drop_old_auctions_table->finish();

    $msg = "Finish SQL Statment - SQL_drop_old_auctions_table";
    $self->update_log( $msg, INFO );
}


sub copy_all_auction_records {

    my $self    = shift;

    $msg = "Copy all Auction records to table OldAuctions";
    $self->update_log( $msg, INFO );

    $SQL_copy_all_auction_records->execute() || $self->update_log( "Unable to copy table AUCTIONS: $DBI::errstr" );

    $SQL_copy_all_auction_records->finish();

    $msg = "Finish SQL Statment - SQL_copy_all_auction_records";
    $self->update_log( $msg, INFO );
}


#--------------------------------------------------------------------
# End of 2Sellit product Maintenance module
# Return true value so the module can actually be used
#--------------------------------------------------------------------

1;


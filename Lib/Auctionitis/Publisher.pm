package Auctionitis::Publisher;
use strict;
use Auctionitis;
use XML::Simple;
require Exporter;

our @ISA = qw( Auctionitis Exporter );

our @EXPORT = qw(
    SITE_TRADEME SITE_SELLA SITE_TANDE SITE_ZILLION
    INFO DEBUG VERBOSE
);

#=============================================================================================
# Properties for object
#=============================================================================================

our $FatalCount;                            # Count of Fatal Errors
our $WarningCount;                          # Count of Warnings
our $MessageCount;                          # Count of Messages
our $ErrorStatus;                           # Error Status
our $MessageData;                           # Error Messages 
our @Messages;                              # Error Messages
our $Version = "1.0";                       # Version number
our $Product = "Auctionitis Publisher";     # Product Name

# Globals

our %i;                                     # input data hash
our $msg;                                   # Variable for message data
our $errorflag;                             # Error flag
our $tm;                                    # TradeMe object

# Counter variables
    
our $DOcount;                               # Delivery options Count
our $Pcount;                                # Paragraph Count
our $Wcount;                                # Warning Count
our $Fcount;                                # Fatal Count
our $Icount;                                # Picture Count

#=============================================================================================
# --- Exported Methods/Subroutines ---
#=============================================================================================

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

    sysopen( CONFIG, "Config.xml", O_RDONLY) or die "Cannot open Config.xml $!";

    while  (<CONFIG>) {
        chomp;                       # no newline
        s/#.*//;                     # no comments
        s/^\s+//;                    # no leading white
        s/\s+$//;                    # no trailing white
        next unless length;          # anything left ?
        my ($ parm, $value ) = split( /\s*=\s*/, $_, 2 );
    
        # Set the property from the config file unless it was passed in with the constructor method
    
        $self->{ 'PB_'.$parm } = $value unless $self->{ 'PB_'.$parm };
    }

    # Parse the returned XML

    my $xs = XML::Simple->new( SuppressEmpty => 'undef' );
    my $config = $xs->XMLin( $data );

    # Create the Trademe object
    
    $tm = Auctionitis->new();
    $tm->initialise(Product => "Auctionitis");  # Initialise the product

    # Set the Debug Level based on the passed in parameter

    if ( defined $DebugLevel ) { 

        if ( $DebugLevel =~ m/[012]/ ) {
            $tm->{ Debug } = $DebugLevel;
        }
        else {
            $msg = "Invalid debug level specified [ ".$DebugLevel." ]. Parameter ignored.";
            UpdateMessageStack( $msg, "WARNING" );
        }
    }
    else {
        $DebugLevel = 0;
    }

    # Print the Auctionitis debug flag status
    
    $msg = "Debug Level is [ ".$tm->{ Debug }." ].";
    UpdateMessageStack( $msg, "DEBUG" );

    # Initialize the Error flag to off

    $errorflag = 0;

    # create test connection to Test existence of input ODBC name

    # If no database specified get the connection from the Auctionitis properties

    if ( ( not defined $DSN ) or ( $DSN eq "" ) ) { 

        if ( defined ( $tm->{ DataBaseName } ) ) {
    
            $DSN = $tm->{ DataBaseName }; 
            $msg = "No Database Name supplied. Default Database [ ".$DSN." ] will be used";
            UpdateMessageStack( $msg, "WARNING" );
        }
    }

    # If still not defined set error flags & exit

    if ( ( not defined $DSN ) or ( $DSN eq "" ) ) { 

        $msg = "Unable to determine Database ODBC Name. Processing terminated.";
        UpdateMessageStack( $msg, "FATAL" );

        UpdateAPIProperties();
        return $errorflag;
    }

    my $dsnerror = 0;
    my $dbhtest;

    eval { $dbhtest = DBI->connect( 'dbi:ODBC:'.$DSN ) || die $dsnerror = 1; };
    
    if ( $dsnerror ) {

        $msg = "Database ODBC Name [ ".$DSN." ] is not valid. Processing terminated.";
        UpdateMessageStack( $msg, "FATAL" );

        # Store Additional debug data

        $@ =~ s/at \/.*?$//s;       # remove module line number

        $msg = "Error Data:\n$@\n\n";
        UpdateMessageStack( $msg, "DEBUG" );

        $msg = "ODBC Name:\n$DSN\n\n";
        UpdateMessageStack( $msg, "DEBUG" );

        UpdateAPIProperties();
        return $errorflag;
    }
    else {

        $dbhtest->disconnect;   # Disconnect from test connection

        $msg = "Database $DSN found - connecting to database";
        UpdateMessageStack( $msg, "DEBUG" );
    }

    # IF DSN name validated connect to the database

    $tm->DBconnect( $DSN );                        # Connect to the database
    
    UpdateAPIProperties();
    return $errorflag;
}

#---------------------------------------------------------------------------------------------
# Method: InsertAuctionRecord
#
# Creates Creates a new Auction Record
#
# Parameters: XML String
#---------------------------------------------------------------------------------------------

sub InsertAuctionRecord {

    my $InputData   = shift;

    my $success  = PutAuctionRecord( $InputData, "UPDATE" );

    UpdateAPIProperties();

    return $success;
}

#---------------------------------------------------------------------------------------------
# Method: VerifyAuctionRecord
#
# Validates the input data without doing an inert
#
# Parameters: XML String
#---------------------------------------------------------------------------------------------

sub ValidateAuctionRecord {

    my $InputData   = shift;

    my $success  = PutAuctionRecord( $InputData, "NOUPDATE" );

    UpdateAPIProperties();

    return $success;
}

#---------------------------------------------------------------------------------------------
# Method: PutAuctionRecord
#
# Creates Creates a new Auction Record
#
# Parameters: XML String
#---------------------------------------------------------------------------------------------

sub PutAuctionRecord {

    my $InputData   = shift;
    my $Action      = shift;
    
    # Hashes for checking/holding data
    
    my %r;              # record hash
    my %n;              # input node name hash
    my %v;              # valid node name hash
    my %m;              # required node name hash
    my %y;              # yes/no fields hash
    my %c;              # currency fields hash
    my %a;              # alphanumeric/text fields hash
    my %w;              # integer/whole number fields hash
    
    # Custom delivery options array (array of anonymous hashes)
    
    my @shipopt;
    
    # Array to hold picture names
    
    my @pics;

    # Counter variables
    
    $DOcount = 0;       # Delivery options Count
    $Pcount  = 0;       # Paragraph Count
    $Wcount  = 0;       # Warning Count
    $Fcount  = 0;       # Fatal Count
    $Icount  = 0;       # Picture Count
                         
    # other variables
    
    my $t;              # tag name for current test
    
    #------------------------------------------------------------------------------
    # Validation control hashes
    #------------------------------------------------------------------------------
    
    # populate the valid tag names hash
    
    $v{ AttributeCategory    } = "1"; 
    $v{ AttributeName        } = "1";
    $v{ AttributeValue       } = "1";
    $v{ AuctionRecord        } = "1";
    $v{ BankDeposit          } = "1";
    $v{ BoldTitle            } = "1";
    $v{ BuyNowPrice          } = "1";
    $v{ CashOnPickup         } = "1";
    $v{ Category             } = "1";
    $v{ ClosedAuction        } = "1";
    $v{ CreditCard           } = "1";
    $v{ ShippingOptions       } = "1";
    $v{ Description          } = "1";
    $v{ DurationHours        } = "1";
    $v{ EndDays              } = "1";
    $v{ EndTime              } = "1";
    $v{ EndType              } = "1";
    $v{ FeatureCombo         } = "1";
    $v{ Featured             } = "1";
    $v{ Gallery              } = "1";
    $v{ HomePage             } = "1";
    $v{ IsNew                } = "1";
    $v{ MovieConfirm         } = "1";
    $v{ MovieRating          } = "1";
    $v{ NotifyWatchers       } = "1";
    $v{ Paragraph            } = "1";
    $v{ Paymate              } = "1";
    $v{ PaymentInfo          } = "1";
    $v{ PickupOption         } = "1";
    $v{ Pictures             } = "1";
    $v{ PictureFile          } = "1";
    $v{ ProductCode          } = "1";
    $v{ ProductCode2         } = "1";
    $v{ ProductType          } = "1";
    $v{ ReservePrice         } = "1";
    $v{ SafeTrader           } = "1";
    $v{ SellerRef            } = "1";
    $v{ ShippingCost         } = "1";
    $v{ ShippingDetails      } = "1";
    $v{ ShippingOption       } = "1";
    $v{ ShippingText         } = "1";
    $v{ StartPrice           } = "1";
    $v{ Subtitle             } = "1";
    $v{ SupplierRef          } = "1";
    $v{ Title                } = "1";
    $v{ TMATT104             } = "1";
    $v{ TMATT104_2           } = "1";
    $v{ TMATT106             } = "1";
    $v{ TMATT106_2           } = "1";
    $v{ TMATT108             } = "1";
    $v{ TMATT108_2           } = "1";
    $v{ TMATT111             } = "1";
    $v{ TMATT112             } = "1";
    $v{ TMATT115             } = "1";
    $v{ TMATT117             } = "1";
    $v{ TMATT118             } = "1";
    $v{ TMBuyerEmail         } = "1";
    
    # populate the required tag names hash
    
    $m{ AuctionRecord        } = "1";
    $m{ AttributeCategory    } = "1";
    $m{ Category             } = "1";
    $m{ Description          } = "1";
    $m{ Paragraph            } = "1";
    $m{ PickupOption         } = "1";
    $m{ ShippingOption       } = "1";
    $m{ StartPrice           } = "1";
    $m{ Title                } = "1";
    
    # populate the yes/no tag names hash
    
    $y{ BankDeposit          } = "1"; 
    $y{ CashOnPickup         } = "1";
    $y{ CreditCard           } = "1"; 
    $y{ BoldTitle            } = "1";
    $y{ ClosedAuction        } = "1";
    $y{ FeatureCombo         } = "1";
    $y{ Featured             } = "1";
    $y{ Gallery              } = "1";
    $y{ HomePage             } = "1";
    $y{ IsNew                } = "1";
    $y{ SafeTrader           } = "1";
    
    # Decimal/Currency tag names
    
    $c{ BuyNowPrice          } = "1";
    $c{ ReservePrice         } = "1";
    $c{ StartPrice           } = "1";
    $c{ ShippingCost         } = "1";
    
    # Integer tag names
    
    $w{ AttributeCategory    } = "1"; 
    $w{ DurationHours        } = "1";
    $w{ EndDays              } = "1";
    $w{ EndTime              } = "1";
    
    # populate the alphanumeric/Text names hash and length values
    
    $a{ AttributeName       } = "20";
    $a{ AttributeValue      } = "20";
    $a{ Description         } = "2018";
    $a{ PaymentInfo         } = "70";
    $a{ ImageName           } = "128";
    $a{ ShippingText        } = "50";
    $a{ Subtitle            } = "50";
    $a{ TMATT104            } = "5";
    $a{ TMATT104_2          } = "5";
    $a{ TMATT106            } = "5";
    $a{ TMATT106_2          } = "5";
    $a{ TMATT108            } = "5";
    $a{ TMATT108_2          } = "5";
    $a{ TMATT111            } = "25";
    $a{ TMATT112            } = "25";
    $a{ TMATT115            } = "5";
    $a{ TMATT117            } = "5";
    $a{ TMATT118            } = "5";
    $a{ Title               } = "50";
    
    #------------------------------------------------------------------------------
    # Document Validation
    #------------------------------------------------------------------------------
    
    # Validate that the input is a valid XML construct
    
    my $parser = XML::Parser->new( ErrorContext => 2 );
    
    eval { $parser->parse( $InputData ); };
    
    if ( $@ ) {
    
        $msg = "XML Input is not valid. Processing terminated.";
        UpdateMessageStack( $msg, "FATAL" );

        # Store Additional debug data

        $@ =~ s/at \/.*?$//s;       # remove module line number

        $msg = "Error Data:\n$@\n\n";
        UpdateMessageStack( $msg, "DEBUG" );

        $msg = "Input Data:\n$InputData\n\n";
        UpdateMessageStack( $msg, "DEBUG" );

        $FatalCount     = $Fcount;
        $WarningCount   = $Wcount;
        $AuctionKey     = 0;
        $ErrorStatus    = $errorflag;
        $MessageCount   = scalar( @Messages );
        $MessageData    = \@Messages;

        return $errorflag;
    
    }
    else {
        $msg = "XML Input is well-formed";
        UpdateMessageStack( $msg, "DEBUG" );
    }
    
    #------------------------------------------------------------------------------
    # Input Field Validation 
    #------------------------------------------------------------------------------

    # Strip out any newlines from the input string

    $msg = "Removing new line characters from input data.";
    UpdateMessageStack( $msg, "DEBUG" );

    $InputData =~ tr/\n//d;

    # Make a copy of the input data for searching

    my $data = $InputData;

    # Create a hash of all the input tags that contain values
    
    while ( $InputData =~ m/(<)(.+?)(>)/g ) {
    
        my $m = $2;
    
        # If node is a start tag add the tag name to the input node name hash
        # Then search the input with closing tag to extract the accompanying data
        # 
        # Add Subroutine handlers or calls here for tags with nested data
        #
        
        if ( not $m =~ m/\// ) {       
        
            my $tag = $m;
            $n{ $tag } = "1";

            $msg = "Identified Opening Tag: $m";
            UpdateMessageStack( $msg, "DEBUG" );
   
            if ( $data =~ m/(<$tag>)(.+?)(<\/$tag>)/ ) {
                $i{ $tag } = $2;
            }
    
            #
            # Processing for Auction Description embedded Paragraph data
            # 
    
            # Clear the description field when start Description tag encountered
    
            if ( $tag eq "Description" ) {
    
                my $text = $i{ Description };
                $i{ Description } = "";
    
                # Read all the paragraphs from the input data and insert into description
    
                while ( $text =~ m/(<Paragraph>)(.*?)(<\/Paragraph>)/g ) {
                    $i{ Description } .= $2."\n";
                    $Pcount++;
                }
    
                # Convert newlines to memo eol value in database 
    
                $i{ Description } =~ s/\n/\x0D\x0A/g;           # change newlines to mem cr/lf combo   
            }
    
            #
            # Processing for Picture Tags
            # 
    
            if ( $tag eq "Pictures" ) {
    
                # Count the number of picture File tags in the Pictures Node
    
                while ( $i{ Pictures } =~ m/(<PictureFile>)(.*?)(<\/PictureFile>)/g ) {
                    $Icount++;
    
                    # if the pic name is too long record a fatal error (truncated name is  no good) else push it onto the pic array
    
                    if ( length ( $2 ) > $a{ PictureFile } ) {
                        $msg = "Fatal: Filename [ ".$2." ] supplied for <PictureFile> longer than allowed length of ".$a{ PictureFile }.".";
                        UpdateMessageStack( $msg, "FATAL" );
                    }
                    else {
                        push ( @pics, $2 );
                    }
                }
    
                if ( $Icount eq 0 ) {
                    $msg = "Required tag <PictureFile> not found in <Pictures> Node";
                    UpdateMessageStack( $msg, "FATAL" );
                }
            }
    
            if ( $Icount gt 3) {
                $msg = "Number of Picture Files specified [ ".$Icount." ] greater than allowable maximum of 3.";
                UpdateMessageStack( $msg, "FATAL" );
            }
        }
    
        # If node is a not a start tag see if it is an empty tag ( <Tagname /> )
        # if it is an empty Node name adde it to the input node name hash
        
        elsif ( $m =~ m/(.+?)(\s+?\/)/ ) {
    
            my $tag = $1;
            $n{ $tag } = "1";
    
            if ( $tag eq "Paragraph" ) {
                $i{ Description } .= "\n";
            }
            
            $msg = "Identified Empty Tag: $m";
            UpdateMessageStack( $msg, "DEBUG" );
        }
    
        # If node is a not a start tage and is not empty, verify that it is an end tag
        
        elsif ( $m =~ m/(\/)(.+)/ ) {
    
            my $tag = $2;
            $msg = "Identified End Tag: $m";
            UpdateMessageStack( $msg, "DEBUG" );
        }
        
        else {
        
            $msg = "Unable to identify Tag: $m";
            UpdateMessageStack( $msg, "DEBUG" );
        }
    }
    
    # Check all required tags found in input list & have associated data
    
    foreach my $key ( sort keys %m ) {
        if (not exists( $n{ $key } ) ) {
            $msg = "Required tag <".$key."> missing from input.";
            UpdateMessageStack( $msg, "FATAL" );
        }
        if ( ( exists( $n{ $key } ) ) and ( not defined $i{ $key } ) ) {
            $msg = "Required tag <".$key."> has no associated data.";
            UpdateMessageStack( $msg, "FATAL" );
        }
    }
    
    # Identify tags which have associated data 
    
    foreach my $key ( sort keys %n ) {
        if ( exists( $i{ $key } ) ) {
            $msg = "Tag <".$key."> has associated data";
            UpdateMessageStack( $msg, "DEBUG" );
        }
        else {
            $msg = "Tag <".$key."> is empty. Default value for tag will be used";
            UpdateMessageStack( $msg, "WARNING" );
        }
    }
    
    # Check for unknown tags in input and verify known tags
    
    foreach my $key ( sort keys %n ) {
        if (not exists( $v{ $key } ) ) {
            $msg = "Tag <".$key."> is unknown. Tag and associated value will be ignored ";
            UpdateMessageStack( $msg, "WARNING" );
        }
        else {
            $msg = "Valid Tag found [ ".$key." ].Tag and associated value will be processed";
            UpdateMessageStack( $msg, "DEBUG" );
        }    
    }
    
    #------------------------------------------------------------------------------
    # Data Type and field length validation checks
    #------------------------------------------------------------------------------
    
    # True/false fields
    
    foreach my $key ( keys %y ) {
        if ( exists ( $i{ $key } ) ) {
            if ( not ( $i{ $key } =~ m/TRUE|FALSE|NO|YES/i ) ) {
                 $msg = "Invalid value [ ".$i{ $key }." ] for tag <".$key.">. Input value must be YES, NO, TRUE OR FALSE";
                 UpdateMessageStack( $msg, "FATAL" );
            }
            else {
                if ( ( $i{ $key } =~ m/TRUE|YES/i ) ) {
                    $i{ $key } = -1;
                }
                else {
                    $i{ $key } = 0;
                }
            }
        }
    }
    
    # Currency fields
    
    foreach my $key ( keys %c ) {
        if ( exists ( $i{ $key } ) ) {
            if ( not ( $i{ $key } =~ m/[0-9\.*]/ ) ) {
                $msg = "Invalid value [ ".$i{ $key }." ] for tag <".$key.">. Input value must be of type Currency";
                UpdateMessageStack( $msg, "FATAL" );
            }
        }
    }
    
    # Integer fields
    
    foreach my $key ( keys %w ) {
        if ( exists ( $i{ $key } ) ) {
            if ( not ( $i{ $key } =~ m/[0-9*]/ ) ) {
                $msg = "Invalid value [ ".$i{ $key }." ] for tag <".$key.">. Input value must be of type Numeric";
                UpdateMessageStack( $msg, "FATAL" );
            }
        }
    }
    
    # Field length of character fields
    
    foreach my $key ( keys %a ) {
        if ( exists ( $i{ $key } ) ) {
            if ( length ( $i{ $key } ) > $a{ $key } ) {
                $msg = "Value supplied for tag <".$key."> longer than allowed length of ".$a{ $key }.". Input will be truncated";
                UpdateMessageStack( $msg, "WARNING" );

                # Store additional debug data

                $msg = "   Old: [ ".$i{ $key }." ]";
                push ( @Messages, $msg );
                UpdateMessageStack( $msg, "DEBUG" );
                
                $i{ $key } = substr( $i{ $key }, 0, $a{ $key } );
                
                $msg = "   New: [ ".$i{ $key }." ]";
                push ( @Messages, $msg );
                UpdateMessageStack( $msg, "DEBUG" );
            }
        }
    }
    
    #------------------------------------------------------------------------------
    # Field Content validation checks
    # Converts to value to be stored in database if necessary
    #------------------------------------------------------------------------------
    
    # Duration End Type
    
    $t = "EndType";
    
    if ( $i{ $t } =~ m/FIXEDEND|DURATION/i ) {
        $i{ $t } = uc( $i{ $t } )
    }
    else {
        $msg = "Invalid value [ ".$i{ $t }." ] for tag <".$t.">. Input value must be FIXEDEND or DURATION";
        UpdateMessageStack( $msg, "FATAL" );
    }
    
    # Auction Duration
    
    if ( $i{ EndType } eq "DURATION" ) {
    
        $t = "DurationHours";
    
        if (not exists( $n{ $t } ) ) {
            $msg = "Tag <".$t."> is a required tag when EndType DURATION is specified.";
            UpdateMessageStack( $msg, "FATAL" );
        }
        if ( ( exists( $n{ $t } ) ) and ( not defined $i{ $t } ) ) {
            $msg = "Tag <".$t."> must contain data when EndType DURATION is specified.";
            UpdateMessageStack( $msg, "FATAL" );
        }

        # Convert API input value to value stored in database

        if    ( $i{ $t } eq 6   )     { $i{ $t } *= 60; } 
        elsif ( $i{ $t } eq 12  )     { $i{ $t } *= 60; } 
        elsif ( $i{ $t } eq 24  )     { $i{ $t } *= 60; } 
        elsif ( $i{ $t } eq 48  )     { $i{ $t } *= 60; } 
        elsif ( $i{ $t } eq 72  )     { $i{ $t } *= 60; } 
        elsif ( $i{ $t } eq 96  )     { $i{ $t } *= 60; } 
        elsif ( $i{ $t } eq 120 )     { $i{ $t } *= 60; } 
        elsif ( $i{ $t } eq 144 )     { $i{ $t } *= 60; } 
        elsif ( $i{ $t } eq 168 )     { $i{ $t } *= 60; } 
        elsif ( $i{ $t } eq 240 )     { $i{ $t } *= 60; } 
        else {
            $msg = "Invalid value [ ".$i{ $t }." ] for tag <".$t.">. Input value must be one of: 6, 12, 24, 48, 72, 96, 120, 144, 168 or 240.";
            UpdateMessageStack( $msg, "FATAL" );
        }
    }
    
    # Scheduled end time
    
    if ( $i{ EndType } eq "FIXEDEND" ) {
    
        $t = "EndDays";
    
        if (not exists( $n{ $t } ) ) {
            $msg = "Tag <".$t."> is a required tag when EndType FIXEDEND is specified.";
            UpdateMessageStack( $msg, "FATAL" );
        }
        if ( ( exists( $n{ $t } ) ) and ( not defined $i{ $t } ) ) {
            $msg = "Tag <".$t."> must contain data when EndType FIXEDEND is specified.";
            UpdateMessageStack( $msg, "FATAL" );
        }
    
        my $testval = int( $i{ $t } );
    
        # Check end days is a whole number between 0 and 10
    
        if    ( ( $i{ $t } lt 0 ) or ( $i{ $t } gt 10 ) or ( $testval != $i{ $t } ) ) { 
            $msg = "Invalid value [ ".$i{ $t }." ] for tag <".$t.">. Input value must a whole number between 0 and 10.";
            UpdateMessageStack( $msg, "FATAL" );
        }
    
        # Check end time is a whole number between 0 and 95
    
        $t = "EndTime";
    
        if (not exists( $n{ $t } ) ) {
            $msg = "Tag <".$t."> is a required tag when EndType FIXEDEND is specified.";
            UpdateMessageStack( $msg, "FATAL" );
        }
        if ( ( exists( $n{ $t } ) ) and ( not defined $i{ $t } ) ) {
            $msg = "Tag <".$t."> must contain data when EndType FIXEDEND is specified.";
            UpdateMessageStack( $msg, "FATAL" );
        }
    
        $testval = int( $i{ $t } );
    
        if    ( ( $i{ $t } lt 0 ) or ( $i{ $t } gt 95 ) or ( $testval != $i{ $t } ) ) { 
            $msg = "Invalid value [ ".$i{ $t }." ] for tag <".$t.">. Input value must a whole number between 0 and 95.";
            UpdateMessageStack( $msg, "FATAL" );
        }
    }
    
    # Relist Status
    
    $t = "RelistStatus";

    if ( exists ( $i{ $t } ) ) {
    
        if    ( uc( $i{ $t } ) eq "NORELIST"   )     { $i{ $t } = 0 ; } 
        elsif ( uc( $i{ $t } ) eq "UNTILSOLD"  )     { $i{ $t } = 1 ; } 
        elsif ( uc( $i{ $t } ) eq "WHILESTOCK" )     { $i{ $t } = 2 ; } 
        elsif ( uc( $i{ $t } ) eq "PERMANENT"  )     { $i{ $t } = 3 ; } 
        else {
            $msg = "Invalid value [ ".$i{ $t }." ] for tag <".$t.">. Input value must be NORELIST, UNTILSOLD, WHILESTOCK or PERMANENT";
            UpdateMessageStack( $msg, "FATAL" );
        }
    }    # Pickup Option
    
    $t = "PickupOption";
    
    if    ( uc( $i{ $t } ) eq "ALLOW"      )     { $i{ $t } = 1 ; } 
    elsif ( uc( $i{ $t } ) eq "DEMAND"     )     { $i{ $t } = 2 ; } 
    elsif ( uc( $i{ $t } ) eq "FORBID"     )     { $i{ $t } = 3 ; } 
    else {
        $msg = "Invalid value [ ".$i{ $t }." ] for tag <".$t.">. Input value must be ALLOW, DEMAND or FORBID";
        UpdateMessageStack( $msg, "FATAL" );
    }
    
    # Shipping Option
    
    $t = "ShippingOption";
    
    if    ( uc( $i{ $t } ) eq "UNDECIDED"  )     { $i{ $t } = 1 ; } 
    elsif ( uc( $i{ $t } ) eq "FREE"       )     { $i{ $t } = 2 ; } 
    elsif ( uc( $i{ $t } ) eq "CUSTOM"     )     { $i{ $t } = 3 ; } 
    else {
        $msg = "Invalid value [ ".$i{ $t }." ] for tag <".$t.">. Input value must be UNDECIDED, FREE, or CUSTOM";
        UpdateMessageStack( $msg, "FATAL" );
    }
    
    # Processing for Custom Shipping Options
    
    if ( $i{ ShippingOption } == 3 ) {
    
        my $text = $i{ ShippingDetails };
    
        while ( $text =~ m/(<ShippingOptions>)(.*?)(<\/ShippingOptions>)/g ) {
    
            my $do = $2;      # Delivery option data (container node)
            my $sc = "";      # Shipping cost
            my $st = "";      # Shipping text

            $DOcount++;
            
            # Extract the Shipping text and Shiping cost from the delivery option data
            
            if ( $do =~ m/(<ShippingCost>)(.*?)(<\/ShippingCost>)/ ) {
                $sc = $2;
            }
            else {
                $msg = "Required tag <ShippingCost> not found in <ShippingOptions> Node.";
                UpdateMessageStack( $msg, "FATAL" );
            }
            
            if ( $do =~ m/(<ShippingText>)(.*?)(<\/ShippingText>)/ ) {
                $st = $2;
            }
            else {
                $msg = "Required tag <ShippingText> not found in <ShippingOptions> Node.";
                UpdateMessageStack( $msg, "FATAL" );
            }
            
            if ( not ( $sc =~ m/[0-9\.*]/ ) ) {
                $msg = "Invalid value [ ".$sc." ] for tag <ShippingCost>. Input value must be of type Currency";
                UpdateMessageStack( $msg, "FATAL" );
            }
            
            if ( length ( $st ) > $a{ ShippingText } ) {
                $msg = "Value supplied for tag <ShippingText> longer than allowed length of ".$a{ ShippingText }.". Input will be truncated";
                UpdateMessageStack( $msg, "WARNING" );

                # Additional debug data

                $msg = "   Old: [ ".$st." ]";
                push ( @Messages, $msg );
                UpdateMessageStack( $msg, "DEBUG" );
                
                $st = substr( $st, 0, $a{ ShippingText } );
                
                $msg = "   New: [ ".$st." ]";
                push ( @Messages, $msg );
                UpdateMessageStack( $msg, "DEBUG" );
            }
    
            push ( @shipopt, { ShippingCost => $sc, ShippingText => $st } );
        }
    
        if ( $DOcount > 10 ) {
            $msg = "Number of Delivery Options specified [ ".$DOcount." ] greater than allowable maximum of 10.";
            UpdateMessageStack( $msg, "FATAL" );
        }
    
        if ( $DOcount == 0 ) {
            $msg = "At least one Delivery Option must be supplied with shipping option CUSTOM.";
            UpdateMessageStack( $msg, "FATAL" );
        }
    
    }
    
    #------------------------------------------------------------------------------
    # Category checks
    #------------------------------------------------------------------------------
    
    # Check category is valid
    
    if ( not $tm->is_valid_category( $i{ Category } ) ) {
        $msg = "Category Input error. Invalid category [ ".$i{ Category }." ].";
        UpdateMessageStack( $msg, "FATAL" );
    }
    
    # Check category value does NOT have any children
    
    if ( $tm->has_children( $i{ Category } ) ) {
        $msg = "Category Input error. Selection not complete for category [ ".$i{ Category }." ].";
        UpdateMessageStack( $msg, "FATAL" );
    }
    
    #------------------------------------------------------------------------------
    # Additional checking for attribute data
    #------------------------------------------------------------------------------
    
    #------------------------------------------------------------------------------
    # Determine whether the category has associated attributes
    # Start with the initial category and test for the attribute category
    # repeat until the test catgory value = 0 or the attribute test is true
    #------------------------------------------------------------------------------

    my $ac = $i{ Category };
    
    $msg = "Checking category [ ".$ac." ] for attribute requirements .";
    UpdateMessageStack( $msg, "DEBUG" );
    
    until ( $tm->has_attributes( $ac ) or $ac eq 0 ) {
       
        $msg = "Retrieve parent category [ ".$tm->get_parent( $ac )." ] for category [ ".$ac." ].";
        UpdateMessageStack( $msg, "DEBUG" );

        $ac = $tm->get_parent( $ac );
    
    }
    
    if ( $ac  ) {
        $msg = "Attribute category [ ".$ac." ] found for base input category [ ".$i{ Category }." ].";
        UpdateMessageStack( $msg, "DEBUG" );
    }
    
    if ( not $ac ) {
        $msg = "No attribute category found for base input category [ ".$i{ Category }." ].";
        UpdateMessageStack( $msg, "DEBUG" );
    }
      
    if ( $ac ne $i{ AttributeCategory } ) {
        $msg = "Attribute Category [ ".$i{ AttributeCategory }." ] not correct for Category [ ".$i{ Category }." ].";
        UpdateMessageStack( $msg, "FATAL" );
    }

    # If there is an attribute category, do the attribute category tests

    if ( $ac ) {
    
        # Attribute combobox processing
    
        if ( $tm->attribute_has_combo( $ac ) ) {
    
            $msg = "Category  [ ".$ac." ] has an associated combo box";
            UpdateMessageStack( $msg, "DEBUG" );
    
            # Check the AttributeField and AttributeValue tags have been included if the category has a combobox
    
            if (not exists( $i{ AttributeName } ) ) {
                $msg = "Tag <AttributeName> is required for Attribute Category [ ".$ac." ].";
                UpdateMessageStack( $msg, "FATAL" );
            }
    
            if (not exists( $i{ AttributeValue } ) ) {
                $msg = "Tag <AttributeValue> is required for Attribute Category [ ".$ac." ].";
                UpdateMessageStack( $msg, "FATAL" );
            }
    
            # Test whether the supplied AttributeName and Attribute Value are valid
    
            my $an = $i{ AttributeName };
            my $av = $i{ AttributeValue };
    
            if ( $tm->is_valid_attribute_value ( $ac, $an, $av ) ) {
    
                $msg = "Attribute Name [ ".$an." ] and Attribute Value [ ".$av. " ] valid for Attribute Category [ ".$ac." ].";
                UpdateMessageStack( $msg, "DEBUG" );
            }
            else {
                $msg = "Attribute Name [ ".$an." ] or Attribute Value [ ".$av. " ] not valid for Attribute Category [ ".$ac." ].";
                UpdateMessageStack( $msg, "FATAL" );
            }
        }
        else {
    
            $msg = "Attribute Category [ ".$ac." ] does not have an associated combo box";
            UpdateMessageStack( $msg, "DEBUG" );
        }
    
        # Attribute custom procedure processing
        # Retrieve the procedure values for the attribute category
    
        my $ap = $tm->get_attribute_procedure( $ac );
    
        if ( $ap  ) {
            $msg = "Attribute Category [ ".$ac." ] has an associated procedure [ ".$ap. " ].";
            UpdateMessageStack( $msg, "DEBUG" );
        }
        else {
            $msg = "Attribute Category [ ".$ac." ] has NO associated procedure.";
            UpdateMessageStack( $msg, "DEBUG" );
        }
    
        if ( $ap eq "EnableDigicams" ) {
    
            # Check required tags have been supplied
    
            Check_AC_Tag( "TMATT117"    , $ac );
            Check_AC_Tag( "TMATT118"    , $ac );
    
            $t = "TMATT117";
    
            if ( exists ( $i{ $t } ) ) {
    
                if ( not ( $i{ $t } =~ m/[0-9\.*]/ ) ) {
                    $msg = "Invalid value [ ".$i{ $t }." ] for tag <".$t.">. Input must be digits and decimal point only.";
                    UpdateMessageStack( $msg, "FATAL" );
                }
    
                if ( length ( $i{ $t } ) gt 4 ) {
                    $msg = "Invalid length [ ".length ( $i{ $t } )." ] for tag <".$t.">. Maximum of 4 characters.";
                    UpdateMessageStack( $msg, "FATAL" );
                }
            }
    
            $t = "TMATT118";
    
            if ( exists ( $i{ $t } ) ) {
    
                if ( not ( $i{ $t } =~ m/[0-9\.*]/ ) ) {
                    $msg = "Invalid value [ ".$i{ $t }." ] for tag <".$t.">. Input must be digits and decimal point only.";
                    UpdateMessageStack( $msg, "FATAL" );
                }
    
                if ( length ( $i{ $t } ) gt 4 ) {
                    $msg = "Invalid length [ ".length ( $i{ $t } )." ] for tag <".$t.">. Maximum of 4 characters.";
                    UpdateMessageStack( $msg, "FATAL" );
                }
            }
        }
        elsif ( $ap eq "EnableMonitors" ) {
    
            # Check required tags have been supplied
            
            Check_AC_Tag( "TMATT115"    , $ac );
            
            $t = "TMATT115";
            
            if ( exists ( $i{ $t } ) ) {
            
                if ( not ( $i{ $t } =~ m/[0-9\.*]/ ) ) {
                    $msg = "Invalid value [ ".$i{ $t }." ] for tag <".$t.">. Input must be digits and decimal point only.";
                    UpdateMessageStack( $msg, "FATAL" );
                }
            
                if ( length ( $i{ $t } ) gt 4 ) {
                    $msg = "Invalid length [ ".length ( $i{ $t } )." ] for tag <".$t.">. Maximum of 4 characters.";
                    UpdateMessageStack( $msg, "FATAL" );
                }
            }
        }
        elsif ( $ap eq "EnableCompSys" ) {
    
            # Check required tags have been supplied
    
            Check_AC_Tag( "TMATT104"    , $ac );
            Check_AC_Tag( "TMATT104_2"  , $ac );
            Check_AC_Tag( "TMATT106"    , $ac );
            Check_AC_Tag( "TMATT106_2"  , $ac );
            Check_AC_Tag( "TMATT108"    , $ac );
            Check_AC_Tag( "TMATT108_2"  , $ac );
            Check_AC_Tag( "TMATT111"    , $ac );
            Check_AC_Tag( "TMATT112"    , $ac );
    
            $t = "TMATT104";
    
            if ( exists ( $i{ $t } ) ) {
    
                if ( not ( $i{ $t } =~ m/[0-9*]/ ) ) {
                    $msg = "Invalid value [ ".$i{ $t }." ] for tag <".$t.">. Input must be digits only.";
                    UpdateMessageStack( $msg, "FATAL" );
                }
    
                if ( length ( $i{ $t } ) gt 3 ) {
                    $msg = "Invalid length [ ".length ( $i{ $t } )." ] for tag <".$t.">. Maximum of 3 characters.";
                    UpdateMessageStack( $msg, "FATAL" );
                }
            }
    
            $t = "TMATT104_2";
    
            if ( exists ( $i{ $t } ) ) {
    
                if ( not ( $i{ $t } =~ m/1000|1/ ) ) {
                    $msg = "Invalid value [ ".$i{ $t }." ] for tag <".$t.">. Input must 1 (Ghz) or 1000 (Mhz).";
                    UpdateMessageStack( $msg, "FATAL" );
                }
            }
    
            $t = "TMATT106";
    
            if ( exists ( $i{ $t } ) ) {
    
                if ( not ( $i{ $t } =~ m/[0-9*]/ ) ) {
                    $msg = "Invalid value [ ".$i{ $t }." ] for tag <".$t.">. Input must be digits only.";
                    UpdateMessageStack( $msg, "FATAL" );
                }
    
                if ( length ( $i{ $t } ) gt 4 ) {
                    $msg = "Invalid length [ ".length ( $i{ $t } )." ] for tag <".$t.">. Maximum of 4 characters.";
                    UpdateMessageStack( $msg, "FATAL" );
                }
            }
    
            $t = "TMATT106_2";
    
            if ( exists ( $i{ $t } ) ) {
    
                if ( not ( $i{ $t } =~ m/1000|1/ ) ) {
                    $msg = "Invalid value [ ".$i{ $t }." ] for tag <".$t.">. Input must 1 (GB) or 1000 (MB).";
                    UpdateMessageStack( $msg, "FATAL" );
                }
            }
    
            $t = "TMATT108";
    
            if ( exists ( $i{ $t } ) ) {
    
                if ( not ( $i{ $t } =~ m/[0-9*]/ ) ) {
                    $msg = "Invalid value [ ".$i{ $t }." ] for tag <".$t.">. Input must be digits only.";
                    UpdateMessageStack( $msg, "FATAL" );
                }
    
                if ( length ( $i{ $t } gt 4 ) ) {
                    $msg = "Invalid length [ ".length ( $i{ $t } )." ] for tag <".$t.">. Maximum of 4 characters.";
                    UpdateMessageStack( $msg, "FATAL" );
                }
            }
    
            $t = "TMATT108_2";
    
            if ( exists ( $i{ $t } ) ) {
    
                if ( not ( $i{ $t } =~ m/1000|1/ ) ) {
                    $msg = "Invalid value [ ".$i{ $t }." ] for tag <".$t.">. Input must 1 (GB) or 1000 (MB).";
                    UpdateMessageStack( $msg, "FATAL" );
                }
            }
            $t = "TMATT111";
    
            if ( exists ( $i{ $t } ) ) {
    
                if ( not ( $i{ $t } =~ m/None| CD reader|CD writer|CD \+ DVD reader|CD writer \+ DVD reader|CD writer \+ DVD writer/ ) ) {
                    $msg  = " Invalid value [ ".$i{ $t }." ] for tag <".$t.">. Input must be one of: ";
                    $msg .= "None; CD reader; CD writer; CD + DVD reader; CD writer + DVD reader; CD writer + DVD writer.";
                    UpdateMessageStack( $msg, "FATAL" );
                }
            }
    
            $t = "TMATT112";
    
            if ( exists ( $i{ $t } ) ) {
    
                if ( not ( $i{ $t } =~ m/No monitor|CRT monitor|LCD monitor/ ) ) {
                    $msg = "Invalid value [ ".$i{ $t }." ] for tag <".$t.">. Input must be one of: No monitor; CRT monitor; LCD monitor.";
                    UpdateMessageStack( $msg, "FATAL" );
                }
            }
        }
        elsif ( $ap eq "EnableLaptops" ) {
    
            Check_AC_Tag( "TMATT104"    , $ac );
            Check_AC_Tag( "TMATT104_2"  , $ac );
            Check_AC_Tag( "TMATT106"    , $ac );
            Check_AC_Tag( "TMATT106_2"  , $ac );
            Check_AC_Tag( "TMATT108"    , $ac );
            Check_AC_Tag( "TMATT108_2"  , $ac );
            Check_AC_Tag( "TMATT111"    , $ac );

            $t = "TMATT104";
    
            if ( exists ( $i{ $t } ) ) {
    
                if ( not ( $i{ $t } =~ m/[0-9*]/ ) ) {
                    $msg = "Invalid value [ ".$i{ $t }." ] for tag <".$t.">. Input must be digits only.";
                    UpdateMessageStack( $msg, "FATAL" );
                }
    
                if ( length ( $i{ $t } ) gt 3 ) {
                    $msg = "Invalid length [ ".length ( $i{ $t } )." ] for tag <".$t.">. Maximum of 3 characters.";
                    UpdateMessageStack( $msg, "FATAL" );
                }
            }
    
            $t = "TMATT104_2";
    
            if ( exists ( $i{ $t } ) ) {
    
                if ( not ( $i{ $t } =~ m/1000|1/ ) ) {
                    $msg = "Invalid value [ ".$i{ $t }." ] for tag <".$t.">. Input must 1 (Ghz) or 1000 (Mhz).";
                    UpdateMessageStack( $msg, "FATAL" );
                }
            }
    
            $t = "TMATT106";
    
            if ( exists ( $i{ $t } ) ) {
    
                if ( not ( $i{ $t } =~ m/[0-9*]/ ) ) {
                    $msg = "Invalid value [ ".$i{ $t }." ] for tag <".$t.">. Input must be digits only.";
                    UpdateMessageStack( $msg, "FATAL" );
                }
    
                if ( length ( $i{ $t } ) gt 4 ) {
                    $msg = "Invalid length [ ".length ( $i{ $t } )." ] for tag <".$t.">. Maximum of 4 characters.";
                    UpdateMessageStack( $msg, "FATAL" );
                }
            }
    
            $t = "TMATT106_2";
    
            if ( exists ( $i{ $t } ) ) {
    
                if ( not ( $i{ $t } =~ m/1000|1/ ) ) {
                    $msg = "Invalid value [ ".$i{ $t }." ] for tag <".$t.">. Input must 1 (GB) or 1000 (MB).";
                    UpdateMessageStack( $msg, "FATAL" );
                }
            }
    
            $t = "TMATT108";
    
            if ( exists ( $i{ $t } ) ) {
    
                if ( not ( $i{ $t } =~ m/[0-9*]/ ) ) {
                    $msg = "Invalid value [ ".$i{ $t }." ] for tag <".$t.">. Input must be digits only.";
                    UpdateMessageStack( $msg, "FATAL" );
                }
    
                if ( length ( $i{ $t } ) gt 4 ) {
                    $msg = "Invalid length [ ".length ( $i{ $t } )." ] for tag <".$t.">. Maximum of 4 characters.";
                    UpdateMessageStack( $msg, "FATAL" );
                }
            }
    
            $t = "TMATT108_2";
    
            if ( exists ( $i{ $t } ) ) {
    
                if ( not ( $i{ $t } =~ m/1000|1/ ) ) {
                    $msg = "Invalid value [ ".$i{ $t }." ] for tag <".$t.">. Input must 1 (GB) or 1000 (MB).";
                    UpdateMessageStack( $msg, "FATAL" );
                }
            }
            $t = "TMATT111";
    
            if ( exists ( $i{ $t } ) ) {
    
                if ( not ( $i{ $t } =~ m/None|CD reader|CD writer|CD \+ DVD reader|CD writer \+ DVD reader|CD writer \+ DVD writer/ ) ) {
                    $msg  = " Invalid value [ ".$i{ $t }." ] for tag <".$t.">. Input must be one of: ";
                    $msg .= "None; CD reader; CD writer; CD + DVD reader; CD writer + DVD reader; CD writer + DVD writer.";
                    UpdateMessageStack( $msg, "FATAL" );
                }
            }
    
        }
        elsif ( $ap eq "EnableGameRating" ) {
    
            $t = "AttributeName";
    
            if ( exists ( $i{ $t } ) ) {
                if    (  $i{ $t } ne 137 )  {       
                    $msg = "Invalid value [ ".$i{ $t }." ] for tag <".$t.">. Input value must be 137";
                    UpdateMessageStack( $msg, "FATAL" );
                }
            }
            else {
                $msg = "Tag [ ".$t." ] required for Attribute Category [ ".$ac." ].";
                UpdateMessageStack( $msg, "FATAL" );
            }
        
            $t = "AttributeValue";
        
            if ( exists ( $i{ $t } ) ) {
                if    (  $i{ $t } ne 1 ) {        
                    $msg = "Invalid value [ ".$i{ $t }." ] for tag <".$t.">. Input value must be 1";
                    UpdateMessageStack( $msg, "FATAL" );
                }
            }
            else {
                $msg = "Tag [ ".$t." ] required for Attribute Category [ ".$ac." ].";
                UpdateMessageStack( $msg, "FATAL" );
            }
        }
        elsif ( $ap eq "EnableCotSafety" ) {
    
            $t = "AttributeName";
    
            if ( exists ( $i{ $t } ) ) {
                if    (  $i{ $t } ne 57 )  {       
                    $msg = "Invalid value [ ".$i{ $t }." ] for tag <".$t.">. Input value must be 57";
                    UpdateMessageStack( $msg, "FATAL" );
                }
            }
            else {
                $msg = "Tag [ ".$t." ] required for Attribute Category [ ".$ac." ].";
                UpdateMessageStack( $msg, "FATAL" );
            }
        
            $t = "AttributeValue";
        
            if ( exists ( $i{ $t } ) ) {
                if    (  $i{ $t } ne 1 )  {       
                    $msg = "Invalid value [ ".$i{ $t }." ] for tag <".$t.">. Input value must be 1";
                    UpdateMessageStack( $msg, "FATAL" );
                }
            }
            else {
                $msg = "Tag [ ".$t." ] required for Attribute Category [ ".$ac." ].";
                UpdateMessageStack( $msg, "FATAL" );
            }
        }
        elsif ( $ap eq "EnableBabyWalkers" ) {         
    
            $t = "AttributeName";
    
            if ( exists ( $i{ $t } ) ) {
                if    (  $i{ $t } ne 57 )  {       
                    $msg = "Invalid value [ ".$i{ $t }." ] for tag <".$t.">. Input value must be 57";
                    UpdateMessageStack( $msg, "FATAL" );
                }
            }
            else {
                $msg = "Tag [ ".$t." ] required for Attribute Category [ ".$ac." ].";
                UpdateMessageStack( $msg, "FATAL" );
            }
        
            $t = "AttributeValue";
        
            if ( exists ( $i{ $t } ) ) {
                if    (  $i{ $t } ne 1 )  {       
                    $msg = "Invalid value [ ".$i{ $t }." ] for tag <".$t.">. Input value must be 1";
                    UpdateMessageStack( $msg, "FATAL" );
                }
            }
            else {
                $msg = "Tag [ ".$t." ] required for Attribute Category [ ".$ac." ].";
                UpdateMessageStack( $msg, "FATAL" );
            }
        }
        elsif ( $ap eq "EnableBabyCarSeats" ) { 
    
            $t = "AttributeName";
    
            if ( exists ( $i{ $t } ) ) {
                if    (  $i{ $t } ne 57 )  {       
                    $msg = "Invalid value [ ".$i{ $t }." ] for tag <".$t.">. Input value must be 57";
                    UpdateMessageStack( $msg, "FATAL" );
                }
            }
            else {
                $msg = "Tag [ ".$t." ] required for Attribute Category [ ".$ac." ].";
                UpdateMessageStack( $msg, "FATAL" );
            }
        
            $t = "AttributeValue";
        
            if ( exists ( $i{ $t } ) ) {
                if    (  $i{ $t } ne 1 )  {       
                    $msg = "Invalid value [ ".$i{ $t }." ] for tag <".$t.">. Input value must be 1";
                    UpdateMessageStack( $msg, "FATAL" );
                }
            }
            else {
                $msg = "Tag [ ".$t." ] required for Attribute Category [ ".$ac." ].";
                UpdateMessageStack( $msg, "FATAL" );
            }
        }
        elsif ( $ap eq "EnableMovieControls" ) {
    
            # Check required tags have been supplied
    
            Check_AC_Tag( "MovieRating"         , $ac );
            Check_AC_Tag( "MovieConfirmation"   , $ac );
    
            # Movie Rating
    
            $t = "MovieRating";
    
            if ( exists ( $i{ $t } ) ) {
                if    ( $i{ $t } eq "G"              )     { $i{ $t } = 1 ; } 
                elsif ( $i{ $t } eq "PG"             )     { $i{ $t } = 2 ; } 
                elsif ( $i{ $t } eq "M"              )     { $i{ $t } = 3 ; } 
                elsif ( $i{ $t } eq "R13"            )     { $i{ $t } = 4 ; } 
                elsif ( $i{ $t } eq "R15"            )     { $i{ $t } = 5 ; } 
                elsif ( $i{ $t } eq "R16"            )     { $i{ $t } = 6 ; } 
                elsif ( $i{ $t } eq "R18"            )     { $i{ $t } = 7 ; } 
                elsif ( $i{ $t } eq "Not Classified" )     { $i{ $t } = 8 ; } 
                else {
                    $msg = "Invalid value [ ".$i{ $t }." ] for tag <".$t.">. Input value must be blank or G, PG, M, R13, R15, R16, R18, or Not Classified";
                    UpdateMessageStack( $msg, "FATAL" );
                }
            }
    
            # Movie Confirmation
    
            $t = "MovieConfirmation";
    
            if ( exists ( $i{ $t } ) ) {
                if    ( uc ( $i{ $t } ) eq "YES" )         { $i{ $t } = 1 ; } 
                else {
                    $msg = "Invalid value [ ".$i{ $t }." ] for tag <".$t.">. Input value must be Yes";
                    UpdateMessageStack( $msg, "FATAL" );
                }
            }
        }
        elsif ( $ap eq "EnableDVDControls" ) {
    
            # Check required tags have been supplied
    
            Check_AC_Tag( "MovieRating"         , $ac );
            Check_AC_Tag( "MovieConfirmation"   , $ac );
            Check_AC_Tag( "TMATT038"            , $ac );
            Check_AC_Tag( "TMATT163"            , $ac );
            Check_AC_Tag( "TMATT164"            , $ac );
    
            # Movie Rating
    
            $t = "MovieRating";
    
            if ( exists ( $i{ $t } ) ) {
                if    ( $i{ $t } eq "G"              )     { $i{ $t } = 1 ; } 
                elsif ( $i{ $t } eq "PG"             )     { $i{ $t } = 2 ; } 
                elsif ( $i{ $t } eq "M"              )     { $i{ $t } = 3 ; } 
                elsif ( $i{ $t } eq "R13"            )     { $i{ $t } = 4 ; } 
                elsif ( $i{ $t } eq "R15"            )     { $i{ $t } = 5 ; } 
                elsif ( $i{ $t } eq "R16"            )     { $i{ $t } = 6 ; } 
                elsif ( $i{ $t } eq "R18"            )     { $i{ $t } = 7 ; } 
                elsif ( $i{ $t } eq "Not Classified" )     { $i{ $t } = 8 ; } 
                else {
                    $msg = "Invalid value [ ".$i{ $t }." ] for tag <".$t.">. Input value must be blank or G, PG, M, R13, R15, R16, R18, or Not Classified";
                    push ( @Messages, $msg );
                    UpdateMessageStack( $msg, "FATAL" );
                }
            }
    
            # Movie Confirmation
    
            $t = "MovieConfirmation";
    
            if ( exists ( $i{ $t } ) ) {
                if    ( uc ( $i{ $t } ) eq "YES" )         { $i{ $t } = 1 ; } 
                else {
                    $msg = "Invalid value [ ".$i{ $t }." ] for tag <".$t.">. Input value must be Yes";
                    UpdateMessageStack( $msg, "FATAL" );
                }
            }
    
            $t = "TMATT038";
    
            if ( exists ( $i{ $t } ) ) {
    
                if ( not ( $i{ $t } =~ m/Brand New|As New|Good|Poor/ ) ) {
                    $msg = "Invalid value [ ".$i{ $t }." ] for tag <".$t.">. Input must be one of: Brand New; As New; Good; Poor.";
                    UpdateMessageStack( $msg, "FATAL" );
                }
            }
    
            $t = "TMATT163";
    
            if ( exists ( $i{ $t } ) ) {
    
                if ( not ( $i{ $t } =~ m/01|02|03|04|05|06|07|08|09|10\+|Don't Know/ ) ) {
                    $msg = "Invalid value [ ".$i{ $t }." ] for tag <".$t.">. Input must be one of: 01: 02: 03: 04: 05: 06: 07: 08: 09: 10+: Don't Know.";
                    UpdateMessageStack( $msg, "FATAL" );
                }
            }
    
            $t = "TMATT164";
    
            if (  exists ( $i{ $t } ) ) {
    
                if ( not $tm->is_valid_movie_genre( $i{ $t } ) ) {
                    $msg = "Invalid value [ ".$i{ $t }." ] for tag <".$t.">. Input must match value in Genre_Value column in MovieGenres table.";
                    UpdateMessageStack( $msg, "FATAL" );
                }
            }
        }
    }

    # End of attribute processing

    #------------------------------------------------------------------------------
    # Check data for conformity to TradeMe Auction input rules 
    #------------------------------------------------------------------------------
    
    # Start Price greater than zero
    
    if ( $i{ StartPrice } <= 0 ) {
        $msg = "Invalid value [ ".$i{ StartPrice }." ] for tag <StartPrice>. Input value must be greater than 0.";
        UpdateMessageStack( $msg, "FATAL" );
    }
    
    # If specified Buy now price must be greater than or equal to the Start Price
    
    if ( ( $i{ BuyNowPrice } > 0 ) and ( $i{ BuyNowPrice } < $i{ StartPrice } ) ) {
        $msg = "Invalid value [ ".$i{ BuyNowPrice }." ] for tag <BuyNowPrice>. BuyNowPrice must be greater than or equal to StartPrice.";
        UpdateMessageStack( $msg, "FATAL" );
    }
    
    # Reserve Price must be greater than or equal to the Start Price;  if no reserve specified set to Start price
    if ( exists ( $i{ ReservePrice } ) ) {    
        if ( $i{ ReservePrice } < $i{ StartPrice } ) {
            $msg = "Invalid value [ ".$i{ ReservePrice }." ] for tag <ReservePrice>. ReservePrice must be greater than or equal to StartPrice.";
            UpdateMessageStack( $msg, "FATAL" );
        }
    }
    else {
        $i{ ReservePrice } = $i{ StartPrice };
        $msg = "No Reserve Price specified; ReservePrice has been set to StartPrice [ ".$i{ StartPrice }." ].";
        UpdateMessageStack( $msg, "WARNING" );
    }

    # Starting price must be at least 10% of the reserve price if the reserve is over exactly 100.00 
    
    if ( ( $i{ ReservePrice } > 100 ) and ( $i{ StartPrice } < $i{ ReservePrice }/10 ) ) {
    
        $msg  = " Invalid value [ ".$i{ StartPrice }." ] for tag <StartPrice>. ";
        $msg .= "StartPrice must be at least 10% of the Reserve if Reserve is greater than 100.00.";
        UpdateMessageStack( $msg, "FATAL" );
    }
    
    # Payment Info must be entered if all of the boolean payment fields are empty/untrue
    
    if (        ( $i{ BankDeposit   } ==  0 ) 
         and    ( $i{ CashOnPickup  } ==  0 ) 
         and    ( $i{ CreditCard    } ==  0 )
         and    ( $i{ Pago          } ==  0 ) 
         and    ( $i{ Paymate       } ==  0 ) 
         and    ( $i{ SafeTrader    } ==  0 ) 
         and  ( ( $i{ PaymentInfo  } eq "" ) or ( not defined $i{ PaymentInfo } ) ) 
        ) {
    
        $msg = "Tag <PaymentInfo> is empty but no other Payment Method has been specified.";
        UpdateMessageStack( $msg, "FATAL" );
    }
    
    # Perform Picture file validation
    
    foreach my $pic ( @pics ) {   
    
        # check that file exists and check size of file
    
        my @fstat = stat( $pic );
        
        if ( not @fstat ) {
            $msg = "File ".$pic." specified in <PictureFile> tag not found or not accessible.";
            UpdateMessageStack( $msg, "WARNING" );
        }
        else {
            if ( $fstat[7] > 500000 ) {
                $msg = "File ".$pic." specified in <PictureFile> exceeds 500,000 bytes and may not upload to TradeMe.";
                UpdateMessageStack( $msg, "WARNING" );
            }
        }
    }
    
    # Check that Picture count is at least 1 if any promotional options have been specified
    
    if  ( $i{ Gallery } ==  1 and $Icount == 0 ) {
        $msg = "Promotional option <Gallery> specified but no PictureFile name has been supplied.";
        UpdateMessageStack( $msg, "FATAL" );
    }
        
    if ( $i{ FeatureCombo } ==  1 and $Icount == 0 ) {
        $msg = "Promotional option <FeatureCombo> specified but no PictureFile name has been supplied.";
        UpdateMessageStack( $msg, "FATAL" );
    }
    
    if ( $i{ HomePage } ==  1 and $Icount == 0 ) {
        $msg = "Promotional option <HomePage> specified but no PictureFile name has been supplied.";
        UpdateMessageStack( $msg, "FATAL" );
    }
    
    #------------------------------------------------------------------------------
    # Write data to database if record not invalid ($errorflag flag is true)
    #------------------------------------------------------------------------------

    my $newkey = 0;

    if ( ( $errorflag == 0 ) and ( $Action eq "UPDATE" ) ) {
    
        # Attempt to get picture key form database; if record found use retrieved key
        # If  not found, add file to database and retrieve key for new record
    
        # Picture 1
    
        if ( $Icount ge 1) {
        
            my $pickey = $tm->get_picture_key( PictureFileName => $pics[0] );        
        
            if ( $pickey )   {
                $i{ PictureKey1 } = $pickey;
            }
            else {        
                $tm->add_picture_record( PictureFileName => $pics[0] );
                $pickey = $tm->get_picture_key( PictureFileName => $pics[0] );
                $i{ PictureKey1 } = $pickey;
            }
        }
    
        # Picture 2
    
        if ( $Icount ge 2 ) {
        
            my $pickey = $tm->get_picture_key( PictureFileName => $pics[1] );        
        
            if ( $pickey )   {
                $i{ PictureKey2 } = $pickey;
            }
            else {        
                $tm->add_picture_record( PictureFileName => $pics[1] );
                $pickey = $tm->get_picture_key( PictureFileName => $pics[1] );
                $i{ PictureKey2 } = $pickey;
            }
        }
    
        # Picture 3
    
        if ( $Icount eq 3 ) {
        
            my $pickey = $tm->get_picture_key( PictureFileName => $pics[2] );        
        
            if ( $pickey )   {
                $i{ PictureKey3 } = $pickey;
            }
            else {        
                $tm->add_picture_record( PictureFileName => $pics[2] );
                $pickey = $tm->get_picture_key( PictureFileName => $pics[2] );
                $i{ PictureKey3 } = $pickey;
            }
        }
    
        # Write auction record
    
        $newkey = $tm->add_auction_record_202(
            AuctionStatus              =>  "PENDING"                        ,
            $i{ AttributeCategory  } ? ( AttributeCategory  =>  $i{ AttributeCategory  } ) : () ,
            $i{ AttributeName      } ? ( AttributeName      =>  $i{ AttributeName      } ) : () ,
            $i{ AttributeValue     } ? ( AttributeValue     =>  $i{ AttributeValue     } ) : () ,
            $i{ AuctionCycle       } ? ( AuctionCycle       =>  $i{ AuctionCycle       } ) : () ,
            $i{ BankDeposit        } ? ( BankDeposit        =>  $i{ BankDeposit        } ) : () ,
            $i{ BoldTitle          } ? ( BoldTitle          =>  $i{ BoldTitle          } ) : () ,
            $i{ BuyNowPrice        } ? ( BuyNowPrice        =>  $i{ BuyNowPrice        } ) : () ,
            $i{ CashOnPickup       } ? ( CashOnPickup       =>  $i{ CashOnPickup       } ) : () ,
            $i{ Category           } ? ( Category           =>  $i{ Category           } ) : () ,
            $i{ ClosedAuction      } ? ( ClosedAuction      =>  $i{ ClosedAuction      } ) : () ,
            $i{ CopyCount          } ? ( CopyCount          =>  $i{ CopyCount          } ) : () ,
            $i{ CreditCard         } ? ( CreditCard         =>  $i{ CreditCard         } ) : () ,
            $i{ Description        } ? ( Description        =>  $i{ Description        } ) : () ,
            $i{ DurationHours      } ? ( DurationHours      =>  $i{ DurationHours      } ) : () ,
            $i{ EndDays            } ? ( EndDays            =>  $i{ EndDays            } ) : () ,
            $i{ EndTime            } ? ( EndTime            =>  $i{ EndTime            } ) : () ,
            $i{ EndType            } ? ( EndType            =>  $i{ EndType            } ) : () ,
            $i{ FeatureCombo       } ? ( FeatureCombo       =>  $i{ FeatureCombo       } ) : () ,
            $i{ Featured           } ? ( Featured           =>  $i{ Featured           } ) : () ,
            $i{ Gallery            } ? ( Gallery            =>  $i{ Gallery            } ) : () ,
            $i{ Held               } ? ( Held               =>  $i{ Held               } ) : () ,
            $i{ HomePage           } ? ( HomePage           =>  $i{ HomePage           } ) : () ,
            $i{ IsNew              } ? ( IsNew              =>  $i{ IsNew              } ) : () ,
            $i{ LoadSequence       } ? ( LoadSequence       =>  $i{ LoadSequence       } ) : () ,
            $i{ MovieConfirm       } ? ( MovieConfirm       =>  $i{ MovieConfirm       } ) : () ,
            $i{ MovieRating        } ? ( MovieRating        =>  $i{ MovieRating        } ) : () ,
            $i{ NotifyWatchers     } ? ( NotifyWatchers     =>  $i{ NotifyWatchers     } ) : () ,
            $i{ Paymate            } ? ( Paymate            =>  $i{ Paymate            } ) : () ,
            $i{ PaymentInfo        } ? ( PaymentInfo        =>  $i{ PaymentInfo        } ) : () ,
            $i{ PickupOption       } ? ( PickupOption       =>  $i{ PickupOption       } ) : () ,
            $i{ PictureKey1        } ? ( PictureKey1        =>  $i{ PictureKey1        } ) : () ,
            $i{ PictureKey2        } ? ( PictureKey2        =>  $i{ PictureKey2        } ) : () ,
            $i{ PictureKey3        } ? ( PictureKey3        =>  $i{ PictureKey3        } ) : () ,
            $i{ ProductCode        } ? ( ProductCode        =>  $i{ ProductCode        } ) : () ,
            $i{ ProductCode2       } ? ( ProductCode2       =>  $i{ ProductCode2       } ) : () ,
            $i{ ProductType        } ? ( ProductType        =>  $i{ ProductType        } ) : () ,
            $i{ RelistStatus       } ? ( RelistStatus       =>  $i{ RelistStatus       } ) : () ,
            $i{ ReservePrice       } ? ( ReservePrice       =>  $i{ ReservePrice       } ) : () ,
            $i{ SafeTrader         } ? ( SafeTrader         =>  $i{ SafeTrader         } ) : () ,
            $i{ SellerRef          } ? ( SellerRef          =>  $i{ SellerRef          } ) : () ,
            $i{ ShippingCost       } ? ( ShippingCost       =>  $i{ ShippingCost       } ) : () ,
            $i{ ShippingDetails    } ? ( ShippingDetails    =>  $i{ ShippingDetails    } ) : () ,
            $i{ ShippingOption     } ? ( ShippingOption     =>  $i{ ShippingOption     } ) : () ,
            $i{ ShippingText       } ? ( ShippingText       =>  $i{ ShippingText       } ) : () ,
            $i{ StartPrice         } ? ( StartPrice         =>  $i{ StartPrice         } ) : () ,
            $i{ StockOnHand        } ? ( StockOnHand        =>  $i{ StockOnHand        } ) : () ,
            $i{ Subtitle           } ? ( Subtitle           =>  $i{ Subtitle           } ) : () ,
            $i{ SupplierRef        } ? ( SupplierRef        =>  $i{ SupplierRef        } ) : () ,
            $i{ TMATT104           } ? ( TMATT104           =>  $i{ TMATT104           } ) : () ,
            $i{ TMATT104_2         } ? ( TMATT104_2         =>  $i{ TMATT104_2         } ) : () ,
            $i{ TMATT106           } ? ( TMATT106           =>  $i{ TMATT106           } ) : () ,
            $i{ TMATT106_2         } ? ( TMATT106_2         =>  $i{ TMATT106_2         } ) : () ,
            $i{ TMATT108           } ? ( TMATT108           =>  $i{ TMATT108           } ) : () ,
            $i{ TMATT108_2         } ? ( TMATT108_2         =>  $i{ TMATT108_2         } ) : () ,
            $i{ TMATT111           } ? ( TMATT111           =>  $i{ TMATT111           } ) : () ,
            $i{ TMATT112           } ? ( TMATT112           =>  $i{ TMATT112           } ) : () ,
            $i{ TMATT115           } ? ( TMATT115           =>  $i{ TMATT115           } ) : () ,
            $i{ TMATT117           } ? ( TMATT117           =>  $i{ TMATT117           } ) : () ,
            $i{ TMATT118           } ? ( TMATT118           =>  $i{ TMATT118           } ) : () ,
            $i{ TMBuyerEmail       } ? ( TMBuyerEmail       =>  $i{ TMBuyerEmail       } ) : () ,
            $i{ Title              } ? ( Title              =>  $i{ Title              } ) : () ,
            $i{ UserDefined01      } ? ( UserDefined01      =>  $i{ UserDefined01      } ) : () ,
            $i{ UserDefined02      } ? ( UserDefined02      =>  $i{ UserDefined02      } ) : () ,
            $i{ UserDefined03      } ? ( UserDefined03      =>  $i{ UserDefined03      } ) : () ,
            $i{ UserDefined04      } ? ( UserDefined04      =>  $i{ UserDefined04      } ) : () ,
            $i{ UserDefined05      } ? ( UserDefined05      =>  $i{ UserDefined05      } ) : () ,
            $i{ UserDefined06      } ? ( UserDefined06      =>  $i{ UserDefined06      } ) : () ,
            $i{ UserDefined07      } ? ( UserDefined07      =>  $i{ UserDefined07      } ) : () ,
            $i{ UserDefined08      } ? ( UserDefined08      =>  $i{ UserDefined08      } ) : () ,
            $i{ UserDefined09      } ? ( UserDefined09      =>  $i{ UserDefined09      } ) : () ,
            $i{ UserDefined10      } ? ( UserDefined10      =>  $i{ UserDefined10      } ) : () ,
            $i{ UserNotes          } ? ( UserNotes          =>  $i{ UserNotes          } ) : () ,
            $i{ UserStatus         } ? ( UserStatus         =>  $i{ UserStatus         } ) : () ,
        );
    
        $msg = "Added new record [ ".$newkey." ].";
        UpdateMessageStack( $msg, "DEBUG" );

        # Update the Auction key property

        $AuctionKey = $newkey;

        # Add the shipping options parameters if we have custom shipping options
        
        if ( @shipopt ) {
        
            my $seq = 1;
        
            foreach my $option ( @shipopt ) {
                 
                $tm->add_shipping_details_record(
                    AuctionKey                 =>   $newkey                     ,          
                    Shipping_Details_Seq       =>   $seq                        ,           
                    Shipping_Details_Cost      =>   $option->{ ShippingCost }   ,           
                    Shipping_Details_Text      =>   $option->{ ShippingText }   ,          
                    Shipping_Option_Code       =>   ""                          ,          
                );
    
                $msg = "Added Shipping Details item [ ".$seq." ].";
                UpdateMessageStack( $msg, "DEBUG" );
    
                $seq++;
            }
        }
    }
    
    # If Debug on, dump all the input fields except Description - it just gets in the way
    
    if ( $tm->{ Debug} ge 1 ) {

        $tm->update_log();
        $tm->update_log( "Input Data dump" );
        $tm->update_log( "------------------------" );
        
        foreach my $key ( sort keys %i ) {
        
            if ( $key ne "Description" and $key ne "AuctionRecord" ) {
              $tm->update_log("<".$key.">\t\t ".$i{ $key } );
            }
        }
        
        $tm->update_log();
        $tm->update_log("Extracted Shipping Options");
        $tm->update_log("------------------------");
        
        foreach my $do ( @shipopt ) {
            $tm->update_log("Shipping Cost: ".$do->{ ShippingCost } );
            $tm->update_log("Shipping Text: ".$do->{ ShippingText } );
        }
    }

    # Update the Auctionitis Log

    $tm->update_log();
    $tm->update_log("Document details Summary" );
    $tm->update_log("------------------------" );
    $tm->update_log("        Messages: ".scalar( @Messages ) );
    $tm->update_log("    Fatal Errors: ".$Fcount );
    $tm->update_log("        Warnings: ".$Wcount );
    $tm->update_log("      Paragraphs: ".$Pcount );
    $tm->update_log("        Pictures: ".$Icount );
    $tm->update_log("Delivery Options: ".$DOcount ); 

    # Update the API property values

    UpdateAPIProperties();

    if ( $errorflag == 0 ) {
        if ( $Action eq "UPDATE" ) {
            return $newkey;
        }
        else {
            return $errorflag;
        }
    }
    else{ 
        return $errorflag;
    }

}

#---------------------------------------------------------------------------------------------
# Method: GetAuctionKey
#
# Retrieves the Index Key for an Auction Record
#
# Parameters: Foreign Key Value (SellerRef, ProductCode, ProductCode2)
#---------------------------------------------------------------------------------------------

sub GetAuctionKey { 

    my $keyname     = shift;
    my $keyvalue    = shift;

    InitGlobals();

    if ( not defined( $keyname )  ) {
        $msg = "Reference Key Name parameter not supplied";
        UpdateMessageStack( $msg, "FATAL" );
        UpdateAPIProperties();
        return $errorflag;
    }

    if ( not defined( $keyvalue )  ) {
        $msg = "Reference Key Value parameter not supplied";
        UpdateMessageStack( $msg, "FATAL" );
        UpdateAPIProperties();
        return $errorflag;
    }

    if ( ( uc( $keyname ) ne "SELLERREF"      )   and
         ( uc( $keyname ) ne "PRODUCTCODE"    )   and
         ( uc( $keyname ) ne "PRODUCTCODE2"   )   ) {

        $msg = "Invalid Reference Key Name - must be PRODUCTCODE, PRODUCTCODE2 or SELLERREF";
        UpdateMessageStack( $msg, "FATAL" );
        UpdateAPIProperties();
        return $errorflag;
    }

    my $auctionkey = $tm->get_auction_key_byval( $keyname, $keyvalue );

    if ( not defined( $auctionkey ) ) {
        $msg = "Auction record not found for Reference Key [ ".$keyname." ] with value [ ".$keyvalue." ]";
        UpdateMessageStack( $msg, "FATAL" );
        UpdateAPIProperties();
        return $errorflag;
    }
    else {

        # set the AuctionKey property and return the retrieved key

        $msg = "Auction record [ ".$auctionkey." ] found for Reference Key [ ".$keyname." ] with value [ ".$keyvalue." ]";
        UpdateMessageStack( $msg, "DEBUG" );
        UpdateAPIProperties();

        return $auctionkey
    }
}

#---------------------------------------------------------------------------------------------
# Method: GetAuctionReference
#
# Retrieves the Trademe reference for an uction record
#
# Parameters: AuctionKey
#---------------------------------------------------------------------------------------------

sub GetAuctionReference { 

    my $auctionkey  = shift;

    InitGlobals();

    if ( not defined( $auctionkey )  ) {
        $msg = "Required Parameter [ AuctionKey ] not supplied";
        UpdateMessageStack( $msg, "FATAL" );
        UpdateAPIProperties();
        return $errorflag;
    }

    if ( not $tm->is_valid_auctionkey( $auctionkey ) ) {
        $msg = "Record with requested primary key [ ".$auctionkey." ] not found in database";
        UpdateMessageStack( $msg, "FATAL" );
        UpdateAPIProperties();
        return $errorflag;
    }

    my $auctionref = $tm->get_auction_ref( $auctionkey );

    $msg = "Retrieved auctions reference [ ".$auctionref." ] for primary key [ ".$auctionkey." ]";
    UpdateMessageStack( $msg, "DEBUG" );
    UpdateAPIProperties();

    if ( not defined(  $auctionref ) or $auctionref eq "" ) {

        $auctionref = "0";
        
        $msg = "Record with requested primary key [ ".$auctionkey." ] does not appear to have been loaded to TradeMe";
        UpdateMessageStack( $msg, "WARN" );
        UpdateAPIProperties();
    }
    return $auctionref;
}

#---------------------------------------------------------------------------------------------
# Method: GetAuctionStatus
#
# Retrieves the Status for an Auction Record
#
# Parameters: AuctionKey
#---------------------------------------------------------------------------------------------

sub GetAuctionStatus { 

    my $auctionkey  = shift;

    if ( not defined( $auctionkey )  ) {
        $msg = "Required Parameter [ AuctionKey ] not supplied";
        UpdateMessageStack( $msg, "FATAL" );
        UpdateAPIProperties();
        return $errorflag;
    }

    if ( not $tm->is_valid_auctionkey( $auctionkey ) ) {
        $msg = "Record with requested primary key [ ".$auctionkey." ] not found in database";
        UpdateMessageStack( $msg, "FATAL" );
        UpdateAPIProperties();
        return $errorflag;
    }

    my $auctionstatus = $tm->get_auction_status( $auctionkey );
    
    $msg = "Retrieved auctions status [ ".$auctionstatus." ] for primary key [ ".$auctionkey." ]";
    UpdateMessageStack( $msg, "DEBUG" );
    UpdateAPIProperties();

    return $auctionstatus;
}

#---------------------------------------------------------------------------------------------
# Method: DeleteAuction
#
# Deletes an Auction Record
#
# Parameters: AuctionKey
#---------------------------------------------------------------------------------------------

sub DeleteAuction { 

    my $auctionkey  = shift;

    if ( not defined( $auctionkey )  ) {
        $msg = "Auction Key not supplied";
        UpdateMessageStack( $msg, "FATAL" );
        UpdateAPIProperties();
        return $errorflag;
    }

    if ( not $tm->is_valid_auctionkey( $auctionkey ) ) {
        $msg = "Record with requested primary key [ ".$auctionkey." ] not found in database";
        UpdateMessageStack( $msg, "FATAL" );
        UpdateAPIProperties();
        return $errorflag;
    }

    $tm->delete_auction_record( AuctionKey => $auctionkey );

    return $errorflag
}

#---------------------------------------------------------------------------------------------
# Method: HoldAuction
#
# Holds an Auction Record to prevent processing
#
# Parameters: AuctionKey
#---------------------------------------------------------------------------------------------

sub HoldAuction { 

    my $auctionkey  = shift;

    if ( not defined( $auctionkey )  ) {
        $msg = "Auction Key not supplied";
        UpdateMessageStack( $msg, "FATAL" );
        UpdateAPIProperties();
        return $errorflag;
    }

    if ( not $tm->is_valid_auctionkey( $auctionkey ) ) {
        $msg = "Record with requested primary key [ ".$auctionkey." ] not found in database";
        UpdateMessageStack( $msg, "FATAL" );
        UpdateAPIProperties();
        return $errorflag;
    }

    $tm->update_auction_record(
        AuctionKey       =>  $auctionkey    ,
        Held             =>  -1             ,
    );

    return $errorflag
}

#---------------------------------------------------------------------------------------------
# Method: ReleaseAuction
#
# Releases (Unholds) an Auction Record
#
# Parameters: AuctionKey
#---------------------------------------------------------------------------------------------

sub ReleaseAuction { 

    my $auctionkey  = shift;

    if ( not defined( $auctionkey )  ) {
        $msg = "Auction Key not supplied";
        UpdateMessageStack( $msg, "FATAL" );
        UpdateAPIProperties();
        return $errorflag;
    }

    if ( not $tm->is_valid_auctionkey( $auctionkey ) ) {
        $msg = "Record with requested primary key [ ".$auctionkey." ] not found in database";
        UpdateMessageStack( $msg, "FATAL" );
        UpdateAPIProperties();
        return $errorflag;
    }

    $tm->update_auction_record(
        AuctionKey       =>  $auctionkey    ,
        Held             =>  0              ,
    );

    return $errorflag
}

#---------------------------------------------------------------------------------------------
# Method: AuctionKeyIsValid
#
# Checks whether the supplied auction keys is valid (found in the Auctions table)
#
# Parameters: AuctionKey
#---------------------------------------------------------------------------------------------

sub AuctionKeyIsValid { 

    my $auctionkey  = shift;

    if ( not defined( $auctionkey )  ) {
        $msg = "Auction Key not supplied";
        UpdateMessageStack( $msg, "FATAL" );
        UpdateAPIProperties();
        return $errorflag;
    }

    if ( $tm->is_valid_auctionkey( $auctionkey ) ) {
        return 0;
    }
    else {
        return -1;
    }
}

#=============================================================================================
# Method: GetMessage
#
# Gets an error message from the error message array
#=============================================================================================

sub GetMessage {

    my $index = shift;
    my $msgdata;

    if ( $index < 1 ) {
        $msgdata = "Invalid Message Index; index must be greater than 1";
    }
    elsif ( $index > scalar( @Messages ) ) {
        $msgdata = "Invalid Message Index; index values are 1 to ".scalar( @Messages );
    }
    else {
        $msgdata = $Messages[ $index - 1 ];
    }

    return $msgdata;
}

#---------------------------------------------------------------------------------------------
# Method: CategoryIsValid
#
# Checks whether the supplied category is valid (found in the Categories table)
#
# Parameters: Category
#---------------------------------------------------------------------------------------------

sub CategoryIsValid { 

    my $category = shift;

    if ( not defined( $category )  ) {
        $msg = "Category not supplied";
        UpdateMessageStack( $msg, "FATAL" );
        UpdateAPIProperties();
        return $errorflag;
    }

    if ( $tm->is_valid_category( $category ) ) {
        return 0;
    }
    else {
        return -1;
    }
}

#---------------------------------------------------------------------------------------------
# Method: CategoryHasChildren
#
# Tests whether the category has child categories
#
# Parameters: Category
#---------------------------------------------------------------------------------------------

sub CategoryHasChildren {

    my $category = shift;

    if ( not defined( $category ) ) {
        $msg = "Input category value not supplied";
        UpdateMessageStack( $msg, "FATAL" );
        UpdateAPIProperties();
        return $errorflag;
    }

    if ( not $tm->is_valid_category( $category )  ) {
        $msg = "Requested category [ ".$category." ] is  not a valid category";
        UpdateMessageStack( $msg, "FATAL" );
        UpdateAPIProperties();
        return $errorflag;
    }

    if ( $tm->has_children( $category ) ) {
        return 0;
    }
    else {
        return -1;
    }
}

#---------------------------------------------------------------------------------------------
# Method: CategoryHasAttributes
#
# Tests whether the category has child categories
#
# Parameters: Category
#---------------------------------------------------------------------------------------------

sub CategoryHasAttributes {

    my $category = shift;

    if ( not defined( $category ) ) {
        $msg = "Input category value not supplied";
        UpdateMessageStack( $msg, "FATAL" );
        UpdateAPIProperties();
        return $errorflag;
    }

    if ( not $tm->is_valid_category( $category )  ) {
        $msg = "Requested category [ ".$category." ] is  not a valid category";
        UpdateMessageStack( $msg, "FATAL" );
        UpdateAPIProperties();
        return $errorflag;
    }

    if ( $tm->has_attributes( $category ) ) {
        return 0;
    }
    else {
        return -1;
    }
}

#---------------------------------------------------------------------------------------------
# Method: GetCategoryParent
#
# Creates Gets the parent Category of the input category
#
# Parameters: XML String
#---------------------------------------------------------------------------------------------

sub GetCategoryParent {

    my $category = shift;

    if ( not defined( $category ) ) {
        $msg = "Input category value not supplied";
        UpdateMessageStack( $msg, "FATAL" );
        UpdateAPIProperties();
        return $errorflag;
    }

    if ( not ( $tm->is_valid_category( $category ) ) ) {
        $msg = "Requested category [ ".$category." ] is  not a valid category";
        UpdateMessageStack( $msg, "FATAL" );
        UpdateAPIProperties();
        return $errorflag;
    }

    my $parent = $tm->get_parent( $category );

    return $parent;
}

#---------------------------------------------------------------------------------------------
# Method: GetCategoryList
#
# Gets a list of child categories for a give catgeory
#
# Parameters: Category
#---------------------------------------------------------------------------------------------

sub GetCategoryList {

    my $category = shift;

    if ( not defined( $category ) ) {
        $msg = "Root category value not supplied";
        UpdateMessageStack( $msg, "FATAL" );
        UpdateAPIProperties();
        return $errorflag;
    }

    if ( not ( $tm->has_children( $category ) ) and $category != 0 ) {
        $msg = "Requested category [ ".$category." ] has no child categories";
        UpdateMessageStack( $msg, "FATAL" );
        UpdateAPIProperties();
        return $errorflag;
    }

    if ( not ( $tm->is_valid_category( $category ) ) and $category != 0 ) {
        $msg = "Requested category [ ".$category." ] is  not a valid category";
        UpdateMessageStack( $msg, "FATAL" );
        UpdateAPIProperties();
        return $errorflag;
    }

    my @catlist = $tm->get_category_list( $category );

    # Convert the returned array to a VB array

    my $categories = ConvertArrayToVBArray( \@catlist );

    return $categories;
}

#---------------------------------------------------------------------------------------------
# Method: GetCategoryDescription
#
# Creates Creates a new Auction Record
#
# Parameters: Category value
#---------------------------------------------------------------------------------------------

sub GetCategoryDescription {

    my $category = shift;

    if ( not defined( $category ) ) {
        $msg = "Input category value not supplied";
        UpdateMessageStack( $msg, "FATAL" );
        UpdateAPIProperties();
        return $errorflag;
    }

    if ( not ( $tm->is_valid_category( $category ) ) ) {
        $msg = "Requested category [ ".$category." ] is  not a valid category";
        UpdateMessageStack( $msg, "FATAL" );
        UpdateAPIProperties();
        return $errorflag;
    }

    my $description = $tm->get_category_description( $category );

    return $description;
}

#---------------------------------------------------------------------------------------------
# Method: GetCategoryServiceDate
#
# retrieves the category service date for the connected database
#
# Parameters: None
#---------------------------------------------------------------------------------------------

sub GetCategoryServiceDate {

    my $csd = $tm->get_DB_property(
        Property_Name       =>  "CategoryServiceDate"   ,
        Property_Default    =>  "01-01-2006"            ,
    );

    return $csd;
}

#---------------------------------------------------------------------------------------------
# Method: GetDatabaseVersion
#
# retrieves the category service date for the connected database
#
# Parameters: None
#---------------------------------------------------------------------------------------------

sub GetDatabaseVersion {

    my $dbv = $tm->get_DB_property(
        Property_Name       =>  "DatabaseVersion"       ,
        Property_Default    =>  "-1"                    ,
    );

    return $dbv;
}

#=============================================================================================
# Method: Check_AC_Tag
#
# Checks whether a required attribute category tage has been provided
#=============================================================================================

sub Check_AC_Tag {

    my $tag        = shift;
    my $attcat     = shift;

    if ( not exists( $i{ $tag } ) ) {
        $msg = "Tag <".$tag."> is required for Attribute Category [ ".$attcat." ].";
        UpdateMessageStack( $msg, "FATAL" );
    }
}

#=============================================================================================
# Method: InitGlobals 
#
# Initialise the globals variables, error counters etc to empty values
#=============================================================================================

sub  InitGlobals {

    $Fcount         = 0;
    $Wcount         = 0;
    $AuctionKey     = 0;
    $errorflag      = 0;
    $#Messages      = -1;
    $MessageData    = "";

    UpdateAPIProperties();
}

#=============================================================================================
# Method: UpdateAPIProperties 
#
# Update the API Property values from the internal global variables
#=============================================================================================

sub  UpdateAPIProperties {

    $FatalCount     = $Fcount;
    $WarningCount   = $Wcount;
    $ErrorStatus    = $errorflag;
    $MessageCount   = scalar( @Messages );
    $MessageData    = \@Messages;
}

#=============================================================================================
# Method: UpdateMessageStack 
#
# Update the Message stack and message counters and Error flag
#=============================================================================================

sub UpdateMessageStack {

    my $msg = shift;
    my $sev = shift;

    if ( uc( $sev ) eq "FATAL" ) {
        $msg = "  Fatal: ".$msg;
        $tm->{ Debug } ge "0" ? ( push ( @Messages, $msg ) ):();
        $Fcount++;
        $errorflag = -1;
    }
    elsif ( uc( $sev ) eq "WARNING" ) {
        $msg = "Warning: ".$msg;
        $tm->{ Debug } ge "1" ? ( push ( @Messages, $msg ) ):();
        $Wcount++;
    }
    elsif ( uc( $sev ) eq "DEBUG" ) {
        $msg = "  Debug: ".$msg;
        $tm->{ Debug } ge "2" ? ( push ( @Messages, $msg ) ):();
    }

    $tm->update_log( $msg )
}

1;



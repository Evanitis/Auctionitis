#!perl -w
#---------------------------------------------------------------------------------------------
# TradeMe automation and interaction package module
#
# Copyright 2002, Evan Harris.  All rights reserved.
# See user documentation at the end of this file.  Search for =head
#---------------------------------------------------------------------------------------------

package Auctionitis;

use strict;
use Fcntl;                                  # Supplies O_RDONLY and other constant file values
use LWP::Simple;
use LWP::UserAgent;
use URI::URL;
use URI::Escape;
use MIME::Lite;
use Net::SMTP;
use MIME::Base64;
use HTTP::Request;
use HTTP::Response;
use HTTP::Headers;
use HTTP::Response;
use HTTP::Cookies;
use HTTP::Request::Common qw(POST);
use HTML::TokeParser;
use DBI;
use Win32::TieRegistry; #TODO
use IO::File;
use XML::Writer; 
use XML::Parser;
use XML::Simple;
use Unicode::String;
use File::Spec;
use File::Basename;

require Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw(
    Z_DELETE Z_NOSTOCK Z_REMOVE Z_CANLIST Z_NEWITEM Z_EXCLUDE Z_SLOW Z_DEAD
    STS_CLONE STS_TEMPLATE STS_CURRENT STS_SOLD STS_UNSOLD STS_RELISTED
    SITE_TRADEME SITE_SELLA SITE_TANDE SITE_ZILLION
    INFO DEBUG VERBOSE WARNING ERROR
);

my $VERSION = "3.0";
sub Version { $VERSION; }

# class variables

my ($ua, $sa, $url, $req, $response, $content, $dbh, $sdb);

my $logfile;        # name and location of current log file
my $oldlog;         # name and location of previous log file when rolled over
my $returncode;     # numeric code returned to indicate error

# pre-prepared SQL statement handles

my $sth_is_DBauction_104;
my $sth_get_auction_key;
my $sth_get_auction_record;
my $sth_update_auction_record;
my $sth_set_auction_closed;
my $sth_delete_picture_record;
my $sth_delete_auction_record;
my $sth_DCLog;
my $SQL_update_stock_on_hand;           # Update stock On hand for a product code

# Setup the registry delimiter value and global variables

my $pound = $Registry->Delimiter("/");  #TODO
my $key;

# Debug Indicator

my $debug = 1;

##############################################################################################
#                         C O N S T A N T S                                                  #
##############################################################################################

use constant {
    Z_DELETE        => 'Z-DELETE'   ,
    Z_NOSTOCK       => 'Z-NOSTOCK'  ,
    Z_REMOVE        => 'Z-REMOVE'   ,
    Z_CANLIST       => 'Z-CANLIST'  ,
    Z_NEWITEM       => 'Z-NEWITEM'  ,
    Z_EXCLUDE       => 'Z-EXCLUDE'  ,
    Z_SLOW          => 'Z-SLOW'     ,
    Z_DEAD          => 'Z-DEAD'     ,
    STS_CLONE       => 'CLONE'      ,
    STS_TEMPLATE    => 'TEMPLATE'   ,
    STS_CURRENT     => 'CURRENT'    ,
    STS_SOLD        => 'SOLD'       ,
    STS_UNSOLD      => 'TEMPLATE'   ,
    STS_RELISTED    => 'RELISTED'   ,
    SITE_TRADEME    => 'TRADEME'    ,
    SITE_SELLA      => 'SELLA'      ,
    SITE_TANDE      => 'TANDE'      ,
    SITE_ZILLION    => 'ZILLION'    ,
    INFO            => 'INFO'       ,
    DEBUG           => 'DEBUG'      ,
    VERBOSE         => 'VERBOSE'    ,
    WARNING         => 'WARNING'    ,
    ERROR           => 'ERROR'      ,
};

##############################################################################################
# --- Methods/Subroutines ---
##############################################################################################

#=============================================================================================
# New() Create new TradeMe object;
# e.g. my $tm = TradeMe->new()
#=============================================================================================

sub new {

    my $class = shift;
    my $self  = { @_ };
    bless ( $self, $class );

    return $self;
}

# Return to allow inheritance _init method to work correctly when Auctionitis is called object

sub _init {

    my $class = shift;
    return;
}

#=============================================================================================
# Initialise object with product specific parameters
#
# Example usage:
#
# $tm->initialise(Product => <product value>,
#                 Profile => <user profile>)
#
# If no profile is specified profile will be set to the special value of "Default"
#
# Valid Products: Auctionitis; Jafa
#=============================================================================================

sub initialise {

    my $self = shift;
    my $parms = {@_};

    # Set the error indicator properties

    $self->clear_err_structure();

    # Set the connected property

    $self->{is_connected} = 0;

    # This code allows browser functions to be used
    # create the LWP user agent object and configure it to accept cookies 

    $ua = LWP::UserAgent->new();
    $ua->agent("Auctionitis/V3.0.1564");
    push @{$ua->requests_redirectable}, 'POST';  # Added 29/04/05
    
    # set proxy for debug purposes [use with wsp proxy tool, webscarab or fiddler]

    # $ua->proxy("http", "http://localhost:5364");                          # wsp
    # $ua->proxy("http", "http://localhost:8888");                          # Fiddler
    # $ua->proxy("http", "http://localhost:8080");                          # Webscarab

    # Enable cookies but do not save between sessions
    
    $ua->cookie_jar( {} );                                                  # added 20/09/06 replaced next two lines
    $ua->cookie_jar->clear();                                               # added 15/04/08 to get rid of session baggage

    # $ua->cookie_jar(HTTP::Cookies->new(file       => "lwpcookies.txt",    # superceded/removed 20/09/06
    #                                    autosave   => 1));                 # Superceded/removed 20/09/06
                                       
    # Check the profile parameter; if no value passed set profile to "Default"
    
    if     ( not defined( $parms->{ Profile } ) )   { $self->{ Profile } = "Default";               }
    else                                            { $self->{ Profile}  = $parms->{Profile};       }

    # Check whether a product was specified and exit if no product provided
    
    if     (not defined($parms->{Product}))   { 
            $self->{Feedback} = "No product specified; processing terminated";
            $returncode = 0;
            return $returncode;
            exit;
    }

    # Check that product is valid and exit if product is unknown

    if    ( uc( $parms->{Product} ) eq "AUCTIONITIS") { $self->{Product} = uc( $parms->{Product} ); } 
    elsif ( uc( $parms->{Product} ) eq "STANDALONE")  { $self->{Product} = uc( $parms->{Product} ); } 
    elsif ( uc( $parms->{Product} ) eq "PICKUP")      { $self->{Product} = uc( $parms->{Product} ); } 
    elsif ( uc( $parms->{Product} ) eq "JAFA")        { $self->{Product} = uc( $parms->{Product} ); } 
    else  {
            $self->{Feedback} = "Unknown product ".$parms->{Product}." specified; processing terminated";
            $returncode = 0;
            return $returncode;
            exit;
    }

    #-----------------------------------------------------------------
    # Processing for AUCTIONITIS
    #-----------------------------------------------------------------

    if  ( $self->{Product} eq "AUCTIONITIS" ) {
    
        # Set up Product Properties (retrieved from the registry) #TODO

        $key   = $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Properties"}
                 or die "Package Auctionitis.pm can't read LMachine/System/Disk key: $^E\n";

        $self->{ UserID                 }   =   $key->{ "/AccountName"            };
        $self->{ Password               }   =   $key->{ "/AccountPassword"        };
        $self->{ TradeMeID              }   =   $key->{ "/TradeMeID"              };
        $self->{ DataBaseName           }   =   $key->{ "/DataBaseName"           };
        $self->{ ServiceURL             }   =   $key->{ "/ServiceURL"             };
        $self->{ UseProxy               }   =   $key->{ "/UseProxy"               };
        $self->{ ProxyAddress           }   =   $key->{ "/ProxyAddress"           };
        $self->{ ProxyPort              }   =   $key->{ "/ProxyPort"              };
        $self->{ SellaAPIURL            }   =   $key->{ "/SellaAPIURL"            };
        $self->{ SellaPassword          }   =   $key->{ "/SellaPassword"          };
        $self->{ SellaEmail             }   =   $key->{ "/SellaEmail"             };
        # Moved to DBCOnnect method - rethink this strategy...

        # $self->{ CategoryServiceDate    }   =   $self->get_DB_property(
        #                                            Property_Name       =>  "CategoryServiceDate"   ,
        #                                            Property_Default    =>  "01-01-2006"            ,
        #                                        );

        # Set up Processing Options (retrieved from the registry)

        $key   = $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Options"}
                 or die "Package Auctionitis.pm can't read LMachine/System/Disk key: $^E\n";

        foreach my $field ( keys(%$key) ) {
                 $self->{ substr( $field,1 ) } = $key->{ $field };
        }

        $logfile = $self->{ LogDirectory }."\\"."logfile.log";
        $oldlog  = $self->{ LogDirectory }."\\"."previous.log";

        # Create the Sella BrowserObject

        $sa = LWP::UserAgent->new();
        $sa->agent("Auctionitis/V3.0.1564");

        my $auth = encode_base64("$self->{ SellaEmail }:$self->{ SellaPassword }");
        $sa->default_headers->push_header('Authorization' => 'Basic '.$auth);

        push @{ $sa->requests_redirectable }, 'POST';  # Added 29/04/05

        # Enable cookies but do not save between sessions

        $sa->cookie_jar( {} );                                                  # added 20/09/06 replaced next two lines
        $sa->cookie_jar->clear();                                               # added 15/04/08 to get rid of session baggage

        # set proxy for debug purposes [use with wsp proxy tool]
        
        if ( $self->{ UseProxy } ) {
            $ua->proxy("http", "http://".$self->{ ProxyAddress }.":".$self->{ ProxyPort } );
            $sa->proxy("http", "http://".$self->{ ProxyAddress }.":".$self->{ ProxyPort } );
        }
        
    }

    #-----------------------------------------------------------------
    # Processing for JAFA
    #-----------------------------------------------------------------

    if  ( $self->{Product} eq "JAFA" ) {

        # Setup the registry value applicable to the product

        $key   = $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/JAFA/Personalities/".$self->{Profile}."/Properties"}
                 or die "an't read LMachine/System/Disk key: $^E\n";

        # retrieve JAFA settings from the registry

        $self->{UserID}         = $key->{"/UserID"};                # TradeMe User ID
        
        
        $self->{Password}       = $key->{"/Password"};              # TradeMe password
        $self->{DataDirectory}  = $key->{"/DataDirectory"};         # Product Data Directory
        $self->{ResponseFile}   = $key->{"/ResponseFile"};          # Response File
        $self->{InputFile}      = $key->{"/InputFile"};             # Input File
        $self->{TrustWeb}       = $key->{"/TrustWeb"};              # Trust-Web (Y/N)

        # Validate that all required properties are available and valid

        if  ( not defined($self->{UserID}) || ($self->{UserID} = "") ) {

            $self->{ErrorStatus}  = "1";
            $self->{ErrorMessage} = "User ID for $self->{Product} (profile $self->{Profile}) has not been entered";
            return;
        }

        if  ( not defined($self->{Password}) || ($self->{Password} = "") ) {

            $self->{ErrorStatus}  = "1";
            $self->{ErrorMessage} = "TradeMe Password for $self->{Product} (profile $self->{Profile}) has not been entered";
            return;
        }

        if  ( not defined($self->{DataDirectory}) || ($self->{DataDirectory} = "") ) {

            $self->{ErrorStatus}  = "1";
            $self->{ErrorMessage} = "Data Directory for $self->{Product} (profile $self->{Profile}) has not been entered";
            return;
        }

        if  ( not defined($self->{ResponseFile}) || ($self->{ResponseFile} = "") ) {

            $self->{ErrorStatus}  = "1";
            $self->{ErrorMessage} = "Feedback Response file for $self->{Product} (profile $self->{Profile}) not entered";
            return;
        }

        if  ( not defined($self->{InputFile}) || ($self->{InputFile} = "") ) {

            $self->{ErrorStatus}  = "1";
            $self->{ErrorMessage} = "Feedback Input file for $self->{Product} (profile $self->{Profile}) not entered";
            return;
        }

        # values for maintaining the log files

        $logfile = $self->{DataDirectory}."\\"."logfile.log";
        $oldlog  = $self->{DataDirectory}."\\"."previous.log";
    }
    
    #-----------------------------------------------------------------
    # Processing for PICKUP
    #-----------------------------------------------------------------

    if  ( $self->{Product} eq "PICKUP" ) {

        # Setup the registry value applicable to the product

        $key   = $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Pick-Up/Personalities/".$self->{Profile}."/Properties"}
                 or die "Package Auctionitis.pm can't read LMachine/System/Disk key: $^E\n";

        # retrieve Pick-up settings from the registry

        $self->{ UserID             } = $key->{ "/UserID"           };        # TradeMe User ID
        $self->{ Password           } = $key->{ "/Password"         };        # TradeMe password
        $self->{ InputDirectory     } = $key->{ "/InputDirectory"   };        # Photo Input Directory
        $self->{ OutputDirectory    } = $key->{ "/OutputDirectory"  };        # Photo Output Directory
        $self->{ LogDirectory       } = $key->{ "/LogDirectory"     };        # Log Directory

        # Validate that all required properties are available and valid

        if  ( not defined($self->{UserID}) || ($self->{UserID} = "") ) {

            $self->{ErrorStatus}  = "1";
            $self->{ErrorMessage} = "User ID for $self->{Product} (profile $self->{Profile}) has not been entered";
            return;
        }

        if  ( not defined($self->{Password}) || ($self->{Password} = "") ) {

            $self->{ErrorStatus}  = "1";
            $self->{ErrorMessage} = "TradeMe Password for $self->{Product} (profile $self->{Profile}) has not been entered";
            return;
        }

        if  ( not defined($self->{InputDirectory}) || ($self->{InputDirectory} = "") ) {

            $self->{ErrorStatus}  = "1";
            $self->{ErrorMessage} = "Input Directory for $self->{Product} (profile $self->{Profile}) has not been entered";
            return;
        }

        if  ( not defined($self->{OutputDirectory}) || ($self->{OutputDirectory} = "") ) {

            $self->{ErrorStatus}  = "1";
            $self->{ErrorMessage} = "Data Directory for $self->{Product} (profile $self->{Profile}) has not been entered";
            return;
        }

        # values for maintaining the log files

        $logfile = $self->{LogDirectory}."\\"."logfile.log";
        $oldlog  = $self->{LogDirectory}."\\"."previous.log";
    }

    # Set the Debug Values
    
    if     ( not defined( $self->{ Debug        } ) )      { $self->{ Debug         } = "0" ;   }
    if     ( not defined( $self->{ DebugCookies } ) )      { $self->{ DebugCookies  } = "0" ;   }
}


#=============================================================================================
# Clear the Auctionitis Error structure
#=============================================================================================

sub clear_err_structure {

    my $self = shift;

    # Clear error indicator and error message properties

    $self->{ErrorStatus}    =   "0";    # returns true if there has been an error
    $self->{ErrorCode}      =   "0";    # returns an error code in the event of an error
    $self->{ErrorMessage}   =   "";     # returns 1st level error message (always present)
    $self->{ErrorDetail}    =   "";     # retruns 2nd level error message data (may be blank)
}

#=============================================================================================
# Function to fill each error structure and return it for inter-operability testing
#=============================================================================================

sub test_err_structure {

    my $self = shift;

    # Clear error indicator properties

    $self->clear_err_structure();

    # Set the error indicator test values
   
    $self->{ErrorStatus}    = "1";
    $self->{ErrorCode}      = "9999";
    $self->{ErrorMessage}   = "First level text of error message";
    $self->{ErrorDetail}    = "Second level text of error message (the long-winded bit)";

}

#=============================================================================================
# check_license
# Check whether the mailmate profile has a valid license
#=============================================================================================

sub valid_license {

    my $self  = shift;
    
    my ($KeyExpiry, $KeyInput, $KeyValue, $KeyProduct, $KeyStatus, $KeyOK, $key, $value);

    # Set returncode to false until verified

    my $returncode = 0;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    # Clear error indicator and error message properties

    $self->clear_err_structure();


    #-----------------------------------------------------------------
    # Processing for AUCTIONITIS
    #-----------------------------------------------------------------

    if  ( $self->{Product} eq "AUCTIONITIS" ) {
    
        # Setup the registry value applicable to the product

#        $key = $Registry->{"HKEY_CURRENT_USER/Software/VB and VBA Program Settings/Auctionitis/Options"};
        $key = $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Properties"};

        # key not retrieved from registry
        
        if  ( not defined($key) ) {
        
            $self->{ErrorStatus}  = "1";
            $self->{ErrorMessage} = "Product $self->{Product} not found or not installed correctly";
            return $returncode;

        }

        # Check license key exists

        $KeyValue = $key->{"/AuctionitisKey"};

        if  ( not defined($KeyValue) || ($KeyValue = "") ) {

            $self->{ErrorStatus}  = "1";
            $self->{ErrorMessage} = "License Key for $self->{Product} has not been entered";
            return $returncode;
        }

        # No User ID/email address exists

        $KeyInput = $key->{"/TradeMeID"};

        if  ( not defined($KeyInput) || ($KeyInput = "") ) {

            $self->{ErrorStatus}  = "1";
            $self->{ErrorMessage} = "TradeMe Account name for $self->{Product} has not been entered";
            return $returncode;
        }

        # No Key expiry date

        $KeyExpiry = $key->{"/KeyExpiryDate"};

        if  ( not defined($KeyExpiry) || ($KeyExpiry = "") ) {

            $self->{ErrorStatus}  = "1";
            $self->{ErrorMessage} = "Key Expiry Date for $self->{Product} has not been entered";
            return $returncode;
        }
    }

    #-----------------------------------------------------------------
    # Processing for JAFA
    #-----------------------------------------------------------------

    if  ( $self->{Product} eq "JAFA") {

        # Setup the registry value applicable to the product

        $key = $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/JAFA/Personalities/".$self->{Profile}."/Properties"};

        # key not retrieved from registry

        if  ( not defined($key) ) {
        
            $self->{ErrorStatus}  = "1";
            $self->{ErrorMessage} = "Product $self->{Product} not found or not installed correctly";
            return $returncode;

        }

        # Check license key exists

        $KeyValue = $key->{"/LicenseKey"};

        if  ( (not defined($KeyValue)) || ($KeyValue eq "") ) {

            $self->{ErrorStatus}  = "1";
            $self->{ErrorMessage} = "License Key for $self->{Product} (profile $self->{Profile}) has not been entered";
            return $returncode;
        }

        # No User ID/email address exists

        $KeyInput = $key->{"/UserID"};

        if  ( (not defined($KeyInput)) || ($KeyInput eq "") ) {

            $self->{ErrorStatus}  = "1";
            $self->{ErrorMessage} = "User ID for $self->{Product} (profile $self->{Profile}) has not been entered";
            return $returncode;
        }

        # No Key expiry date

        $KeyExpiry = $key->{"/ExpiryDate"};

        if  ( not defined($KeyExpiry) || ($KeyExpiry eq "") ) {

            $self->{ErrorStatus}  = "1";
            $self->{ErrorMessage} = "Key Expiry Date for $self->{Product} (profile $self->{Profile}) has not been entered";
            return $returncode;
        }
    }

    #-----------------------------------------------------------------
    # Perform key validation once product details retrieved & verified
    #-----------------------------------------------------------------

    my $xKey = Win32::OLE->new('AuctXKey.modAuctXKey');

    if  ( not defined($xKey) ) {

        $self->{ErrorStatus}  = "1";
        $self->{ErrorMessage} = "Error checking license key; not all components not installed correctly";
        return $returncode;
    }

    $xKey->{KeyProduct} = $self->{Product};     # product Name
    $xKey->{KeyValue}   = $KeyValue;            # License key value
    $xKey->{KeyInput}   = $KeyInput;            # USer value portion of license key
    $xKey->{KeyExpiry}  = $KeyExpiry;           # key expiry date

    $xKey->CheckKey();                          # ActiveX Check key function

    if  ( $xKey->{KeyOK}) { $returncode = 1; }  # set return code to true when verified
    
    if  ( $xKey->{KeyStatus} eq "Expired") {

        $self->{ErrorStatus}  = "1";
        $self->{ErrorMessage} = "License key for product $self->{Product} (profile $self->{Profile}) has expired";
        return $returncode;

    }
    if  ($xKey->{KeyStatus} eq "Invalid") {

        $self->{ErrorStatus}  = "1";
        $self->{ErrorMessage} = "License key for product $self->{Product} (profile $self->{Profile}) is invalid";
        return $returncode;
    }

    # if we reach this statement return returncode value indicating license is valid (or we havent dropped out correctly)
    
    return $returncode;
}

#=============================================================================================
# Method    : dump_properties
# Added     : 4/12/05
# Input     : 
# Returns   : dumps the Auctionitis properties to the auctionitis log
#=============================================================================================

sub dump_properties {

    my $self    = shift;
    
    $self->update_log("*-------------------------------------------------------------------");
    $self->update_log("* Auctionitis Property Dump");
    $self->update_log("*-------------------------------------------------------------------");

    foreach my $property ( sort keys %$self ) {
        if ( ( $property ne "AccountPassword" ) and  ( $property ne "SellaPassword" ) ) {
             if ( $property ne "Password" )     {
                  my $spacer = " " x ( 40-length( $property ) ) ;

                  # update the log with the  output

                  $self->update_log( $property.":".$spacer.$self->{ $property } );
             }
        }
    }
    return;
}


#=============================================================================================
# Set Schedule properties
#=============================================================================================

sub set_Schedule_properties {

    my $self = shift;

    my $scheduleday = shift;
    
    # Clear error indicator and error message properties

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    $self->clear_err_structure();

    # Set up Processing Options (retrieved from the registry)

    $key   = $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Schedule/#".$scheduleday};

    foreach my $field ( keys(%$key) ) {
             $self->{ substr( $field,1 ) } = $key->{ $field };
    }
}

#=============================================================================================
# CurrencyFormat
# Used for rounding numbers to 2 decimal places and placing a
# Dollar sign ($) in front
# It also adds in commas as thousand markers and adds a negative sign
# if necessary
#=============================================================================================

sub CurrencyFormat {

    my $self   = shift;
    my $number = shift;
    my $minus  = 0;

    $number =~ s/,//g;                   # Remove any commas.
    $number =~ s/\$//g;                  # Remove any dollar signs.
    if ($number < 0) {$minus = 1;}       # set flag if negative
    $number =~ s/\-//g;                  # Remove any negative signs
    $number =  sprintf "%.2f",$number;   # Round to 2 decimal places

    my @arrTemp = split(/\./,$number);   # Split based on the cents.
    my $strFormatted;
    my $nbrComma;                        # Counter for comma output.

    $arrTemp[0]  = reverse($arrTemp[0]); # Reverse string of numbers.
    my $nbrFinal = length($arrTemp[0]);  # Get no of chars in the no.

    #Loop through and add the commas.
    for (my $nbrCounter = 0; $nbrCounter < $nbrFinal; $nbrCounter++) {
         $nbrComma++;
         my $strChar = substr($arrTemp[0],$nbrCounter,1);
         if     ($nbrComma == 3 && $nbrCounter < ($nbrFinal - 1)){
                 $strFormatted .= "$strChar,";
                 $nbrComma = 0;
         } else {
                 $strFormatted .= $strChar;
                }
         }
    $strFormatted = reverse($strFormatted); #reverse back to normal

    #Add the dollar sign and put the cents back on.
    $number = '$' . $strFormatted . '.' . $arrTemp[1];


    #Add minus sign on end if number was negative
    if ($minus) {$number = $number."-";}

    return $number;
}

#=============================================================================================
# Method    : datenow
# Added     : 25/06/05
# Input     : 
# Returns   : String formatted as data in dd-mm-ccyy format including padded zeros
#=============================================================================================

sub datenow {

    my $self   = shift;
    my ($date, $day, $month, $year);

    # Set the day value

    if   ( (localtime)[3] < 10 )        { $day = "0".(localtime)[3]; }
    else                                { $day = (localtime)[3]; }

    # Set the month value
    
    if   ( ((localtime)[4]+1) < 10 )    { $month = "0".((localtime)[4]+1); }
    else                                { $month = ((localtime)[4]+1) ; }

    # Set the century/year value

    $year = ((localtime)[5]+1900);

    $date = $day."-".$month."-".$year;
    
    return $date;
}

#=============================================================================================
# Method    : timenow
# Added     : 25/06/05
# Input     : 
# Returns   : String formatted as time in hh:mm:ss format including padded zeros
#=============================================================================================

sub timenow {

    my $self   = shift;
    my ($time, $hour, $min, $sec);

    # Set the hour value

    if   ( (localtime)[2] < 10 )                    { $hour = "0".(localtime)[2]; }
    else                                            { $hour = (localtime)[2] ; }
    
    # Set the minute value
    
    if   ( (localtime)[1] < 10 )                    { $min = "0".(localtime)[1]; }
    else                                            { $min = (localtime)[1] ; }

    # Set the second value

    if   ( (localtime)[0] < 10 )                    { $sec = "0".(localtime)[0]; }
    else                                            { $sec = (localtime)[0] ; }


    $time = $hour.":".$min.":".$sec;
    
    return $time;
}

#=============================================================================================
# Method    : closedate
# Added     : 25/06/05
# Input     : duration (in minutes)
# Returns   : String formatted as data in dd/mm/ccyy format including padded zeros
#           : Date returned is calculated date of today plus duration period
#=============================================================================================

sub closedate {

    my $self    = shift;
    my $elapsed = shift;
    my ($date, $day, $month, $year);
                                                    
    my $closetime = time + ($elapsed * 60);         # New time = now + duration in seconds

    # Set the day value

    if   ( ((localtime($closetime))[3]) < 10 )      { $day = "0".(localtime($closetime))[3]; }
    else                                            { $day = (localtime($closetime))[3]; }

    # Set the month value
    
    if   ( ((localtime($closetime))[4]+1) < 10 )    { $month = "0".((localtime($closetime))[4]+1); }
    else                                            { $month = ((localtime($closetime))[4]+1) ; }

    # Set the century/year value

    $year = ( (localtime($closetime))[5]+1900 );

    $date = $day."-".$month."-".$year;
    
    return $date;
}

#=============================================================================================
# Method    : closetime
# Added     : 25/06/05
# Input     : duration (in minutes)
# Returns   : String formatted as time in hh:mm:ss format including padded zeros
#           : Date returned is calculated date of today plus duration period
#=============================================================================================

sub closetime {

    my $self    = shift;
    my $elapsed = shift;
    my ($time, $hour, $min, $sec);

    my $closetime = time + ($elapsed * 60);         # New time = now + duration in seconds

    # Set the hour value

    if   ( ((localtime($closetime))[2]) < 10 )      { $hour = "0".((localtime($closetime))[2]); }
    else                                            { $hour = ((localtime($closetime))[2]) ; }
    
    # Set the minute value
    
    if   ( ((localtime($closetime))[1]) < 10 )      { $min = "0".((localtime($closetime))[1]); }
    else                                            { $min = ((localtime($closetime))[1]) ; }


    # Set the second value

    if   ( ((localtime($closetime))[0]) < 10 )      { $sec = "0".((localtime($closetime))[0]); }
    else                                            { $sec = ((localtime($closetime))[0]) ; }

    $time = $hour.":".$min.":".$sec;
    
    return $time;
}

#=============================================================================================
# Method    : fixeddate
# Added     : 17/09/06
# Input     : numeric value indicating number of days auction is to run for
#           : (Number can be from 0 to 10, 0 indicating today)
# Returns   : String formatted as data in dd/mm/ccyy format including padded zeros
#           : Date returned is calculated date of today plus duration period
#=============================================================================================

sub fixeddate {

    my $self    = shift;
    my $days    = shift;
    my ($date, $day, $month, $year);

    # New date = now + duration in seconds (number of days X 24 (hrs) X 60 (mins) X 60 (secs)
                                                    
    my $closetime = time + ($days * 24 * 60 * 60);      

    # Set the day value

    if   ( ((localtime($closetime))[3]) < 10 )      { $day = "0".(localtime($closetime))[3]; }
    else                                            { $day = (localtime($closetime))[3]; }

    # Set the month value
    
    if   ( ((localtime($closetime))[4]+1) < 10 )    { $month = "0".((localtime($closetime))[4]+1); }
    else                                            { $month = ((localtime($closetime))[4]+1) ; }

    # Set the century/year value

    $year = ( (localtime($closetime))[5]+1900 );

    $date = $day."-".$month."-".$year;
    
    return $date;
}

#=============================================================================================
# Method    : fixedtime
# Added     : 17/09/06
# Input     : numeric value indicating number of 15 minute increments from midnight
# Returns   : String formatted as time in hh:mm:ss format including padded zeros
#           : Date returned is calculated date of today plus duration period
#=============================================================================================

sub fixedtime {

    my $self    = shift;
    my $period  = shift;
    my ($time, $hour, $min, $sec);

    # closing hour = integer portion of number of intervals divided by 4
    # closing mins = equals number of periods not converted to hours * 15

    my $closehour = int($period / 4);             
    my $closemins = ($period - ($closehour * 4)) * 15;             

    # Set the hour value

    if   ( $closehour < 10 )                        { $hour = "0".$closehour;   }
    else                                            { $hour = $closehour    ;   }
    
    # Set the minute value
    
    if   ( $closemins < 10 )                        { $min = "0".$closemins ;    }
    else                                            { $min = $closemins     ;    }

    $sec = "00" ;

    $time = $hour.":".$min.":".$sec;
    
    return $time;
}

#=============================================================================================
# Method    : TMFixedEndDate
# Added     : 17/09/06
# Input     : numeric value indicating number of days auction is to run for
#           : (Number can be from 0 to 10, 0 indicating today)
# Returns   : String formatted as data in dd/mm/ccyy format including padded zeros
#           : Date returned is calculated date of today plus duration period
#           : This is the string used to specify the end time in Fixed End Auctions by TradeMe
#=============================================================================================

sub TMFixedEndDate {

    my $self    = shift;
    my $days    = shift;

    my ($date, $day, $month, $year);

    # New date = now + duration in seconds (number of days X 24 (hrs) X 60 (mins) X 60 (secs)
                                                    
    my $closetime = time + ($days * 24 * 60 * 60);      

    # Set the day value

    if   ( ((localtime($closetime))[3]) < 10 )      { $day = "0".(localtime($closetime))[3]; }
    else                                            { $day = (localtime($closetime))[3]; }

    # Set the month value
    
    if   ( ((localtime($closetime))[4]+1) < 10 )    { $month = "0".((localtime($closetime))[4]+1); }
    else                                            { $month = ((localtime($closetime))[4]+1) ; }

    # Set the century/year value

    $year = ( (localtime($closetime))[5]+1900 );

    $date = $day."/".$month."/".$year;
    
    return $date;
}

#=============================================================================================
# Method    : TMFixedEndTime
# Added     : 06/01/08
# Input     : numeric value indicating number of 15 minute increments from midnight
# Returns   : String formatted as time in hh:mm am/pm format including padded zeros
#           : This is the string used to specify the end time in Fixed End Auctions by TradeMe
#=============================================================================================

sub TMFixedEndTime {

    my $self    = shift;
    my $period  = shift;

    my ($time, $hour, $min, $ampm);

    # closing hour = integer portion of number of intervals divided by 4
    # closing mins = equals number of periods not converted to hours * 15

    my $closehour = int($period / 4);             
    my $closemins = ($period - ($closehour * 4)) * 15;             

     # Set the minute value
    
    if   ( $closemins < 10 )                        { $min = "0".$closemins ;    }
    else                                            { $min = $closemins     ;    }

    # Set the am/pm value
    
    if   ( $closehour < 12 )                        { $ampm = "am"          ;    }
    else                                            { $ampm = "pm"          ;    }

    # Modify hours to twelve hour format
    
    if   ( $closehour > 12 )                        { $closehour -= 12      ;    }

    # Set the hour value

    if   ( $closehour < 10 )                        { $hour = "0".$closehour;   }
    else                                            { $hour = $closehour    ;   }

    $time = $hour.":".$min. " ".$ampm;
    
    return $time;
}

#=============================================================================================
# Method    :   is_internet_connected
# Added :   14/04/07        
# Input         : 
# Returns   :   Boolean
#                            
# This function access the trademe website to return an internet connection status
#=============================================================================================

sub is_internet_connected {

    my $self = shift;           # Auctionitis object
    my $retval = 0;
    
    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    $self->clear_err_structure();
    
    # Try connecting to the Auctionitis Service URL
    
    $url = $self->{ServiceURL}."/Category_Control.html";

    $self->update_log("Testing Connection to URL: ".$url);

    $req       = HTTP::Request->new(GET => $url);
    $response  = $ua->request($req);

    if ($response->is_error()) {
    
        # If the reponse is an error Try connecting to theTradeMe Statistics page
        
        $url = "http://www.trademe.co.nz/Community/SiteStats.aspx";

        $self->update_log("Testing Connection to URL: ".$url);

        $req       = HTTP::Request->new(GET => $url);
        $response  = $ua->request($req);

        if ($response->is_error()) {
            $retval = 1;
        }
        else {
            $retval = 0;
        }
    }
    else {
        $retval = 0;
    }
    
    return $retval;
}

#=============================================================================================
# Login(); connec to the trademe website
# e.g. my tm = TradeMe->login()
# Logs into Trademe and sets other values used for controlling trademe
# processing:
# curr_listings: number of current auction listsings including permanent listings
# curr_listings_pp: no. of current listsings per page (used for calculating control loops)
# curr_pages: no of pages with current auction data
# comp_listings: number of completed auction listings
# comp_listings_pp: no. of completed listings per page (used for calculating control loops)
# comp_pages: no of pages with completed auction data
#=============================================================================================

sub login {

    my $self  = shift;
    my $p          = { @_ };

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;
    $self->clear_err_structure();

    # Check whether the Log in details have been passed in as parameters - allows us to 
    # Override who we log on as in scripts

    if ( not defined $p ) {
        $p->{ TradeMeID } = $self->{ TradeMeID  };
        $p->{ UserID    } = $self->{ UserID     };
        $p->{ Password  } = $self->{ Password   };
    }

    if ( not defined $p->{ TradeMeID } ) {
        $p->{ TradeMeID } = $self->{ TradeMeID  };
    }

    if ( not defined $p->{ UserID } ) {
        $p->{ UserID    } = $self->{ UserID   };
    }

    if ( not defined $p->{ Password } ) {
        $p->{ Password  } = $self->{ Password   };
    }

    # -- S E T T I N G   U P   A C C O U N T --
    # log into trademe using CGI POST form values
    # field names and values were obtained by examining the source of the login.asp page
    # if it stops operating at any stage this would be the place to start...

    $self->{Debug} ge "1" ? ( $self->update_log( "TradeMe log in process" ) ) : ();

    $self->{ DebugCookies } ge "1" ? ( $self->update_log( "Cookie store BEFORE log in" ) ) : ();
    $self->{ DebugCookies } ge "1" ? ( $self->dump_cookies() ) : ();

    # 12/11/07 - TradeMe added Secure log in - HTTPS with a session ID in the header

    $url = "http://www.trademe.co.nz/Members/Login.aspx";                   # 12/11/07

    $req       = HTTP::Request->new(GET => $url);
    my $stuff = $ua->request($req)->as_string;

    $stuff =~ m/(session=\{)(.+?)(\})/gs;
    $url = "https://secure.trademe.co.nz/Members/SecureLogin.aspx?session={".$2."}.aspx";

    $self->update_log("TradeMe Secure Login URL extracted: $url");

    $req = POST $url, [url            =>  ""                ,               # 12/11/07
                       email          =>  $p->{ UserID   }  ,               # 12/11/07
                       password       =>  $p->{ Password }  ,               # 12/11/07
                       login_attempts =>  "0"               ,               # 12/11/07
                       submitted      =>  'Y'               ];              # 12/11/07

    $response  = $ua->request($req);
    print "HTTP Response code for login request: ".$response->status_line."\n";
    $self->update_log("HTTP Response code for login request: ".$response->status_line);

    $content = $ua->request($req)->as_string; # posts the data to the remote site i.e. logs in

    $self->{Debug} ge "2" ? ($self->update_log("POST URL: $url")) : ();
    $self->{Debug} ge "2" ? ($self->update_log("---------------------------------------------------")) : ();
    $self->{Debug} ge "2" ? ($self->update_log("$content")) : ();
    $self->{Debug} ge "2" ? ($self->update_log("---------------------------------------------------")) : ();

    # $content = $ua->request($req)->as_string; # posts the data to the remote site i.e. logs in
    
    # -- L O G G E D   I N --

    # Dump the cookies associated wiuth the user agent

    $self->{ DebugCookies } ge "1" ? ( $self->update_log( "Cookie store before AFTER log in" ) ) : ();
    $self->{ DebugCookies } ge "1" ? ( $self->dump_cookies() ) : ();

    # Clear the temporary cookies to get rid of any dross that might have been saved on Trademe

    # $ua->cookie_jar->clear_temporary_cookies();

    $self->{ DebugCookies } ge "1" ? ( $self->update_log( "Cookie store before AFTER log in" ) ) : ();
    $self->{ DebugCookies } ge "1" ? ( $self->dump_cookies() ) : ();

    $self->{is_connected} = 1;
    
    # get member id value

    #    $url="http://www.trademe.co.nz/structure/my_trademe.asp";
    
    $url="http://www.trademe.co.nz/MyTradeMe/Default.aspx";
    
    $req       = HTTP::Request->new(GET => $url);
    $response  = $ua->request($req);
    $content = $response->content();

    $self->{Debug} ge "2" ? ($self->update_log("GET URL: $url")) : ();
    $self->{Debug} ge "2" ? ($self->update_log("Content:\n---------------------------------------------------")) : ();
    $self->{Debug} ge "2" ? ($self->update_log("$content")) : ();
    $self->{Debug} ge "2" ? ($self->update_log("---------------------------------------------------")) : ();
    
    # Retrieve the Member number and Log in ID from the MyTradeMe page for
    # The log in ID will be used validating the license key
    # The member ID will be used for retrieving other data

    # if      ($content =~ m/(<br>You are member <b>)([0-9]+?)(<\/b>)/) {   # Old source superceded 8/12/04

    # <a href="/structure/show_member_listings.asp?member=457799"><font color=#0033cc><b>auctionitis</b>    # pre 10/05/2006
    # <a href="/Members/Listings.aspx?member=457799"><b>auctionitis</b></a>                                 # 10/05/2006
    # <a href="/Members/Listings.aspx?member=457799"><b>auctionitis</b>
    
    if ( $content =~ m/(\/Members\/Listings\.aspx\?member=)([0-9]+?)("><b>)(.+?)(<\/b>)/sg ) {
        $self->{ LoggedInID } = $4;
        $self->update_log("Logged into TradeMe using account ".$self->{ LoggedInID } );
    }
    else {
        $self->update_log("Could not extract the log in ID" );
        $self->update_log("- - - D A T A - - - " );
        $self->update_log($content );
        $self->update_log("- - - D A T A - - - " );
    }

    #<br /><small>You are member <b>457799</b>

    if ( $content =~ m/(<br \/><small>You are member <b>)([0-9]+?)(<\/b>)/sg ) {
        $self->{ MemberID } = $2;
        $self->update_log("Extracted TradeMe Member ID ".$self->{ MemberID } );
    }
    else { 
        $self->{ is_connected  }   =   0;
        $self->{ ErrorStatus   }   =   "1";
        $self->{ ErrorMessage  }   =   "Unable to log in to TradeMe";
        $self->{ ErrorDetail   }   =   "Could not log in to the TradeMe web site. The account password may be incorrect or the site may be down or not responding";
        $self->update_log("- - - D A T A - - - " );
        $self->update_log($content );
        $self->update_log("- - - D A T A - - - " );
        return;
    }
    
    # Check that the TradeMe ID displayed on the my trademe page is the same as the Licensed ID
    # Convert both values to upper case before comparing to avoid any differences in data entry

    if ( uc( $self->{ LoggedInID } ) ne uc( $p->{ TradeMeID } ) ) {

        $self->{ ErrorStatus   }   =   "1";
        $self->{ ErrorMessage  }   =   "TradeMe Account Name (".$self->{ LoggedInID }.") does not match license key ID";
        $self->{ ErrorDetail   }   =   "The TradeMe Account ID (".$self->{ LoggedInID }.") retrieved after logging on does not match the TradeMe ID for which the license key was issued(".$self->{ TradeMeID }.") .";
        return;
    }
    
    return $self->{is_connected};
}

#=============================================================================================
# Logout(); disconnect from the trademe website
# e.g. $tm->logout()
#=============================================================================================

sub logout {

    my $self  = shift;
    my $p          = { @_ };

    $self->{ Debug } ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;
    $self->clear_err_structure();

    $self->{ Debug } ge "1" ? ( $self->update_log( "Logging out of TradeMe" ) ) : ();

    $self->{ DebugCookies } ge "1" ? ( $self->update_log( "Cookie store BEFORE log out" ) ) : ();
    $self->{ DebugCookies } ge "1" ? ( $self->dump_cookies() ) : ();

    $url = "http://www.trademe.co.nz//Members/Logout.aspx?change_user=y";

    $req       = HTTP::Request->new(GET => $url);

    $self->{ DebugCookies } ge "1" ? ( $self->update_log( "Cookie store AFTER log out" ) ) : ();
    $self->{ DebugCookies } ge "1" ? ( $self->dump_cookies() ) : ();

    $self->{ is_connected } = 0;
    
}

#=============================================================================================
# dump_cookies
#=============================================================================================

sub dump_cookies {

    my $self = shift;

    # setup the callback reference for the cookie_jar->scan request

    my $printsub = sub { $self->print_cookie( @_ ) };

    $self->update_log( "Dumping Cookies" );
    $self->update_log( "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -" );
    $ua->cookie_jar->scan( $printsub );                                # print each cookie
    $self->update_log( "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -" );
    $self->update_log( "End of Dump" );

}

sub print_cookie {

    my $self        = shift;
    my $version     = shift;
    my $key         = shift;
    my $val         = shift;
    my $path        = shift;
    my $domain      = shift;
    my $port        = shift;
    my $pathspec    = shift;
    my $secure      = shift;
    my $expires     = shift;
    my $discard     = shift;
    my $hash        = shift;

    $key       ?  ( $self->update_log( "Key     : ".uri_unescape( $key      ) ) ) : ( $self->update_log( "Key     : Empty Value"  ) ) ; 
    $version   ?  ( $self->update_log( "Version : ".uri_unescape( $version  ) ) ) : ( $self->update_log( "Version : Empty Value"  ) ) ; 
    $val       ?  ( $self->update_log( "Val     : ".uri_unescape( $val      ) ) ) : ( $self->update_log( "Val     : Empty Value"  ) ) ;  
    $path      ?  ( $self->update_log( "Path    : ".uri_unescape( $path     ) ) ) : ( $self->update_log( "Path    : Empty Value"  ) ) ; 
    $domain    ?  ( $self->update_log( "Domain  : ".uri_unescape( $domain   ) ) ) : ( $self->update_log( "Domain  : Empty Value"  ) ) ; 
    $port      ?  ( $self->update_log( "Port    : ".uri_unescape( $port     ) ) ) : ( $self->update_log( "Port    : Empty Value"  ) ) ; 
    $pathspec  ?  ( $self->update_log( "Pathspec: ".uri_unescape( $pathspec ) ) ) : ( $self->update_log( "Pathspec: Empty Value"  ) ) ; 
    $secure    ?  ( $self->update_log( "Secure  : ".uri_unescape( $secure   ) ) ) : ( $self->update_log( "Secure  : Empty Value"  ) ) ; 
    $expires   ?  ( $self->update_log( "Expires ; ".uri_unescape( $expires  ) ) ) : ( $self->update_log( "Expires ; Empty Value"  ) ) ; 
    $discard   ?  ( $self->update_log( "Discard : ".uri_unescape( $discard  ) ) ) : ( $self->update_log( "Discard : Empty Value"  ) ) ; 
    $hash      ?  ( $self->update_log( "Hash    : ".$hash                     ) ) : ( $self->update_log( "Hash    : Empty Value"  ) ) ; 
    $self->update_log( " " );

}

#=============================================================================================
# Retrieve Auction Interval value for drip feed auctions
#=============================================================================================

sub load_interval {

    my $self = shift;

    return $self->{DripFeedInterval};
}

#=============================================================================================
# Retrieve connected status
#=============================================================================================

sub is_connected {

    my $self = shift;
    return $self->{connected};
}

#=============================================================================================
# Get number of current listings per page
#=============================================================================================

sub curr_listings_pp {

    my $self = shift;
    return $self->{curr_listings_pp};
}

#=============================================================================================
# Get number of pages with current listings
#=============================================================================================

sub curr_pages {

    my $self = shift;
    return $self->{curr_pages};
}

#=============================================================================================
# Get number of current listings
#=============================================================================================

sub curr_listings {

    my $self = shift;
    return $self->{curr_listings};
}

#=============================================================================================
# Get number of completed listings
#=============================================================================================

sub comp_listings {

    my $self = shift;
    return $self->{comp_listings};
}

#=============================================================================================
# Get number of completed listings per page
#=============================================================================================

sub comp_listings_pp {

    my $self = shift;
    return $self->{comp_listings_pp};
}

#=============================================================================================
# Get number of pages with completed listings
#=============================================================================================

sub comp_pages {

    my $self = shift;
    return $self->{comp_pages};
}

#=============================================================================================
# Method    : get_current_auction_count
# Added     : 09/08/06
# Input     : 
# Returns   : Integer
#
# This function returns the number of CURRENT auctions on TradeMe
# be listed on TradeMe without incurring the HVS (High Volume Seller) fee
#=============================================================================================

sub get_current_auction_count {

    my $self = shift;           # TradeMe object
    my $listings = 0;           # Total current listings
    my $pattern;                # pattern to mach in reg exps
    my $retries;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    # Clear error indicator and error message properties

    $self->clear_err_structure();

    # Define the external message subroutine (Callback) if provided

    my $msgsub = shift;
    
    # -- extract the current listing summary details from the first current listings page --

    $url="http://www.trademe.co.nz/structure/my_listings_current.asp?sort=&sort_order=";        # pre 10/05/2006
    $url="http://www.trademe.co.nz/MyTradeMe/Sell/Current.aspx";                                # 10/05/2006
    
    $req       = HTTP::Request->new(GET => $url);
    $response  = $ua->request($req);

    $retries = 1;
    
    while ( $retries lt 4 ) {
    
        $req      = HTTP::Request->new(GET => $url);
        $response = $ua->request($req);              

        if ($response->is_error()) {

            $self->update_log("[get_curr_listings} Error retrieving count of current auctions; Retrying (attempt $retries)");
            $retries++;
            sleep 5;

            if ( $retries eq 4 ) {
                $self->update_log("[get_curr_listings] Could  not retrieve Count of current Auctions URL");
                $self->{ErrorStatus}  = "1";
                $self->{ErrorMessage} = "[get_curr_list] Error retrieving Count of current auctions";
                return;
            }
        }
        
        else {
        
            $retries = 4;
        }
 
    }

    # use a regular expression to extract the needed details
    # The HTML looks something like this (as at 1st January 2005)
    # ... <small>207 current items, showing 1 to 25</small> ...
    # calculate the current pages by dividing the no. of listings by listings per page
    # if the number is not an exact number then round up to the next whole number by
    # adding one to the integer portion of the result

    # test the content for 0 sold items

    $content = $response->content();

    $pattern = "No listings to display";

    if ($content =~ m/$pattern/) {

        $listings   = 0;

        return $listings;
    }

    # retrieve the current number of listings when current auctions more than 1 page

    $pattern = "current items, showing";

    if ($content =~ m/(<small>)([0-9]+)(\s+$pattern\s+)([0-9]+)(\s+to\s+)([0-9]+)(<\/small>)/g) {

        $listings = $2;
        
        return $listings;
    }
    
    # If not 0 and not more than 1 page, then there must be between 1-25 auctions
    # Just retrieve the auction details and get the count from the array attributes

    while ($content =~ m/(Closes: )(.+?)(<\/small>)(.+?)(<small>\(#)(.+?)(\)<\/small>)/gm) {

        $listings++;
        
        return $listings;

    }

}

#=============================================================================================
# Get current TM Listing data (retrieve individual current auction details)
# get the list of auction numbers in the current auctions listing
# returns an array of auction numbers representing members current auctions
#=============================================================================================

sub get_curr_listings {

    my $self = shift;           # TradeMe object
    my $auction;
    my @auctions;               # Auction array      
    my $listings;               # Total current listings
    my $listings_pp;            # NUmber listings per page
    my $pages;                  # Calculated number of pages
    my $counter = 1;            # Item counter
    my $listpage = 1;           # Current list page
    my $pattern;                # pattern to mach in reg exps
    my $retries;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    # Clear error indicator and error message properties

    $self->clear_err_structure();

    # Define the external message subroutine (Callback) if provided

    my $msgsub = shift;
    
    # -- extract the current listing summary details from the first current listings page --

    $url="http://www.trademe.co.nz/structure/my_listings_current.asp?sort=&sort_order=";        # pre 10/05/2006
    $url="http://www.trademe.co.nz/MyTradeMe/Sell/Current.aspx";                                # 10/05/2006
    
    $req       = HTTP::Request->new(GET => $url);
    $response  = $ua->request($req);

    $retries = 1;
    
    while ( $retries lt 4 ) {
    
        $req      = HTTP::Request->new(GET => $url);
        $response = $ua->request($req);              

        if ($response->is_error()) {

            $self->update_log("[get_curr_listings} Error retrieving list of current auctions; Retrying (attempt $retries)");
            $retries++;
            sleep 5;

            if ( $retries eq 4 ) {
                $self->update_log("[get_curr_listings] Could  not retrieve Current Listings URL");
                $self->{ErrorStatus}  = "1";
                $self->{ErrorMessage} = "[get_curr_list] Error retrieving list of current auctions";
                return;
            }
        }
        else {
            $retries = 4;
        }
    }

    # use a regular expression to extract the needed details
    # The HTML looks something like this (as at 1st January 2005)
    # ... <small>207 current items, showing 1 to 25</small> ...
    # calculate the current pages by dividing the no. of listings by listings per page
    # if the number is not an exact number then round up to the next whole number by
    # adding one to the integer portion of the result

    # test the content for 0 sold items

    $content = $response->content();

    $pattern = "No listings to display";

    if ($content =~ m/$pattern/) {

        $self->{curr_listings}     = 0;
        $self->{curr_listings_pp}  = 0;
        $self->{curr_pages}        = 0;
        return;
    }

    # test the content for more than 1 page of items 

    $pattern = "current items, showing";

    if ($content =~ m/(<small>)([0-9]+)(\s+$pattern\s+)([0-9]+)(\s+to\s+)([0-9]+)(<\/small>)/g) {
        $listings = $2;
        $listings_pp = $6;
        $pages = int($listings/$listings_pp);

        if (($listings/$listings_pp) > $pages) {
            $pages =  $pages + 1;
        }

        $self->{curr_listings}     = $2;
        $self->{curr_listings_pp}  = $6;
        $self->{curr_pages}        = $pages;

        # Loop through the sold auction pages to retrieve the auction no.s and put them on the array

        while ($listpage <= $pages) {

            if ($msgsub) {
                &$msgsub("Processing Current Items Page ".$listpage." of ".$pages);
            }

            $url = "http://www.trademe.co.nz/MyTradeMe/Sell/Current.aspx?filter=all&page=".$listpage;             # 10/05/2006
            $retries = 1;

            while ( $retries lt 4 ) {

                $req = HTTP::Request->new(GET => $url);
                my $response = $ua->request($req);

                if ($response->is_error()) {

                    $self->update_log("[get_curr_listings] Error retrieving list of current auctions; Retrying (attempt $retries)");
                    $retries++;
                    sleep 5;

                    if ( $retries eq 4 ) {
                        $self->update_log("[get_curr_listings] Could  not retrieve Current Listings URL");
                        $self->{ErrorStatus}  = "1";
                        $self->{ErrorMessage} = "[get_curr_list] Error retrieving list of current auctions";
                        return;
                    }
                }
                        
                else {

                    # The HTML looks something like this (as at 1st January 2005)
                    # ... <small>(#20465112)</small> ...
                    # Closes: &nbsp;Wed&nbsp;10&nbsp;May&nbsp;11:36&nbsp;am</small>
                    # </font>&nbsp;<font color="#000000"><small>(#55604549)</small>
                    
                    $content = $response->content();

                    while ($content =~ m/(Closes: )(.+?)(<\/small>)(.+?)(<small>\(#)(.+?)(\)<\/small>)/gm) {

                        $auction  = $6;                                      # Auction ref

                        my $cldate = calc_close_date($2,"FUTURE");
                        my $cltime = calc_close_time($2);

                        # put anonymous auction details hash in return array

                        push ( @auctions, { AuctionRef => $auction, CloseDate => $cldate, CloseTime => $cltime } );         
                    }
                    
                    $retries = 4;
                }
            }
            $listpage ++;
        }
        return \@auctions;
    }
    
    # If not 0 and not more than 1 page, then there must be between 1-25 auctions
    # Just retrieve the auction details and get the count from the array attributes

    while ($content =~ m/(Closes: )(.+?)(<\/small>)(.+?)(<small>\(#)(.+?)(\)<\/small>)/gm) {

        $auction  = $6;                                      # Auction ref
        my $cldate = calc_close_date($2,"FUTURE");
        my $cltime = calc_close_time($2);

        # put anonymous auction details hash in return array

        push ( @auctions, { AuctionRef => $auction, CloseDate => $cldate, CloseTime => $cltime } );         
    }

    # Sold listings is number of array elements; items per page is the same value; only 1 page

    $self->{curr_listings}     = $#auctions + 1; 
    $self->{curr_listings_pp}  = $self->{curr_listings}; 
    $self->{curr_pages}        = 1;
    return \@auctions;

}

#=============================================================================================
# Method    : get_unanswered questions
# Added     : 18/06/08
# Input     : Hash; 
# Parameters: Filename (Optional), Filter (optional)
#       
#             If a file name is passed the input is read from the file instead of from the
#             the Trade Me web site. The file must be in the same format as the file available
#             on Trade Me
# 
#             Filter values:    "all"               All current listings
#                               "closing_today"     Closing today
#                               "has_bid"           Listings with bids
#                               "reserve_met"       Reserve met
#                               "reserve_not_met"   Reserve not met
#                               "questions"         Unanswered questions
#               
# Returns   : Array of Auctions 
#=============================================================================================

sub get_current_auctions {

    my $self   = shift;
    my $i = { @_ };        

    $self->{ Debug } ge "1" ? ( $self->update_log( "Invoked Method: ". ( caller( 0 ) )[ 3 ] ) ) : () ;

    # Clear error indicator and error message properties

    $self->clear_err_structure();

    my @current_auctions;     # array to hold sales records
    my $auction_record;       # hash to store sales record fields

    if ( not defined( $i->{ Filter } ) ) {
        $i->{ Filter } = 'all';
    }

    # if the method was called with an input file name read the file
    # Otherwise Retrieve the sales export from the Trademe web page

    if ( defined( $i->{ Filename } ) ) {
       local $/;                                                      #slurp mode (undef)
       local *F;                                                      #create local filehandle
       open(F, "< $i->{ Filename} \0") || return;
       $content = <F>;                                                #read whole file
       close(F);                                                      # ignore retval
    }
    else {
       $url= "http://www.trademe.co.nz/MyTradeMe/Export/MyListingsCSV.aspx";
   
       $req = POST $url,
   
       [   'ListingType'       =>  'Current'        ,
           'searchTerm'        =>  ''               ,
           'filter'            =>  $i->{ Filter }   ,
       ];
   
       $content = $ua->request( $req )->content();
    }

    # Substitute a "hard" value for the end of line to allow for CRLFs in contained columns

    $content  =~ s/(AM|PM)(",)(\x0D)/$1<EOL>/gm;

    while ( $content =~ m/"(.*?)","                                     # Auction
                           (.*?)","                                     # Title
                           (.*?)","                                     # Category
                           (.*?)","                                     # Shipping details
                           (.*?)","                                     # Listing Fees
                           (.*?)","                                     # Promotion Fees
                           (.*?)","                                     # Start price
                           (.*?)","                                     # Reserve price
                           (.*?)","                                     # Buy now price
                           (.*?)","                                     # Start date
                           (.*?)","                                     # End date
                           (.*?)","                                     # Auction length
                           (.*?)","                                     # Restrictions
                           (.*?)","                                     # Featured
                           (.*?)","                                     # Gallery
                           (.*?)","                                     # Bold
                           (.*?)","                                     # Homepage
                           (.*?)","                                     # Highlight
                           (.*?)","                                     # Extra photos
                           (.*?)","                                     # Scheduled end date
                           (.*?)","                                     # Bidders watchers
                           (.*?)","                                     # Max Bid amount
                           (.*?)                                        # Extract Date
                           <EOL>                                        # EOL"
                            /gxs )    {

        # If not title line, convert extracted data into anonymous hash and add to array

        unless ( $1 eq "listing_id" ) {

            $auction_record = {
                AuctionRef          => $1   ,
                Title               => $2   ,
                Category            => $3   ,
                Shipping_Details    => $4   ,
                Listing_Fees        => $5   ,
                Promotion_Fees      => $6   ,
                Start_Price         => $7   ,
                Reserve_Price       => $8   ,
                BuyNow_Price        => $9   ,
                Start_Date          => $10  ,
                End_Date            => $11  ,
                Duration            => $12  ,
                Restrictions        => $13  ,
                Featured            => $14  ,
                Gallery             => $15  ,
                Bold                => $16  ,
                Homepage            => $17  ,
                Highlight           => $18  ,
                Extra_Photos        => $19  ,
                Scheduled_End       => $20  ,
                B_W_Count           => $21  ,
                Max_Bid_Amount      => $22  ,
                Extract_Date        => $23  ,
            };

            # Format the data and time fields Mth DD YYYY HH:MM AM/PM to Aug-24-2008 10:22 AM

            $auction_record->{ Start_Time   } =  $auction_record->{ Start_Date };
            $auction_record->{ Start_Time   } =~ s/(.+?)(\s+)(.+?)(\s+)(.+?)(\s+)(\d+)(:)(\d+)(AM|PM)/$7:$9 $10/;

            $auction_record->{ Start_Date   } =~ s/(.+?)(\s+)(.+?)(\s+)(.+?)(\s+)(.+)/$1-$3-$5/;

            $auction_record->{ End_Time     } =  $auction_record->{ End_Date };
            $auction_record->{ End_Time     } =~ s/(.+?)(\s+)(.+?)(\s+)(.+?)(\s+)(\d+)(:)(\d+)(AM|PM)/$7:$9 $10/;

            $auction_record->{ End_Date   } =~ s/(.+?)(\s+)(.+?)(\s+)(.+?)(\s+)(.+)/$1-$3-$5/;

            # Store the extracted and converted record in the sales data array

            push ( @current_auctions, $auction_record  );
        }
     }
    return \@current_auctions;
}

#=============================================================================================
# Method    : get_sold_listings
# Added     : 19/06/08
# Input     : Hash
# Returns   : 1. Array of Hashes containing each cell of CSV spreadsheet 
#             2. Raw Data extracted form Trade Me web site
# Usage     : $tm->get_sold_listings {
#                  last_45_days => 1            ,  #optional
#                  Filename     => <Filename>   ,  # Optional - Input file
#                  RawData      => <Scalar>     ,  # Optional - raw input data
#                  Output       => ARRAY|RAW    ,  # optional - Output type
#                  
#=============================================================================================

sub new_get_sold_listings {

    my $self   = shift;
    my $i = { @_ };        

    my $filter;

    $self->{ Debug } ge "1" ? ( $self->update_log( "Invoked Method: ". ( caller( 0 ) )[ 3 ] ) ) : () ;

    # Clear error indicator and error message properties

    $self->clear_err_structure();

    my @sales_data;         # array to hold sales records
    my $sales_record;       # hash to store sales record fields

    # Set the number of days to extract

    if ( defined( $i->{ Last_45_Days } ) ) {
        $filter = "last_45_days";
    }
    else { 
        $filter = "last_7_days";
    }

    # if the method was called with an input file name read the file
    # if the method was called with RawData read the input data
    # Otherwise Retrieve the sales export from the Trademe web page

    if ( defined( $i->{ Filename } ) ) {
       local $/;                                                      #slurp mode (undef)
       local *F;                                                      #create local filehandle
       open(F, "< $i->{ Filename} \0") || return;
       $content = <F>;                                                #read whole file
       close(F);                                                      # ignore retval
    }
    elsif ( defined( $i->{ RawData } ) ) {
       $content = $i->{ RawData };                                    #read whole file
    }
    else {
       $url= "http://www.trademe.co.nz/MyTradeMe/Export/MyListingsCSV.aspx";
   
       $req = POST $url,
   
       [   "ListingType"       =>  "Sold"               ,
           "filter"            =>  $filter              ,
           "show_deleted"      =>  1                    ,
       ] ;
   
       $content = $ua->request( $req )->content();
    }

    # Set the Return data format. If called with Output => 'RAW' return the raw data
    # Otherwise return a reference to the formtatted data array

    if ( not defined( $i->{ Output } ) ) {
        $i->{ Output } = 'ARRAY';
    }

    print "Looking for missing CSV separators...\n";

    while ( $content =~ s/",,"/","","/gx )    {
       print "Quotes added to missing field\n";
    }

    # Substitute a "hard" value for the end of line to allow for CRLFs in contained columns

    $content  =~ s/(")(yes|no)(")(,\x0D)/$1.$2.$3<EOL>/gm;

    while ( $content =~ m/"(.*?)","                                     # Auction
                           (.*?)","                                     # Title
                           (.*?)","                                     # Category
                           (.*?)","                                     # Sold date
                           (.*?)","                                     # Sale type
                           (.*?)","                                     # Sale price
                           (.*?)","                                     # Shipping details
                           (.*?)","                                     # Selected Shipping
                           (.*?)","                                     # Buyer name
                           (.*?)","                                     # Buyer delivery Address
                           (.*?)","                                     # Buyer message
                           (.*?)","                                     # Buyer email
                           (.*?)","                                     # Listing fees
                           (.*?)","                                     # Promo fees
                           (.*?)","                                     # Success fees
                           (.*?)","                                     # Refund status
                           (.*?)","                                     # Start price
                           (.*?)","                                     # Reserve price
                           (.*?)","                                     # Buy now price
                           (.*?)","                                     # Start date
                           (.*?)","                                     # Auction length
                           (.*?)","                                     # Restrictions
                           (.*?)","                                     # Featured
                           (.*?)","                                     # Gallery
                           (.*?)","                                     # Bold
                           (.*?)","                                     # Homepage
                           (.*?)","                                     # Highlight
                           (.*?)","                                     # Extra photos
                           (.*?)","                                     # Scheduled end date
                           (.*?)","                                     # Bidders watchers
                           (.*?)","                                     # Note
                           (.*?)"                                       # Pay Now
                           <EOL>                                        # EOL
                            /gxs )    {

        # If not title line, convert extracted data into anonymous hash and add to array

        unless ( $1 eq "Auction #" ) {

            $sales_record = {
                AuctionRef      => $1   ,
                Title           => $2   ,
                Category        => $3   ,
                Sold_Date       => $4   ,
                Sale_Type       => $5   ,
                Sale_Price      => $6   ,
                Buyer_Name      => $9   ,
                Buyer_Address   => $10  ,
                Buyer_Message   => $11  ,
                Buyer_Email     => $12  ,
                Listing_Fee     => $13  ,
                Promo_Fee       => $14  ,
                Success_Fee     => $15  ,
                Refund_Status   => $16  ,
                Start_Price     => $17  ,
                Reserve_Price   => $18  ,
                BuyNow_Price    => $19  ,
                Start_Date      => $20  ,
                Duration        => $21  ,
                Restrictions    => $22  ,
                Featured        => $23  ,
                Gallery         => $24  ,
                Bold            => $25  ,
                Homepage        => $26  ,
                Highlight       => $27  ,
                Extra_Photos    => $28  ,
                Scheduled_End   => $29  ,
                B_W_Count       => $30  ,
                Auction_Note    => $31  ,
                PayNow          => $32  ,
            };

            # Save the extracted ship data for use later on (regex placeholder gets f***ed up otherwise !)

            my $ship_data       =  $7;

            # Create the Selected Shipping fields - 2 possible formats to deal with
            # 1. $6.50 Fastways Courier Nationwide - Combining Items
            # 2. Combining with items I have paid Courier Fee on
            # Second formt has had amount input as 0 so Trade Me don't return it
            
            my @shipping = split / /, $8, 2;
            $shipping[0] =~ tr/\$//d;

            if ( not $shipping[0] =~ m/[0..9,\.]+/ ) {
                $shipping[1] = $shipping[0]." ".$shipping[1];
                $shipping[0] = 0;
            }

            # Cater for when the fee is 0.00 (and Trade Me leave it out !)

            $sales_record->{ "Selected_Ship_Cost" } =  $shipping[0];
            $sales_record->{ "Selected_Ship_Text" } =  $shipping[1];

            # Once we have the regex variables in the hash, perform field level conversions

            # Scrape Crap from the PayNow field (Additional stuff from being the last fieldo n the CSV record

            $sales_record->{ PayNow } =~ tr/"//d;       #"
            $sales_record->{ PayNow } =~ tr/,//d;

            # Set the sale type to the look up key

            if  ( $sales_record->{ Sale_Type     } eq "Auction"           ) { $sales_record->{ Sale_Type     } = "AUCTION"  ; }
            if  ( $sales_record->{ Sale_Type     } eq "Buy now"           ) { $sales_record->{ Sale_Type     } = "BUYNOW"   ; }
            if  ( $sales_record->{ Sale_Type     } eq "Fixed price offer" ) { $sales_record->{ Sale_Type     } = "FPOFFER"  ; }

            # Set the sale type to the look up key

            if  ( $sales_record->{ Refund_Status } eq ""                  ) { $sales_record->{ Refund_Status } = ""         ; }
            if  ( $sales_record->{ Refund_Status } eq "Refund pending"    ) { $sales_record->{ Refund_Status } = "PENDING"  ; }
            if  ( $sales_record->{ Refund_Status } eq "Refund declined"   ) { $sales_record->{ Refund_Status } = "DECLINED" ; }
            if  ( $sales_record->{ Refund_Status } eq "Refund approved"   ) { $sales_record->{ Refund_Status } = "ACCEPTED" ; }

            # Set up Boolean values

            if  ( $sales_record->{ Featured      } eq "no"                ) { $sales_record->{ Featured      } = 0; }
            else                                                            { $sales_record->{ Featured      } = 1; }

            if  ( $sales_record->{ Gallery       } eq "no"                ) { $sales_record->{ Gallery       } = 0; }
            else                                                            { $sales_record->{ Gallery       } = 1; }

            if  ( $sales_record->{ Bold          } eq "no"                ) { $sales_record->{ Bold          } = 0; }
            else                                                            { $sales_record->{ Bold          } = 1; }

            if  ( $sales_record->{ Homepage      } eq "no"                ) { $sales_record->{ Homepage      } = 0; }
            else                                                            { $sales_record->{ Homepage      } = 1; }

            if  ( $sales_record->{ Highlight     } eq "no"                ) { $sales_record->{ Highlight     } = 0; }
            else                                                            { $sales_record->{ Highlight     } = 1; }

            if  ( $sales_record->{ Extra_Photos  } eq "no"                ) { $sales_record->{ Extra_Photos  } = 0; }
            else                                                            { $sales_record->{ Extra_Photos  } = 1; }

            if  ( $sales_record->{ Scheduled_End } eq "no"                ) { $sales_record->{ Scheduled_End } = 0; }
            else                                                            { $sales_record->{ Scheduled_End } = 1; }

            if  ( $sales_record->{ PayNow        } =~ m/no/i              ) { $sales_record->{ PayNow        } = 0; }
            else                                                            { $sales_record->{ PayNow        } = 1; }

            # Format the data and time fields Mth DD YYYY HH:MM AM/PM to Aug-24-2008 10:22 AM

            $sales_record->{ Start_Time    } =  $sales_record->{ Start_Date    };
            $sales_record->{ Start_Time    } =~ s/(.+?)(\s+)(.+?)(\s+)(.+?)(\s+)(\d+)(:)(\d+)(AM|PM)/$7:$9 $10/;

            $sales_record->{ Start_Date    } =~ s/(.+?)(\s+)(.+?)(\s+)(.+?)(\s+)(.+)/$1-$3-$5/;

            $sales_record->{ Sold_Time     } =  $sales_record->{ Sold_Date    };
            $sales_record->{ Sold_Time     } =~ s/(.+?)(\s+)(.+?)(\s+)(.+?)(\s+)(\d+)(:)(\d+)(AM|PM)/$7:$9 $10/;

            $sales_record->{ Sold_Date     } =~ s/(.+?)(\s+)(.+?)(\s+)(.+?)(\s+)(.+)/$1-$3-$5/;

            # Format the Address details saved earlier to a usable format

            $sales_record->{ Buyer_Address } =~ s/, /<BR>/gs;

            # If we find a postcode at the end extract it and remove it form the address

            if ( $sales_record->{ Buyer_Address } =~ m/(.*)( )(\d+?)$/ ) {
                $sales_record->{ Buyer_Address   } =  $1;
                $sales_record->{ Buyer_Postcode   } =  $3;
            }

            # Format the Buyer Message to a usable format

            $sales_record->{ Buyer_Message } =~ s/\x0D\x0A/<BR>/gs;
            $sales_record->{ Buyer_Message } =~ s/\n/<BR>/gs;

            # Format the Shipping details saved earlier to a usable format


            if ( $ship_data =~ m/(.+?)(Seller allows pick-ups)/ ) {
                $sales_record->{ Pickup_Text    } =  "ALLOW";
                $ship_data = $1;
            }

            elsif ( $ship_data =~ m/(.+?)(No pick-ups allowed)/ ) {
                $sales_record->{ Pickup_Text    } =  "FORBID";
                $ship_data = $1;
            }

            elsif ( $ship_data =~ m/(.+?)(Buyer must pick up)/ ) {
                $sales_record->{ Pickup_Text    } =  "DEMAND";
                $ship_data = $1;
            }

            else {
                $sales_record->{ Pickup_Text    } =  "";
                $sales_record->{ Ship_Text1     } =  $ship_data;
                $ship_data = "";
            }

            if ( $ship_data =~ m/Not yet known/ ) {
                $sales_record->{ Ship_Text1     } =  "Not yet known";
            }

            elsif ( $ship_data =~ m/Free Shipping in New Zealand/ ) {
                $sales_record->{ Ship_Text1     } =  "Free shipping in NZ";
            }

            else {

                # build an array of each of the shipping options in cost/Text format

                my $opt_count   = 1;

                while ( $ship_data =~ m/(.*?)(\s{3,})/g ) {
                    my @shipping = split / /,$1,2;
                    $sales_record->{ "Ship_Cost".$opt_count } =  $shipping[0];
                    $sales_record->{ "Ship_Text".$opt_count } =  $shipping[1];
                    $opt_count++;
                }
            }

            # Store the extracted and converted record in the sales data array

            push ( @sales_data, $sales_record  );

        }
    }
    if ( $i->{ Output } eq 'ARRAY' ) {
        return \@sales_data;
    }
    elsif ( $i->{ Output } eq 'RAW' ) {
        return $content;
    }
}

#=============================================================================================
# Get sold Listing data (retrieve list of sold auction numbers)
# get the list of auction numbers in the sold auctions listing
# returns an array of auction numbers representing members sold auctions
# Sets the number of sold auctions, sold auctions per page, and sold auction pages properties
#=============================================================================================

sub get_sold_listings {

    my $self = shift;           # TradeMe object
    my $auction;
    my @auctions;               # Auction array      
    my $listings;               # Total current listings
    my $listings_pp;            # NUmber listings per page
    my $pages;                  # Calculated number of pages
    my $counter = 1;            # Item counter
    my $listpage = 1;           # Current list page
    my $pattern;                # pattern to mach in reg exps
    my $retries;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    # Clear error indicator and error message properties

    $self->clear_err_structure();

    # Define the external message subroutine (Callback) if provided

    my $msgsub = shift;
    
    # -- extract the current listing summary details from the first current listings page --

    $url="http://www.trademe.co.nz/MyTradeMe/Sell/Sold.aspx";                                               # 10/05/2006
    
    $req       = HTTP::Request->new(GET => $url);
    $response  = $ua->request($req);

    $retries = 1;
    
    while ( $retries lt 7 ) {
    
        $req      = HTTP::Request->new(GET => $url);
        $response = $ua->request($req);              
        $self->update_log("HTTP Response code for request: ".$response->status_line);

        if ($response->is_error()) {

            $self->update_log("[get_sold_listings} Error retrieving list of sold auctions; Retrying (attempt $retries)");
            $retries++;
            sleep 5;

            if ( $retries eq 7 ) {
                $self->update_log("[get_sold_listings] Could  not retrieve Sold Listings URL");
                $self->{ErrorStatus}  = "1";
                $self->{ErrorMessage} = "[get_Sold_list] Error retrieving list of Sold auctions page";
                return;
            }
        }
        
        else {
        
            $retries = 7;
        }
 
    }

    # use a regular expression to extract the needed details
    # The HTML looks something like this (as at 1st January 2005)
    # ... <small>207 current items, showing 1 to 25</small> ...
    # calculate the current pages by dividing the no. of listings by listings per page
    # if the number is not an exact number then round up to the next whole number by
    # adding one to the integer portion of the result

    $content = $response->content();

    # test the content for 0 sold items

    $pattern = "No listings to display";

    if ($content =~ m/$pattern/g) {

        $self->{sold_listings}     = 0;
        $self->{sold_listings_pp}  = 0;
        $self->{sold_pages}        = 0;
        return;
    }

    # test the content for more than 1 page of items 

    $pattern = "sold items, showing";

    if ( $content =~ m/(<small>)([0-9]+)(\s+$pattern\s+)([0-9]+)(\s+to\s+)([0-9]+)(<\/small>)/ ) {
        $listings = $2;
        $listings_pp = $6;
        $pages = int( $listings/$listings_pp );

        if ( ( $listings/$listings_pp ) > $pages ) {
            $pages =  $pages + 1;
        }

        $self->{ sold_listings      }   = $2;
        $self->{ sold_listings_pp   }   = $6;
        $self->{ sold_pages         }   = $pages;

        # Loop through the sold auction pages to retrieve the auction no.s and put them on the array

        while ( $listpage <= $pages ) {

            if ( $msgsub ) {
                &$msgsub( "Processing Sold items Page ".$listpage." of ".$pages );
            }

            $url = "http://www.trademe.co.nz/MyTradeMe/Sell/Sold.aspx?filter=all&page=".$listpage;           # 10/05/2006

            $retries = 1;

            while ( $retries lt 4 ) {

                $req = HTTP::Request->new(GET => $url);
                my $response = $ua->request($req);

                if ( $response->is_error() ) {

                    $self->update_log( "[get_sold_listings] Error retrieving list of sold auctions; Retrying (attempt $retries)" );
                    $retries++;
                    sleep 5;

                    if ( $retries eq 4 ) {
                        $self->update_log( "[get_sold_listings] Could  not retrieve Sold Listings URL" );
                        $self->{ ErrorStatus    }   = "1";
                        $self->{ ErrorMessage   }   = "[get_Sold_list] Error retrieving list of sold auctions";
                        return;
                    }
                }
        
                else {

                    # The HTML looks something like this (as at 1st January 2005)
                    # ... <small>(#20465112)</small> ...

                    $content = $response->content();

                    while ( $content =~ m/(Closed: )(.+?)(<\/small>)(.+?)(<small>\(#)(.+?)(\)<\/small>)/gm ) {        #"

                        $auction  = $6;                                      # Auction ref
                        my $cldate = calc_close_date( $2,"PAST" );
                        my $cltime = calc_close_time( $2        );

                        # put anonymous auction details hash in return array

                        push ( @auctions, { AuctionRef => $auction, CloseDate => $cldate, CloseTime => $cltime } );         
                    }
                    
                    $retries = 4;
                }
            }                
            $listpage ++;
        }
        return \@auctions;
    }
    
    # If not 0 and not more than 1 page, then there must be between 1-25 auctions
    # Just retrieve the auction details and get the count from the array attributes

    while ($content =~ m/(Closed: )(.+?)(<\/small>)(.+?)(<small>\(#)(.+?)(\)<\/small>)/gm) {

        $auction  = $6;                                      # Auction ref
        my $cldate = calc_close_date($2,"PAST");
        my $cltime = calc_close_time($2);

        # put anonymous auction details hash in return array

        push ( @auctions, { AuctionRef => $auction, CloseDate => $cldate, CloseTime => $cltime } );         
    }

    # Sold listings is number of array elements; items per page is the same value; only 1 page

    $self->{sold_listings}     = $#auctions + 1; 
    $self->{sold_listings_pp}  = $self->{sold_listings}; 
    $self->{sold_pages}        = 1;
    return \@auctions;

}

#=============================================================================================
# Get unsold Listing data (retrieve list of unsold auction numbers)
# get the list of auction numbers in the unsold auctions listing
# Returns an array of auction numbers representing members unsold auctions
# Sets the no. of unsold auctions, unsold auctions per page, & unsold auction pages properties
#=============================================================================================

sub get_unsold_listings {

    my $self = shift;           # TradeMe object
    my $auction;
    my @auctions;               # Auction array      
    my $listings;               # Total current listings
    my $listings_pp;            # NUmber listings per page
    my $pages;                  # Calculated number of pages
    my $counter = 1;            # Item counter
    my $listpage = 1;           # Current list page
    my $pattern;                # pattern to mach in reg exps
    my $retries;
    
    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    # Clear error indicator and error message properties

    $self->clear_err_structure();

    # Define the external message subroutine (Callback) if provided

    my $msgsub = shift;
    
    # -- extract the current listing summary details from the first current listings page --

    $url="http://www.trademe.co.nz/structure/my_trademe/sell_unsold.asp";                                   # pre 10/05/2006
    $url="http://www.trademe.co.nz/MyTradeMe/Sell/Unsold.aspx";                                             # 10/05/2006

    $req       = HTTP::Request->new(GET => $url);
    $response  = $ua->request($req);

    $retries = 1;
    
    while ( $retries lt 7 ) {
    
        $req      = HTTP::Request->new(GET => $url);
        $response = $ua->request($req);              
        $self->update_log("HTTP Response code for request: ".$response->status_line);

        if ($response->is_error()) {

            $self->update_log("[get_unsold_listings} Error retrieving list of unsold auctions; Retrying (attempt $retries)");
            $retries++;
            sleep 5;

            if ( $retries eq 7 ) {
                $self->update_log("[get_sold_listings] Could  not retrieve Unsold Listings URL");
                $self->{ErrorStatus}  = "1";
                $self->{ErrorMessage} = "[get_sold_listings] Error retrieving list of unsold auctions";
                return;
            }
        }
        
        else {
        
            $retries = 7;
        }
 
    }

    # use a regular expression to extract the needed details
    # The HTML looks something like this (as at 1st January 2005)
    # ... <small>207 current items, showing 1 to 25</small> ...
    # calculate the current pages by dividing the no. of listings by listings per page
    # if the number is not an exact number then round up to the next whole number by
    # adding one to the integer portion of the result

    $content = $response->content();

    # test the content for 0 sold items

    $pattern = "No listings to display";

    if ($content =~ m/$pattern/g) {

        $self->{unsold_listings}     = 0;
        $self->{unsold_listings_pp}  = 0;
        $self->{unsold_pages}        = 0;
        return;
    }

    # test the content for more than 1 page of items 

    $pattern = "unsold items, showing";

    if ($content =~ m/(<small>)([0-9]+)(\s+$pattern\s+)([0-9]+)(\s+to\s+)([0-9]+)(<\/small>)/) {
        $listings = $2;
        $listings_pp = $6;
        $pages = int($listings/$listings_pp);

        if (($listings/$listings_pp) > $pages) {
            $pages =  $pages + 1;
        }

        $self->{unsold_listings}     = $2;
        $self->{unsold_listings_pp}  = $6;
        $self->{unsold_pages}        = $pages;

        # Loop through the sold auction pages to retrieve the auction no.s and put them on the array

        while ($listpage <= $pages) {

            if ($msgsub) {
                &$msgsub("Processing Unsold Items Page ".$listpage." of ".$pages);
            }

            $url = "http://www.trademe.co.nz/MyTradeMe/Sell/Unsold.aspx?filter=all&page=".$listpage;           # 10/05/2006

            $retries = 1;

            while ( $retries lt 4 ) {

                $req = HTTP::Request->new(GET => $url);
                my $response = $ua->request($req);

                if ($response->is_error()) {

                    $self->update_log("[get_unsold_listings] Error retrieving list of unsold auctions; Retrying (attempt $retries)");
                    $retries++;
                    sleep 5;

                    if ( $retries eq 4 ) {
                        $self->update_log("[get_unsold_listings] Could  not retrieve Unsold Listings URL");
                        $self->{ErrorStatus}  = "1";
                        $self->{ErrorMessage} = "[get_unsold_list] Error retrieving list of unsold auctions";
                        return;
                    }
                }
        

                else {

                    # The HTML looks something like this (as at 1st January 2005)
                    # ... <small>(#20465112)</small> ...

                    $content = $response->content();

                    while ($content =~ m/(Closed: )(.+?)(<\/small>)(.+?)(<small>\(#)(.+?)(\)<\/small>)/gm) {

                        $auction  = $6;                                      # Auction ref
                        my $cldate = calc_close_date($2,"PAST");
                        my $cltime = calc_close_time($2);

                        # put anonymous auction details hash in return array

                        push ( @auctions, { AuctionRef => $auction, CloseDate => $cldate, CloseTime => $cltime } );         
                    }
                    
                    $retries = 4;
                }
            }
            $listpage ++;
        }
        return \@auctions;
    }
    
    # If not 0 and not more than 1 page, then there must be between 1-25 auctions
    # Just retrieve the auction details and get the count from the array attributes

    while ($content =~ m/(Closed: )(.+?)(<\/small>)(.+?)(<small>\(#)(.+?)(\)<\/small>)/gm) {

           $auction  = $6;                                      # Auction ref
           my $cldate = calc_close_date($2,"PAST");
           my $cltime = calc_close_time($2);

           # put anonymous auction details hash in return array
           
           push ( @auctions, { AuctionRef => $auction, CloseDate => $cldate, CloseTime => $cltime } );         
    }

    # Sold listings is number of array elements; items per page is the same value; only 1 page

    $self->{unsold_listings}     = $#auctions + 1; 
    $self->{unsold_listings_pp}  = $self->{unsold_listings}; 
    $self->{unsold_pages}        = 1;
    return \@auctions;
}

#=============================================================================================
# Get sold Listing data (retrieve list of sold auction numbers)
# get the list of auction numbers in the sold auctions listing
# returns an array of auction numbers representing members sold auctions
# Sets the number of sold auctions, sold auctions per page, and sold auction pages properties
#=============================================================================================

sub get_completed_auction_feedback_list {

    my $self = shift;           # TradeMe object
    my $auction;
    my $buyerid;
    my $saletype;
    my @auctions;               # Auction array      
    my $listings;               # Total current listings
    my $listings_pp;            # NUmber listings per page
    my $pages;                  # Calculated number of pages
    my $counter = 1;            # Item counter
    my $listpage = 1;           # Current list page
    my $pattern;                # pattern to mach in reg exps
    my $retries;

    $self->{ Debug } ge "1" ? ( $self->update_log( "Invoked Method: ". ( caller(0) )[3] ) ) : () ;

    # Clear error indicator and error message properties

    $self->clear_err_structure();

    # Define the external message subroutine (Callback) if provided

    my $msgsub = shift;
    
    # -- extract the current listing summary details from the first current listings page --

    $url="http://www.trademe.co.nz/MyTradeMe/Sell/Sold.aspx?filter=sale_completed";
    
    $req       = HTTP::Request->new( GET => $url );
    $response  = $ua->request( $req );

    $retries = 1;
    
    while ( $retries lt 4 ) {
    
        $req      = HTTP::Request->new( GET => $url );
        $response = $ua->request( $req );              

        if ( $response->is_error() ) {

            $self->update_log("[get_completed_auction_feedback_list] Error retrieving Sale Complete Sold auctions; Retrying (attempt $retries)");
            $retries++;
            sleep 5;

            if ( $retries eq 4 ) {
                $self->update_log( "[get_completed_auction_feedback_list] Could  not retrieve Sold Status Listings URL" );
                $self->{ ErrorStatus    }  = "1";
                $self->{ ErrorMessage   } = "[get_completed_auction_feedback_list] Error retrieving Sale Complete Sold auctions page";
                return;
            }
        }
        else {
            $retries = 4;
        }
    }

    # use a regular expression to extract the needed details
    # The HTML looks something like this (as at 1st January 2005)
    # ... <small>207 current items, showing 1 to 25</small> ...
    # calculate the current pages by dividing the no. of listings by listings per page
    # if the number is not an exact number then round up to the next whole number by
    # adding one to the integer portion of the result

    $content = $response->content();

    # test the content for 0 sold items

    if ( $content =~ m/No listings to display/g ) {
        return;
    }

    # test the content for more than 1 page of items 

    if ( $content =~ m/(<small>)([0-9]+)(\s+sold items, showing\s+)([0-9]+)(\s+to\s+)([0-9]+)(<\/small>)/ ) {
        $listings = $2;
        $listings_pp = $6;
        $pages = int($listings/$listings_pp);

        if (($listings/$listings_pp) > $pages) {
            $pages =  $pages + 1;
        }

        # Loop through the sold auction pages to retrieve the auction no.s and put them on the array

        while ($listpage <= $pages) {

            if ( $msgsub ) {
                &$msgsub( "Processing Completed items Page ".$listpage." of ".$pages );
            }

            $url = "http://www.trademe.co.nz/MyTradeMe/Sell/Sold.aspx?filter=sale_completed&page=".$listpage; 

            $retries = 1;

            while ( $retries lt 4 ) {

                $req = HTTP::Request->new( GET => $url );
                my $response = $ua->request( $req );

                if ( $response->is_error() ) {

                    $self->update_log( "[get_completed_auction_feedback_list] Error retrieving status list of sold auctions; Retrying (attempt $retries)" );
                    $retries++;
                    sleep 5;

                    if ( $retries eq 4 ) {
                        $self->update_log( "[get_completed_auction_feedback_list] Could  not retrieve Sold status Listings URL" );
                        $self->{ ErrorStatus    }  = "1";
                        $self->{ ErrorMessage   } = "[get_completed_auction_feedback_list] Error retrieving status list of sold auctions";
                        return;
                    }
                }
        
                else {

                    # The HTML looks something like this (as at 1st January 2005)
                    # ... <small>(#20465112)</small> ...

                    $content = $response->content();

                    while ( $content =~ m/(cmdPlaceFeedback)(.*?)(_)(.+?)(_)(.+?)(")/gm ) {

                        if ( $2 eq "Offer" ) {
                            $saletype = "OFFER";
                        }
                        else {
                            $saletype = "AUCTION";
                        }

                        $auction  = $4;
                        $buyerid  = $6;

                        # put anonymous auction details hash in return array

                        push ( @auctions, { AuctionRef => $auction, BuyerID => $buyerid, SaleType => $saletype } );         
                    }
                    
                    $retries = 4;
                }
            }                
            $listpage ++;
        }
        return \@auctions;
    }
    
    # If not 0 and not more than 1 page, then there must be between 1-25 auctions
    # Just retrieve the auction details and get the count from the array attributes

    while ( $content =~ m/(cmdPlaceFeedback)(.*?)(_)(.+?)(_)(.+?)(")/gm ) {

        if ( $2 eq "Offer" ) {
            $saletype = "OFFER";
        }
        else {
            $saletype = "AUCTION";
        }

        $auction  = $4;
        $buyerid  = $6;

        # put anonymous auction details hash in return array

        push ( @auctions, { AuctionRef => $auction, BuyerID => $buyerid, SaleType => $saletype } );         
    }

    # Sold listings is number of array elements; items per page is the same value; only 1 page

    return \@auctions;
}

#=============================================================================================
# Method    : get_account_statement
# Added     : 23/06/08
# Input     : None
# Returns   : Array of Hashes containg each cell of CSV spreadsheet
#=============================================================================================

sub get_account_statement {

    my $self  = shift;

    my @account_data;         # array to hold sales records
    my $account_record;       # hash to store sales record fields

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    # Clear error indicator and error message properties

    $self->clear_err_structure();

    # Retrieve the sales export from the Trademe web page

    $url= "http://www.trademe.co.nz/MyTradeMe/Export/LedgerCSV.aspx";

    $req = POST $url,

    [   "days"              =>  45                  ,
        "submitted"         =>  "y"                 ,
    ] ;

    $content = $ua->request($req)->content();

    print "Looking for missing CSV separators...\n";

    while ( $content =~ s/",,"/","","/gx )    {
        print "Quotes added to missing field\n";
    }

    print "Formatting raw account data retrieved from TradeMe\n";

    while ( $content =~ m/"(.*?)","    # Date 
                           (.*?)","    # Text
                           (.*?)","    # Credit
                           (.*?)","    # Debit
                           (.*?)","    # Balance
                           (.*?)\x0D   # Auction Ref Payment Ref
                            /gx )    {

        # If not title line, convert extracted data into anonymous hash and add to array    #"

        unless ( $1 eq "Date" ) {           

            $account_record = { 
                Account_Date    => $1   ,
                Text            => $2   ,  
                Credit          => $3   ,   
                Debit           => $4   ,  
                Balance         => $5   ,  
                Reference       => $6   ,  
            };

            # Once we have the regex variables in the hash, perform field level conversions                          

            # Scrape Crap from the PayNow field (Additional stuff from being the last field on the CSV record

            $account_record->{ Reference } =~ tr/"//d;
            $account_record->{ Reference } =~ tr/,//d;

            # Format the data and time fields

            $account_record->{ Item_Time    } =  $account_record->{ Account_Date    };
            $account_record->{ Item_Time    } =~ s/(.+?)(\s+)(.+?)(\s+)(.+?)(\s+)(\d+)(:)(\d+)(AM|PM)/$7:$9 $10/;
            $account_record->{ Item_Date    } =  $account_record->{ Account_Date    };
            $account_record->{ Item_Date    } =~ s/(.+?)(\s+)(.+?)(\s+)(.+?)(\s+)(.+)/$1-$3-$5/;

            # Create the Transaction Amount

            if ( $account_record->{ Credit } > 0 ) {
                $account_record->{ Item_Amount } = $account_record->{ Credit }      ;
            }
            else {
                $account_record->{ Item_Amount } = $account_record->{ Debit  } * -1 ;
            }

            # Format the description

            $account_record->{ Item_Description } =  $account_record->{ Text };
            $account_record->{ Item_Description } =~ s/(.+?)( \()(.*)/$1/;

            # Store the extracted and converted record in the account data array

            push ( @account_data, $account_record  );

        }                      
    }
    return \@account_data;
}

#=============================================================================================
# Method    : get_buyer_id
# Added     : 02/06/08
# Input     : 
# Returns   : Integer
#
# This function returns 0 if successful other wise 1
#=============================================================================================

sub get_buyer_id {

    my $self    = shift;
    my $p       = { @_ };
    my $buyerid = 0;
    my $retries;

    $self->{ ErrorStatus  } = 0;
    $self->{ ErrorMessage } = "";

    # 22/01/06      http://www.trademe.co.nz/Browse/Listing.aspx?id=45317821    

    $url = "http://www.trademe.co.nz/Browse/Listing.aspx?id=".$p->{ AuctionRef };

    # Retrieve the requested auction page and if not found return with error message

    $retries = 1;
    
    while ( $retries lt 4 ) {
    
        $req      = HTTP::Request->new( GET => $url );
        $response = $ua->request( $req );              

        if ( $response->is_error() ) {

            $retries++;
            sleep 2;

            if ( $retries ge 4 ) {
                $self->{ ErrorStatus  } = 1;
                $self->{ ErrorMessage } = "Auction details page could not be retrieved - check the internet connection";
                return;
            }
        }
        else {
            $retries = 4;
        }
 
    }

    $content = $response->content();

    # String to verify auction number has been found
    # <small>Auction Number: 47316142</small>
    
    unless ( $content =~ m/<small>Auction Number: $p->{ AuctionRef }<\/small>/gs ) {
            $self->{ ErrorStatus  } = 1;
            $self->{ ErrorMessage } = "Auction ".$p->{ AuctionRef }. " does not appear to be a valid auction number";
            return;
    }    

    # String to extract member ID from using the name and the "Buyer:" string and URL as the end anchor points
    # Extract the URL with the buyer name first then verify that the buyer name matches the submitted name
    # 14/05/06 Buyer:</td><td><a href="/Members/Listings.aspx?member=1323011"><b>southernhome</b>
    
    my $data = $content;    

    if ( $data =~ m/(Buyer:.+?)(\d+?)("><b>)($p->{ BuyerName })(<\/b>)/gs ) {          
        $buyerid = $2;                                                            
    } 
    else {
        $self->{ ErrorStatus    }   = 1;
        $self->{ ErrorMessage   }   = "Reference to buyer ".$p->{ BuyerName }." not found for auction ".$p->{ AuctionRef };
        return;
    }    

    return $buyerid;
}

#=============================================================================================
# Method    : get_member_no
# Added     : 22/12/08
# Input     : 
# Returns   : Integer
#
# Get Member name when a name is input
#=============================================================================================

sub get_member_no {

    my $self        = shift;
    my $membername  = shift;

    $url="http://www.trademe.co.nz/Browse/SearchResults.aspx?searchtype=SELLER&searchstring=".$membername;

    $req = HTTP::Request->new(GET => $url);
    $response = $ua->request($req);

    if ( $response->is_error() ) {
        return undef;
    }
    else {
        $content = $response->content();
    }

    if ( $content =~ m/(This member has been disabled)/g ) {
        return -1;
    } 

    if ( $content =~ m/(Member_)(\d+)/ ) {
        return $2;
    }
    else {
        return 0;
    }
    
}

#=============================================================================================
# Method    : get_member_location
# Added     : 22/12/08
# Input     : 
# Returns   : Integer
#
# Get Member location - input Trademe member ID
#=============================================================================================

sub get_member_location {

    my $self        = shift;
    my $memberid    = shift;

    $url="http://www.trademe.co.nz/Members/Profile.aspx?member=".$memberid;

    $req = HTTP::Request->new(GET => $url);
    $response = $ua->request($req);

    if ( $response->is_error() ) {
        return undef;
    }
    else {
        $content = $response->content();
    }

    if ( $content =~ m/(This member has been disabled)/g ) {
        return "DISABLED";
    } 

    if ( $content =~ m/(<b>Suburb:<\/b><\/small><\/td><td>)(.+?)(<\/td>)/gs ) {
        return $2;
    }
    else {
        return "NOT FOUND";
    }
    
}

#=============================================================================================
# Method    : put_feedback
# Added     : 02/06/08
# Input     : 
# Returns   : Integer
#
# This function returns 0 if successful other wise 1
#=============================================================================================

sub put_feedback {

    my $self    = shift;
    my $p       = { @_ };
    my $retries;
    my $uniquekey;

    $self->{Debug} ge "1" ? ( $self->update_log( "Invoked Method: ". (caller(0))[3] )) : () ;

    my $baseurl= "http://www.trademe.co.nz/MyTradeMe/Feedback/";

    if ( uc( $p->{ SaleType } ) eq "AUCTION" ) {
        $p->{ role } = "successful_bidder";
        $url = $baseurl."Submit.aspx?id=".$p->{ AuctionRef }."&bidderid=".$p->{ BuyerID };
    }

    if ( uc( $p->{ SaleType } ) eq "OFFER" ) {
        $p->{ Role } = "offer_recipient";
        $url = $baseurl."Submit.aspx?id=".$p->{ AuctionRef }."&offermemberid=".$p->{ BuyerID };
    }

    # Retrieve the requested auction page and if not found return with error message

    $retries = 1;
    
    while ( $retries lt 4 ) {
    
        $req      = HTTP::Request->new( GET => $url );
        $response = $ua->request( $req );              

        if ( $response->is_error() ) {

            $retries++;
            sleep 2;

            if ( $retries ge 4 ) {
                $self->{ ErrorStatus  } = 1;
                $self->{ ErrorMessage } = "Place Feedback page could not be retrieved - check the internet connection";
                return;
            }
        }
        else {
            $retries = 4;
        }
 
    }

    $content = $response->content();

    # Check that page parameters match all input parameters
    # extract the bidders role from the values returned on the post feedback input form
    # and also extract the unique key value generated as part of the process

    print "Placing Feedback\n";

    if ( $content =~ m/(name="OtherMemberId".+?value=")($p->{ BuyerID })(")/ ) {
        if ( $content =~ m/(name="ReferenceId".+?value=")($p->{ AuctionRef })(")/ ) {
            if ( $content =~ m/(name="UniqueKey".+?value=")(.+?)(")/ ) {
                $uniquekey = $2;
  
                print "Unique key extracted is: $uniquekey\n";
        
                $url = $baseurl."SubmitDone.aspx";
                $req = POST $url,
        
                [ "OtherMemberId"       =>  $p->{ BuyerID       }   ,
                  "ReferenceId"         =>  $p->{ AuctionRef    }   ,
                  "UserRole"            =>  "seller"                ,
                  "OtherMemberRole"     =>  $p->{ Role          }   ,
                  "UniqueKey"           =>  $uniquekey              ,
                  "feedback"            =>  $p->{ Feedback      }   ,
                  "positive"            =>  1                       ,
                ];
        
                # post the feedback
        
                $content = $ua->request($req)->as_string;

                unless ( $content =~ m/Your feedback has been placed/s ) {
                    $self->{ ErrorStatus    }   = 1;
                    $self->{ ErrorMessage   }   = "Unspecified error occurred placing feedback for ".$p->{ BuyerName }." on auction ".$p->{ AuctionRef }.".";
                    $self->{ ErrorMessage   }   = $self->{ ErrorMessage }." Check that feedback has been placed as expected";
                }
            }
            else {
                $self->{ ErrorStatus    }   = 1;
                $self->{ ErrorMessage   }   = "Could not extract unique key to place feedback. Possible TradeMe site change.";
            }
        }
        else {
            $self->{ ErrorStatus    }   = 1;
            $self->{ ErrorMessage   }   = "All feedback appears to have been placed for auction".$p->{ AuctionRef };
        }
    }
    else {
        $self->{ ErrorStatus    }   = 1;
        $self->{ ErrorMessage   }   = "Feedback already appears to have already been placed for buyer ".$p->{ BuyerName }. " on auction ".$p->{ AuctionRef };
    }
}

#=============================================================================================
# Method    : get_free_listing_limit
# Added     : 27/03/06
# Input     : 
# Returns   : Integer
#
# This function returns and integer value representing the number of items that can currently
# be listed on TradeMe without incurring the HVS (High Volume Seller) fee
#=============================================================================================

sub get_free_listing_limit {

    my $self = shift;           # TradeMe object

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    # Clear error indicator and error message properties

    $self->clear_err_structure();

    # -- Load the My TradeMe weekly summary page --

    # $url="http://www.trademe.co.nz/structure/my_listings_summary.asp";

    $url="http://www.trademe.co.nz/MyTradeMe/WeeklySummary.aspx";

    $req       = HTTP::Request->new(GET => $url);
    $response  = $ua->request($req);

    my $retries = 1;
    
    while ( $retries lt 4 ) {
    
        $req      = HTTP::Request->new(GET => $url);
        $response = $ua->request($req);              

        if ($response->is_error()) {

            $self->update_log("[get_free_listing_limit] Error retrieving Listing limit value; Retrying (attempt $retries)");
            $retries++;
            sleep 5;

            if ( $retries eq 4 ) {
                $self->update_log("[get_free_listing_limit] Error retrieving Listing limit value");
                $self->{ErrorStatus}  = "1";
                $self->{ErrorMessage} = "[get_free_listing_limit] Error retrieving Listing limit value";
                return;
            }
        }
        
        else {
        
            $retries = 4;
        }
 
    }

    # use a regular expression to extract the needed details
    # The HTML looks something like this (as at 27th March 2006)
    # ... you can list <strong>100</strong> ...
    # ... you can list 190 concurrent items ... (01/09/2008)

    $content = $response->content();

    # test the content for 0 sold items

    if  ( $content =~ m/(you can list )(\d+?)( concurrent items)/gs ) {

        $self->{free_listing_limit}  = $2;
    }
    else {
        $self->{free_listing_limit}  = 0;
    }

    return $self->{free_listing_limit};
}

#=============================================================================================
# Method    : get_free_listing_limit
# Added     : 27/03/06
# Input     : 
# Returns   : Currency decimal amount
#
# This function returns and integer value representing the number of items that can currently
# be listed on TradeMe without incurring the HVS (High Volume Seller) fee
#=============================================================================================

sub get_account_balance {

    my $self = shift;           # TradeMe object

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    # Clear error indicator and error message properties

    $self->clear_err_structure();

    # -- Load the My TradeMe page --

    $url="http://www.trademe.co.nz/MyTradeMe/Default.aspx";

    $req       = HTTP::Request->new(GET => $url);
    $response  = $ua->request($req);

    my $retries = 1;
    
    while ( $retries lt 4 ) {
    
        $req      = HTTP::Request->new(GET => $url);
        $response = $ua->request($req);              

        if ($response->is_error()) {

            $self->update_log("[get_account_balance] Error retrieving Listing Account Balance value; Retrying (attempt $retries)");
            $retries++;
            sleep 5;

            if ( $retries eq 4 ) {
                $self->update_log("[get_account_balance] Error retrieving Listing Account Balance value");
                $self->{ErrorStatus}  = "1";
                $self->{ErrorMessage} = "[get_account_balance] Error retrieving Listing Account Balance value";
                return;
            }
        }
        else {
            $retries = 4;
        }
    }

    # use a regular expression to extract the needed details
    # The HTML looks something like this (as at 6th June 2008)
    # <div class="accountsTextDiv"><b><a href="/MyTradeMe/AccountStatement.aspx">Trade Me account</a></b></div>
    # <div class="accountsTextDiv">Balance: <span style="color: #339900;"><b>$138.05</b></span></div>

    $content = $response->content();

    # If the accou/nt is not a PayNow acount use extraction test #1 otherwise use extraction test #2

    if  ( $content =~ m/(AccountWithoutPayNowCell)/gs ) {

        if  ( $content =~ m/(Balance:.+?<b>\$)(.+?)(<\/b>)/gs ) {
    
            $self->{ AccountBalance }  = $2;
        }
        else {
            $self->{ AccountBalance }  = 0;
        }
    }
    else {
        if  ( $content =~ m/(Trade Me account.+?<div class="accountsTextDiv">Balance:.+?<b>\$)(.+?)(<\/b>)/gs ) {
    
            $self->{ AccountBalance }  = $2;
        }
        else {
            $self->{ AccountBalance }  = 0;
        }
    }

    return $self->{ AccountBalance };
}


#=============================================================================================
# Method    : set_always_minimized
# Added     : 31/05/07
# Input     : "1" or "0" (other values are treated as "0" anyway)
# Returns   : sets the always minimized flag in the registry
#=============================================================================================

sub set_always_minimize {   #TODO

    my $self    = shift;
    my $p       = shift;

    # Setup the registry value applicable to the product

    my $regkey   = $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Options"}
              or die "Package Auctionitis.pm can't read HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Options key: $^E\n";

    # if the value is "1" set the always minimize flag on otherwise set it off 
    
    if ( $p eq "1" ) {
        $regkey->{ "/AlwaysMinimize" }  = "1";
    }
    else {
        $regkey->{ "/AlwaysMinimize" }  = "0";
    }
    
    return;
}

#=============================================================================================
# Method    : calc_close_time
# Added     : 3/12/05
# Input     : String containing close time from current/sold/unsold listings pages
# Returns   : String formatted as time in hh:mm:ss format including padded zeros
#=============================================================================================

sub calc_close_time {

    my $expr = shift;
    my $hh;

    # Code pre 10/05/2006

    # $expr =~ m/(&nbsp;&nbsp;)(.+?)(:)(.+?)(&nbsp;)(am|pm)/;
    # if   (($6 eq "pm") and ($2 < 12)) { $hh = $2+12; }
    # else                              { $hh = $2;    }

    # my $mm = $4;
    # my $closet = $hh.":".$mm.":00";


    # Code as at 10/05/2006

    #            &nbsp;  Wed  &nbsp;   10  &nbsp;  May  &nbsp;   6   :  04   &nbsp;   pm
    #            1       2     3       4    5      6     7       8  9  10   1        12
    
    $expr =~ m/(&nbsp;)(.+?)(&nbsp;)(.+?)(&nbsp;)(.+?)(&nbsp;)(.+?)(:)(.+?)(&nbsp;)(am|pm)/;
    

    if   (($12 eq "pm") and ($8 < 12)) { $hh = $8+12; }
    else                               { $hh = $8;    }

    my $mm = $10;
    my $closet = $hh.":".$mm.":00";


    return $closet
    
}

#=============================================================================================
# Method    : calc_close_date
# Added     : 3/12/05
# Input     : String containing close date from current/sold/unsold listings pages
#           : Variable indicating which listing type the string comes from
# Returns   : String formatted as dd-mth-yyyy
#=============================================================================================

sub calc_close_date {

    my $dateexpr    = shift;
    my $listtype    = shift;
    
    # $dateexpr =~ m/(&nbsp;)(.+?)(&nbsp;)(.+?)(&nbsp;)(.+?)(&nbsp;&nbsp;)/;        # pre 10/05/2006
    $dateexpr =~ m/(&nbsp;)(.+?)(&nbsp;)(.+?)(&nbsp;)(.+?)(&nbsp;)/;                # 10/05/2006

    my $curmth = (localtime)[4]+1;
    my $curyr  = (localtime)[5]+1900;

    my ($dd,$mm,$mth,$yy);

    $dd = $4;

    if      ( $6 eq 'Jan' ) { $mm =  1; }
    elsif   ( $6 eq 'Feb' ) { $mm =  2; }
    elsif   ( $6 eq 'Mar' ) { $mm =  3; }
    elsif   ( $6 eq 'Apr' ) { $mm =  4; }
    elsif   ( $6 eq 'May' ) { $mm =  5; }
    elsif   ( $6 eq 'Jun' ) { $mm =  6; }
    elsif   ( $6 eq 'Jul' ) { $mm =  7; }
    elsif   ( $6 eq 'Aug' ) { $mm =  8; }
    elsif   ( $6 eq 'Sep' ) { $mm =  9; }
    elsif   ( $6 eq 'Oct' ) { $mm = 10; }
    elsif   ( $6 eq 'Nov' ) { $mm = 11; }
    elsif   ( $6 eq 'Dec' ) { $mm = 12; }

    if ( $listtype eq "FUTURE" ) {

        if      ( $mm <  $curmth ) { $yy =  $curyr + 1;  }
        elsif   ( $mm == $curmth ) { $yy =  $curyr;      }
        elsif   ( $mm >  $curmth ) { $yy =  $curyr;      }
    }

    if ( $listtype eq "PAST" ) {
    
        if      ( $mm <  $curmth ) { $yy =  $curyr;      }
        elsif   ( $mm == $curmth ) { $yy =  $curyr;      }
        elsif   ( $mm >  $curmth ) { $yy =  $curyr - 1;  }
    }

    if      ( $mm eq  1 ) { $mth = 'Jan'; }
    elsif   ( $mm eq  2 ) { $mth = 'Feb'; }
    elsif   ( $mm eq  3 ) { $mth = 'Mar'; }
    elsif   ( $mm eq  4 ) { $mth = 'Apr'; }
    elsif   ( $mm eq  5 ) { $mth = 'May'; }
    elsif   ( $mm eq  6 ) { $mth = 'Jun'; }
    elsif   ( $mm eq  7 ) { $mth = 'Jul'; }
    elsif   ( $mm eq  8 ) { $mth = 'Aug'; }
    elsif   ( $mm eq  9 ) { $mth = 'Sep'; }
    elsif   ( $mm eq 10 ) { $mth = 'Oct'; }
    elsif   ( $mm eq 11 ) { $mth = 'Nov'; }
    elsif   ( $mm eq 12 ) { $mth = 'Dec'; }

    my $closed = $dd."-".$mth."-".$yy;
    return $closed
    
}

#=============================================================================================
# Get Auction Details from TradeMe
# This functions need 1 parameters: auction ref
# It logs into trademe and extracts the auction details;
# It always returns a status
#=============================================================================================

sub get_auction_details {

    my $self  = shift;
    my $auctionref = shift;
    my $data;
    my $section;

    $self->{ Debug } ge "1" ? ( $self->update_log( "Invoked Method: ". ( caller( 0 ) )[3] ) ) : () ;

    $data->{ AuctionRef } = $auctionref; 

    $url="http://www.trademe.co.nz/structure/auction_detail.asp?id=".$auctionref;

    $req = HTTP::Request->new(GET => $url);
    $response = $ua->request($req);

    if     ($response->is_error()) {
            printf " %s\n", $response->status_line;
            die "Cannot connect or unable retrieve data";
    } else {
            $content = $response->content();

            if    ( $content =~ m/This item is no longer available/ ) {
                   $data->{ Status } = "NOTFOUND";}
            elsif ( $content =~ m/Closed: / )                         {
                   $data->{ Status } = "CLOSED"  ;}
            elsif ( $content =~ m/This auction has been relisted/ )   {
                   $data->{ Status } = "RELISTED";}
            else  {
                   $data->{ Status } = "CURRENT" ;}
    }


    #-----------------------------------------------------------------
    # Processing for an ACTIVE auction
    #-----------------------------------------------------------------

    if      ($data->{Status} eq "CURRENT") {

            # Get auction title

            if   ($content =~ m/(<title>)(.+?)( for sale - TradeMe)/) {$data->{Title} = $2;}
            $data->{Title} =~ s/&quot;/"/g;           # remove HTML &quot (") substitution values from description
            $data->{Title} =~ s/&amp;/&/g;            # remove HTML &amp (&) substitution values from description
            $data->{Title} =~ s/&#8216;/`/g;          # remove HTML &amp (&) substitution values from description
            $data->{Title} =~ s/&#8217;/'/g;          # remove HTML &amp (&) substitution values from description "'

            # Get auction close date and time

            if   ($content =~ m/(Closes <b> )(\d+)(:)(\d+)(\s+)(am|pm)(,)(\s+)(.+?)(\s+)(\d+)(\s+)(.+?)(\.)/) {

                 if   (($6 eq "pm") and ($2 < 12)) {$data->{CloseTime} = (($2+12).$3.$4);}
                 else                              {$data->{CloseTime} = ($2.$3.$4);}

                my($mm, $yy)   = (localtime(time))[4,5];
                
                if     ( $13 < ($mm + 1) ) {
                         $yy =  $yy + 1900 +1;
                } else { 
                         $yy =  $yy + 1900;
                }

                 $data->{CloseDate} = $11."-".$13."-".$yy;
            }
            
            # Reserve Met flag

            if   ($content =~ m/reserve price has not been met/) {$data->{ReserveMet} = 0;}
            else                                                 {$data->{ReserveMet} = 1;}

            # Buy Now Price
            # HTML as at 1/1/2005 (line breaks inserted to make it more readable)
            # <tr><td><span style="color: #666666;">Buy Now:</span></td><td>&nbsp;</td>
            # <td align="right"><span style="color: #666666;">$39.99</span></td><td colspan="2">&nbsp;</td></tr>
            
            if   ($content =~ m/(<td>)(.+?)(Buy Now:)(.+?)(\$)(.+?)(<)/) {$data->{BuyNowPrice} = $6;}

            # Start price
            # HTML as at 1/1/2005 (line breaks inserted to make it more readable)
            # <tr><td><span style="color: #666666;">Start price:</span></td><td>&nbsp;</td>
            # <td align="right"><span style="color: #666666;">$37.99</span></td><td colspan="2">&nbsp;</td></tr>
            
            if   ($content =~ m/(<td>)(.+?)(Start price:)(.+?)(\$)(.+?)(<)/) {$data->{StartingPrice} = $6;}

            # Reserve price
            # HTML as at 1/1/2005 (line breaks inserted to make it more readable)
            # <tr><td><span style="color: #666666;">Reserve:</span></td><td>&nbsp;</td>
            # <td align="right"><span style="color: #666666;">$37.99</span></td><td colspan="2">&nbsp;</td></tr>

            if   ($content =~ m/(<td>)(.+?)(Reserve:)(.+?)(\$)(.+?)(<)/)  {$data->{ReservePrice} = $6;}

            # Current Bid value
            # HTML as at 1/1/2005 (line breaks inserted to make it more readable)
            # Current bid:</td><td>&nbsp;</td><td align="right">No bids</td>
            
            if   ($content =~ m/(Current bid:<\/td><td>&nbsp;<\/td><td align="right">)(.*?)(<\/td>)/) 
                 { $data->{CurrentBid} = $2; }
            if   ($data->{CurrentBid} eq "No bids")                     { $data->{CurrentBid} = 0; }
            
            # brand New item flag
            # <small>&nbsp;Brand New Item</small>

            if   ($content =~ m/<small>&nbsp;Brand New Item<\/small>/)  {$data->{BrandNew} = 1;}
            else                                                        {$data->{BrandNew} = 0;}

            # Auction Description HTML extracted as at 1/1/2005
            # Views: <b>5</b>&nbsp;&nbsp;&nbsp;</span></td></tr></table><br/>
            # <table border=0 cellspacing=0 width=100% cellpadding=0><tr valign=top><td>
            # <table border=0 cellpadding=0 cellspacing=0></table>
            # <br><table cellpadding=0 cellspacing=0><tr><td>
            # <img src="/images/icon_new_item.gif" align=absmiddle border=0></td>
            # <td><small>&nbsp;Brand New Item</small></td></tr></table><img src="/images/1pixel.gif" height=6 border=0>
            # <br>You are invited to bid on this Contemporary Red Coral Sterling Silver Ring in size US 8 / NZ Q as pictured.<br> ...
            # ... [Loaded by Auctionitis]<br><br><br></td>

#            if   ($content =~ m/(<br><table cellpadding=0 cellspacing=0>)(.*?)(<br>)(.*?)(<\/td>)/s) { $data->{Description} = $4; }

            # Description pattern as at 19/2/2005 --- This needs some work and analysis to make sturdier !!!! ---

            
#            if   ($content =~ m/(<img src="\/images\/1pixel\.gif" height=6 border=0>)(.*?)(<\/td>)/s) { 
#            pos=0;
            if   ( $content =~ m/(height=6 border=0>)(.*?)(<\/td>)/s ) { $data->{Description} = $2; }
                  
            $data->{Description} =~ s/<br>//g;                          # remove HTML <br> instructions from description
            $data->{Description} =~ s/&quot;/"/g;                       # remove HTML &quot (") substitution values from description
            $data->{Description} =~ s/&amp;/&/g;                        # remove HTML &amp (&) substitution values from description
            $data->{Description} =~ s/&#8216;/`/g;                      # remove HTML &amp (&) substitution values from description
            $data->{Description} =~ s/&#8217;/'/g;                      # remove HTML &amp (&) substitution values from description
            $data->{Description} =~ s/\[Loaded by Auctionitis\]//g;     # remove Auctionitis Tag

            # Category

            while ($content =~ m/(mcat-)(.+?)(\.htm)/g)                         {$section = $2;}
            while ($section =~ m/(\d+)(-)/g)                                    {$data->{Category} = $1;}

            # Photo Id

            if   ($content =~ m/(PhotoId-)(\d+)(\/title)/)                      {$data->{PhotoId} = $2;}

            # SafeTrader

            if    ($content =~ m/Doesn't support SafeTrader/)                   {$data->{SafeTrader} = 0}
            elsif ($content =~ m/Will use SafeTrader if the buyer pays/)        {$data->{SafeTrader} = 3}

            # Unanswered questions flag

            if   ($content =~ m/(unanswered question)/)                         {$data->{Questions} = 1;}
            else                                                                {$data->{Questions} = 0;}

            # Auto extend
            
            if   ($content =~ m/This auction may auto-extend/)                  {$data->{AutoExtend} = 1;}
            else                                                                {$data->{AutoExtend} = 0;}

            # get number of bids
            # Bids: <b>0</b>

            if   ($content =~ m/(Bids: <b>)(.+?)(<\/b>)/)                       {$data->{Bids} = $2;}

            # High bidder name, high bidder ID and number of feedbacks
            
            if   ($data->{Bids} ne 0) {
                  if ($content =~ m/(Bid history)(.+?)(<hr size=0>)(.+?)(<hr size=0>)/) {
                      $section = $4;
                      if ($section =~ m/(.+?)(<font color=#0033cc><b>)(.+?)(<\/b>)(.+?)(member=)(\d+)("><font color=#0033cc>)(.+?)(<\/font>)/) {
                          $data->{HighBidderID} = $7;                
                          $data->{HighBidder} = $3;                
                          $data->{HighBidderRating} = $9;
                          if ($data->{HighBidderRating} eq "new")  {$data->{HighBidderRating} = 0;}
                      }
                  }
            } else {
                      $data->{HighBidderID} = "";                
                      $data->{HighBidder} = "";                
                      $data->{HighBidderRating} = 0;
            }
            
            if ($content =~ m/(<td.+?Monitor:.+?<\/td>.+?<\/td><td>)(.+?)(<\/td>)/gs)  {$data->{Monitor} = $2;}

    }

    #-------------------------------------------------------------------
    # Processing for an CLOSED auction
    #-------------------------------------------------------------------

    if      ($data->{Status} eq "CLOSED") {

            # Determine if auction was passed in or sold and change status accordingly

            if     ($content =~ m/This auction finished and did not meet the reserve price/) {
                    $data->{Status} = "PASSEDIN";}
            elsif  ($content =~ m/You withdrew this listing/)                                {
                    $data->{Status} = "WITHDRAWN";}
            elsif  ($content =~ m/No bids were placed in the auction/)                       {
                    $data->{Status} = "PASSEDIN";}
            elsif  ($content =~ m/The item sold with 'Buy Now' for /)                        {
                    $data->{Status} = "BUYITNOW";}
            elsif  ($content =~ m/You have relisted this item/)                              {
                    $data->{Status} = "RELISTED";}
            else   {$data->{Status} = "SOLD";}

            # Get auction description

            if   ($content =~ m/(<title>)(.+?)( for sale - TradeMe)/) {$data->{Title} = $2;}
            $data->{Title} =~ s/&quot;/"/g;           # remove HTML &quot (") substitution values from description
            $data->{Title} =~ s/&amp;/&/g;            # remove HTML &amp (&) substitution values from description
            $data->{Title} =~ s/&#8216;/`/g;          # remove HTML &amp (&) substitution values from description
            $data->{Title} =~ s/&#8217;/'/g;          # remove HTML &amp (&) substitution values from description

            # Get auction close date and time
            if   ($content =~ m/(<small>Closed:\s+)(\d+)(:)(\d+)(\s+)(am|pm)(,)(\s+)(.+?)(\s+)(\d+)(\s+)(.+?)(\s+)(\d+)(<\/small>)/) {

                 if   (($6 eq "pm") and ($2 < 12)) {$data->{CloseTime} = (($2+12).$3.$4);}
                 else                              {$data->{CloseTime} = ($2.$3.$4);}

                 $data->{CloseDate} = $11."-".$13."-".$15;
            }

            # Relisted Flag

            if   ($content =~ m/You have relisted this item/)    {$data->{Relisted} = 1;}
            else                                                 {$data->{Relisted} = 0;}


            # Reserve Met flag

            if   ($content =~ m/reserve price has not been met/) {$data->{ReserveMet} = 0;}
            else                                                 {$data->{ReserveMet} = 1;}


            # brand New item flag
            # <small>&nbsp;Brand New Item</small>

            if   ($content =~ m/<small>&nbsp;Brand New Item<\/small>/)  {$data->{BrandNew} = 1;}
            else                                                        {$data->{BrandNew} = 0;}

            # Auction Description

            if   ($content =~ m/(<table border=0 cellspacing=0 width=100% cellpadding=0>)(.*?)(<br>)(.*?)(<\/td>)/s) {
                  $data->{Description} = $4;}
            $data->{Description} =~ s/<br>//g;              # remove HTML <br> instructions from description
            $data->{Description} =~ s/&quot;/"/g;           # remove HTML &quot (") substitution values from description
            $data->{Description} =~ s/&amp;/&/g;            # remove HTML &amp (&) substitution values from description
            $data->{Description} =~ s/&#8216;/`/g;          # remove HTML &amp (&) substitution values from description
            $data->{Description} =~ s/&#8217;/'/g;          # remove HTML &amp (&) substitution values from description '

            # Category

            while ($content =~ m/(mcat-)(.+?)(\.htm)/g)                         {$section = $2;}
            while ($section =~ m/(\d+)(-)/g)                                    {$data->{Category} = $1;}

            # Photo Id

            if   ($content =~ m/(PhotoId-)(\d+)(\/title)/)                      {$data->{PhotoId} = $2;}

            # get number of bids

            if   ($content =~ m/(no bids have been placed on this auction)/)    {$data->{Bids} = 0;}

            if   ($content =~ m/(<b>Bid history - )(\d+?)(\s+)/)                {$data->{Bids} = $2;}
            
            if   (not defined $data->{Bids}) {
                  $data->{Bids} = 0;
                  if ($content =~ m/(Bid history<\/b><hr size=0>)(.+?)(<hr size=0>)/) {
                      $section = $2;
                      while ($section =~ m/show_member_listings/g) {
                             $data->{Bids} ++;
                      }
                  }
            }

            # High bidder name, high bidder ID and number of feedbacks
            
            if   ($data->{Bids} ne 0) {
                  if ($content =~ m/(Bid history)(.+?)(<hr size=0>)(.+?)(<hr size=0>)/) {
                      $section = $4;
                      if ($section =~ m/(.+?)(<font color=#0033cc><b>)(.+?)(<\/b>)(.+?)(member=)(\d+)("><font color=#0033cc>)(.+?)(<\/font>)/) {      #"
                          $data->{HighBidderID} = $7;                
                          $data->{HighBidder} = $3;                
                          $data->{HighBidderRating} = $9;
                          if ($data->{HighBidderRating} eq "new")  {$data->{HighBidderRating} = 0;}
                      }
                  }
            } else {
                      $data->{HighBidderID} = "";                
                      $data->{HighBidder} = "";                
                      $data->{HighBidderRating} = 0;
            }

            if ($content =~ m/(<td.+?>Monitor:<.+?<\/td>)(<td.+?<\/td>)(<td>)(.+?)(<\/td>)/gs)  {$data->{Monitor} = $4;}
    }

    return $data;
}

#=============================================================================================
# Method    : get_auction_content
# Added     : 19/06/09
# Input     : Hash
# Parameters: AuctionRef - Auction Reference Number
# Returns   : Content from page or undef if page not found
#=============================================================================================

sub get_auction_content {

    my $self    = shift;
    my $p       = { @_ };

    $self->{ Debug } ge "1" ? ( $self->update_log( "Invoked Method: ". ( caller( 0 ) )[3] ) ) : () ;

    $self->{ ErrorStatus  } = 0;
    $self->{ ErrorMessage } = "";

    $url = "http://www.trademe.co.nz/Browse/Listing.aspx?id=".$p->{ AuctionRef };

    # Retrieve the requested auction page and if not found return with error message

    my $retries = 1;
    
    while ( $retries lt 4 ) {
    
        $req      = HTTP::Request->new( GET => $url );
        $response = $ua->request( $req );              
        $self->{ Debug } ge "1" ? ( $self->update_log( "HTTP Response Code: ".$response->status_line ) ) : () ;

        if ( $response->is_error() ) {

            $retries++;
            sleep 2;

            if ( $retries ge 4 ) {
                $self->{ ErrorStatus  } = 1;
                $self->{ ErrorMessage } = "Auction details page could not be retrieved - check the internet connection";
                $self->{ Debug } ge "1" ? ( $self->update_log( "HTTP Response Code: ".$response->status_line ) ) : () ;
                return undef;
            }
        }
        else {
            $retries = 4;
        }
 
    }

    $content = $response->content();

    return $content;
}


#=============================================================================================
# Method    : get_pending_offers    
# Added     : 11/08/08
# Input     :
# Returns   : Array of hash references
#
# This method returns a list of completed auctions that have not had an FPO made on TradeMe
# All auctions with a status of SOLD or UNSOLD that have an offer amount assigned are returned
#=============================================================================================

sub get_pending_offers {

    my $self    = shift;
    my $select  = shift;
    my $returndata;
    my $SQL;

    $self->{ Debug } ge "1" ? ( $self->update_log( ( caller( 0 ) )[3] ) ) : () ;

    $self->clear_err_structure();

    if ( uc( $select ) eq "ALL" ) {
        $SQL = qq {
            SELECT        *
            FROM          Auctions
            WHERE   ( ( ( AuctionStatus    =  'SOLD'    ) 
            OR          ( AuctionStatus    =  'UNSOLD'  ) )
            AND         ( OfferPrice       >  0         ) 
            AND         ( OfferProcessed   =  0         ) )
        };
    }
    elsif ( uc( $select ) eq "SOLD" ) {
        $SQL = qq {
            SELECT        *
            FROM          Auctions
            WHERE     ( ( AuctionStatus    =  'SOLD'    ) 
            AND         ( OfferPrice       >  0         ) 
            AND         ( OfferProcessed   =  0         ) )
        };
    }
    elsif ( uc( $select ) eq "UNSOLD" ) {
        $SQL = qq {
            SELECT        *
            FROM          Auctions
            WHERE     ( ( AuctionStatus    =  'UNSOLD'  ) 
            AND         ( OfferPrice       >  0         ) 
            AND         ( OfferProcessed   =  0         ) )
        };
    }

    $self->update_log("Executing SQL Statement:\n".$SQL);
    print "Executing SQL Statement:\n".$SQL;

    my $sth = $dbh->prepare( $SQL );
    
    $sth->execute();

    $returndata = $sth->fetchall_arrayref( {} );

    # If the record was found return the details otherwise populate the error structure

    if     ( defined( $returndata ) ) {    

            return $returndata;
            
    } else {
    
            $self->{ErrorStatus}    = "1";
            $self->{ErrorMessage}   = "No auctions are eligible for offering on TradeMe";
            $self->{ErrorDetail}    = "";
            return undef;
    }
}

#=============================================================================================
# Method    : make_offer
# Added     : 01/04/08
# Input     : Auction reference
# Returns   : has containg details of the offer or undef on failure 
#=============================================================================================

sub make_offer {

    my $self            = shift;
    my $p               = { @_ };
    my %offerdata;
    my $hasbidders;
    my $haswatchers;

    $self->{ Debug } ge "1" ? ( $self->update_log("Invoked Method: ". ( caller( 0 ) )[3] ) ) : () ;

    $self->clear_err_structure();

    $self->update_log( "Fixed Price Offer Processing for auction ".$p->{ AuctionRef } );

    # Get the offer input screen so that bidder/watcher details can be extracted and tested

    $url="http://www.trademe.co.nz/MyTradeMe/MakeAnOffer.aspx?id=".$p-> { AuctionRef };

    $req = HTTP::Request->new(GET => $url);
    $response = $ua->request($req);

    if ( $response->is_error() ) {
        $self->{ ErrorStatus    }    = "1";
        $self->{ ErrorMessage   }    = "Auction ".$p-> { AuctionRef }." was not found";
        $self->{ ErrorDetail    }    = "";
        $self->update_log( "Error: Auction ".$p-> { AuctionRef }." was not found" );
        return undef;
    }
    else {
        $content = $response->content();
    }

    # Check whether a fixed price offer can be made on the auction

    if ( $content =~ m/You are unable to make a Fixed Price Offer as all bidders and watchers have removed this item from their watchlist/gs )  {
        $self->update_log( "Auction ".$p-> { AuctionRef }." is not eligible for Offer" );
        return;
    }

    $offerdata{ OfferCount      } = 0;
    $offerdata{ BidderCount     } = 0;
    $offerdata{ WatcherCount    } = 0;

    # Set the initial parameters for the offer using the method input

    my %offer;

    $offer{ "id"                } = "$p->{ AuctionRef }";
    $offer{ "status"            } = "confirmed";
    $offer{ "valid_for"         } = "$p->{ OfferDuration }";

    # Extract Reserve

    $content =~ m/(<td.+?Reserve price was.+?>\$)(.+?)(<\/td>)/;
    $offerdata{ Reserve } = $2;

    # Extract High Bid

    $offerdata{ HighBid } = 0;

    if ( $content =~ m/(<td.+?Highest bid was.+?>\$)(.+?)(<\/td>)/ ) {
        $offerdata{ HighBid } = $2;
    }

    # Check/re-calculate the Offer amount value using the highest Bid value

    if ( $p->{ UseHighestBid } and $offerdata{ HighBid } > $p->{ OfferPrice } ) {
        $offer{ "offer_price"       } = $offerdata{ HighBid };
        $offerdata{ OfferPrice      } = $offerdata{ HighBid };
    }
    else {
        $offer{ "offer_price"       } = $p->{ OfferPrice    };
        $offerdata{ OfferPrice      } = $p->{ OfferPrice    };
    }

    # Extract text containing Bidder details:

    $content =~ m/(>Bidders.+?)(<table.+?>)(.+?)(<\/table>)(.+?>Watchers)/;
    my $bidderblock = $3;

    # Extract text containing Watcher details:

    $content =~ m/(>Watchers.+?)(<table.+?>)(.+?)(<\/table>)(.+?>Valid for)/;
    my $watcherblock = $3;
    $self->update_log( "Auction:".$p-> { AuctionRef }." Reserve:".$offerdata{ Reserve }." High Bid:".$offerdata{ HighBid }." Offer Price:".$p->{ OfferPrice } );


    # Processing from here extracts individual member details and decides whether to include them or not
    # --------------------------------------------------------------------------------------------------

    # Process BIDDERS
    # ---------------

    # If the text block is not equal to the none value process the text block

    if ( $bidderblock ne "<tr><td>None</td></tr>" ) {

        # process each row in the table; 1 row = 1 bidder/watcher

        while ( $bidderblock =~ m/(<tr.+?>)(.+?)(<\/tr>)/gs ) {

            my $data = $2;

            $offerdata{ BidderCount }++;

            # $data =~ m/(<a href="\/Members\/Feedback\.aspx\?member=)(\d+)(.+?>)(\d+)(<\/a>)/;  modified 9/2/09
            $data =~ m/(<a href="\/Members\/Feedback\.aspx\?member=)(\d+)(.+?>)(\d+|new)(<\/a>)/;

            my $memberid = $2;
            my $feedback = $4;

            if ( $feedback eq "new" ) {
                $feedback = 0;
            }

            $data =~ m/(<a href="\/Members\/Listings\.aspx\?member=.+?><b>)(.+?)(<\/b>)/;

            my $membername = $2;

            # Check if blacklisted

            my $blacklisted = "No";

            if ( $data =~ m/<b>Blacklisted<\/b>/ ) {
                $blacklisted = "Yes";
            }

            # Check if authenticated

            my $authenticated = "No";

            if ( $data =~ m/\/images\/star/ ) {
                $authenticated = "Yes";
            }

            # Check if address verified

            my $addverified = "No";

            if ( $data =~ m/\/images\/icon_av/ ) {
                $addverified = "Yes";
            }

            # Set value for hasBidders form value

            $hasbidders = "1";

            # Log the offer details

            my $msg =  "Considering Bidder:".$membername."(".$feedback.") ID:".$memberid." Auth:".$authenticated." AV:".$addverified." BL:".$blacklisted;
            $self->update_log( $msg );

            # If Bidder/Watchers blacklisted: Don't make the offer

            if ( $blacklisted eq "Yes" ) {
                $self->update_log( "Ignored: Blacklisted" );
                next;
            }

            # If Offer to Bidders not selected: Don't make the offer

            if ( $p->{ OfferBidders } ne "1" ) {
                $self->update_log( "Ignored: Offer to Bidders not specified" );
                next;
            }

            # If Authenticated only selected & bidder/watcher is not authenticated: Don't make the offer

            if ( $p->{ AuthenticatedOnly } and $authenticated eq "No"  ) {
                $self->update_log( "Ignored: Offer to Authenticated Only specified" );
                next;
            }

            # If Address-verified only selected & bidder/watcher is not authenticated: Don't make the offer

            if ( $p->{ AVOnly } and $addverified eq "No"  ) {
                $self->update_log( "Ignored: Offer to Address Verified Only specified" );
                next;
            }

            # If Feedback Minimum specified & bidder/watcher is below minimum: Don't make the offer

            if ( $feedback < $p->{ FeedbackMinimum }  ) {
                $self->update_log( "Ignored: Offer Feedback Minimum of ".$p->{ FeedbackMinimum }." specified" );
                next;
            }

            # If we get to here, we can add the offer to the offer list

            $self->update_log( "Approved: Item will be offered to Bidder ".$membername );
            $offer{ "bidder_id_".$memberid  } = "on";
            $offerdata{ OfferCount }++;

        }
    }
    else {
        $self->update_log( "No Bidders found for auction ".$p->{ AuctionRef } );
        $hasbidders = "0";
        $offer{ HasBidders } = "$hasbidders";
    }

    # Process WATCHERS
    # ----------------

    # If the text block is not equal to the none value process the text block
    
    if ( $watcherblock ne "<tr><td>None</td></tr>" ) {

        # process each row in the table; 1 row = 1 bidder/watcher

        while ( $watcherblock =~ m/(<tr.+?>)(.+?)(<\/tr>)/gs ) {

            my $data = $2;

            $offerdata{ WatcherCount }++;

            # $data =~ m/(<a href="\/Members\/Feedback\.aspx\?member=)(\d+)(.+?>)(\d+)(<\/a>)/; modified 9/2/09
            $data =~ m/(<a href="\/Members\/Feedback\.aspx\?member=)(\d+)(.+?>)(\d+|new)(<\/a>)/;

            my $memberid = $2;
            my $feedback = $4;

            if ( $feedback eq "new" ) {
                $feedback = 0;
            }

            $data =~ m/(<a href="\/Members\/Listings\.aspx\?member=.+?><b>)(.+?)(<\/b>)/;

            my $membername = $2;

            # Check if blacklisted

            my $blacklisted = "No";

            if ( $data =~ m/<b>Blacklisted<\/b>/ ) {
                $blacklisted = "Yes";
            }

            # Check if authenticated

            my $authenticated = "No";

            if ( $data =~ m/\/images\/star/ ) {
                $authenticated = "Yes";
            }

            # Check if address verified

            my $addverified = "No";

            if ( $data =~ m/\/images\/icon_av/ ) {
                $addverified = "Yes";
            }

            # Set value for hasWatchers form value

            $haswatchers = "1";
            $offer{ "hasWatchers"       } = "$haswatchers";

            # Log the offer details

            my $msg =  "Considering Watcher:".$membername."(".$feedback.") ID:".$memberid." Auth:".$authenticated." AV:".$addverified." BL:".$blacklisted;
            $self->update_log( $msg );

            # If Bidder/Watchers blacklisted: Don't make the offer

            if ( $blacklisted eq "Yes" ) {
                $self->update_log( "Ignored: Blacklisted" );
                next;
            }

            # If Offer to Watchers not selected: Don't make the offer

            if ( $p->{ OfferWatchers } ne "1" ) {
                $self->update_log( "Ignored: Offer to Watchers not specified" );
                next;
            }

            # If Authenticated only selected & bidder/watcher is not authenticated: Don't make the offer

            if ( $p->{ AuthenticatedOnly } and $authenticated eq "No"  ) {
                $self->update_log( "Ignored: Offer to Authenticated Only specified" );
                next;
            }

            # If Address-verified only selected & bidder/watcher is not authenticated: Don't make the offer

            if ( $p->{ AVOnly } and $addverified eq "No"  ) {
                $self->update_log( "Ignored: Offer to Address Verified Only specified" );
                next;
            }

            # If Feedback Minimum specified & bidder/watcher is below minimum: Don't make the offer

            if ( $feedback < $p->{ FeedbackMinimum }  ) {
                $self->update_log( "Ignored: Offer Feedback Minimum of ".$p->{ FeedbackMinimum }." specified" );
                next;
            }

            # If we get to here, we can add the offer to the offer list
            # test to see if we should add the item to the offer list

            $self->update_log( "Approved: Item will be offered to Watcher ".$membername );
            $offer{ "bidder_id_".$memberid  } = "on";
            $offerdata{ OfferCount }++;
        }
    }
    else {
        $self->update_log( "No Watchers found for auction ".$p->{ AuctionRef } );
        $haswatchers = "0";
        $offer{ HasWatchers } = "$haswatchers";
    }

    if ( $offerdata{ OfferCount } > 0 ) {
        $self->update_log( "Auction ".$p->{ AuctionRef }." offered for ".$offerdata{ OfferPrice }."; there were ".$offerdata{ OfferCount }. " offers made" );

        $url="http://www.trademe.co.nz/MyTradeMe/MakeAnOfferDone.aspx";

        # Set the FPODebug valuein the registry to allo offer processign to be tested without actually being processed
        # This allows us to simulate what will happen for settings without compromising the offer process

        unless ( $self->{ FPODebug } ) {
            $req = POST $url, [ %offer ];
            $content = $ua->request( $req )->as_string;
        }
    }
    else {
        $self->update_log( "Auction ".$p->{ AuctionRef }." was not offered; no bidders or watchers met offer criteria" );
    }

    # Return the Offer data hash object which has the offer meta-data

    return \%offerdata;
}

#=============================================================================================
# Method    : add_offer_record
# Added     : 01/04/08
# Input     : Hash with offer column values
# Returns   : 
#=============================================================================================

sub add_offer_record {

    my $self = shift;
    my $input = { @_ };
    my $r;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    $self->clear_err_structure();

    # Set default values for new record
    # Key value Offer Key is defined as Autonumber and will be generated by the database
    
    $r->{ Offer_Date        }   = $self->datenow()  ;
    $r->{ AuctionRef        }   = "0"               ;
    $r->{ Offer_Duration    }   = 1                 ;
    $r->{ Offer_Amount      }   = "00:00:01"        ;
    $r->{ Highest_Bid       }   = ""                ;
    $r->{ Offer_Reserve     }   = 0                 ;
    $r->{ Actual_Offer      }   = 0                 ;
    $r->{ Bidder_Count      }   = 0                 ;
    $r->{ Watcher_Count     }   = 0                 ;
    $r->{ Offer_Count       }   = 0                 ;
    $r->{ Offer_Successful  }   = 0                 ;
    $r->{ Offer_Type        }   = "NONE"            ;

    # Read through the input values and alter the corresponding fields in the "Record" hash

    while ( ( my $key, my $value ) = each( %{ $input } ) ) {
            $r->{ $key } = $value;
    }

    # Prepare the SQL Insert Statement

    my $SQL = qq { 
        INSERT INTO Offers ( 
            Offer_Date          ,      
            AuctionRef          ,
            Offer_Duration      ,
            Offer_Amount        ,
            Highest_Bid         ,
            Offer_Reserve       ,
            Actual_Offer        ,
            Bidder_Count        ,
            Watcher_Count       ,
            Offer_Count         ,
            Offer_Successful    ,
            Offer_Type          )
        VALUES             ( ?,?,?,?,?,?,?,?,?,?,?,? )     
    };

    print $SQL."\n";

    my $sth = $dbh->prepare( $SQL );

    $sth->execute(
       "$r->{ Offer_Date        }"  ,
       "$r->{ AuctionRef        }"  ,
        $r->{ Offer_Duration    }   ,
        $r->{ Offer_Amount      }   ,
        $r->{ Highest_Bid       }   ,
        $r->{ Offer_Reserve     }   ,
        $r->{ Actual_Offer      }   ,
        $r->{ Bidder_Count      }   ,
        $r->{ Watcher_Count     }   ,
        $r->{ Offer_Count       }   ,
        $r->{ Offer_Successful  }   ,
       "$r->{ Offer_Type        }"  ,
    )              
    || die "insert_offer_record - Error executing statement: $DBI::errstr\n";
}

#=============================================================================================
# Method    : add_question_record
# Added     : 21/06/09
# Input     : Hash with question column values
# Returns   : 
#=============================================================================================

sub add_question_record {

    my $self = shift;
    my $input = { @_ };
    my $r;

    $self->{ Debug } ge "1" ? ( $self->update_log( "Invoked Method: ". (caller(0))[3] ) ) : () ;

    $self->clear_err_structure();

    # Set default values for new record
    # Key value QuestionID is defined as Autonumber and will be generated by the database
    
    $r->{ AuctionSite           }   = "TRADEME"         ;
    $r->{ AuctionRef            }   = "0"               ;
    $r->{ ProductCode           }   = ""                ;
    $r->{ Question_Reference    }   = "0"               ;
    $r->{ Question_Text         }   = ""                ;
    $r->{ Answer_Text           }   = ""                ;
    $r->{ Answered              }   = 0                 ;
    $r->{ Asked_By_Member       }   = ""                ;
    $r->{ Asked_By_Member_ID    }   = ""                ;

    # Read through the input values and alter the corresponding fields in the "Record" hash

    while ( ( my $key, my $value ) = each( %{ $input } ) ) {
            $r->{ $key } = $value;
    }

    # Create a fake key, save the old product code and set the product code to the generated key
 
    my $keygen  = "##-".rand;
    my $savprod = $r->{ ProductCode };
    $r->{ ProductCode }   = $keygen;

    # Prepare the SQL Insert Statement

    my $SQL = qq { 
        INSERT INTO Questions ( 
            AuctionSite         ,      
            AuctionRef          ,
            ProductCode         ,
            Question_Reference  ,
            Question_Text       ,
            Answer_Text         ,
            Answered            ,
            Asked_By_Member     ,
            Asked_By_Member_ID  )
        VALUES             ( ?, ?, ?, ?, ?, ?, ?, ?, ?  )     
    };

    $self->{ Debug } ge "1" ? ( $self->update_log( "SQL Statement:\n".$SQL ) ) : () ;

    my $sth = $dbh->prepare( $SQL );
    
    $sth->bind_param( 5, $sth, DBI::SQL_LONGVARCHAR );   
    $sth->bind_param( 6, $sth, DBI::SQL_LONGVARCHAR );   

    $sth->execute(
       "$r->{ AuctionSite         }"  ,
       "$r->{ AuctionRef          }"  ,
       "$r->{ ProductCode         }"  ,
       "$r->{ Question_Reference  }"  ,
       "$r->{ Question_Text       }"  ,
       "$r->{ Answer_Text         }"  ,
        $r->{ Answered            }   ,
       "$r->{ Asked_By_Member     }"  ,
       "$r->{ Asked_By_Member_ID  }"  ,
    )              
    || die "insert_question_record - Error executing statement: $DBI::errstr\n";

    # retrieve the key for the fake product code - should be key of record just added

    my $newq    = $self->get_questions_by_productcode( ProductCode => $keygen );

    if ( scalar( $newq ) gt 1 ) {    
        $self->update_log( scalar( @$newq )." Questions with Product Code found - first record updated" );
    }

    my $rcdkey  = $newq->[0]->{ QuestionID };

    # Update the record with the correct product code (the saved value)

    $self->update_question_record(
        QuestionID          =>  $rcdkey    ,
        ProductCode         =>  $savprod   ,
    );
    
    return $rcdkey;
}

#=============================================================================================
# Method    : update_question_record
# Added     : 30/03/05
# Input     : 
# Returns   : Hash Reference
#
# This method returns the details for a specific photo record in a referenced hash
#=============================================================================================

sub update_question_record {

    my $self = shift;
    my $p = {@_};

    $self->{ Debug } ge "1" ? ( $self->update_log( "Invoked Method: ". (caller(0))[3] ) ) : () ;

    # Retrieve the current record from the database and update "Record" data-Hash

    my $SQL = qq {
        SELECT *
        FROM   Questions
        WHERE  QuestionID  = ? 
    };

    $self->{ Debug } ge "1" ? ( $self->update_log( "SQL Statement:\n".$SQL ) ) : () ;

    my $sth = $dbh->prepare( $SQL ) || die "Error preparing statement: $DBI::errstr\n";

    $sth->execute( $p->{ QuestionID } );

    my $r = $sth->fetchrow_hashref;

    # Read through the input record and alter the corresponding field in the "Record" hash

    while ( ( my $key, my $value ) = each( %{ $p } ) ) {
        $r->{ $key } = $value;
    }

    # Update the database with the new updated "Record" hash

    $SQL = qq {
        UPDATE  Questions  
        SET     AuctionSite         = ?,      
                AuctionRef          = ?,
                ProductCode         = ?,
                Question_Reference  = ?,
                Question_Text       = ?,
                Answer_Text         = ?,
                Answered            = ?,
                Asked_By_Member     = ?,
                Asked_By_Member_ID  = ?
        WHERE   QuestionID          = ? 
    };

    $self->{ Debug } ge "1" ? ( $self->update_log( "SQL Statement:\n".$SQL ) ) : () ;

    $sth = $dbh->prepare( $SQL ) || die "Error preparing statement: $DBI::errstr\n";
    
    $sth->bind_param( 5, $sth, DBI::SQL_LONGVARCHAR );   
    $sth->bind_param( 6, $sth, DBI::SQL_LONGVARCHAR );   

    $sth->execute(
        "$r->{ AuctionSite         }"  ,
        "$r->{ AuctionRef          }"  ,
        "$r->{ ProductCode         }"  ,
        "$r->{ Question_Reference  }"  ,
        "$r->{ Question_Text       }"  ,
        "$r->{ Answer_Text         }"  ,
         $r->{ Answered            }   ,
        "$r->{ Asked_By_Member     }"  ,
        "$r->{ Asked_By_Member_ID  }"  ,
         $r->{ QuestionID          }   ,
    )     
    || die "update_question_record - Error executing statement: $DBI::errstr\n";
}

#=============================================================================================
# Method    : get_question_record    
# Added     : 7/04/05
# Input     :
# Returns   : Hash references
#
# This method returns a specific question record
#=============================================================================================

sub get_question_record {

    my $self    = shift;
    my $p       = { @_ };

    $self->{Debug} ge "1" ? ($self->update_log( (caller(0))[3] )) : () ;

    $self->clear_err_structure();

    my $SQL = qq {  
        SELECT      *
        FROM        Questions
        WHERE       QuestionID = ? 
    };

    $self->{ Debug } ge "1" ? ( $self->update_log( "SQL Statement:\n".$SQL ) ) : () ;

    my $sth = $dbh->prepare( $SQL );
    
    $sth->execute(
        $p->{ QuestionID } ,
    );

    my $question = $sth->fetchrow_hashref;

    # If the record was found return the details otherwise populate the error structure

    if ( defined( $question ) ) {    
        return $question;
    }
    else {
        $self->{ ErrorStatus    } = "1";
        $self->{ ErrorMessage   } = "No questions matching Question ID ".$p->{ QuestionID };
        $self->{ ErrorDetail    } = "";
        return undef;
    }
}

#=============================================================================================
# Method    : get_questions_by_product_code    
# Added     : 7/04/05
# Input     :
# Returns   : Array of hash references
#
# This method returns a list of questions related to a product code
#=============================================================================================

sub get_questions_by_productcode {

    my $self    = shift;
    my $p       = { @_ };

    $self->{Debug} ge "1" ? ($self->update_log( (caller(0))[3] )) : () ;

    $self->clear_err_structure();

    my $SQL = qq {  
        SELECT      *
        FROM        Questions
        WHERE       ProductCode = ? 
    };

    $self->{ Debug } ge "1" ? ( $self->update_log( "SQL Statement:\n".$SQL ) ) : () ;

    my $sth = $dbh->prepare( $SQL );
    
    $sth->execute(
        $p->{ ProductCode } ,
    );

    my $questions = $sth->fetchall_arrayref({});

    # If the record was found return the details otherwise populate the error structure

    if ( defined( $questions ) ) {    
        return $questions;
    }
    else {
        $self->{ ErrorStatus    } = "1";
        $self->{ ErrorMessage   } = "No questions matching product code ".$p->{ ProductCode };
        $self->{ ErrorDetail    } = "";
        return undef;
    }
}

#=============================================================================================
# Method    : put_auction_answer
# Added     : 02/06/08
# Input     : Hash - AuctionRef, QuestionID (Optional) and Comment
# Returns   : Integer
#
# This function returns 0 if successful other wise 1
#=============================================================================================

sub put_trademe_comment {

    my $self    = shift;
    my $p       = { @_ };

    # Set question ID to 0 if it has not been passed in to ensure comments work

    unless ( defined $p->{ QuestionID } ) {
        $p->{ QuestionID } = '0';
    }

    $self->{Debug} ge "1" ? ( $self->update_log( "Invoked Method: ". (caller(0))[3] )) : () ;
    
    $url = "http://www.trademe.co.nz/Browse/AddComment.aspx";
    $req = POST $url,
        [ "submitted"       =>  "1"                     ,
          "id"              =>  $p->{ AuctionRef    }   ,
          "listingtype"     =>  'A'                     ,
          "qid"             =>  $p->{ QuestionID    }   ,
          "comment"         =>  $p->{ Comment       }   ,
          "pageMcatField"   =>  ""                      ,
        ];

    # post the comment

    $content = $ua->request( $req )->as_string;

    $self->{ Debug } ge "2" ? ( $self->update_log( "Auction Detail input:" ) ) : ();
    $self->{ Debug } ge "2" ? ( $self->update_log( "Post $url" ) ) : ();
    $self->{ Debug } ge "2" ? ( $self->update_log( "$content" ) ) : ();

    unless ( $content =~ m/Comment submitted/s ) {
        $self->{ ErrorStatus    }   = 1;
        $self->{ ErrorMessage   }   = "Unspecified error occurred answering a question on auction ".$p->{ AuctionRef }.".";
        $self->{ ErrorMessage   }   = $self->{ ErrorMessage }." Check that question has been answered as expected";
        return undef;
    }
    return 1;
}

#=============================================================================================
# Method    : get_monitor_type
# Added     : 30/03/05
# Input     : Auction reference
# Returns   : String
#=============================================================================================

sub get_monitor_type {

    my $self  = shift;
    my $auctionref = shift;
    my $monitor;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    $url="http://www.trademe.co.nz/structure/auction_detail.asp?id=".$auctionref;

    $req = HTTP::Request->new(GET => $url);
    $response = $ua->request($req);

    if ($response->is_error()) {
        $self->{ErrorStatus}    = "1";
        $self->{ErrorMessage}   = "Auction ".$auctionref." was not found";
        $self->{ErrorDetail}    = "";
        return undef;

    }
    else {
        $content = $response->content();
    }

    if ($content =~ m/(Monitor:<\/font><\/td>)(.+?)(<\/td><td>)(.+?)(<\/td>)/gs)  {

        $monitor = $4;
    }
    else {
        $monitor = "NONE"
    }

    return $monitor;
}

#=============================================================================================
# Method    : get_picture_link
# Added     : 23/09/06
# Input     : Auction reference 
# Returns   : string
#=============================================================================================

sub get_picture_link {

    my $self  = shift;
    my $auctionref = shift;
    my $picurl;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    $url="http://www.trademe.co.nz/Browse/Listing.aspx?id=".$auctionref;

    $req = HTTP::Request->new(GET => $url);
    $response = $ua->request($req);

    if ($response->is_error()) {
        $self->{ErrorStatus}    = "1";
        $self->{ErrorMessage}   = "Auction ".$auctionref." was not found";
        $self->{ErrorDetail}    = "";
        return undef;
    }
    else {
        $content = $response->content();
    }

    # Picture URL extraction pattern 26/2/09
    #  <img src="http://images.trademe.co.nz/photoserver/tq/42/83787342.jpg" id="mainImage" class="t_83787342" />

    # Extract Picture URL

    if ($content =~ m/(src=")(http:\/\/images\.trademe\.co\.nz\/photoserver.+?jpg)(" id="mainImage")/gs)  {            
        $picurl = $2;
    }
    else {
        $picurl = "NOPIC";
    }

    return $picurl;
}

#=============================================================================================
# Method    : import_picture
# Added     : 23/09/06
# Input     : Picture file URL, Output file name
# Returns   : 
#=============================================================================================

sub import_picture {

    my $self  = shift;
    my $p     = {@_};

    $response = $ua->get( $p->{ URL }, ":content_file"  => $p->{ FileName } );
    my $msg = "Method: import_picture; HTTP Response code for Image GET request: ".$response->status_line;
    $self->update_log( $msg, DEBUG );
}

#=============================================================================================
# Method    : import_auction_details
# Added     : 18/09/06
# Input     : Auction reference; Auction Status (CURRENT, SOLD, UNSOLD);
# Returns   : Hash Reference
#
# This method returns the details for a specific auction in a referenced hash
# It uses the "Sell_similar_item" function to obtain all the extra details need to import
# the auction into the database. The sell Similar Item function invokes an auction edit page
# which contains all the auction details for editing. These details can be easily extracted
# using the various form <input> tags to isolate the individual auction fields
#
#=============================================================================================

sub import_auction_details {

    my $self  = shift;
    my $auctionref      = shift;
    my $auctionstatus   = shift;
    my %imp;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    $self->clear_err_structure();

    $imp{AuctionRef} = $auctionref; 

    # Invoke the Sell a Similar item input form

    $url="http://www.trademe.co.nz/MyTradeMe/AuctionDetailCommand.aspx";        # 21/05.2006

    $req = POST $url, [
        "id"                             =>   $auctionref,
        ($auctionstatus eq "CURRENT"  )   ?   ("cmdSellSimilarItem"      => 'Sell similar item')    : () ,
        ($auctionstatus eq "SOLD"     )   ?   ("cmdSellSimilarItemSold"  => 'Sell similar item')    : () ,
        ($auctionstatus eq "UNSOLD"   )   ?   ("cmdSellSimilarItemSold"  => 'Sell similar item')    : () ,
    ];

    # Submit the auction details to TradeMe (HTTP POST operation) 
    
    $content = $ua->request($req)->as_string;
    $debug ? (print "$content\n"):();

    ($auctionstatus eq "CURRENT"    ) ? ( $imp{ AuctionStatus } = "CURRENT"  ) : (                          ) ;
    ($auctionstatus eq "SOLD"       ) ? ( $imp{ AuctionStatus } = "SOLD"     ) : (                          ) ;
    ($auctionstatus eq "SOLD"       ) ? ( $imp{ AuctionSold   } = 1          ) : ( $imp{ AuctionSold } = 0  ) ;
    ($auctionstatus eq "UNSOLD"     ) ? ( $imp{ AuctionStatus } = "UNSOLD"   ) : (                          ) ;

    if ($response->is_error()) {
    
        $self->{ErrorStatus}    = "1";
        $self->{ErrorMessage}   = "Auction ".$auctionref." was not found";
        $self->{ErrorDetail}    = "";
        return undef;
            
    } 
    else {
        $debug ? (print "Auction Ref: $auctionref\n"):();
        $debug ? (print "Status     : $auctionstatus\n\n"):();
        $debug ? (print "$content\n"):();
    }

    #-----------------------------------------------------------------
    # Extract individual auction values using the input form fields
    #-----------------------------------------------------------------

    # parse the data using the toke parser module

    my $select_group;

    my $stream = new HTML::TokeParser(\$content);

    while ( my $token = $stream->get_token() ) {

        if ( $token->[0] eq 'S' and $token->[1] eq 'input' ) {

            #Category ID

            if ( uc( $token->[2]{ 'name' } ) eq 'CATEGORYID' ) {

                $imp{ Category } = $token->[2]{ 'value' };
            }

            # Auction Title

            if ( uc( $token->[2]{ 'name' } ) eq 'TITLE' ) {

                $imp{ Title } = $token->[2]{ 'value' };
            }

            # Auction subtitle

            if ( uc( $token->[2]{ 'name' } ) eq 'SUBTITLE' ) {

                $imp{ Subtitle } = $token->[2]{ 'value' };
            }

            # "Is New" Flag

            if ( uc( $token->[2]{ 'name' } ) eq 'IS_NEW' ) {

                print "\n\n\n*** TOKEN IS_NEW FOUND - checked value is:".uc($token->[2]{ 'checked' })."\n\n\n";

                if ( uc($token->[2]{ 'checked' } ) eq 'CHECKED' ) {

                    $imp{ IsNew } = 1;
                }
                else {
                    $imp{ IsNew } = 0;
                }
             }

            # Start Price

            if ( uc( $token->[2]{ 'name' } ) eq 'STARTPRICE' ) {

                $imp{ StartPrice } = $token->[2]{ 'value' };
            }

            # Reserve Price

            if ( uc( $token->[2]{ 'name' } ) eq 'RESERVEPRICE' ) {

                $imp{ ReservePrice } = $token->[2]{ 'value' };
            }


            # Start eq Reserve Radio button

            if ( uc( $token->[2]{ 'name' } ) eq 'START_EQ_RESERVE' ) {

                if ( $token->[2]{ 'value' } == 1 and uc( $token->[2]{ 'checked' } ) eq 'CHECKED' ) {

                    $imp{ StartEqReserve } =$token->[2]{ 'value' };
                }
            }

            # BuyNow Price

            if ( uc( $token->[2]{ 'name' } ) eq 'BUYNOWPRICE' ) {

                $imp{ BuyNowPrice   } = $token->[2]{ 'value' };

                unless ( $imp{ BuyNowPrice } =~ m/^[0123456789\.]+$/ ) {

                    $imp{ BuyNowPrice } = 0;
                }

            }

            # Auction Duration type 

            if ( uc( $token->[2]{ 'name' } ) eq 'DURATION_TYPE' ) {

                if ( uc($token->[2]{ 'value' } ) eq 'EASY' and uc($token->[2]{ 'checked' } ) eq 'CHECKED' ) {

                    $imp{ EndType } = "DURATION";
                }

                if ( uc($token->[2]{ 'value' } ) eq 'ADVANCED' and uc($token->[2]{ 'checked' } ) eq 'CHECKED' ) {

                    $imp{ EndType } = "FIXEDEND";
                }
            }

            # Closed Auction (authorised members only)  *** CHECK this carefully !!!

            if ( uc( $token->[2]{ 'name' } ) eq 'CLOSED' ) {

                if ( uc($token->[2]{ 'checked' } ) eq 'CHECKED' ) {

                    $imp{ ClosedAuction } = 1;
                }
                else {
                    $imp{ ClosedAuction } = 0;
                }
             }

            # Delivery options 

            if ( uc( $token->[2]{ 'name' } ) eq 'DELIVERY' ) {

                if ( uc($token->[2]{ 'checked' } ) eq 'CHECKED' ) {

                    if ( uc($token->[2]{ 'value' } ) eq 'UNDECIDEDED' ) {

                        $imp{ ShippingOption } = 1;
                    }
                    elsif ( uc($token->[2]{ 'value' } ) eq 'FREE' ) {

                        $imp{ ShippingOption } = 2;
                    }
                    elsif ( uc($token->[2]{ 'value' } ) eq 'CUSTOM' ) {

                        $imp{ ShippingOption } = 3;
                    }
                }
            }

            # Delivery Cost 01

            if ( uc( $token->[2]{ 'name' } ) eq 'DELIVERY_COST_1' ) {

                $imp{ DCost1 } = $token->[2]{ 'value' };
            }

            # Delivery Text 01

            if ( uc( $token->[2]{ 'name' } ) eq 'DELIVERY_METHOD_1' ) {

                $imp{ DText1 } = $token->[2]{ 'value' };

            }

            # Delivery Cost 02

            if ( uc( $token->[2]{ 'name' } ) eq 'DELIVERY_COST_2' ) {

                $imp{ DCost2 } = $token->[2]{ 'value' };
            }

            # Delivery Text 02

            if ( uc( $token->[2]{ 'name' } ) eq 'DELIVERY_METHOD_2' ) {

                $imp{ DText2 } = $token->[2]{ 'value' };

            }
            # Delivery Cost 03

            if ( uc( $token->[2]{ 'name' } ) eq 'DELIVERY_COST_3' ) {

                $imp{ DCost3 } = $token->[2]{ 'value' };
            }

            # Delivery Text 03

            if ( uc( $token->[2]{ 'name' } ) eq 'DELIVERY_METHOD_3' ) {

                $imp{ DText3 } = $token->[2]{ 'value' };

            }

            # Delivery Cost 04

            if ( uc( $token->[2]{ 'name' } ) eq 'DELIVERY_COST_4' ) {

                $imp{ DCost4 } = $token->[2]{ 'value' };
            }

            # Delivery Text 04

            if ( uc( $token->[2]{ 'name' } ) eq 'DELIVERY_METHOD_4' ) {

                $imp{ DText4 } = $token->[2]{ 'value' };

            }
            # Delivery Cost 05

            if ( uc( $token->[2]{ 'name' } ) eq 'DELIVERY_COST_5' ) {

                $imp{ DCost5 } = $token->[2]{ 'value' };
            }

            # Delivery Text 05

            if ( uc( $token->[2]{ 'name' } ) eq 'DELIVERY_METHOD_5' ) {

                $imp{ DText5 } = $token->[2]{ 'value' };

            }
            # Delivery Cost 06

            if ( uc( $token->[2]{ 'name' } ) eq 'DELIVERY_COST_6' ) {

                $imp{ DCost6 } = $token->[2]{ 'value' };
            }

            # Delivery Text 06

            if ( uc( $token->[2]{ 'name' } ) eq 'DELIVERY_METHOD_6' ) {

                $imp{ DText6 } = $token->[2]{ 'value' };

            }
            # Delivery Cost 07

            if ( uc( $token->[2]{ 'name' } ) eq 'DELIVERY_COST_7' ) {

                $imp{ DCost7 } = $token->[2]{ 'value' };
            }

            # Delivery Text 07

            if ( uc( $token->[2]{ 'name' } ) eq 'DELIVERY_METHOD_7' ) {

                $imp{ DText7 } = $token->[2]{ 'value' };

            }

            # Delivery Cost 08

            if ( uc( $token->[2]{ 'name' } ) eq 'DELIVERY_COST_8' ) {

                $imp{ DCost8 } = $token->[2]{ 'value' };
            }

            # Delivery Text 08

            if ( uc( $token->[2]{ 'name' } ) eq 'DELIVERY_METHOD_8' ) {

                $imp{ DText8 } = $token->[2]{ 'value' };

            }

            # Delivery Cost 09

            if ( uc( $token->[2]{ 'name' } ) eq 'DELIVERY_COST_9' ) {

                $imp{ DCost9 } = $token->[2]{ 'value' };
            }

            # Delivery Text 09

            if ( uc( $token->[2]{ 'name' } ) eq 'DELIVERY_METHOD_9' ) {

                $imp{ DText9 } = $token->[2]{ 'value' };

            }
            # Delivery Cost 10

            if ( uc( $token->[2]{ 'name' } ) eq 'DELIVERY_COST_10' ) {

                $imp{ DCost10 } = $token->[2]{ 'value' };
            }

            # Delivery Text 10

            if ( uc( $token->[2]{ 'name' } ) eq 'DELIVERY_METHOD_10' ) {

                $imp{ DText10 } = $token->[2]{ 'value' };

            }

            # Payment Info options

            if ( uc( $token->[2]{ 'name' } ) eq 'PAYMENT_INFO' ) {

                # Bank Deposit

                if (  uc($token->[2]{ 'value' } ) eq 'BANK_DEPOSIT' ) {

                    if ( uc($token->[2]{ 'checked' } ) eq 'CHECKED' ) {

                        $imp{ BankDeposit } = 1;
                    }
                    else {
                        $imp{ BankDeposit } = 0;
                    }
                }

                # Credit Card

                if (  uc($token->[2]{ 'value' } ) eq 'CREDIT_CARD' ) {

                    if ( uc($token->[2]{ 'checked' } ) eq 'CHECKED' ) {

                        $imp{ CreditCard } = 1;
                    }
                    else {
                        $imp{ CreditCard } = 0;
                    }
                }

                # Cash on Pickup

                if (  uc($token->[2]{ 'value' } ) eq 'CASH_ON_PICKUP' ) {

                    if ( uc($token->[2]{ 'checked' } ) eq 'CHECKED' ) {

                        $imp{ CashOnPickup } = 1;
                    }
                    else {
                        $imp{ CashOnPickup } = 0;
                    }
                }

                # Paymate

                if (  uc($token->[2]{ 'value' } ) eq 'PAYMATE' ) {

                    if ( uc($token->[2]{ 'checked' } ) eq 'CHECKED' ) {

                        $imp{ Paymate } = 1;
                    }
                    else {
                        $imp{ Paymate } = 0;
                    }
                }

                # Safe Trader

                if (  uc($token->[2]{ 'value' } ) eq 'SAFE_TRADER' ) {

                    if ( uc($token->[2]{ 'checked' } ) eq 'CHECKED' ) {

                        $imp{ SafeTrader } = 1;
                    }
                    else {
                        $imp{ SafeTrader } = 0;
                    }
                }

                # Payment information "Other"

                if (  uc($token->[2]{ 'id' } ) eq 'PAYMENT_INFO_OTHER_TEXT' ) {

                    $imp{ PaymentInfo } = $token->[2]{ 'value' };
                }
            }

            # Buyer Email

            if ( uc( $token->[2]{ 'name' } ) eq 'SEND_BUYER_EMAIL' ) {

                if ( uc($token->[2]{ 'value' } ) eq 'Y' )  {

                    $imp{ TMBuyerEmail } = 1;
                }
                else {

                    $imp{ TMBuyerEmail } = 0;
                }
            }

            # Cot Safety Confirmation

            if ( uc( $token->[2]{ 'name' } ) eq '57' )  {

                $imp{ AttributeName     } = $token->[2]{ 'name'  };
                $imp{ AttributeValue    } = $token->[2]{ 'value' };
            }

            # Game rating Confirmation

            if ( uc( $token->[2]{ 'name' } ) eq '137' )  {

                $imp{ AttributeName     } = $token->[2]{ 'name'  };
                $imp{ AttributeValue    } = $token->[2]{ 'value' };
            }

            # Digital camera attributes - Megapixels

            if ( uc( $token->[2]{ 'name' } ) eq '117' )  {              

                $imp{ TMATT117          } = $token->[2]{ 'value' };
            }

            # Digital camera attributes - Optical Zoom

            if ( uc( $token->[2]{ 'name' } ) eq '118' )  {              

                $imp{ TMATT118          } = $token->[2]{ 'value' };
            }

            # Monitor Attribute - Size

            if ( uc( $token->[2]{ 'name' } ) eq '115' )  {

                $imp{ TMATT115          } = $token->[2]{ 'value' };
            }

            # Desktop Attribute - Speed MHz/Ghz

            if ( uc( $token->[2]{ 'name' } ) eq '104' )  {

                $imp{ TMATT104          } = $token->[2]{ 'value' };
            }

            # Desktop Attribute - RAM

            if ( uc( $token->[2]{ 'name' } ) eq '106' )  {

                $imp{ TMATT106          } = $token->[2]{ 'value' };
            }

            # Desktop Attribute - HDD SIze

            if ( uc( $token->[2]{ 'name' } ) eq '108' )  {

                $imp{ TMATT108          } = $token->[2]{ 'value' };
            }
        }

        if ( $token->[0] eq 'S' and $token->[1] eq 'select' ) {

            $select_group = $token->[2]{ 'name' };
        }

        if ( $token->[0] eq 'E' and $token->[1] eq 'select' ) {

            $select_group = "";
        }

        # Check the individual options in the select groups for what was selected

        if ( $token->[0] eq 'S' and $token->[1] eq 'option' ) {

            # Auction Duration values

            if ( uc( $select_group ) eq 'AUCTION_LENGTH' ) {

                if ( uc( $token->[2]{ 'selected' } ) eq 'SELECTED' ) {

                    $imp{ DurationHours } = $token->[2]{ 'value' };
                }
            }

            # Auction Duration values - Fixed end

            if ( uc( $select_group ) eq 'SET_END_DAYS' ) {

                if ( uc( $token->[2]{ 'selected' } ) eq 'SELECTED' ) {

                    $imp{ EndDays } = $token->[2]{ 'value' };
                }
            }

            if ( uc( $select_group ) eq 'SET_END_HOUR' ) {

                if ( uc( $token->[2]{ 'selected' } ) eq 'SELECTED' ) {

                    $imp{ EndTime } = $token->[2]{ 'value' };
                }
            }

            # Pickup Options

            if ( uc( $select_group ) eq 'PICKUP' ) {

                if ( uc ($token->[2]{ 'selected' } ) eq 'SELECTED' ) {

                    if ( uc ($token->[2]{ 'value' } ) eq 'ALLOW' ) {

                        $imp{ PickupOption       } = 1;
                    }
                    elsif ( uc ($token->[2]{ 'value' } ) eq 'DEMAND' ) {

                        $imp{ PickupOption       } = 2;
                    }
                    elsif ( uc ($token->[2]{ 'value' } ) eq 'FORBID' ) {

                        $imp{ PickupOption       } = 3;
                    }
                }
            }

            # Clothing Attributes

            if ( ( uc( $select_group ) eq  '86' ) or
                 ( uc( $select_group ) eq  '87' ) or
                 ( uc( $select_group ) eq  '88' ) or
                 ( uc( $select_group ) eq  '89' ) or
                 ( uc( $select_group ) eq  '91' ) or
                 ( uc( $select_group ) eq  '92' ) or
                 ( uc( $select_group ) eq  '93' ) or
                 ( uc( $select_group ) eq '130' ) ) {

                if ( uc ($token->[2]{ 'selected' } ) eq 'SELECTED' ) {

                    $imp{ AttributeName     } = $select_group;
                    $imp{ AttributeValue    } = $token->[2]{ 'value' };
                }
            }

            # Mobile Phone Accessories Attributes

            if ( uc( $select_group ) eq '120' ) {

                if ( uc ($token->[2]{ 'selected' } ) eq 'SELECTED' ) {

                    $imp{ AttributeName     }   = $select_group;
                    $imp{ AttributeValue    }   = $token->[2]{ 'value' };
                }
            }

            # Mobile Phone Accessories Attributes

            if ( uc( $select_group ) eq '116' ) {

                if ( uc ($token->[2]{ 'selected' } ) eq 'SELECTED' ) {

                    $imp{ AttributeName     }   = $select_group;
                    $imp{ AttributeValue    }   = $token->[2]{ 'value' };
                }
            }


            # Movie Rating Accessories Attributes

            if ( uc( $select_group ) eq '55' ) {

                if ( uc ($token->[2]{ 'selected' } ) eq 'SELECTED' ) {

                    $imp{ MovieRating       }   = $token->[2]{ 'value' };
                    $imp{ MovieConfirm      }   = 1;
                }
            }

            # Desktop Attribute - Speed MHz/Ghz

            if ( uc( $select_group ) eq '104' ) {

                if ( uc ($token->[2]{ 'selected' } ) eq 'SELECTED' ) {

                    $imp{ TMATT104_2        } = $token->[2]{ 'value' }
                }
            }

            # Desktop Attribute - RAM

            if ( uc( $select_group ) eq '106' ) {

                if ( uc ($token->[2]{ 'selected' } ) eq 'SELECTED' ) {

                    $imp{ TMATT106_2        } = $token->[2]{ 'value' }
                }
            }
             # Desktop Attribute - HDD

            if ( uc( $select_group ) eq '108' ) {

                if ( uc ($token->[2]{ 'selected' } ) eq 'SELECTED' ) {

                    $imp{ TMATT108_2        } = $token->[2]{ 'value' }
                }
            }
            # Desktop Attribute - CD Drive

            if ( uc( $select_group ) eq '111' ) {

                if ( uc ($token->[2]{ 'selected' } ) eq 'SELECTED' ) {

                    $imp{ TMATT111          } = $token->[2]{ 'value' }
                }
            }
             # Desktop Attribute - Monitor Type

            if ( uc( $select_group ) eq '112' ) {

                    $imp{ TMATT112          } = "";

                if ( uc ($token->[2]{ 'selected' } ) eq 'SELECTED' ) {

                    $imp{ TMATT112          } = $token->[2]{ 'value' }
                }
            }
       }

        # Auction Description

        if ( $token->[0] eq 'S' and $token->[1] eq 'textarea' and uc( $token->[2]{ 'name' } ) eq 'BODY' ) {

            $imp{ Description } = $stream->get_text();
            $imp{Description} =~ s/\[ Loaded by Auctionitis \]//g;      # remove Auctionitis Tag
        }
    }

    # Finished processing the token stream now other logical stuff can be done

    # If start equals reserve flag is set set the reserve price the start price

    if ( $imp{ StartEqReserve } ) {
        $imp{ ReservePrice } = $imp{ StartPrice };
    }

    # Set the category attribute value using the auction category

    my $catval = $imp{ Category };

    if ( $self->has_attributes($catval) ) {

        $imp{ AttributeCategory } = $catval;
    }
    else {

        $catval = $self->get_parent($catval);
    }

    if ( $catval ne 0 ) {

        if ( $self->has_attributes($catval) ) {

            $imp{ AttributeCategory } = $catval;
        }
        else {

            $catval = $self->get_parent($catval);
        }
    }

    if ( $catval ne 0 ) {

        if ( $self->has_attributes($catval) ) {

            $imp{ AttributeCategory } = $catval;
        }
        else {

            $catval = $self->get_parent($catval);
        }
    }

    if ( $catval ne 0 ) {

        if ( $self->has_attributes($catval) ) {

            $imp{ AttributeCategory } = $catval;
        }
    }

    if ( exists $imp{ TMATT112 }  ) {
        my $monitor = $self->get_monitor_type( $auctionref );
        $imp{ TMATT112 } = $monitor ;
    }

    if ( exists $imp{ MovieRating }  ) {
        delete $imp{ AttributeName      };
        delete $imp{ AttributeValue     };
        delete $imp{ Attributecategory  };
    }

    return %imp;
    
}

#=============================================================================================
# Method    : get_movie_search_list
# Added     : 25/04/2007
# Input     : Search string
# Returns   : HTML page (as string)
#
#=============================================================================================

sub get_movie_search_list {

    my $self        = shift;
    my $searchval   = "";
    my $HTMLPage    = "";

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    $self->clear_err_structure();

    # parese the command line to get all search arguments

    foreach my $i (@_) {

        if ( $searchval eq "") {

            $searchval = $i;
        }
        else {

            $searchval = $searchval." ".$i;
        }
    }

    # Start a new DVD auction
    
    # Send the search string

    $url="http://www.trademe.co.nz/Sell/SearchCatalogue.aspx";        

    $req = POST $url, [
        "submitted"         =>   "1"            ,
        "resultSelected"    =>   "0"            ,
        "mcat"              =>   "0003-0365-"   ,
        "searchtitle"       =>   $searchval     ,
    ];

    $content = $ua->request($req)->as_string;

    # print $content."\n\n";

    # Add test and page for no items returned
    
    # Add test and page for only 1 item

    # parse the data using the toke parser module

    my $data    = "0";
    my $record  = "0";
    my $title   = "" ;
    my $image   = "" ;
    my $data1   = "" ;
    my $data2   = "" ;
    my $catID   = "" ;
    my $backfill= "0";

    my $stream = new HTML::TokeParser(\$content);

    while ( my $token = $stream->get_token() ) {

        # Check whether we have the "Listings" table
        # If we see a table tag in the Listings table it is a movie "record" returned from the search
        # If we see an end table tag and the record flag is on it marks the end of the record
        # If we see an end table tag and the record flag is already off it marks the end of the data
        
        if ( $token->[0] eq 'S' and  $token->[1] eq 'table' and uc( $token->[2]{ 'class' } ) eq 'LISTINGS' ) {

            $data = "1";
            
            # print "*** Start of Listings table\n"    

            $HTMLPage   =           "<HTML>\n";
            $HTMLPage   = $HTMLPage."<HEAD><TITLE>Movie Selections for search value: $searchval<\/TITLE>\n";
            $HTMLPage   = $HTMLPage."<BODY>\n";
            $HTMLPage   = $HTMLPage."<HEAD><H2>Movie Selections for search value: $searchval<\/H2>\n";
            $HTMLPage   = $HTMLPage."<FORM name=\"DVDSearch\"\>\n";
            $HTMLPage   = $HTMLPage. qq { <TABLE  WIDTH="100%" BORDER="1" BORDERCOLOR="black" CELLPADDING="0" CELLSPACING="0">\n };
        }
        elsif ( $data eq "1" and $token->[0] eq 'S' and  $token->[1] eq 'table' ) {

            $record = "1";

            $HTMLPage   = $HTMLPage."<TR>\n";
            $HTMLPage   = $HTMLPage."<TD>\n";
            
            if ( $backfill eq "1" ) {

                $HTMLPage   = $HTMLPage."<TABLE WIDTH=\"100%\" BGCOLOR=\"lightgrey\">\n";
                $backfill = "0";
            }               
            else {
                $HTMLPage   = $HTMLPage."<TABLE WIDTH=\"100%\">\n";
                $backfill = "1";
            }
            

            # print "*** Start of Movie Record\n"    

        }
        elsif ( $data eq "1" and $record eq "1" and $token->[0] eq 'E' and  $token->[1] eq 'table' ) {

            $record = "0";

            # print "*** End of Movie record\n"    

            $HTMLPage   = $HTMLPage."<TR>\n";    
            $HTMLPage   = $HTMLPage."  <TD width=\"12%\" align=\"centre\" rowspan = 4>".$image."<\/TD>\n";    
            $HTMLPage   = $HTMLPage."  <TD>".$title."<\/TD>\n";    
            $HTMLPage   = $HTMLPage."<\/TR>\n";    

            $HTMLPage   = $HTMLPage."<TR><TD>".$data1."<\/TD><\/TR>\n";    
            $HTMLPage   = $HTMLPage."<TR><TD>".$data2."<\/TD><\/TR>\n";    
            $HTMLPage   = $HTMLPage."<TR><TD><input type=\"submit\" value=\"Select\" id=\"$catID\" name=\"DVDSelection\"><\/TD><\/TR>\n";

            $HTMLPage   = $HTMLPage."<\/TABLE>\n";    
            $HTMLPage   = $HTMLPage."<\/TD>\n";
            $HTMLPage   = $HTMLPage."<\/TR>\n";

            $title   = "" ;
            $image   = "" ;
            $data1   = "" ;
            $data2   = "" ;
            $catID   = "" ;

        }
        elsif ( $data eq "1" and  $record eq "0" and $token->[0] eq 'E' and  $token->[1] eq 'table' ) {

            $data = "0";

            # print "*** End of Listings table\n"    

            $HTMLPage   = $HTMLPage."<\/TABLE>\n";    
            $HTMLPage   = $HTMLPage."<\/FORM>\n";    
            $HTMLPage   = $HTMLPage."<\/BODY>\n";    
            $HTMLPage   = $HTMLPage."<\/HTML>\n";    
        }

        # If record flag is on and we see an image token we want the data

        if ( $record eq "1" ) {

            if ( $token->[0] eq 'S' and  $token->[1] eq 'img' ) {

                if  ( $token->[2]{'src'} =~ m/(photoserver)/ ) {
                                $image = "<IMG WIDTH=\"80\" SRC=\"".$token->[2]{'src'}."\">";
                }
            }

            if ( $token->[0] eq 'S' and  $token->[1] eq 'a' ) {
                
                if  ( $token->[2]{'href'} =~ m/(\/Sell\/Details\.aspx\?catalogueId=)(\d+)/ ) {
                    $catID=$2;
                }
                else {
                    $catID="Not matched";
                }
                
            }

            if ( $token->[0] eq 'S' and  $token->[1] eq 'b' ) {
                my ( $text) = ($stream->get_token );
                if ( $text->[0] eq 'T' ) {
                    
                    $stream->unget_token( $text );
                    $title = $stream->get_text();
                }
                else {
                    $stream->unget_token( $text );
                }
            }

            if ( $token->[0] eq 'S' and  $token->[1] eq 'div' ) {
                my ( $text) = ($stream->get_token) ;
                if ( $text->[0] eq 'T' ) {

                    $stream->unget_token( $text );
                    
                    if ( $data1 eq "" ) {
                        $data1 = $stream->get_text();
                    }
                    else {
                        $data2 = $stream->get_text();
                    }

                }
                else {
                    $stream->unget_token( $text );
                }
            }
        }
    }    

    return $HTMLPage;
    
}


#=============================================================================================
# Get permanent TM Listing data (retrieve individual permanent auction details)
#=============================================================================================
#
# All Current auction pages are looped through looking for permanent auction details
#
# Permanent Auction details are retrieved by a regular expression; a sample of the the auction
# data used to contruct the auction detail can be found in /Trademe/documents
#
# The permanent auction details from the page are put in array @rowdata in format:
# Auction reference, auction description, no. of items, times viewed, listed date, listed year,
# price.
#
# The rowdata array is then pushed into the auction data array as an anonymous array;
# items in the data array can then be accessed by reference in the returned auction data array.
#
# Example (including how to get at the data):
#   my @auctions = $tm->get_perm_listings();
#   foreach my $item (@auctions) {
#           print "$item->[0]\t $item->[1]\n";
#   }
#
# prints the auction reference and description of all permanent auctions
#
# script tmsimple.pl has examples of all functions provided by the package.
#
# After all pages have been processed the auction data array is returned

sub get_perm_listings {

    my $self= shift;
    my $listpage = 1;
    my @auctions;
    my @rowdata;
    my $counter = 1;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    while ($listpage <= $self->curr_pages) {

           $url="http://www.trademe.co.nz/structure/my_listings_current.asp?sort=&page=".$listpage."&sort_order=";
           # print "derived URL $url for page: $listpage\n";     #DEBUG INFO

           $req = HTTP::Request->new(GET => $url);
           my $response = $ua->request($req);

           if     ($response->is_error()) {
                   printf " %s\n", $response->status_line;
                   die "Cannot connect or unable retrieve data";
           } else {
                    # print "Logged in; extracting permanent auction details for page ".$listpage." of " .$self->curr_pages."\n"; #DEBUG INFO
                    $content = $response->content();

                    my $pattern = "permanent=1\"><b>";
                    while ($content =~ m/($pattern)(.+?)(<\/b>.+?Permanent listing: )([0-9]+)(.+?<b>)([0-9]+)(<\/b>.+?<small> )(.+?)(<br>)(.+?)(<\/small>.+?center>)(.+?)(&nbsp)(.+?)(<\/TD>)/g) {

                           $rowdata[0]  = $4;           # Auction ref
                           $rowdata[1]  = $2;           # Auction Desc
                           $rowdata[2]  = 1;            # No. of items
                           $rowdata[3]  = $6;           # Viewed
                           $rowdata[4]  = $8." ".$10;   # Close Date
                           $rowdata[4]  =~ tr/ /-/;     # chg spaces to dashes
                           $rowdata[5]  = $12;          # Price

                           if  ($3 =~ m/(\()([0-9]+)( items\))/) {$rowdata[2] = $2;}

                           $rowdata[1]  =~ s/(.+?)(&amp;)(.+?)/$1&$3/; #remove ampersand thing

                           push (@auctions, [@rowdata]);
                           # print "$counter\t $rowdata[0]\t $rowdata[1]\n"; #DEBUG INFO
                           $counter++;
                    }
           }
           $listpage ++
    }
    return @auctions;
}

#=============================================================================================
# Get Bidder ID from completed auction
# This functions need 2 parameters: auction ref and buyer id (thats the text handle of the
# buyer) and will return the buyers trademe id - the numeric one (variable $buyerref)
# This function uses the fact that feedback is required to locate the data on the page
# format for this as at 19/10/2003 was:
# After the transaction, <a href="/structure/trader_feedback_
# submit.asp?id=6360431&bidderid=320212">Submit feedback</a> about name</td
#=============================================================================================

sub get_bidder_id {

    my $self  = shift;
    my $parms = {@_};
    my @buyerref;
    my $pattern;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    # Clear error indicator and error message properties

    $self->clear_err_structure();
    
    # 22/01/06      http://www.trademe.co.nz/Browse/Listing.aspx?id=45317821    

    my $baseurl= "http://www.trademe.co.nz";
    $url=$baseurl."/Browse/Listing.aspx?id=".$parms->{auctionref};

    # Retrieve the requested auction page and if not found return with error message

    $req = HTTP::Request->new(GET => $url);
    $response = $ua->request($req);
    if     ($response->is_error()) {
            $self->{ErrorStatus}    = "1";
            $self->{ErrorMessage}   = "Page for Auction number ".$parms->{auctionref}." not found or connection is not available";
            $self->{ErrorDetail}    = $response->status_line;
            return;
    }

    $content = $response->content();

    # String to verify auction number has been found
    # <input type="hidden" name="id" value="20539411"
    # <small>Auction Number: 47316142</small>

    # $pattern = "<input type=\"hidden\" name=\"id\" value=\""; as at 20/2/2006
    
    $pattern = "<small>Auction Number: $parms->{auctionref}</small>";
    
    unless ($content =~ m/$pattern/gs) {
            $self->{ErrorStatus}    = "1";
            $self->{ErrorMessage}   = "Auction ".$parms->{auctionref}. " does not appear to be a valid auction number";
            $self->{ErrorDetail}    = "";
            return;
    }    

    # String to extract member ID from using the name and the "Buyer:" string and URL as the end anchor points
    # Buyer:</td><td><a href="/structure/show_member_listings.asp?member=41207"><font color=#0033cc><b>nelsonchic</b>    
    # Extract the URL with the buyer name first then verify that the buyer name matches the submitted name
    # 21/01/06 Buyer:</td><td><a href="/structure/show_member_listings.asp?member=1418875" style="color: #03c; font-weight: 700;">chatelet</a>
    # 22/02/06 Buyer:</td><td><a href="/Members/Listings.aspx?member=787595" style="color: #03c; font-weight: 700;">snatchy1</a>
    # 14/05/06 Buyer:</td><td><a href="/Members/Listings.aspx?member=1323011"><b>southernhome</b>
    # $pattern = "\/structure\/show_member_listings\.asp\\?member="; 22/2/06
    
    my $data    = $content;    

    # my $p0      = "Buyer:<\/td><td><a href=\"\/Members\/Listings\.aspx";                  # Removed 14/05/06
    # my $p1      = "member=";                                                              # Removed 14/05/06
    # my $p2      = "\" style=\"color: \#03c; font-weight: 700;\">";                        # Removed 14/05/06
    
    # if     ( $data =~ m/($p0)(\?)($p1)([0-9]+)($p2)($parms->{buyerid})(<\/a>)/gs ) {      # Removed 14/05/06
    #         $buyerref[0] = $4;                                                            # Removed 14/05/06

    if     ( $data =~ m/(Buyer:.+?)(\d+?)("><b>)($parms->{buyerid})(<\/b>)/gs ) {           # 14/05/06 "
             $buyerref[0] = $2;                                                             # 14/05/06
    } else {
    
            $self->{ErrorStatus}    = "1";
            $self->{ErrorMessage}   = "Reference to buyer ".$parms->{buyerid}." not found for auction ".$parms->{auctionref};
            $self->{ErrorDetail}    = "";
            return;
    }    


    # Once we have matched the buyer ID, use it to match the feedback link and extract the buyers role in
    # the auction (feedback must specify whether the buyer was a successful bidder or accepted an offer)
    #           <a href="/structure/trader_feedback_submit.asp?id=18807947&offermemberid=41207">Place feedback</a>     
    # 22/01/05  <a href="/structure/trader_feedback_submit.asp?id=45317821&amp;offermemberid=1418875">Place feedback</a>
    # 20/2/06   <a href="/structure/trader_feedback_submit.asp?id=47314601&amp;offermemberid=783439">    
    # 14/05/06  <a href="/structure/trader_feedback_submit.asp?id=56535987&amp;bidderid=1323011">
    # 03/06/06  <a href="/MyTradeMe/Feedback/Submit.aspx?id=57704077&amp;offermemberid=1618198">Place feedback</a>
    
    # $pattern = "\/structure\/trader_feedback_submit\.asp";                                # 03/06/06
    $pattern = "<a href=\"\/MyTradeMe\/Feedback\/Submit\.aspx";
    
    if     ($content =~ m/($pattern)(.+?)($parms->{auctionref})(&amp;)(bidderid=|offermemberid=)($buyerref[0])(">Place feedback<\/a>)/s) {                                                                                               #"

            if ($5 eq "bidderid=")         { $buyerref[1] = "successful_bidder"; }
            if ($5 eq "offermemberid=")    { $buyerref[1] = "offer_recipient";   }
    } else {
            $buyerref[1] = "unresolved";
            $self->{ErrorStatus}    = "1";
            $self->{ErrorMessage}   = "Feedback already placed for ".$parms->{buyerid}." on auction ".$parms->{auctionref};
            $self->{ErrorDetail}    = "";
            return;
    }

    return @buyerref;
}

#=============================================================================================
# Get TradeMeStats
# This functions need 1 parameters: auction ref
# It logs into trademe and extracts the auction details;
# It always returns a status
#=============================================================================================

sub get_TMStats {

    my $self  = shift;
    my $retries = 1;
    my $loggedin;
    my $auctions;
    my $data;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    $url="http://www.trademe.co.nz/Community/SiteStats.aspx";


    $data->{ LoggedIn   } = 0;
    $data->{ Auctions   } = 0;
    $data->{ ExtractOK  } = 0;

    while ($retries < 4 ) {

        $req = HTTP::Request->new(GET => $url);
        $response = $ua->request($req);

        if ($response->is_error()) {
        
            printf " %s\n", $response->status_line;
            $retries++;
            sleep 2;
        }

        else {

            $content = $response->content();
            if ($content =~ m/(People online right now \(live\).+?<b>)(.+?)(<\/b><\/td>)/s) {
                $loggedin = $2;
            }

            if ($content =~ m/(No\. of current listings \(live\)<\/td>.+?>)(.+?)(<\/td>)/s) {
                $auctions = $2;
            }

            $loggedin =~ tr/,//d;
            $auctions =~ tr/,//d;

            $data->{ LoggedIn   } = $loggedin;
            $data->{ Auctions   } = $auctions;
            $data->{ ExtractOK  } = 1;

            $retries = 4;
        }

    }
    return $data;
}

#=============================================================================================
# get_category_stats
#=============================================================================================

sub get_category_stats {

    my $self  = shift;
    my $category = shift;
    my $data;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    my $url="http://www.trademe.co.nz/".$category."/index.htm";

    $req = HTTP::Request->new(GET => $url);
    $response = $ua->request($req);

    if     ($response->is_error()) {
            printf " %s\n", $response->status_line;
            die "Cannot connect or unable retrieve data";
    } else {
            $content = $response->content();
            
            # html fragment as at 1/1/2005: 
            # <a href="/Trade-Me-Motors/Aircraft/mcat-0001-1484-.htm">Aircraft</a>&nbsp;<font color=#666666 size=1>(11)    

            while ($content =~ m/(\/$category\/)(.+?)(htm">)(.+?)(<\/a>&nbsp;<font color=#666666 size=1>\()(.+?)(\))/g) {    #"
                $data->{$4} = $6; 
            }
    }

    return $data;
}

#=============================================================================================
# Get TradeMe Photo count
# Method    : get_TM_photo_count
# Added     : 30/03/05
#=============================================================================================

sub get_TM_photo_count {

    my $self = shift;
    my $photocount;
    my $retries;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    # Clear error indicator and error message properties

    $self->clear_err_structure();
    
    # -- extract the current listing summary details from the first current listings page --

    # $url="http://www.trademe.co.nz/structure//view_photos.asp?page=1";        # pre 10/05/2006

    $url="http://www.trademe.co.nz/MyTradeMe/MyPhotos.aspx?page=1";             # 10/05/2006
    
    $retries = 1;
    
    while ( $retries lt 4 ) {
    
        $req      = HTTP::Request->new(GET => $url);
        $response = $ua->request($req);              

        if ( $response->is_error() ) {

            $self->update_log("[get_photo_list] Error retrieving list of photos page; Retrying (attempt $retries)");
            $retries++;
            
            if ( $retries eq 4 ) {
                $self->update_log("[get_photo_list] Could  not retrieve MyPictures URL");
                $self->{ErrorStatus}  = "1";
                $self->{ErrorMessage} = "[get_photo_list] Error retrieving list of photos page";
                return;
            }
        }
        
        else {
        
            $retries = 4;
        }
    }

    $content  = $response->content();

    # Test for no photos currently on the server

    if ($content =~ m/(You do not have any uploaded photos available)/) {

        $photocount = 0;
    }

    # Get the number of photos on TradeMe
    # as at 26/07/2006 : <td style="background: url(/images/my_trademe/grey_bg.gif);
    #                    vertical-align: middle;" align="right" nowrap>583 photos, showing 1 to 15&nbsp;&nbsp;</td>

    if ($content =~ m/(>)(\d+?)(\s+?photos, showing\s+?)(.+?)(\s+?to\s+?)(\d.+?)(.+?)(<\/td>)/) {
        $photocount    = $2;
    }

    return $photocount;

}

#=============================================================================================
# Get TradeMe Photo details
# Method    : get_photo_list
# Added     : 30/03/05
#=============================================================================================

sub get_photo_list {

    my $self = shift;
    my $photo;
    my @photos;                 # Photo array      
    my $photocount;             # Total current photos
    my $photos_pp;              # NUmber phots per page
    my $pages;                  # Calculated number of pages
    my $counter = 1;            # Item counter
    my $listpage = 1;           # Current list page
    my $pattern;                # pattern to mach in reg exps
    my $retries;
    
    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    # Clear error indicator and error message properties

    $self->clear_err_structure();
    
    # Define the external message subroutine (Callback) if provided

    my $msgsub = shift;
    
    # -- extract the current listing summary details from the first current listings page --

    # $url="http://www.trademe.co.nz/structure//view_photos.asp?page=1";        # pre 10/05/2006
    $url="http://www.trademe.co.nz/MyTradeMe/MyPhotos.aspx?page=1";             # 10/05/2006
    
    $retries = 1;
    
    while ( $retries lt 4 ) {
    
        $req      = HTTP::Request->new(GET => $url);
        $response = $ua->request($req);              

        if ($response->is_error()) {

            $self->update_log("[get_photo_list] Error retrieving list of photos page; Retrying (attempt $retries)");
            $retries++;
            sleep 5;

            if ( $retries eq 4 ) {
                $self->update_log("[get_photo_list] Could  not retrieve MyPictures URL");
                $self->{ErrorStatus}  = "1";
                $self->{ErrorMessage} = "[get_photo_list] Error retrieving list of photos page";
                return;
            }
        }
        
        else {
        
            $retries = 4;
        }
 
    }

    $content  = $response->content();

    # Test for no photos currently on the server

    if ($content =~ m/(You do not have any uploaded photos available)/) {

             $self->{photos}        = 0;
             $self->{photos_pp}     = 0;
             $self->{photo_pages}   = 0;
             return;
    }

    # Get the number of photos on Trademe and the number of photos per page
    # extract from url : <TD>220 photos, showing 1 to 15</TD>
    # as at 10/05/2006 : <td>455 photos, showing 1 to 15</td>
    # as at 26/07/2006 : <td style="background: url(/images/my_trademe/grey_bg.gif);
    #                    vertical-align: middle;" align="right" nowrap>583 photos, showing 1 to 15&nbsp;&nbsp;</td>

    # if      ($content =~ m/(<td>)(.+?)(\s+?photos, showing\s+?)(.+?)(\s+?to\s+?)(.+?)(<\/td>)/) {    # superceded 26/7/06
    
    if ($content =~ m/(>)(\d+?)(\s+?photos, showing\s+?)(.+?)(\s+?to\s+?)(\d.+?)(.+?)(<\/td>)/) {
    
        $photocount    = $2;
        $photos_pp     = $6;
        $pages         = int($photocount/$photos_pp);

        if (( $photocount/$photos_pp ) > $pages) { $pages =  $pages + 1 }

        $self->{photos}        = $2;
        $self->{photos_pp}     = $6;
        $self->{photo_pages}   = $pages;

        # Loop through the photo pages to retrieve the photo id.s and put them on the array

        while ($listpage <= $pages) {

            if ($msgsub) {
                 &$msgsub("Processing Picture Items Page ".$listpage." of ".$pages);
            }

            # $url = "http://www.trademe.co.nz/structure//view_photos.asp?page=".$listpage;     # pre 10/05/2006
            $url="http://www.trademe.co.nz/MyTradeMe/MyPhotos.aspx?page=".$listpage;            # 10/05/2006

            $retries = 1;

            while ( $retries lt 4 ) {
            
                $req = HTTP::Request->new(GET => $url);

                my $response = $ua->request($req);

                if ( $response->is_error() ) {

                    $self->update_log("[get_photo_list] Error retrieving of photo page $listpage; Retrying (attempt $retries)");
                    $retries++;

                    if ( $retries  eq 4 ) {
                        $self->update_log("[get_photo_list] Could  not retrieve MyPictures page $listpage after $retries attempts");
                        $self->{ErrorStatus}  = "1";
                        $self->{ErrorMessage} = "[get_photo_list] Error retrieving list photo page $listpage";
                        return;
                    }
                }

                else {

                    # The HTML looks something like this (as at 1st January 2005)
                    # 22/01/06  <br /><a href="http://202.21.128.20/photoserver/1/16735301_full.jpg">
                    # 10/05/06  <br /><a href="http://images.trademe.co.nz/photoserver/88/19434288_full.jpg">
                    # 25/07/06  <a href="http://images.trademe.co.nz/photoserver/92/24073992_full.jpg"><img src="

                    $content = $response->content();
                    
                    # while ($content =~ m/(<BR><A href="http:.+?)(photoserver\/)(.+?)(\/)(.+?)(_full.jpg">)/gm) {
                    # while ($content =~ m/(<br \/><a href="http:.+?)(photoserver\/)(.+?)(\/)(.+?)(_full.jpg">)/gm) {
                    # while ($content =~ m/(<br \/><a href="http:.+?)(photoserver\/)(.+?)(\/)(.+?)(_full.jpg"><img)/gm) {

                    while ($content =~ m/(<a href="http:.+?)(photoserver\/)(.+?)(\/)(.+?)(_full.jpg"><img)/gm) {

                         $photo     = $5;                # photo id
                         push (@photos, $photo);         # put photo on return array
                    }
                    
                    $retries = 4;
                }
            }
            $listpage ++;
        }
    }
    return @photos;
}

#=============================================================================================
# Method    : get_tm_unused_photos
# Added     : 02/10/05
# Input     : None
# Returns   : Array of auction numbers that can be deleted
#
# This function provides a list of TradeMe pictures that can be deleted
#=============================================================================================

sub get_tm_unused_photos {

    my $self= shift;
    my $photo;
    my @photos;                 # Photo array      
    my $photocount;             # Total current photos
    my $photos_pp;              # NUmber phots per page
    my $pages;                  # Calculated number of pages
    my $counter = 1;            # Item counter
    my $listpage = 1;           # Current list page
    my $pattern;                # pattern to mach in reg exps

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    # Clear error indicator and error message properties

    $self->clear_err_structure();
    
    # Define the external message subroutine (Callback) if provided

    my $msgsub = shift;
    
    # -- extract the current listing summary details from the first current listings page --

    # $url="http://www.trademe.co.nz/structure//view_photos.asp?page=1";      # pre 18/05/06
    
    $url="http://www.trademe.co.nz/MyTradeMe/MyPhotos.aspx?page=1";
    $req      = HTTP::Request->new(GET => $url);
    $response = $ua->request($req);              

    if ($response->is_error()) {

        $self->{ErrorStatus}  = "1";
        $self->{ErrorMessage} = "[get_photo_list] Error retrieving list of photos page";
        return;
    }

    $content  = $response->content();

    # Test for no photos currently on the server

    if ($content =~ m/(You do not have any uploaded photos available)/) {

        $self->{photos}        = 0;
        $self->{photos_pp}     = 0;
        $self->{photo_pages}   = 0;
        return;
    }

    # Get the number of photos on Trademe and the number of photos per page
    # <TD>220 photos, showing 1 to 15</TD>  # pre 18/5/06
    # <td>457 photos, showing 1 to 15</td>  # 18/5/06
    # as at 26/07/2006 : <td style="background: url(/images/my_trademe/grey_bg.gif);
    #                    vertical-align: middle;" align="right" nowrap>583 photos, showing 1 to 15&nbsp;&nbsp;</td>

    # if      ($content =~ m/(<td>)(.+?)(\s+?photos, showing\s+?)(.+?)(\s+?to\s+?)(.+?)(<\/td>)/) {    # superceded 26/7/06
    if      ($content =~ m/(>)(\d+?)(\s+?photos, showing\s+?)(.+?)(\s+?to\s+?)(\d.+?)(.+?)(<\/td>)/) {
        $photocount    = $2;
        $photos_pp     = $6;
        $pages         = int($photocount/$photos_pp);

        if (( $photocount/$photos_pp ) > $pages) { $pages =  $pages + 1 }

        $self->{photos}        = $2;
        $self->{photos_pp}     = $6;
        $self->{photo_pages}   = $pages;

        # Loop through the photo pages to retrieve the photo id's and put them on the array

        while ($listpage <= $pages) {
             
            if ($msgsub) {
                &$msgsub("Scanning MyPhotos Page ".$listpage." of ".$pages);
            }

            # $url = "http://www.trademe.co.nz/structure//view_photos.asp?page=".$listpage;  # pre 18/05/06
            $url = "http://www.trademe.co.nz/MyTradeMe/MyPhotos.aspx?page=".$listpage;       # 18/05/06

            $req = HTTP::Request->new(GET => $url);

            my $response = $ua->request($req);

            if ($response->is_error()) {
                $self->{ErrorStatus}  = "1";
                $self->{ErrorMessage} = "[get_photo_list] Error retrieving list of photos page";
                return;
            }

            else {

            # The HTML identifying phots that can be deleted looks something like this
            # ... <a href="/structure/delete_photos.asp?photo_id=12668499&page= 1">Delete Photo ...   # 01/01/2006
            # ... <a href="/MyTradeMe/DeletePhoto.aspx?photo_id=19434288&amp;page=1">Delete Photo</a> # 18/05/2006
            # ... <a href="/MyTradeMe/DeletePhoto.aspx?photo_id=24753064&amp;page=1">Delete Photo</a> # 25/07/2007
            
            $content = $response->content();

            while ($content =~ m/(<a href="\/MyTradeMe\/DeletePhoto\.aspx\?photo_id=)(\d+?)(&amp;page=)(\d+?)(">Delete Photo)/gm) {
                $photo     = $2;                # photo id
                push (@photos, $photo);         # put photo on return array
            }
        }
        $listpage ++;
        sleep 2;
    }

    return \@photos;

    }
  
}

#=============================================================================================
# Method    : delete_tm_photo
# Added     : 02/10/05
# Input     : Photo ID
# Returns   : 
#
# This function deletes a photo from TradeMe
#=============================================================================================

sub delete_tm_photo {

    my $self    = shift;
    my $PhotoId = shift;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    # Clear error indicator and error message properties

    $self->clear_err_structure();
    
    # -- extract the current listing summary details from the first current listings page --

    my $baseurl =   "http://www.trademe.co.nz/MyTradeMe/DeletePhoto.aspx?photo_id=";

    $url        =   $baseurl.$PhotoId."&page= 1";
    
    $req        =   HTTP::Request->new(GET => $url);
    $response   =   $ua->request($req);              

    if     ($response->is_error()) {

            $self->{ErrorStatus}  = "1";
            $self->{ErrorMessage} = "[delete_tm_photo] Error Deleting photo";
            return;
    }
  
}

#=============================================================================================
# Get Auction Details from TradeMe
# This functions need 1 parameters: auction ref
# It logs into trademe and extracts the auction details;
# It always returns a status
#=============================================================================================

sub list_bidders {

    my $self  = shift;
    my $auctionref = shift;
    my $bidlist;
    my @bidders;
    my @biddata;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    # retrieve auction details using get_auction_details function

    my %auction = $self->get_auction_details($auctionref);

    if ($auction{Status} eq "ACTIVE") {

         $url="http://www.trademe.co.nz/structure/auction_detail.asp?id=".$auctionref;

         $req = HTTP::Request->new(GET => $url);
         $response = $ua->request($req);

         if     ($response->is_error()) {
                 printf " %s\n", $response->status_line;
                 die "Cannot connect or unable retrieve data";
         } else {
                 $content = $response->content();

                 if ($content =~ m/(<b>Bid history)(.+?)(<\/table>)/) { $bidlist = $2; }

                 while ($bidlist =~ m/(<td>.+?listings\.asp\?member=)(\d+)(.+?<b>)(.+?)(<\/b>.+?\()(\d+|new)(.+?<\/td>)/g) {
                           $biddata[1]  = $2;                    # TradeMe numeric ID
                           $biddata[2]  = $4;                    # TradeMe handle
                           $biddata[3]  = $6;                    # No. of feedbacks

                           push (@bidders, [@biddata]);
                 }
         }
    }

    return @bidders;
}


#=============================================================================================
# bid_on_auction
# This functions places a bid on an auction; (it has no smarts it just posts a bid)
#=============================================================================================

sub bid_on_auction {

    my $self  = shift;
    my $parms = {@_};

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    # print "BidAmount   $parms->{BidAmount}\n";
    # print "ProxyBid    $parms->{ProxyBid}\n";
    # print "AuctionRef  $parms->{AuctionRef}\n";
    # print "StoreID     $parms->{StoreID}\n";
    # print "MemberID    $parms->{MemberID}\n";
    # print "Staging     $parms->{Staging}\n";
    # print "Increment   $parms->{Increment}\n";
    # print "ExistingBid $parms->{ExistingBid}\n";
    # print "StartingBid $parms->{StartingBid}\n";
    # print "Reminder    $parms->{Reminder}\n";


    my $baseurl= "http://www.trademe.co.nz/structure/";


            $url = $baseurl."process_bid.asp";
            $req = POST $url,
            ["bid"                =>  $parms->{BidAmount},
             proxy_bid            =>  "",
             confirmed            =>  1,
             id                   =>  $parms->{AuctionRef},
             staging              =>  $parms->{Staging},
             reminder             =>  "",
             mobile               =>  "",
             radio                =>  ""];

           # post the auction offer
           $content = $ua->request($req)->as_string;
}

#=============================================================================================
# load_auction
# This functions loads an auction up to trademe
# It returns the new auction number if successfully loaded otherwise returns undef
# Notes:
#=============================================================================================

### DO NOT USE THIS FUNCTION ###

sub load_auction {       ### DEPRECATED ###

    my $self  = shift;
    my $parms = {@_};
    my $newauction;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    my $baseurl= "http://www.trademe.co.nz/structure/sell/";

    #  echo the input parameters [turn on for debugging if required]
    #  Insert an appropriate for each loop with sort here (consider formatting)

    #-----------------------------------------------------------------
    # start at the new auction form and select a GENERAL AUCTION
    #-----------------------------------------------------------------

    $url = $baseurl."default.asp";

    $req = POST $url,
          [submitted            =>  1,
           mCat                 =>  "",
           group                =>  "GENERAL"];

    # Submit the initial auction request (HTTP POST operation)
    
    $content = $ua->request($req)->as_string;

    #-----------------------------------------------------------------
    # Prepare the category selection form using the input category
    #-----------------------------------------------------------------

    $url = $baseurl."newlisting_2.asp";

    $req = POST $url,
           ["submitted"            =>  1,
            "categoryID"           =>  "$parms->{CategoryID}"];

    # Submit the auction category selection (HTTP POST operation)

    $content = $ua->request($req)->as_string;

    #-----------------------------------------------------------------
    # rip any carriage return/line feeds out of the description
    # (it originates in a memo field from an access/jet database)
    #-----------------------------------------------------------------

    $parms->{Description} =~ s/\n/\x0D\x0A/g;

    #-----------------------------------------------------------------
    # Prepare the auction details form using input/paramters and
    # configuration defaults aS required
    #-----------------------------------------------------------------

    $url = $baseurl."newlisting_3.asp";

    $req = POST $url,
    ["submitted"            =>  1,
     "group"                =>  'GENERAL',
     "categoryID"           =>  $parms->{CategoryID},
     "title"                =>  $parms->{Title},
     "body"                 =>  $parms->{Description},
     "Startprice"           =>  $parms->{StartPrice},
     "reserveprice"         =>  $parms->{ReservePrice},
     "buynowprice"          =>  $parms->{BuyNowPrice},
    #"buynowonly"           =>  1,
    #"closed"               =>  1,
    #"auto_extend"          =>  1,
     "duration_type"        =>  'easy',
     "auction_length"       =>  $parms->{AuctionLength},
     "payment_info"         =>  'cash',
     "payment_info"         =>  'cheque',
     "payment_info"         =>  'bank_deposit',
     "payment_info"         =>  'Due in 7 days See Auction',
     "accepts_safetrader"   =>  3,
     "shipping_info"        =>  'Track and trace courier',
    #  permanent            =>  '',
    #  itemcount            =>  '',
    #  multiple_release     =>  '',
     "delay_start"          =>  0];

    # Submit the auction details to TradeMe (HTTP POST operation) 
    
    $content = $ua->request($req)->as_string;

    #-----------------------------------------------------------------
    # If there is a photo ID specified do TradeMe auction photo stuff
    #  -- Photos loaded in advance using the load_photo function --
    #-----------------------------------------------------------------

    #-----------------------------------------------------------------
    # Perform a GET operation to upload the required Photo ID
    # Need to extract the string operator at some stage in case
    # it changes
    #-----------------------------------------------------------------

    $url = url($baseurl."upload_photo_3_complete.asp");

    $url->query_form(memberid           => $self->{MemberID},
                     server_name        => 'http://www.trademe.co.nz',
                     string             => "YwEhtrk",
                     StrUploadNowOption => "1",
                     photo              => $parms->{PhotoId});

    $req = HTTP::Request->new('GET', $url);
    $content = $ua->request($req)->as_string;

    #-----------------------------------------------------------------
    # Prepare the auction photo charges form
    #-----------------------------------------------------------------

    $url = $baseurl."newlisting_4.asp";

    $req = POST $url,
    [submitted       =>  "1",
      gallery         =>  $parms->{Gallery}];
     # feature         =>  "1",
     # bold            =>  "1",
     # bundled_options =>  "1",
     # feature         =>  "5"];

    # Submit the auction confirmation (HTTP POST operation)
            
    $content = $ua->request($req)->as_string;
   
    #-----------------------------------------------------------------
    # Prepare the auction details confirmation form
    #-----------------------------------------------------------------

    $url = $baseurl."newlisting_5.asp";

    $req = POST $url,
    [submitted  =>  1];

    # Submit the auction confirmation (HTTP POST operation)
            
    $content = $ua->request($req)->as_string;
    
    #-----------------------------------------------------------------
    # Retrieve the Auction number to return it (return auction fees also)
    #-----------------------------------------------------------------

    if ($content =~ m/(Location: \/structure\/sell\/newlisting_6\.asp\?id=)([0-9]+?)(&type=AUCTION&sell_mode=SELL)/g) {
        $newauction = $2;
    }
    
 #   unless (defined $newauction) {print "$content\n";}

    return $newauction;
}

#=============================================================================================
# Method    : load_new_auction
# Added     : 30/03/05
# Input     : Auction parameters...
# Returns   : string (Auction NUmber from Trademe)
#
# This functions loads a new TradeMe auction
# It returns the new auction number if successfully loaded otherwise returns undef
# Notes: This fuction is intended to replace both the load_auction and winload_auction methods
#        Functionality extended to allow input of multiple photos
#=============================================================================================

sub load_new_auction {

    my $self    = shift;
    my $p       = {@_};
    my $newauction;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    # Output input parameters

    foreach my $k ( keys %$p ) {
        print "$k \t: $p->{ $k } \n";
    }

    #---------------------------------------------------------------------------------------------
    # Check that the category is valid - update log and return if not valid
    #---------------------------------------------------------------------------------------------

    if ( not $self->is_valid_category( $p->{ CategoryID } ) ) {
        $self->update_log("Auction not loaded - category $p->{CategoryID} is not a valid category");
        return;
    }
    
    #---------------------------------------------------------------------------------------------
    # Check that the category does not have children - update log and return if not valid
    #---------------------------------------------------------------------------------------------

    if ( $self->has_children( $p->{ CategoryID } ) ) {
        $self->update_log("Auction not loaded - category selection does not appear to be complete");
        return;
    }

    my $baseurl= "http://www.trademe.co.nz/structure/sell/";
    
    #-----------------------------------------------------------------
    # start at the new auction form and select a GENERAL AUCTION
    #-----------------------------------------------------------------

#    $url = $baseurl."default.asp";
    $url = "http://www.trademe.co.nz/Sell/Default.aspx";

    $req = POST $url,
          [submitted            =>  1,
           mCat                 =>  "",
           group                =>  "GENERAL"];

    # Submit the initial auction request (HTTP POST operation)
    
    $content = $ua->request($req)->as_string;
    
    $self->{Debug} ge "2" ? ($self->update_log("Initiate new auction process:")) : () ;
    $self->{Debug} ge "2" ? ($self->update_log("Post $url")) : () ;
    $self->{Debug} ge "2" ? ($self->update_log("$content")) : () ;

    #-----------------------------------------------------------------
    # Prepare the category selection form using the input category
    #-----------------------------------------------------------------

    # $url = $baseurl."newlisting_2.asp";

    $url = "http://www.trademe.co.nz/Sell/Category.aspx";

    $req = POST $url,
           ["submitted"            =>  1,
            "categoryID"           =>  "$p->{CategoryID}"];

    # Submit the auction category selection (HTTP POST operation)

    $content = $ua->request($req)->as_string;

    $self->{Debug} ge "2" ? ($self->update_log("Category selection input:")) : () ;
    $self->{Debug} ge "2" ? ($self->update_log("Post $url")) : () ;
    $self->{Debug} ge "2" ? ($self->update_log("$content")) : () ;

    #-----------------------------------------------------------------
    # rip all extra carriage return/line feeds out of the description
    # (it originates in a memo field from an access/jet database)
    # Seems like I put them in then took them out in the original code
    # no wonder I couldn't work out what was going on
    #-----------------------------------------------------------------

    $p->{Description} =  $p->{Description}."\x0D\x0A\x0D\x0A[ Loaded by Auctionitis ]";   

    # Check to see whether the send buyer email is enabled & set boolean value as appropriate

    unless ($content =~ m/(send_buyer_email)/g) {
            $p->{TMBuyerEmail} = 0;
    }

    #-----------------------------------------------------------------
    # Prepare the auction details form using input/paramters and
    # configuration defaults aS required
    #-----------------------------------------------------------------

    # $url = $baseurl."newlisting_3.asp";

    $url = "http://www.trademe.co.nz/Sell/Details.aspx";

    # Set Reserve = Start if Reserve = 0

    if ($p->{ReservePrice} == 0) { $p->{ReservePrice} = $p->{StartPrice}; }
    if ($p->{BuyNowPrice}  == 0) { $p->{BuyNowPrice}  = ""; }

    # Set start eq reserve property for use with DVD auctions

    if ( $p->{StartPrice} == $p->{ReservePrice} )   {
        $p->{StartEqReserve} = "1";
    }
    else {
        $p->{StartEqReserve} = "0";
    }

    # Reformat the end date and end time for FIXEDEND Auctions (Changed by TradeMe on 23/12)

    my ( $TMEndDate, $TMEndTime );

    if ( $p->{ EndType } eq 'FIXEDEND' ) {
        $TMEndDate = $self->TMFixedEndDate( $p->{ EndDays } );
        $TMEndTime = $self->TMFixedEndTime( $p->{ EndTime } );
        $self->update_log("Scheduled End Time: $TMEndTime");
        $self->update_log("Scheduled End Date: $TMEndDate");
    }

    $req = POST $url,
       ["submitted"                 =>   1                          ,
        "group"                     =>   'GENERAL'                  ,
        "categoryID"                =>   $p->{ CategoryID           },
        "title"                     =>   $p->{ Title                },
        $p->{ Subtitle }            ?   ("SubtitleChoice"           =>   1                      )   : ( "SubtitleChoice"    =>   0  ),
        $p->{ Subtitle }            ?   ("Subtitle"                 =>   $p->{ Subtitle }       )   : ( "Subtitle"          =>   "" ),
        "body"                      =>   $p->{ Description          },
        "is_new"                    =>   $p->{ IsNew                },
        "Startprice"                =>   $p->{ StartPrice           },
        "reserveprice"              =>   $p->{ ReservePrice         },
        "buynowprice"               =>   $p->{ BuyNowPrice          },
        $p->{ ClosedAuction }       ?   ( "closed"                  =>  'auth'                  )   : ( "closed"         =>  'all'  ),
        "autoRelist"                =>   0                          ,
        $p->{EndType} eq 'DURATION' ?   ("duration_type"            =>  'easy'                  )   : (),
        $p->{EndType} eq 'DURATION' ?   ("auction_length"           =>  $p->{ DurationHours }   )   : (),
        $p->{EndType} eq 'FIXEDEND' ?   ("duration_type"            =>  'advanced'              )   : (),
        $p->{EndType} eq 'FIXEDEND' ?   ("set_end_days"             =>  $TMEndDate              )   : (),
        $p->{EndType} eq 'FIXEDEND' ?   ("set_end_hour"             =>  $TMEndTime              )   : (),
        $p->{EndType} eq 'FIXEDEND' ?   ("auction_length"           =>  "10080"                 )   : (),
        $p->{BankDeposit}           ?   ("payment_info"             =>  "bank_deposit"          )   : (),
        $p->{CreditCard}            ?   ("payment_info"             =>  "credit_card"           )   : (),
        $p->{CashOnPickup}          ?   ("payment_info"             =>  "cash_on_pickup"        )   : (),
        $p->{SafeTrader}            ?   ("payment_info"             =>  "safe_trader"           )   : (),
        $p->{PaymentInfo}           ?   ("payment_info_other"       =>  "true"                  )   : (),
        $p->{PaymentInfo}           ?   ("payment_info"             =>  $p->{PaymentInfo    }   )   : (),
        $p->{ShippingInfo}          ?   ("shipping_info"            =>  $p->{ShippingInfo   }   )   : (),
        $p->{FreeShippingNZ}        ?   ("shipping_info"            =>  "free_shipping_nz"      )   : (),
        $p->{PickupOption} eq 1     ?   ("pickup"                   =>  "Allow"                 )   : (),
        $p->{PickupOption} eq 2     ?   ("pickup"                   =>  "Demand"                )   : (),
        $p->{PickupOption} eq 3     ?   ("pickup"                   =>  "Forbid"                )   : (),
        $p->{ShippingOption} eq 1   ?   ("delivery"                 =>  "Undecided"             )   : (),
        $p->{ShippingOption} eq 2   ?   ("delivery"                 =>  "Free"                  )   : (),
        $p->{ShippingOption} eq 3   ?   ("delivery"                 =>  "Custom"                )   : (),
        $p->{DCost1}                ?   ("delivery_cost_1"          =>  $p->{DCost1}            )   : (),
        $p->{DText1}                ?   ("delivery_method_1"        =>  $p->{DText1}            )   : (),
        $p->{DCost2}                ?   ("delivery_cost_2"          =>  $p->{DCost2}            )   : (),
        $p->{DText2}                ?   ("delivery_method_2"        =>  $p->{DText2}            )   : (),
        $p->{DCost3}                ?   ("delivery_cost_3"          =>  $p->{DCost3}            )   : (),
        $p->{DText3}                ?   ("delivery_method_3"        =>  $p->{DText3}            )   : (),
        $p->{DCost4}                ?   ("delivery_cost_4"          =>  $p->{DCost4}            )   : (),
        $p->{DText4}                ?   ("delivery_method_4"        =>  $p->{DText4}            )   : (),
        $p->{DCost5}                ?   ("delivery_cost_5"          =>  $p->{DCost5}            )   : (),
        $p->{DText5}                ?   ("delivery_method_5"        =>  $p->{DText5}            )   : (),
        $p->{DCost6}                ?   ("delivery_cost_6"          =>  $p->{DCost6}            )   : (),
        $p->{DText6}                ?   ("delivery_method_6"        =>  $p->{DText6}            )   : (),
        $p->{DCost7}                ?   ("delivery_cost_7"          =>  $p->{DCost7}            )   : (),
        $p->{DText7}                ?   ("delivery_method_7"        =>  $p->{DText7}            )   : (),
        $p->{DCost8}                ?   ("delivery_cost_8"          =>  $p->{DCost8}            )   : (),
        $p->{DText8}                ?   ("delivery_method_8"        =>  $p->{DText8}            )   : (),
        $p->{DCost9}                ?   ("delivery_cost_9"          =>  $p->{DCost9}            )   : (),
        $p->{DText9}                ?   ("delivery_method_9"        =>  $p->{DText9}            )   : (),
        $p->{DCost10}               ?   ("delivery_cost_10"         =>  $p->{DCost10}           )   : (),
        $p->{DText10}               ?   ("delivery_method_10"       =>  $p->{DText10}           )   : (),
        $p->{TMBuyerEmail}          ?   ("send_buyer_email"         =>  'y'                     )   : (),
        $p->{MovieRating}           ?   ("55"                       =>  $p->{MovieRating}       )   : (),
        $p->{MovieRating}           ?   ("57"                       =>  1,                      )   : (),
        $p->{MovieRating}           ?   ("57"                       =>  "blank"                 )   : (),
        $p->{TMATT038}              ?   ( "38"                      =>  $p->{TMATT038       }   )   : (),
        $p->{TMATT163}              ?   ( "163"                     =>  $p->{TMATT163       }   )   : (),
        $p->{TMATT164}              ?   ( "164"                     =>  $p->{TMATT164       }   )   : (),
        $p->{TMATT164}              ?   ( "start_eq_reserve"        =>  $p->{StartEqReserve }   )   : (),
        $p->{AttributeName}         ?   ($p->{ AttributeName }      =>  $p->{AttributeValue }   )   : (),
        $p->{AttributeName} eq "57"  ?  ("57"                       =>  1                       )   : (),
        $p->{AttributeName} eq "137" ?  ("137"                      =>  1                       )   : (),
        $p->{TMATT104}              ?   ( "104"                     =>  $p->{TMATT104       }   )   : (),
        $p->{TMATT104}              ?   ( "104"                     =>  $p->{TMATT104_2     }   )   : (),
        $p->{TMATT106}              ?   ( "106"                     =>  $p->{TMATT106       }   )   : (),
        $p->{TMATT106}              ?   ( "106"                     =>  $p->{TMATT106_2     }   )   : (),
        $p->{TMATT108}              ?   ( "108"                     =>  $p->{TMATT108       }   )   : (),
        $p->{TMATT108}              ?   ( "108"                     =>  $p->{TMATT108_2     }   )   : (),
        $p->{TMATT111}              ?   ( "111"                     =>  $p->{TMATT111       }   )   : (),
        $p->{TMATT112}              ?   ( "112"                     =>  $p->{TMATT112       }   )   : (),
        $p->{TMATT115}              ?   ( "115"                     =>  $p->{TMATT115       }   )   : (),
        $p->{TMATT117}              ?   ( "117"                     =>  $p->{TMATT117       }   )   : (),
        $p->{TMATT118}              ?   ( "118"                     =>  $p->{TMATT118       }   )   : (),
        "delay_start"               =>   0];

    # Submit the auction details to TradeMe (HTTP POST operation) 
    
    $content = $ua->request($req)->as_string;

    $self->{Debug} ge "2" ? ($self->update_log("Auction Detail input:")) : () ;
    $self->{Debug} ge "2" ? ($self->update_log("Post $url")) : () ;
    $self->{Debug} ge "2" ? ($self->update_log("$content")) : () ;

    # %%%% added 15/10/2008 to try and fix the notorious photo issues %%%%
    # Caters for the addition of the flash photo control

    $url = "http://www.trademe.co.nz/Sell/Photos.aspx?noFlash=1";
    $req = HTTP::Request->new(GET => $url);

    # %%%% added 14/02/2006 to try and fix the notorious photo issues %%%%

    #-----------------------------------------------------------------
    # If there is a photo ID carried over then we need to remove any
    # photos hanging around before adding the new ones
    # Search the page until no more references to pictures are found
    #-----------------------------------------------------------------

    #-----------------------------------------------------------------
    # if the remove photo url is found remove it and get the content
    #-----------------------------------------------------------------

    # <a href="http://www.TradeMe.co.nz/Sell/RemovePhoto.aspx?PhotoId=17223941&type=mult">
    # <a href="/Sell/RemovePhoto.aspx?PhotoId=17223646&amp;type=mult">                                          # 09/04/06
    # <a href="/Sell/RemovePhoto.aspx?PhotoId=27450332&amp;type=mult" onClick="persistY (this);">Delete</a>     # 20/09/06
    
    # if ($content =~ m/(<a href=")(\/Sell\/RemovePhoto\.aspx\?PhotoId=)(\d+)(&type=mult)(">)/gs) {               # 09/04/06
    #  if ($content =~ m/(<a href=")(\/Sell\/RemovePhoto\.aspx\?PhotoId=)(\d+)(&amp;type=mult")/gs) {              # 20/09/06

    my $deletedpic = 1;

    while ($content =~ m/(<a href=")(\/Sell\/RemovePhoto\.aspx\?photoid=)(\d+)(")/gs) {              # 15/09/06

        $url = url("http://www.TradeMe.co.nz".$2.$3); 

        print "Removing Unwanted Picture ref ".$deletedpic." (".$2."): $url\n";

        $req = HTTP::Request->new('GET', $url);
        $content = $ua->request($req)->as_string;
    }

    #-----------------------------------------------------------------
    # Retrieve the image records related to the auction ID;
    # for each image record get the actual picture details - 
    # then perform a GET operation to input the required Photo ID
    #  -- Photos loaded in advance using the load_photo function --
    #-----------------------------------------------------------------

    my $images = $self->get_auction_image_records( AuctionKey => $p->{ AuctionKey } );

    $self->update_log( "Retrieving image list for AuctionKey: ".$p->{ AuctionKey } );
    $self->update_log( scalar( @$images )." images selected for auction input" );

    if ( defined( $images) and scalar( @$images ) > 0 ) {

        foreach my $i ( @$images ) {

            $self->update_log( "Retrieving Auction Image record for PictureKey: ".$i->{ PictureKey } );

            my $r = $self->get_picture_record( PictureKey => $i->{ PictureKey } );

            $self->update_log( "Adding Image ".$r->{ PictureFileName }. " ID: ".$r->{ PhotoId } );

            if ( $r->{ PhotoId } ) {
        
                # <a href="/Sell/UploadPhotoComplete.aspx?photo=27450512&amp;type=mult" title="Magic Slippers.jpg">
                # 10/05/09 $url = url("http://www.TradeMe.co.nz/Sell/UploadPhotoComplete.aspx?photo=".$r->{ PhotoId }."&amp;type=mult");
                $url = "http://www.TradeMe.co.nz/Sell/UploadPhotoComplete.aspx?photo=".$r->{ PhotoId };
                
                $req = HTTP::Request->new('GET', $url);

                $response  = $ua->request( $req );
                $self->update_log( "HTTP Response code for Add Image request: ".$response->status_line );

                $content = $ua->request( $req )->as_string;
        
                $self->{ Debug } ge "2" ? ( $self->update_log( "Picture 1 input:"   ) ) : () ;
                $self->{ Debug } ge "2" ? ( $self->update_log( "GET $url"           ) ) : () ;
                $self->{ Debug } ge "2" ? ( $self->update_log( "$content"           ) ) : () ;
            }
        }
    }

    #-----------------------------------------------------------------
    # Prepare the auction photo charges form
    #-----------------------------------------------------------------

    # $url = $baseurl."newlisting_4.asp"; # Superceded 9/1/2007

    $url = "http://www.trademe.co.nz/Sell/Extras.aspx";

    # If home page selected submit with home page feature requested
    # otherwise submit with feature, gallery etc requested

    if (not $p->{ MovieRating } ) {

       if ($p->{HomePage}) {

           $req = POST $url,
           [  submitted               =>  "1"                     ,
              HomepageCheckbox        =>  $p->{ HomePage      }   ,
           ];

       }
       else {

           $req = POST $url,
           [  submitted               =>  "1"                     ,
              FeatureCheckbox         =>  $p->{ Featured      }   ,
              GalleryCheckbox         =>  $p->{ Gallery       }   ,
              BoldTitleCheckbox       =>  $p->{ BoldTitle     }   ,
              ComboCheckbox           =>  $p->{ FeatureCombo  }   ,
           ];
       }

       # Submit the auction confirmation (HTTP POST operation)
               
       $content = $ua->request($req)->as_string;
    }

    $self->{Debug} ge "2" ? ($self->update_log("Auction promotion screen:")) : () ;
    $self->{Debug} ge "2" ? ($self->update_log("Post $url")) : () ;
    $self->{Debug} ge "2" ? ($self->update_log("$content")) : () ;

    #---------------------------------------------------------------------------------------------
    # Check that the insufficient credit message has not been displayed
    #---------------------------------------------------------------------------------------------

    if ($content =~ m/(you don't have enough credit to pay for this listing)/g) {       #'
        $self->update_log("Auction not loaded due to insufficient credit on TradeMe");
        return;
    }

    #---------------------------------------------------------------------------------------------
    # Prepare the auction details confirmation form
    #---------------------------------------------------------------------------------------------

    # $url = $baseurl."newlisting_5.asp";

    $url = "http://www.trademe.co.nz/Sell/Confirm.aspx";

    $req = POST $url,
    [submitted  =>  1];

    # Submit the auction confirmation (HTTP POST operation)
            
    $content = $ua->request($req)->as_string;

    $self->{Debug} ge "2" ? ($self->update_log("Auction Confirmation screen:")) : () ;
    $self->{Debug} ge "2" ? ($self->update_log("Post $url")) : () ;
    $self->{Debug} ge "2" ? ($self->update_log("$content")) : () ;
    
    #--------------------------------------------------------------------------------------------
    # Retrieve the Auction number to return it (return auction fees also)
    # Update - fees don't seem to get returned in the content :/
    #--------------------------------------------------------------------------------------------

    #  pre 30/10/2005  <a href="../auction_detail.asp?id=39260928&ed=true">View my auction</a>
    #      30/10/2005  <a href="\.\.\/auction_detail\.asp\?id=)([0-9]+?)&ed=true">View my auction</a>
    #      21/01/2006  <a href="/Browse/Listing.aspx?id=45791055&amp;ed=true">View my auction</a>     
    
    # if ($content =~ m/(<a href="\.\.\/auction_detail\.asp\?id=)([0-9]+?)(&ed=true">View my auction<\/a>)/g) {
    
    if ($content =~ m/(<a href="\/Browse\/Listing\.aspx\?id=)([0-9]+?)(&amp;ed=true">View my auction<\/a>)/g) {
        $newauction = $2;
    }

    return $newauction;
}

#=============================================================================================
# Method: relist_auction 
# Added     : 27/03/05
# Input     : old auction number
# Returns   : new auction number
#
# This functions relists an existing TradeMe auction 
#
# It returns the new auction number if successfully loaded otherwise returns undef
# Notes:
#=============================================================================================

sub relist_auction {

    my $self  = shift;
    my $p = {@_};
    my ($newauction);
    my $watcher_checkbox = 0;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    my $baseurl= "http://www.trademe.co.nz/structure/sell/";

    $self->clear_err_structure();

    if  ( $self->{Debug} ge "2" ) {    
          $self->update_log("Auctionitis relist_auction method called with parameters:");
          while( (my $key, my $value) = each(%$p) ) {
                $self->update_log("$key \t:\t $value");
          }
    }
    
    #---------------------------------------------------------------------------------------------
    # Check that the category is valid - update log and return if not valid
    #---------------------------------------------------------------------------------------------

    if ( not $self->is_valid_category( $p->{ Category } ) ) {
        $self->update_log("Auction $p->{AuctionRef} not relisted - category $p->{Category} is not a valid category");
        return;
    }
    
    #---------------------------------------------------------------------------------------------
    # Check that the category does not have children - update log and return if not valid
    #---------------------------------------------------------------------------------------------

    if ( $self->has_children( $p->{ Category } ) ) {
        $self->update_log("Auction $p->{AuctionRef} not relisted - category selection does not appear to be complete");
        return;
    }
    
    #-----------------------------------------------------------------------------------------
    # Start by initiating the relist process as though clicking the relist button
    # As at 27/03/05 this is done by getting a specific page and (presumably) a cookie is set
    #-----------------------------------------------------------------------------------------

    # $url = "http://www.trademe.co.nz/structure/my_trademe/sell_unsold.asp?cmdRelist_".$p->{AuctionRef}."=\"Relist\"";
    $url = "http://www.trademe.co.nz/MyTradeMe/Sell/Unsold.aspx?cmdRelist_".$p->{AuctionRef}."=\"Relist\"";

    $req = HTTP::Request->new('GET', $url);
    $content = $ua->request($req)->as_string;

    $self->{Debug} ge "2" ? ($self->update_log("Initiate relist process:"   )) : () ;
    $self->{Debug} ge "2" ? ($self->update_log("GET $url\n"                 )) : () ;
    $self->{Debug} ge "2" ? ($self->update_log("$content"                   )) : () ;

    # Check to see whether the notify watchers checkbox is enabled & sett boolean value as appropriate

    if ( $content =~ m/(inform_previous_bidders)/g ) {
        $watcher_checkbox = 1;
    }

    $self->{Debug} ge "2" ? ($self->update_log("Watcher checkbox boolean value; $watcher_checkbox"   )) : () ;

    #-----------------------------------------------------------------
    # rip all extra carriage return/line feeds out of the description
    # (it originates in a memo field from an access/jet database)
    #-----------------------------------------------------------------

    $p->{Description} =  $p->{Description}."\x0D\x0A\x0D\x0A[ Loaded by Auctionitis ]";   

    # Check to see whether the send buyer email is enabled & set boolean value as appropriate

    unless ($content =~ m/(send_buyer_email)/g) {
            $p->{TMBuyerEmail} = 0;
    }

    #-----------------------------------------------------------------
    # Prepare the auction details form using input/parameters and
    # configuration defaults aS required
    #-----------------------------------------------------------------

    # $url = $baseurl."newlisting_3.asp";

    $url = "http://www.trademe.co.nz/Sell/Details.aspx";


    # Set Reserve = Start if Reserve = 0

    if ($p->{ReservePrice} == 0)    {$p->{ReservePrice} = $p->{StartPrice};}
    if ($p->{BuyNowPrice} == 0)     {$p->{BuyNowPrice} = "";}

    # Set start eq reserve property for use with DVD auctions

    if ( $p->{StartPrice} == $p->{ReservePrice} )   {
        $p->{StartEqReserve} = "1";
    }
    else {
        $p->{StartEqReserve} = "0";
    }

    # Reformat the end date and end time for FIXEDEND Auctions (Changed by TradeMe on 23/12)

    my ( $TMEndDate, $TMEndTime );

    if ( $p->{ EndType } eq 'FIXEDEND' ) {
        $TMEndTime = $self->TMFixedEndTime( $p->{ EndTime } );
        $TMEndDate = $self->TMFixedEndDate( $p->{ EndDays } );
        $self->update_log("Scheduled End Time: $TMEndTime");
        $self->update_log("Scheduled End Date: $TMEndDate");
    }

    $req = POST $url,
    ["submitted"                =>  1,
     "group"                    =>  'GENERAL'                   ,
     "categoryID"               =>  $p->{ Category          },
     "new_item_relist"          =>  0                           ,
     "title"                    =>  $p->{ Title             },
     $p->{ Subtitle }           ?   ("SubtitleChoice"       =>   1                      )   : ( "SubtitleChoice"    =>   0  ),
     $p->{ Subtitle }           ?   ("Subtitle"             =>   $p->{ Subtitle }       )   : ( "Subtitle"          =>   "" ),
     "body"                     =>  $p->{ Description       },
     "is_new"                   =>  $p->{ IsNew             },
     "Startprice"               =>  $p->{ StartPrice        },
     "reserveprice"             =>  $p->{ ReservePrice      },
     "buynowprice"              =>  $p->{ BuyNowPrice       },
     $p->{ClosedAuction}    ?   ( "closed"                  =>  'auth'                  )  : ( "closed"      =>  'all' ),
     "auto_extend"              =>  $p->{ AutoExtend        },
     $p->{EndType} eq 'DURATION' ?   ("duration_type"            =>  'easy'                  )   : (),
     $p->{EndType} eq 'DURATION' ?   ("auction_length"           =>  $p->{ DurationHours }   )   : (),
     $p->{EndType} eq 'FIXEDEND' ?   ("duration_type"            =>  'advanced'              )   : (),
     $p->{EndType} eq 'FIXEDEND' ?   ("set_end_days"             =>  "$TMEndDate"            )   : (),
     $p->{EndType} eq 'FIXEDEND' ?   ("set_end_hour"             =>  "$TMEndTime"            )   : (),
     $p->{EndType} eq 'FIXEDEND' ?   ("auction_length"           =>  "10080"                 )   : (),
     $p->{BankDeposit}           ?   ("payment_info"             =>  "bank_deposit"          )   : (),
     $p->{CreditCard}            ?   ("payment_info"             =>  "credit_card"           )   : (),
     $p->{CashOnPickup}          ?   ("payment_info"             =>  "cash_on_pickup"        )   : (),
     $p->{SafeTrader}            ?   ("payment_info"             =>  "safe_trader"           )   : (),
     $p->{PaymentInfo}           ?   ("payment_info_other"       =>  "true"                  )   : (),
     $p->{PaymentInfo}           ?   ("payment_info"             =>  $p->{PaymentInfo    }   )   : (),
     $p->{ShippingInfo}          ?   ("shipping_info"            =>  $p->{ShippingInfo   }   )   : (),
     $p->{FreeShippingNZ}        ?   ("shipping_info"            =>  "free_shipping_nz"      )   : (),
     $p->{PickupOption} eq 1     ?   ("pickup"                   =>  "Allow"                 )   : (),
     $p->{PickupOption} eq 2     ?   ("pickup"                   =>  "Demand"                )   : (),
     $p->{PickupOption} eq 3     ?   ("pickup"                   =>  "Forbid"                )   : (),
     $p->{ShippingOption} eq 1   ?   ("delivery"                 =>  "Undecided"             )   : (),
     $p->{ShippingOption} eq 2   ?   ("delivery"                 =>  "Free"                  )   : (),
     $p->{ShippingOption} eq 3   ?   ("delivery"                 =>  "Custom"                )   : (),
     $p->{DCost1}                ?   ("delivery_cost_1"          =>  $p->{DCost1}            )   : (),
     $p->{DText1}                ?   ("delivery_method_1"        =>  $p->{DText1}            )   : (),
     $p->{DCost2}                ?   ("delivery_cost_2"          =>  $p->{DCost2}            )   : (),
     $p->{DText2}                ?   ("delivery_method_2"        =>  $p->{DText2}            )   : (),
     $p->{DCost3}                ?   ("delivery_cost_3"          =>  $p->{DCost3}            )   : (),
     $p->{DText3}                ?   ("delivery_method_3"        =>  $p->{DText3}            )   : (),
     $p->{DCost4}                ?   ("delivery_cost_4"          =>  $p->{DCost4}            )   : (),
     $p->{DText4}                ?   ("delivery_method_4"        =>  $p->{DText4}            )   : (),
     $p->{DCost5}                ?   ("delivery_cost_5"          =>  $p->{DCost5}            )   : (),
     $p->{DText5}                ?   ("delivery_method_5"        =>  $p->{DText5}            )   : (),
     $p->{DCost6}                ?   ("delivery_cost_6"          =>  $p->{DCost6}            )   : (),
     $p->{DText6}                ?   ("delivery_method_6"        =>  $p->{DText6}            )   : (),
     $p->{DCost7}                ?   ("delivery_cost_7"          =>  $p->{DCost7}            )   : (),
     $p->{DText7}                ?   ("delivery_method_7"        =>  $p->{DText7}            )   : (),
     $p->{DCost8}                ?   ("delivery_cost_8"          =>  $p->{DCost8}            )   : (),
     $p->{DText8}                ?   ("delivery_method_8"        =>  $p->{DText8}            )   : (),
     $p->{DCost9}                ?   ("delivery_cost_9"          =>  $p->{DCost9}            )   : (),
     $p->{DText9}                ?   ("delivery_method_9"        =>  $p->{DText9}            )   : (),
     $p->{DCost10}               ?   ("delivery_cost_10"         =>  $p->{DCost10}           )   : (),
     $p->{DText10}               ?   ("delivery_method_10"       =>  $p->{DText10}           )   : (),
     $p->{TMBuyerEmail}          ?   ("send_buyer_email"         =>  'y'                     )   : (),
     $p->{MovieRating}           ?   ("55"                       =>  $p->{MovieRating}       )   : (),
     $p->{MovieRating}           ?   ("57"                       =>  1,                      )   : (),
     $p->{MovieRating}           ?   ("57"                       =>  "blank"                 )   : (),
     $p->{TMATT038}              ?   ( "38"                      =>  $p->{TMATT038       }   )   : (),
     $p->{TMATT163}              ?   ( "163"                     =>  $p->{TMATT163       }   )   : (),
     $p->{TMATT164}              ?   ( "164"                     =>  $p->{TMATT164       }   )   : (),
     $p->{TMATT164}              ?   ( "start_eq_reserve"        =>  $p->{StartEqReserve }   )   : (),
     $watcher_checkbox           ?   ( "inform_previous_bidders" =>  $p->{NotifyWatchers})  : (),
     $p->{AttributeName}    ?   ( $p->{ AttributeName } =>  $p->{AttributeValue})  : (),
     $p->{AttributeName}  eq "57"  ?   ("57"                =>  1                       )  : (),
     $p->{AttributeName}  eq "137" ?   ("137"               =>  1                       )  : (),
     $p->{TMATT104}         ?   ( "104"                     =>  $p->{TMATT104      })  : (),
     $p->{TMATT104}         ?   ( "104"                     =>  $p->{TMATT104_2    })  : (),
     $p->{TMATT106}         ?   ( "106"                     =>  $p->{TMATT106      })  : (),
     $p->{TMATT106}         ?   ( "106"                     =>  $p->{TMATT106_2    })  : (),
     $p->{TMATT108}         ?   ( "108"                     =>  $p->{TMATT108      })  : (),
     $p->{TMATT108}         ?   ( "108"                     =>  $p->{TMATT108_2    })  : (),
     $p->{TMATT111}         ?   ( "111"                     =>  $p->{TMATT111      })  : (),
     $p->{TMATT112}         ?   ( "112"                     =>  $p->{TMATT112      })  : (),
     $p->{TMATT115}         ?   ( "115"                     =>  $p->{TMATT115      })  : (),
     $p->{TMATT117}         ?   ( "117"                     =>  $p->{TMATT117      })  : (),
     $p->{TMATT118}         ?   ( "118"                     =>  $p->{TMATT118      })  : (),
     
     "delay_start"              =>  0];
   
    # Submit the auction details to TradeMe (HTTP POST operation) 
    
    $content = $ua->request($req)->as_string;

    $self->{ Debug } ge "2" ? ( $self->update_log( "Relist Auction Details:"    ) ) : ();
    $self->{ Debug } ge "2" ? ( $self->update_log( "POST $url"                  ) ) : ();
    $self->{ Debug } ge "2" ? ( $self->update_log( "$content"                   ) ) : ();

    # %%%% added 15/10/2008 to try and fix the notorious photo issues %%%%
    # Caters for the addition of the flash photo control

    $url = "http://www.trademe.co.nz/Sell/Photos.aspx?noFlash=1";
    $req = HTTP::Request->new(GET => $url);

    # %%%% added 12/1/2006 to try and fix the notorious photo issues %%%%

    #-----------------------------------------------------------------
    # If there is a photo ID carried over then we need to remove any
    # photos hanging around before adding the new ones
    # Process the test 3 times - once for each potential pic
    #-----------------------------------------------------------------

    my $deletedpic = 1;

    while ($content =~ m/(<a href=")(\/Sell\/RemovePhoto\.aspx\?photoid=)(\d+)(")/gs) {              # 15/09/06

        $url = url("http://www.TradeMe.co.nz".$2.$3); 

        print "Removing Unwanted Picture ref ".$deletedpic." (".$2."): $url\n";

        $req = HTTP::Request->new('GET', $url);
        $content = $ua->request($req)->as_string;
    }

    #-----------------------------------------------------------------
    # Retrieve the image records related to the auction ID
    # Perform a GET operation to upload the required Photo ID
    #  -- Photos loaded in advance using the load_photo function --
    #-----------------------------------------------------------------

    my $images = $self->get_auction_image_records( AuctionKey => $p->{ AuctionKey } );

    $self->{Debug} ge "1" ? ( $self->update_log( "Retrieving image list for AuctionKey: ".$p->{ AuctionKey } ) ): () ;
    $self->{Debug} ge "1" ? ( $self->update_log( scalar( @$images )." images selected for auction input" ) ): () ;

    if ( defined( $images) and scalar( @$images ) > 0 ) {

        foreach my $i ( @$images ) {

            $self->{Debug} ge "1" ? ( $self->update_log( "Retrieving Picture record for PictureKey: ".$i->{ PictureKey } ) ): () ;

            my $r = $self->get_picture_record( PictureKey => $i->{ PictureKey } );

            $self->{Debug} ge "1" ? ( $self->update_log( "Adding Image ".$r->{ PictureFileName }. " ID: ".$r->{ PhotoId } ) ): () ;

            if ( $r->{ PhotoId } ) {
        
                # <a href="/Sell/UploadPhotoComplete.aspx?photo=27450512&amp;type=mult" title="Magic Slippers.jpg">
                # 10/05/09 $url = url("http://www.TradeMe.co.nz/Sell/UploadPhotoComplete.aspx?photo=".$r->{ PhotoId }."&amp;type=mult");
                $url = "http://www.TradeMe.co.nz/Sell/UploadPhotoComplete.aspx?photo=".$r->{ PhotoId };
                
                $req = HTTP::Request->new('GET', $url);
                $content = $ua->request( $req )->as_string;
        
                $self->{ Debug } ge "2" ? ( $self->update_log( "Picture 1 input:"   ) ) : () ;
                $self->{ Debug } ge "2" ? ( $self->update_log( "GET $url"           ) ) : () ;
                $self->{ Debug } ge "2" ? ( $self->update_log( "$content"           ) ) : () ;
            }
        }
    }

    #-----------------------------------------------------------------
    # Prepare the auction photo charges form
    #-----------------------------------------------------------------

    # $url = $baseurl."newlisting_4.asp";

    $url = "http://www.trademe.co.nz/Sell/Extras.aspx";

    # If home page selected submit with home page feature requested
    # otherwise submit with feature, gallery etc requested

    if ($p->{HomePage}) {

        $req = POST $url,
        [   submitted               =>  "1"                         ,
            HomepageCheckbox        =>  $p->{ HomePage      }   ,
        ];
  
    }
    else {
    
        $req = POST $url,
        [   submitted               =>  "1"                         ,
            FeatureCheckbox         =>  $p->{ Featured      }   ,
            GalleryCheckbox         =>  $p->{ Gallery       }   ,
            BoldTitleCheckbox       =>  $p->{ BoldTitle     }   ,
            ComboCheckbox           =>  $p->{ FeatureCombo  }   ,
        ];
    }


    # Submit the auction confirmation (HTTP POST operation)
            
    $content = $ua->request($req)->as_string;

    $self->{Debug} ge "2" ? ($self->update_log("Auction Promotion processing:"  )) : ();
    $self->{Debug} ge "2" ? ($self->update_log("POST $url"                      )) : ();
    $self->{Debug} ge "2" ? ($self->update_log("$content\n"                     )) : ();

    #---------------------------------------------------------------------------------------------
    # Check that the insufficient credit message has not been displayed
    #---------------------------------------------------------------------------------------------

    if ( $content =~ m/(you don't have enough credit to pay for this listing)/g ) {
        $self->update_log( "Auction not relisted due to insufficient credit on TradeMe" );
        return;
    }

    #-----------------------------------------------------------------
    # Prepare the auction details confirmation form
    #-----------------------------------------------------------------

    # $url = $baseurl."newlisting_5.asp";

    $url = "http://www.trademe.co.nz/Sell/Confirm.aspx";

    $req = POST $url,
    [submitted  =>  1];

    # Submit the auction confirmation (HTTP POST operation)
            
    $content = $ua->request($req)->as_string;

    $self->{Debug} ge "2" ? ($self->update_log("Confirm Auction Relist and extract new auction number:" )) : ();
    $self->{Debug} ge "2" ? ($self->update_log("POST $url"                                              )) : ();
    $self->{Debug} ge "2" ? ($self->update_log("$content\n"                                             )) : ();
    
    #--------------------------------------------------------------------------------------------
    # Retrieve the Auction number to return it (return auction fees also)
    # Update - fees don't seem to get returned in the content :/
    #--------------------------------------------------------------------------------------------

    # <input type="hidden" name="id" value="30282367"><input type="hidden" name="relist" value="FALSE"><
    # <input type="hidden" name="id" value="29151261">
    # Sill being gay - this is not always returned (depends on something I havcen't quite fdigured yet)
    # So try this string as the number extractor:
    # <a href="./newlisting_6.asp?id=35688120&action=

    # if ($content =~ m/(<input type="hidden" name="id" value=")(.+?)(">)/g) {
    #         $newauction = $2;
    # }
    #      25/10/2005  <a href="/Browse/Listing.aspx?id=45791055&amp;ed=true">View my auction</a>     21/01/2006
    #      21/01/2006  <a href="/Browse/Listing.aspx?id=45791055&amp;ed=true">View my auction</a>     
    
    if ($content =~ m/(<a href="\/Browse\/Listing\.aspx\?id=)([0-9]+?)(&amp;ed=true">View my auction<\/a>)/g) {
        $newauction = $2;
    }
    
    return $newauction;
}

#=============================================================================================
# Method    : delete_auction
# Added     : 7/04/05
# Input     : Auction reference (string)
# Returns   : Boolean (success)
#
# This functions deletes an existing TradeMe auction
#=============================================================================================

sub delete_auction {

    my $self  = shift;
    my $parms = {@_};

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    $self->clear_err_structure();
       
    $url = "http://www.trademe.co.nz/MyTradeMe/WatchlistDelete.aspx";

    # refurl: MyTradeMe/Sell/Unsold.aspx?filter=all&amp;page=3

    $req = POST $url,
    [ refurl            =>  "http://www.trademe.co.nz/MyTradeMe/Sell/Unsold.aspx?filter=all&amp;page=1",
      type              =>  "log",
      postback          =>  "1",
      ref               =>  "unsold",
      auction_id        =>  "0",
      offer_id          =>  "",
      auction_list      =>  $parms->{ AuctionRef } ];

    $content = $ua->request($req)->as_string;

#            $self->{ErrorStatus}    = "1";
#            $self->{ErrorMessage}   = "Problem encountered deleting auction";
#            $self->{ErrorDetail}    = "";
#            return undef;

}

#=============================================================================================
# load_picture
# Method    : load_picture
# Added     : 06/06/05
# Input     : File name (as hash)
# Returns   : Hash Reference
#
# This method returns the picture number of the uploaded picture
#=============================================================================================

sub load_picture {

    my $self  = shift;
    my $parms = { @_ };
    my $xstring;
    my $newpicture;
    
    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    $self->clear_err_structure();

    # check that file exists before commencing processing; return if file does not exist

    my @exists = stat( $parms->{ FileName } );
    
    if ( not @exists ) {
        $self->update_log( "File not found: ".$parms->{ FileName } );
        return;
    }

    my $baseurl= "http://www.trademe.co.nz/structure/";

    $ua->requests_redirectable( [] );                 # Added 9/06/05
    push @{ $ua->requests_redirectable }, 'GET' ;     # Added 9/06/05
    push @{ $ua->requests_redirectable }, 'HEAD';     # Added 9/06/05

    #-----------------------------------------------------------------------------------------
    # Initialise the photo upload by requesting the upload page
    #-----------------------------------------------------------------------------------------
 
    # $url = $baseurl."upload_photo1.asp";                          # pre 10/05/2006
    $url = "http://www.trademe.co.nz/MyTradeMe/UploadPhoto.aspx";   # 10/05/2006

    $self->{ Debug } ge "2" ? ( $self->update_log( "Commencing Picture Upload process"                   ) ) : ();
    $self->{ Debug } ge "2" ? ( $self->update_log( "Uploading File Name $parms->{ FileName }"            ) ) : ();
    $self->{ Debug } ge "2" ? ( $self->update_log( "For Member Number $self->{ MemberID }"               ) ) : ();
    $self->{ Debug } ge "2" ? ( $self->update_log( "Get $url"                                            ) ) : ();

    $req      = HTTP::Request->new( GET => $url );
    $response = $ua->request( $req );
    $content  = $response->content();

    #-----------------------------------------------------------------------------------------
    # Extract the unique ID stuff returned from TradeMe to allow upload to proceed
    # Trademe returns a unique value in the ACTION URL so we have to extract the URL
    # They also return an x-string ID that has to be set properly for pictures to upload
    #-----------------------------------------------------------------------------------------

    if ($content =~ m/(.*?)(<input type=hidden name=\"string\" value=\")(.*?)(\" \/>)/) {
        $xstring = $3;
        $xstring =~ s/&quot;/"/g;           # convert HTML &quot (") substitution values from description
        $xstring =~ s/&amp;/&/g;            # convert HTML &amp  (&) substitution values from description
        $xstring =~ s/&#8216;/`/g;          # convert HTML &amp  (&) substitution values from description
        $xstring =~ s/&#8217;/'/g;          # convert HTML &amp  (&) substitution values from description "'
        print "X-String Value: $xstring\n";
    }

    $self->{ Debug } ge "1" ? ( $self->update_log( "X-String Value: $xstring" ) ) : ();

    # print "TradeMe x-string value: $xstring\n";  # Debugging stuff...

    # Code before 10-6-04 changes which caused IP addresses to sometimes turn up in the URL
    # if ($content =~ m/(.*?)(action=)(\")(http:\/\/wwww\.trademe\.co\.nz\/upload_photo2\.asp.+?)(\")/) #{
    #    $url = $4;
    #}

    #    if ($content =~ m/(.*?)(<FORM action=\")(http:\/\/)(.+?)(\/upload_photo2\.asp.+?)(\")/) {
    #        $url = $3.$4.$5.$6;
    #    }

    $self->{ Debug } ge "2" ? ( $self->update_log( "Content:"                                            ) ) : ();
    $self->{ Debug } ge "2" ? ( $self->update_log( "---------------------------------------------------" ) ) : ();
    $self->{ Debug } ge "2" ? ( $self->update_log( "$content"                                            ) ) : ();
    $self->{ Debug } ge "2" ? ( $self->update_log( "---------------------------------------------------" ) ) : ();
    $self->{ Debug } ge "2" ? ( $self->update_log( "Attempting to extract picture upload URL with unique key data (pseudo password)" ) ) : ();
    
    # changed 2/2/07    if ($content =~ m/(<form action=")(http:\/\/uploads)(.+?)(" method="post")/gs) {
    if ($content =~ m/(<form action=")(http:\/\/www.trademe.co.nz\/Upload\/MyPhoto\.aspx)(.+?)(" method="post")/gs) {    #" 
    $url = $2.$3;
        $self->update_log( "URL extracted: $url" );
    }
    else {
        $self->update_log( "couldn't extract usable URL" );
    }
    
    $self->{Debug} ge "2" ? ($self->update_log("Push picture to TradeMe")) : ();
    $self->{Debug} ge "2" ? ($self->update_log("POST $url")) : () ;

    $req  = POST $url,
           ['memberid'              =>  $self->{ MemberID }          ,
            'photo_type'            =>  'new_auction'                ,
            'server_name'           =>  'http:\/\/www.trademe.co.nz' ,
            'string'                =>  $xstring,
            'watermark'             =>  "$self->{ Watermark }"       ,
            'fileloc'               => ["$parms->{FileName}"=>"$parms->{FileName}"=>'image/pjpeg']],
            'Content_Type'          =>  'multipart/form-data'        ;

    # Upload the auction photos (HTTP POST operation)

    $content = $ua->request($req)->as_string;

    #-----------------------------------------------------------------
    # Retrieve the Trademe picture reference number
    #-----------------------------------------------------------------

    $self->{ Debug } ge "2" ? ( $self->update_log( "Content:"                                            ) ) : ();
    $self->{ Debug } ge "2" ? ( $self->update_log( "---------------------------------------------------" ) ) : ();
    $self->{ Debug } ge "2" ? ( $self->update_log( "$content"                                            ) ) : ();
    $self->{ Debug } ge "2" ? ( $self->update_log( "---------------------------------------------------" ) ) : ();

    # html fragment confirming picture upload 
    # ;uploaded=true&amp;photo=25912456&amp;        [14/08/06]
    # ?uploaded=true&amp;photo=32859174"            [09/01/07]
        
    # if ($content =~ m/(uploaded=true\&photo=)(.*?)(\n)/g) {

    if ($content =~ m/(uploaded=true\&amp;photo=)(\d+?)(")/g) {                     #"
        $newpicture = $2;
    }

    $self->update_log( "Extracted New Picture ID Value: $newpicture" );

    push @{$ua->requests_redirectable}, 'POST';     # Added 9/06/05

    return $newpicture;
}

#=============================================================================================
# load_picture
# Method    : load_picture
# Added     : 06/06/05
# Input     : File name (as hash)
# Returns   : Hash Reference
#
# This method returns the picture number of the uploaded picture
#=============================================================================================

sub load_picture_from_DB {

    my $self  = shift;
    my $p = { @_ };
    my $xstring;
    my $newpicture;
    
    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    $self->clear_err_structure();

    my $baseurl= "http://www.trademe.co.nz/structure/";

    $ua->requests_redirectable( [] );                 # Added 9/06/05
    push @{ $ua->requests_redirectable }, 'GET' ;     # Added 9/06/05
    push @{ $ua->requests_redirectable }, 'HEAD';     # Added 9/06/05

    #-----------------------------------------------------------------------------------------
    # Initialise the photo upload by requesting the upload page
    #-----------------------------------------------------------------------------------------
 
    # $url = $baseurl."upload_photo1.asp";                          # pre 10/05/2006
    $url = "http://www.trademe.co.nz/MyTradeMe/UploadPhoto.aspx";   # 10/05/2006

    $self->{ Debug } ge "2" ? ( $self->update_log( "Commencing Picture Upload process"                   ) ) : ();
    $self->{ Debug } ge "2" ? ( $self->update_log( "Uploading File Name $p->{ PictureKey }"          ) ) : ();
    $self->{ Debug } ge "2" ? ( $self->update_log( "For Member Number $self->{ MemberID }"               ) ) : ();
    $self->{ Debug } ge "2" ? ( $self->update_log( "Get $url"                                            ) ) : ();

    $req      = HTTP::Request->new( GET => $url );
    $response = $ua->request( $req );
    $content  = $response->content();

    #-----------------------------------------------------------------------------------------
    # Extract the unique ID stuff returned from TradeMe to allow upload to proceed
    # Trademe returns a unique value in the ACTION URL so we have to extract the URL
    # They also return an x-string ID that has to be set properly for pictures to upload
    #-----------------------------------------------------------------------------------------

    if ($content =~ m/(.*?)(<input type=hidden name=\"string\" value=\")(.*?)(\" \/>)/) {
        $xstring = $3;
        $xstring =~ s/&quot;/"/g;           # convert HTML &quot (") substitution values from description
        $xstring =~ s/&amp;/&/g;            # convert HTML &amp  (&) substitution values from description
        $xstring =~ s/&#8216;/`/g;          # convert HTML &amp  (&) substitution values from description
        $xstring =~ s/&#8217;/'/g;          # convert HTML &amp  (&) substitution values from description "'
        print "X-String Value: $xstring\n";
    }

    $self->{ Debug } ge "1" ? ( $self->update_log( "X-String Value: $xstring" ) ) : ();

    # print "TradeMe x-string value: $xstring\n";  # Debugging stuff...

    # Code before 10-6-04 changes which caused IP addresses to sometimes turn up in the URL
    # if ($content =~ m/(.*?)(action=)(\")(http:\/\/wwww\.trademe\.co\.nz\/upload_photo2\.asp.+?)(\")/) #{
    #    $url = $4;
    #}

    #    if ($content =~ m/(.*?)(<FORM action=\")(http:\/\/)(.+?)(\/upload_photo2\.asp.+?)(\")/) {
    #        $url = $3.$4.$5.$6;
    #    }

    $self->{ Debug } ge "2" ? ( $self->update_log( "Content:"                                            ) ) : ();
    $self->{ Debug } ge "2" ? ( $self->update_log( "---------------------------------------------------" ) ) : ();
    $self->{ Debug } ge "2" ? ( $self->update_log( "$content"                                            ) ) : ();
    $self->{ Debug } ge "2" ? ( $self->update_log( "---------------------------------------------------" ) ) : ();
    $self->{ Debug } ge "2" ? ( $self->update_log( "Attempting to extract picture upload URL with unique key data (pseudo password)" ) ) : ();
    
    # changed 2/2/07    if ($content =~ m/(<form action=")(http:\/\/uploads)(.+?)(" method="post")/gs) {
    if ($content =~ m/(<form action=")(http:\/\/www.trademe.co.nz\/Upload\/MyPhoto\.aspx)(.+?)(" method="post")/gs) {    #" 
    $url = $2.$3;
        $self->update_log( "URL extracted: $url" );
    }
    else {
        $self->update_log( "couldn't extract usable URL" );
    }

    $self->{Debug} ge "2" ? ( $self->update_log( "Push picture to TradeMe"  ) ) : ();
    $self->{Debug} ge "2" ? ( $self->update_log( "POST $url"                ) ) : () ;

    # Get the image data from the database

    my $imagedata = $self->get_picture_image_data( PictureKey => $p->{ PictureKey } );
    open ( IMAGEDATA, '>', 'image.jpg' );
    binmode IMAGEDATA;
    print IMAGEDATA $imagedata;
    close IMAGEDATA;

    $req  = POST $url,
           ['memberid'              =>  $self->{ MemberID }          ,
            'photo_type'            =>  'new_auction'                ,
            'server_name'           =>  'http:\/\/www.trademe.co.nz' ,
            'string'                =>  $xstring,
            'watermark'             =>  "$self->{ Watermark }"       ,
            'fileloc'               => [ "image.jpg" => "$p->{ ImageName }.jpg" => 'image/pjpeg'] ],
            'Content_Type'          =>  'multipart/form-data'        ;

    # Upload the auction photos (HTTP POST operation)

    $content = $ua->request($req)->as_string;

    #-----------------------------------------------------------------
    # Retrieve the Trademe picture reference number
    #-----------------------------------------------------------------

    $self->{ Debug } ge "2" ? ( $self->update_log( "Content:"                                            ) ) : ();
    $self->{ Debug } ge "2" ? ( $self->update_log( "---------------------------------------------------" ) ) : ();
    $self->{ Debug } ge "2" ? ( $self->update_log( "$content"                                            ) ) : ();
    $self->{ Debug } ge "2" ? ( $self->update_log( "---------------------------------------------------" ) ) : ();

    # html fragment confirming picture upload 
    # ;uploaded=true&amp;photo=25912456&amp;        [14/08/06]
    # ?uploaded=true&amp;photo=32859174"            [09/01/07]
        
    # if ($content =~ m/(uploaded=true\&photo=)(.*?)(\n)/g) {

    if ($content =~ m/(uploaded=true\&amp;photo=)(\d+?)(")/g) {                     #"
        $newpicture = $2;
    }

    $self->update_log( "Extracted New Picture ID Value: $newpicture" );

    push @{$ua->requests_redirectable}, 'POST';     # Added 9/06/05

    return $newpicture;
}

#=============================================================================================
# update trusted web
# This functions need 3 parameters: auction ref and buyer id (thats the text handle of the
# buyer) and the feedback text to be posted.
#=============================================================================================

sub update_trusted_web {

    my $self  = shift;
    my $parms = {@_};

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    my $baseurl= "http://www.trademe.co.nz/structure/";

#    $content = $response->content();

    $url = $baseurl."add_member_trust_reln2.asp";
    $req = POST $url,
    [ about_member_id    =>  "0",
      nickname           =>  $parms->{user},
      reln_type          =>  "T"];

      # post the new trusted web member name
      $content = $ua->request($req)->as_string;

}


#=============================================================================================
# Process received email (currently transferred from Eudora)
# This method will return a reference to a hash that has the various pieces of mail
# data extracted from the incoming email where they are applicable
# The calling program will need to cater for which attributes are returned based on the
# MailType attribute of the hash
#=============================================================================================

#*********************************************************************************************
# --- Mail Processing Routines ---
#*********************************************************************************************

sub process_mail_in {

    my $self  = shift;
    my $input = shift;
    my $maildata;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    # Extract the type of mail from the subject of the email

    if ($input =~ m/(.+?)(Subject: )(.+?)(To:)/) {

        if     ($3 =~ m/A question on your auction/)           { $maildata->{Type} = "QUESTION";}
        elsif  ($3 =~ m/New Feedback Posted/)                  { $maildata->{Type} = "NEWFBACK";}
        elsif  ($3 =~ m/your auction for/ )                    { $maildata->{Type} = "NEWAUCT" ;}
        elsif  ($3 =~ m/You have been out-bid/)                { $maildata->{Type} = "OUTBID"  ;}
        elsif  ($3 =~ m/Your auction has finished/)            { $maildata->{Type} = "ENDAUCT" ;}
        elsif  ($3 =~ m/Your offer has been accepted/)         { $maildata->{Type} = "OFFERYES";}
        elsif  ($3 =~ m/Your offer for auction.+?has closed/)  { $maildata->{Type} = "OFFERNO" ;}
        elsif  ($3 =~ m/Your offer has not been accepted/)     { $maildata->{Type} = "OFFEREXP";}
        else                                                   { $maildata->{Type} = "UNKNOWN" ;}
    }

    # if the auction has ended then parse the details out of the email

    #-------------------------------------------------------------------
    # Processing for auction ended (ENDAUCT) emails
    #-------------------------------------------------------------------

    if ($maildata->{Type} eq "ENDAUCT") {

       # Extract auction description & convert to lower case (if required)

       if ($input =~ m/(Your auction for \")(.+?)(\")/)
          {$maildata->{Description} = $2;}

       # Extract auction number (use url reference as text location is more predictable)

       if ($input =~ m/(id=)([0-9]+)(\s+)/) {
           $maildata->{Auctionref} = $2;
       }

       # Check whether the auction sold as a buy it now auction and set status to BUYITNOW

       if ($input =~ m/(The auction was won with a \"Buy Now\" bid)/)
          {$maildata->{Result} = "BUYITNOW";}

       # If email has success fee then auction was successful; if there is not already a buy
       # it now status then the item must have sold at auction so set status to WINNINGBUD
       # if there is no success fee then then item was passed in so set status to PASSEDIN

       if     ($input =~ m/SUCCESS FEE:(\s+?)(.+?)(\s+?)/) {
               $maildata->{SuccessFee} = $2;
               if (not defined($maildata->{Result})) { $maildata->{Result} = "WINNINGBID";}
       } else {
               $maildata->{Result} = "PASSEDIN";
       }

       if      ($maildata->{Result} ne "PASSEDIN") {

               # Extract auction amount

               if ($input =~ m/(AMOUNT:)(\s+)(.+?)(\s+)/) {
                   $maildata->{ClosePrice} = $3;
               }

               # Extract successful bidders name

               if ($input =~ m/(TOP BIDDER:|USERNAME:)(\s+)(.+?)(\s+)/) {
                   $maildata->{BuyerName} = $3;
               }

               # Extract bidders email address

               if ($input =~ m/(mailto:)(.+?)(\s+)/) {
                   $maildata->{BuyerEmail} = $2;
               }
       } else {
               # Extract closing amount if passed in

               if   ($input =~ m/(he highest bid the auction received was for)(\s+)(.+?)(\s+)/) {
                    ($maildata->{ClosePrice} = $3) =~ s/(\$[0-9]+\.[0-9]+)(\.)/$1/;
               } else {
                     $maildata->{ClosePrice} = "\$0.00";
               }
       }

       $self->close_DBauction(AuctionRef    => $maildata->{Auctionref},
                              AuctionStatus => $maildata->{Result},
                              SuccessFee    => $maildata->{SuccessFee},
                              ClosePrice    => $maildata->{ClosePrice},
                              BuyerName     => $maildata->{BuyerName},
                              BuyerEmail    => $maildata->{BuyerEmail});
    }

    #-------------------------------------------------------------------
    # End of Processing for auction ended (ENDAUCT) emails
    #-------------------------------------------------------------------

    #-------------------------------------------------------------------
    # Processing for Offer accepted (OFFERYES) emails
    #-------------------------------------------------------------------

    if ($maildata->{Type} eq "OFFERYES") {

        $maildata->{Result} = "FIXEDOFFER";

       # Extract auction description & convert to lower case (if required)

       if ($input =~ m/(Your fixed-price offer for \")(.+?)(\")/)
          {$maildata->{Description} = $2;}

       # Extract auction number (use url reference as text location is more predictable)

       if ($input =~ m/(id=)([0-9]+)/) {
           $maildata->{Auctionref} = $2;
       }

       # Extract the Success fee

       if ($input =~ m/SUCCESS FEE:(\s+)(.+?)(\s+)/) {
           $maildata->{SuccessFee} = $2;
       }

       # Extract auction amount

       if ($input =~ m/(AMOUNT:)(\s+)(.+?)(\s+)/) {
           $maildata->{ClosePrice} = $3;
       }

       # Extract successful bidders name

       if ($input =~ m/(TOP BIDDER:|USERNAME:)(\s+)(.+?)(\s+)/) {
           $maildata->{BuyerName} = $3;
       }

       # Extract bidders email address

       if ($input =~ m/(mailto:)(.+?)(\s+)/) {
           $maildata->{BuyerEmail} = $2;
       }

       $self->close_DBauction(AuctionRef    => $maildata->{Auctionref},
                              AuctionStatus => $maildata->{Result},
                              SuccessFee    => $maildata->{SuccessFee},
                              ClosePrice    => $maildata->{ClosePrice},
                              BuyerName     => $maildata->{BuyerName},
                              BuyerEmail    => $maildata->{BuyerEmail});
    }

    #-------------------------------------------------------------------
    # End of Processing for Offer accepted (OFFERYES) emails
    #-------------------------------------------------------------------

    #-------------------------------------------------------------------
    # Processing for Offer not accepted (OFFERNO) emails
    #-------------------------------------------------------------------

    if ($maildata->{Type} eq "OFFERNO") {

        $self->close_DBauction(AuctionRef    => $maildata->{Auctionref},
                               AuctionStatus => $maildata->{Type});
    }

    #-------------------------------------------------------------------
    # End of Processing for Offer accepted (OFFERNO) emails
    #-------------------------------------------------------------------

    #-------------------------------------------------------------------
    # Processing for Offer Expireded (OFFEREXP) emails
    #-------------------------------------------------------------------

    if ($maildata->{Type} eq "OFFEREXP") {

        $self->close_DBauction(AuctionRef    => $maildata->{Auctionref},
                               AuctionStatus => $maildata->{Type});
    }

    #-------------------------------------------------------------------
    # End of Processing for Offer accepted (OFFERNO) emails
    #-------------------------------------------------------------------

    #-------------------------------------------------------------------
    # Processing for Offer New Auction advice (NEWAUCT) emails
    #-------------------------------------------------------------------

    if ($maildata->{Type} eq "NEWAUCT") {

       # Extract auction description & convert to lower case (if required)

       if ($input =~ m/(Your auction for \")(.+?)(\")/)
          {$maildata->{Description} = $2;}

       # Extract auction number (use url reference as text location is more predictable)

       if ($input =~ m/(id=)([0-9]+)/) {
           $maildata->{Auctionref} = $2;
       }

       # Extract Starting price amount

       if ($input =~ m/(Start price:)(\s+)(.+?)(\s+)/) {
           $maildata->{StartPrice} = $3;
       }

       # Extract reserve amount

       if ($input =~ m/(Reserve price:)(\s+)(.+?)(\s+)/) {
           $maildata->{ReservePrice} = $3;
       }

       # Extract Buy Now price

       if ($input =~ m/(Buy now price:)(\s+)(.+?)(\s+)/) {
           $maildata->{BuyNowPrice} = $3;
       }

       # Extract Auction end date and time

       if ($input =~ m/(Listing ends:)(\s+)(.+?)(,\s+)(.+?)(\s+)/) {
           $maildata->{EndDate} = $3;
           $maildata->{EndTime} = $5;
       }

       # Add the new auction to the auctions database

       my $time = localtime;
       $maildata->{EndDate}     = $maildata->{EndDate}." 2003";
       $maildata->{EndDate}     =~ tr/ /-/;
       ($maildata->{StartDate}  = $time)  =~ s/^(.+?)(\s+)(.+?)(\s+)(.+?)(\s+)(.+?)(\s+)(.+?)$/$5-$3-$9/;

       $self->insert_DBauction(AuctionRef    => $maildata->{Auctionref},
                               Description   => $maildata->{Description},
                               AuctionStatus => $maildata->{Type},
                               StartDate     => $maildata->{StartDate},
                               EndDate       => $maildata->{EndDate},
                               EndTime       => $maildata->{EndTime},
                               StartPrice    => $maildata->{StartPrice},
                               Reserve       => $maildata->{ReservePrice},
                               BuyNowPrice   => $maildata->{BuyNowPrice});
    }

    #-------------------------------------------------------------------
    # End of Processing for New Auction advice (NEWAUCT) emails
    #-------------------------------------------------------------------

    return $maildata;
}

#=============================================================================================
# build auction ackowledgement
#=============================================================================================

sub crt_auction_ack {

    my $self  = shift;
    my $data  = @_;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    my $template="c:\\evan\\trademe\\forms\\auction_ack.form";
    my $text = $self->_process_template($template, $data);

    return $text
}

#=============================================================================================
# build buy-it-now acknowledgement
#=============================================================================================

sub crt_buyitnow_ack {

    my $self  = shift;
    my $data  = @_;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    my $template="c:\\evan\\trademe\\forms\\buyitnow_ack.form";
    my $text = $self->_process_template($template, $data);

    return $text
}

#=============================================================================================
# build details-already-sent response
#=============================================================================================

sub crt_detailssent_adv {

    my $self  = shift;
    my $data  = @_;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    my $template="c:\\evan\\trademe\\forms\\detailssent_adv.form";
    my $text = $self->_process_template($template, $data);

    return $text
}

#=============================================================================================
# build request for address
#=============================================================================================

sub crt_address_req {

    my $self  = shift;
    my $data  = @_;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    my $template="c:\\evan\\trademe\\forms\\address_req.form";
    my $text = $self->_process_template($template, $data);

    return $text
}

#=============================================================================================
# build request for response from bidder
#=============================================================================================

sub crt_response_req {

    my $self  = shift;
    my $data  = @_;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    my $template="c:\\evan\\trademe\\forms\\response_req.form";
    my $text = $self->_process_template($template, $data);

    return $text
}

#=============================================================================================
# build akncowledgement of payment pending
#=============================================================================================

sub crt_payment_pend_ack {

    my $self  = shift;
    my $data  = @_;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    my $template="c:\\evan\\trademe\\forms\\payment_pend_ack.form";
    my $text = $self->_process_template($template, $data);

    return $text
}

#=============================================================================================
# build payment recieved acknowledgement
#=============================================================================================

sub crt_payment_rcvd_ack {

    my $self  = shift;
    my $data  = @_;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    my $template="c:\\evan\\trademe\\forms\\payment_rcvd_ack.form";
    my $text = $self->_process_template($template, $data);

    return $text
}

#=============================================================================================
# build buy-it-now acknowledgement
#=============================================================================================

sub crt_payment_req {

    my $self  = shift;
    my $data  = @_;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    my $template="c:\\evan\\trademe\\forms\\payment_req.form";
    my $text = $self->_process_template($template, $data);

    return $text
}



#=============================================================================================
# fill in variables on form template
#=============================================================================================

sub _process_template {

    my $self  = shift;
    my $template=shift;
    my $data = {@_};
    my $text;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    local $/;                                                      #slurp mode (undef)
    local *F;                                                      #create local filehandle
    open(F, "< $template\0") || return;
    $text = <F>;                                                   #read whole file
    close(F);                                                      # ignore retval
    # replace quoted words with value  in %$fillings hash
    $text =~ s{ %%  ( .*? ) %% }
              { exists( $data->{$1} )
                      ? $data->{$1}
                      : ""
              }gsex;
    return $text
}


#=============================================================================================
# Send Email out using the SMTP Server from the config file
#=============================================================================================

sub send_email {

    my $self  = shift;
    my $parms = {@_};
    my $maildata;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    # send the email to the target user

    $maildata = MIME::Lite->build(
                Type      => 'text',
                From      => $self->{SenderAddress},
                To        => $parms->{ToAddress},
                Subject   => $parms->{Subject},
                Data      => $parms->{MessageData});

    # If email is on actually send the email via SMTP

    if  ($self->{SendEmail} eq "Yes") {
         $maildata->send('smtp', $self->{SMTPServer}, Timeout=>120);
    }

    # If mail logging is active write mail log entry

    if ($self->{LogMail} eq "Yes") {

        my $time = localtime;
       (my $currdate = $time)  =~ s/^(.+?)(\s+)(.+?)(\s+)(.+?)(\s+)(.+?)(\s+)(.+?)$/$5-$3-$9/;
       (my $currtime = $time)  =~ s/^(.+?)(\s+)(.+?)(\s+)(.+?)(\s+)(.+?)(\s+)(.+?)$/$7/;

        my $sth = $dbh->prepare( qq { INSERT INTO MailLog (MailDate, MailTime, MailType, MailTo, AuctionRef, MailData) Values(?,?,?,?,?,?)}) || die "Error preparing statement: $DBI::errstr\n";

        #substitute the Control-Enter combo for cr/lf (or new line ?) to format memo fields properly

        # Format the Message data to display correctly in the memo
        # field by replacing the line feeds with the ctr-enter codes

        $parms->{MessageData} =~ s/\n/\x0D\x0A/g;

        $sth->bind_param(6, $sth, DBI::SQL_LONGVARCHAR);

        $sth->execute($currdate,
                      $currtime,
                      $parms->{Type},
                      $parms->{ToAddress},
                      $parms->{AuctionRef},
                      $parms->{MessageData})
                   || die "Error executing statement: $DBI::errstr\n";
        }

    # If a copy is required send a copy to the copy address

    if ($self->{SendCopy} eq "On") {

        $parms->{Subject} = "[SENDER COPY] ".$parms->{Subject};
        $parms->{MessageData} = "*** Original sent to: ".$parms->{ToAddress}."***\n\n".$parms->{MessageData};

        $maildata = MIME::Lite->build(Type      => 'text',
                                      From      => $self->{SenderAddress},
                                      To        => $self->{CopyAddress},
                                      Subject   => $parms->{Subject},
                                      Data      => $parms->{MessageData});

        # If email is on actually send the email via SMTP

        if  ($self->{SendEmail} eq "Yes") {
             $maildata->send('smtp', $self->{SMTPServer}, Timeout=>120);
        }
    }
}

#=============================================================================================
# update_log
# update the mailmate log file
#=============================================================================================

sub update_log {

    my $self = shift;
    my $text = shift;

    #### DO NOT ADD STANDARD DEBUGGING TO THIS METHOD I.E. UPDATE_LOG   ####
    #### AS IT WILL RESULT IN A RECURSIVE CALL                          ####    

    # IF the log file is not defined exit

    if ( not defined( $logfile ) ) {
        return;
    }

    # check whether date on log file is same as today and roll logs if not
    
    my @stat=stat( $logfile );
    
    my ($secs, $mins, $hrs, $dd, $mm, $yy, $dow, $jul, $isdst) = localtime($stat[8]);
    
    my $logdate = "$dd-$mm-$yy";
    
    ($secs, $mins, $hrs, $dd, $mm, $yy, $dow, $jul, $isdst) = localtime;
    
    my $nowdate = "$dd-$mm-$yy";

    if ( $nowdate ne $logdate ) {
        unlink( $oldlog );
        rename( $logfile, $oldlog );
    }
    
    # open the logfile

    open (LOGFILE, ">> $logfile");

    #format the retrieved date and time values

    $mm = $mm + 1;
    $yy = $yy + 1900;

    if ($secs < 10)   { $secs = "0".$secs; }
    if ($mins < 10)   { $mins = "0".$mins; }
    if ($dd   < 10)   { $dd   = "0".$dd;   }
    if ($mm   < 10)   { $mm   = "0".$mm;   }

    my $now = "$dd-$mm-$yy $hrs:$mins:$secs";

    # Strip any new lines out before printing to log
    
#    @_ =~ tr/\n//; 

    $text =~ tr/\n//; 

    print LOGFILE "$now $text\n";
    
    close LOGFILE;
}

#*********************************************************************************************
# --- Category Maintenance Rotines ---
#*********************************************************************************************

#=============================================================================================
# Method    : get_remote_service_date   
# Added     : 7/05/05        
# Input     : 
# Returns   : Current Service date (in dd-mm-yyyy format)
#                            
# This function retrieves the current service date value from the Auctionitis website
#=============================================================================================

sub get_remote_service_date {

    my $self = shift;           # Auctionitis object

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    $self->clear_err_structure();
    
    # -- extract the current listing summary details from the first current listings page --

    # $url="http://www.auctionitis.co.nz/service/Category_Control.html"; superceded 15/8/05
    
    $url = $self->{ServiceURL}."/Category_Control.html";

    $self->{Debug} ge "1" ? ($self->update_log("Using Service URL: ". $self->{ServiceURL} )) : () ;

    $req       = HTTP::Request->new(GET => $url);
    $response  = $ua->request($req);

    if ($response->is_error()) {

        $self->{ErrorStatus}  = "1";
        $self->{ErrorMessage} = "Error retrieving URL containing Category Service Date";
        return;
    }

    $content = $response->content();

    if ( $content =~ m/(<TR><TD>Current Service Date<\/TD><TD>)(.+?)(<\/TD><\/TR>)/ ) {
    
        $self->{RemoteServiceDate}=$2;
             
    }
    
    else {

        $self->{ErrorStatus}  = "1";
        $self->{ErrorMessage} = "Could not extract Category Service Date";
        return;
    }

}

#=============================================================================================
# Method    : get_remote_checksum   
# Added     : 7/05/05        
# Input     : 
# Returns   : Category file checksum
#                            
# This function retrieves the current category checksum value from the Auctionitis website
#=============================================================================================

sub get_remote_checksum {

    my $self = shift;           # Auctionitis object

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    # Clear error indicator and error message properties

    $self->clear_err_structure();
    
    # -- extract the current listing summary details from the first current listings page --

    # $url="http://www.auctionitis.co.nz/service/Category_Control.html"; Superceded 15/8/05

    $url = $self->{ServiceURL}."/Category_Control.html";

    $self->{Debug} ge "1" ? ($self->update_log("Using Service URL: ". $self->{ServiceURL} )) : () ;

    $req       = HTTP::Request->new(GET => $url);
    $response  = $ua->request($req);

    if     ($response->is_error()) {

            $self->{ErrorStatus}  = "1";
            $self->{ErrorMessage} = "Error retrieving URL containing Category Service Checksum";
            return;
    }

    $content = $response->content();

    if       ( $content =~ m/(<TR><TD>Category Checksum<\/TD><TD>)(.+?)(<\/TD><\/TR>)/ ) {
    
             $self->{RemoteChecksum}=$2;
             
    } else {

            $self->{ErrorStatus}  = "1";
            $self->{ErrorMessage} = "Could not extract Category Service Checksum";
            return;
    }

}

#=============================================================================================
# Method    : get_remote_current_version   
# Added     : 7/05/05        
# Input     : 
# Returns   : Category file checksum
#                            
# This function retrieves the current category checksum value from the Auctionitis website
#=============================================================================================

sub get_remote_current_version {

    my $self = shift;           # Auctionitis object

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    # Clear error indicator and error message properties

    $self->clear_err_structure();

    # $url="http://www.auctionitis.co.nz/service/Category_Control.html"; supercdeded 15/8/05

    $url = $self->{ServiceURL}."/Category_Control.html";

    $self->{Debug} ge "1" ? ($self->update_log("Using Service URL: ". $self->{ServiceURL} )) : () ;

    $req       = HTTP::Request->new(GET => $url);
    $response  = $ua->request($req);

    if     ($response->is_error()) {

            $self->{ErrorStatus}  = "1";
            $self->{ErrorMessage} = "Error retrieving URL containing Remote Current Version Value";
            return;
    }

    $content = $response->content();

    if       ( $content =~ m/(<TR><TD>Current Version<\/TD><TD>)(.+?)(<\/TD><\/TR>)/ ) {
    
             $self->{RemoteCurrentVersion} = $2;
             
    } else {

            $self->{ErrorStatus}  = "1";
            $self->{ErrorMessage} = "Could not extract Remote current Version";
            return;
    }

}

#=============================================================================================
# Method    : get_remote_category_table   
# Added     : 7/05/05        
# Input     : 
# Returns   : referenced array of hash records
#                            
# This function returns an array of hashs containing the master category table stored
# on the auctionitis web site
#=============================================================================================

sub get_remote_category_table {

    my $self = shift;           # Auctionitis object
    my @categories;             # array to category records
    my %record;                 # category record

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    # Clear error indicator and error message properties

    $self->clear_err_structure();

    # $url="http://www.auctionitis.co.nz/service/Category_Data.html";  Superceded 15/8/05

    $url = $self->{ServiceURL}."/Category_Data.html";

    $self->{Debug} ge "1" ? ($self->update_log("Using Service URL: ". $self->{ServiceURL} )) : () ;

    $req       = HTTP::Request->new(GET => $url);
    $response  = $ua->request($req);

    if     ($response->is_error()) {

            $self->{ErrorStatus}  = "1";
            $self->{ErrorMessage} = "Error retrieving URL containing Category Table Date";
            return;
    }

    $content = $response->content();
    
    print "$content\n";

    while  ( $content =~ m/(<TR><TD>)(.+?)(<\/TD><TD>)(.+?)(<\/TD><TD>)(.+?)(<\/TD><TD>)(.+?)(<\/TD><\/TR>)/g ) {

             # Put the category data into a hash
            
             $record{ Category      }   = $2;
             $record{ Description   }   = $4;
             $record{ Parent        }   = $6;
             $record{ Sequence      }   = $8;

             $self->{Debug} ge "2" ? ($self->update_log("Category $record{Description} $record{Category} $record{Parent} $record{Sequence}")) :();
             
             # push the hash into the categories array 
             
             push (@categories, { %record });
    
    }            

    return \@categories;
}

#=============================================================================================
# Method    : get_service_dates
# Added     : 7/05/05        
# Input     : 
# Returns   : referenced array of hash records
#                            
# This function returns an array of hashs containing the unloaded service dates and the 
# service URL for loading the data
#=============================================================================================

sub get_service_dates {

    my $self = shift;           # Auctionitis object
    my $localservicedate = shift;
    my @servicedates;           # array of service date hashes
    my %record;                 # service record

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    # Clear error indicator and error message properties

    $self->clear_err_structure();
    
    # reverse the local service date parameter to allow simpler date comparisons
    
    my $revlocal = substr( $localservicedate,6,4 ) * 10000 +
                   substr( $localservicedate,3,2 ) * 100 +
                   substr( $localservicedate,0,2 );

    # $url="http://www.auctionitis.co.nz/service/Category_Data.html"; Superceded 15/8/05

    $url = $self->{ServiceURL}."/Category_Control.html";

    $self->{Debug} ge "1" ? ($self->update_log("Using Service URL: ". $self->{ServiceURL} )) : () ;

    $req       = HTTP::Request->new(GET => $url);
    $response  = $ua->request($req);

    if     ($response->is_error()) {

            $self->{ErrorStatus}  = "1";
            $self->{ErrorMessage} = "Error retrieving URL containing Service Date Data";
            return;
    }

    $content = $response->content();

    # Format of service data web page
    # <TR><TD>Service Date</TD><TD>18-07-2005</TD><TD>url data</TD></TR>
    
    while  ( $content =~ m/(<TR><TD>Service Date<\/TD><TD>)(.+?)(<\/TD><TD>)(.+?)(<\/TD><\/TR>)/g ) {

             # Put the service data into a hash

             $record{ ServiceDate   }   = $2;
             $record{ ServiceURL    }   = $4;

             my $revremote = substr( $record{ ServiceDate   },6,4 ) * 10000 +
                             substr( $record{ ServiceDate   },3,2 ) * 100 +
                             substr( $record{ ServiceDate   },0,2 );

             if ($revremote > $revlocal) {

                 # push the hash into the categories array 

                 push (@servicedates, { %record } );
             }
    
    }            

    return \@servicedates;
}

#=============================================================================================
# Method    : get_remapping_data
# Added     : 7/05/05        
# Input     : Service URL
# Returns   : referenced array of hash records
#                            
# This function returns an array of hashs containing the description of the category being
# Remapped, the old category number and the new category number
#=============================================================================================

sub get_remapping_data {

    my $self        = shift;    # Auctionitis object
    my $serviceurl  = shift;
    my @mapdata;                # array of service date hashes
    my %record;                 # service record

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    # Clear error indicator and error message properties

    $self->clear_err_structure();

    $url       = $serviceurl;

    $self->{Debug} ge "1" ? ($self->update_log("Using Service URL: ". $serviceurl )) : () ;

    $req       = HTTP::Request->new(GET => $url);
    $response  = $ua->request($req);

    if     ($response->is_error()) {

            $self->{ErrorStatus}  = "1";
            $self->{ErrorMessage} = "Error retrieving URL containing Remapping Data";
            return;
    }

    $content = $response->content();

    # Format of service data record
    # <TR><TD>Clothing/Costumes</TD><TD>1472</TD><TD>153</TD></TR>

    while  ( $content =~ m/(<TR><TD>)(.+?)(<\/TD><TD>)(.+?)(<\/TD><TD>)(.+?)(<\/TD><\/TR>)/g ) {

             # Put the service data into a hash
            
             $record{ Description   }   = $2;
             $record{ OldCategory   }   = $4;
             $record{ NewCategory   }   = $6;
             
             # push the hash into the categories array 
             
             push (@mapdata, { %record } );
    
    }            

    return \@mapdata;
}

#=============================================================================================
# Method    : clear_category_table
# Added     : 7/05/05        
# Input     : 
# Returns   : 
#                            
# This function deletes all records from the category table
#=============================================================================================

sub clear_category_table {

    my $self = shift;
    
    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    my $SQLStmt = "DELETE * FROM TMCategories";
    my $sth = $dbh->prepare($SQLStmt)|| die "Error preparing statement: $DBI::errstr\n";
    $sth->execute() || die "Error executing statement: $DBI::errstr\n";

}

#=============================================================================================
# Method    : insert_category_record
# Added     : 7/05/05        
# Input     : Hash containing category data
# Returns   : 
#                            
# This function adds a new category record
#=============================================================================================

sub insert_category_record {

    my $self = shift;
    my $input = {@_};
    my $record;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    $record->{ Category      }   = "";
    $record->{ Description   }   = 0;
    $record->{ Parent        }   = $6;
    $record->{ Sequence      }   = $8;
    

    # Read through the input values and alter the corresponding fields in the "Record" hash

    while ((my $key, my $value) = each(%{$input})) {
            $record->{$key} = $value;
    }

    # insert the updated record into the database

    my $sth = $dbh->prepare( qq { INSERT INTO TMCategories ( Description   ,     
                                                             Category      ,     
                                                             Parent        ,                
                                                             Sequence      )                
                                    VALUES                 (?,?,?,?         ) } );    
    
    $sth->execute( "$record->{ Description   }",           
                    $record->{ Category      },              
                    $record->{ Parent        },              
                    $record->{ Sequence      })              
                    || die "Insert_DBAuction - Error executing statement: $DBI::errstr\n";
}

#=============================================================================================
# Method    : convert_category
# Added     : 7/05/05        
# Input     : Old category, new category
# Returns   : 
#                            
# This function converts an old category to a new category
# This allows categories deleted by TradeMe to be remapped to a new valid category
#=============================================================================================

sub convert_category {

    my $self = shift;

    my $oldcat = shift;
    my $newcat = shift;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    # Set categories equal to old category equal to new category

    my $sth = $dbh->prepare( qq { UPDATE Auctions SET Category = ? WHERE Category = ?})
              || die "Error preparing statement: $DBI::errstr\n";

    $sth->execute($newcat, $oldcat)
              || die "Error executing statement: $DBI::errstr\n";

    # Check each set of defaults & Alter default category value if it is one of the dropped categories
    # Processing of subkeys should only run if default sets have been saved and created

    my $profkey = $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities"};   #TODO

    if ( $profkey ) {
        foreach my $subkey (  $profkey->SubKeyNames  ) {
            my $key = $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities/".$subkey."/Defaults"};
            my $dftcat = $key->{"/Category"};
            if ($dftcat eq $oldcat) {$key->{"/Category"} = $newcat;}
        }
    }
}

#=============================================================================================
# Method    : update_local_service_date   
# Added     : 9/05/05        
# Input     : 
# Returns   : Current Service date (in dd-mm-yyyy format)
#                            
# This function updates the local service date to the remote service date value
# This function should be called after get_remote_service_date which set the RemoteServiceDate
# property, and after any outstanding category updates have been applied
# It is also recommended that the local and remote category checksums be compared before
# executing this function to provide maximum surety that the category data is good
#=============================================================================================

sub update_local_service_date {

    my $self = shift;           # Auctionitis object

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    $self->clear_err_structure();

    my $key = $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Properties"}; #TODO
    
    $key->{"/Category"} = $self->{RemoteServiceDate};
}

#=============================================================================================
# Method    : calculate_local_checksum
# Added     : 7/05/05        
# Input     : 
# Returns   : Current Service date (in dd-mm-yyyy format)
#                            
# This function updates the local service date to the remote service date value
# This function should be called after get_remote_service_date which set the RemoteServiceDate
# property, and after any outstanding category updates have been applied
#=============================================================================================

sub get_local_checksum {

    my $self = shift;           # Auctionitis object

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    $self->clear_err_structure();

    # Load all the category records into the categories referenced hash

    my $SQLStmt = "SELECT * FROM TMCategories";
    
    my $sth     = $dbh->prepare($SQLStmt)|| die "Error preparing statement: $DBI::errstr\n";
    
    $sth->execute() || die "Error executing statement: $DBI::errstr\n";

    my $categories = $sth->fetchall_arrayref({});

    # Read through the categories array and calculate the checksum value for the categories table
    # This is the sum of all the category values and is used to check the integrity of the client category table
 
    my $category_checksum = 0;
 
    foreach my $record (@$categories) {
       $category_checksum = $category_checksum + $record->{ Category }        
    }
    
    $self->{LocalChecksum} = $category_checksum;

}

#=============================================================================================
# Method    : get_category_readme
# Added     : 7/05/05        
# Input     : 
# Returns   : 
#                            
# This function writes the category readme file to disk
#=============================================================================================

sub get_category_readme {

    my $self = shift;           # Auctionitis object

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    $self->clear_err_structure();

    # $url       = "http://auctionitis.co.nz/service/Category update readme.txt"; Superceded 15/8/05

    $url = $self->{ServiceURL}."/Category update readme.txt";

    $self->{Debug} ge "1" ? ($self->update_log("Using Service URL: ". $self->{ServiceURL} )) : () ;

    $response  = $ua->get($url);

    if     ($response->is_error()) {

            $self->{ErrorStatus}  = "1";
            $self->{ErrorMessage} = "Error retrieving URL containing Service Date Data";
            return;
    }

    $content = $response->content();
   
    return $content;

}


#*********************************************************************************************
# --- DataBase Access Routines ---
#*********************************************************************************************

#=============================================================================================
# Method    : DBConnect    
# Added     : 07/05/05
# Input     : Database Name (optional)
# Returns   : 
#
# This function connects Auctionitis to the database; if an argument is supplied Auctionitis
# will attempt to connect to the supplied ODBC connection name, otherwise it will connect to
# the default data source name stored in the Registry
#=============================================================================================

sub DBconnect {

    my $self  = shift;
    my $DB    = shift;
    
    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    if ( not defined $DB ) { $DB = $self->{ DataBaseName } } # Probably not required any more... or use for path to db file

    #   Create the database handle and then make it a property of the Autionitis object for use by other modules

    #SQL Lite database driver
    
    my $dbfile = "C:\\evan\\auctionitis103\\auctionitis.db3";
    $dbh = DBI->connect( "dbi:SQLite:dbname=$dbfile","","" );

    # ODBC Driver for access databases

    # $dbh=DBI->connect('dbi:ODBC:'.$DB, {AutoCommit => 1} ) 
    #     || die "Error opening Auctions database: $DBI::errstr\n";
        
    $dbh->{ LongReadLen } = 65555;            # cater for retrieval of memo fields

    $self->{ DBH } = $dbh;

    # Set the Category Service date now - rethink this strategy...

    $self->{ CategoryServiceDate } = $self->get_DB_property(
        Property_Name       =>  "CategoryServiceDate"   ,
        Property_Default    =>  "01-01-2006"            ,
    );

    # create pre-prepared  statement handles

    $sth_is_DBauction_104 = $dbh->prepare( qq {
        SELECT  COUNT(*)
        FROM    Auctions
        WHERE   AuctionRef                      = ?
    });
    
    $sth_get_auction_key = $dbh->prepare( qq { 
        SELECT AuctionKey
        FROM   Auctions
        WHERE  AuctionRef                     = ?
    });

    $sth_get_auction_record = $dbh->prepare( qq { 
        SELECT  *
        FROM    Auctions
        WHERE   AuctionKey                     = ?
    });

    $sth_set_auction_closed = $dbh->prepare( qq { 
        UPDATE  Auctions  
        SET     AuctionStatus                  = 'CLOSED'
        WHERE   AuctionKey                     = ? 
    });
    
    $sth_update_auction_record = $dbh->prepare( qq { 
        UPDATE  Auctions  
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
                Quickpay                       = ?,
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
        WHERE   AuctionKey                     = ? 
    });

    # Additional setup for field 2 (Description) as it is a memo field    
    
    $sth_update_auction_record->bind_param( 3, $sth_update_auction_record, DBI::SQL_LONGVARCHAR);   
    $sth_update_auction_record->bind_param(78, $sth_update_auction_record, DBI::SQL_LONGVARCHAR);   

    $sth_delete_picture_record      = $dbh->prepare( qq { 
    
        DELETE  FROM    Pictures 
                WHERE   PictureKey  = ?
    });

    $sth_delete_auction_record      = $dbh->prepare( qq { 
    
        DELETE  FROM    Auctions
                WHERE   AuctionKey  = ?
    });

    $SQL_update_stock_on_hand       = $dbh->prepare( qq { 
        UPDATE      Auctions
        SET         StockOnHand     = ?
        WHERE       ProductCode     = ?
    } );

}

#=============================================================================================
# Method    : DBDisconnect    
# Added     : 24/01/06
# Input     : 
# Returns   : 
#
# This function disconnects Auctionitis from the currently connnected database; 
#=============================================================================================

sub DBdisconnect {

    my $self  = shift;
    
    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    $sth_is_DBauction_104->finish;
    
    $sth_get_auction_key->finish;

    $sth_get_auction_record->finish;

    $sth_set_auction_closed->finish;
    
    $sth_update_auction_record->finish;

    $sth_delete_picture_record->finish;

    $sth_delete_auction_record->finish;
        
    $dbh->disconnect    || warn $dbh->errstr;
}


#=============================================================================================
# Get Email stored in database back into a message data format
#=============================================================================================

sub get_DBemail {

    my $self  = shift;
    my $parms = {@_};
    my $maildata;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    my $sth = $dbh->prepare( qq { SELECT   MailData
                                  FROM     MailLog
                                  WHERE  ((MailDate   = ?)
                                  AND     (MailTime   = ?)
                                  AND     (Auctionref = ?))})
                                  || die "Error preparing statement: $DBI::errstr\n";

    $sth->execute($parms->{MailDate},
                  $parms->{MailTime},
                  $parms->{AuctionRef}
    ) || die "Error exexecuting statement: $DBI::errstr\n";

    $maildata=$sth->fetchrow_array;

    print "$maildata\n";

    return $maildata;
}


#=============================================================================================
# Check if Auction in database
#=============================================================================================

sub is_DBauction {

    my $self = shift;
    my $auctionref = shift;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    my $sth = $dbh->prepare("SELECT COUNT(*) FROM Auctions WHERE (((AuctionNumber)=?))") || die "Error preparing statement: $DBI::errstr\n";
    $sth->execute($auctionref) || die "Error exexecuting statement: $DBI::errstr\n";
    my $found=$sth->fetchrow_array;

    return $found;
}

#=============================================================================================
# Get closing price of auction in database
#=============================================================================================

sub get_DBcloseprice {

    my $self = shift;
    my $auctionref = shift;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    my $sth = $dbh->prepare("SELECT ClosPrice FROM Auctions WHERE (((AuctionNumber)=?))") || die "Error preparing statement: $DBI::errstr\n";
    $sth->execute($auctionref) || die "Error exexecuting statement: $DBI::errstr\n";
    my $closeprice = $self->CurrencyFormat($sth->fetchrow_array);

    return $closeprice;
}

#=============================================================================================
# Add Auction to Database
# Update the Auctions databaSe (usually with the TradeMe details confirmed via email)
#=============================================================================================

sub insert_DBauction {

    my $self = shift;
    my $parms = {@_};
    my $AuctionActive = 1;          # Set AuctionActive status field to "True"

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    # Set defaults where required

    my $sth = $dbh->prepare( qq { INSERT INTO Auctions (AuctionNumber, Description, AuctionActive,AuctionStatus, StartDate, EndDate, EndTime, StartPrice, Reserve, BuyNowPrice) VALUES(?,?,?,?,?,?,?,?,?,?)}) || die "Error preparing statement: $DBI::errstr\n";

    my $time = localtime;
    (my $currdate = $time)  =~ s/^(.+?)(\s+)(.+?)(\s+)(.+?)(\s+)(.+?)(\s+)(.+?)$/$5-$3-$9/;
    (my $currtime = $time)  =~ s/^(.+?)(\s+)(.+?)(\s+)(.+?)(\s+)(.+?)(\s+)(.+?)$/$7/;

    $sth->execute($parms->{AuctionRef},
                  $parms->{Description},
                  $AuctionActive,
                  $parms->{AuctionStatus},
                  $currdate,
                  $parms->{EndDate},
                  $parms->{EndTime},
                  $parms->{StartPrice},
                  $parms->{Reserve},
                  $parms->{BuyNowPrice})
                  || die "Error executing statement: $DBI::errstr\n";
}

#=============================================================================================
# Update auction database
# Update the Auctions databaSe (usually with the TradeMe details confirmed via email)
# This function first retrieves the data from the current database record and places data for
# all fields in a hash keyed on field name: $record->{key} = $value. The input data is a hash
# with the field name and data to be updated. Each record in the input hash is matched against
# the corresponding field name in the retrieved record has and the value altered to the input
# value. When all fields in the inpuyt has have been processed the record is written back into
# the database with the updated values
#=============================================================================================

sub update_DBauction {

    my $self = shift;
    my $parms = {@_};
    my $record;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    # Retrieve the current record from the database and update "Record" data-Hash

    my $sth = $dbh->prepare( qq { SELECT *
                                  FROM   Auctions
                                  WHERE  AuctionNumber  = ? })
                                  || die "Error preparing statement: $DBI::errstr\n";

    $sth->execute($parms->{AuctionRef}) || die "Error executing statement: $DBI::errstr\n";

    $record = $sth->fetchrow_hashref;

    # Read through the input record and alter the corresponding field in the "Record" hash

    while ((my $key, my $value) = each(%{$parms})) {
            $record->{$key} = $value;
    }

    # Update the database with the new updated "Record" hash

    $sth = $dbh->prepare( qq { UPDATE Auctions
                               SET    Description    = ?,
                                      AuctionActive  = ?,
                                      AuctionStatus  = ?,
                                      StartDate      = ?,
                                      EndDate        = ?,
                                      EndTime        = ?,
                                      Viewed         = ?,
                                      Cost           = ?,
                                      StartPrice     = ?,
                                      Reserve        = ?,
                                      BuyNowPrice    = ?,
                                      CurrentBid     = ?,
                                      SuccessFee     = ?,
                                      AuctionSold    = ?,
                                      ClosePrice     = ?,
                                      BuyerNumber    = ?
                               WHERE  AuctionNumber  = ? })
                               || die "Error preparing statement: $DBI::errstr\n";

     $sth->execute($record->{Description},
                   $record->{AuctionActive},
                   $record->{AuctionStatus},
                   $record->{StartDate},
                   $record->{EndDate},
                   $record->{EndTime},
                   $record->{Viewed},
                   $record->{Cost},
                   $record->{StartPrice},
                   $record->{Reserve},
                   $record->{BuyNowPrice},
                   $record->{CurrentBid},
                   $record->{SuccessFee},
                   $record->{AuctionSold},
                   $record->{ClosePrice},
                   $record->{BuyerNumber},
                   $record->{AuctionRef})
                   || die "Error executing statement: $DBI::errstr\n";
}

#=============================================================================================
# Close Auction on database
# Update the Auctions databaSe (usually with the TradeMe details confirmed via email)
#=============================================================================================

sub close_DBauction {

    my $self = shift;
    my $parms = {@_};
    my $AuctionActive = 0;          # Set AuctionActive status field to "False"
    my $AuctionSold = 0;            # Set AuctionSold default status field to "False"
    my $CustomerNumber = 0;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    # Set defaults where required

    if (not defined $parms->{SuccessFee}) { $parms->{SuccessFee} = "\$0.00";}
    if (not defined $parms->{ClosePrice}) {
        $parms->{ClosePrice} = $self->get_DBcloseprice($parms->{AuctionRef});
    }

    # If the auction sold set the sold status to True
    # then get the TradeMe numeric buyer ID and write a customer database record
    # If the customer cant be found set the customer Number to 999999

    if    (($parms->{AuctionStatus} eq "OFFERYES")
    or     ($parms->{AuctionStatus} eq "WINNINGBID")
    or     ($parms->{AuctionStatus} eq "BUYITNOW"))  {

            $AuctionSold = 1;

            if (not $self->{is_connected}) {
                $self->login();
            }

            my @bidderid = $self->get_bidder_id(auctionref => $parms->{AuctionRef},
                                                buyerid    => $parms->{BuyerName});

            if     ($bidderid[0] ne "ERROR") {
                    $CustomerNumber = $bidderid[0];
                    if   (not $self->is_DBcustomer($CustomerNumber)) {
                          $self->insert_DBcustomer(BuyerNumber => $CustomerNumber,
                                                   BuyerID     => $parms->{BuyerName},
                                                   Email       => $parms->{BuyerEmail});
                    }
            } else {
                    $CustomerNumber = 999999;
            }
    }

    my $sth = $dbh->prepare( qq { UPDATE Auctions
                                  SET    AuctionActive  = ?,
                                         SuccessFee     = ?,
                                         AuctionStatus  = ?,
                                         ClosePrice     = ?,
                                         AuctionSold    = ?,
                                         BuyerNumber    = ?
                                  WHERE  AuctionNumber  = ? })
                                  || die "Error preparing statement: $DBI::errstr\n";

     $sth->execute($AuctionActive,
                   $parms->{SuccessFee},
                   $parms->{AuctionStatus},
                   $parms->{ClosePrice},
                   $AuctionSold,
                   $CustomerNumber,
                   $parms->{AuctionRef})
                   || die "Error executing statement: $DBI::errstr\n";
}


#=============================================================================================
# Add Customer to Database
#=============================================================================================

sub insert_DBcustomer {

    my $self = shift;
    my $parms = {@_};

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    my $sth = $dbh->prepare( qq { INSERT INTO Customers (BuyerNumber, BuyerID, Email) Values(?,?,?)}) || die "Error preparing statement: $DBI::errstr\n";

    $sth->execute($parms->{BuyerNumber},
                  $parms->{BuyerID},
                  $parms->{Email})
                  || die "Error executing statement: $DBI::errstr\n";
}

#=============================================================================================
# Check if Customer is in database
#=============================================================================================

sub is_DBcustomer {

    my $self = shift;
    my $cusnumber = shift;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    my $sth = $dbh->prepare("SELECT COUNT(*) FROM Customers WHERE (((BuyerNumber)=?))") || die "Error preparing statement: $DBI::errstr\n";
    $sth->execute($cusnumber) || die "Error exexecuting statement: $DBI::errstr\n";
    my $found=$sth->fetchrow_array;

    return $found;
}

#=============================================================================================
# Pause until enter pressed (utility routine for DOS windows)
#=============================================================================================

sub pause {

    my $self = shift;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    print "Press enter to continue...\n";
    <STDIN>;
}

#=============================================================================================
# List message board threads
#=============================================================================================

sub ListMBThreads {

    my $self  = shift;
    my $topic = shift;   #input numeric parameter
    my @threads;
    my %totals;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    my $url="http://www.trademe.co.nz/structure/messageboard/show_threads.asp?topic=".$topic;

    $req      = HTTP::Request->new(GET => $url);
    $response = $ua->request($req);              
    $content  = $response->content();
    
#    my $pattern = "<a href=\"\/structure\/messageboard\/show_messages\.asp\?id=";
    my $pattern = "<a href=\"\/structure\/messageboard\/show_messages\.asp";

    while ($content =~ m/($pattern)(.*?)(id=)(.+?)(&threadid=)(.+?)(\">)/g) {
           push (@threads, $6);
    }

    my $baseurl="http://www.trademe.co.nz/structure/messageboard/show_messages.asp?id=";

    foreach my $thread (@threads) {

        $url       = $baseurl.$thread."&threadid=".$thread;
        $req       = HTTP::Request->new(GET => $url);
        $response  = $ua->request($req);
        $content  = $response->content();

        if ($content =~ m/(1\.<\/td><td.+?<B>)(.+?)(<\/B>)/) {
            print "Reading thread: $2\n";
        }
        $pattern = "<DIV align=right><a href=\"\/structure\/show_member_listings\.asp";
        while ($content =~ m/($pattern)(.*?)(member=)(.+?)(\"><font color=#0033cc><b>)(.+?)(<\/b>)/g) {
               if (exists($totals{$6})) {$totals{$6} = $totals{$6} + 1;}
               else                     {$totals{$6} = 1;}
        }
        sleep 5;
    }
    return %totals;
}
#=============================================================================================
# List message board thread starters
#=============================================================================================

sub ListMBThreadStarters {

    my $self  = shift;
    my $topic = shift;   #input numeric parameter
    my @threads;
    my %totals;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    my $url="http://www.trademe.co.nz/structure/messageboard/show_threads.asp?topic=".$topic;

    $req      = HTTP::Request->new(GET => $url);
    $response = $ua->request($req);              
    $content  = $response->content();
    
#    my $pattern = "<a href=\"\/structure\/messageboard\/show_messages\.asp\?id=";
    my $pattern = "<a href=\"\/structure\/messageboard\/show_messages\.asp";

    while ($content =~ m/($pattern)(.*?)(id=)(.+?)(&threadid=)(.+?)(\">)/g) {
           push (@threads, $6);
    }

    my $baseurl="http://www.trademe.co.nz/structure/messageboard/show_messages.asp?id=";

    foreach my $thread (@threads) {

        $url       = $baseurl.$thread."&threadid=".$thread;
        $req       = HTTP::Request->new(GET => $url);
        $response  = $ua->request($req);
        $content  = $response->content();

        if ($content =~ m/(1\.<\/td><td.+?<B>)(.+?)(<\/B>)/) {
            print "Reading thread: $2\n";
        }
        $pattern = "<DIV align=right><a href=\"\/structure\/show_member_listings\.asp";
        if ($content =~ m/($pattern)(.*?)(member=)(.+?)(\"><font color=#0033cc><b>)(.+?)(<\/b>)/) {
              if (exists($totals{$6})) {$totals{$6} = $totals{$6} + 1;}
              else                     {$totals{$6} = 1;}
        }
        sleep 5;
    }
    return %totals;
}

#*********************************************************************************************
# --- DataBase Access Routines --- V1.03 database format ---1
#*********************************************************************************************

#=============================================================================================
# Check if Auction in database
#=============================================================================================

sub is_DBauction_103 {

    my $self = shift;
    my $auctionref = shift;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    my $sth = $dbh->prepare("SELECT COUNT(*) FROM Auctions WHERE (((TradeMeRef)=?))") 
          || die "Error preparing statement: $DBI::errstr\n";
    $sth->execute($auctionref) 
          || die "Error exexecuting statement: $DBI::errstr\n";
    my $found=$sth->fetchrow_array;

    return $found;
}

#=============================================================================================
# Add Auction to Database
#=============================================================================================

sub insert_DBauction_103 {

    my $self = shift;
    my $input = {@_};
    my $record;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

#    my $dbh=DBI->connect('dbi:ODBC:Auctionitis') 
#       || die "Error opening Auctions database: $DBI::errstr\n";
#    $dbh->{LongReadLen} = 65555;            # caters for retrieval of memo fields

    # Set default values for new record
    # Key value AuctionKey is defined as Autonumber and will be generated by the database
    
    $record->{Title}                = "";
    $record->{Description}          = "";
    $record->{IsNew}                = 0;
    $record->{AuctionLoaded}        = 0;
    $record->{AuctionHeld}          = 0;
    $record->{TradeMeRef}           = "";
    $record->{DateLoaded}           = "01/01/2000";
    $record->{TradeMeFees}          = 0;
    $record->{CategoryID}           = "";
    $record->{MovieRating}          = 0;
    $record->{MovieConfirm}         = 0;
    $record->{StartPrice}           = 0;
    $record->{ReservePrice}         = 0;
    $record->{BuyNowPrice}          = 0;
    $record->{DurationHours}        = 0;
    $record->{ClosedAuction}        = 0;
    $record->{AutoExtend}           = 0;
    $record->{Cash}                 = 0;
    $record->{Cheque}               = 0;
    $record->{BankDeposit}          = 0;
    $record->{PaymentInfo}          = "";
    $record->{FreeShippingNZ}       = 0;
    $record->{ShippingInfo}         = "";
    $record->{SafeTrader}           = 0;
    $record->{PictureName}          = "";
    $record->{PhotoId}              = "";
    $record->{Featured}             = 0;
    $record->{Gallery}              = 0;
    $record->{BoldTitle}            = 0;
    $record->{FeatureCombo}         = 0;
    $record->{HomePage}             = 0;
    $record->{Permanent}            = 0;
    $record->{CopyCount}            = 1;
    $record->{Message}              = "";
    

    # Read through the input values and alter the corresponding fields in the "Record" hash

    while ((my $key, my $value) = each(%{$input})) {
            $record->{$key} = $value;
    }

    # insert the updated record into the database

    my $sth = $dbh->prepare( qq { INSERT INTO Auctions (Title,        
                                                        Description,  
                                                        IsNew,        
                                                        AuctionLoaded,
                                                        AuctionHeld,  
                                                        TradeMeRef,   
                                                        DateLoaded,   
                                                        TradeMeFees,  
                                                        CategoryID,   
                                                        MovieRating,  
                                                        MovieConfirm, 
                                                        StartPrice,   
                                                        ReservePrice, 
                                                        BuyNowPrice,  
                                                        DurationHours,
                                                        ClosedAuction,
                                                        AutoExtend,   
                                                        Cash,         
                                                        Cheque,       
                                                        BankDeposit,  
                                                        PaymentInfo,  
                                                        FreeShippingNZ,
                                                        ShippingInfo, 
                                                        SafeTrader,   
                                                        PictureName,  
                                                        PhotoId,      
                                                        Featured,     
                                                        Gallery,      
                                                        BoldTitle,    
                                                        FeatureCombo, 
                                                        HomePage,     
                                                        Permanent,    
                                                        CopyCount,    
                                                        Message)      
                                    VALUES             (?,?,?,?,?,?,?,?,?,?,?,
                                                        ?,?,?,?,?,?,?,?,?,?,?,
                                                        ?,?,?,?,?,?,?,?,?,?,?,?)});                   



    $sth->bind_param(2, $sth, DBI::SQL_LONGVARCHAR);   # Additional setup for field 2 (Description) as it is a memo field
#    $record->{Description} =~ s/\X0D\x0A/\n/g;        # change mem cr/lf to new lines    
    $record->{Description} =~ s/\n/\x0D\x0A/g;         # change newlines to mem cr/lf combo   
    
    $sth->execute($record->{Title},         
                  $record->{Description},   
                  $record->{IsNew},         
                  $record->{AuctionLoaded}, 
                  $record->{AuctionHeld},   
                  $record->{TradeMeRef},    
                  $record->{DateLoaded},    
                  $record->{TradeMeFees},   
                  $record->{CategoryID},    
                  $record->{MovieRating},   
                  $record->{MovieConfirm},  
                  $record->{StartPrice},    
                  $record->{ReservePrice},  
                  $record->{BuyNowPrice},   
                  $record->{DurationHours}, 
                  $record->{ClosedAuction}, 
                  $record->{AutoExtend},    
                  $record->{Cash},          
                  $record->{Cheque},        
                  $record->{BankDeposit},   
                  $record->{PaymentInfo},   
                  $record->{FreeShippingNZ},
                  $record->{ShippingInfo},  
                  $record->{SafeTrader},    
                  $record->{PictureName},   
                  $record->{PhotoId},       
                  $record->{Featured},      
                  $record->{Gallery},       
                  $record->{BoldTitle},     
                  $record->{FeatureCombo},  
                  $record->{HomePage},      
                  $record->{Permanent},     
                  $record->{CopyCount},     
                  $record->{Message})       
                  || die "Insert_DBAuction - Error executing statement: $DBI::errstr\n";
}

#*********************************************************************************************
# --- DataBase Access Routines --- V1.04 database format ---1
#*********************************************************************************************

#=============================================================================================
# Check if Auction in database
#=============================================================================================

sub is_DBauction_104 {

    my $self = shift;
    my $auctionref = shift;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

#    my $sth = $dbh->prepare("SELECT COUNT(*) FROM Auctions WHERE (((AuctionRef)=?))") 
#          || die "Error preparing statement: $DBI::errstr\n";
    $sth_is_DBauction_104->execute( $auctionref ) 
          || die "Error exexecuting statement: $DBI::errstr\n";
          
    my $found=$sth_is_DBauction_104->fetchrow_array;

    return $found;
}

#=============================================================================================
# Add Auction to Database
# Update the Auctions databaSe (usually with the TradeMe details confirmed via email)
#=============================================================================================

sub insert_DBauction_104 {

    my $self = shift;
    my $input = {@_};
    my $record;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    $self->clear_err_structure();

    # Set default values for new record
    # Key value AuctionKey is defined as Autonumber and will be generated by the database
    
    $record->{ Title                }   = ""            ;               
    $record->{ Description          }   = ""            ;               
    $record->{ ProductType          }   = ""            ;               
    $record->{ ProductCode          }   = ""            ;               
    $record->{ Held                 }   = 0             ;                
    $record->{ AuctionStatus        }   = ""            ;               
    $record->{ AuctionCycle         }   = ""            ;               
    $record->{ RelistStatus         }   = 0             ;               
    $record->{ AuctionSold          }   = 0             ;               
    $record->{ StockOnHand          }   = 0             ;                
    $record->{ RelistCount          }   = 0             ;                
    $record->{ NotifyWatchers       }   = 0             ;                
    $record->{ UseTemplate          }   = 0             ;                
    $record->{ TemplateKey          }   = 0             ;                
    $record->{ AuctionRef           }   = ""            ;               
    $record->{ SellerRef            }   = ""            ;               
    $record->{ DateLoaded           }   = "01/01/2000"  ;     
    $record->{ CloseDate            }   = "01/01/2000"  ;     
    $record->{ CloseTime            }   = "00:00:01"    ;       
    $record->{ Category             }   = ""            ;               
    $record->{ MovieConfirm         }   = 0             ;                
    $record->{ MovieRating          }   = 0             ;                
    $record->{ AttributeCategory    }   = 0             ;               
    $record->{ AttributeName        }   = ""            ;               
    $record->{ AttributeValue       }   = ""            ;               
    $record->{ TMATT104             }   = ""            ;               
    $record->{ TMATT104_2           }   = ""            ;               
    $record->{ TMATT106             }   = ""            ;               
    $record->{ TMATT106_2           }   = ""            ;               
    $record->{ TMATT108             }   = ""            ;               
    $record->{ TMATT108_2           }   = ""            ;               
    $record->{ TMATT111             }   = ""            ;               
    $record->{ TMATT112             }   = ""            ;               
    $record->{ TMATT115             }   = ""            ;               
    $record->{ TMATT117             }   = ""            ;               
    $record->{ TMATT118             }   = ""            ;               
    $record->{ IsNew                }   = 0             ;                
    $record->{ TMBuyerEmail         }   = 0             ;                
    $record->{ StartPrice           }   = 0             ;                
    $record->{ ReservePrice         }   = 0             ;                
    $record->{ BuyNowPrice          }   = 0             ;                
    $record->{ DurationHours        }   = 0             ;                
    $record->{ ClosedAuction        }   = 0             ;                
    $record->{ AutoExtend           }   = 0             ;                
    $record->{ Cash                 }   = 0             ;                
    $record->{ Cheque               }   = 0             ;                
    $record->{ BankDeposit          }   = 0             ;                
    $record->{ PaymentInfo          }   = ""            ;               
    $record->{ FreeShippingNZ       }   = 0             ;                
    $record->{ ShippingInfo         }   = ""            ;               
    $record->{ SafeTrader           }   = 0             ;                
    $record->{ Featured             }   = 0             ;                
    $record->{ Gallery              }   = 0             ;                
    $record->{ BoldTitle            }   = 0             ;                
    $record->{ FeatureCombo         }   = 0             ;                
    $record->{ HomePage             }   = 0             ;                
    $record->{ CopyCount            }   = 1             ;                
    $record->{ Message              }   = ""            ;               
    $record->{ PictureKey1          }   = 0             ;                
    $record->{ PictureKey2          }   = 0             ;                
    $record->{ PictureKey3          }   = 0             ;                
    $record->{ AuctionSite          }   = ""            ;               
    

    # Read through the input values and alter the corresponding fields in the "Record" hash

    while ((my $key, my $value) = each(%{$input})) {
            $record->{$key} = $value;
    }

    # insert the updated record into the database

    my $sth = $dbh->prepare( qq { INSERT INTO Auctions (Title               ,     
                                                        Description         ,     
                                                        ProductType         ,                
                                                        ProductCode         ,                
                                                        Held                ,                
                                                        AuctionCycle        ,
                                                        AuctionStatus       ,
                                                        StockOnHand         ,
                                                        RelistStatus        ,                
                                                        AuctionSold         ,                
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
                                                        IsNew               ,                
                                                        TMBuyerEmail        ,                
                                                        StartPrice          ,                
                                                        ReservePrice        ,                
                                                        BuyNowPrice         ,                
                                                        DurationHours       ,                
                                                        ClosedAuction       ,                
                                                        AutoExtend          ,                
                                                        Cash                ,                
                                                        Cheque              ,                
                                                        BankDeposit         ,                
                                                        PaymentInfo         ,                
                                                        FreeShippingNZ      ,                
                                                        ShippingInfo        ,                
                                                        SafeTrader          ,                
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
                                                        AuctionSite         )                     
                                    VALUES            ( ?,?,?,?,?,?,?,?,?,?,     
                                                        ?,?,?,?,?,?,?,?,?,?,
                                                        ?,?,?,?,?,?,?,?,?,?,
                                                        ?,?,?,?,?,?,?,?,?,?,
                                                        ?,?,?,?,?,?,?,?,?,?,
                                                        ?,?,?,?,?,?,?,?,?,?,?,? ) } );



    $sth->bind_param(2, $sth, DBI::SQL_LONGVARCHAR);   # Additional setup for field 2 (Description) as it is a memo field
#    $record->{Description} =~ s/\x0D\x0A/\n/g;        # change mem cr/lf to new lines    
    $record->{Description} =~ s/\n/\x0D\x0A/g;         # change newlines to mem cr/lf combo   
    
    $sth->execute( "$record->{ Title                }",           
                   "$record->{ Description          }",          
                   "$record->{ ProductType          }",          
                   "$record->{ ProductCode          }",          
                    $record->{ Held                 },
                   "$record->{ AuctionCycle         }",            
                   "$record->{ AuctionStatus        }",            
                    $record->{ StockOnHand          },            
                    $record->{ RelistStatus         },            
                    $record->{ AuctionSold          },            
                    $record->{ RelistCount          },            
                    $record->{ NotifyWatchers       },            
                    $record->{ UseTemplate          },            
                    $record->{ TemplateKey          },            
                   "$record->{ AuctionRef           }",
                   "$record->{ SellerRef            }",
                   "$record->{ DateLoaded           }",
                   "$record->{ CloseDate            }",
                   "$record->{ CloseTime            }",
                   "$record->{ Category             }",               
                    $record->{ MovieRating          },              
                    $record->{ MovieConfirm         },              
                    $record->{ AttributeCategory    },              
                   "$record->{ AttributeName        }",              
                   "$record->{ AttributeValue       }",              
                   "$record->{ TMATT104             }",              
                   "$record->{ TMATT104_2           }",              
                   "$record->{ TMATT106             }",              
                   "$record->{ TMATT106_2           }",              
                   "$record->{ TMATT108             }",              
                   "$record->{ TMATT108_2           }",              
                   "$record->{ TMATT111             }",              
                   "$record->{ TMATT112             }",              
                   "$record->{ TMATT115             }",              
                   "$record->{ TMATT117             }",              
                   "$record->{ TMATT118             }",              
                    $record->{ IsNew                },              
                    $record->{ TMBuyerEmail         },              
                    $record->{ StartPrice           },              
                    $record->{ ReservePrice         },                
                    $record->{ BuyNowPrice          },              
                    $record->{ DurationHours        },              
                    $record->{ ClosedAuction        },              
                    $record->{ AutoExtend           },              
                    $record->{ Cash                 },              
                    $record->{ Cheque               },              
                    $record->{ BankDeposit          },              
                   "$record->{ PaymentInfo          }",              
                    $record->{ FreeShippingNZ       },              
                   "$record->{ ShippingInfo         }",              
                    $record->{ SafeTrader           },              
                    $record->{ Featured             },              
                    $record->{ Gallery              },              
                    $record->{ BoldTitle            },              
                    $record->{ FeatureCombo         },              
                    $record->{ HomePage             },              
                    $record->{ CopyCount            },              
                   "$record->{ Message              }",              
                    $record->{ PictureKey1          },              
                    $record->{ PictureKey2          },              
                    $record->{ PictureKey3          },              
                   "$record->{ AuctionSite          }")              
                    || die "Insert_DBAuction_104 - Error executing statement: $DBI::errstr\n";
}

#=============================================================================================
# Method    : get_last_auction_key    
# Added     : 01/08/06
# Input     : 
# Returns   : Long Integer
#
#=============================================================================================

sub get_last_auction_key {

    my $self        =   shift;
    my $lastkey;
    
    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    # Get the current highest Auction key value

    my $SQL =  qq { SELECT MAX(AuctionKey) FROM Auctions };
    my $sth = $dbh->prepare($SQL);

    $sth->execute();

    my @data = $sth->fetchrow_array();

    $sth->finish;

    # If there are no records in the table element 0 will be undefined, otherwise it will contain
    # the most recently used index key (that's the the theory anyway)
    
    if ( defined ( $data[0] ) ) {
        $lastkey = $data[0];
    }
    else {
        $lastkey = 0;
    }
    return $lastkey;

}

#=============================================================================================
# Method    : add_auction_record_202
# Added     : 31/07/05
# Input     : Hash containg filed/value pairs
# Returns   : Key of new record
#
# Add an Auction Record to the databaSe 
#=============================================================================================

sub add_auction_record_202 {

    my $self = shift;
    my $input = {@_};
    my $record;
    my $lastkey;
    my $newkey;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    $self->clear_err_structure();

    # Store the current highest key value

    $lastkey = $self->get_last_auction_key();

    # Set default values for new record
    # Key value AuctionKey is defined as Autonumber and will be generated by the database
    
    $record->{ Title                }   = ""            ;               
    $record->{ Subtitle             }   = ""            ;               
    $record->{ Description          }   = ""            ;               
    $record->{ ProductType          }   = ""            ;               
    $record->{ ProductCode          }   = ""            ;               
    $record->{ ProductCode2         }   = ""            ;               
    $record->{ SupplierRef          }   = ""            ;               
    $record->{ LoadSequence         }   = 0             ;                
    $record->{ Held                 }   = 0             ;                
    $record->{ AuctionCycle         }   = ""            ;               
    $record->{ AuctionStatus        }   = ""            ;               
    $record->{ RelistStatus         }   = 0             ;               
    $record->{ AuctionSold          }   = 0             ;               
    $record->{ StockOnHand          }   = 0             ;                
    $record->{ RelistCount          }   = 0             ;                
    $record->{ NotifyWatchers       }   = 0             ;                
    $record->{ UseTemplate          }   = 0             ;                
    $record->{ TemplateKey          }   = 0             ;                
    $record->{ AuctionRef           }   = ""            ;               
    $record->{ SellerRef            }   = ""            ;               
    $record->{ DateLoaded           }   = "01/01/2000"  ;     
    $record->{ CloseDate            }   = "01/01/2000"  ;     
    $record->{ CloseTime            }   = "00:00:01"    ;       
    $record->{ Category             }   = ""            ;               
    $record->{ MovieRating          }   = 0             ;                
    $record->{ MovieConfirm         }   = 0             ;                
    $record->{ AttributeCategory    }   = 0             ;               
    $record->{ AttributeName        }   = ""            ;               
    $record->{ AttributeValue       }   = ""            ;               
    $record->{ TMATT038             }   = ""            ;               
    $record->{ TMATT104             }   = ""            ;               
    $record->{ TMATT104_2           }   = ""            ;               
    $record->{ TMATT106             }   = ""            ;               
    $record->{ TMATT106_2           }   = ""            ;               
    $record->{ TMATT108             }   = ""            ;               
    $record->{ TMATT108_2           }   = ""            ;               
    $record->{ TMATT111             }   = ""            ;               
    $record->{ TMATT112             }   = ""            ;               
    $record->{ TMATT115             }   = ""            ;               
    $record->{ TMATT117             }   = ""            ;               
    $record->{ TMATT118             }   = ""            ;               
    $record->{ TMATT163             }   = ""            ;               
    $record->{ TMATT164             }   = ""            ;               
    $record->{ IsNew                }   = 0             ;                
    $record->{ TMBuyerEmail         }   = 0             ;                
    $record->{ StartPrice           }   = 0             ;                
    $record->{ ReservePrice         }   = 0             ;                
    $record->{ BuyNowPrice          }   = 0             ;                
    $record->{ EndType              }   = ""            ;                
    $record->{ DurationHours        }   = 0             ;                
    $record->{ EndDays              }   = 0             ;                
    $record->{ EndTime              }   = 0             ;                
    $record->{ ClosedAuction        }   = 0             ;                
    $record->{ BankDeposit          }   = 0             ;                
    $record->{ CreditCard           }   = 0             ;                
    $record->{ CashOnPickup         }   = 0             ;                
    $record->{ EFTPOS               }   = 0             ;                
    $record->{ Quickpay             }   = 0             ;                
    $record->{ AgreePayMethod       }   = 0             ;                
    $record->{ SafeTrader           }   = 0             ;                
    $record->{ PaymentInfo          }   = ""            ;               
    $record->{ FreeShippingNZ       }   = 0             ;                
    $record->{ ShippingInfo         }   = ""            ;               
    $record->{ PickupOption         }   = 0             ;                
    $record->{ ShippingOption       }   = 0             ;                
    $record->{ Featured             }   = 0             ;                
    $record->{ Gallery              }   = 0             ;                
    $record->{ BoldTitle            }   = 0             ;                
    $record->{ FeatureCombo         }   = 0             ;                
    $record->{ HomePage             }   = 0             ;                
    $record->{ CopyCount            }   = 1             ;                
    $record->{ Message              }   = ""            ;               
    $record->{ PictureKey1          }   = 0             ;                
    $record->{ PictureKey2          }   = 0             ;                
    $record->{ PictureKey3          }   = 0             ;                
    $record->{ AuctionSite          }   = ""            ;               
    $record->{ UserDefined01        }   = ""            ;               
    $record->{ UserDefined02        }   = ""            ;               
    $record->{ UserDefined03        }   = ""            ;               
    $record->{ UserDefined04        }   = ""            ;               
    $record->{ UserDefined05        }   = ""            ;               
    $record->{ UserDefined06        }   = ""            ;               
    $record->{ UserDefined07        }   = ""            ;               
    $record->{ UserDefined08        }   = ""            ;               
    $record->{ UserDefined09        }   = ""            ;               
    $record->{ UserDefined10        }   = ""            ;               
    $record->{ UserStatus           }   = ""            ;               
    $record->{ UserNotes            }   = ""            ;               
    $record->{ OfferPrice           }   = 0             ;               
    $record->{ OfferProcessed       }   = 0             ;               
    $record->{ SaleType             }   = ""            ;               

    # Read through the input values and alter the corresponding fields in the "Record" hash

    while ( ( my $key, my $value ) = each( %{ $input } ) ) {
            $record->{ $key } = $value;
    }

    # Create a fake key, save the old product code and set the product code to the generated key
 
    my $keygen  = "##-".rand;
    my $savprod = $record->{ ProductCode };
    $record->{ ProductCode }   = $keygen;

    # Prepare the SQL statement

    my $sth = $dbh->prepare( qq {
        INSERT INTO     Auctions            (
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
                        ?                    )});

    $sth->bind_param( 3, $sth, DBI::SQL_LONGVARCHAR);   # Additional setup for field 3  (Description) as it is a memo field
    $sth->bind_param(86, $sth, DBI::SQL_LONGVARCHAR);   # Additional setup for field 86 (Usernotes) as it is a memo field
    
    $sth->execute(                                     
                   "$record->{ Title                }", 
                   "$record->{ Subtitle             }", 
                   "$record->{ Description          }",
                   "$record->{ ProductType          }",
                   "$record->{ ProductCode          }",
                   "$record->{ ProductCode2         }",
                   "$record->{ SupplierRef          }",
                    $record->{ LoadSequence         }, 
                    $record->{ Held                 }, 
                   "$record->{ AuctionCycle         }",  
                   "$record->{ AuctionStatus        }",  
                    $record->{ RelistStatus         },  
                    $record->{ AuctionSold          },  
                    $record->{ StockOnHand          },  
                    $record->{ RelistCount          },  
                    $record->{ NotifyWatchers       },  
                    $record->{ UseTemplate          },  
                    $record->{ TemplateKey          },  
                   "$record->{ AuctionRef           }",
                   "$record->{ SellerRef            }",
                   "$record->{ DateLoaded           }",
                   "$record->{ CloseDate            }",
                   "$record->{ CloseTime            }",
                   "$record->{ Category             }",     
                    $record->{ MovieRating          },    
                    $record->{ MovieConfirm         },    
                    $record->{ AttributeCategory    },    
                   "$record->{ AttributeName        }",    
                   "$record->{ AttributeValue       }",    
                   "$record->{ TMATT038             }",    
                   "$record->{ TMATT104             }",    
                   "$record->{ TMATT104_2           }",    
                   "$record->{ TMATT106             }",    
                   "$record->{ TMATT106_2           }",    
                   "$record->{ TMATT108             }",    
                   "$record->{ TMATT108_2           }",    
                   "$record->{ TMATT111             }",    
                   "$record->{ TMATT112             }",    
                   "$record->{ TMATT115             }",    
                   "$record->{ TMATT117             }",    
                   "$record->{ TMATT118             }",    
                   "$record->{ TMATT163             }",    
                   "$record->{ TMATT164             }",    
                    $record->{ IsNew                },    
                    $record->{ TMBuyerEmail         },    
                    $record->{ StartPrice           },    
                    $record->{ ReservePrice         },      
                    $record->{ BuyNowPrice          },    
                   "$record->{ EndType              }",    
                    $record->{ DurationHours        },    
                    $record->{ EndDays              },    
                    $record->{ EndTime              },    
                    $record->{ ClosedAuction        },    
                    $record->{ BankDeposit          },    
                    $record->{ CreditCard           },    
                    $record->{ CashOnPickup         },    
                    $record->{ EFTPOS               },    
                    $record->{ Quickpay             },    
                    $record->{ AgreePayMethod       },    
                    $record->{ SafeTrader           },    
                   "$record->{ PaymentInfo          }",    
                    $record->{ FreeShippingNZ       },    
                   "$record->{ ShippingInfo         }",    
                    $record->{ PickupOption         },    
                    $record->{ ShippingOption       },    
                    $record->{ Featured             },    
                    $record->{ Gallery              },    
                    $record->{ BoldTitle            },    
                    $record->{ FeatureCombo         },    
                    $record->{ HomePage             },    
                    $record->{ CopyCount            },    
                   "$record->{ Message              }",    
                    $record->{ PictureKey1          },    
                    $record->{ PictureKey2          },    
                    $record->{ PictureKey3          },    
                   "$record->{ AuctionSite          }",
                   "$record->{ UserDefined01        }",
                   "$record->{ UserDefined02        }",
                   "$record->{ UserDefined03        }",
                   "$record->{ UserDefined04        }",
                   "$record->{ UserDefined05        }",
                   "$record->{ UserDefined06        }",
                   "$record->{ UserDefined07        }",
                   "$record->{ UserDefined08        }",
                   "$record->{ UserDefined09        }",
                   "$record->{ UserDefined10        }",
                   "$record->{ UserStatus           }",
                   "$record->{ UserNotes            }",
                    $record->{ OfferPrice           },
                    $record->{ OfferProcessed       },
                   "$record->{ SaleType             }")

                    || die "add_auction_record_202 - Error executing statement: $DBI::errstr\n";
                    
    $sth->finish;

    # retrieve the key for the fake product code - should be key of record just added

    my $rcdkey = $self->get_auction_key_by_productcode( $keygen );

    # Store the current highest key value - should also be key of record just added

    $newkey = $self->get_last_auction_key();
    
    # Check that newest key equals the key retrieved using the fake product code
    
    if ( $newkey ne $rcdkey ) {
        $self->update_log("Possible Integrity error adding record to database");
        $self->update_log("Error occurred in method ADD_NEW_RECORD_202");
        $self->update_log("Highest key before insert : ".$lastkey);
        $self->update_log("Highest key after insert  : ".$newkey);
        $self->update_log("Highest key after insert  : ".$newkey);
        $self->update_log("Retrieved Key after insert: ".$rcdkey);

        while( (my $key, my $value) = each(%$record) ) {
            $self->update_log("$key \t:\t $value");
        }
    }

    # Update the record with the correct product code (the saved value)

    $self->update_auction_record(
        AuctionKey          =>  $rcdkey    ,
        ProductCode         =>  $savprod   ,
    );
    
    return $rcdkey;
}

#=============================================================================================
# Method    : add_auction_record_201
# Added     : 31/07/05
# Input     : Hash containg filed/value pairs
# Returns   : Key of new record
#
# Add an Auction Record to the databaSe 
#=============================================================================================

sub add_auction_record_201 {

    my $self = shift;
    my $input = {@_};
    my $record;
    my $lastkey;
    my $newkey;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    $self->clear_err_structure();

    # Store the current highest key value

    $lastkey = $self->get_last_auction_key();

    # Set default values for new record
    # Key value AuctionKey is defined as Autonumber and will be generated by the database
    
    $record->{ Title                }   = ""            ;               
    $record->{ Subtitle             }   = ""            ;               
    $record->{ Description          }   = ""            ;               
    $record->{ ProductType          }   = ""            ;               
    $record->{ ProductCode          }   = ""            ;               
    $record->{ ProductCode2         }   = ""            ;               
    $record->{ SupplierRef          }   = ""            ;               
    $record->{ LoadSequence         }   = 0             ;                
    $record->{ Held                 }   = 0             ;                
    $record->{ AuctionCycle         }   = ""            ;               
    $record->{ AuctionStatus        }   = ""            ;               
    $record->{ RelistStatus         }   = 0             ;               
    $record->{ AuctionSold          }   = 0             ;               
    $record->{ StockOnHand          }   = 0             ;                
    $record->{ RelistCount          }   = 0             ;                
    $record->{ NotifyWatchers       }   = 0             ;                
    $record->{ UseTemplate          }   = 0             ;                
    $record->{ TemplateKey          }   = 0             ;                
    $record->{ AuctionRef           }   = ""            ;               
    $record->{ SellerRef            }   = ""            ;               
    $record->{ DateLoaded           }   = "01/01/2000"  ;     
    $record->{ CloseDate            }   = "01/01/2000"  ;     
    $record->{ CloseTime            }   = "00:00:01"    ;       
    $record->{ Category             }   = ""            ;               
    $record->{ MovieRating          }   = 0             ;                
    $record->{ MovieConfirm         }   = 0             ;                
    $record->{ AttributeCategory    }   = 0             ;               
    $record->{ AttributeName        }   = ""            ;               
    $record->{ AttributeValue       }   = ""            ;               
    $record->{ TMATT104             }   = ""            ;               
    $record->{ TMATT104_2           }   = ""            ;               
    $record->{ TMATT106             }   = ""            ;               
    $record->{ TMATT106_2           }   = ""            ;               
    $record->{ TMATT108             }   = ""            ;               
    $record->{ TMATT108_2           }   = ""            ;               
    $record->{ TMATT111             }   = ""            ;               
    $record->{ TMATT112             }   = ""            ;               
    $record->{ TMATT115             }   = ""            ;               
    $record->{ TMATT117             }   = ""            ;               
    $record->{ TMATT118             }   = ""            ;               
    $record->{ IsNew                }   = 0             ;                
    $record->{ TMBuyerEmail         }   = 0             ;                
    $record->{ StartPrice           }   = 0             ;                
    $record->{ ReservePrice         }   = 0             ;                
    $record->{ BuyNowPrice          }   = 0             ;                
    $record->{ DurationHours        }   = 0             ;                
    $record->{ ClosedAuction        }   = 0             ;                
    $record->{ BankDeposit          }   = 0             ;                
    $record->{ CreditCard           }   = 0             ;                
    $record->{ SafeTrader           }   = 0             ;                
    $record->{ PaymentInfo          }   = ""            ;               
    $record->{ FreeShippingNZ       }   = 0             ;                
    $record->{ ShippingInfo         }   = ""            ;               
    $record->{ PickupOption         }   = 0             ;                
    $record->{ ShippingOption       }   = 0             ;                
    $record->{ Featured             }   = 0             ;                
    $record->{ Gallery              }   = 0             ;                
    $record->{ BoldTitle            }   = 0             ;                
    $record->{ FeatureCombo         }   = 0             ;                
    $record->{ HomePage             }   = 0             ;                
    $record->{ CopyCount            }   = 1             ;                
    $record->{ Message              }   = ""            ;               
    $record->{ PictureKey1          }   = 0             ;                
    $record->{ PictureKey2          }   = 0             ;                
    $record->{ PictureKey3          }   = 0             ;                
    $record->{ AuctionSite          }   = ""            ;               
    $record->{ UserDefined01        }   = ""            ;               
    $record->{ UserDefined02        }   = ""            ;               
    $record->{ UserDefined03        }   = ""            ;               
    $record->{ UserDefined04        }   = ""            ;               
    $record->{ UserDefined05        }   = ""            ;               
    $record->{ UserDefined06        }   = ""            ;               
    $record->{ UserDefined07        }   = ""            ;               
    $record->{ UserDefined08        }   = ""            ;               
    $record->{ UserDefined09        }   = ""            ;               
    $record->{ UserDefined10        }   = ""            ;               
    $record->{ UserStatus           }   = ""            ;               
    $record->{ UserNotes            }   = ""            ;               

    # Read through the input values and alter the corresponding fields in the "Record" hash

    while ((my $key, my $value) = each(%{$input})) {
            $record->{$key} = $value;
    }

    my $sth = $dbh->prepare( qq {
        INSERT INTO     Auctions            (
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
                        IsNew               ,
                        TMBuyerEmail        ,
                        StartPrice          ,
                        ReservePrice        ,
                        BuyNowPrice         ,
                        DurationHours       ,
                        ClosedAuction       ,
                        BankDeposit         ,
                        CreditCard          ,
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
                        UserNotes           )
        VALUES        ( ?,?,?,?,?,?,?,?,?,?,     
                        ?,?,?,?,?,?,?,?,?,?,
                        ?,?,?,?,?,?,?,?,?,?,
                        ?,?,?,?,?,?,?,?,?,?,
                        ?,?,?,?,?,?,?,?,?,?,
                        ?,?,?,?,?,?,?,?,?,?,
                        ?,?,?,?,?,?,?,?,?,?,
                        ?,?,?,?,?,?,?,?     )});

    $sth->bind_param( 3, $sth, DBI::SQL_LONGVARCHAR);   # Additional setup for field 3  (Description) as it is a memo field
    $sth->bind_param(78, $sth, DBI::SQL_LONGVARCHAR);   # Additional setup for field 78 (Usernotes) as it is a memo field
    
    $sth->execute(                                     
                   "$record->{ Title                }", 
                   "$record->{ Subtitle             }", 
                   "$record->{ Description          }",
                   "$record->{ ProductType          }",
                   "$record->{ ProductCode          }",
                   "$record->{ ProductCode2         }",
                   "$record->{ SupplierRef          }",
                    $record->{ LoadSequence         }, 
                    $record->{ Held                 }, 
                   "$record->{ AuctionCycle         }",  
                   "$record->{ AuctionStatus        }",  
                    $record->{ RelistStatus         },  
                    $record->{ AuctionSold          },  
                    $record->{ StockOnHand          },  
                    $record->{ RelistCount          },  
                    $record->{ NotifyWatchers       },  
                    $record->{ UseTemplate          },  
                    $record->{ TemplateKey          },  
                   "$record->{ AuctionRef           }",
                   "$record->{ SellerRef            }",
                   "$record->{ DateLoaded           }",
                   "$record->{ CloseDate            }",
                   "$record->{ CloseTime            }",
                   "$record->{ Category             }",     
                    $record->{ MovieRating          },    
                    $record->{ MovieConfirm         },    
                    $record->{ AttributeCategory    },    
                   "$record->{ AttributeName        }",    
                   "$record->{ AttributeValue       }",    
                   "$record->{ TMATT104             }",    
                   "$record->{ TMATT104_2           }",    
                   "$record->{ TMATT106             }",    
                   "$record->{ TMATT106_2           }",    
                   "$record->{ TMATT108             }",    
                   "$record->{ TMATT108_2           }",    
                   "$record->{ TMATT111             }",    
                   "$record->{ TMATT112             }",    
                   "$record->{ TMATT115             }",    
                   "$record->{ TMATT117             }",    
                   "$record->{ TMATT118             }",    
                    $record->{ IsNew                },    
                    $record->{ TMBuyerEmail         },    
                    $record->{ StartPrice           },    
                    $record->{ ReservePrice         },      
                    $record->{ BuyNowPrice          },    
                    $record->{ DurationHours        },    
                    $record->{ ClosedAuction        },    
                    $record->{ BankDeposit          },    
                    $record->{ CreditCard           },    
                    $record->{ SafeTrader           },    
                   "$record->{ PaymentInfo          }",    
                    $record->{ FreeShippingNZ       },    
                   "$record->{ ShippingInfo         }",    
                    $record->{ PickupOption         },    
                    $record->{ ShippingOption       },    
                    $record->{ Featured             },    
                    $record->{ Gallery              },    
                    $record->{ BoldTitle            },    
                    $record->{ FeatureCombo         },    
                    $record->{ HomePage             },    
                    $record->{ CopyCount            },    
                   "$record->{ Message              }",    
                    $record->{ PictureKey1          },    
                    $record->{ PictureKey2          },    
                    $record->{ PictureKey3          },    
                   "$record->{ AuctionSite          }",
                   "$record->{ UserDefined01        }",
                   "$record->{ UserDefined02        }",
                   "$record->{ UserDefined03        }",
                   "$record->{ UserDefined04        }",
                   "$record->{ UserDefined05        }",
                   "$record->{ UserDefined06        }",
                   "$record->{ UserDefined07        }",
                   "$record->{ UserDefined08        }",
                   "$record->{ UserDefined09        }",
                   "$record->{ UserDefined10        }",
                   "$record->{ UserStatus           }",
                   "$record->{ UserNotes            }")
                    || die "add_auction_record_201 - Error executing statement: $DBI::errstr\n";
                    

    # Store the current highest key value - should be key of record just added

    $newkey = $self->get_last_auction_key();
    
    # Check that newest key is 1 greater than the key before the insert
    
    if ( ( $newkey - $lastkey ) ne 1 ) {
        $self->update_log("Integrity error adding record to database");
        $self->update_log("Error occurred in method ADD_NEW_RECORD-201");
        $self->update_log("Highest key before insert:".$lastkey);
        $self->update_log("Highest key after insert :".$newkey);
        $self->update_log("Input parameters:");

        while( (my $key, my $value) = each(%$record) ) {
            $self->update_log("$key \t:\t $value");
        }
    }
    
    return $newkey;
}

#=============================================================================================
# Method    : delete_auction_record    
# Added     : 10/06/05
# Input     : AuctionKey <fieldname => value>
# Returns   : 
#
# Delete an Auction Record from the databaSe 
#=============================================================================================

sub delete_auction_record {

    my $self = shift;
    my $parms = {@_};
    
    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    $sth_delete_auction_record->execute( $parms->{ AuctionKey } );
}

#=============================================================================================
# Method    : set_auction_closed
# Added     : 03/07/05
# Input     : Auction key
# Returns   : Success or failure
#
# This method ets the Auction Status to 'CLOSED' for the input auction key
#=============================================================================================

sub set_auction_closed {

    my $self = shift;
    my $input = {@_};
    my $record;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    $sth_set_auction_closed->execute($input->{AuctionKey});

}

#=============================================================================================
# Method    : update_auction_record    
# Added     : 31/07/06
# Input     : AuctionKey <fieldname => value>
# Returns   : 
#
# Update the Auctions databaSe (usually with the TradeMe details confirmed via email)
# This function first retrieves the data from the current database record and places data for
# all fields in a hash keyed on field name: $record->{key} = $value. The input data is a hash
# with the field name and data to be updated. Each record in the input hash is matched against
# the corresponding field name in the retrieved record has and the value altered to the input
# value. When all fields in the inpuyt has have been processed the record is written back into
# the database with the updated values
#=============================================================================================

sub update_auction_record {

    my $self = shift;
    my $input = {@_};
    my $record;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    $self->clear_err_structure();

    # Retrieve the current record from the database and update "Record" data-Hash

    $sth_get_auction_record->execute($input->{AuctionKey});

    $record = $sth_get_auction_record->fetchrow_hashref;

    # Read through the input record and alter the corresponding field in the "Record" hash

    while ((my $key, my $value) = each(%{$input})) {

            $record->{$key} = $value;
    }

    if  ( $self->{Debug} ge "2" ) {    
          $self->update_log("Input parameters:");
          while( (my $key, my $value) = each(%$input) ) {
                $self->update_log("$key \t:\t $value");
          }
    }

    # Update the database with the new updated "Record" hash

    # $record->{Description} =~ s/\x0D\x0A/\n/g;        # change mem cr/lf to new lines
    # only do this if Description was passed in from an external call.... but look into it more as to why
    # Seems to add vertical bars (misinterpreting cr/lf and memo fields input I think) when updated & not actually changed

    if ( exists $input->{ Description } ) {
        $record->{ Description } =~ s/\n/\x0D\x0A/g;         # change newlines to mem cr/lf combo   
    }

    if ( exists $input->{ UserNotes } ) {
        $record->{ UserNotes } =~ s/\n/\x0D\x0A/g;         # change newlines to mem cr/lf combo   
    }
    
    if  ( $self->{Debug} ge "2" ) {    
          $self->update_log("Record Values:");
          while( (my $key, my $value) = each(%$record) ) {
                $self->update_log("$key \t:\t $value");
          }
    }
    
    $sth_update_auction_record->execute(
                   "$record->{ Title                }",           
                   "$record->{ Subtitle             }",           
                   "$record->{ Description          }",          
                   "$record->{ ProductType          }",          
                   "$record->{ ProductCode          }",          
                   "$record->{ ProductCode2         }",          
                   "$record->{ SupplierRef          }",          
                    $record->{ LoadSequence         },
                    $record->{ Held                 },
                   "$record->{ AuctionCycle         }",            
                   "$record->{ AuctionStatus        }",            
                    $record->{ RelistStatus         },            
                    $record->{ AuctionSold          },            
                    $record->{ StockOnHand          },            
                    $record->{ RelistCount          },            
                    $record->{ NotifyWatchers       },            
                    $record->{ UseTemplate          },            
                    $record->{ TemplateKey          },            
                   "$record->{ AuctionRef           }",
                   "$record->{ SellerRef            }",
                   "$record->{ DateLoaded           }",
                   "$record->{ CloseDate            }",
                   "$record->{ CloseTime            }",
                   "$record->{ Category             }",               
                    $record->{ MovieRating          },              
                    $record->{ MovieConfirm         },              
                    $record->{ AttributeCategory    },              
                   "$record->{ AttributeName        }",              
                   "$record->{ AttributeValue       }",              
                   "$record->{ TMATT038             }",              
                   "$record->{ TMATT104             }",              
                   "$record->{ TMATT104_2           }",              
                   "$record->{ TMATT106             }",              
                   "$record->{ TMATT106_2           }",              
                   "$record->{ TMATT108             }",              
                   "$record->{ TMATT108_2           }",              
                   "$record->{ TMATT111             }",              
                   "$record->{ TMATT112             }",              
                   "$record->{ TMATT115             }",              
                   "$record->{ TMATT117             }",              
                   "$record->{ TMATT118             }",              
                   "$record->{ TMATT163             }",              
                   "$record->{ TMATT164             }",              
                    $record->{ IsNew                },              
                    $record->{ TMBuyerEmail         },              
                    $record->{ StartPrice           },              
                    $record->{ ReservePrice         },                
                    $record->{ BuyNowPrice          },              
                   "$record->{ EndType              }",              
                    $record->{ DurationHours        },              
                    $record->{ EndDays              },              
                    $record->{ EndTime              },              
                    $record->{ ClosedAuction        },              
                    $record->{ BankDeposit          },              
                    $record->{ CreditCard           },              
                    $record->{ CashOnPickup         },              
                    $record->{ EFTPOS               },              
                    $record->{ Quickpay             },              
                    $record->{ AgreePayMethod       },              
                    $record->{ SafeTrader           },              
                   "$record->{ PaymentInfo          }",              
                    $record->{ FreeShippingNZ       },              
                   "$record->{ ShippingInfo         }",              
                    $record->{ PickupOption         },              
                    $record->{ ShippingOption       },              
                    $record->{ Featured             },              
                    $record->{ Gallery              },              
                    $record->{ BoldTitle            },              
                    $record->{ FeatureCombo         },              
                    $record->{ HomePage             },              
                    $record->{ CopyCount            },              
                   "$record->{ Message              }",              
                    $record->{ PictureKey1          },              
                    $record->{ PictureKey2          },              
                    $record->{ PictureKey3          },              
                   "$record->{ AuctionSite          }",
                   "$record->{ UserDefined01        }",
                   "$record->{ UserDefined02        }",
                   "$record->{ UserDefined03        }",
                   "$record->{ UserDefined04        }",
                   "$record->{ UserDefined05        }",
                   "$record->{ UserDefined06        }",
                   "$record->{ UserDefined07        }",
                   "$record->{ UserDefined08        }",
                   "$record->{ UserDefined09        }",
                   "$record->{ UserDefined10        }",
                   "$record->{ UserStatus           }",
                   "$record->{ UserNotes            }",
                    $record->{ OfferPrice           },
                    $record->{ OfferProcessed       },
                   "$record->{ SaleType             }",
                    $record->{ AuctionKey           })     
                    || die "update_auction_record - Error executing statement: $DBI::errstr\n";
                             
}                            
                                                          
#=============================================================================================
# Method    : copy_auction_record    
# Added     : 31/07/06        
# Input     : AuctionKey     
# Returns   :                
#                            
# This function first retrieves the record identified by the key value passed into the method
# into a hash keyed on field name: $record->{key} = $value. The input data is a hash
# with the field name and data to be updated. Each record in the input hash is matched against
# the corresponding field name in the retrieved record hash and the value altered to the input
# value. When all fields in the input has have been processed the record is written back into
# the database as a NEW record with the copy record values overriden by the input
#=============================================================================================
                             
sub copy_auction_record {    
                             
    my $self = shift;        
    my $input = {@_};        
    my $record;
    
    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    if  ( $self->{Debug} ge "2" ) {    
          $self->update_log("Input parameters:");
          while( (my $key, my $value) = each(%$input) ) {
                $self->update_log("$key \t:\t $value");
          }
    }

    # Retrieve the current record from the database and update "Record" data-Hash
                             
    my $SQL = qq {  SELECT *
                    FROM   Auctions
                    WHERE  AuctionKey  = ? } ;

    my $sth = $dbh->prepare( $SQL );

    $self->{Debug} ge "2" ? ($self->update_log("Executing SQL Statement:\n: $SQL")) : () ;
                             
    $sth->execute( $input->{ AuctionKey } );

    $record = $sth->fetchrow_hashref;
                             
    # Read through the input record and override any matching record field with the 
    # corresponding field in the "input" hash
                             
    while ( ( my $key, my $value ) = each( %{ $input } ) ) {
            $record->{ $key } = $value;
    }
    
    my $newkey = $self->add_auction_record_202(
        Title                   =>   $record->{ Title                },           
        Subtitle                =>   $record->{ Subtitle             },           
        Description             =>   $record->{ Description          },          
        ProductType             =>   $record->{ ProductType          },          
        ProductCode             =>   $record->{ ProductCode          },          
        ProductCode2            =>   $record->{ ProductCode2         },          
        SupplierRef             =>   $record->{ SupplierRef          },          
        LoadSequence            =>   $record->{ LoadSequence         },
        Held                    =>   $record->{ Held                 },
        AuctionCycle            =>   $record->{ AuctionCycle         },            
        AuctionStatus           =>   $record->{ AuctionStatus        },            
        StockOnHand             =>   $record->{ StockOnHand          },            
        RelistStatus            =>   $record->{ RelistStatus         },            
        AuctionSold             =>   $record->{ AuctionSold          },            
        RelistCount             =>   $record->{ RelistCount          },            
        NotifyWatchers          =>   $record->{ NotifyWatchers       },            
        UseTemplate             =>   $record->{ UseTemplate          },            
        TemplateKey             =>   $record->{ TemplateKey          },            
        AuctionRef              =>   $record->{ AuctionRef           },
        SellerRef               =>   $record->{ SellerRef            },
        DateLoaded              =>   $record->{ DateLoaded           },
        CloseDate               =>   $record->{ CloseDate            },
        CloseTime               =>   $record->{ CloseTime            },
        Category                =>   $record->{ Category             },               
        MovieRating             =>   $record->{ MovieRating          },              
        MovieConfirm            =>   $record->{ MovieConfirm         },              
        AttributeCategory       =>   $record->{ AttributeCategory    },              
        AttributeName           =>   $record->{ AttributeName        },              
        AttributeValue          =>   $record->{ AttributeValue       },              
        TMATT038                =>   $record->{ TMATT038             },              
        TMATT104                =>   $record->{ TMATT104             },              
        TMATT104_2              =>   $record->{ TMATT104_2           },              
        TMATT106                =>   $record->{ TMATT106             },              
        TMATT106_2              =>   $record->{ TMATT106_2           },              
        TMATT108                =>   $record->{ TMATT108             },              
        TMATT108_2              =>   $record->{ TMATT108_2           },              
        TMATT111                =>   $record->{ TMATT111             },              
        TMATT112                =>   $record->{ TMATT112             },              
        TMATT115                =>   $record->{ TMATT115             },              
        TMATT117                =>   $record->{ TMATT117             },              
        TMATT118                =>   $record->{ TMATT118             },              
        TMATT163                =>   $record->{ TMATT163             },              
        TMATT164                =>   $record->{ TMATT164             },              
        IsNew                   =>   $record->{ IsNew                },              
        TMBuyerEmail            =>   $record->{ TMBuyerEmail         },              
        StartPrice              =>   $record->{ StartPrice           },              
        ReservePrice            =>   $record->{ ReservePrice         },                
        BuyNowPrice             =>   $record->{ BuyNowPrice          },              
        EndType                 =>   $record->{ EndType              },              
        DurationHours           =>   $record->{ DurationHours        },              
        EndDays                 =>   $record->{ EndDays              },              
        EndTime                 =>   $record->{ EndTime              },              
        ClosedAuction           =>   $record->{ ClosedAuction        },              
        BankDeposit             =>   $record->{ BankDeposit          },              
        CreditCard              =>   $record->{ CreditCard           },              
        CashOnPickup            =>   $record->{ CashOnPickup         },              
        EFTPOS                  =>   $record->{ EFTPOS               },              
        Quickpay                =>   $record->{ Quickpay             },              
        AgreePayMethod          =>   $record->{ AgreePayMethod       },              
        SafeTrader              =>   $record->{ SafeTrader           },              
        PaymentInfo             =>   $record->{ PaymentInfo          },              
        FreeShippingNZ          =>   $record->{ FreeShippingNZ       },              
        ShippingInfo            =>   $record->{ ShippingInfo         },              
        PickupOption            =>   $record->{ PickupOption         },              
        ShippingOption          =>   $record->{ ShippingOption       },              
        Featured                =>   $record->{ Featured             },              
        Gallery                 =>   $record->{ Gallery              },              
        BoldTitle               =>   $record->{ BoldTitle            },              
        FeatureCombo            =>   $record->{ FeatureCombo         },              
        HomePage                =>   $record->{ HomePage             },              
        CopyCount               =>   $record->{ CopyCount            },              
        Message                 =>   $record->{ Message              },              
        PictureKey1             =>   $record->{ PictureKey1          },              
        PictureKey2             =>   $record->{ PictureKey2          },              
        PictureKey3             =>   $record->{ PictureKey3          },              
        AuctionSite             =>   $record->{ AuctionSite          },
        UserDefined01           =>   $record->{ UserDefined01        },
        UserDefined02           =>   $record->{ UserDefined02        },
        UserDefined03           =>   $record->{ UserDefined03        },
        UserDefined04           =>   $record->{ UserDefined04        },
        UserDefined05           =>   $record->{ UserDefined05        },
        UserDefined06           =>   $record->{ UserDefined06        },
        UserDefined07           =>   $record->{ UserDefined07        },
        UserDefined08           =>   $record->{ UserDefined08        },
        UserDefined09           =>   $record->{ UserDefined09        },
        UserDefined10           =>   $record->{ UserDefined10        },
        UserStatus              =>   $record->{ UserStatus           },
        UserNotes               =>   $record->{ UserNotes            },
        OfferPrice              =>   $record->{ OfferPrice           },
        OfferProcessed          =>   $record->{ OfferProcessed       },
        SaleType                =>   $record->{ SaleType             },
    );

    # Add the shipping option data
    
    $self->copy_shipping_details_records(
        FromAuctionKey  =>  $input->{ AuctionKey  }     ,
        ToAuctionKey    =>  $newkey                     ,
    );

    # Add the Auction Images data
    
    $self->copy_auction_image_records(
        FromAuctionKey  =>  $input->{ AuctionKey  }     ,
        ToAuctionKey    =>  $newkey                     ,
    );
    
    return $newkey;
    
}

#=============================================================================================
# Method    : get_auction_record
# Added     : 27/03/05
# Input     : AuctionKey
# Returns   : Hash Reference
#
# This method returns the details for a specific auction record key in a referenced hash
#=============================================================================================

sub get_auction_record {

    my $self = shift;
    my $auctionkey = shift;
    my $record;

    $self->{ Debug } ge "1" ? ( $self->update_log( "Invoked Method: ".( caller(0))[3] ) ) : ();

    $self->clear_err_structure();

    my $sth = $dbh->prepare( qq { SELECT *
                                  FROM   Auctions
                                  WHERE  AuctionKey  = ? });

    $sth->execute( $auctionkey );

    $record = $sth->fetchrow_hashref;

    $sth->finish;

    # If the record was found return the details otherwise populate the error structure

    if ( $record->{ AuctionKey } eq $auctionkey ) {    
        return $record;
    } 
    else {
        $self->{ ErrorStatus    } = "1";
        $self->{ ErrorMessage   } = "Auction key $auctionkey not found in Auction database";
        $self->{ ErrorDetail    } = "";
        return undef;
    }
}

#=============================================================================================
# Method    : get_auction_key
# Added     : 27/03/05
# Input     : AuctionRef
# Returns   : String value
#
# This method returns the auction key for the input auction reference
#=============================================================================================

sub get_auction_key {

    my $self = shift;
    my $auctionref = shift;
    my $key;
    my $record;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;
    
    $self->clear_err_structure();

    $sth_get_auction_key->execute( $auctionref );

    $record = $sth_get_auction_key->fetchrow_hashref;
    $key    = $record->{AuctionKey};

    # If the record was found return the key otherwise populate the error structure

    if     (defined $key) {    

            return $key;
            
    } else {
    
            $self->{ErrorStatus}    = "1";
            $self->{ErrorMessage}   = "Auction reference $auctionref not found in Auction database";
            $self->{ErrorDetail}    = "";
            return undef;
    }
}

#=============================================================================================
# Method    : get_auction_key_by_seller_ref
# Added     : 31/03/06
# Input     : SellerRef
# Returns   : String value
#
# This method returns the auction key for the input sellers reference
#=============================================================================================

sub get_auction_key_by_seller_ref {

    my $self = shift;
    my $sellerref = shift;
    my $key;
    my $record;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;
    
    $self->clear_err_structure();

    my $sth = $dbh->prepare( qq { SELECT AuctionKey
                                  FROM   Auctions
                                  WHERE  SellerRef  = ? });

    $sth->execute($sellerref);

    $record = $sth->fetchrow_hashref;
    $key    = $record->{AuctionKey};

    $sth->finish;

    # If the record was found return the key otherwise populate the error structure

    if     (defined $key) {    

            return $key;
            
    } else {
    
            $self->{ErrorStatus}    = "1";
            $self->{ErrorMessage}   = "Seller reference $sellerref not found in Auction database";
            $self->{ErrorDetail}    = "";
            return undef;
    }
}

#=============================================================================================
# Method    : get_auction_key_by_productcode
# Added     : 31/03/06
# Input     : SellerRef
# Returns   : String value
#
# This method returns the auction key for the product code
#=============================================================================================

sub get_auction_key_by_productcode {

    my $self = shift;
    my $productcode = shift;
    my $key;
    my $record;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;
    
    $self->clear_err_structure();

    my $SQL = qq {
        SELECT AuctionKey
        FROM   Auctions
        WHERE  ProductCode  = ?
    };

    my $sth = $dbh->prepare( $SQL );

    $sth->execute( $productcode );

    $record = $sth->fetchrow_hashref;
    $key    = $record->{ AuctionKey };

    $sth->finish;

    # If the record was found return the key otherwise populate the error structure

    if ( defined $key ) {    
        return $key;
    } 
    else {
        $self->{ ErrorStatus    } = "1";
        $self->{ ErrorMessage   } = "Product Code $productcode not found in Auction database";
        $self->{ ErrorDetail    } = "";
        return undef;
    }
}

#=============================================================================================
# Method    : get_auction_key_byval
# Added     : 13/07/08
# Input     : KeyName, KeyValue
# Returns   : Auction key or undef if not found
#
# This method returns the auction index key for a given record. The search value must be one of 
# SellerRef, ProductCode or ProductCode2
#
# Scripts calling this method must check that the column name is valid
#=============================================================================================

sub get_auction_key_byval {

    my $self     = shift;
    my $keyname  = shift;
    my $keyvalue = shift ;
    my $record;
    my $sth;
    my $SQL;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;
    
    $self->clear_err_structure();

    $SQL = qq {  
        SELECT      AuctionKey
        FROM        Auctions
        WHERE     ( $keyname = '$keyvalue' ) 
    };

    print "get_auction_key_byval SQL: ".$SQL."\n";

    $sth = $dbh->prepare( $SQL );

    $sth->execute();

    $record = $sth->fetchrow_hashref;
    $key    = $record->{ AuctionKey };

    $sth->finish;

    # If the record was found return the key otherwise populate the error structure

    if     ( defined $key ) {    

            return $key;
            
    } else {
    
            $self->{ ErrorStatus    }   = "1";
            $self->{ ErrorMessage   }   = "Auction record not found for value $keyvalue in column $keyname";
            $self->{ ErrorDetail    }   = "";
            return undef;
    }
}

#=============================================================================================
# Method    : is_valid_auctionkey    
# Added     : 14/07/08
# Input     : AuctionKey
# Returns   : Boolean
#
# This method returns true or false based on whether the auction key value passed is valid
# or not. The method tests whether the auction key exists in the Auctions table
#=============================================================================================

sub is_valid_auctionkey {

    my $self        =   shift;
    my $key         =   shift;
    
    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    my $SQL     =   qq {    SELECT        COUNT(*)
                            FROM          Auctions
                            WHERE         AuctionKey = ?      } ;

    my $sth     =   $dbh->prepare( $SQL ) || die "Error preparing statement: $DBI::errstr\n";
    
    $sth->execute( $key ) || die "Error executing statement: $DBI::errstr\n";
    
    my $found   =   $sth->fetchrow_array;

    $sth->finish;

    return $found;

}

#=============================================================================================
# Method    : get_auction_ref
# Added     : 14/07/08
# Input     : AuctionKey
# Returns   : String value reference to Auction reference if it exists. Note that this
#             Value can be Null orempty if the uctionhas not been loaded yet.
#
# The key passed to this method shoudl be validated by the is_valid_key function when
# used by "external" functions
#=============================================================================================

sub get_auction_ref {

    my $self = shift;
    my $key = shift;
    my $ref;
    my $record;
    my $sth;
    my $SQL;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;
    
    $self->clear_err_structure();

    $SQL = qq {  
        SELECT      AuctionRef
        FROM        Auctions
        WHERE     ( AuctionKey = ? ) 
    };

    print "get_auction_ref SQL: ".$SQL."\n";

    $sth = $dbh->prepare( $SQL ) || die "Error preparing statement: $DBI::errstr\n";

    $sth->execute( $key );

    $record = $sth->fetchrow_hashref;
    $ref    = $record->{ AuctionRef };

    $sth->finish;

    # If the record was found return the key otherwise populate the error structure

    if ( defined $ref ) {    
        return $ref;
            
    }
    else {
        $self->{ ErrorStatus    }   = "1";
        $self->{ ErrorMessage   }   = "Auction reference not found for Auction Key $key";
        $self->{ ErrorDetail    }   = "";
        return undef;
    }
}

#=============================================================================================
# Method    : get_auction_status
# Added     : 14/07/08
# Input     : AuctionKey
# Returns   : String value containing uction Status
#
# The key passed to this method should be validated by the is_valid_key function when
# used by "external" functions
#=============================================================================================

sub get_auction_status {

    my $self = shift;
    my $key = shift;
    my $sts;
    my $record;
    my $sth;
    my $SQL;

    $self->{ Debug } ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;
    
    $self->clear_err_structure();

    $SQL = qq {  
        SELECT      AuctionStatus
        FROM        Auctions
        WHERE     ( AuctionKey = ? ) 
    };

    print "get_auction_status SQL: ".$SQL."\n";

    $sth = $dbh->prepare( $SQL ) || die "Error preparing statement: $DBI::errstr\n";

    $sth->execute( $key );

    $record = $sth->fetchrow_hashref;
    $sts    = $record->{ AuctionStatus };

    $sth->finish;

    # If the record was found return the key otherwise populate the error structure

    if ( defined $sts ) {    
        return $sts;
    }
    else {
        $self->{ ErrorStatus    }   = "1";
        $self->{ ErrorMessage   }   = "Auction Status not found for Auction Key $key";
        $self->{ ErrorDetail    }   = "";
        return undef;
    }
}

#=============================================================================================
# Method    : update_stock_on_hand
# Added     : 7/04/05
# Input     :
# Returns   : Array of hash references
#
# This method returns a list of auction records that have not been loaded to Trademe
# Auctions with a status of pending, that are not inlcuded in an auction cycle and are not
# held are returned
#=============================================================================================

sub update_stock_on_hand {

    my $self        = shift;
    my $i           = { @_ };

    $self->{ Debug } ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    $SQL_update_stock_on_hand->execute(
        $i->{ StockOnHand           }   ,
       "$i->{ ProductCode           }"  ,
    ) || die "SQL in ".(caller(0))[3]." failed:\n $DBI::errstr\n";
}

#=============================================================================================
# Method    : get_pending_auctions    
# Added     : 7/04/05
# Input     :
# Returns   : Array of hash references
#
# This method returns a list of auction records that have not been loaded to Trademe
# Auctions with a status of pending, that are not included in an auction cycle and are not
# held are returned
#=============================================================================================

sub get_pending_auctions {

    my $self    = shift;
    my $p       = { @_ };

    my $sortfield;
    my $returndata;

    $self->{Debug} ge "1" ? ($self->update_log( (caller(0))[3] )) : () ;

    $self->clear_err_structure();
    
    if ( $self->{ UseLoadSequenceOrder } ) {
        $sortfield = 'LoadSequence';
    }
    else {
        $sortfield = 'AuctionKey';
    }

    my $SQL = qq {  
        SELECT         *
        FROM          Auctions
        WHERE     ( ( AuctionStatus     = 'PENDING' ) 
        AND         ( AuctionCycle      = ''        )
        AND         ( AuctionSite       = ?         )
        AND         ( Held              = 0         ) )
        ORDER BY    ( $sortfield                    ) 
    };

    $self->{Debug} ge "2" ? ( $self->update_log( "Executing SQL Statement:\n: $SQL" ) ) : () ;
    $self->{Debug} ge "2" ? ( $self->update_log( "AuctionSite: ". $p->{ AuctionSite } ) ) : () ;

    my $sth = $dbh->prepare($SQL);
    
    $sth->execute(
        $p->{ AuctionSite } ,
    );

    $returndata = $sth->fetchall_arrayref({});

    # If the record was found return the details otherwise populate the error structure

    if ( defined($returndata) ) {    
        return $returndata;
    }
    else {
        $self->{ErrorStatus     } = "1";
        $self->{ErrorMessage    } = "No auctions require uploading to ".$p->{ AuctionSite };
        $self->{ErrorDetail     } = "";
        return undef;
    }
}

#=============================================================================================
# Method    : get_closed_auctions    
# Added     : 7/07/05
# Input     :
# Returns   : Array of hash references
#
# This method returns a list of auction records that have not been loaded to Trademe
# Auctions with a status of pending, that are not inlcuded in an auction cycle and are not
# held are returned
#=============================================================================================

sub get_closed_auctions {

    my $self = shift;
    my $sortfield;
    my $returndata;

    $self->{Debug} ge "1" ? ($self->update_log( (caller(0))[3] )) : () ;

    $self->clear_err_structure();
    
    my $SQL = qq {  
        SELECT      *
        FROM        Auctions
        WHERE     ( AuctionStatus    =  'CLOSED' ) 
    };

    $self->{Debug} ge "2" ? ($self->update_log("Executing SQL Statement:\n: $SQL")) : () ;

    my $sth = $dbh->prepare($SQL);
    
    $sth->execute;

    $returndata = $sth->fetchall_arrayref({});

    # If the record was found return the details otherwise populate the error structure

    if     ( defined($returndata) ) {    

            return $returndata;
            
    } else {
    
            $self->{ErrorStatus}    = "1";
            $self->{ErrorMessage}   = "No closed auctions in database";
            $self->{ErrorDetail}    = "";
            return undef;
    }
}

#=============================================================================================
# Method    : get_cycle_auctions    
# Added     : 6/06/05
# Input     : Auction Cycle
# Returns   : Array of hash references
#
# This method returns a list of auction records that have not been loaded to Trademe
# Auctions with a status of pending, that are included in the selected auction cycle and are
# selected held are returned
#=============================================================================================

sub get_cycle_auctions {

    my $self    = shift;
    my $p       = { @_ };

    my $sortfield;
    my $returndata;
    
    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    $self->clear_err_structure();
    
    if ( $self->{ UseLoadSequenceOrder } ) {
        $sortfield = 'LoadSequence';
    }
    else {
        $sortfield = 'AuctionKey';
    }

    my $SQL = qq {
        SELECT      *
        FROM        Auctions
        WHERE   ( ( AuctionStatus   = 'PENDING' ) 
        AND       ( AuctionCycle    = ?         )
        AND       ( AuctionSite     = ?         )
        AND       ( Held            = 0         ) ) 
        ORDER BY  ( $sortfield                  )
    };

    my $sth = $dbh->prepare($SQL);

    $self->{Debug} ge "2" ? ($self->update_log("Derived SQL Statement: $SQL")) : () ;
    
    $sth->execute(
        $p->{ AuctionCycle  } ,
        $p->{ AuctionSite   } ,
    );

    $returndata = $sth->fetchall_arrayref({});

    # If the record was found return the details otherwise populate the error structure

    if     ( defined($returndata) ) {    

            return $returndata;
            
    } else {
    
            $self->{ErrorStatus}    = "1";
            $self->{ErrorMessage}   = "No auctions require uploading to TradeMe";
            $self->{ErrorDetail}    = "";
            return undef;
    }
}

#=============================================================================================
# Method    : get_uploaded_auctions    
# Added     : 28/06/05
# Input     :
# Returns   : Array of hash references
#
# This method returns a list of auction records which have an auction reference
# but are not marked as closed (All records currently meant to be on TradeMe)
# 
# DEPRECATED *** use method: get_open_listings
# 
#=============================================================================================

sub get_uploaded_auctions {

    my $self = shift;
    my $returndata;

    $self->{Debug} ge "1" ? ($self->update_log( (caller(0))[3] )) : () ;

    $self->clear_err_structure();
    
    my $SQL = qq {
 

        SELECT          AuctionKey,
                        AuctionRef                          
        FROM            Auctions
        WHERE       ( ( AuctionRef        <>  ''            ) 
        AND           ( AuctionStatus     <>  'CLOSED'      ) 
        AND           ( AuctionStatus     <>  'RELISTED'    )  
        AND           ( AuctionSite       =   'TRADEME'     ) ) 
    };

    $self->{Debug} ge "2" ? ($self->update_log("Executing SQL Statement:\n: $SQL")) : () ;

    my $sth = $dbh->prepare($SQL);
    
    $sth->execute;

    $returndata = $sth->fetchall_arrayref({});

    # If the record was found return the details otherwise populate the error structure

    if     ( defined($returndata) ) {    

            return $returndata;
            
    } else {
    
            $self->{ErrorStatus}    = "1";
            $self->{ErrorMessage}   = "Loaded auctions not found in database";
            $self->{ErrorDetail}    = "";
            return undef;
    }
}

#=============================================================================================
# Method    : get_open_listings
# Added     : 25/10/09
# Input     :
# Returns   : Array of hash references listing AuctionKey & AuctionRef
#
# This method returns a list of auction records with status CURRENT for the selected Auction
# Site
#=============================================================================================

sub get_open_listings {

    my $self = shift;
    my $p    = { @_ };

    $self->{ Debug } ge "1" ? ( $self->update_log( (caller(0))[3] ) ) : () ;

    $self->clear_err_structure();

    my $SQL = qq {
        SELECT          AuctionKey,
                        AuctionRef                          
        FROM            Auctions
        WHERE       ( ( AuctionRef        <>  ''        ) 
        AND           ( AuctionStatus     =   'CURRENT' ) 
        AND           ( AuctionSite       =   ?         ) ) 
    };

    $self->{Debug} ge "2" ? ($self->update_log("Executing SQL Statement:\n: $SQL")) : () ;

    my $sth = $dbh->prepare( $SQL );
    
    $sth->execute( $p->{ AuctionSite } );

    my $returndata = $sth->fetchall_arrayref({});

    # If the record was found return the details otherwise populate the error structure

    if ( defined( $returndata ) ) {    
        return $returndata;
    } 
    else {
        $self->{ ErrorStatus    }   = "1";
        $self->{ ErrorMessage   }   = "No CURRENT auctions found in database for ".$p->{ AuctionSite };
        $self->{ ErrorDetail    }   = "";
        return undef;
    }
}

#=============================================================================================
# Method    : get_clone_auctions    
# Added     : 25/06/05
# Input     : Cycle name
# Returns   : Array of hash references
#
# This method returns a list of auction records that have a status of "CLONE"
#=============================================================================================

sub get_clone_auctions {

    my $self    = shift;
    my $p       = {@_};

    $self->{ Debug } ge "1" ? ( $self->update_log( ( caller( 0 ) )[3] ) ) : () ;

    $self->clear_err_structure();
    
    if ( not defined $p->{ AuctionCycle  } ) { $p->{ AuctionCycle  }  = ""; }

    my $SQL =  qq { SELECT *
                    FROM          Auctions
                    WHERE     ( ( AuctionStatus    =  'CLONE'  ) 
                    AND         ( AuctionCycle     =  ?        )
                    AND         ( AuctionSite      =  ?        )
                    AND         ( Held             =  0        ) ) };

    $self->{Debug} ge "2" ? ($self->update_log("Executing SQL Statement:\n $SQL")) : () ;

    my $sth = $dbh->prepare( $SQL );
    
    $sth->execute(
        $p->{ AuctionCycle  } ,
        $p->{ AuctionSite   } ,
    );

    my $returndata = $sth->fetchall_arrayref({});
    
}

#=============================================================================================
# Method    : get_standard_relists    
# Added     : 6/06/05
# Input     :
# Returns   : Array of hash references
#
# This method returns a list of auction records that are elegible for relisting
# This function will select the following auctions:
#
# 1. Auctions with a status of UNSOLD, that are have a relist flag of 1 (UNTILSOLD)
# 2. Auctions with a status of UNSOLD, that are have a relist flag of 2 (WHILESTOCK)
#    which have a STOCKONHAND greater than 0
# 3. Auctions with a status of SOLD,   that are have a relist flag of 2 (WHILESTOCK)
#    which have a STOCKONHAND greater than 0
# 4. Auctions with a status of UNSOLD, that are have a relist flag of 3 (PERMANENT)
# 5. Auctions with a status of SOLD,   that are have a relist flag of 3 (PERMANENT)
# 
# Auctions that are HELD or have an AUCTION CYCLE specified will not be selected
#=============================================================================================

sub get_standard_relists {

    my $self = shift;
    my $sortfield;
    my $returndata;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    $self->clear_err_structure();
    
    if     ( $self->{ UseLoadSequenceOrder } ) {
    
             $sortfield = 'LoadSequence';
    } else {
             $sortfield = 'AuctionKey';
    }

    # Relist Statuses
    # 0 = NORELIST
    # 1 = UNTILSOLD
    # 2 = WHILESTOCK
    # 3 = PERMANENT

    my $SQL =  qq { SELECT          *
                    FROM            Auctions
                    WHERE   ( ( (   AuctionStatus   =  'UNSOLD'   ) 
                    AND         (   RelistStatus    =  1          ) 
                    AND         (   Held            =  0          ) 
                    AND         (   AuctionCycle    =  ''         ) )
                    OR        ( (   AuctionStatus   =  'UNSOLD'   ) 
                    AND         (   RelistStatus    =  2          ) 
                    AND         (   StockOnHand     >  0          ) 
                    AND         (   Held            =  0          ) 
                    AND         (   AuctionCycle    =  ''         ) )
                    OR        ( (   AuctionStatus   =  'SOLD'     ) 
                    AND         (   RelistStatus    =  2          ) 
                    AND         (   StockOnHand     >  0          ) 
                    AND         (   Held            =  0          ) 
                    AND         (   AuctionCycle    =  ''         ) )
                    OR        ( (   AuctionStatus   =  'UNSOLD'   ) 
                    AND         (   RelistStatus    =  3          ) 
                    AND         (   Held            =  0          ) 
                    AND         (   AuctionCycle    =  ''         ) ) 
                    OR        ( (   AuctionStatus =  'SOLD'       ) 
                    AND         (   RelistStatus    =  3          ) 
                    AND         (   Held            =  0          ) 
                    AND         (   AuctionCycle    =  ''         ) ) )
                    ORDER BY        $sortfield                    };                     

    my $sth = $dbh->prepare($SQL);

    $self->update_log("Executing SQL Statement:\n $SQL");
    
    $sth->execute;

    $returndata = $sth->fetchall_arrayref({});

    # If the record was found return the details otherwise populate the error structure

    if     ( defined($returndata) ) {    

            return $returndata;
            
    } else {
    
            $self->{ErrorStatus}    = "1";
            $self->{ErrorMessage}   = "No auctions require uploading to TradeMe";
            $self->{ErrorDetail}    = "";
            return undef;
    }
}

#=============================================================================================
# Method    : get_cycle_relists    
# Added     : 6/06/05
# Input     :
# Returns   : Array of hash references
#
# This method returns a list of auction records that are elegible for relisting
# This function will select the following auctions:
#
# 1. Auctions with a status of UNSOLD, that are have a relist flag of 1 (UNTILSOLD)
# 2. Auctions with a status of UNSOLD, that are have a relist flag of 2 (WHILESTOCK)
#    which have a STOCKONHAND greater than 0
# 3. Auctions with a status of SOLD,   that are have a relist flag of 2 (WHILESTOCK)
#    which have a STOCKONHAND greater than 0
# 4. Auctions with a status of UNSOLD, that are have a relist flag of 3 (PERMANENT)
# 5. Auctions with a status of SOLD,   that are have a relist flag of 3 (PERMANENT)
# 
# Only Auctions with an AUCTIONCYCLE equal to the input cycle value will be selected
# Auctions that are HELD will not be selected
#=============================================================================================

sub get_cycle_relists {

    my $self    = shift;
    my $p       = { @_ };
    my $sortfield;
    my $returndata;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    $self->clear_err_structure();
    
    if     ( $self->{ UseLoadSequenceOrder } ) {
    
             $sortfield = 'LoadSequence';
    } else {
             $sortfield = 'AuctionKey';
    }

    # Relist Statuses
    # 0 = NORELIST
    # 1 = UNTILSOLD
    # 2 = WHILESTOCK
    # 3 = PERMANENT

    my $SQL = qq {  SELECT *
                    FROM        Auctions
                    WHERE ( ( ( AuctionStatus =  'UNSOLD'               ) 
                    AND       ( RelistStatus  =  1                      ) 
                    AND       ( Held          =  0                      ) 
                    AND       ( AuctionSite   =  '$p->{ AuctionSite }'  ) 
                    AND       ( AuctionCycle  =  '$p->{ AuctionCycle }' ) )
                    OR      ( ( AuctionStatus =  'UNSOLD'               ) 
                    AND       ( RelistStatus  =  2                      ) 
                    AND       ( StockOnHand   >  0                      ) 
                    AND       ( Held          =  0                      ) 
                    AND       ( AuctionSite   =  '$p->{ AuctionSite }'  ) 
                    AND       ( AuctionCycle  =  '$p->{ AuctionCycle }' ) )
                    OR      ( ( AuctionStatus =  'SOLD'                 ) 
                    AND       ( RelistStatus  =  2                      ) 
                    AND       ( StockOnHand   >  0                      ) 
                    AND       ( Held          =  0                      ) 
                    AND       ( AuctionSite   =  '$p->{ AuctionSite }'  ) 
                    AND       ( AuctionCycle  =  '$p->{ AuctionCycle }' ) )
                    OR      ( ( AuctionStatus =  'UNSOLD'               ) 
                    AND       ( RelistStatus  =  3                      ) 
                    AND       ( Held          =  0                      ) 
                    AND       ( AuctionSite   =  '$p->{ AuctionSite }'  ) 
                    AND       ( AuctionCycle  =  '$p->{ AuctionCycle }' ) )
                    OR      ( ( AuctionStatus =  'SOLD'                 ) 
                    AND       ( RelistStatus  =  3                      ) 
                    AND       ( Held          =  0                      ) 
                    AND       ( AuctionSite   =  '$p->{ AuctionSite }'  ) 
                    AND       ( AuctionCycle  =  '$p->{ AuctionCycle }' ) ) )
                    ORDER BY    $sortfield                              };      

    $self->update_log("Executing SQL Statement:\n $SQL");

    my $sth = $dbh->prepare( $SQL );
    
    $sth->execute;

    $returndata = $sth->fetchall_arrayref({});

    # If the record was found return the details otherwise populate the error structure

    if     ( defined($returndata) ) {    

            return $returndata;
            
    } else {
    
            $self->{ErrorStatus}    = "1";
            $self->{ErrorMessage}   = "No auctions require relisting on TradeMe";
            $self->{ErrorDetail}    = "";
            return undef;
    }
}

#=============================================================================================
# Method    : get_auction_records
# Added     : 7/04/05
# Input     : list of auction keys
# Returns   : Array of hash references
#
# This method returns the details of auctions in the input list if they are not held 
#=============================================================================================

sub get_auction_records {

    my $self = shift;
    my $p = { @_ };
    my $keylist;
    my $sortfield;
    my $returndata;

    $self->{ Debug } ge "1" ? ( $self->update_log( "Invoked Method: ". ( caller( 0 ) )[3] ) ) : () ;

    $self->clear_err_structure();
    
    if ( $self->{ UseLoadSequenceOrder } )  { $sortfield = 'LoadSequence';  }
    else                                    { $sortfield = 'AuctionKey';    }

    #Build a comma separated string of Auction Keys for the SQL statement

    foreach my $item ( @{ $p->{ AuctionKeys } } ) {
        if ( $keylist eq "" ) {
            $keylist = $item;
        }
        else {    
            $keylist = $keylist.", ".$item;
        }    
    }

    my $SQL = qq {
        SELECT *
        FROM         Auctions
        WHERE    ( ( AuctionKey     IN  ( $keylist )    )  
        AND        ( AuctionSite    =   ?               )  
        AND        ( Held           =   0               ) )
        ORDER BY   $sortfield
    };

    $self->update_log( "SQL Statement to Execute:\n $SQL" );

    my $sth = $dbh->prepare( $SQL );

    $sth->execute( $p->{ AuctionSite } );

    $returndata = $sth->fetchall_arrayref( {} );

    # If the record was found return the details otherwise populate the error structure

    if ( defined($returndata) ) {    
        return $returndata;
    } 
    else {
        $self->{ ErrorStatus    } = "1";
        $self->{ ErrorMessage   } = "No auctions require uploading to TradeMe";
        $self->{ ErrorDetail    } = "";
        return undef;
    }
}

#=============================================================================================
# Method    : update_picture_record
# Added     : 30/03/05
# Input     : Photo record key
# Returns   : Hash Reference
#
# This method returns the details for a specific photo record in a referenced hash
#=============================================================================================

sub update_picture_record {

    my $self = shift;
    my $input = {@_};
    my $record;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    # Retrieve the current record from the database and update "Record" data-Hash

    my $sth = $dbh->prepare( qq {
        SELECT *
        FROM   Pictures
        WHERE  PictureKey  = ? 
    } );

    $sth->execute( $input->{ PictureKey } );

    $record = $sth->fetchrow_hashref;

    # Read through the input record and alter the corresponding field in the "Record" hash

    while ( ( my $key, my $value ) = each( %{ $input } ) ) {
        $record->{ $key } = $value;
    }

    # Update the database with the new updated "Record" hash

    $sth = $dbh->prepare( qq {
        UPDATE  Pictures  
        SET     PictureFileName   = ?,
                PhotoId           = ?,
                SellaID           = ?
        WHERE   PictureKey        = ? 
    } )
    || die "Error preparing statement: $DBI::errstr\n";

    $sth->execute(
        "$record->{ PictureFileName  }"   ,   
        "$record->{ PhotoId          }"   ,
        "$record->{ SellaID          }"   ,
         $record->{ PictureKey       }    ,
    )     
    || die "update_picture_record - Error executing statement: $DBI::errstr\n";
}

#=============================================================================================
# Method    : get_picture_record
# Added     : 30/03/05
# Input     : Photo record key
# Returns   : Hash reference
#
# This method returns the details for a specific photo record in a referenced hash
#=============================================================================================

sub get_picture_record {

    my $self = shift;
    my $p = {@_};
    my $record;

    $self->{ Debug } ge "1" ? ($self->update_log( (caller(0))[3] )) : () ;

    $self->clear_err_structure();

    my $SQL =  qq { 
        SELECT *
        FROM   Pictures
        WHERE  PictureKey  = ? 
    };

    $self->{ Debug } ge "1" ? ( $self->update_log( "Executing SQL Statement:".$SQL ) ) : () ;
    $self->{ Debug } ge "1" ? ( $self->update_log( "Selected Picture Key: ".$p->{ PictureKey } ) ) : () ;

    my $sth = $dbh->prepare( $SQL );

    $sth->execute( $p->{ PictureKey } );

    $record = $sth->fetchrow_hashref;

    # If the record was found return the details otherwise populate the error structure

    if ( defined( $record ) ) {

        $self->{ Debug } ge "2" ? ( $self->update_log( "Normal return from get_picture_record" ) ) : () ;
        return $record;
    }
    else {
        $self->{ Debug } ge "2" ? ( $self->update_log( "Abend: picture not found" ) ) : () ;
    
        $self->{ ErrorStatus    }  = "1";
        $self->{ ErrorMessage   }  = "Picture $p->{ PictureKey } not found in Auction database";
        $self->{ ErrorDetail    }  = "";
        return undef;
    }
}

#=============================================================================================
# Method    : get_picture_image_data
# Added     : 30/03/05
# Input     : Photo record key
# Returns   : Hash reference
#
# This method returns the details for a specific photo record in a referenced hash
#=============================================================================================

sub get_picture_image_data {

    my $self = shift;
    my $p = { @_ };
    my $data;

    $self->{ Debug } ge "1" ? ( $self->update_log( ( caller(0) )[3] ) ) : () ;

    $self->clear_err_structure();

    my $SQL =  qq { 
        SELECT ImageData
        FROM   Pictures
        WHERE  PictureKey  = ? 
    };

    $self->{ Debug } ge "1" ? ( $self->update_log( "Executing SQL Statement:".$SQL ) ) : () ;
    $self->{ Debug } ge "1" ? ( $self->update_log( "Selected Picture Key: ".$p->{ PictureKey } ) ) : () ;

    my $sth = $dbh->prepare( $SQL );

    $sth->execute( $p->{ PictureKey } );

    my $rec = $sth->fetchrow_hashref;
    $data   = $rec->{ ImageData };

    # If the record was found return the details otherwise populate the error structure

    if ( length( $data ) > 0 ) {

        $self->{ Debug } ge "2" ? ( $self->update_log( "Image Data content found and returned" ) ) : () ;
        return $data;
    }
    else {
        $self->{ Debug } ge "2" ? ( $self->update_log( "Error: Image data content not found" ) ) : () ;
    
        $self->{ ErrorStatus    }  = "1";
        $self->{ ErrorMessage   }  = "Picture $p->{ PictureKey } not found in Auction database or had no associated image data";
        $self->{ ErrorDetail    }  = "";
        return undef;
    }
}

#=============================================================================================
# Method    : get_TMPhotoId_filename   
# Added     : 12/12/07
# Input     : TradeMe Photo ID
# Returns   : Picture File name or undef
#
# This method returns the primary key for the input picture name otherwise it returned undef
#=============================================================================================

sub get_TMPhotoId_filename {

    my $self    = shift;
    my $PhotoId = shift;
    
    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    # Clear error indicator and error message properties

    $self->clear_err_structure();

    # Create SQL Statement string

    my $SQL = qq {
        SELECT        PictureFileName
        FROM          Pictures
        WHERE         PhotoId          = ?
    };

    my $sth = $dbh->prepare($SQL) || die "Error preparing statement: $DBI::errstr\n";
    
    $sth->execute( "$PhotoId" ) || die "Error exexecuting statement: $DBI::errstr\n";
    
    my $filename = $sth->fetchrow_array;

    $sth->finish;
    
    return $filename;

}

#=============================================================================================
# Method    : get_picture_key   
# Added     : 31/03/05
# Input     : picture file name #
# Returns   : PictureKey (primary key) or undef
#
# This method returns the primary key for the input picture name otherwise it returned undef
#=============================================================================================

sub get_picture_key {

    my $self    = shift;
    my $parms   = {@_};
    
    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    # Clear error indicator and error message properties

    $self->clear_err_structure();

    # Create SQL Statement string

    my $SQL = qq {
        SELECT        PictureKey
        FROM          Pictures
        WHERE         PictureFileName = ?
    };

    my $sth = $dbh->prepare( $SQL ) || die "Error preparing statement: $DBI::errstr\n";
    
    $sth->execute( "$parms->{ PictureFileName }" ) || die "Error exexecuting statement: $DBI::errstr\n";
    
    my $PictureKey = $sth->fetchrow_array;

    $sth->finish;
    
    return $PictureKey;
}

#=============================================================================================
# Method    : add_picture_record
# Added     : 31/03/06
# Input     : hash containing field values
# Returns   : 
#
# This function will add a record to the Pictures table
#=============================================================================================

sub add_picture_record {

    my $self    = shift;
    my $parms   = {@_};
    my $record;
    
    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    # Clear error indicator and error message properties

    $self->clear_err_structure();

    # Set default values for new record
    # Key value AuctionKey is defined as Autonumber and will be generated by the database
    
    $record->{ PictureFileName } = ""  ;               

    # Read through the input values and alter the corresponding fields in the "Record" hash

    while ( ( my $key, my $value ) = each( %{ $parms } ) ) {
            $record->{ $key } = $value;
    }

    # Create SQL Statement string

    my $SQLStmt = qq {
        INSERT INTO Pictures 
                  ( PictureFileName )
        VALUES    ( ?               )
    } ;

    my $sth = $dbh->prepare($SQLStmt) || die "Error preparing statement: $DBI::errstr\n";

    # Execute the SQL Statement           
    
    $sth->execute(  
        "$record->{ PictureFileName     }"    ) 
         || die .((caller(0))[3])." - Error executing statement: $DBI::errstr\n";

    $sth->finish;

    # Return the key of the newly added Picture Record

    return $self->get_picture_key( $record->{ PictureFileName } );
}

#=============================================================================================
# Method    : get_all_pictures
# Added     : 8/06/05
# Input     :
# Returns   : Array of hash references
#
# This method returns a list of all photo records
#=============================================================================================

sub get_all_pictures {

    my $self = shift;
    my $returndata;

    $self->{Debug} ge "1" ? ($self->update_log( (caller(0))[3] )) : () ;

    $self->clear_err_structure();

    my $sth = $dbh->prepare( qq { SELECT * FROM   Pictures });
    
    $sth->execute;

    $returndata = $sth->fetchall_arrayref({});

    # If the record was found return the details otherwise populate the error structure

    if     ( defined($returndata) ) {    

            return $returndata;
            
    } else {
    
            $self->{ErrorStatus}    = "1";
            $self->{ErrorMessage}   = "problem accessing picture table in Auctionitis database";
            $self->{ErrorDetail}    = "";
            return undef;
    }
}

#=============================================================================================
# Method    : get_picture_records
# Added     : 8/06/05
# Input     :
# Returns   : Array of hash references
#
# This method returns a list of all photo records in the requested list
#=============================================================================================

sub get_picture_records {

    my $self = shift;
    my $keylist;
    my $returndata;

    $self->{Debug} ge "1" ? ($self->update_log( (caller(0))[3] )) : () ;

    $self->clear_err_structure();
    
    foreach my $item (@_) {

        if     ($keylist eq "") {
                $keylist = $item;
        } else {    
                $keylist = $keylist.", ".$item;
        }    
    }

    my $SQL =  qq { SELECT * 
                    FROM          Pictures
                    WHERE       ( PictureKey IN ( $keylist ) ) };

    $self->{Debug} ge "1" ? ($self->update_log("SQL Statement: $SQL")) : () ;

    my $sth = $dbh->prepare($SQL);
    
    $sth->execute;

    $returndata = $sth->fetchall_arrayref({});

    # If the record was found return the details otherwise populate the error structure

    if     ( defined($returndata) ) {    

            return $returndata;
            
    } else {
    
            $self->{ErrorStatus}    = "1";
            $self->{ErrorMessage}   = "problem accessing picture table in Auctionitis database";
            $self->{ErrorDetail}    = "";
            return undef;
    }
}

#=============================================================================================
# Method    : get_unloaded_pictures
# Added     : 6/04/05
# Input     :
# Returns   : Array of hash references
#
# This method returns a list of photo records that have not been loaded to Trademe
#=============================================================================================

sub get_unloaded_pictures {

    my $self = shift;
    my $p    = {@_};

    my $picidfield;
    my $returndata;

    $self->{Debug} ge "1" ? ($self->update_log( ( caller(0) )[3] ) ) : () ;

    $self->clear_err_structure();

    # Select the Picture ID field based on the Auction Site Parameter

    if ( $p->{ AuctionSite } eq "TRADEME" ) {
        $picidfield = "PhotoId";
    }
    elsif ( $p->{ AuctionSite } eq "SELLA" ) {
        $picidfield = "SellaID";
    }

    # Select picture keys in Pictures table from selection auction list

    my $SQL =  qq {
        SELECT DISTINCT Pictures.*
        FROM            Auctions 
        INNER JOIN    ( AuctionImages 
        INNER JOIN      Pictures 
        ON              AuctionImages.PictureKey    = Pictures.PictureKey       )
        ON              Auctions.AuctionKey         = AuctionImages.AuctionKey 
        WHERE       ( ( Auctions.AuctionSite        = '$p->{ AuctionSite }'     )  
        AND           ( Auctions.Held =  0                                      )
        AND         ( ( Pictures.$picidfield IS NULL                            ) 
        OR            ( Pictures.$picidfield = ''                               ) ) )
    };

    $self->{ Debug } ge "1" ? ( $self->update_log( "SQL Statement: $SQL" ) ) : () ;

    my $sth = $dbh->prepare( $SQL );

    $sth->execute();

    $returndata = $sth->fetchall_arrayref({});

    # If the record was found return the details otherwise populate the error structure

    if ( defined( $returndata ) ) {    
        return $returndata;
    } 
    else {
        $self->{ ErrorStatus    } = "1";
        $self->{ ErrorMessage   } = "No pictures require uploading to ".$p->{ AuctionSite };
        $self->{ ErrorDetail    } = "";
        return undef;
    }
}

#=============================================================================================
# Method    : get_selected_unloaded_pictures
# Added     : 16/07/05
# Input     : Array of auction numbers
# Returns   : array of picture record hashes
#
# This method returns a list of photo records that have not been uploaded to Trademe
#=============================================================================================

sub get_selected_unloaded_pictures {

    my $self = shift;
    my $p    = { @_ };

    my $keylist;
    my $piclist;
    my $picidfield;
    my $returndata;

    $self->{ Debug}  ge "1" ? ( $self->update_log( ( caller(0) )[3] ) ) : () ;

    $self->clear_err_structure();

    # Build the auction key selection list from the input array

    foreach my $item ( @{ $p->{ AuctionKeys } } ) {
        if ( $keylist eq "" ) {
            $keylist = $item;
        }
        else {    
            $keylist = $keylist.", ".$item;
        }    
    }

    # Select the Picture ID field based on the Auction Site Parameter

    if ( $p->{ AuctionSite } eq "TRADEME" ) {
        $picidfield = "PhotoId";
    }
    elsif ( $p->{ AuctionSite } eq "SELLA" ) {
        $picidfield = "SellaID";
    }

    # Select picture keys in Pictures table from selection auction list

    my $SQL =  qq {

        SELECT DISTINCT Pictures.*
        FROM            Auctions 
        INNER JOIN    ( AuctionImages 
        INNER JOIN      Pictures 
        ON              AuctionImages.PictureKey    = Pictures.PictureKey )
        ON              Auctions.AuctionKey         = AuctionImages.AuctionKey 
        WHERE       ( ( Auctions.AuctionKey IN ( $keylist ) )  
        AND           ( Auctions.Held =  0                  )
        AND         ( ( Pictures.$picidfield IS NULL        ) 
        OR            ( Pictures.$picidfield = ''           ) ) )
    };

    $self->{ Debug } ge "1" ? ( $self->update_log( "Executing SQL Statement:\n".$SQL ) ) : () ;

    my $sth = $dbh->prepare( $SQL );

    $sth->execute();

    $returndata = $sth->fetchall_arrayref({});

    $sth->finish();

    # If the record was found return the details otherwise populate the error structure

    if ( defined( $returndata ) ) {    
        return $returndata;
    }
    else {
        $self->{ ErrorStatus    } = "1";
        $self->{ ErrorMessage   } = "No pictures require uploading to ".$p->{ AuctionSite };
        $self->{ ErrorDetail    } = "";
        return undef;
    }
}

#=============================================================================================
# Method    : get_used_picture_keys
# Added     : 7/07/05
# Input     :
# Returns   : Hash with all used picture keys in format $key{1}
#
# This method returns a list of all photo keys currently in use in auction records as a HASH
#=============================================================================================

sub get_used_picture_keys {

    my $self    = shift;
    my $p       = { @_ };

    my %keylist;
    my $picturekeys;

    $self->{ Debug } ge "1" ? ( $self->update_log( ( caller( 0 ) )[3] ) ) : () ;

    $self->clear_err_structure();

    # Select picture keys in Pictures table from selection auction list

    my $SQL =  qq {
        SELECT DISTINCT Pictures.PictureKey
        FROM            Auctions 
        INNER JOIN    ( AuctionImages 
        INNER JOIN      Pictures 
        ON              AuctionImages.PictureKey    = Pictures.PictureKey       ) 
        ON              Auctions.AuctionKey         = AuctionImages.AuctionKey 
    };

    $self->{ Debug } ge "2" ? ( $self->update_log( "Executing SQL Statement:\n".$SQL ) ) : () ;

    my $sth = $dbh->prepare( $SQL );

    $sth->execute();

    $picturekeys = $sth->fetchall_arrayref();

    foreach my $key ( @$picturekeys ) {
        $keylist{ $key->[0] } = 1;
    }

    # If the record was found return the details otherwise populate the error structure

    if ( %keylist ) {    
        return %keylist;
    }
    else {
        $self->{ ErrorStatus    } = "1";
        $self->{ ErrorMessage   } = "No pictures used in this database";
        $self->{ ErrorDetail    } = "";
        return undef;
    }
}

#=============================================================================================
# Method    : get_selected_used_picture_keys
# Added     : 7/07/05
# Input     :
# Returns   : Hash with all used picture keys in format $data{key}
#
# This method returns a list of all photo keys currently in use in auction records
#=============================================================================================

sub get_selected_used_picture_keys {

    my $self    = shift;
    my $p       = { @_ };

    my $keylist;
    my $keydata;
    my $picturekeys;
    my $picidfield;

    $self->{Debug} ge "1" ? ($self->update_log( (caller(0))[3] )) : () ;

    $self->clear_err_structure();

    # Build the auction key selection list from the input array

    foreach my $item ( @{ $p->{ AuctionKeys } } ) {
        if ( $keylist eq "" ) {
            $keylist = $item;
        }
        else {    
            $keylist = $keylist.", ".$item;
        }    
    }

    # Select the Picture ID field based on the Auction Site Parameter

    if ( $p->{ AuctionSite } eq "TRADEME" ) {
        $picidfield = "PhotoId";
    }
    elsif ( $p->{ AuctionSite } eq "SELLA" ) {
        $picidfield = "SellaID";
    }

    # Select picture keys in Pictures table from selection auction list

    my $SQL =  qq {
        SELECT DISTINCT Pictures.PictureKey
        FROM            Auctions 
        INNER JOIN    ( AuctionImages 
        INNER JOIN      Pictures 
        ON              AuctionImages.PictureKey = Pictures.PictureKey ) 
        ON              Auctions.AuctionKey = AuctionImages.AuctionKey 
        WHERE       ( ( Auctions.AuctionKey  IN ( $keylist )    )  
        AND           ( Pictures.$picidfield IS NOT NULL        ) )
    };

    $self->{ Debug } ge "2" ? ( $self->update_log( "Executing SQL Statement:\n".$SQL ) ) : () ;

    my $sth = $dbh->prepare( $SQL );
    
    $sth->execute;

    $keydata    =   $sth->fetchall_arrayref();

    foreach my $key ( @$keydata ) {
        $self->{ Debug } ge "1" ? ( $self->update_log( "Adding Picture Key: ".$key->[0]." to return array" ) ) : () ;
        push( @$picturekeys, $key->[0] );
    }
    
    # If any records were found return the details otherwise populate the error structure

    if ( $picturekeys ) {    
        return $picturekeys;
    }
    else {
        $self->{ ErrorStatus    } = "1";
        $self->{ ErrorMessage   } = "No pictures used in this database";
        $self->{ ErrorDetail    } = "";
        return undef;
    }
}

#=============================================================================================
# Method    : delete_picture_record    
# Added     : 07/07/05
# Input     : AuctionKey <fieldname => value>
# Returns   : 
#
# Delete an Auction Record from the databaSe 
#=============================================================================================

sub delete_picture_record {

    my $self        =   shift;
    my $picturekey  =   shift;
    
    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    $sth_delete_picture_record->execute( $picturekey );
}

#=============================================================================================
# Method    : add_auction_images_record
# Added     : 2/08/05
# Input     : Hash containg filed/value pairs
#
# Add an Auction shipping Record to the databaSe 
#=============================================================================================

sub add_auction_images_record {

    my $self    = shift;
    my $p       = { @_ };
    my $record;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    $self->clear_err_structure();

    # Set default values for new record
    # Key value AuctionKey is defined as Autonumber and will be generated by the database
    
    $record->{ PictureKey       }   = 0;               
    $record->{ AuctionKey       }   = 0;               
    $record->{ ImageSequence    }   = 0;               

    # Read through the input values and alter the corresponding fields in the "Record" hash

    while ( ( my $key, my $value ) = each( %{ $p } ) ) {
            $record->{ $key } = $value;
    }

    # insert the updated record into the database

    my $sth = $dbh->prepare( qq {
        INSERT INTO     AuctionImages            
                      ( PictureKey      ,
                        AuctionKey      ,
                        ImageSequence   )
        VALUES        ( ?,?,?           )
    } );
    
    $sth->execute( 
         $record->{ PictureKey       }  ,         
         $record->{ AuctionKey       }  ,          
         $record->{ ImageSequence    }  ,
    ) || die "add_auction_images_record - Error executing statement: $DBI::errstr\n";
                    
}

#=============================================================================================
# Method    : copy_auction_image_records   
# Added     : 02/08/06        
# Input     : AuctionKey     
# Returns   :                
#                            
#=============================================================================================
                             
sub copy_auction_image_records {    
                             
    my $self    = shift;        
    my $p       = {@_};        
    my $recs;
    
    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    # Delete any ToAuction records already in the AuctionImages file (unlikely, but...)
                             
    my $SQL = qq {
        DELETE      *
        FROM        AuctionImages
        WHERE       AuctionKey = ?
    } ;

    my $sth = $dbh->prepare( $SQL );

    $self->{ Debug } ge "2" ? ( $self->update_log( "Executing SQL Statement:\n".$SQL ) ) : () ;
                             
    $sth->execute( $p->{ ToAuctionKey } );

    # Retrieve the FromAuction data records from the database
                             
    $SQL = qq {
        SELECT      *
        FROM        AuctionImages
        WHERE       AuctionKey = ?
        ORDER BY    ImageSequence
    } ;

    $sth = $dbh->prepare( $SQL );

    $self->{ Debug } ge "2" ? ( $self->update_log( "Executing SQL Statement:\n".$SQL ) ) : () ;
                             
    $sth->execute( $p->{ FromAuctionKey } );
    $recs = $sth->fetchall_arrayref({});

    # Add each From Record into the Shipping details file using the To Auction Key

    foreach my $r ( @$recs ) {

        $self->add_auction_images_record(
            AuctionKey      =>   $p->{  ToAuctionKey    }  ,          
            PictureKey      =>   $r->{  PictureKey      }  ,          
            ImageSequence   =>   $r->{  ImageSequence   }  ,           
        );
    }    
}

#=============================================================================================
# Method    : get_auction_image_records   
# Added     : 02/08/06        
# Input     : AuctionKey     
# Returns   :                
#                            
#=============================================================================================
                             
sub get_auction_image_records {    
                             
    my $self    = shift;        
    my $p       = { @_ };        
    my $recs;
    
    $self->{ Debug } ge "1" ? ( $self->update_log( "Invoked Method: ". ( caller( 0 ) )[3] ) ) : () ;

    # Retrieve the FromAuction data records from the database
                             
    my $SQL = qq {
        SELECT      *
        FROM        AuctionImages
        WHERE       AuctionKey = ?
        ORDER BY    ImageSequence
    };

    my $sth = $dbh->prepare( $SQL );

    $self->{ Debug } ge "1" ? ( $self->update_log( "Executing SQL Statement:\n".$SQL ) ) : () ;
    $self->{ Debug } ge "1" ? ( $self->update_log( "Selected Auction Key:\n".$p->{ AuctionKey } ) ) : () ;
                             
    $sth->execute( $p->{ AuctionKey } );
    $recs = $sth->fetchall_arrayref( {} );

    if ( defined( $recs ) ) {
        return $recs;
    }
    else {
        return undef;
    }

}

#=============================================================================================
# Method    : add_shipping_details_record
# Added     : 2/08/05
# Input     : Hash containg filed/value pairs
#
# Add an Auction shipping Record to the databaSe 
#=============================================================================================

sub add_shipping_details_record {

    my $self = shift;
    my $input = {@_};
    my $record;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    $self->clear_err_structure();

    # Set default values for new record
    # Key value AuctionKey is defined as Autonumber and will be generated by the database
    
    $record->{  Shipping_Details_Seq       }   = 0             ;               
    $record->{  Shipping_Details_Cost      }   = 0             ;               
    $record->{  Shipping_Details_Text      }   = ""            ;               
    $record->{  AuctionKey                 }   = 0             ;               
    $record->{  Shipping_Option_Code       }   = ""            ;               

    # Read through the input values and alter the corresponding fields in the "Record" hash

    while ((my $key, my $value) = each(%{$input})) {
            $record->{$key} = $value;
    }

    # insert the updated record into the database

    my $sth = $dbh->prepare( qq {
        INSERT INTO     ShippingDetails            
                      ( Shipping_Details_Seq    ,
                        Shipping_Details_Cost   ,
                        Shipping_Details_Text   ,
                        AuctionKey              ,
                        Shipping_Option_Code    )
        VALUES        ( ?,?,?,?,?               )
    } );
    
    $sth->execute( 
         $record->{ Shipping_Details_Seq     }  ,         
         $record->{ Shipping_Details_Cost    }  ,          
        "$record->{ Shipping_Details_Text    }" ,
         $record->{ AuctionKey               }  ,
        "$record->{ Shipping_Option_Code     }" )           
        || die "add_shipping_details_record - Error executing statement: $DBI::errstr\n";
                    
}

#=============================================================================================
# Method    : copy_shipping_details_records   
# Added     : 02/08/06        
# Input     : AuctionKey     
# Returns   :                
#                            
# This function first retrieves the record identified by the key value passed into the method
# into a hash keyed on field name: $record->{key} = $value. The input data is a hash
# with the field name and data to be updated. Each record in the input hash is matched against
# the corresponding field name in the retrieved record hash and the value altered to the input
# value. When all fields in the input has have been processed the record is written back into
# the database as a NEW record with the copy record values overriden by the input
#=============================================================================================
                             
sub copy_shipping_details_records {    
                             
    my $self = shift;        
    my $input = {@_};        
    my $recs;
    
    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    # Delete any ToAuction records already in the ShippingDetails file (unlikely, but...)
                             
    my $SQL = qq {
        DELETE      *
        FROM        ShippingDetails
        WHERE       AuctionKey = ?
    } ;

    my $sth = $dbh->prepare( $SQL );

    $self->{Debug} ge "2" ? ($self->update_log("Executing SQL Statement:\n: $SQL")) : () ;
                             
    $sth->execute( $input->{ ToAuctionKey } );

    # Retrieve the FromAuction data records from the database
                             
    $SQL = qq {
        SELECT      *
        FROM        ShippingDetails
        WHERE       AuctionKey = ?
        ORDER BY    Shipping_Details_Seq
    } ;

    $sth = $dbh->prepare( $SQL );

    $self->{Debug} ge "2" ? ($self->update_log("Executing SQL Statement:\n: $SQL")) : () ;
                             
    $sth->execute( $input->{ FromAuctionKey } );
    $recs = $sth->fetchall_arrayref({});

    # Add each From Record into the Shipping details file using the To Auction Key

    foreach my $sdrec ( @$recs ) {
                             
        $self->add_shipping_details_record(
            AuctionKey                 =>   $input->{  ToAuctionKey             }  ,          
            Shipping_Details_Seq       =>   $sdrec->{  Shipping_Details_Seq     }  ,           
            Shipping_Details_Cost      =>   $sdrec->{  Shipping_Details_Cost    }  ,           
            Shipping_Details_Text      =>   $sdrec->{  Shipping_Details_Text    }  ,          
            Shipping_Option_Code       =>   $sdrec->{  Shipping_Option_Code     }  ,          
        );
    }    
}

#=============================================================================================
# Method    : get_shipping_details
# Added     : 2/08/05
# Input     : Hash containg filed/value pairs
# Output    : Array of hashes (records)
# 
#=============================================================================================

sub get_shipping_details {

    my $self = shift;
    my $input = {@_};
    my $shipdata;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    $self->clear_err_structure();

    # Define the SQL statemrent

    my $SQL = qq {
        SELECT      *
        FROM        ShippingDetails
        WHERE       AuctionKey  = ?
        ORDER BY    Shipping_Details_Seq
    } ;

    my $sth = $dbh->prepare( $SQL );
    
    # get the From record details
    
    $sth->execute( $input->{ AuctionKey } );

    $shipdata = $sth->fetchall_arrayref({});
    
    $sth->finish;

    return $shipdata;
}

#=============================================================================================
# Method    : is_valid_category    
# Added     : 17/03/05
# Input     : AuctionCategory
# Returns   : Boolean
#
# This method returns true or false based on whether the category value passed is valid
# or not. The method tests whether the category exists in the Category table
#=============================================================================================

sub is_valid_category {

    my $self        =   shift;
    my $cat         =   shift;
    
    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    my $SQL     =   qq {    SELECT        COUNT(*)
                            FROM          TMCategories
                            WHERE         Category = ?      } ;

    my $sth     =   $dbh->prepare($SQL) || die "Error preparing statement: $DBI::errstr\n";
    
    $sth->execute($cat) || die "Error exexecuting statement: $DBI::errstr\n";
    
    my $found   =   $sth->fetchrow_array;

    $sth->finish;

    return $found;
}

#=============================================================================================
# Method    : get_category_list    
# Added     : 18/07/05
# Input     : AuctionCategory
# Returns   : Array of Arrays
#
# This method returns true or false based on whether the category value passed is valid
# or not. The method tests whether the category exists in the Category table
#=============================================================================================

sub get_category_list {

    my $self        =   shift;
    my $cat         =   shift;
    my @catlist;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    my $SQL     =   qq {    SELECT        Category
                            FROM          TMCategories
                            WHERE         Parent        = ?      
                            ORDER BY      Sequence      } ;

    my $sth     =   $dbh->prepare($SQL) || die "Error preparing statement: $DBI::errstr\n";
    
    $sth->execute( $cat ) || die "Error exexecuting statement: $DBI::errstr\n";

    my $records =  $sth->fetchall_arrayref( {} );

    $sth->finish;

    # Now build the array of arrays to return

    foreach my $row ( @$records ) {
        push ( @catlist, $row->{ Category       } );
    }

    return @catlist;
}

#=============================================================================================
# Method    : get_category_description    
# Added     : 18/07/05
# Input     : AuctionCategory
# Returns   : Array of Arrays
#
# This method returns true or false based on whether the category value passed is valid
# or not. The method tests whether the category exists in the Category table
#=============================================================================================

sub get_category_description {

    my $self        =   shift;
    my $cat         =   shift;

    $self->{Debug} ge "1" ? ( $self->update_log("Invoked Method: ".(caller(0))[3] ) ) : () ;

    my $SQL     =   qq {    SELECT        Description
                            FROM          TMCategories
                            WHERE         Category      = ? };   

    my $sth     =   $dbh->prepare($SQL) || die "Error preparing statement: $DBI::errstr\n";
    
    $sth->execute( $cat ) || die "Error exexecuting statement: $DBI::errstr\n";

    my $record = $sth->fetchrow_hashref;
    my $description = $record->{ Description };

    $sth->finish;


    return $description;
}

#=============================================================================================
# Method    : has_children    
# Added     : 17/03/05
# Input     : AuctionCategory
# Returns   : Boolean
#
# This method returns true or false based on whether the category value passed has child
# categories attached to it or not. 
#=============================================================================================

sub has_children {

    my $self        =   shift;
    my $cat         =   shift;
    
    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    my $SQL     =   qq {    SELECT        COUNT(*)
                            FROM          TMCategories
                            WHERE         Parent = ?        } ;

    my $sth = $dbh->prepare($SQL) || die "Error preparing statement: $DBI::errstr\n";
    
    $sth->execute($cat) || die "Error exexecuting statement: $DBI::errstr\n";
    
    my $haschildren = $sth->fetchrow_array;

    $sth->finish;

    return $haschildren;
    
}

#=============================================================================================
# Method    : get_children    
# Added     : 17/03/05
# Input     : AuctionCategory
# Returns   : Category List
#
# This method returns true or false based on whether the category value passed has child
# categories attached to it or not. 
#=============================================================================================

sub get_children {

    my $self        =   shift;
    my $cat         =   shift;
    
    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    my $SQL     =   qq {    SELECT        Category
                            FROM          TMCategories
                            WHERE         Parent = ?
                            ORDER BY      Sequence          } ;

    my $sth = $dbh->prepare($SQL) || die "Error preparing statement: $DBI::errstr\n";
    
    $sth->execute($cat) || die "Error exexecuting statement: $DBI::errstr\n";
    
    my $haschildren = $sth->fetchrow_array;

    $sth->finish;

    return $haschildren;
    
}

#=============================================================================================
# Method    : get_parent    
# Added     : 17/09/06
# Input     : AuctionCategory
# Returns   : Boolean
#
# This method returns the parent category for the input category
#=============================================================================================

sub get_parent {

    my $self        =   shift;
    my $cat         =   shift;
    
    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    my $SQL     =   qq {    SELECT        Parent
                            FROM          TMCategories
                            WHERE         Category = ?        } ;

    my $sth = $dbh->prepare($SQL) || die "Error preparing statement: $DBI::errstr\n";
    
    $sth->execute($cat) || die "Error exexecuting statement: $DBI::errstr\n";
    
    my $record = $sth->fetchrow_hashref;
    my $parent = $record->{ Parent };

    $sth->finish;

    # If the record was found return the key otherwise populate the error structure

    if (defined $parent) {    

        return $parent;
    }
    else {            
        return 0;
    }
}

#=============================================================================================
# Method    : has_attributes    
# Added     : 17/09/06
# Input     : AuctionCategory
# Returns   : 
#
# This method returns true or false based on whether the category value passed has attributes
# attached to it or not. 
#=============================================================================================

sub has_attributes {

    my $self        =   shift;
    my $cat         =   shift;
    
    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    my $SQL     =   qq {    SELECT        COUNT(*)
                            FROM          Attributes
                            WHERE         AttributeCategory = ?        } ;

    my $sth = $dbh->prepare($SQL) || die "Error preparing statement: $DBI::errstr\n";
    
    $sth->execute($cat) || die "Error exexecuting statement: $DBI::errstr\n";
    
    my $has_attributes = $sth->fetchrow_array;

    $sth->finish;

    return $has_attributes;   
}

#=============================================================================================
# Method    : attribute_has_combo
# Added     : 01/08/07
# Input     : AuctionCategory
# Returns   : 
#
# This method returns true or false based on whether the category value passed has attributes
# cpmbo box (i.e. selection list) attached to it or not. 
#=============================================================================================

sub attribute_has_combo {

    my $self        =   shift;
    my $cat         =   shift;
    
    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    my $SQL     =   qq {    SELECT      COUNT(*)
                            FROM        Attributes
                            WHERE       AttributeCategory   = ?        
                            AND         AttributeCombo      = 1 } ;

    my $sth = $dbh->prepare($SQL) || die "Error preparing statement: $DBI::errstr\n";

    $sth->execute( $cat ) || die "Error exexecuting statement: $DBI::errstr\n";

    my $combo = $sth->fetchrow_array;

    $sth->finish;

    return $combo;   
}

#=============================================================================================
# Method    : get_attribute_procedure
# Added     : 01/08/07
# Input     : AuctionCategory
# Returns   : 
#
# This method returns the name of the associated procedure for an attribute category
#=============================================================================================

sub get_attribute_procedure {

    my $self        =   shift;
    my $cat         =   shift;
    my $text        =   shift;
    
    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    my $SQL     =   qq {    SELECT      AttributeProcedure
                            FROM        Attributes
                            WHERE       AttributeCategory   = ? } ;

    my $sth = $dbh->prepare($SQL) || die "Error preparing statement: $DBI::errstr\n";
    
    $sth->execute( $cat ) || die "Error exexecuting statement: $DBI::errstr\n";
    
    my $proc = $sth->fetchrow_array;

    $sth->finish;

    return $proc;
}

#=============================================================================================
# Method    : is_valid_attribute_value
# Added     : 01/08/07
# Input     : AttributeCategory
# Returns   : 
#
# Method to validate that AttributeField and AttributeValue are valid for the input category
#=============================================================================================

sub is_valid_attribute_value {

    my $self        =   shift;
    my $cat         =   shift;
    my $field       =   shift;
    my $value       =   shift;
    
    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    my $SQL     =   qq {    SELECT      COUNT(*)
                            FROM        Attributes
                            WHERE       AttributeCategory   = ?
                            AND         AttributeField      = ?
                            AND         AttributeValue      = ? } ;

    my $sth = $dbh->prepare($SQL) || die "Error preparing statement: $DBI::errstr\n";
    
    $sth->execute( $cat, $field, $value ) || die "Error exexecuting statement: $DBI::errstr\n";
    
    my $valid = $sth->fetchrow_array;

    $sth->finish;

    return $valid;  
}

#=============================================================================================
# Method    : is_valid_movie_genre
# Added     : 01/08/07
# Input     : Movie Genre
# Returns   : 
#
# Method to validate that AttributeField and AttributeValue are valid for the input category
#=============================================================================================

sub is_valid_movie_genre {

    my $self        =   shift;
    my $genre       =   shift;
    
    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    my $SQL     =   qq {    SELECT      COUNT(*)
                            FROM        MovieGenres
                            WHERE       Genre_Value         = ? } ;

    my $sth = $dbh->prepare($SQL) || die "Error preparing statement: $DBI::errstr\n";
    
    $sth->execute( $genre ) || die "Error exexecuting statement: $DBI::errstr\n";
    
    my $valid = $sth->fetchrow_array;

    $sth->finish;

    return $valid;  
}

#=============================================================================================
# Method    : is_product_type    
# Added     : 11/07/06
# Input     : Product Type Name
# Returns   : Boolean
#
# This method returns true or false based on whether the product type passed is valid or not.
#=============================================================================================

sub is_product_type {

    my $self        =   shift;
    my $ptype       =   shift;
    
    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    my $SQL     =   qq {    SELECT        COUNT(*)
                            FROM          ProductTypes
                            WHERE         ProductType   = ?      } ;

    my $sth     =   $dbh->prepare($SQL) || die "Error preparing statement: $DBI::errstr\n";
    
    $sth->execute($ptype) || die "Error exexecuting statement: $DBI::errstr\n";
    
    my $found   =   $sth->fetchrow_array;

    $sth->finish;

    return $found;
}

#=============================================================================================
# Method    : add_product_type    
# Added     : 11/07/06
# Input     : Product Type Name
# Returns   : Boolean
#
#=============================================================================================

sub add_product_type {

    my $self        =   shift;
    my $ptype       =   shift;
    
    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    # Get the current highest product type sequence number

    my $SQL =  qq { SELECT MAX(ProductTypeSequence) FROM ProductTypes };
    my $sth = $dbh->prepare($SQL);

    $sth->execute();

    my @data = $sth->fetchrow_array();

    my $pseq = $data[0] + 10;

    # Add the product Type into the product type table

    $SQL = qq {
        INSERT INTO ProductTypes
                  ( ProductType             ,
                    ProductTypeSequence     )
        VALUES    ( ?,?                     )
    } ;

    $sth     =   $dbh->prepare($SQL)    || die "Error preparing statement: $DBI::errstr\n";
    
    $sth->execute($ptype, $pseq)        || die "Error executing statement: $DBI::errstr\n";

    $sth->finish;

}

#=============================================================================================
# Method    : is_auction_cycle    
# Added     : 11/07/06
# Input     : Auction Cycle Name
# Returns   : Boolean
#
# This method returns true or false based on whether the Auction Cycle passed is valid or not.
#=============================================================================================

sub is_auction_cycle {

    my $self        =   shift;
    my $cycle       =   shift;
    
    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    my $SQL     =   qq {    SELECT        COUNT(*)
                            FROM          AuctionCycles
                            WHERE         AuctionCycle  = ?      } ;

    my $sth     =   $dbh->prepare($SQL) || die "Error preparing statement: $DBI::errstr\n";
    
    $sth->execute($cycle) || die "Error exexecuting statement: $DBI::errstr\n";
    
    my $found   =   $sth->fetchrow_array;

    $sth->finish;

    return $found;

}

#=============================================================================================
# Method    : add_auction_cycle    
# Added     : 11/07/06
# Input     : AuctionCycle Name
# Returns   : Boolean
#
#=============================================================================================

sub add_auction_cycle {

    my $self        =   shift;
    my $cycle       =   shift;
    
    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    # Get the current highest product type sequence number

    my $SQL =  qq { SELECT MAX(AuctionCycleSequence) FROM AuctionCycles };
    my $sth = $dbh->prepare($SQL);

    $sth->execute();

    my @data = $sth->fetchrow_array();

    my $cseq = $data[0] + 10;

    # Add the product Type into the product type table

    $SQL = qq {
        INSERT INTO AuctionCycles
                  ( AuctionCycle            ,
                    AuctionCycleSequence    )
        VALUES    ( ?,?                     )
    } ;

    $sth     =   $dbh->prepare($SQL)    || die "Error preparing statement: $DBI::errstr\n";
    
    $sth->execute($cycle, $cseq)        || die "Error executing statement: $DBI::errstr\n";

    $sth->finish;

}

#=============================================================================================
# Method    : get_standard_terms    
# Added     : 01/08/06
# Input     : 
# Returns   : String if successful, undef if no data found
#
#=============================================================================================

sub get_standard_terms {

    my $self    = shift;
    my $p       = { @_ };
    
    $self->{ Debug } ge "1" ? ( $self->update_log( "Invoked Method: ". ( caller( 0 ) )[3] ) ) : () ;

    # Get the standard terms for the specified web site

    my ( $SQL, $sth );

    if ( $p->{ AuctionSite } eq "TRADEME" ) {
        $SQL =  qq {
        SELECT  StdText 
        FROM    StandardText 
        WHERE   StdName = '##STANDARDTERMS' };
        $sth = $dbh->prepare($SQL);
    }
    elsif (  $p->{ AuctionSite } eq "SELLA" ) {
        $SQL =  qq {
        SELECT  StdText 
        FROM    StandardText 
        WHERE   StdName = '##STANDARDTERMSSELLA' };
        $sth = $dbh->prepare($SQL);
    }

    $sth->execute();

    my $record = $sth->fetchrow_hashref;
    my $terms  = $record->{ StdText };

    $sth->finish;

    # If the record was found return the key otherwise populate the error structure

    if ( defined $terms ) {    
        return $terms;
    }
    else {            
        return undef;
    }
}

#=============================================================================================
# Method    : export_data
# Added     : 28/05/05
# Input     : SQL Selection statement
# Returns   : 
#
# This method returns a list of photo records that have not been loaded to Trademe
#=============================================================================================

sub export_data {

    my $self    = shift;
    my $input = {@_};
    my $fieldlist;
    my $exportrecord;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    $self->clear_err_structure();

    open (OUTFILE, "> $input->{ Outfile }");

    # retrieve the selected output fields from the registry - boolean value for all available fields

    $key   = $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Output"} #TODO
             or die "Package Auctionitis.pm can't read LMachine/System/Disk key: $^E\n";

    foreach my $field ( keys(%$key) ) {
        $fieldlist->{ substr($field,1) } = $key->{ $field };
    }

    if ( $fieldlist->{ IncludeHeadings } ) {
    
        $exportrecord = "";
        if ( $fieldlist->{ Title         } ) { $exportrecord = $exportrecord.",\"Title\""; }  
        if ( $fieldlist->{ Description   } ) { $exportrecord = $exportrecord.",\"Description\""; } 
        if ( $fieldlist->{ ProductType   } ) { $exportrecord = $exportrecord.",\"ProductType\""; } 
        if ( $fieldlist->{ ProductCode   } ) { $exportrecord = $exportrecord.",\"ProductCode\""; } 
        if ( $fieldlist->{ AuctionCycle  } ) { $exportrecord = $exportrecord.",\"AuctionCycle\""; } 
        if ( $fieldlist->{ AuctionStatus } ) { $exportrecord = $exportrecord.",\"AuctionStatus\""; } 
        if ( $fieldlist->{ RelistStatus  } ) { $exportrecord = $exportrecord.",\"RelistStatus\""; } 
        if ( $fieldlist->{ AuctionSold   } ) { $exportrecord = $exportrecord.",\"AuctionSold\""; } 
        if ( $fieldlist->{ RelistCount   } ) { $exportrecord = $exportrecord.",\"RelistCount\""; } 
        if ( $fieldlist->{ AuctionRef    } ) { $exportrecord = $exportrecord.",\"AuctionRef\""; } 
        if ( $fieldlist->{ SellerRef     } ) { $exportrecord = $exportrecord.",\"SellerRef\""; } 
        if ( $fieldlist->{ DateLoaded    } ) { $exportrecord = $exportrecord.",\"DateLoaded\""; } 
        if ( $fieldlist->{ StartPrice    } ) { $exportrecord = $exportrecord.",\"StartPrice\""; } 
        if ( $fieldlist->{ ReservePrice  } ) { $exportrecord = $exportrecord.",\"ReservePrice\""; } 
        if ( $fieldlist->{ BuyNowPrice   } ) { $exportrecord = $exportrecord.",\"BuyNowPrice \""; } 
        if ( $fieldlist->{ ShippingInfo  } ) { $exportrecord = $exportrecord.",\"ShippingInfo\""; } 
        if ( $fieldlist->{ Featured      } ) { $exportrecord = $exportrecord.",\"Featured\""; }
        if ( $fieldlist->{ Gallery       } ) { $exportrecord = $exportrecord.",\"Gallery\""; }
        if ( $fieldlist->{ BoldTitle     } ) { $exportrecord = $exportrecord.",\"BoldTitle\""; }
        if ( $fieldlist->{ FeatureCombo  } ) { $exportrecord = $exportrecord.",\"FeatureCombo\""; }
        if ( $fieldlist->{ HomePage      } ) { $exportrecord = $exportrecord.",\"HomePage\""; }
        if ( $fieldlist->{ StockOnHand   } ) { $exportrecord = $exportrecord.",\"StockOnHand\""; } 

        print OUTFILE substr($exportrecord,1)."\n";
    }

    my $sth = $dbh->prepare( $input->{ SQL } );
    
    $sth->execute;

    my $exportdata = $sth->fetchall_arrayref({});

    foreach my $record (@$exportdata) {
    
        $exportrecord = "";
    
        if ( $fieldlist->{ Title         } ) { $exportrecord = $exportrecord.",\"".$record->{ Title         }." \""; }  
        if ( $fieldlist->{ Description   } ) { $exportrecord = $exportrecord.",\"".$record->{ Description   }." \""; } 
        if ( $fieldlist->{ ProductType   } ) { $exportrecord = $exportrecord.",\"".$record->{ ProductType   }." \""; } 
        if ( $fieldlist->{ ProductCode   } ) { $exportrecord = $exportrecord.",\"".$record->{ ProductCode   }." \""; } 
        if ( $fieldlist->{ AuctionCycle  } ) { $exportrecord = $exportrecord.",\"".$record->{ AuctionCycle  }." \""; } 
        if ( $fieldlist->{ AuctionStatus } ) { $exportrecord = $exportrecord.",\"".$record->{ AuctionStatus }." \""; } 
        if ( $fieldlist->{ RelistStatus  } ) { $exportrecord = $exportrecord.",\"".$record->{ RelistStatus  }." \""; } 
        
        if ( $fieldlist->{ AuctionSold   } ) { 
             if ( $record->{ AuctionSold   } ) {
                  $exportrecord = $exportrecord.",\"Yes\""; 
             } else {
                  $exportrecord = $exportrecord.",\"No\""; 
             }
        }        
        
        if ( $fieldlist->{ RelistCount   } ) { $exportrecord = $exportrecord.",\"".$record->{ RelistCount   }." \""; } 
        if ( $fieldlist->{ AuctionRef    } ) { $exportrecord = $exportrecord.",\"".$record->{ AuctionRef    }." \""; } 
        if ( $fieldlist->{ SellerRef     } ) { $exportrecord = $exportrecord.",\"".$record->{ SellerRef    }." \""; } 
        if ( $fieldlist->{ DateLoaded    } ) { $exportrecord = $exportrecord.",\"".$record->{ DateLoaded    }." \""; } 
        if ( $fieldlist->{ StartPrice    } ) { 
             $record->{ StartPrice } = $self->CurrencyFormat($record->{ StartPrice });
             $exportrecord = $exportrecord.",".$record->{ StartPrice    };
        } 
        if ( $fieldlist->{ ReservePrice  } ) {
             $record->{ ReservePrice } = $self->CurrencyFormat($record->{ ReservePrice });
             $exportrecord = $exportrecord.",".$record->{ ReservePrice  };
        } 
        if ( $fieldlist->{ BuyNowPrice   } ) {
             $record->{ BuyNowPrice } = $self->CurrencyFormat($record->{ BuyNowPrice });
             $exportrecord = $exportrecord.",".$record->{ BuyNowPrice   };
        } 
        if ( $fieldlist->{ ShippingInfo  } ) { $exportrecord = $exportrecord.",\"".$record->{ ShippingInfo  }." \""; } 
        if ( $fieldlist->{ Featured      } ) { 
             if ( $record->{ Featured      } ) {
                $exportrecord = $exportrecord.",\"Yes\""; 
             } else {
                $exportrecord = $exportrecord.",\"No\""; 
             }
        }

        if ( $fieldlist->{ Gallery       } ) { 
             if ( $record->{ Gallery       } ) {
                  $exportrecord = $exportrecord.",\"Yes\""; 
             } else {
                  $exportrecord = $exportrecord.",\"No\""; 
             }
        }

        if ( $fieldlist->{ BoldTitle     } ) { 
             if ( $record->{ BoldTitle      } ) {
                  $exportrecord = $exportrecord.",\"Yes\""; 
             } else {
                  $exportrecord = $exportrecord.",\"No\""; 
             }
        }

        if ( $fieldlist->{ FeatureCombo  } ) { 
             if ( $record->{ FeatureCombo  } ) {
                  $exportrecord = $exportrecord.",\"Yes\""; 
             } else {
                  $exportrecord = $exportrecord.",\"No\""; 
             }
        }

        if ( $fieldlist->{ HomePage      } ) { 
             if ( $record->{ HomePage      } ) {
                  $exportrecord = $exportrecord.",\"Yes\""; 
             } else {
                  $exportrecord = $exportrecord.",\"No\""; 
             }
        }

        if ( $fieldlist->{ StockOnHand   } ) { $exportrecord = $exportrecord.",".$record->{ StockOnHand   }.""; } 

        print OUTFILE substr($exportrecord,1)."\n";

    }

    close OUTFILE;
    
    # If the record was found return the details otherwise populate the error structure

    if     ( defined($exportdata) ) {    

            return 1;
            
    } else {
    
            $self->{ErrorStatus}    = "1";
            $self->{ErrorMessage}   = "No data exported";
            $self->{ErrorDetail}    = "";
            return undef;
    }
}

#=============================================================================================
# Method    : export_HTML_as_pages
# Added     : 28/05/05
# Input     : SQL Selection statement
# Returns   : 
#
#=============================================================================================

sub export_HTML_as_pages {

    my $self    = shift;
    my $input = {@_};
    my $fieldlist;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    $self->clear_err_structure();

    open (OUTFILE, "> $input->{ Outfile }");

    # retrieve the selected output fields from the registry - boolean value for all available fields

    $key   = $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Output"} #TODO
             or die "Package Auctionitis.pm can't read LMachine/System/Disk key: $^E\n";

    foreach my $field ( keys(%$key) ) {
        $fieldlist->{ substr($field,1) } = $key->{ $field };
    }

    print OUTFILE "<HTML><HEAD><TITLE>Auctionitis HTML Data - 1 Page Per record</TITLE></HEAD><BODY>\n";
    
    my $sth = $dbh->prepare( $input->{ SQL } );
    
    $sth->execute;

    my $exportdata = $sth->fetchall_arrayref({});

    foreach my $record (@$exportdata) {

        print OUTFILE "<P style=\"page-break-before: always\">\n";

        print OUTFILE "<TABLE width=100% Cellpadding=1 cellspacing=1 border=1>\n";
    
        if ( $fieldlist->{ Title } ) { 
            print OUTFILE "<TR><TD width=30% ><B>Title</B></TD><TD>".$record->{ Title }."</TD></TR>\n";
        }
        if ( $fieldlist->{ Description } ) { 
            $record->{ Description } =~ tr/\n/\x0D\x0A/;    
            print OUTFILE "<TR><TD><B>Description</B></TD><TD>".$record->{ Description }."</TD></TR>\n";;
        }
        if ( $fieldlist->{ ProductType } ) { 
            print OUTFILE "<TR><TD><B>Product Type</B></TD><TD>".$record->{ ProductType }."</TD></TR>\n";
        }
        if ( $fieldlist->{ ProductCode } ) { 
            print OUTFILE "<TR><TD><B>Product Code</B></TD><TD>".$record->{ ProductCode }."</TD></TR>\n";
        } 
        if ( $fieldlist->{ AuctionCycle } ) { 
            print OUTFILE "<TR><TD><B>Auction Cycle</B></TD><TD>".$record->{ AuctionCycle }."</TD></TR>\n";
        } 
        if ( $fieldlist->{ AuctionStatus } ) {
            print OUTFILE "<TR><TD><B>Auction Status</B></TD><TD>".$record->{ AuctionStatus }."</TD></TR>\n";
        } 
        if ( $fieldlist->{ RelistStatus } ) {
            print OUTFILE "<TR><TD><B>Relist Status</B></TD><TD>".$record->{ RelistStatus }."</TD></TR>\n";
        } 
        
        if ( $fieldlist->{ AuctionSold } ) { 
             if ( $record->{ AuctionSold   } ) {
                  print OUTFILE "<TR><TD><B>Sold</B></TD><TD>Yes</TD></TR>\n"; 
             } else {
                  print OUTFILE "<TR><TD><B>Sold</B></TD><TD>No</TD></TR>\n"; 
             }
        }        
        
        if ( $fieldlist->{ RelistCount } ) { 
            print OUTFILE "<TR><TD><B>Relist Count</B></TD><TD>".$record->{ RelistCount }."</TD></TR>\n";
        }        
        if ( $fieldlist->{ AuctionRef } ) { 
            print OUTFILE "<TR><TD><B>Auction Ref</B></TD><TD>".$record->{ AuctionRef }."</TD></TR>\n";
        }        
        if ( $fieldlist->{ SellerRef } ) { 
            print OUTFILE "<TR><TD><B>Seller Ref</B></TD><TD>".$record->{ SellerRef }."</TD></TR>\n";
        }
        if ( $fieldlist->{ DateLoaded } ) {
            print OUTFILE "<TR><TD><B>Date Loaded</B></TD><TD>".$record->{ DateLoaded }."</TD></TR>\n";
        }        
        if ( $fieldlist->{ StartPrice } ) {
            $record->{ StartPrice } = $self->CurrencyFormat($record->{ StartPrice });
            print OUTFILE "<TR><TD><B>Start Price</B></TD><TD>".$record->{ StartPrice }."</TD></TR>\n";
        }        
        if ( $fieldlist->{ ReservePrice } ) {
            $record->{  ReservePrice } = $self->CurrencyFormat($record->{ ReservePrice });
            print OUTFILE "<TR><TD><B>Reserve Price</B></TD><TD>".$record->{ ReservePrice }."</TD></TR>\n";
        }        
        if ( $fieldlist->{ BuyNowPrice } ) {
            $record->{  BuyNowPrice } = $self->CurrencyFormat($record->{ BuyNowPrice });
            print OUTFILE "<TR><TD><B>Buy Now Price</B></TD><TD>".$record->{ BuyNowPrice }."</TD></TR>\n";
        }        
        if ( $fieldlist->{ ShippingInfo } ) {
            print OUTFILE "<TR><TD><B>Shipping Info</B></TD><TD>".$record->{ ShippingInfo }."</TD></TR>\n";
        }        
        if ( $fieldlist->{ Featured } ) { 
             if ( $record->{ Featured   } ) {
                  print OUTFILE "<TR><TD><B>Featured</B></TD><TD>Yes</TD></TR>\n"; 
             } else {
                  print OUTFILE "<TR><TD><B>Featured</B></TD><TD>No</TD></TR>\n"; 
             }
        }        

        if ( $fieldlist->{ Gallery       } ) { 
             if ( $record->{ Gallery   } ) {
                  print OUTFILE "<TR><TD><B>Gallery</B></TD><TD>Yes</TD></TR>\n"; 
             } else {
                  print OUTFILE "<TR><TD><B>Gallery</B></TD><TD>No</TD></TR>\n"; 
             }
        }        

        if ( $fieldlist->{ BoldTitle     } ) { 
             if ( $record->{ BoldTitle      } ) {
                  print OUTFILE "<TR><TD><B>Bold Title</B></TD><TD>Yes</TD></TR>\n"; 
             } else {
                  print OUTFILE "<TR><TD><B>Bold Title</B></TD><TD>No</TD></TR>\n"; 
             }
        }        

        if ( $fieldlist->{ FeatureCombo  } ) { 
             if ( $record->{ FeatureCombo  } ) {
                  print OUTFILE "<TR><TD><B>Feature Combo</B></TD><TD>Yes</TD></TR>\n"; 
             } else {
                  print OUTFILE "<TR><TD><B>Feature Combo</B></TD><TD>No</TD></TR>\n"; 
             }
        }        

        if ( $fieldlist->{ HomePage      } ) { 
             if ( $record->{ HomePage } ) {
                  print OUTFILE "<TR><TD><B>Home Page</B></TD><TD>Yes</TD></TR>\n"; 
             } else {
                  print OUTFILE "<TR><TD><B>Home Page</B></TD><TD>No</TD></TR>\n"; 
             }
        }        
    
        print OUTFILE "</TABLE></P>\n";

    }

    print OUTFILE "</BODY></HTML>\n";

    close OUTFILE;
    
    # If the record was found return true otherwise populate the error structure

    
    #        $self->{ErrorStatus}    = "1";
    #        $self->{ErrorMessage}   = "No data exported";
    #        $self->{ErrorDetail}    = "";
    #        return undef;

}

#=============================================================================================
# Method    : export_HTML_as_records
# Added     : 29/08/05
# Input     : SQL Selection statement
# Returns   : 
#
#=============================================================================================

sub export_HTML_as_records {

    my $self    = shift;
    my $input = {@_};
    my $fieldlist;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    $self->clear_err_structure();

    open (OUTFILE, "> $input->{ Outfile }");

    # retrieve the selected output fields from the registry - boolean value for all available fields

    $key   = $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Output"} #TODO
             or die "Package Auctionitis.pm can't read LMachine/System/Disk key: $^E\n";

    foreach my $field ( keys(%$key) ) {
        $fieldlist->{ substr($field,1) } = $key->{ $field };
    }

    print OUTFILE "<HTML><HEAD><TITLE>Auctionitis HTML Record Data</TITLE></HEAD><BODY>\n";
    
    my $sth = $dbh->prepare( $input->{ SQL } );
    
    $sth->execute;

    my $exportdata = $sth->fetchall_arrayref({});

    print OUTFILE "<TABLE width=100% Cellpadding=1 cellspacing=1 border=1>\n";

    # Print the Header records

    if ( $fieldlist->{ Title } ) { 
         print OUTFILE "<TR><TD width=30% ><B>Title</B></TD>\n";
    }
    if ( $fieldlist->{ Description } ) { 
         print OUTFILE "<TD><B>Description</B></TD>\n";;
    }
    if ( $fieldlist->{ ProductType } ) { 
         print OUTFILE "<TD><B>Product Type</B></TD>\n";
    }
    if ( $fieldlist->{ ProductCode } ) { 
         print OUTFILE "<TD><B>Product Code</B></TD>\n";
    } 
    if ( $fieldlist->{ AuctionCycle } ) { 
         print OUTFILE "<TD><B>Auction Cycle</B></TD>\n";
    } 
    if ( $fieldlist->{ AuctionStatus } ) {
         print OUTFILE "<TD><B>Auction Status</B></TD>\n";
    } 
    if ( $fieldlist->{ RelistStatus } ) {
         print OUTFILE "<TD><B>Relist Status</B></TD>\n";
    } 
    if ( $fieldlist->{ AuctionSold } ) { 
         print OUTFILE "<TD><B>Sold</B></TD>\n"; 
    }        
    if ( $fieldlist->{ RelistCount } ) { 
         print OUTFILE "<TD><B>Relist Count</B></TD>\n";
    }        
    if ( $fieldlist->{ AuctionRef } ) { 
         print OUTFILE "<TD><B>Auction Ref</B></TD>\n";
    }        
    if ( $fieldlist->{ SellerRef } ) { 
         print OUTFILE "<TD><B>Seller Ref</B></TD>\n";
    }
    if ( $fieldlist->{ DateLoaded } ) {
         print OUTFILE "<TD><B>Date Loaded</B></TD>\n";
    }        
    if ( $fieldlist->{ StartPrice } ) {
         print OUTFILE "<TD><B>Start Price</B></TD>\n";
    }        
    if ( $fieldlist->{ ReservePrice } ) {
         print OUTFILE "<TD><B>Reserve Price</B></TD>\n";
    }        
    if ( $fieldlist->{ BuyNowPrice } ) {
         print OUTFILE "<TD><B>Buy Now Price</B></TD>\n";
    }        
    if ( $fieldlist->{ ShippingInfo } ) {
         print OUTFILE "<TD><B>Shipping Info</B></TD>\n";
    }        
    if ( $fieldlist->{ Featured } ) { 
         print OUTFILE "<TD><B>Featured</B></TD>\n"; 
    }        
    if ( $fieldlist->{ Gallery       } ) { 
         print OUTFILE "<TD><B>Gallery</B></TD>\n"; 
    }        
    if ( $fieldlist->{ BoldTitle     } ) { 
         print OUTFILE "<TD><B>Bold Title</B></TD>\n"; 
    }        
    if ( $fieldlist->{ FeatureCombo  } ) { 
         print OUTFILE "<TD><B>Feature Combo</B></TD>\n"; 
    }        
    if ( $fieldlist->{ HomePage      } ) { 
         print OUTFILE "<TD><B>Home Page</B></TD></TR>\n"; 
    }        

    # Print the detail records
   
    foreach my $record (@$exportdata) {
    
    
        if ( $fieldlist->{ Title } ) { 
            print OUTFILE "<TR><TD>".$record->{ Title }."</TD>\n";
        }
        if ( $fieldlist->{ Description } ) { 
            $record->{ Description } =~ tr/\n/\x0D\x0A/;    
            print OUTFILE "<TD>".$record->{ Description }."</TD>\n";;
        }
        if ( $fieldlist->{ ProductType } ) { 
            print OUTFILE "<TD>".$record->{ ProductType }."</TD>\n";
        }
        if ( $fieldlist->{ ProductCode } ) { 
            print OUTFILE "<TD>".$record->{ ProductCode }."</TD>\n";
        } 
        if ( $fieldlist->{ AuctionCycle } ) { 
            print OUTFILE "<TD>".$record->{ AuctionCycle }."</TD>\n";
        } 
        if ( $fieldlist->{ AuctionStatus } ) {
            print OUTFILE "<TD>".$record->{ AuctionStatus }."</TD>\n";
        } 
        if ( $fieldlist->{ RelistStatus } ) {
            print OUTFILE "<TD>".$record->{ RelistStatus }."</TD>\n";
        } 
        
        if ( $fieldlist->{ AuctionSold } ) { 
             if ( $record->{ AuctionSold   } ) {
                  print OUTFILE "<TD>Yes</TD>\n"; 
             } else {
                  print OUTFILE "<TD>No</TD>\n"; 
             }
        }        
        
        if ( $fieldlist->{ RelistCount } ) { 
            print OUTFILE "<TD>".$record->{ RelistCount }."</TD>\n";
        }        
        if ( $fieldlist->{ AuctionRef } ) { 
            print OUTFILE "<TD>".$record->{ AuctionRef }."</TD>\n";
        }        
        if ( $fieldlist->{ SellerRef } ) { 
            print OUTFILE "<TD>".$record->{ SellerRef }."</TD>\n";
        }
        if ( $fieldlist->{ DateLoaded } ) {
            print OUTFILE "<TD>".$record->{ DateLoaded }."</TD>\n";
        }        
        if ( $fieldlist->{ StartPrice } ) {
            $record->{ StartPrice } = $self->CurrencyFormat($record->{ StartPrice });
            print OUTFILE "<TD>".$record->{ StartPrice }."</TD>\n";
        }        
        if ( $fieldlist->{ ReservePrice } ) {
            $record->{  ReservePrice } = $self->CurrencyFormat($record->{ ReservePrice });
            print OUTFILE "<TD>".$record->{ ReservePrice }."</TD>\n";
        }        
        if ( $fieldlist->{ BuyNowPrice } ) {
            $record->{  BuyNowPrice } = $self->CurrencyFormat($record->{ BuyNowPrice });
            print OUTFILE "<TD>".$record->{ BuyNowPrice }."</TD>\n";
        }        
        if ( $fieldlist->{ ShippingInfo } ) {
            print OUTFILE "<TD>".$record->{ ShippingInfo }."</TD>\n";
        }        
        if ( $fieldlist->{ Featured } ) { 
             if ( $record->{ Featured   } ) {
                  print OUTFILE "<TD>Yes</TD>\n"; 
             } else {
                  print OUTFILE "<TD>No</TD>\n"; 
             }
        }        

        if ( $fieldlist->{ Gallery       } ) { 
             if ( $record->{ Gallery   } ) {
                  print OUTFILE "<TD>Yes</TD>\n"; 
             } else {
                  print OUTFILE "<TD>No</TD>\n"; 
             }
        }        

        if ( $fieldlist->{ BoldTitle     } ) { 
             if ( $record->{ BoldTitle      } ) {
                  print OUTFILE "<TD>Yes</TD>\n"; 
             } else {
                  print OUTFILE "<TD>No</TD>\n"; 
             }
        }        

        if ( $fieldlist->{ FeatureCombo  } ) { 
             if ( $record->{ FeatureCombo  } ) {
                  print OUTFILE "<TD>Yes</TD>\n"; 
             } else {
                  print OUTFILE "<TD>No</TD>\n"; 
             }
        }        

        if ( $fieldlist->{ HomePage      } ) { 
             if ( $record->{ HomePage } ) {
                  print OUTFILE "<TD>Yes</TD>\n"; 
             } else {
                  print OUTFILE "<TD>No</TD></TR>\n"; 
             }
        }        
    
    }

    print OUTFILE "</TABLE>\n";
    print OUTFILE "</BODY></HTML>\n";
    close OUTFILE;
    
    # If the record was found return true otherwise populate the error structure
    
    #        $self->{ErrorStatus}    = "1";
    #        $self->{ErrorMessage}   = "No data exported";
    #        $self->{ErrorDetail}    = "";
    #        return undef;

}

#*********************************************************************************************
# --- XML Methods ---
#*********************************************************************************************

#=============================================================================================
# Method    : export_XML
# Added     : 29/08/05
# Input     : SQL Selection statement, file description, file name
# Returns   : 
#
#=============================================================================================

sub export_XML {

    my $self    = shift;
    my $input = {@_};

    $self->{ Debug } ge "1" ? ( $self->update_log( "Invoked Method: ". ( caller( 0 ) )[3] ) ) : () ;

    $self->clear_err_structure();

    my $msgsub = $input->{ Feedback };
    my $prgsub = $input->{ Progress };
    my $totsub = $input->{ Total    };
    
    if ( $msgsub ) {
         &$msgsub("Extracting export data from database");
    }

    $self->update_log( "Export Selection Data" );
    $self->update_log( "       Outfile: ". $input->{ Outfile   }      );
    $self->update_log( "          Text: ". $input->{ FileText  }      );
    $self->update_log( "           SQL: ". $input->{ SQL       }      );

    # Open the input file and execute the SQL query
    
    my $sth = $dbh->prepare( $input->{ SQL } );
   
    $sth->execute;

    my $exportdata = $sth->fetchall_arrayref({});

    my $rectot = scalar( @$exportdata );

    if ( $rectot eq 0 ) {    
    
        $self->{ErrorStatus }   = "1";
        $self->{ErrorMessage}   = "No records selected for export";
        $self->{ErrorDetail }   = "There were no records matching the export selection criteria";
        return;
    }

    my $counter = 1;
    
    my @XMLfields = $self->get_xml_field_list();

    # Initialise the XML OUtput document

    my $xmlfile = new IO::File(">$input->{ Outfile }");

    my $xo = new XML::Writer( OUTPUT => $xmlfile, DATA_MODE => 'true', DATA_INDENT => 2 );

    if ( $msgsub ) {
         &$msgsub( "Creating XML header" );
    }

    $xo->xmlDecl( 'UTF-8'   );
    $xo->doctype( 'XML'     );
    $xo->comment( 'Auctionitis XML data export');
    
    $xo->startTag( 'XML');
    $xo->startTag( 'AuctionitisDatabase');
    $xo->dataElement( "ExportVersion"           , "3.0"                           );
    $xo->dataElement( "PublishDate"             , $self->datenow()                );
    $xo->dataElement( "FileDescription"         , $input->{ FileText            } );
    $xo->dataElement( "TradeMeID"               , $self->{ TradeMeID            } );
    $xo->dataElement( "UserID"                  , $self->{ UserID               } );
    $xo->dataElement( "CategoryServiceDate"     , $self->{ CategoryServiceDate  } );
    $xo->dataElement( "RecordCount"             , $rectot                         );

    $xo->startTag( 'Auctions');

    if ( $totsub ) {
         &$totsub( $rectot );
    }
            
    # Create the xml for each  record

    foreach my $rcd ( @$exportdata ) {

        if ( $prgsub ) {
             &$prgsub( $counter );
        }
        
        if ( $msgsub ) {
             &$msgsub( "Processing: ".$rcd->{ Title } );
        }

        # Store the Auction Site as an attribute on the Auction Record so we can condition
        # import processing on the Auction Record

        $xo->startTag( 'AuctionRecord',  AuctionSite => $rcd->{ AuctionSite } );
        
        foreach my $col ( @XMLfields ) {
            
            $col =~ tr/ //d;
            
            my $val = $self->set_XML_elem_value (
                AuctionSite =>  $rcd->{ AuctionSite }   ,
                Tag         =>  $col                    , 
                Value       =>  $rcd->{ $col        }   ,
            );
           
            if ( ( defined( $val )          ) and  
                 ( $col ne "Description"    ) and
                 ( $col ne "UserNotes"      ) ) {
               
                $xo->startTag( $col );
                $xo->characters( $val );
                $xo->endTag();
            } 
            
            if  ( not defined( $val ) )  {
                $xo->emptyTag( $col );
            }
            
            if  ( $col eq "Description" ) {

                $xo->startTag( $col );
                
                # while ( $rcd->{ $col } =~ m/(.+?)(\x0D\x0A)/g ) {             # Break on cr/lf

                my @ps = split( /\x0D\x0A/, $rcd->{ $col } );
                
                foreach my $p ( @ps ) {
                    $val = Unicode::String->new($p);
                    $xo->startTag( "Paragraph" );
                    $xo->characters( $val );
                    $xo->endTag();
                }
                $xo->endTag();                
            }

            if  ( $col eq "UserNotes" ) {

                $xo->startTag( $col );
                
                # while ( $rcd->{ $col } =~ m/(.+?)(\x0D\x0A)/g ) {             # Break on cr/lf

                my @ps = split( /\x0D\x0A/, $rcd->{ $col } );
                
                foreach my $p ( @ps ) {
                    $val = Unicode::String->new($p);
                    $xo->startTag( "Note" );
                    $xo->characters( $val );
                    $xo->endTag();
                }
                $xo->endTag();                
            }

            if ( ( $col eq "ShippingOption" )   and
                 ( $val eq "Custom"         ) )  {

                $xo->startTag( "ShippingDetails" );

                my $options = $self->get_shipping_details( AuctionKey => $rcd->{ AuctionKey } );
                
                if ( $self->{ ErrorStatus } ) {
                    $self->update_log( "Error Processing Record: ".$rcd->{ AuctionKey }." (".$rcd->{ Title }.")" );
                    $self->update_log( "Error Message: ".$self->{ErrorMessage} );
                    $self->update_log( " Error Detail: ".$self->{ErrorDetail} );
                    
                    $self->clear_err_structure();
                }

                foreach my $o ( @$options ) {

                    $xo->startTag( "Option" );

                    $xo->startTag( "ShippingCost" );
                    $xo->characters( $o->{ Shipping_Details_Cost } );               
                    $xo->endTag();

                    $xo->startTag( "ShippingText" );
                    $xo->characters( $o->{ Shipping_Details_Text } );               
                    $xo->endTag();

                    $xo->endTag();
                }
                $xo->endTag();
            }
        }

        my $images = $self->get_auction_image_records( AuctionKey =>$rcd->{ AuctionKey } );
        $self->{ Debug  } ge "1" ? ( $self->update_log( "Image count for auction: ".scalar( @$images ) ) ) :();

        if ( scalar( @$images ) > 0 ) {

            $xo->startTag( "Images" );

            foreach my $i ( @$images ) {

                my $r = $self->get_picture_record( PictureKey => $i->{ PictureKey } );

                $xo->startTag( "Image" );

                $xo->startTag( "PictureFileName" );
                $xo->characters( $r->{ PictureFileName } );               
                $xo->endTag();
                $xo->startTag( "PhotoId" );
                $xo->characters( $r->{ PhotoId } );               
                $xo->endTag();
                $xo->startTag( "SellaID" );
                $xo->characters( $r->{ SellaID } );               
                $xo->endTag();

                $xo->endTag();
            }
            $xo->endTag();                
        }

        $xo->endTag();
        $counter++;
    }

    $xo->endTag();
    $xo->endTag();
    $xo->endTag();
    $xo->end();

}

#=============================================================================================
# Method    : set_XML_elem_value
# Added     : 29/08/05
# Input     : Input field name, input field data
# Returns   : data converted to format to be included in XML file
#
#=============================================================================================

sub set_XML_elem_value {

    my $self    = shift;
    my $p       = { @_ };
    my $outval;

    # Turned off logging statement as it is too noisy
    # $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    $self->clear_err_structure();

    if ( $p->{ Tag } eq "Description" ) {
        
        $outval = Unicode::String->new( $p->{ Value } );
        return $outval;
    }

    if ( $p->{ Tag } eq "Usernotes" ) {

        $outval = Unicode::String->new( $p->{ Value } );
        return $outval;
    }

    if ( $p->{ Tag } eq "DurationHours" ) {

        $outval = Unicode::String->new( $p->{ Value } );
        return $outval;
    }

    if ( $p->{ Tag } eq "DateLoaded" ) {

        $p->{ Value } =~ m/(^.+?)( )(.+$)/;
        $outval = $1;
        return $outval;
    }
    
    if ( $p->{ Tag } eq "CloseDate" ) {

        $p->{ Value } =~ m/(^.+?)( )(.+$)/;
        $outval = $1;
        return $outval;
    }
    
    if  ( $p->{ Tag } eq "CloseTime" ) {

        $p->{ Value } =~ m/(^.+?)( )(.+$)/;
        $outval = $3;
        return $outval;
    }

    if ( $p->{ Tag } eq "TemplateKey" ) {

        if ( $p->{ Value } eq "" )      { $outval = 0               ; } 
        else                            { $outval = $p->{ Value }   ; } 
        return $outval;
    }
    
    if ( $p->{ Tag } eq "RelistStatus" ) {

        if    ( $p->{ Value } eq 0 )     { $outval = "NORELIST"     ; } 
        elsif ( $p->{ Value } eq 1 )     { $outval = "UNTILSOLD"    ; } 
        elsif ( $p->{ Value } eq 2 )     { $outval = "WHILESTOCK"   ; } 
        elsif ( $p->{ Value } eq 3 )     { $outval = "PERMANENT"    ; } 
        return $outval;
    }
    
    if ( ( $p->{ Tag } eq "Held"                ) or
         ( $p->{ Tag } eq "OfferProcessed"      ) or 
         ( $p->{ Tag } eq "AuctionSold"         ) or 
         ( $p->{ Tag } eq "NotifyWatchers"      ) or 
         ( $p->{ Tag } eq "UseTemplate"         ) or 
         ( $p->{ Tag } eq "MovieConfirm"        ) or 
         ( $p->{ Tag } eq "IsNew"               ) or 
         ( $p->{ Tag } eq "TMBuyerEmail"        ) or 
         ( $p->{ Tag } eq "ClosedAuction"       ) or 
         ( $p->{ Tag } eq "AutoExtend"          ) or 
         ( $p->{ Tag } eq "BankDeposit"         ) or 
         ( $p->{ Tag } eq "CreditCard"          ) or 
         ( $p->{ Tag } eq "CashOnPickup"        ) or 
         ( $p->{ Tag } eq "EFTPOS"              ) or 
         ( $p->{ Tag } eq "Quickpay"            ) or 
         ( $p->{ Tag } eq "AgreePayMethod"      ) or 
         ( $p->{ Tag } eq "SafeTrader"          ) or 
         ( $p->{ Tag } eq "FreeShippingNZ"      ) or 
         ( $p->{ Tag } eq "Featured"            ) or 
         ( $p->{ Tag } eq "Gallery"             ) or 
         ( $p->{ Tag } eq "BoldTitle"           ) or 
         ( $p->{ Tag } eq "FeatureCombo"        ) or 
         ( $p->{ Tag } eq "HomePage"            ))   { 

        if ( $p->{ Value } )            { $outval = "Yes"           ; } 
        else                            { $outval = "No"            ; } 
        return $outval;
    }

    if ( $p->{ Tag } eq "AttributeCategory" ) {

        if ( $p->{ Value } eq "" )      { $outval = 0               ; } 
        else                            { $outval = $p->{ Value }   ; } 
        return $outval;
    }

    if ( $p->{ Tag } eq "MovieRating" ) {
        
        if    ( $p->{ Value } eq 1 )    { $outval = "G"             ; } 
        elsif ( $p->{ Value } eq 2 )    { $outval = "PG"            ; } 
        elsif ( $p->{ Value } eq 3 )    { $outval = "M"             ; } 
        elsif ( $p->{ Value } eq 4 )    { $outval = "R13"           ; } 
        elsif ( $p->{ Value } eq 5 )    { $outval = "R15"           ; } 
        elsif ( $p->{ Value } eq 6 )    { $outval = "R16"           ; } 
        elsif ( $p->{ Value } eq 7 )    { $outval = "R18"           ; } 
        return $outval;
    }

    if ( $p->{ Tag } eq "PickupOption" ) {
        
        if    ( $p->{ Value } eq 0 )    { $outval = "Not Selected"    ; } 
        elsif ( $p->{ Value } eq 1 )    { $outval = "Allow"           ; } 
        elsif ( $p->{ Value } eq 2 )    { $outval = "Demand"          ; } 
        elsif ( $p->{ Value } eq 3 )    { $outval = "Forbid"          ; } 
        return $outval;
    }

    if ( $p->{ Tag } eq "ShippingOption" ) {

        if ( $p->{ AuctionSite } eq "TRADEME" ) {
            if    ( $p->{ Value } eq 0 )     { $outval = "Not Selected"    ; } 
            elsif ( $p->{ Value } eq 1 )     { $outval = "Undecided"       ; } 
            elsif ( $p->{ Value } eq 2 )     { $outval = "Free"            ; } 
            elsif ( $p->{ Value } eq 3 )     { $outval = "Custom"          ; } 
            return $outval;
        }
        elsif ( $p->{ AuctionSite } eq "SELLA" ) {
            if    ( $p->{ Value } eq 0 )     { $outval = "Not Selected"    ; } 
            elsif ( $p->{ Value } eq 1 )     { $outval = "Free"            ; } 
            elsif ( $p->{ Value } eq 2 )     { $outval = "Org"             ; } 
            elsif ( $p->{ Value } eq 3 )     { $outval = "Other"           ; } 
            return $outval;
        }
    }
        
    $outval = $p->{ Value };
    
    return $outval;

}

#=============================================================================================
# Method    : get_xml_field_list
# Added     : 29/08/05
# Input     : None
# Returns   : List of fields to be included in XML processing
#
#=============================================================================================

sub get_xml_field_list {

    my $self = shift;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    $self->clear_err_structure();

    my @XMLlist = ( "AuctionKey         "   ,
                    "Title              "   ,  
                    "Subtitle           "   ,  
                    "Description        "   ,             
                    "ProductType        "   ,             
                    "ProductCode        "   ,             
                    "ProductCode2       "   ,             
                    "SupplierRef        "   ,             
                    "LoadSequence       "   ,             
                    "Held               "   ,             
                    "AuctionCycle       "   ,             
                    "AuctionStatus      "   ,             
                    "RelistStatus       "   ,             
                    "AuctionSold        "   ,             
                    "StockOnHand        "   ,             
                    "RelistCount        "   ,             
                    "NotifyWatchers     "   ,             
                    "UseTemplate        "   ,             
                    "TemplateKey        "   ,             
                    "AuctionRef         "   ,             
                    "SellerRef          "   ,             
                    "DateLoaded         "   ,             
                    "CloseDate          "   ,             
                    "CloseTime          "   ,             
                    "Category           "   ,             
                    "MovieRating        "   ,             
                    "MovieConfirm       "   ,             
                    "AttributeCategory  "   ,             
                    "AttributeName      "   ,             
                    "AttributeValue     "   ,             
                    "TMATT104           "   ,             
                    "TMATT104_2         "   ,             
                    "TMATT106           "   ,             
                    "TMATT106_2         "   ,             
                    "TMATT108           "   ,             
                    "TMATT108_2         "   ,             
                    "TMATT111           "   ,             
                    "TMATT112           "   ,             
                    "TMATT115           "   ,             
                    "TMATT117           "   ,             
                    "TMATT118           "   ,             
                    "TMATT038           "   ,             
                    "TMATT163           "   ,             
                    "TMATT164           "   ,             
                    "IsNew              "   ,             
                    "TMBuyerEmail       "   ,             
                    "StartPrice         "   ,             
                    "ReservePrice       "   ,             
                    "BuyNowPrice        "   ,             
                    "OfferPrice         "   ,             
                    "OfferProcessed     "   ,             
                    "EndType            "   ,             
                    "DurationHours      "   ,             
                    "EndDays            "   ,             
                    "EndTime            "   ,             
                    "ClosedAuction      "   ,             
                    "BankDeposit        "   ,             
                    "CreditCard         "   ,             
                    "CashOnPickup       "   ,             
                    "AgreePayMethod     "   ,             
                    "EFTPOS             "   ,             
                    "Quickpay           "   ,             
                    "SafeTrader         "   ,             
                    "PaymentInfo        "   ,             
                    "FreeShippingNZ     "   ,             
                    "ShippingInfo       "   ,             
                    "PickupOption       "   ,             
                    "ShippingOption     "   ,             
                    "Featured           "   ,             
                    "Gallery            "   ,             
                    "BoldTitle          "   ,             
                    "FeatureCombo       "   ,             
                    "HomePage           "   ,             
                    "CopyCount          "   ,             
                    "Message            "   ,             
                    "UserDefined01      "   ,
                    "UserDefined02      "   ,
                    "UserDefined03      "   ,
                    "UserDefined04      "   ,
                    "UserDefined05      "   ,
                    "UserDefined06      "   ,
                    "UserDefined07      "   ,
                    "UserDefined08      "   ,
                    "UserDefined09      "   ,
                    "UserDefined10      "   ,
                    "UserStatus         "   ,
                    "UserNotes          "   ,
                    );

    return @XMLlist;

}

#=============================================================================================
# Method    : list_xml_picturenames
# Added     : 8/05/06
# Input     : None
# Returns   : List of fields to be included in XML processing
#
#=============================================================================================

sub list_xml_picturenames {

    my $self    = shift;
    my $input = {@_};

    my $picdata;
    my $piclist;
    my $piccount = 1;
    
    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    $self->clear_err_structure();


    # Global Variables for nested subroutines

    my $e;
    my $key;
    my $picname;

    # Define the XML Hanlders as Local Subroutines

    #------------------------------------------------------------------------------
    # List XML Pictgures ; Element start
    #------------------------------------------------------------------------------

    local *lxp_elem_start = sub {

        my( $expat, $name, %atts ) = @_;

        $e = $name;

        # Clear the picture record

        if ( $name eq "PictureFileName" )   {
            $picname = "";
        } 

    };

    #------------------------------------------------------------------------------
    # Element data
    #------------------------------------------------------------------------------

    local *lxp_elem_data = sub {

        my( $expat, $data ) = @_;

        chomp $data;    

        if ( $e eq "PictureFileName" ) {
            unless ( $data =~ m/^\s+$/) { 
                $picname .=$data;
            }
        }
    };

    #------------------------------------------------------------------------------
    # Element End
    #------------------------------------------------------------------------------

    local *lxp_elem_end = sub {

        my( $expat, $name ) = @_;

        if ( $name eq "PictureFileName" ) {
            unless ( $picname eq "") {
                unless ( $piclist->{ $picname } eq "1" ) {
                    $piclist->{ $picname } = "1";
                    $piccount++;
                }
            }
        }
    };


    # Initialise the parser and set the category array record handler

    my $parser = XML::Parser->new( Handlers=> {     Start   =>  \&lxp_elem_start    ,
                                                    Char    =>  \&lxp_elem_data     ,
                                                    End     =>  \&lxp_elem_end      } );

    $parser->parsefile( $input->{ Filename } ) ;

    $picdata->{ Count } = $piccount;
    $picdata->{ Data  } = $piclist;
        
    return $picdata;

}

#=============================================================================================
# Method    : get_xml_properties
# Added     : 8/05/06
# Input     : None
# Returns   : List of known document properties/attributes to control processing
#
#=============================================================================================

sub get_xml_properties {

    my $self    = shift;
    my $input = {@_};
    
    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    $self->clear_err_structure();
    
    # Comman Variables for XML Handler subroutines

    my %att;
    my $e;

    # Define the XML handler routines as local subroutines

    #------------------------------------------------------------------------------
    # Element start
    #------------------------------------------------------------------------------

    local *gxp_elem_start = sub {

        my( $expat, $name, %atts ) = @_;

        $e = $name;

    };

    #------------------------------------------------------------------------------
    # Element data
    #------------------------------------------------------------------------------

    local *gxp_elem_data = sub {

        my( $expat, $data ) = @_;

        chomp $data;    

        # clean out XML entities from the element data

        $data =~ s/&/&/g;
        $data =~ s/</&lt;/g;

        if  ( $e eq "AuctionitisDatabase" )     { 

                $att{ DocType } = "Auctionitis-Export";
        }

        if (( $e eq "ExportVersion"       )     or
            ( $e eq "PublishDate"         )     or 
            ( $e eq "FileDescription"     )     or 
            ( $e eq "TradeMeID"           )     or 
            ( $e eq "CategoryServiceDate" )     or 
            ( $e eq "RecordCount"         ))    { 

            $att{ $e } .= $data;
        }
    };


    # Initialise the parser and set the category array record handler

    my $parser = XML::Parser->new( Handlers=> {     Start   =>  \&gxp_elem_start    ,
                                                    Char    =>  \&gxp_elem_data     } );
    
    $parser->parsefile( $input->{ Filename } ) ;

    return \%att;
}

#=============================================================================================
# Method    : import_XML
# Added     : 04/07/06
# Input     : 
# Returns   : 
#
#=============================================================================================

sub import_XML {

    my $self    = shift;
    my $input = {@_};
    my %fieldlist;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    $self->clear_err_structure();

    # Callbacks to update progress bar

    my $msgsub = $input->{ Feedback };
    my $prgsub = $input->{ Progress };

    # Hashes to hold selections for XML processing testing

    my $AS = $input->{ AuctionStatus   };    # Auction Statuses
    my $RS = $input->{ RelistStatus    };    # Relist Statuses
    my $PT = $input->{ ProductType     };    # Product Types
    my $AC = $input->{ AuctionCycle    };    # Auction Cycles
    my $HS = $input->{ HeldStatus      };    # Held statuses

    while( ( my $status, my $value) = each ( %$AS ) ) {
    
        $self->update_log( "Auction Status: ". $status ); 
    }

    while( ( my $status, my $value) = each ( %$RS ) ) {
    
        $self->update_log( " Relist Status: ". $status ); 
    }
    
    while( ( my $status, my $value) = each ( %$PT ) ) {
    
        $self->update_log( "  Product Type: ". $status ); 
    }
    
    while( ( my $status, my $value) = each ( %$AC ) ) {
    
        $self->update_log( " Auction Cycle: ". $status ); 
    }
    
    while( ( my $status, my $value) = each ( %$HS ) ) {
    
        $self->update_log( "   Held Status: ". $status ); 
    }
    
    if ($msgsub) {
         &$msgsub("Importing XML data");
    }

    # Initialise the XML Input document

    my $xmlfile = $input->{ FileName };
    $self->update_log( "Importing XML Data from ".$xmlfile );                

    #------------------------------------------------------------------------------
    # Document Validation
    #------------------------------------------------------------------------------
    
    # Validate that the input is a valid XML construct
    
    my $parser = XML::Parser->new( ErrorContext => 2 );
    
    eval { $parser->parsefile( $xmlfile ); };
    
    if ( $@ ) {
        $self->update_log( "XML Input File Failed validation" );
        $self->update_log(  "XML Validation Error Data:\n--\n$@\n\n" );
        $self->{ErrorStatus}    = "1";
        $self->{ErrorMessage}   = "XML Input File is not valid. Processing terminated.";
        $self->{ErrorDetail}    = "Check the Auctionitis Logfile for additional data";
        return;
    }
    else {
        $self->update_log( "XML Input File passed validation" );
    }

    # Common Variables for XML IMport function(s)

    my %rec;
    my $e;
    my $desc;
    my $notes;
    my @ship_options;
    my %image;
    my @images;
    my %ship_data;
    my $invalidrec;

    my $counter = 1;

    # Define XML event Handlers as Local Subroutines

    #------------------------------------------------------------------------------
    # Element start
    #------------------------------------------------------------------------------

    local *ximp_elem_start = sub {

        my( $expat, $name, %atts ) = @_;

        $e = $name;

        if ( $name eq "AuctionRecord" ) {

            # Dump the Attributes to the log for debugging

            if ( $self->{ Debug } ge "1" ) {
                while( ( my $key, my $value ) = each( %atts ) ) {
                    $self->update_log( "Auction Record Attribute; ".$key. " Value: ".$value );
                }
            }

            # set progress total via call back

            if ( $prgsub ) {
                &$prgsub( $counter );
            }

            $self->update_log( "Processing XML record ".$counter );                
            $counter++;

            # Clear all the data from the previous record

            while( ( my $key, my $value ) = each( %rec ) ) {
                delete( $rec{ $key } );
            }

            # Clear the shipping details placeholders

            undef @ship_options;
            undef %ship_data;

            # Clear the picture record

            undef @images;
            undef %image;

            $desc   = "";

            $notes   = "";

            # Set the Auction Site processing Context using the AuctionSite Attribute

            $rec{ AuctionSite } = $atts{ AuctionSite };
        }

        # Handle clearing the repeated/nested elements without losing previous data

        if ( $name eq "Option" ) {
            delete( $ship_data{ Cost } );
            delete( $ship_data{ Text } );
        }

        if ( $name eq "Image" ) {
            delete( $image{ PictureFileName } );
            delete( $image{ PhotoId } );
            delete( $image{ SellaID } );
        }
    };

    #------------------------------------------------------------------------------
    # Element data
    #------------------------------------------------------------------------------

    local *ximp_elem_data = sub {

        my( $expat, $data ) = @_;

        chomp $data;    

        # clean out XML entities from the element data

        $data =~ s/&/&/g;
        $data =~ s/</&lt;/g;

        if ( ( $e eq "AuctionKey"          )     or
             ( $e eq "Title"               )     or 
             ( $e eq "Subtitle"            )     or 
             ( $e eq "ProductType"         )     or 
             ( $e eq "ProductCode"         )     or 
             ( $e eq "ProductCode2"        )     or 
             ( $e eq "SupplierRef"         )     or 
             ( $e eq "LoadSequence"        )     or 
             ( $e eq "AuctionCycle"        )     or 
             ( $e eq "AuctionStatus"       )     or 
             ( $e eq "StockOnHand"         )     or 
             ( $e eq "RelistCount"         )     or 
             ( $e eq "TemplateKey"         )     or 
             ( $e eq "AuctionRef"          )     or 
             ( $e eq "SellerRef"           )     or 
             ( $e eq "DateLoaded"          )     or 
             ( $e eq "CloseDate"           )     or 
             ( $e eq "CloseTime"           )     or 
             ( $e eq "Category"            )     or 
             ( $e eq "MovieRating"         )     or 
             ( $e eq "AttributeCategory"   )     or 
             ( $e eq "AttributeName"       )     or 
             ( $e eq "AttributeValue"      )     or 
             ( $e eq "TMATT104"            )     or 
             ( $e eq "TMATT104_2"          )     or 
             ( $e eq "TMATT106"            )     or 
             ( $e eq "TMATT106_2"          )     or 
             ( $e eq "TMATT108"            )     or 
             ( $e eq "TMATT108_2"          )     or 
             ( $e eq "TMATT111"            )     or 
             ( $e eq "TMATT112"            )     or 
             ( $e eq "TMATT115"            )     or 
             ( $e eq "TMATT117"            )     or 
             ( $e eq "TMATT118"            )     or 
             ( $e eq "TMATT038"            )     or 
             ( $e eq "TMATT163"            )     or 
             ( $e eq "TMATT164"            )     or 
             ( $e eq "EndType"             )     or 
             ( $e eq "EndDays"             )     or 
             ( $e eq "EndTime"             )     or 
             ( $e eq "StartPrice"          )     or 
             ( $e eq "ReservePrice"        )     or 
             ( $e eq "BuyNowPrice"         )     or 
             ( $e eq "OfferPrice"          )     or 
             ( $e eq "PaymentInfo"         )     or
             ( $e eq "ShippingInfo"        )     or 
             ( $e eq "CopyCount"           )     or 
             ( $e eq "Message"             )     or 
             ( $e eq "UserDefined01"       )     or 
             ( $e eq "UserDefined02"       )     or 
             ( $e eq "UserDefined03"       )     or 
             ( $e eq "UserDefined04"       )     or 
             ( $e eq "UserDefined05"       )     or 
             ( $e eq "UserDefined06"       )     or 
             ( $e eq "UserDefined07"       )     or 
             ( $e eq "UserDefined08"       )     or 
             ( $e eq "UserDefined09"       )     or 
             ( $e eq "UserDefined10"       )     or 
             ( $e eq "UserStatus"          ) )   { 

                ( $rec{ $e } .= $data ) =~ s/\s+$//;
        }

        if ( ( $e eq "Held"                )     or
             ( $e eq "OfferProcessed"      )     or 
             ( $e eq "AuctionSold"         )     or 
             ( $e eq "NotifyWatchers"      )     or 
             ( $e eq "UseTemplate"         )     or 
             ( $e eq "MovieConfirm"        )     or 
             ( $e eq "IsNew"               )     or 
             ( $e eq "TMBuyerEmail"        )     or 
             ( $e eq "ClosedAuction"       )     or 
             ( $e eq "BankDeposit"         )     or 
             ( $e eq "CreditCard"          )     or 
             ( $e eq "CashOnPickup"        )     or 
             ( $e eq "AgreePayMethod"      )     or 
             ( $e eq "EFTPOS"              )     or 
             ( $e eq "Quickpay"            )     or 
             ( $e eq "SafeTrader"          )     or 
             ( $e eq "FreeShippingNZ"      )     or 
             ( $e eq "Featured"            )     or 
             ( $e eq "Gallery"             )     or 
             ( $e eq "BoldTitle"           )     or 
             ( $e eq "FeatureCombo"        )     or 
             ( $e eq "HomePage"            ) )   { 

            if    ( $data =~ m/.*Yes.*/sg )     { $rec{ $e } = -1; } 
            if    ( $data =~ m/.*No.*/sg  )     { $rec{ $e } = 0;  } 
        }

        if ( $e eq "Paragraph" ) {
            unless ( $data =~ m/^\s+$/ ) { 
                $desc .= $data ;
            }
        }

        if ( $e eq "Note" ) {
            unless ( $data =~ m/^\s+$/ ) { 
                $notes .= $data ;
            }
        }

        if ( $e eq "DurationHours" ) {
            unless ( $data =~ m/^\s*$/ ) { 
                ( $rec{ $e } .= $data ) =~ s/\s+$//;
            }
        }

        if ( $e eq "RelistStatus" ) {
            if ( $rec{ AuctionSite } eq "TRADEME" ) {
                if    ( $data eq "NORELIST"     )     { $rec{ $e } = 0 ; } 
                elsif ( $data eq "UNTILSOLD"    )     { $rec{ $e } = 1 ; } 
                elsif ( $data eq "WHILESTOCK"   )     { $rec{ $e } = 2 ; } 
                elsif ( $data eq "PERMANENT"    )     { $rec{ $e } = 3 ; }
            }
            elsif (  $rec{ AuctionSite } eq "SELLA" ) {
               { $rec{ $e } = 0 ; }
            }
        }

        if ( $e eq "MovieRating" ) {
            if ( $rec{ AuctionSite } eq "TRADEME" ) {
                if    ( $data eq "G"            )     { $rec{ $e } = 1 ; } 
                elsif ( $data eq "PG"           )     { $rec{ $e } = 2 ; } 
                elsif ( $data eq "M"            )     { $rec{ $e } = 3 ; } 
                elsif ( $data eq "R13"          )     { $rec{ $e } = 4 ; } 
                elsif ( $data eq "R15"          )     { $rec{ $e } = 5 ; } 
                elsif ( $data eq "R16"          )     { $rec{ $e } = 6 ; } 
                elsif ( $data eq "R18"          )     { $rec{ $e } = 7 ; } 
                else                                  { $rec{ $e } = 0 ; }
            }
            elsif (  $rec{ AuctionSite } eq "SELLA" ) {
               $rec{ $e } = 0 ;
            }
        }

        if ( $e eq "PickupOption" ) {
            if    ( $data eq "Not Selected" )     { $rec{ $e } = 0 ; } 
            elsif ( $data eq "Allow"        )     { $rec{ $e } = 1 ; } 
            elsif ( $data eq "Demand"       )     { $rec{ $e } = 2 ; } 
            elsif ( $data eq "Forbid"       )     { $rec{ $e } = 3 ; } 
        }

        if ( $e eq "ShippingOption" ) {
            if ( $rec{ AuctionSite } eq "TRADEME" ) {
                if    ( $data eq "Not Selected" )     { $rec{ $e } = 0 ; } 
                elsif ( $data eq "Undecided"    )     { $rec{ $e } = 1 ; } 
                elsif ( $data eq "Free"         )     { $rec{ $e } = 2 ; } 
                elsif ( $data eq "Custom"       )     { $rec{ $e } = 3 ; } 
            }
            elsif ( $rec{ AuctionSite } eq "SELLA" ) {
                if    ( $data eq "Not Selected" )     { $rec{ $e } = 0 ; } 
                elsif ( $data eq "Free"         )     { $rec{ $e } = 1 ; } 
                elsif ( $data eq "Org"          )     { $rec{ $e } = 2 ; } 
                elsif ( $data eq "Other"        )     { $rec{ $e } = 3 ; } 
            }
        }

        if ( $e eq "ShippingCost" ) {
            if ( $rec{ AuctionSite } eq "TRADEME" ) {
                unless ( $data =~ m/^\s+$/ ) { 
                    $ship_data{ Cost } .= $data ;
                }
            }
        }

        if ( $e eq "ShippingText" ) {
            if ( $rec{ AuctionSite } eq "TRADEME" ) {
                unless ( $data =~ m/^\s+$/ ) { 
                    $ship_data{ Text } .= $data ;
                }
            }
        }

        if ( $e eq "PictureFileName" ) {
            unless ( $data =~ m/^\s+$/){ 
                $image{ PictureFileName } .= $data;
            }
        }

        if ( $e eq "PhotoId" ) {
            unless ( $data =~ m/^\s+$/){ 
                $image{ PhotoId }  .= $data;
            }
        }

        if ( $e eq "SellaID" ) {
            unless ( $data =~ m/^\s+$/){ 
                $image{ SellaID }  .= $data;
            }
        }
    };

    #------------------------------------------------------------------------------
    # Element End
    #------------------------------------------------------------------------------

    local *ximp_elem_end = sub {

        my( $expat, $name ) = @_;

        if ( $name eq "Description" )   {

            $rec{ Description } = $desc;
        }

        if ( $name eq "Paragraph" )     {

            # Add the data and the mem field CRLF value for each paragraph 

            $desc .= "\n";
        }

        if ( $name eq "UserNotes" )     {

            $rec{ UserNotes } = $notes;
        }

        if ( $name eq "Note" )          {

            $notes .= "\n";
        }

        if ( $name eq "Option" )        {

            $self->update_log( "Storing shipping options; Cost: ".$ship_data{ Cost }."\t Text: ".$ship_data{ Text } );
            
            if ( %ship_data ) {
                push ( @ship_options, { %ship_data } );
            }
        }

        if ( $name eq "Image" )        {

            $self->update_log( "Storing Image ".$image{ PictureFileName }."; Trade Me ID: ".$image{ PhotoId }."; Sella ID: ".$image{ SellaID } );
            
            if ( %image ) {
                push ( @images, { %image } );
            }
        }

        if ( $name eq "AuctionRecord" ) {

            # Set values that are sitespecific in case of crap XML

            if ( $rec{ AuctionSite } eq "TRADEME" ) {
                $rec{ EFTPOS            } = 0;
                $rec{ Quickpay          } = 0;
                $rec{ AgreePayMethod    } = 0;
            }
            elsif ( $rec{ AuctionSite } eq "SELLA" ) {
                $rec{ MovieRating       } = 0; 
                $rec{ MovieConfirm      } = 0; 
                $rec{ AttributeCategory } = 0; 
                $rec{ AttributeName     } = ""; 
                $rec{ AttributeValue    } = ""; 
                $rec{ TMATT104          } = ""; 
                $rec{ TMATT104_2        } = ""; 
                $rec{ TMATT106          } = ""; 
                $rec{ TMATT106_2        } = ""; 
                $rec{ TMATT108          } = ""; 
                $rec{ TMATT108_2        } = ""; 
                $rec{ TMATT111          } = ""; 
                $rec{ TMATT112          } = ""; 
                $rec{ TMATT115          } = ""; 
                $rec{ TMATT117          } = ""; 
                $rec{ TMATT118          } = ""; 
                $rec{ TMATT038          } = ""; 
                $rec{ TMATT163          } = ""; 
                $rec{ TMATT164          } = ""; 
                $rec{ OfferPrice        } = 0; 
                $rec{ OfferProcessed    } = 0; 
                $rec{ RelistStatus      } = 0;
                $rec{ BuyerEmail        } = 0;
                $rec{ NotifyWatchers    } = 0;
                $rec{ ClosedAuction     } = 0;
                $rec{ SafeTrader        } = 0;
                $rec{ Gallery           } = 0;
                $rec{ BoldTitle         } = 0;
                $rec{ Featured          } = 0;
                $rec{ FeatureCombo      } = 0;
                $rec{ HomePage          } = 0;
            }

            $self->update_log( "Updating database with imported record" );
        
            # Check the auction details match the selection criteria

            if  ( ( ( $AS->{ $rec{ AuctionStatus } } ) or ( $AS->{ ALL } ) )
            and   ( ( $RS->{ $rec{ RelistStatus  } } ) or ( $RS->{ ALL } ) )
            and   ( ( $PT->{ $rec{ ProductType   } } ) or ( $PT->{ ALL } ) )
            and   ( ( $AC->{ $rec{ AuctionCycle  } } ) or ( $AC->{ ALL } ) )
            and   ( ( $HS->{ $rec{ Held          } } ) or ( $HS->{ ALL } ) ) ) {

                $self->update_log( "XML Import Criteria matched" );

                # check to make sure wearenot overwriting an existing auction record (i.e. has an auction ref)
                # Templates,CLones etc. dont matter s omuch

                if ( $rec{ AuctionRef } eq "" or not $self->is_DBauction_104( $rec{ AuctionRef } ) ) {
                
                    # Write auction record

                    $self->update_log( "Adding Auction record to database for record $rec{ AuctionKey }" );
                    
                    # if debug mode is on update the log with the individual field entries

                    if ( $self->{Debug} ge "2" ) {
                        while(( my $key, my $value) = each(%rec)) {
                            $self->update_log( "Field: ".$key."\t Data: ".$rec{ $key } );
                        }
                    }
                    
                    # Convert newlines to memo eol value in database 

                    $rec{ Description   } =~ s/\n/\x0D\x0A/g;           # change newlines to mem cr/lf combo   
                    $rec{ UserNotes     } =~ s/\n/\x0D\x0A/g;           # change newlines to mem cr/lf combo   

                    my $auctionkey = $self->add_auction_record_202( %rec );

                    if ( @images ) {
                    
                        my $seq = 1;
                        
                        $self->update_log( "Adding Images to Auction Record" );

                        foreach my $i ( @images ) {

                            # Get the Picture key from the picture file; if picture does not exist add it

                            my $pickey = $self->get_picture_key( PictureFileName => $i->{ PictureFileName } );

                            if ( defined ( $pickey ) ) {
                                $self->update_log( "Picture ".$i->{ PictureFileName }." (".$pickey.") FOUND in database");
                            }
                            else {
                                $self->add_picture_record( PictureFileName => $i->{ PictureFileName } );
                                $pickey = $self->get_picture_key( PictureFileName =>  $i->{ PictureFileName } );
                                $self->update_log( "NEW Picture ".$i->{ PictureFileName }." (".$pickey.") ADDED to database");
                            }

                            # Update the imported picture IDs

                            $self->update_picture_record(
                                PictureKey      =>  $pickey         ,
                                PhotoId         =>  $i->{ PhotoId } ,
                                SellaID         =>  $i->{ SellaID } ,
                            );

                            $self->update_log( "Updated Picture Record with TradeMe ID: ".$i->{ PhotoId }."; Sella ID: ".$i->{ SellaID } );

                            $self->add_auction_images_record(
                                AuctionKey      =>   $auctionkey    ,          
                                PictureKey      =>   $pickey        ,          
                                ImageSequence   =>   $seq           ,           
                            );

                            $self->update_log( "Added Image record for Auction Key: ".$auctionkey."; Picture Key: ".$pickey."; Seq: ".$seq );

                            $seq++;
                        }
                    }
                    
                    if ( @ship_options and scalar( @ship_options > 1 ) ) {
                    
                        my $seq = 1;
                        
                        $self->update_log( "Adding Shipping Details to Auction Record" );

                        foreach my $option ( @ship_options ) {
                        
                            $self->update_log( "Seq: ".$seq."\tCost: ".$option->{ Cost }."\t Text: ".$option->{ Text } );
                            
                            $self->add_shipping_details_record(
                                AuctionKey                 =>   $auctionkey         ,          
                                Shipping_Details_Seq       =>   $seq                ,           
                                Shipping_Details_Cost      =>   $option->{ Cost }   ,           
                                Shipping_Details_Text      =>   $option->{ Text }   ,          
                                Shipping_Option_Code       =>   ""                  ,          
                            );
                            $seq++;
                        }
                    }
                }
                
                else {
                    $self->update_log( "Auction record not added - Auction ref ".$rec{ AuctionRef }." already exists" );
                }
            }
        }
    };

    # Initialise the parser and set the category array record handler

    $parser = XML::Parser->new( Handlers=> {     Start   =>  \&ximp_elem_start   ,
                                                    Char    =>  \&ximp_elem_data    ,
                                                    End     =>  \&ximp_elem_end     } );

    if ( $xmlfile ) {
        $parser->parsefile( $xmlfile ) ;
    }         
    
}

#=============================================================================================
# Method    : replace_auction_text
# Added     : 26/04/08
# Input     : hash containing parameters: AuctionKey, SearchString, ReplaceString, UpdateTitle,
#             UpdateDescription. UpdateTitle and UpdateDescription are boolean values
# Returns   : 
#
# This function will replace the tesxt in the Auction Description and optiionally the title
#=============================================================================================

sub replace_auction_text {

    my $self        = shift;
    my $p           = { @_};

    $self->{ Debug } ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;
    $self->clear_err_structure();

    my $SQLStmt ;
    
   # SQL to get list of auctions from data base
    
    $SQLStmt = qq { 
        SELECT  AuctionKey,
                Title,
                Description
        FROM    Auctions  
        WHERE   AuctionKey          = ? 
    };
    
    my $SQLSelect = $dbh->prepare( $SQLStmt );
    
    # SQL to Update Description fields in Auction record
    
    $SQLStmt = qq { 
        UPDATE  Auctions  
        SET     Title               = ? ,
                Description         = ?
        WHERE   AuctionKey          = ? 
    };
    
    my $SQLUpdate = $dbh->prepare( $SQLStmt );
    $SQLUpdate->bind_param( 2, $SQLUpdate, DBI::SQL_LONGVARCHAR );   
    
    # Retrieve the auction
    
    $SQLSelect->execute( $p->{ AuctionKey } );
    
    my $auction = $SQLSelect->fetchrow_hashref();
 
    $self->update_log( "Processing Auction: ".$auction->{ Title } );

    if ( $p->{ UpdateTitle } ) {

        $auction-> { Title } =~ s/$p->{ SearchString }/$p->{ ReplaceString }/g;

        if (  length( $auction-> { Title } ) > 50 ) {

            $self->update_log( "Error updating Auction - Title would exceed maximum allowed length (50)" );

            # return 1 to indicate failure
            
            return 1;
        }
    }

    if ( $p->{ UpdateDescription } ) {

        $auction-> { Description } =~ s/$p->{ SearchString }/$p->{ ReplaceString }/g ;

        # If the description would be longer than it should be then return without updating
        # update this to include calculating the length of the standard terms and conditions

        if (  length( $auction-> { Description } ) > 2016 ) {

            $self->update_log( "Error updating Auction - Description would exceed allowed length (2016)" );

            # return 1 to indicate success

            return 1;
        }

    }
    $SQLUpdate->execute(
        $auction-> { Title          },
        $auction-> { Description    },
        $auction-> { AuctionKey     }, 
    );

    $SQLUpdate->finish;
    $SQLSelect->finish;

    # return 0 to indicate success

    return 0;

}

#*********************************************************************************************
# --- DataBase property routines
#*********************************************************************************************

#=============================================================================================
# Method    : get_DB_property
# Added     : 31/07/06
# Input     : Property Name
# Returns   : String with property value or undef
#=============================================================================================

sub get_DB_property  {

    my $self    = shift;
    my $parms   = {@_};

    my $DBProperty;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    $self->clear_err_structure();

    # Check that a default value has been supplied

    if     ( not defined( $parms->{ Property_Default } ) ) {    

            $self->{ ErrorStatus    }    = "1";
            $self->{ ErrorMessage   }    = "Default value not supplied for property".$parms->{ Property_Name };
            $self->{ ErrorDetail    }    = "";
            return undef;
    }

    # Create SQL Statement to retrieve record
    
    my $SQLStmt = qq {
        SELECT      Property_Value
        FROM        DBProperties
        WHERE     (  Property_Name = ? )
    } ;

    my $sth = $dbh->prepare( $SQLStmt );
    
    $sth->execute( $parms->{ Property_Name } );

    $DBProperty = $sth->fetchrow_hashref;

    $sth->finish;

    # If the record was found return the details otherwise populate the error structure

    if ( defined($DBProperty) ) {    

        return $DBProperty->{ Property_Value };
          
    }
    else {

        $self->update_log("DB Property ".$parms->{ Property_Name }." not found; default value " .$parms->{ Property_Default }." used");
        return $parms->{ Property_Default };
    }
}

#=============================================================================================
# Method    : set_DB_property
# Added     : 31/07/06
# Input     : hash containing field values
# Returns   : 
#
# This function will set a value
#=============================================================================================

sub set_DB_property {

    my $self    = shift;
    my $parms   = {@_};

    my $DBProperty;
    my $record;
    
    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    # Clear error indicator and error message properties

    $self->clear_err_structure();

    # Retrieve the property value to see if it exists

    my $SQLStmt = ( qq {
        SELECT      *
        FROM        DBProperties
        WHERE     ( Property_Name = ?   )
    } );

    my $sth = $dbh->prepare( $SQLStmt );
    
    $sth->execute( $parms->{ Property_Name } );

    $DBProperty = $sth->fetchrow_hashref;

    $sth->finish;

    # If the property was found update it with the new value otherwise insert the property

    if ( defined( $DBProperty->{ Property_Name } ) ) {    

        $SQLStmt = ( qq {
            UPDATE      DBProperties 
            SET         Property_Value = ?   
            WHERE       Property_Name  = ?   
        } );

        $self->update_log("Updating DB Property ".$parms->{ Property_Name }." Old value: " .$DBProperty->{ Property_Value });

        $sth = $dbh->prepare( $SQLStmt ) || die "Error preparing statement: $DBI::errstr\n";
        $sth->execute(  
            "$parms->{ Property_Value        }"    , 
            "$parms->{ Property_Name         }"    , 
        );
        
        $sth->finish;

        $self->update_log("Updating DB Property ".$parms->{ Property_Name }." New value: " .$parms->{ Property_Value });

    }

    else {

        $SQLStmt = ( qq {
            INSERT INTO DBProperties 
                      ( Property_Name        ,
                        Property_Value       )
            VALUES    ( ?,?                  )
        } );

        $sth = $dbh->prepare( $SQLStmt ) || die "Error preparing statement: $DBI::errstr\n";
        $sth->execute(  
            "$parms->{ Property_Name         }"    , 
            "$parms->{ Property_Value        }"    , 
        );
        
        $sth->finish;

        $self->update_log("Added DB Property ".$parms->{ Property_Name }." Value: " .$parms->{ Property_Value });
    }

}

#=============================================================================================
# Method    : get_TM_sold_csv_file
# Added     : 07/08/2007
# Input     : Option Hash as follows:
#           : Filename - name of file to save extracted data to
#           : Days     - number of days to download
#
# This method retreieves the Trademe Sold CSV file and writes it to a file on disk
#=============================================================================================

sub get_TM_sold_csv_file {

    my $self    = shift;
    my $p       = {@_};

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    # Clear error indicator and error message properties

    $self->clear_err_structure();

    # Make an entry in the log recording the target file name

    $self->update_log( "Extracting TradeMe Sales data to file ".$p->{ Filename } );

    # Retrieve the sales export from the Trademe web page

    $url= "http://www.trademe.co.nz/MyTradeMe/Export/MyListingsCSV.aspx";

    $p->{ Days } = "all";

    $req = POST $url,
    
    [   "ListingType"       =>  "Sold"              ,
        "filter"            =>  $p->{ Selection }   ,
        "show_deleted"      =>  1                   ,
    ] ;

    $content = $ua->request( $req )->content();

    # Open the file for output - Use binary  mode to avoid additional CR/LF's

    open ( CSV, "> $p->{ Filename }" );
    binmode CSV;
    print CSV "$content";

}

#=============================================================================================
# Method    : get_TM_unsold_csv_file
# Added     : 07/08/2007
# Input     : Option Hash as follows:
#           : Filename - name of file to save extracted data to
#           : Days     - number of days to download
# Returns   : Array of Hashes containg each cell of CSV spreadsheet
#
# This method retreieves the Trademe Sold CSV file and writes it to a file on disk
#=============================================================================================

sub get_TM_unsold_csv_file {

    my $self    = shift;
    my $p       = {@_};

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    # Clear error indicator and error message properties

    $self->clear_err_structure();

    # Make an entry in the log recording the target fiel name

    $self->update_log( "Extracting TradeMe Unsold data to file ".$p->{ Filename } );

    # Retrieve the sales export from the Trademe web page

    $url= "http://www.trademe.co.nz/MyTradeMe/Export/MyListingsCSV.aspx";

    $p->{ Days } = "all";

    $req = POST $url,
    
    [   "ListingType"       =>  "Unsold"            ,
        "filter"            =>  $p->{ Selection }   ,
        "show_deleted"      =>  1                   ,
    ] ;

    $content = $ua->request( $req )->content();

    # Open the file for output - Use binary  mode to avoid additional CR/LF's

    open ( CSV, "> $p->{ Filename }" );
    binmode CSV;
    print CSV "$content";

}

#=============================================================================================
# Method    : get_TM_current_csv_file
# Added     : 07/08/2007
# Input     : Option Hash as follows:
#           : Filename - name of file to save extracted data to
#           : Days     - number of days to download
# Returns   : Array of Hashes containg each cell of CSV spreadsheet
#
# This method retreieves the Trademe Sold CSV file and writes it to a file on disk
#=============================================================================================

sub get_TM_current_csv_file {

    my $self    = shift;
    my $p       = {@_};

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    # Clear error indicator and error message properties

    $self->clear_err_structure();

    # Make an entry in the log recording the target fiel name

    $self->update_log( "Extracting TradeMe Current Auction data to file ".$p->{ Filename } );

    # Retrieve the sales export from the Trademe web page

    $url= "http://www.trademe.co.nz/MyTradeMe/Export/MyListingsCSV.aspx";

    $p->{ Days } = "all";

    $req = POST $url,
    
    [   "ListingType"       =>  "Current"           ,
        "filter"            =>  $p->{ Selection }   ,
        "show_deleted"      =>  1                   ,
    ] ;

    $content = $ua->request( $req )->content();

    # Open the file for output - Use binary  mode to avoid additional CR/LF's

    open ( CSV, "> $p->{ Filename }" );
    binmode CSV;
    print CSV "$content";

}

#=============================================================================================
# Method    : get_TM_statement_csv_file
# Added     : 07/08/2007
# Input     : Option Hash as follows:
#           : Filename - name of file to save extracted data to
#           : Days     - number of days to download
# Returns   : Array of Hashes containg each cell of CSV spreadsheet
#
# This method retreieves the Trademe Sold CSV file and writes it to a file on disk
#=============================================================================================

sub get_TM_statement_csv_file {

    my $self    = shift;
    my $p       = {@_};

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    # Clear error indicator and error message properties

    $self->clear_err_structure();

    # Make an entry in the log recording the target fiel name

    $self->update_log( "Extracting TradeMe Staement data to file ".$p->{ Filename } );

    # Retrieve the sales export from the Trademe web page

    $url= "http://www.trademe.co.nz/MyTradeMe/Export/LedgerCSV.aspx";

    $p->{ Days } = "45";

    $req = POST $url,
    
    [   "days"              =>  $p->{ Selection }   ,
    ] ;

    $content = $ua->request( $req )->content();

    # Open the file for output - Use binary  mode to avoid additional CR/LF's

    open ( CSV, "> $p->{ Filename }" );
    binmode CSV;
    print CSV "$content";

}


#*********************************************************************************************
# --- Sold! Subroutines --- V 1.0
#*********************************************************************************************

#=============================================================================================
# Method    : connect_to_sales_db
# Added     : 22/03/06
# Input     : Database Name (optional)
# Returns   : 
#
# This function connects to the Sold! database; if an argument is supplied Auctionitis
# will attempt to connect to the supplied ODBC connection name, otherwise it will connect to
# the default data source name stored in the Registry
#=============================================================================================

sub connect_to_sales_DB {

    my $self  = shift;
    my $DB    = shift;
    
    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    if (not defined $DB ) { $DB = $self->{DataBaseName} }

    # $sdb=DBI->connect('dbi:ODBC:'.$DB, {AutoCommit => 1} ) 
    $sdb=DBI->connect('dbi:ODBC:Sold', {AutoCommit => 1} ) 
         || die "Error opening Auctions database: $DBI::errstr\n";
        
    $sdb->{LongReadLen} = 65555;            # cater for retrieval of memo fields

    my $SQLStmt = qq {
        INSERT INTO DataChangeLog
                  ( Operation       ,
                    Operation_Date  ,           
                    Operation_Time  ,           
                    Operation_Table ,           
                    Operation_Column,           
                    Operation_Before,
                    Operation_After )
        VALUES    ( ?,?,?,?,?,?,?   )
    } ;

    $sth_DCLog = $sdb->prepare( $SQLStmt );
    $sth_DCLog->bind_param(6, $sth_DCLog, DBI::SQL_LONGVARCHAR);
    $sth_DCLog->bind_param(7, $sth_DCLog, DBI::SQL_LONGVARCHAR);
        
}

#=============================================================================================
# Method    : DBDisconnect    
# Added     : 19/03/06
# Input     : 
# Returns   : 
#
# This function disconnects Auctionitis from the currently connnected database; 
#=============================================================================================

sub disconnect_sales_DB {

    my $self  = shift;
    
    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    $sth_DCLog->finish;
        
    $sdb->disconnect    || warn $sdb->errstr;
}


#=============================================================================================
# Method    : update_DC_Log
# Added     : 19/03/06
# Input     : Hash value sindicating what was updated
# Returns   : 
#
# This function logs changes to the various database tables
#=============================================================================================

sub update_DC_Log {

    my $self  = shift;
    my $parms   = {@_};

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    # Clear error indicator and error message properties

    $self->clear_err_structure();

    if ( $self->{ DBLogging } ) {

        $sth_DCLog->execute(
            "$parms->{ Operation        }"  ,
             $self->datenow                 ,    
             $self->timenow                 ,    
            "$parms->{ Operation_Table  }"  ,    
            "$parms->{ Operation_Column }"  ,    
            "$parms->{ Operation_Before }"  ,    
            "$parms->{ Operation_After  }"  )    
             || die "Insert Sold Record - Error executing statement: $DBI::errstr\n";
    }

}


#=============================================================================================
# Method    : get_TM_raw_sales_record    
# Added     : 22/03/05
# Input     : Auction Reference #
# Returns   : Boolean
#
# This method returns true or false based on whether the auction reference is found in the
# TM Raw sales file or not
#=============================================================================================

sub get_TM_raw_sales_key {

    my $self    =   shift;
    my $parms   = {@_};
    
    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    # Clear error indicator and error message properties

    $self->clear_err_structure();

    # Create SQL Statement string

    my $SQLStmt = qq {
        SELECT        Record_ID
        FROM          TMRawSales
        WHERE         Auction_Ref = ?
    } ;

    my $sth = $sdb->prepare($SQLStmt) || die "Error preparing statement: $DBI::errstr\n";
    
    $sth->execute( $parms->{ Auction_Ref } ) || die "Error exexecuting statement: $DBI::errstr\n";
    
    my $Record_ID = $sth->fetchrow_array;

    $sth->finish;

    return $Record_ID;

}

#=============================================================================================
# Method    : add_TM_raw_sales_record
# Added     : 19/03/06
# Input     : hash containing field values
# Returns   : 
#
# This function will add a record to the TMRawSales table
#=============================================================================================

sub add_TM_raw_sales_record {

    my $self    = shift;
    my $parms   = {@_};

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    # Clear error indicator and error message properties

    $self->clear_err_structure();

    # write the change record to the log (must be done before record values changed)

    $self->update_log("Insert Record: TMRawSales; ");
    
    while( (my $key, my $value) = each(%$parms) ) {
        $self->update_DC_Log(
            Operation           =>  "INSERT"            ,     
            Operation_Table     =>  "TMRawSales"        ,
            Operation_Column    =>  $key                ,
            Operation_Before    =>  ""                  ,
            Operation_After     =>  $parms->{ $key }    ,
        );
    }

    # Create SQL Statement string

    my $SQLStmt = qq {
        INSERT INTO TMRawSales
                  ( Auction_Ref         ,
                    Title               ,
                    Category            ,           
                    Sold_Date           ,           
                    Sold_Time           ,           
                    Sale_Type           ,           
                    Sale_Price          ,
                    Ship_Cost1          ,
                    Ship_Text1          ,
                    Ship_Cost2          ,
                    Ship_Text2          ,
                    Ship_Cost3          ,
                    Ship_Text3          ,
                    Ship_Cost4          ,
                    Ship_Text4          ,
                    Ship_Cost5          ,
                    Ship_Text5          ,
                    Ship_Cost6          ,
                    Ship_Text6          ,
                    Ship_Cost7          ,
                    Ship_Text7          ,
                    Ship_Cost8          ,
                    Ship_Text8          ,
                    Ship_Cost9          ,
                    Ship_Text9          ,
                    Ship_Cost10         ,
                    Ship_Text10         ,
                    Pickup_Text         ,
                    Buyer_Name          ,
                    Buyer_Email         ,           
                    Buyer_Address       ,           
                    Buyer_Postcode      ,           
                    Buyer_Message       ,           
                    Listing_Fee         ,           
                    Promo_Fee           ,           
                    Success_Fee         ,           
                    Refund_Status       ,           
                    Start_Price         ,           
                    Reserve_Price       ,           
                    BuyNow_Price        ,           
                    Start_Date          ,           
                    Start_Time          ,
                    Duration            ,           
                    Restrictions        ,           
                    Featured            ,
                    Gallery             ,
                    Bold                ,
                    Homepage            ,
                    Extra_Photos        ,
                    Scheduled_End       ,
                    B_W_Count           ,
                    View_Count          )
        VALUES    ( ?,?,?,?,?,?,?,?,?,?,
                    ?,?,?,?,?,?,?,?,?,?,
                    ?,?,?,?,?,?,?,?,?,?,
                    ?,?,?,?,?,?,?,?,?,?,
                    ?,?,?,?,?,?,?,?,?,?,
                    ?,?                 )
    } ;

    my $sth = $sdb->prepare($SQLStmt) || die "Error preparing statement: $DBI::errstr\n";

    # Execute the SQL Statement           

    $sth->bind_param(31, $sth, DBI::SQL_LONGVARCHAR);
    $sth->bind_param(33, $sth, DBI::SQL_LONGVARCHAR);
    
    $sth->execute(
        "$parms->{ Auction_Ref      }"  ,
        "$parms->{ Title            }"  ,    
        "$parms->{ Category         }"  ,    
        "$parms->{ Sold_Date        }"  ,    
        "$parms->{ Sold_Time        }"  ,    
        "$parms->{ Sale_Type        }"  ,    
         $parms->{ Sale_Price       }   ,    
         $parms->{ Ship_Cost1       }   , 
        "$parms->{ Ship_Text1       }"  , 
         $parms->{ Ship_Cost2       }   , 
        "$parms->{ Ship_Text2       }"  , 
         $parms->{ Ship_Cost3       }   , 
        "$parms->{ Ship_Text3       }"  , 
         $parms->{ Ship_Cost4       }   , 
        "$parms->{ Ship_Text4       }"  , 
         $parms->{ Ship_Cost5       }   , 
        "$parms->{ Ship_Text5       }"  , 
         $parms->{ Ship_Cost6       }   , 
        "$parms->{ Ship_Text6       }"  , 
         $parms->{ Ship_Cost7       }   , 
        "$parms->{ Ship_Text7       }"  , 
         $parms->{ Ship_Cost8       }   , 
        "$parms->{ Ship_Text8       }"  , 
         $parms->{ Ship_Cost9       }   , 
        "$parms->{ Ship_Text9       }"  , 
         $parms->{ Ship_Cost10      }   , 
        "$parms->{ Ship_Text10      }"  , 
        "$parms->{ Pickup_Text      }"  , 
        "$parms->{ Buyer_Name       }"  ,    
        "$parms->{ Buyer_Email      }"  ,    
        "$parms->{ Buyer_Address    }"  ,    
         $parms->{ Buyer_Postcode   }   ,    
        "$parms->{ Buyer_Message    }"  ,    
         $parms->{ Listing_Fee      }   ,    
         $parms->{ Promo_Fee        }   ,    
         $parms->{ Success_Fee      }   ,    
        "$parms->{ Refund_Status    }"  ,    
         $parms->{ Start_Price      }   ,    
         $parms->{ Reserve_Price    }   ,    
         $parms->{ BuyNow_Price     }   ,    
        "$parms->{ Start_Date       }"  ,    
        "$parms->{ Start_Time       }"  , 
        "$parms->{ Duration         }"  ,    
        "$parms->{ Restrictions     }"  ,    
         $parms->{ Featured         }   ,    
         $parms->{ Gallery          }   ,    
         $parms->{ Bold             }   ,    
         $parms->{ Homepage         }   ,    
         $parms->{ Extra_Photos     }   ,    
         $parms->{ Scheduled_End    }   ,    
         $parms->{ B_W_Count        }   ,    
         $parms->{ View_Count       }   )    
         || $self->Handle_SQL_Error("Insert Sold Record", $SQLStmt, $DBI::errstr, $parms);

    $sth->finish;

}

sub Handle_SQL_Error {

    my $self    = shift;
    my $routine = shift;
    my $SQL     = shift;
    my $errstr  = shift;
    my $errdata = shift;
    
    print "DBI Error encountered\n"         ;
    print "Routine in error: $routine\n"    ;
    print "   SQL Statement: $SQL\n"        ;
    print "   Error message: $errstr\n"     ;
    print "Error Data:\n"                   ;
    
    while( (my $key, my $value) = each(%$errdata) ) {
        print "Field: $key\n"               ;
        print "Value: $value\n"             ;
    }
}

#=============================================================================================
# Method    : get_TM_raw_sales_record
# Added     : 23/03/06
# Input     : list of auction keys
# Returns   : Array of hash references
#
# This method returns the details of auctions in the input list if they are not held 
#=============================================================================================

sub get_TM_raw_sales_record  {

    my $self    = shift;
    my $parms   = {@_};

    my $TM_raw_sales_record;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    $self->clear_err_structure();

    # Create SQL Statement to retrieve record
    
    my $SQLStmt = ( qq {
        SELECT      *
        FROM        TMRawSales
        WHERE     ( Record_ID = ?   )
    } );


    my $sth = $sdb->prepare( $SQLStmt );
    
    $sth->execute( $parms->{ Record_ID } );

    $TM_raw_sales_record = $sth->fetchrow_hashref;

    $sth->finish;

    # If the record was found return the details otherwise populate the error structure

    if     ( defined($TM_raw_sales_record) ) {    

            return $TM_raw_sales_record;
            
    } else {
    
            $self->{ErrorStatus}    = "1";
            $self->{ErrorMessage}   = "Record ID $parms->{ RecordID } not found in TMRawSales table";
            $self->{ErrorDetail}    = "";
            return undef;
    }
}

#=============================================================================================
# Method    : update_TM_raw_sales_record   
# Added     : 10/04/05
# Input     : Hash with <Input Field> => <New Value> pairs
#           : The RecordID => <record ID> pair is mandatory
# Returns   : 
#=============================================================================================

sub update_TM_raw_sales_record {

    my $self = shift;
    my $parms = {@_};
    my $record;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    $self->clear_err_structure();

    # Retrieve the current record from the database and update "Record" data-Hash

    $record = $self->get_TM_raw_sales_record( Record_ID =>$parms->{ Record_ID } );

    if  ( $self->{ Debug } ge "2" ) {    
        $self->update_log("Input parameters:");
        while( ( my $key, my $value ) = each( %$parms ) ) {
            $self->update_log("$key \t:\t $value");
        }
    }

    # write the change record to the log (must be done before record values changed)

    $self->update_log("Update Table: TMRawSales; Record Key: $parms->{ Record_ID }");
    
    while( (my $key, my $value) = each(%$record) ) {
        $self->update_DC_Log(
            Operation           =>  "UPDATE"            ,     
            Operation_Table     =>  "TMRawSales"        ,
            Operation_Column    =>  $key                ,
            Operation_Before    =>  $record->{ $key }   ,
            Operation_After     =>  $parms->{ $key }    ,
        );
    }

    # Read through the input record and alter the corresponding field in the "Record" hash

    while ((my $key, my $value) = each(%{ $parms })) {

        $record->{$key} = $value;
    }

    # Create the SQL Statement

    my $SQLStmt = qq { 

        UPDATE  TMRawSales  
        SET     Auction_Ref     = ?,          
                Title           = ?,
                Category        = ?,
                Sold_Date       = ?,
                Sold_Time       = ?,
                Sale_Type       = ?,
                Sale_Price      = ?,
                Ship_Cost1      = ?,
                Ship_Text1      = ?,
                Ship_Cost2      = ?,
                Ship_Text2      = ?,
                Ship_Cost3      = ?,
                Ship_Text3      = ?,
                Ship_Cost4      = ?,
                Ship_Text4      = ?,
                Ship_Cost5      = ?,
                Ship_Text5      = ?,
                Ship_Cost6      = ?,
                Ship_Text6      = ?,
                Ship_Cost7      = ?,
                Ship_Text7      = ?,
                Ship_Cost8      = ?,
                Ship_Text8      = ?,
                Ship_Cost9      = ?,
                Ship_Text9      = ?,
                Ship_Cost10     = ?,
                Ship_Text10     = ?,
                Pickup_Text     = ?,
                Buyer_Name      = ?,
                Buyer_Email     = ?,
                Buyer_Address   = ?,
                Buyer_Postcode  = ?,
                Buyer_Message   = ?,
                Listing_Fee     = ?,
                Promo_Fee       = ?,
                Success_Fee     = ?,
                Refund_Status   = ?,
                Start_Price     = ?,
                Reserve_Price   = ?,
                BuyNow_Price    = ?,
                Start_Date      = ?,
                Start_Time      = ?,
                Duration        = ?,
                Restrictions    = ?,
                Featured        = ?,
                Gallery         = ?,
                Bold            = ?,
                Homepage        = ?,
                Extra_Photos    = ?,
                Scheduled_End   = ?,
                B_W_Count       = ?,
                View_Count      = ?
        WHERE   Record_ID       = ? 
    };

    # Prepare the SQL Statement
    
    my $sth = $sdb->prepare($SQLStmt) || die "Error preparing statement: $DBI::errstr\n";

    $sth->bind_param(31, $sth, DBI::SQL_LONGVARCHAR);
    $sth->bind_param(33, $sth, DBI::SQL_LONGVARCHAR);
    
    # Update the database with the new updated "Record" hash

    $sth->execute(
        "$record->{ Auction_Ref      }"  ,
        "$record->{ Title            }"  ,
        "$record->{ Category         }"  ,
        "$record->{ Sold_Date        }"  ,
        "$record->{ Sold_Time        }"  ,
        "$record->{ Sale_Type        }"  ,
         $record->{ Sale_Price       }   ,
         $record->{ Ship_Cost1       }   ,
        "$record->{ Ship_Text1       }"  ,
         $record->{ Ship_Cost2       }   ,
        "$record->{ Ship_Text2       }"  ,
         $record->{ Ship_Cost3       }   ,
        "$record->{ Ship_Text3       }"  ,
         $record->{ Ship_Cost4       }   ,
        "$record->{ Ship_Text4       }"  ,
         $record->{ Ship_Cost5       }   ,
        "$record->{ Ship_Text5       }"  ,
         $record->{ Ship_Cost6       }   ,
        "$record->{ Ship_Text6       }"  ,
         $record->{ Ship_Cost7       }   ,
        "$record->{ Ship_Text7       }"  ,
         $record->{ Ship_Cost8       }   ,
        "$record->{ Ship_Text8       }"  ,
         $record->{ Ship_Cost9       }   ,
        "$record->{ Ship_Text9       }"  ,
         $record->{ Ship_Cost10      }   ,
        "$record->{ Ship_Text10      }"  ,
        "$record->{ Pickup_Text      }"  ,
        "$record->{ Buyer_Name       }"  ,
        "$record->{ Buyer_Email      }"  ,
        "$record->{ Buyer_Address    }"  ,
         $record->{ Buyer_Postcode   }   ,
        "$record->{ Buyer_Message    }"  ,
         $record->{ Listing_Fee      }   ,
         $record->{ Promo_Fee        }   ,
         $record->{ Success_Fee      }   ,
        "$record->{ Refund_Status    }"  ,
         $record->{ Start_Price      }   ,
         $record->{ Reserve_Price    }   ,
         $record->{ BuyNow_Price     }   ,
        "$record->{ Start_Date       }"  ,
        "$record->{ Start_Time       }"  ,
        "$record->{ Duration         }"  ,
        "$record->{ Restrictions     }"  ,
         $record->{ Featured         }   ,
         $record->{ Gallery          }   ,
         $record->{ Bold             }   ,
         $record->{ Homepage         }   ,
         $record->{ Extra_Photos     }   ,
         $record->{ Scheduled_End    }   ,
         $record->{ B_W_Count        }   ,
         $record->{ View_Count       }   ,
         $record->{ Record_ID        }   )
         || die .((caller(0))[3])." - Error executing statement: $DBI::errstr\n";

    $sth->finish;

}                            

#=============================================================================================
# Method    : get_addressbook_key   
# Added     : 22/03/05
# Input     : Address book shortname #
# Returns   : PersondID (primary key) or undef
#
# This method returns the primary key for the input short name otherwise it returned undef
#=============================================================================================

sub get_addressbook_key {

    my $self    = shift;
    my $parms   = {@_};
    
    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    # Clear error indicator and error message properties

    $self->clear_err_structure();

    # Create SQL Statement string

    my $SQL = qq {
        SELECT        Person_ID
        FROM          AddressBook
        WHERE         Short_Name = ?
    };

    my $sth = $sdb->prepare($SQL) || die "Error preparing statement: $DBI::errstr\n";
    
    $sth->execute( "$parms->{ Short_Name }" ) || die "Error exexecuting statement: $DBI::errstr\n";
    
    my $Person_ID = $sth->fetchrow_array;

    $sth->finish;
    
    return $Person_ID;

}

#=============================================================================================
# Method    : add_addressbook_record
# Added     : 19/03/06
# Input     : hash containing field values
# Returns   : 
#
# This function will add a record to the Address book table
#=============================================================================================

sub add_addressbook_record {

    my $self    = shift;
    my $parms   = {@_};
    my $record;
    
    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    # Clear error indicator and error message properties

    $self->clear_err_structure();

    # Set default values for new record
    # Key value AuctionKey is defined as Autonumber and will be generated by the database
    
    $record->{ Short_Name           } = ""  ;               
    $record->{ Relationship_ID      } = 1   ;               
    $record->{ Title                } = ""  ;               
    $record->{ First_Name           } = ""  ;                
    $record->{ Last_Name            } = ""  ;               
    $record->{ Company              } = ""  ;               
    $record->{ Email                } = ""  ;               
    $record->{ Alternate_Email      } = ""  ;               
    $record->{ Use_Alternate_Email  } = 0   ;                
    $record->{ Phone                } = ""  ;                
    $record->{ Mobile               } = ""  ;                
    $record->{ Fax                  } = ""  ;                
    $record->{ WebSite              } = ""  ;                
    $record->{ Buyer_Address        } = ""  ;               
    $record->{ Buyer_Postcode       } = 0   ;               
    $record->{ Use_Alternate_Address} = 0   ;       
    $record->{ Alternate_Address    } = ""  ;               
    $record->{ Alternate_Postcode   } = 0   ;                
    $record->{ Country              } = ""  ;               
    $record->{ Notes                } = ""  ;               
    $record->{ Blacklist            } = 0   ;               
    $record->{ Trade_Again          } = 0   ;               
    $record->{ Preferred            } = 0   ;               
    $record->{ Mailing_List         } = 0   ;               

    # write the change record to the log (must be done before record values changed)

    $self->update_log("Insert Record: AddressBook; ");
    
    while( (my $key, my $value) = each(%$parms) ) {
        $self->update_DC_Log(
            Operation           =>  "INSERT"            ,     
            Operation_Table     =>  "AddressBook"       ,
            Operation_Column    =>  $key                ,
            Operation_Before    =>  ""                  ,
            Operation_After     =>  $parms->{ $key }    ,
        );
    }
    
    # Read through the input values and alter the corresponding fields in the "Record" hash

    while ( ( my $key, my $value ) = each( %{ $parms } ) ) {
            $record->{ $key } = $value;
    }

    # Create SQL Statement string

    my $SQLStmt = qq {
        INSERT INTO AddressBook 
                  ( Short_Name           ,
                    Relationship_ID      ,
                    Title                ,           
                    First_Name           ,           
                    Last_Name            ,           
                    Company              ,           
                    Email                ,
                    Alternate_Email      ,
                    Use_Alternate_Email  ,
                    Phone                ,           
                    Mobile               ,           
                    Fax                  ,           
                    WebSite              ,           
                    Buyer_Address        ,           
                    Buyer_Postcode       ,           
                    Use_Alternate_Address,           
                    Alternate_Address    ,
                    Alternate_Postcode   ,           
                    Country              ,
                    Notes                ,
                    Blacklist            ,
                    Trade_Again          ,
                    Preferred            ,
                    Mailing_List         )
        VALUES    ( ?,?,?,?,?,?,?,?,?,?,
                    ?,?,?,?,?,?,?,?,?,?,
                    ?,?,?,?              )
    } ;

    my $sth = $sdb->prepare($SQLStmt) || die "Error preparing statement:\n SQL: $SQLStmt\n $DBI::errstr\n";

    # Additional setup for field 25 (Notes) as it is a memo field    
    
    $sth->bind_param(14, $sth, DBI::SQL_LONGVARCHAR);
    $sth->bind_param(17, $sth, DBI::SQL_LONGVARCHAR);
    $sth->bind_param(20, $sth, DBI::SQL_LONGVARCHAR);

    # Execute the SQL Statement           
    
    $sth->execute(  
        "$record->{ Short_Name              }"    , 
         $record->{ Relationship_ID         }     , 
        "$record->{ Title                   }"    , 
        "$record->{ First_Name              }"    , 
        "$record->{ LastName                }"    , 
        "$record->{ Company                 }"    , 
        "$record->{ Email                   }"    , 
        "$record->{ Alternate_Email         }"    , 
         $record->{ Use_Alternate_Email     }     , 
        "$record->{ Phone                   }"    , 
        "$record->{ Mobile                  }"    , 
        "$record->{ Fax                     }"    , 
        "$record->{ WebSite                 }"    , 
        "$record->{ Buyer_Address           }"    , 
         $record->{ Buyer_Postcode          }     , 
         $record->{ Use_Alternate_Address   }     , 
        "$record->{ Alternate_Address       }"    , 
         $record->{ Alternate_Postcode      }     , 
        "$record->{ Country                 }"    , 
        "$record->{ Notes                   }"    , 
         $record->{ Blacklist               }     , 
         $record->{ Trade_Again             }     , 
         $record->{ Preferred               }     , 
         $record->{ Mailing_List            }     )
         || die .((caller(0))[3])." - Error executing statement:\n SQL: $SQLStmt\n $DBI::errstr\n";

    $sth->finish;

}


#=============================================================================================
# Method    : get_addressbook_record
# Added     : 23/03/06
# Input     : list of auction keys
# Returns   : Array of hash references
#=============================================================================================

sub get_addressbook_record  {

    my $self    = shift;
    my $parms   = {@_};

    my $addressbook_record;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    $self->clear_err_structure();

    # Create SQL Statement to retrieve record
    
    my $SQLStmt = ( qq {
        SELECT      *
        FROM        AddressBook
        WHERE     ( Person_ID = ?   )
    } );


    my $sth = $sdb->prepare( $SQLStmt );
    
    $sth->execute( $parms->{ Person_ID } )|| die "Error retrieving address book record: $DBI::errstr\n";

    $addressbook_record = $sth->fetchrow_hashref;

    $sth->finish;

    # If the record was found return the details otherwise populate the error structure

    if     ( defined($addressbook_record) ) {    

            return $addressbook_record;
            
    } else {
    
            $self->{ErrorStatus}    = "1";
            $self->{ErrorMessage}   = "Record ID $parms->{ Person_ID } not found in AddressBook table";
            $self->{ErrorDetail}    = "";
            return undef;
    }
}

#=============================================================================================
# Method    : update_addressbook_record  
# Added     : 23/03/05
# Input     : Hash with <Input Field> => <New Value> pairs
#           : The Person_ID => <person ID> pair is mandatory
# Returns   : 
#=============================================================================================

sub update_addressbook_record {

    my $self = shift;
    my $parms = {@_};
    my $record;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    $self->clear_err_structure();

    # Retrieve the current record from the database and update "Record" data-Hash

    $record = $self->get_addressbook_record( Person_ID => $parms->{ Person_ID } );

    if  ( $self->{Debug} ge "2" ) {    
        $self->update_log("Input parameters:");
        while( ( my $key, my $value ) = each( %$parms ) ) {
            $self->update_log("$key \t:\t $value");
        }
    }

    # write the change record to the log (must be done before record values changed)

    $self->update_log("Update Table: AddressBook; Record Key: $parms->{ Person_ID }");
    
    while( (my $key, my $value) = each(%$record) ) {
        $self->update_DC_Log(
            Operation           =>  "UPDATE"            ,     
            Operation_Table     =>  "AddressBook"       ,
            Operation_Column    =>  $key                ,
            Operation_Before    =>  $record->{ $key }   ,
            Operation_After     =>  $parms->{ $key }    ,
        );
    }

    # Read through the input record and alter the corresponding field in the "Record" hash

    while ( ( my $key, my $value ) = each( %{ $parms } ) ) {
        $record->{ $key } = $value;
    }

    # Create the SQL Statement

    my $SQLStmt = qq { 

        UPDATE  AddressBook               
        SET     Short_Name              = ?,  
                Relationship_ID         = ?,  
                Title                   = ?,  
                First_Name              = ?,   
                Last_Name               = ?,  
                Company                 = ?,  
                Email                   = ?,  
                Alternate_Email         = ?,  
                Use_Alternate_Email     = ?,  
                Phone                   = ?,  
                Mobile                  = ?,  
                Fax                     = ?,  
                Website                 = ?,  
                Buyer_Address           = ?,        
                Buyer_Postcode          = ?,        
                Use_Alternate_Address   = ?,          
                Alternate_Address       = ?,  
                Alternate_Postcode      = ?,        
                Country                 = ?,  
                Notes                   = ?,  
                Blacklist               = ?,  
                Trade_Again             = ?,  
                Preferred               = ?,  
                Mailing_List            = ?   
        WHERE   Person_ID               = ?           
    };                                  

    # Prepare the SQL Statement

    my $sth = $sdb->prepare($SQLStmt) || die "Error preparing statement: $DBI::errstr\n";

    # Additional setup for field 25 (Notes) as it is a memo field    
    
    $sth->bind_param(14, $sth, DBI::SQL_LONGVARCHAR);
    $sth->bind_param(17, $sth, DBI::SQL_LONGVARCHAR);
    $sth->bind_param(20, $sth, DBI::SQL_LONGVARCHAR);
    
    # Update the database with the new updated "Record" hash

    $sth->execute(
        "$record->{ Short_Name              }"    , 
         $record->{ Relationship_ID         }     , 
        "$record->{ Title                   }"    , 
        "$record->{ First_Name              }"    , 
        "$record->{ LastName                }"    , 
        "$record->{ Company                 }"    , 
        "$record->{ Email                   }"    , 
        "$record->{ Alternate_Email         }"    , 
         $record->{ Use_Alternate_Email     }     , 
        "$record->{ Phone                   }"    , 
        "$record->{ Mobile                  }"    , 
        "$record->{ Fax                     }"    , 
        "$record->{ WebSite                 }"    , 
        "$record->{ Buyer_Address           }"    , 
         $record->{ Buyer_Postcode          }     , 
         $record->{ Use_Alternate_Address   }     , 
        "$record->{ Alternate_Address       }"    , 
         $record->{ Alternate_Postcode      }     , 
        "$record->{ Country                 }"    , 
        "$record->{ Notes                   }"    , 
         $record->{ Blacklist               }     , 
         $record->{ Trade_Again             }     , 
         $record->{ Preferred               }     , 
         $record->{ Mailing_List            }     ,
         $record->{ Person_ID               }     ) 
         || die .((caller(0))[3])." - Error executing statement: $DBI::errstr\n";

    $sth->finish;
                             
}                            
        
#=============================================================================================
# Method    : get_sales_key   
# Added     : 22/03/05
# Input     : Sales reference # (Auction Number) and Sale type ID
# Returns   : Sales_ID (primary key) or undef
#
# This method returns the primary key for the input short name otherwise it returned undef
# The two part key is required as TradeMe use the same auction no. for buynow & auction sales
#=============================================================================================

sub get_sales_key {

    my $self    = shift;
    my $parms   = {@_};
    
    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    # Clear error indicator and error message properties

    $self->clear_err_structure();

    # Create SQL Statement string

    my $SQLstmt = qq {
        SELECT        Sale_ID
        FROM          Sales
        WHERE     ( ( Sale_Number   = ? )
        AND         ( Sale_Type     = ? ) )
    };

    my $sth = $sdb->prepare($SQLstmt) || die "Error preparing statement: $DBI::errstr\n";
    
    $sth->execute(
        "$parms->{ Sale_Number }"    ,
        "$parms->{ Sale_Type   }"    )   
        || die "Error exexecuting statement: $DBI::errstr\n";
    
    my $Sales_ID = $sth->fetchrow_array;

    $sth->finish;
    
    return $Sales_ID;

}

#=============================================================================================
# Method    : add_sales_record
# Added     : 19/03/06
# Input     : hash containing field values
# Returns   : 
#
# This function will add a record to the Address book table
#=============================================================================================

sub add_sales_record {

    my $self    = shift;
    my $parms   = {@_};
    my $record;
    
    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    # Clear error indicator and error message properties

    $self->clear_err_structure();

    # write the change record to the log (must be done before record values changed)

    $self->update_log("Insert Record: TMRawSales; ");
    
    while( (my $key, my $value) = each(%$parms) ) {
        $self->update_DC_Log(
            Operation           =>  "INSERT"            ,     
            Operation_Table     =>  "Sales"             ,
            Operation_Column    =>  $key                ,
            Operation_Before    =>  ""                  ,
            Operation_After     =>  $parms->{ $key }    ,
        );
    }

    # Set default values for new record
    # Key value AuctionKey is defined as Autonumber and will be generated by the database
    # No defualt value is set for the date sold field - it is null if nto set
                                             
    $record->{ Account_ID               } = 0   ;             
    $record->{ Person_ID                } = 0   ;             
    $record->{ Sale_Number              } = ""  ;              
    $record->{ Sale_Type                } = ""  ;             
    $record->{ Sale_Reference           } = ""  ;             
    $record->{ Invoice_Number           } = ""  ;             
    $record->{ Sale_Amount              } = 0   ;              
    $record->{ Start_Price              } = 0   ;               
    $record->{ Reserve_Price            } = 0   ;               
    $record->{ Buy_Now_Price            } = 0   ;               
    $record->{ Listing_Fee              } = 0   ;               
    $record->{ Success_Fee              } = 0   ;               
    $record->{ Promotion_Fee            } = 0   ;              
    $record->{ Item_Cost                } = 0   ;              
    $record->{ Postage_Amount           } = 0   ;    
    $record->{ Status_ID                } = 0   ;   
    $record->{ Refund_Status            } = ""  ;     
    $record->{ Buyer_Message            } = ""  ;     
    $record->{ Item_Description         } = ""  ;             
    $record->{ Item_Description_Long    } = ""  ;               
    $record->{ Product_Type             } = ""  ;              
    $record->{ Product_Code             } = ""  ;             
    $record->{ Product_Picture          } = ""  ;             
    $record->{ Cash                     } = 0   ;         
    $record->{ Cheque                   } = 0   ;         
    $record->{ Bank_Deposit             } = 0   ;         
    $record->{ Payment_Info             } = ""  ;             
    $record->{ Free_Shipping_NZ         } = 0   ;         
    $record->{ Shipping_Info            } = ""  ;             
    $record->{ Delivery_Type_ID         } = 0   ;             
    $record->{ Delivery_Reference       } = ""  ;             
    $record->{ Delivery_Address         } = ""  ;             
    $record->{ Delivery_Postcode        } = 0   ;             
    $record->{ Delivery_Address_3       } = ""  ;             
    $record->{ Delivery_Address_4       } = ""  ;             
    $record->{ Special_Instructions     } = ""  ;              
    $record->{ Notes                    } = ""  ;              

    # Read through the input values and alter the corresponding fields in the "Record" hash

    while ( ( my $key, my $value ) = each( %{ $parms } ) ) {
            $record->{ $key } = $value;
    }
    
    # Create SQL Statement string

    my $SQLStmt = qq {
        INSERT INTO Sales 
                  ( Account_ID               ,
                    Person_ID                ,
                    Sale_Number              ,           
                    Sale_Type                ,           
                    Sale_Reference           ,           
                    Invoice_Number           ,           
                    Date_Sold                ,           
                    Time_Sold                ,           
                    Sale_Amount              ,
                    Start_Price              ,
                    Reserve_Price            ,
                    Buy_Now_Price            ,           
                    Listing_Fee              ,           
                    Success_Fee              ,           
                    Promotion_Fee            ,           
                    Item_Cost                ,           
                    Postage_Amount           ,           
                    Status_ID                ,           
                    Refund_Status            ,           
                    Buyer_Message            ,           
                    Item_Description         ,           
                    Item_Description_Long    ,
                    Product_Type             ,           
                    Product_Code             ,           
                    Product_Picture          ,
                    Cash                     ,
                    Cheque                   ,
                    Bank_Deposit             ,
                    Payment_Info             ,
                    Free_Shipping_NZ         ,
                    Shipping_Info            ,
                    Delivery_Type            ,
                    Delivery_Reference       ,
                    Delivery_Address         ,
                    Delivery_Postcode        ,
                    Special_Instructions     ,
                    Notes                    )
        VALUES    ( ?,?,?,?,?,?,?,?,?,?,
                    ?,?,?,?,?,?,?,?,?,?,
                    ?,?,?,?,?,?,?,?,?,?,
                    ?,?,?,?,?,?,?            )
    } ;

    my $sth     =   $sdb->prepare($SQLStmt) || die "Error preparing statement: $DBI::errstr\n";

    # Additional setup for field 19 (Long Description) field 35 (Special Instructions) and
    # field 36 (Notes) as they are memo field    
    
    $sth->bind_param(20, $sth, DBI::SQL_LONGVARCHAR);
    $sth->bind_param(22, $sth, DBI::SQL_LONGVARCHAR);
    $sth->bind_param(34, $sth, DBI::SQL_LONGVARCHAR);
    $sth->bind_param(36, $sth, DBI::SQL_LONGVARCHAR);
    $sth->bind_param(37, $sth, DBI::SQL_LONGVARCHAR);

    # Execute the SQL Statement           
    
    $sth->execute(                                     
         $record->{ Account_ID                }     ,  
         $record->{ Person_ID                 }     ,  
        "$record->{ Sale_Number               }"    ,  
        "$record->{ Sale_Type                 }"    ,  
        "$record->{ Sale_Reference            }"    ,  
        "$record->{ Invoice_Number            }"    ,  
        "$record->{ Date_Sold                 }"    ,  
        "$record->{ Time_Sold                 }"    ,  
         $record->{ Sale_Amount               }     ,  
         $record->{ Start_Price               }     ,  
         $record->{ Reserve_Price             }     ,  
         $record->{ Buy_Now_Price             }     ,  
         $record->{ Listing_Fee               }     ,  
         $record->{ Success_Fee               }     ,  
         $record->{ Promotion_Fee             }     ,  
         $record->{ Item_Cost                 }     ,  
         $record->{ Postage_Amount            }     ,  
         $record->{ Status_ID                 }     ,  
         $record->{ Refund_Status             }     ,  
        "$record->{ Buyer_Message             }"    ,  
        "$record->{ Item_Description          }"    ,  
        "$record->{ Item_Description_Long     }"    ,  
        "$record->{ Product_Type              }"    ,  
        "$record->{ Product_Code              }"    ,  
        "$record->{ Product_Picture           }"    ,  
         $record->{ Cash                      }     ,  
         $record->{ Cheque                    }     ,  
         $record->{ Bank_Deposit              }     ,  
        "$record->{ Payment_Info              }"    ,  
         $record->{ Free_Shipping_NZ          }     ,  
        "$record->{ Shipping_Info             }"    ,  
         $record->{ Delivery_Type             }     ,  
        "$record->{ Delivery_Reference        }"    ,  
        "$record->{ Delivery_Address          }"    ,  
         $record->{ Delivery_Postcode         }     ,  
        "$record->{ Special_Instructions      }"    ,  
        "$record->{ Notes                     }"    )  
         || die .((caller(0))[3])." - Error executing statement: $DBI::errstr\n";

    $sth->finish;

}

#=============================================================================================
# Method    : get_sales_record
# Added     : 23/03/06
# Input     : list of auction keys
# Returns   : Array of hash references
#=============================================================================================

sub get_sales_record  {

    my $self    = shift;
    my $parms   = {@_};

    my $sales_record;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    $self->clear_err_structure();

    # Create SQL Statement to retrieve record
    
    my $SQLStmt = ( qq {
        SELECT      *
        FROM        Sales
        WHERE     ( Sale_ID = ? )
    } );


    my $sth = $sdb->prepare( $SQLStmt );
    
    $sth->execute( $parms->{ Sale_ID } );

    $sales_record = $sth->fetchrow_hashref;

    $sth->finish;

    # If the record was found return the details otherwise populate the error structure

    if     ( defined($sales_record) ) {    

            return $sales_record;
            
    } else {
    
            $self->{ErrorStatus}    = "1";
            $self->{ErrorMessage}   = "Record ID $parms->{ Sales_ID } not found in Sales table";
            $self->{ErrorDetail}    = "";
            return undef;
    }
}

#=============================================================================================
# Method    : update_sales_record  
# Added     : 23/03/05
# Input     : Hash with <Input Field> => <New Value> pairs
#           : The Person_ID => <person ID> pair is mandatory
# Returns   : 
#=============================================================================================

sub update_sales_record {

    my $self = shift;
    my $parms = {@_};
    my $record;

    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    $self->clear_err_structure();

    # Retrieve the current record from the database and update "Record" data-Hash

    $record = $self->get_sales_record( Sale_ID => $parms->{ Sale_ID } );

    if  ( $self->{Debug} ge "2" ) {    
        $self->update_log("Input parameters:");
        while( ( my $key, my $value ) = each( %$parms ) ) {
            $self->update_log("$key \t:\t $value");
        }
    }

    # write the change record to the log (must be done before record values changed)

    $self->update_log("Insert Record: Sales; ");
    
    while( (my $key, my $value) = each(%$parms) ) {
        $self->update_DC_Log(
            Operation           =>  "UPDATE"            ,     
            Operation_Table     =>  "Sales"             ,
            Operation_Column    =>  $key                ,
            Operation_Before    =>  $record->{ $key }   ,
            Operation_After     =>  $parms->{ $key }    ,
        );
    }
    
    # Read through the input record and alter the corresponding field in the "Record" hash

    while ((my $key, my $value) = each(%{ $parms })) {

        $record->{$key} = $value;
    }

    # Create the SQL Statement

    my $SQLStmt = qq { 

        UPDATE  Sales  
        SET     Account_ID              = ?   ,
                Person_ID               = ?   ,
                Sale_Number             = ?   ,           
                Sale_Type               = ?   ,           
                Sale_Reference          = ?   ,           
                Invoice_Number          = ?   ,           
                Date_Sold               = ?   ,           
                Time_Sold               = ?   ,           
                Sale_Amount             = ?   ,
                Start_Price             = ?   ,
                Reserve_Price           = ?   ,
                Buy_Now_Price           = ?   ,           
                Listing_Fee             = ?   ,           
                Success_Fee             = ?   ,           
                Promotion_Fee           = ?   ,           
                Item_Cost               = ?   ,           
                Postage_Amount          = ?   ,           
                Status_ID               = ?   ,           
                Refund_Status           = ?   ,           
                Buyer_Message           = ?   ,           
                Item_Description        = ?   ,           
                Item_Description_Long   = ?   ,
                Product_Type            = ?   ,           
                Product_Code            = ?   ,           
                Product_Picture         = ?   ,
                Cash                    = ?   ,
                Cheque                  = ?   ,
                Bank_Deposit            = ?   ,
                Payment_Info            = ?   ,
                Free_Shipping_NZ        = ?   ,
                Shipping_Info           = ?   ,
                Delivery_Type           = ?   ,
                Delivery_Reference      = ?   ,
                Delivery_Address        = ?   ,
                Delivery_Postcode       = ?   ,
                Special_Instructions    = ?   ,
                Notes                   = ?
        WHERE   Sale_ID                 = ? 
    };

    # Prepare the SQL Statement
    
    my $sth = $sdb->prepare($SQLStmt) || die "Error preparing statement: $DBI::errstr\n";

    # Additional setup for field 19 (Long Description) field 35 (Special Instructions) and
    # field 36 (Notes) as they are memo field    
    
    $sth->bind_param(20, $sth, DBI::SQL_LONGVARCHAR);
    $sth->bind_param(22, $sth, DBI::SQL_LONGVARCHAR);
    $sth->bind_param(34, $sth, DBI::SQL_LONGVARCHAR);
    $sth->bind_param(36, $sth, DBI::SQL_LONGVARCHAR);
    $sth->bind_param(37, $sth, DBI::SQL_LONGVARCHAR);
    
    # Update the database with the new updated "Record" hash

    $sth->execute(
         $record->{ Account_ID                }     ,
         $record->{ Person_ID                 }     ,
        "$record->{ Sale_Number               }"    ,
        "$record->{ Sale_Type                 }"    ,
        "$record->{ Sale_Reference            }"    ,
        "$record->{ Invoice_Number            }"    ,
        "$record->{ Date_Sold                 }"    ,
        "$record->{ Time_Sold                 }"    ,
         $record->{ Sale_Amount               }     ,
         $record->{ Start_Price               }     ,
         $record->{ Reserve_Price             }     ,
         $record->{ Buy_Now_Price             }     ,
         $record->{ Listing_Fee               }     ,
         $record->{ Success_Fee               }     ,
         $record->{ Promotion_Fee             }     ,
         $record->{ Item_Cost                 }     ,
         $record->{ Postage_Amount            }     ,
         $record->{ Status_ID                 }     ,
        "$record->{ Refund_Status             }"    ,
        "$record->{ Buyer_Message             }"    ,
        "$record->{ Item_Description          }"    ,
        "$record->{ Item_Description_Long     }"    ,
        "$record->{ Product_Type              }"    ,
        "$record->{ Product_Code              }"    ,
        "$record->{ Product_Picture           }"    ,
         $record->{ Cash                      }     ,
         $record->{ Cheque                    }     ,
         $record->{ Bank_Deposit              }     ,
         $record->{ Payment_Info              }     ,
         $record->{ Free_Shipping_NZ          }     ,
        "$record->{ Shipping_Info             }"    ,
        "$record->{ Delivery_Type             }"    ,
        "$record->{ Delivery_Reference        }"    ,
        "$record->{ Delivery_Address          }"    ,
         $record->{ Delivery_Postcode         }     ,
        "$record->{ Special_Instructions      }"    ,
        "$record->{ Notes                     }"    ,
         $parms->{  Sale_ID                   }     )
        || die .((caller(0))[3])." - Error executing statement: $DBI::errstr\n";

    $sth->finish;
                             
}

#=============================================================================================
# Method    : add_sales_txn_record
# Added     : 19/03/06
# Input     : hash containing field values
# Returns   : 
#
# This function will add a record to the Address book table
#=============================================================================================

sub add_sales_txn_record {

    my $self    = shift;
    my $parms   = {@_};
    my $record;
    
    $self->{Debug} ge "1" ? ($self->update_log("Invoked Method: ". (caller(0))[3] )) : () ;

    # Clear error indicator and error message properties

    $self->clear_err_structure();

    # Set default values for new record
    # Key value AuctionKey is defined as Autonumber and will be generated by the database
    
    $record->{ Before_Status    } = 0   ;               
    $record->{ After_Status     } = 0   ;               
    $record->{ Txn_Type_ID      } = 0   ;                
    $record->{ Txn_Description  } = ""  ;               
    $record->{ Sale_ID          } = 0   ;               
    $record->{ Txn_Seq          } = 0   ;               
    $record->{ Txn_Date         } = ""  ;               
    $record->{ Txn_Time         } = ""  ;                
    $record->{ Txn_Data         } = ""  ;                

    # Read through the input values and alter the corresponding fields in the "Record" hash

    while ( ( my $key, my $value ) = each( %{ $parms } ) ) {
            $record->{ $key } = $value;
    }
    
    # Create SQL Statement string

    my $SQLStmt = qq {
        INSERT INTO Transactions
                  ( Before_Status   ,
                    After_Status    ,
                    Txn_Type_ID     ,           
                    Txn_Description ,           
                    Sale_ID         ,           
                    Txn_Seq         ,           
                    Txn_Date        ,
                    Txn_Time        ,
                    Txn_Data        )
        VALUES    ( ?,?,?,?,?,?,?,?,? )
    } ;

    my $sth     =   $sdb->prepare($SQLStmt) || die "Error preparing statement: $DBI::errstr\n";

    # Additional setup for field 9 (Txn data) as it is memo field    
    
    $sth->bind_param(9, $sth, DBI::SQL_LONGVARCHAR);

    # Execute the SQL Statement           
    
    $sth->execute(  
         $record->{ Before_Status       }     , 
         $record->{ After_Status        }     , 
         $record->{ Txn_Type_ID         }     , 
        "$record->{ Txn_Description     }"    , 
         $record->{ Sale_ID             }     , 
         $record->{ Txn_Seq             }     , 
        "$record->{ Txn_Date            }"    , 
        "$record->{ Txn_Time            }"    , 
        "$record->{ Txn_Data            }"    )
         || die .((caller(0))[3])." - Error executing statement: $DBI::errstr\n";

    $sth->finish;

}

#*********************************************************************************************
# --- Sella Methods --- V 1.0
#*********************************************************************************************

#=============================================================================================
# Method    : connect_to_sella   
# Added     : 02/02/09
# Input     : 
# Returns   : 1 if connected, else undef
#
# This method connects to Sella and sets the session user ID for subsequet operations
#============================================================================================

sub connect_to_sella {

    my $self = shift;
    my $xml;

    $self->{Debug} ge "1" ? ( $self->update_log( "Invoked Method: ". ( caller(0))[3] ) ) : () ;

    $self->clear_err_structure();

    # Check we have a password and email address

    if ( ( not defined( $self->{ SellaPassword } )  )
    or   ( $self->{ SellaPassword } eq ""           )
    or   ( not defined( $self->{ SellaEmail } )     )
    or   ( $self->{SellaEmail } eq ""               ) ) {
        $self->{ ErrorStatus    } = "1";
        $self->{ ErrorMessage   } = "Sella User details not entered - cannot connect";
        $self->{ ErrorDetail    } = "The user details for Sella have not been entered.\n";
        $self->{ ErrorDetail    } = "Either the password or log in name  or both can not be found.\n";
        $self->{ ErrorDetail    } .= "Use the Sella tab on the File->Options menu to entered the required details and retry the operation";
        return undef;
    }

    # Set up the request parameters

    $xml = "<method>";
    $xml .= "<name>sella_api_session_user_id<\/name>";
    $xml .= "<\/method>";

    # Log the XML Request if rerquired

    $self->{ Debug } ge "2" ? ( $self->update_log( "RequestXML:\n\n".$xml."\n--\n" ) ) : () ;

    # Send the Data to Sella and read the response using the sella agent

    $req = POST $self->{ SellaAPIURL }, [ xml => $xml ];
    $response  = $sa->request( $req );

    $self->{ Debug } ge "1" ? ( $self->update_log( $xml ) ): () ;
    $self->{ Debug } ge "1" ? ( $self->update_log( "Sella API Request URL: ".$self->{ SellaAPIURL } ) ) : () ;
    $self->{ Debug } ge "1" ? ( $self->update_log( "HTTP Response Code: ".$response->status_line ) ) : () ;
    $self->{ Debug } ge "2" ? ( $self->update_log( "Content Returned:\n\n".$response->content()."\n" ) ) : () ;

    my $sessionid = $self->get_sella_api_result( $response->content() );

    #######################################################################
    # The session id is the user id of the user logged in for the session #
    # User Id and Session ID are interchangebale terms once connected     #
    #######################################################################

    # If no sessionid was returned exit with an appropriate message

    if ( not defined $sessionid ) {
        $self->update_log( "Attempted to obtain Sella Session ID for Sella login: ".$self->{ SellaEmail }.";Sella User ID: ".$self->{ SellaID } );
        $self->update_log( "Session ID Request Transmit Data: ".$xml );
        $self->update_log( "HTTP Response Code: ".$response->status_line );
        $self->update_log( "Session ID Request Return data:".$response->content() );
        $self->{ ErrorStatus    } = "1";
        $self->{ ErrorMessage   } = "Unable to obtain a session ID from Sella";
        $self->{ ErrorDetail    } = "This normally occurs if the supplied log in details are incorrect. Check your email and password details for Sella.";
        return undef;
    }
    else {
        $self->{ SellaSessionID } = $sessionid;
    }

    my $properties = $self->sella_get_user_id_properties();

    if ( defined $properties->{ quickpay_enabled } ) {
        $self->{ QuickpayEnabled } = $properties->{ quickpay_enabled };
        if ( $self->{ QuickpayEnabled } ) {
            $self->update_log( "Quickpay is enabled for this account" );
        }
        else {
            $self->update_log( "Quickpay is NOT enabled for this account" );
        }
    }
    else {
        $self->update_log( "Unable to retrieve Quickpay properties for user. Quickpay status defaulted to Off" );
        $self->{ HasQuickpay } = 0;
    }
    return 1;
}

#=============================================================================================
# Method    : sella_load_auction
# Added     : 15/10/05
# Input     : 
# Returns   : 
#
#============================================================================================

sub load_sella_auction {

    my $self    = shift;
    my $p       = {@_};

    my ( $xo, $xml );

    $self->{ Debug } ge "1" ? ( $self->update_log( "Invoked Method: ". ( caller(0))[3] ) ) : () ;

    $self->clear_err_structure();

    # exit if the Session Id is not defined

    if ( not defined $self->{ SellaSessionID } ) {
        $self->update_log( "Sella Session ID not present - possible authentication error" );
        $self->{ ErrorStatus    } = "1";
        $self->{ ErrorMessage   } = "No Session ID present- cannot load auctions";
        $self->{ ErrorDetail    } = "";
        return undef;
    }

    $p->{ SellaCategory } = $self->sella_lookup_trademe_category( Category => $p->{ Category } );

    unless ( $p->{ SellaCategory } ) {
        $self->update_log( "Trade Me Category ".$p->{ Category }." has no equivalent category on Sella - auction cannot be loaded" );
        return undef;
    }

    #-----------------------------------------------------------------
    # Create listing structure on Sella and get guid for new listing 
    #-----------------------------------------------------------------

    # Set up the request method name

    $xml = "";
    $xo  = new XML::Writer( OUTPUT => \$xml );

    $xo->startTag( 'method');
    $xo->startTag( 'name'  );
    $xo->characters( 'sella_api_listing_create' );
    $xo->endTag( 'name' );

    # Set up the request parameters

    $xo->startTag( 'params' );
    $xo->startTag( 'param', name => 'user_id' );
    $xo->characters( $self->{ SellaSessionID } );
    $xo->endTag();

    $xo->startTag( 'param', name => 'type' );
    $xo->characters( 'a' );
    $xo->endTag();

    $xo->startTag( 'param', name => 'category_id' );
    $xo->characters( $p->{ SellaCategory } );
    $xo->endTag( 'param' );

    $xo->endTag( 'params' );
    $xo->endTag( 'method' );

    $xo->end();

    $req = POST $self->{ SellaAPIURL } , [ xml     =>  $xml    ];

    $response  = $sa->request( $req );

    # Debugging statements

    $self->{ Debug } ge "2" ? ( $self->update_log( "RequestXML:\n\n".$xml."\n--\n" ) ) : () ;
    $self->{ Debug } ge "1" ? ( $self->update_log( "Sella API Request URL: ".$self->{ SellaAPIURL } ) ) : () ;
    $self->{ Debug } ge "1" ? ( $self->update_log( "HTTP Response Code: ".$response->status_line ) ) : () ;
    $self->{ Debug } ge "2" ? ( $self->update_log( "Content Returned:\n\n".$response->content()."\n--\n" ) ) : () ;

    my $listingid = $self->get_sella_api_result( $response->content() );

    if ( not defined $listingid ) {
        $self->update_log( "Listing ID not returned - listing cannot be saved" );
        $self->{ ErrorStatus    } = "1";
        $self->{ ErrorMessage   } = "Listing ID not returned from Sella - listing cannot be fully processed";
        $self->{ ErrorDetail    } = "";
        return undef;
    }

    #-----------------------------------------------------------------
    # Update the new listing with listing details 
    #-----------------------------------------------------------------

    # Set up the request method name

    $xml = "";
    $xo  = new XML::Writer( OUTPUT => \$xml );

    $xo->startTag( 'method');
    $xo->startTag( 'name' );
    $xo->characters( 'sella_api_listing_save' );
    $xo->endTag( 'name' );

    # Set up the request parameters

    $xo->startTag( 'params' );
    $xo->startTag( 'param', name => 'data' );

    # Add the required Data Parameters

    $p->{Description} =  $p->{Description}."\n\n[ Loaded by Auctionitis ]  www.auctionitis.co.nz";   

    $xo->dataElement( 'id'                     , $listingid ); 
    $xo->dataElement( 'caption'                , Unicode::String->new( $p->{ Title          } ) );
    $xo->dataElement( 'description'            , Unicode::String->new( $p->{ Description    } ) );
    $xo->dataElement( 'auction-start_price'    , $p->{ StartPrice }  );

    # Handle additional pricing details

    $p->{ ReservePrice  } ? ( $xo->dataElement( 'auction-has_reserve'   , 'true'                )   ) : ();
    $p->{ ReservePrice  } ? ( $xo->dataElement( 'auction-reserve_price' , $p->{ ReservePrice }  )   ) : ();
    $p->{ BuyNowPrice   } ? ( $xo->dataElement( 'auction-buy_now_price' , $p->{ BuyNowPrice  }  )   ) : (); 

    # Handle when the auction will close

    if ( $p->{ EndType } eq "DURATION" ) {
        $xo->dataElement( 'close_in'            , "D" );
        $xo->dataElement( 'close_in_duration'   , $p->{ DurationHours } );
    }
    elsif ( $p->{ EndType } eq "FIXEDEND" ) {
        $xo->dataElement( 'close_in'            , 'S' );
        $xo->dataElement( 'close_in_date'       , $self->sella_close_in_date( $p->{ EndDays}, $p->{ EndTime } ) );
    }

    # Process Payment Elements

    $xo->startTag( 'payment');

    $p->{ BankDeposit       }   ?   ( $xo->dataElement( 'item'              , 'deposit'             ) ) : ();
    $p->{ CreditCard        }   ?   ( $xo->dataElement( 'item'              , 'credit'              ) ) : ();
    $p->{ CashOnPickup      }   ?   ( $xo->dataElement( 'item'              , 'cash'                ) ) : ();
    $p->{ EFTPOS            }   ?   ( $xo->dataElement( 'item'              , 'eftpos'              ) ) : ();
    $p->{ AgreePayMethod    }   ?   ( $xo->dataElement( 'item'              , 'org'                 ) ) : ();
    $p->{ PaymentInfo       }   ?   ( $xo->dataElement( 'item'              , 'other'               ) ) : ();

    if ( $self->{ QuickpayEnabled } ) {
        $p->{ Quickpay      }   ?   ( $xo->dataElement( 'item'              , 'quickpay'            ) ) : ();
    }

    $xo->endTag( 'payment' );

    $p->{ PaymentInfo       }   ?   ( $xo->dataElement( 'payment_other'     , $p->{ PaymentInfo  }  ) ) : ();

    # If the account can use Quickpay and payment option quickpay specified, set the flag to use std instructions

    if ( $self->{ QuickpayEnabled } and $p->{ Quickpay } ) {
        $xo->dataElement( 'use_standard_instructions'   , '1' );
    }

    # Pickup Options

    $p->{ PickupOption } == 1   ?   ( $xo->dataElement( 'pickup'            , 'can'                 ) ) : ();
    $p->{ PickupOption } == 2   ?   ( $xo->dataElement( 'pickup'            , 'must'                ) ) : ();
    $p->{ PickupOption } == 3   ?   ( $xo->dataElement( 'pickup'            , 'none'                ) ) : ();

    # Shipping Options

    $p->{ ShippingOption} == 1  ?   ( $xo->dataElement( 'shipping'          , 'free'                ) ) : ();

    $p->{ ShippingOption} == 2  ?   ( $xo->dataElement( 'shipping'          , 'org'                 ) ) : ();

    if ( $p->{ ShippingOption} == 3 ) {

        my $shipping_options = $self->get_shipping_details( AuctionKey => $p->{ AuctionKey } );

        $xo->dataElement( 'shipping', 'custom');
    
        $xo->startTag( 'shipping_custom');
        $xo->startTag( 'details');
        foreach my $s ( @$shipping_options ) { $xo->dataElement( 'item' , $s->{ Shipping_Details_Text } );  }
        $xo->endTag( 'details');
        $xo->startTag( 'cost');
        foreach my $s ( @$shipping_options ) { $xo->dataElement( 'item' , $s->{ Shipping_Details_Cost } );  }
        $xo->endTag( 'cost');
        $xo->endTag( 'shipping_custom');
    }

    $p->{ ShippingOption} == 4  ?   ( $xo->dataElement( 'shipping'          , 'other'               ) ) : ();
    $p->{ ShippingInfo  }       ?   ( $xo->dataElement( 'shipping_other'    , $p->{ShippingInfo  }  ) ) : ();

    # Process Optional Elements

    $p->{ Subtitle          }   ?   ( $xo->dataElement( 'subcaption'        , $p->{ Subtitle }      ) ) : ();
    $p->{ IsNew             }   ?   ( $xo->dataElement( 'new_item'          , 'true'                ) ) : ();

    if ( $p->{ RestrictAddress } )  { $xo->dataElement( 'restrict_address'  , 'true'  ); }
    else                            { $xo->dataElement( 'restrict_address'  , 'false' ); }
    if ( $p->{ RestrictPhone   } )  { $xo->dataElement( 'restrict_phone'    , 'true'  ); }
    else                            { $xo->dataElement( 'restrict_phone'    , 'false' ); }
    if ( $p->{ RestrictRating  } )  { $xo->dataElement( 'restrict_rating'   , 'true'  ); }
    else                            { $xo->dataElement( 'restrict_rating'   , 'false' ); }

    # Set for immediate publication

    $xo->dataElement( 'publish_option' , 'I' );

    # Close the XML elements off

    $xo->endTag( 'param' );
    $xo->endTag( 'params' );
    $xo->endTag( 'method' );

    $req = POST $self->{ SellaAPIURL }   , [ xml     =>  $xml    ];

    $response  = $sa->request( $req );

    # Debugging statements

    $self->{ Debug } ge "2" ? ( $self->update_log( "RequestXML:\n\n".$xml."\n--\n" ) ) : () ;
    $self->{ Debug } ge "1" ? ( $self->update_log( "Sella API Request URL: ".$self->{ SellaAPIURL } ) ) : () ;
    $self->{ Debug } ge "1" ? ( $self->update_log( "HTTP Response Code: ".$response->status_line ) ) : () ;
    $self->{ Debug } ge "2" ? ( $self->update_log( "Content Returned:\n\n".$response->content()."\n--\n" ) ) : () ;

    #If the response is not OK (200) then bail out as an error has occurred -dont activate the listing

    if ( $response->content() =~ m/error/gs ) {
        $self->update_log( "Error encountered when saving listing to Sella (method: sella_api_listing_save)" );
        $self->update_log( "Message Data:\n\n".$response->content()."\n--\n" );
        return undef;
    }

    #-----------------------------------------------------------------
    # Attach the images to the auction
    #-----------------------------------------------------------------
    #-----------------------------------------------------------------
    # Retrieve the image records related to the auction ID;
    # for each image record get the actual picture details - 
    # then perform a GET operation to input the required Photo ID
    #  -- Photos loaded in advance using the load_photo function --
    #-----------------------------------------------------------------

    my $images = $self->get_auction_image_records( AuctionKey => $p->{ AuctionKey } );

    $self->{Debug} ge "1" ? ( $self->update_log( "Retrieving image list for AuctionKey: ".$p->{ AuctionKey } ) ): () ;
    $self->{Debug} ge "1" ? ( $self->update_log( scalar( @$images )." images selected for auction input" ) ): () ;

    if ( defined( $images) and scalar( @$images ) > 0 ) {

        foreach my $i ( @$images ) {

            $self->{Debug} ge "1" ? ( $self->update_log( "Retrieving Picture record for PictureKey: ".$i->{ PictureKey } ) ): () ;

            my $r = $self->get_picture_record( PictureKey => $i->{ PictureKey } );

            $self->{Debug} ge "1" ? ( $self->update_log( "Adding Image ".$r->{ PictureFileName }. " ID: ".$r->{ SellaID } ) ): () ;

            # If the record has a sella id add it to the listing

            if ( $r->{ SellaID } ) {

                my $ok = $self->sella_image_add(
                    ListingID   =>  $listingid      ,
                    ImageID     =>  $r->{ SellaID } ,
                );

                # if the image does not get added attempt to load it and add it again

                if ( not $ok ) {

                    $self->update_log( "Re-sending image file $r->{ PictureFileName } to Sella " );

                    my $sellaid = $self->load_sella_image( FileName => $r->{ PictureFileName } );
    
                    if ( not defined $sellaid ) {
                        $self->update_log( "Error uploading File $r->{ PictureFileName } to Sella (record $i->{ PictureKey })" );
                    }
                    else {
                        $self->update_picture_record( 
                            PictureKey       =>  $i->{ PictureKey }   ,
                            SellaID          =>  $sellaid               ,
                        );

                        $self->update_log( "Loaded File $r->{ PictureFileName } to Sella as $sellaid (record $i->{ PictureKey })" );

                        $self->{Debug} ge "1" ? ( $self->update_log( "Adding Image ".$r->{ PictureFileName }. " ID: ".$sellaid ) ): () ;

                        $ok = $self->sella_image_add(
                            ListingID   =>  $listingid      ,
                            ImageID     =>  $sellaid        ,
                        );
                    }
                }
            }

            # If no ID in the picture record - attempt to add it to Sella then add to listing

            else {
                $self->update_log( "Adding image file $r->{ PictureFileName } to Sella " );

                my $sellaid = $self->load_sella_image( FileName => $r->{ PictureFileName } );

                if ( not defined $sellaid ) {
                    $self->update_log( "Error uploading File $r->{ PictureFileName } to Sella (record $i->{ PictureKey })" );
                }
                else {
                    $self->update_picture_record( 
                        PictureKey       =>  $i->{ PictureKey }   ,
                        SellaID          =>  $sellaid               ,
                    );

                    $self->update_log( "Loaded File $r->{ PictureFileName } to Sella as $sellaid (record $i->{ PictureKey })" );

                    $self->{Debug} ge "1" ? ( $self->update_log( "Adding Image ".$r->{ PictureFileName }. " ID: ".$sellaid ) ): () ;

                    my $ok = $self->sella_image_add(
                        ListingID   =>  $listingid      ,
                        ImageID     =>  $sellaid        ,
                    );
                }
            }
        }
    }

    #-----------------------------------------------------------------
    # Activate the listing 
    #-----------------------------------------------------------------

    # Set up the request method name

    if ( $self->{ DelayedActivate } ) {
        $self->update_log( "Listing $listingid not activated - Delayed Activate Flag set to TRUE" );
        return $listingid;
    }
    else {
        $xml = "";
        $xo  = new XML::Writer( OUTPUT => \$xml );

        $xo->startTag( 'method');
        $xo->startTag( 'name' );
        $xo->characters( 'sella_listing_request_activate' );
        $xo->endTag();

        # Set up the request parameters

        $xo->startTag( 'params' );
        $xo->dataElement( 'listing_id' , $listingid );
        $xo->endTag( 'params' );
        $xo->endTag( 'method' );

        $xo->end();
    
        $req = POST $self->{ SellaAPIURL } , [ xml     =>  $xml    ];
    
        $response  = $sa->request( $req );

        # Debugging statements
    
        $self->{ Debug } ge "2" ? ( $self->update_log( "RequestXML:\n\n".$xml."\n--\n" ) ) : () ;
        $self->{ Debug } ge "1" ? ( $self->update_log( "Sella API Request URL: ".$self->{ SellaAPIURL } ) ) : () ;
        $self->{ Debug } ge "1" ? ( $self->update_log( "HTTP Response Code: ".$response->status_line ) ) : () ;
        $self->{ Debug } ge "2" ? ( $self->update_log( "Content Returned:\n\n".$response->content()."\n--\n" ) ) : () ;
    
        my $activated = $self->get_sella_api_result( $response->content() );
    
        if ( uc( $activated ) ne "TRUE" ) {
            $self->update_log( "Listing $listingid not activated - check the listing in Sella for errors" );
            $self->{ ErrorStatus    } = "1";
            $self->{ ErrorMessage   } = "Listing $listingid not activated - check the listing in Sella for errors";
            $self->{ ErrorDetail    } = "";
            return undef;
        }
    }
    return $listingid;
}

#=============================================================================================
# Method    : sella_get_listing_state
# Added     : 5/10/09
# Input     : Auction refeence
# Returns   : Hash with Auction details
#
# Retrieves the status of an auction from Sella and returns the formatted data
#============================================================================================

 sub sella_get_listing_state {

    my $self = shift;
    my $p    = { @_ };

    $self->{ Debug } ge "1" ? ( $self->update_log( "Invoked Method: ". ( caller(0))[3] ) ) : () ;

    $self->clear_err_structure();

    # exit if the Session Id is not defined

    if ( not defined $self->{ SellaSessionID } ) {
        $self->update_log( "Sella Session ID not present - possible authentication error" );
        $self->{ ErrorStatus    } = "1";
        $self->{ ErrorMessage   } = "No Session ID present- cannot load auctions";
        $self->{ ErrorDetail    } = "";
        return undef;
    }

    my $xml = "";
    my $xo  = new XML::Writer( OUTPUT => \$xml );

    $xo->startTag( 'method');

    $xo->startTag( 'name' );
    $xo->characters( 'sella_api_listing_get_state' );
    $xo->endTag( 'name' );

    # Set up the request parameters

    $xo->startTag( 'params' );
    $xo->startTag( 'param', name => 'listing_id' );
    $xo->characters( $p->{ AuctionRef } );
    $xo->endTag( 'param' );
    $xo->endTag( 'params' );
    $xo->endTag( 'method' );

    $xo->end();

    $req = POST $self->{ SellaAPIURL } , [ xml     =>  $xml    ];

    $response  = $sa->request( $req );

    # Debugging statements

    $self->{ Debug } ge "2" ? ( $self->update_log( "RequestXML:\n\n".$xml."\n--\n" ) ) : () ;
    $self->{ Debug } ge "1" ? ( $self->update_log( "Sella API Request URL: ".$self->{ SellaAPIURL } ) ) : () ;
    $self->{ Debug } ge "1" ? ( $self->update_log( "HTTP Response Code: ".$response->status_line ) ) : () ;
    $self->{ Debug } ge "2" ? ( $self->update_log( "Content Returned:\n\n".$response->content()."\n--\n" ) ) : () ;

    my $data = $response->content();

    # Parse the returned XML

    my $xs = XML::Simple->new( SuppressEmpty => 'undef' );
    my $listing = $xs->XMLin( $data );

    if ( not defined( $listing->{ error } ) ) {
        return $listing;
    }
    else {
        $self->update_log( "Error retrieving status of listing $p->{ AuctionRef }" );
        $self->{ ErrorStatus    } = "1";
        $self->{ ErrorMessage   } = "Error retrieving status of listing $p->{ AuctionRef }";
        $self->{ ErrorDetail    } = $listing->{ message };
        return;
    }
}

#=============================================================================================
# Method    : sella_get_user_id_properties
# Added     : 5/10/09
# Input     : Auction refeence
# Returns   : Hash with Auction details
#
# Retrieves the status of an auction from Sella and returns the formatted data
#============================================================================================

sub sella_get_user_id_properties {

    my $self = shift;
    my $p    = { @_ };

    $self->{ Debug } ge "1" ? ( $self->update_log( "Invoked Method: ". ( caller(0))[3] ) ) : () ;

    $self->clear_err_structure();

    # exit if the Session Id is not defined

    if ( not defined $self->{ SellaSessionID } ) {
        $self->update_log( "Sella Session ID not present - possible authentication error" );
        $self->{ ErrorStatus    } = "1";
        $self->{ ErrorMessage   } = "No Session ID present - unable to retrieve user Id properties";
        $self->{ ErrorDetail    } = "";
        return undef;
    }

    my $xml = "";
    my $xo  = new XML::Writer( OUTPUT => \$xml );

    $xo->startTag( 'method');

    $xo->startTag( 'name' );
    $xo->characters( 'sella_api_user_get_by_id' );
    $xo->endTag( 'name' );

    # Set up the request parameters

    $xo->startTag( 'params' );
    $xo->startTag( 'param', name => 'user_id' );
    $xo->characters( $self->{ SellaSessionID } );
    $xo->endTag( 'param' );
    $xo->endTag( 'params' );
    $xo->endTag( 'method' );

    $xo->end();

    $req = POST $self->{ SellaAPIURL } , [ xml     =>  $xml    ];

    $response  = $sa->request( $req );

    # Debugging statements

    $self->{ Debug } ge "2" ? ( $self->update_log( "RequestXML:\n\n".$xml."\n--\n" ) ) : () ;
    $self->{ Debug } ge "1" ? ( $self->update_log( "Sella API Request URL: ".$self->{ SellaAPIURL } ) ) : () ;
    $self->{ Debug } ge "1" ? ( $self->update_log( "HTTP Response Code: ".$response->status_line ) ) : () ;
    $self->{ Debug } ge "2" ? ( $self->update_log( "Content Returned:\n\n".$response->content()."\n--\n" ) ) : () ;

    my $data = $response->content();

    print "User Data: ".$data."\n";

    # Parse the returned XML

    my $xs = XML::Simple->new( SuppressEmpty => 'undef' );
    my $userdata = $xs->XMLin( $data );

    if ( defined( $userdata->{ error } ) ) {
        $self->update_log( "Error retrieving properties for user ID $self->{ SellaSessionID }" );
        $self->{ ErrorStatus    } = "1";
        $self->{ ErrorMessage   } = "Error retrieving status of properties for user ID $self->{ SellaSessionID }";
        $self->{ ErrorDetail    } = $userdata->{ message };
        return;
    }
    else {
        return $userdata;
    }
}

#=============================================================================================
# Method    : is_sella_category    
# Added     : 15/10/05
# Input     : 
# Returns   : 
#
# Test whether a category is valid on Sella
#============================================================================================

sub is_sella_category {

    my $self  = shift;
    my $cat   = shift;

    if ( $response->content() =~ m/(<root\/>|<root \/>)/ ) {
        return 0;
    }
    else { 
        return 1;
    }
}

#=============================================================================================
# Method    : sella_load_image
# Added     : 15/10/05
# Input     : 
# Returns   : 
#
# Test sending an XML method to ZSella
#============================================================================================

sub load_sella_image {

    my $self    = shift;
    my $p       = { @_ };

    $self->{ Debug } ge "1" ? ( $self->update_log( "Invoked Method: ". ( caller(0))[3] ) ) : () ;

    $self->clear_err_structure();

    # check that file exists before commencing processing; return if file does not exist

    my @exists = stat( $p->{ FileName } );
    
    if ( not @exists ) {
        $self->update_log( "File not found: ".$p->{ FileName } );
        return undef;
    }

    # Set up the request parameters

    my $xml;
    $xml .= "<method>";
    $xml .= "<name>sella_api_image_save<\/name>";
    $xml .= "<\/method>";

    $self->{ Debug } ge "2" ? ( $self->update_log( "RequestXML:\n\n".$xml."\n--\n" ) ) : () ;

    $req = POST $self->{ SellaAPIURL }, 
        [   xml         =>  $xml                                                        ,
            image       => [ $p->{ FileName } => $p->{ FileName } => 'image/pjpeg' ] ]  ,
        'Content_Type'  =>  'multipart/form-data' ;

    $response  = $sa->request( $req );

    $self->{ Debug } ge "1" ? ( $self->update_log( "Sella API Request URL: ".$self->{ SellaAPIURL } ) ) : () ;
    $self->{ Debug } ge "1" ? ( $self->update_log( "HTTP Response Code: ".$response->status_line ) ) : () ;
    $self->{ Debug } ge "2" ? ( $self->update_log( "Content Returned:\n\n".$response->content()."\n" ) ) : () ;

    # $content = $response->content(); # posts the data to the remote site i.e. logs in

    my $imageid = $self->get_sella_api_result( $response->content() );

    if ( defined $imageid ) {
        $self->{ Debug } ge "1" ? ( $self->update_log( "Loaded Sella Image ID: ".$imageid ) ) : () ;
        return $imageid;
    }
    else {
        $self->{ ErrorStatus    } = "1";
        $self->{ ErrorMessage   } = "Image ID not returned from Sella";
        $self->{ ErrorDetail    } = "";
        return undef;
    }
}

#=============================================================================================
# Method    : sella_image_add    
# Added     : 15/10/05
# Input     : 
# Returns   : 
#
# Test sending an XML method to Sella
#============================================================================================

sub sella_image_add {

    my $self    = shift;
    my $p       = {@_};

    # Set up the request parameters

    my $xml;
    $xml .= "<method>";
    $xml .= "<name>sella_api_listing_add_image<\/name>";
    $xml .= "<params>";
    $xml .= $self->set_sella_api_parm( "listing_id"  , $p->{ ListingID } ); 
    $xml .= $self->set_sella_api_parm( "image_id"    , $p->{ ImageID   } ); 
    $xml .= "<\/params>";
    $xml .= "<\/method>";

    $self->{ Debug } ge "2" ? ( $self->update_log( "RequestXML:\n\n".$xml."\n--\n" ) ) : () ;

    $req = POST $self->{ SellaAPIURL }, [ xml     =>  $xml    ];

    $response  = $sa->request( $req );

    $self->{ Debug } ge "1" ? ( $self->update_log( "Sella API Request URL: ".$self->{ SellaAPIURL } ) ) : () ;
    $self->{ Debug } ge "1" ? ( $self->update_log( "HTTP Response Code: ".$response->status_line ) ) : () ;
    $self->{ Debug } ge "2" ? ( $self->update_log( "Content Returned:\n\n".$response->content()."\n--\n" ) ) : () ;

    #If the response contains an error string <error> then load the image again

    if ( $response->content() =~ m/<error>/gs ) {
        $self->update_log( "Error encountered adding image to listing (method: sella_image_add)" );
        $self->update_log( "Message Data:\n\n".$response->content()."\n--\n" );
        return 0;
    }
    else {
        $self->update_log( "Image ".$p->{ ImageID }." added to listing ID ".$p->{ ListingID } );
        return 1;
    }
}


#=============================================================================================
# Method    : sella_lookup_trademe_category  
# Added     : 15/10/05
# Input     : 
# Returns   : 
#
# Test sending an XML method to Sella
#============================================================================================

sub sella_lookup_trademe_category {

    my $self  = shift;
    my $p     = {@_};

    # Set up the request patameters

    my $xml;
    $xml .= "<method>";
    $xml .= "<name>sella_api_import_map_get_id_from_external_id<\/name>";

    # Set up the request parameters

    $xml .= "<params>";
    $xml .= "<param name=\"category_name\">trademe_category<\/param>";      # Identify mapping table to use (trademe)
    $xml .= "<param name=\"external_id\">".$p->{ Category }."<\/param>";    # TradeMe category 
    $xml .= "<\/params>";

    $xml .= "<\/method>";

    $self->{ Debug } ge "2" ? ( $self->update_log( "RequestXML:\n\n".$xml."\n--\n" ) ) : () ;

    $req = POST $self->{ SellaAPIURL }, [ xml     =>  $xml    ];

    $response  = $ua->request( $req );

    $self->{ Debug } ge "1" ? ( $self->update_log( "Sella API Request URL: ".$self->{ SellaAPIURL } ) ) : () ;
    $self->{ Debug } ge "1" ? ( $self->update_log( "HTTP Response Code: ".$response->status_line ) ) : () ;
    $self->{ Debug } ge "2" ? ( $self->update_log( "Content Returned:\n\n".$response->content()."\n" ) ) : () ;

    # If the response content indicates an error then return category code 0 otherwise return the response

    if ( $response->content() =~ m/error/gs ) {
        return 0;
    }
    else { 
        return $self->get_sella_api_result( $response->content() );
    }
}

#=============================================================================================
# Method    : get_sella_api_result
# Added     : 02/02/09
# Input     : 
# Returns   : string value or undef
#
# Paresethe result returned from an API call to Sella
#============================================================================================

sub get_sella_api_result {

    my $self  = shift;
    my $data  = shift;

    $self->{ Debug } ge "1" ? ( $self->update_log( "Invoked Method: ". ( caller(0))[3] ) ) : () ;
    $self->{ Debug } ge "2" ? ( $self->update_log( "Input Data: ".$data ) ) : () ;

    $self->clear_err_structure();

    # Remove the enclosing XML tags from the returned reult

    $data =~ m/(<root><result>)(.+?)(<\/result><\/root>)/gs ;

    my $result = $2;

    if ( defined $result ) {
        $self->{ Debug } ge "1" ? ( $self->update_log( "Returned API Data: ".$result ) ) : () ;
        return $result;
    }
    else {
        $self->{ ErrorStatus    } = "1";
        $self->{ ErrorMessage   } = "Unable to extract result from Sella API data";
        $self->{ ErrorDetail    } = "";
        return undef;
    }
}

#=============================================================================================
# Method    : set_sella_api_parm
# Added     : 02/02/09
# Input     : name and value pair
# Returns   : string - input value wrapped in enclosing xml tags with name
#
# Test sending an XML method to ZSella
#============================================================================================

sub set_sella_api_parm {

    my $self  = shift;
    my $name  = shift;
    my $val   = shift;

    $self->{ Debug } ge "1" ? ( $self->update_log( "Invoked Method: ". ( caller(0))[3] ) ) : () ;
    $self->{ Debug } ge "1" ? ( $self->update_log( "Parameter  Name: ".$name ) ) : () ;
    $self->{ Debug } ge "1" ? ( $self->update_log( "Parameter Value: ".$val ) ) : () ;

    $self->clear_err_structure();

    my $unival = Unicode::String->new( $val );

    my $param = "<param name=\"".$name."\">".$unival."<\/param>";

    if ( defined $param ) {
        $self->{ Debug } ge "2" ? ( $self->update_log( "Returned API Parameter: ".$param ) ) : () ;
        return $param;
    }
    else {
        $self->{ ErrorStatus    } = "1";
        $self->{ ErrorMessage   } = "Problem Setting Sella API Parameter correctly";
        $self->{ ErrorDetail    } = "";
        return undef;
    }
}

#=============================================================================================
# Method    : set_sella_api_elem
# Added     : 02/02/09
# Input     : 
# Returns   : 
#
# Test sending an XML method to ZSella
#============================================================================================

sub set_sella_api_elem {

    my $self  = shift;
    my $name  = shift;
    my $val   = shift;

    $self->{ Debug } ge "1" ? ( $self->update_log( "Invoked Method: ". ( caller(0))[3] ) ) : () ;
    $self->{ Debug } ge "1" ? ( $self->update_log( "Element  Name: ".$name ) ) : () ;
    $self->{ Debug } ge "1" ? ( $self->update_log( "Element Value: ".$val ) ) : () ;

    $self->clear_err_structure();

    my $unival = Unicode::String->new( $val );

    my $elem = "<".$name.">".$unival."<\/".$name.">";

    if ( defined $elem ) {
        $self->{ Debug } ge "2" ? ( $self->update_log( "Returned API Element: ".$elem ) ) : () ;
        return $elem;
    }
    else {
        $self->{ ErrorStatus    } = "1";
        $self->{ ErrorMessage   } = "Problem Setting Sella API Element correctly";
        $self->{ ErrorDetail    } = "";
        return undef;
    }
}

#=============================================================================================
# Method    : SellaFixedEnd
# Added     : 17/09/06
# Input     : numeric value indicating number of days auction is to run for
#           : (Number can be from 0 to 10, 0 indicating today)
# Returns   : String formatted as data in dd/mm/ccyy format including padded zeros
#           : Date returned is calculated date of today plus duration period
#           : This is the string used to specify the end time in Fixed End Auctions by TradeMe
#=============================================================================================

sub sella_close_in_date {

    my $self    = shift;
    my $days    = shift;
    my $period  = shift;

    my ( $date, $day, $month, $year,$time, $hour, $min, $utcoffset );

    # New date = now + duration in seconds (number of days X 24 (hrs) X 60 (mins) X 60 (secs)
                                                    
    my $closetime = time + ($days * 24 * 60 * 60);      

    # Set the day value

    if   ( ( ( localtime( $closetime ) )[3] ) < 10 )    { $day = "0".( localtime( $closetime ) )[3]; }
    else                                                { $day = ( localtime( $closetime ) )[3]; }

    # Set the month value
    
    if   ( ( ( localtime( $closetime ) )[4]+1 ) < 10 )  { $month = "0".( ( localtime( $closetime ) )[4]+1 ); }
    else                                                { $month = ( ( localtime( $closetime ) )[4]+1 ) ; }

    # Set the century/year value

    $year = ( ( localtime( $closetime ) )[5]+1900 );

    $date = $year."-".$month."-".$day;

    # closing hour = integer portion of number of intervals divided by 4
    # closing mins = equals number of periods not converted to hours * 15

    my $closehour = int($period / 4);             
    my $closemins = ($period - ($closehour * 4)) * 15;             

     # Set the minute value
    
    if   ( $closemins < 10 )                        { $min = "0".$closemins ;    }
    else                                            { $min = $closemins     ;    }

    # Set the hour value

    if   ( $closehour < 10 )                        { $hour = "0".$closehour;   }
    else                                            { $hour = $closehour    ;   }

    $time = $hour.":".$min.":00";

    # Set the offsetvalue based on whether daylight saving is in effect or not

    if ( ( localtime )[8] )                         { $utcoffset = "+13:00";    }
    else                                            { $utcoffset = "+12:00";    }

    $self->{ Debug } ge "1" ? ( $self->update_log( "Daylight Saving Flag: ".$utcoffset ) ) : () ;
    $self->{ Debug } ge "1" ? ( $self->update_log( "Sella Close In Date: ".$date."T".$time.$utcoffset ) ) : () ;

    return $date."T".$time.$utcoffset;
}

sub format_sella_close_date {

    my $self    = shift;
    my $p       =   { @_ };

    my $mth;

    # New date = now + duration in seconds (number of days X 24 (hrs) X 60 (mins) X 60 (secs)
                                                    
    $p->{ CloseDate } =~ m/(\d+)-(\d+)-(\d+)T(.+?)\+/;      

    if      ( $2 eq  1 ) { $mth = 'Jan'; }
    elsif   ( $2 eq  2 ) { $mth = 'Feb'; }
    elsif   ( $2 eq  3 ) { $mth = 'Mar'; }
    elsif   ( $2 eq  4 ) { $mth = 'Apr'; }
    elsif   ( $2 eq  5 ) { $mth = 'May'; }
    elsif   ( $2 eq  6 ) { $mth = 'Jun'; }
    elsif   ( $2 eq  7 ) { $mth = 'Jul'; }
    elsif   ( $2 eq  8 ) { $mth = 'Aug'; }
    elsif   ( $2 eq  9 ) { $mth = 'Sep'; }
    elsif   ( $2 eq 10 ) { $mth = 'Oct'; }
    elsif   ( $2 eq 11 ) { $mth = 'Nov'; }
    elsif   ( $2 eq 12 ) { $mth = 'Dec'; }

    my $closedate = $3."-".$mth."-".$1;
    my $closetime = $4;

    $self->{ Debug } ge "1" ? ( $self->update_log( "Input Closing Date: ".$p->{ CloseDate }  ) ) : () ;
    $self->{ Debug } ge "1" ? ( $self->update_log( "Requested Format: ".$p->{ Format }  ) ) : () ;
    $self->{ Debug } ge "1" ? ( $self->update_log( "Formatted Close Date: ".$closedate ) ) : () ;
    $self->{ Debug } ge "1" ? ( $self->update_log( "Formatted Close Time: ".$closetime ) ) : () ;

    if ( uc( $p->{ Format } ) eq 'DATE' ) {
        return $closedate;
    }
    elsif ( uc( $p->{ Format } ) eq 'TIME' )  {
        return $closetime;
    }
}

1;

#--------------------------------------------------------------------
# End of TradeMe automation and interaction package module
# Return true value so the module can actually be used
#--------------------------------------------------------------------

######################### POD Documentation ##########################

=head1 SYNOPSIS
The TradeMe module is intended to be used for accessing and managing data
operations required to run an on-line business using the TradeMe website,
together with some extendeded functionality not supplied by TradeMe.

The functions are meant to be accessed via Perl scripts using the supplied
object interface in a (hopefully) simple and straightforward way.

=head1 NEW FUNCTION
The new function - called by TradeMe->new(documentname) creates a new TradeMe
session .

example: my $tm = TradeMe->new();

=cut
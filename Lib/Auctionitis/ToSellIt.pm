#!perl -w
#---------------------------------------------------------------------------------------------
# 2SellIt automation and interaction package module
#
# Copyright 2007, Evan Harris.  All rights reserved.
#---------------------------------------------------------------------------------------------

package Auctionitis::ToSellIt;

use strict;
use Fcntl qw(:DEFAULT :flock);                                # Supplies O_RDONLY and other constant file values
use MIME::Lite;
use DBI;

my $VERSION = "0.002";
sub Version { $VERSION; }

# class variables

my ($ua, $url, $req, $response, $content, $dbh, $logfile);

# SQL Constants

my $SQL_get_account_list;               # Get list of accounts to process
my $SQL_write_event_log;                # Write to the Event Log

# other module/class constants

##############################################################################################
# --- Methods/Subroutines ---
##############################################################################################

#=============================================================================================
# Method    : New 
# Added     : 22/03/07
#
# Create new Westgate object;
# e.g. my $tm = TradeMe->new()
#=============================================================================================

sub new {

    my $class = shift;
    my $self  = {@_};
    bless ($self, $class);

    unless ( defined $self-> { Config } ) {
        $self-> { Config } = '2Sellit.config';
    }

    $self->_load_config;
    $self->_init;

    return $self;
}

#=============================================================================================
# Method    :  _LoadConfig
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
            $self->{ $parm} = $value;
    }
}

#=============================================================================================
# Method    :  _init
# Added     : 22/03/07
#
# Initialise object (called from new)
# Internal routine only...
#=============================================================================================

sub _init {

    my $self = shift;

    my $DSN     =   "driver={SQL Server};";
    $DSN        .=  "Server=".$self->{ SQLServer }.";";
    $DSN        .=  "Database=".$self->{ DatabaseName }.";";
    $DSN        .=  "uid=".$self->{ UserName }.";";
    $DSN        .=  "pwd=".$self->{ Password }.";";
    $dbh        =   DBI->connect("dbi:ODBC:$DSN", $self->{ UserName }, $self->{ Password } );

    $dbh->{ LongReadLen } = 65555;            # cater for retrieval of memo fields

    # Prepare standard SQL Statements

    $SQL_get_account_list = $dbh->prepare( qq { 
        SELECT  *
        FROM    AccountControl
    } );

    $SQL_write_event_log          = $dbh->prepare( qq { 
        INSERT INTO EventLog                (
                    Event_Severity          ,
                    Event_Process           ,
                    Event_Method            ,
                    Event_Message           )
        VALUES    ( ?, ?, ?, ?              )
    } );
}

#=============================================================================================
# Method    : get_account_list
# Added     : 22/03/07
#
# Returns the list of accounts in the 2Sellit AccoutnControl Table
#=============================================================================================

sub get_account_list {

    my $self    = shift;

    $SQL_get_account_list->execute();
    my $accounts = $SQL_get_account_list->fetchall_arrayref( {} );

    return $accounts;
}

#=============================================================================================
# Method    : write_event_log
# Added     : 22/03/07
#
# Writes a message to the event log
#=============================================================================================

sub write_event_log {

    my $self    = shift;
    my $p       = { @_ };
    my $msg     = shift;

    $p->{ Severity } = uc( $p->{ Severity } );

    my $proc = (caller(1))[1];
    $proc =~ s/\.pl//g;

    my $meth = (caller(1))[3];
    $meth =~ s/main:://g;

    $SQL_write_event_log->execute( 
        $p->{ Severity  }   ,
        $proc               ,
        $meth               ,
        $p->{ Message   }   ,
    );
}

#=============================================================================================
# Method    : CurrencyFormat
# Added     : 22/03/07
#
# Used for rounding numbers to 2 decimal places and placing a
# Dollar sign ($) in front
# It also adds in commas as thousand markers and adds a negative sign
# if necessary
#=============================================================================================

sub currency_format {

    my $self    = shift;
    my $number  = shift;
    my $minus   = 0;

    $number     =~ s/,//g;                      # Remove any commas.
    $number     =~ s/\$//g;                     # Remove any dollar signs.
    if ($ number < 0 ) { $minus = 1; }          # set flag if negative
    $number     =~ s/\-//g;                     # Remove any negative signs
    $number     =  sprintf "%.2f",$number;      # Round to 2 decimal places

    my @arrTemp = split(/\./,$number);          # Split based on the cents.
    my $strFormatted;
    my $nbrComma;                               # Counter for comma output.

    $arrTemp[0]  = reverse( $arrTemp[0] );      # Reverse string of numbers.
    my $nbrFinal = length( $arrTemp[0] );       # Get no of chars in the no.

    # Loop through and add the commas.
    
    for ( my $nbrCounter = 0; $nbrCounter < $nbrFinal; $nbrCounter++ )  {
        $nbrComma++;
        my $strChar = substr($arrTemp[0],$nbrCounter,1);
        if ( $nbrComma == 3 && $nbrCounter < ( $nbrFinal - 1 ) )        {
            $strFormatted .= "$strChar,";
            $nbrComma = 0;
        } 
        else {
            $strFormatted .= $strChar;
        }
    }
    
    #reverse back to normal
    
    $strFormatted = reverse( $strFormatted ); 

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
# Method    : is_debug
# Added     : 22/03/07
#
# Retrieve connected status
#=============================================================================================

sub is_debug {

    my $self = shift;
    if ( $self->{ Debug } eq "On" ) { return 1; } else { return 0; }
}

#*********************************************************************************************
# --- Mail Processing Routines ---
#*********************************************************************************************


#=============================================================================================
# Method    : crt_registration_ack
# Added     : 22/03/07
#
# build auction ackowledgement
#=============================================================================================

sub create_balance_alert {

    my $self  = shift;
    my %data  = {@_};

    my $template    = $self->{ RootDirectory }.$self->{ AccountBalanceAlert };
    my $text        = $self->_process_template( $template, %data );

    return $text
}

#=============================================================================================
# Method    : _process_template
# Added     : 22/03/07
#
# fill in variables on form template
#=============================================================================================

sub process_template {

    my $self        = shift;
    my $p           = { @_ };
    my $template    = $p->{ Template    };
    my $data        = $p->{ Data        };
    my $text;

    local $/;                                                      #slurp mode (undef)
    local *F;                                                      #create local filehandle
    open(F, "< $template\0") || return;
    $text = <F>;                                                   #read whole file
    close(F);                                                      # ignore retval
    
    # replace quoted words with value  in %$fillings hash
    
    $text =~ s{ %_  ( .*? ) _% }
              { exists( $data->{ $1 } )
                      ? $data->{ $1 }
                      : ""
              }gsex;
    return $text
}

#=============================================================================================
# Method    : send_email
# Added     : 22/03/07
#
# Send Email out using the SMTP Server from the config file
#=============================================================================================

sub send_email {

    my $self  = shift;
    my $p = { @_ };
    my $maildata;

    # send the email to the target user

    $maildata = MIME::Lite->build(
        Type      => 'TEXT',
        From      => $self->{ SenderAddress     },
        To        => $p->{ ToAddress            },
        Subject   => $p->{ Subject              },
        Data      => $p->{ MessageData          },
    );

    # If email is on actually send the email via SMTP

    if  ( $self->{ SendEmail } eq "Yes" ) {

        eval { $maildata->send('smtp', $self->{ SMTPServer }, Timeout=>120); };
        # if  ($@ ne '') { $self->update_log("Error sending email for [ $@ ]"); }
    }

    if  ( $self->{ Console } eq "Yes" ) {
        
        print "**** Mail Output redirected to Console *****\n\n";    
        print "From   :  ".$self->{ SenderAddress     }."\n";
        print "To     :  ".$p->{ ToAddress            }."\n";
        print "Subject:  ".$p->{ Subject              }."\n";
        print "Body   :\n".$p->{ MessageData        }."\n";
        print "**** End of Console Output *****\n\n";    
    }

    # If a copy is required send a copy to the copy address

    if ($self->{ SendCopy } eq "On") {

        $p->{ Subject       } = "-DUPLICATE- ".$p->{Subject};
        $p->{ MessageData   } = "*** Original email was sent to: ".$p->{ ToAddress }."***\n\n".$p->{ MessageData };
        $p->{ MessageData   } = "*** This Email is a SENDER COPY ***\n".$p->{ MessageData };

        $maildata = MIME::Lite->build(
            Type      => 'TEXT',
            From      => $self->{ SenderAddress   },
            To        => $self->{ CopyAddress     },
            Subject   => $p->{ Subject            },
            Data      => $p->{ MessageData        },
        );
        
        # If email is on actually send the email via SMTP

        if  ($self->{ SendEmail } eq "Yes") {
        
            eval { $maildata->send('smtp', $self->{ SMTPServer }, Timeout=>120); };

            if ($@ ne '') {
                $self->update_log( "ERROR Sending email to   : ".$p->{ ToAddress  }." [ $@ ]" );
                $self->update_log( "ERROR DATA               : [ $@ ]" );
            }
            else {
                $self->update_log( "EMAIL Sent to            : ".$p->{ ToAddress  } );
            }
        }

        if  ( $self->{ Console } eq "Yes" ) {

            print "*** Mail Output redirected to Console ****\n\n";    
            print "From   :  ".$self->{ SenderAddress       }."\n";
            print "To     :  ".$p->{ ToAddress              }."\n";
            print "Subject:  ".$p->{ Subject                }."\n";
            print "Body   :\n".$p->{ MessageData            }."\n";
            print "**** End of Console Output *****\n\n";    
        }
    }
}

#=============================================================================================
# Method    : send_email_with_file
# Added     : 22/03/07
#
# Send Email with an attachment out using the SMTP Server from the config file
#=============================================================================================

sub send_email_with_file {

    my $self  = shift;
    my $p = { @_ };
    my $maildata;

    # Create the mail objects

    $maildata = MIME::Lite->new(
        From        => $self->{ SenderAddress   }   ,
        To          => $p->{ ToAddress          }   ,
        Subject     => $p->{ Subject            }   ,
        Type        => 'multipart/mixed'            ,
    );

    # Add the Text for the email

    $maildata->attach(
        Type        => 'TEXT'                       ,
        Data        => $p->{ MessageData        }   ,
    );

    # Add the Attachment

    $maildata->attach(
        Type        => 'application/zip'            ,
        Path        => $p->{ AttachFile         }   ,
        Filename    => $p->{ AttachFile         }   ,
        Disposition => 'attachment'                 ,
    );

    # If email is on actually send the email via SMTP

    if  ( $self->{ SendEmail } eq "Yes" ) {

        eval { $maildata->send('smtp', $self->{ SMTPServer }, Timeout=>120); };
        # if  ($@ ne '') { $self->update_log("Error sending email for [ $@ ]"); }
    }

    if  ( $self->{ Console } eq "Yes" ) {
        
        print "**** Mail Output redirected to Console *****\n\n";    
        print "From   :  ".$self->{ SenderAddress     }."\n";
        print "To     :  ".$p->{ ToAddress            }."\n";
        print "Subject:  ".$p->{ Subject              }."\n";
        print "Body   :\n".$p->{ MessageData        }."\n";
        print "**** End of Console Output *****\n\n";    
    }

    # If a copy is required send a copy to the copy address

    if ($self->{ SendCopy } eq "On") {

        $p->{ Subject       } = "-DUPLICATE- ".$p->{Subject};
        $p->{ MessageData   } = "*** Original email was sent to: ".$p->{ ToAddress }."***\n\n".$p->{ MessageData };
        $p->{ MessageData   } = "*** This Email is a SENDER COPY ***\n".$p->{ MessageData };


        # Create the mail objects

        $maildata = MIME::Lite->new(
            From        => $self->{ SenderAddress   }   ,
            To          => $p->{ ToAddress          }   ,
            Subject     => $p->{ Subject            }   ,
            Type        => 'multipart/mixed'            ,
        );

        # Add the Text for the email

        $maildata->attach(
            Type        => 'TEXT'                       ,
            Data        => $p->{ MessageData        }   ,
        );

        # Add the Attachment

        $maildata->attach(
            Type        => 'application/zip'            ,
            Path        => $p->{ AttachFile         }   ,
            Filename    => $p->{ AttachFile         }   ,
            Disposition => 'attachment'                 ,
        );
        
        # If email is on actually send the email via SMTP

        if  ($self->{ SendEmail } eq "Yes") {
        
            eval { $maildata->send('smtp', $self->{ SMTPServer }, Timeout=>120); };

            if ($@ ne '') {
                $self->update_log( "ERROR Sending email to   : ".$p->{ ToAddress  }." [ $@ ]" );
                $self->update_log( "ERROR DATA               : [ $@ ]" );
            }
            else {
                $self->update_log( "EMAIL Sent to            : ".$p->{ ToAddress  } );
            }
        }

        if  ( $self->{ Console } eq "Yes" ) {

            print "*** Mail Output redirected to Console ****\n\n";    
            print "From   :  ".$self->{ SenderAddress       }."\n";
            print "To     :  ".$p->{ ToAddress              }."\n";
            print "Subject:  ".$p->{ Subject                }."\n";
            print "Body   :\n".$p->{ MessageData            }."\n";
            print "**** End of Console Output *****\n\n";    
        }
    }
}

#=============================================================================================
# update_log
# update the mailmate log file
#=============================================================================================

sub update_log {

    my $self = shift;

    #### DO NOT ADD STANDARD DEBUGGING TO THIS METHOD I.E. UPDATE_LOG   ####
    #### AS IT WILL RESULT IN A RECURSIVE CALL                          ####    
    
    # Get todays date to Timestamp log entry
    
    my ($secs, $mins, $hrs, $dd, $mm, $yy, $dow, $jul, $isdst) = localtime;
    
    # open the logfile

    open (LOGFILE, ">> $logfile");

    # format the retrieved date and time values

    $mm = $mm + 1;
    $yy = $yy + 1900;

    if ($secs < 10)   { $secs = "0".$secs; }
    if ($mins < 10)   { $mins = "0".$mins; }
    if ($dd   < 10)   { $dd   = "0".$dd;   }
    if ($mm   < 10)   { $mm   = "0".$mm;   }

    my $now = "$dd-$mm-$yy $hrs:$mins:$secs";

    # Strip any new lines out before printing to log

    tr/\n//; 

    print LOGFILE "$now @_\n";
    
    close LOGFILE;
}

#=============================================================================================
# Method    : pause
# Added     : 22/03/07
#
# Pause until enter pressed (utility routine for DOS windows)
#=============================================================================================

sub pause {

    my $self = shift;

    print "Press enter to continue...\n";
    <STDIN>;
}

#=============================================================================================
# Method    : dump_properties
# Added     : 22/03/07
# Input     : 
# Returns   : dumps the Auctionitis properties to the auctionitis log
#=============================================================================================

sub dump_properties {

    my $self    = shift;
    
    foreach my $property (sort keys %$self ) {    
        my $spacer = " " x ( 40 - length( $property ) );
        $self->write_event_log(
            Severity    => "Dump"                                       , 
            Message     => $property.":".$spacer.$self->{ $property }   ,
        );
    }
    
    return;
}

#=============================================================================================
# Method    : dump_hash
# Added     : 22/03/07
# Input     : 
# Returns   : dumps the values in a hash to the event log
#=============================================================================================

sub dump_hash {

    my $self    = shift;
    my $text    = shift;
    my $hash    = shift;

    $self->write_event_log(
        Severity    => "Dump"               , 
        Message     => "Hash Name - ".$text ,
    );

    foreach my $prop ( sort keys %$hash ) {    
        my $spacer = " " x ( 40 - length( $prop ) );
        $self->write_event_log(
            Severity    => "Dump"                               , 
            Message     => $prop.":".$spacer.$hash->{ $prop }   ,
        );
    }
    
    return;
}

#--------------------------------------------------------------------
# End of 2Sellit automation and interaction package module
# Return true value so the module can actually be used
#--------------------------------------------------------------------

1;


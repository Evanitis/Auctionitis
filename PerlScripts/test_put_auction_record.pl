#------------------------------------------------------------------------------------------------------------
# Test/prototype program to validate and/or add single record to Auctionitis database
# Input is in the form of an XML formatted string
#------------------------------------------------------------------------------------------------------------

use strict;
use Auctionitis; 
use XML::Parser;

my $input = shift;

# Hashes for checking/holding data

my %r;              # record hash
my %i;              # input data hash
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

my $DOcount = 0;    # Delivery options Count
my $Pcount  = 0;    # Paragraph Count
my $Wcount  = 0;    # Warning Count
my $Fcount  = 0;    # Fatal Count
my $Icount  = 0;    # Picture Count
                     
# other variables

my $t;              # tag name for current test
my $recOK = 1;      # Record OK to write

# Create the Trademe object

my $tm = Auctionitis->new();
$tm->initialise(Product => "Auctionitis");  # Initialise the product
$tm->DBconnect();                           # Connect to the database

# Set Auctionitis debug flag on or off as required

$tm->{ Debug } = 0;

$tm->{ Debug } ge "1" ? ( print "  Debug: Debug Level is [ ".$tm->{ Debug }." ].\n"):();

#------------------------------------------------------------------------------
# Validation control hashes
#------------------------------------------------------------------------------

# populate the valid tag names hash

$v{ AttributeCategory    } = "1"; 
$v{ AttributeName        } = "1";
$v{ AttributeValue       } = "1";
$v{ AuctionCycle         } = "1";
$v{ AuctionRecord        } = "1";
$v{ BankDeposit          } = "1";
$v{ BoldTitle            } = "1";
$v{ BuyNowPrice          } = "1";
$v{ CashOnPickup         } = "1";
$v{ Category             } = "1";
$v{ CategoryServiceDate  } = "1";
$v{ ClosedAuction        } = "1";
$v{ CopyCount            } = "1";
$v{ CreditCard           } = "1";
$v{ DeliveryOption       } = "1";
$v{ DatabaseVersion      } = "1";
$v{ Description          } = "1";
$v{ DurationHours        } = "1";
$v{ EndDays              } = "1";
$v{ EndTime              } = "1";
$v{ EndType              } = "1";
$v{ FeatureCombo         } = "1";
$v{ Featured             } = "1";
$v{ Gallery              } = "1";
$v{ Held                 } = "1";
$v{ HomePage             } = "1";
$v{ IsNew                } = "1";
$v{ LoadSequence         } = "1";
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
$v{ RelistStatus         } = "1";
$v{ ReservePrice         } = "1";
$v{ SafeTrader           } = "1";
$v{ SellerRef            } = "1";
$v{ ShippingCost         } = "1";
$v{ ShippingDetails      } = "1";
$v{ ShippingOption       } = "1";
$v{ ShippingText         } = "1";
$v{ StartPrice           } = "1";
$v{ StockOnHand          } = "1";
$v{ Subtitle             } = "1";
$v{ SupplierRef          } = "1";
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
$v{ Title                } = "1";
$v{ UserDefined01        } = "1";
$v{ UserDefined02        } = "1";
$v{ UserDefined03        } = "1";
$v{ UserDefined04        } = "1";
$v{ UserDefined05        } = "1";
$v{ UserDefined06        } = "1";
$v{ UserDefined07        } = "1";
$v{ UserDefined08        } = "1";
$v{ UserDefined09        } = "1";
$v{ UserDefined10        } = "1";
$v{ UserNotes            } = "1";
$v{ UserStatus           } = "1";

# populate the required tag names hash

$m{ AuctionRecord        } = "1";
$m{ AttributeCategory    } = "1";
$m{ Category             } = "1";
$m{ CategoryServiceDate  } = "1";
$m{ DatabaseVersion      } = "1";
$m{ Description          } = "1";
$m{ EndType              } = "1";
$m{ Paragraph            } = "1";
$m{ PickupOption         } = "1";
$m{ ShippingOption       } = "1";
$m{ StartPrice           } = "1";
$m{ Title                } = "1";

# populate the yes/no tag names hash

$y{ BankDeposit          } = "1"; 
$y{ CashOnPickup         } = "1";
$y{ CreditCard           } = "1"; 
$y{ Paymate              } = "1";
$y{ BoldTitle            } = "1";
$y{ ClosedAuction        } = "1";
$y{ FeatureCombo         } = "1";
$y{ Featured             } = "1";
$y{ Gallery              } = "1";
$y{ Held                 } = "1";
$y{ HomePage             } = "1";
$y{ IsNew                } = "1";
$y{ MovieConfirm         } = "1";
$y{ NotifyWatchers       } = "1";
$y{ Paymate              } = "1";
$y{ SafeTrader           } = "1";
$y{ TMBuyerEmail         } = "1";

# Decimal/Currency tag names

$c{ BuyNowPrice          } = "1";
$c{ ReservePrice         } = "1";
$c{ StartPrice           } = "1";
$c{ ShippingCost         } = "1";

# Integer tag names

$w{ AttributeCategory    } = "1"; 
$w{ AttributeName        } = "1";
$w{ CopyCount            } = "1";
$w{ DurationHours        } = "1";
$w{ EndDays              } = "1";
$w{ EndTime              } = "1";
$w{ LoadSequence         } = "1";
$w{ StockOnHand          } = "1";

# populate the alphanumeric/Text names hash and length values

$a{ AttributeName        } = "20";
$a{ AttributeValue       } = "20";
$a{ AuctionCycle         } = "20";
$a{ Description          } = "2018";
$a{ PaymentInfo          } = "70";
$a{ PictureFile          } = "128";
$a{ ProductCode          } = "20";
$a{ ProductCode2         } = "20";
$a{ ProductType          } = "20";
$a{ SellerRef            } = "20";
$a{ ShippingText         } = "50";
$a{ Subtitle             } = "50";
$a{ SupplierRef          } = "20";
$a{ TMATT104             } = "5";
$a{ TMATT104_2           } = "5";
$a{ TMATT106             } = "5";
$a{ TMATT106_2           } = "5";
$a{ TMATT108             } = "5";
$a{ TMATT108_2           } = "5";
$a{ TMATT111             } = "25";
$a{ TMATT112             } = "25";
$a{ TMATT115             } = "5";
$a{ TMATT117             } = "5";
$a{ TMATT118             } = "5";
$a{ Title                } = "50";
$a{ UserDefined01        } = "30";
$a{ UserDefined02        } = "30";
$a{ UserDefined03        } = "30";
$a{ UserDefined04        } = "30";
$a{ UserDefined05        } = "30";
$a{ UserDefined06        } = "30";
$a{ UserDefined07        } = "30";
$a{ UserDefined08        } = "30";
$a{ UserDefined09        } = "30";
$a{ UserDefined10        } = "30";
$a{ UserNotes            } = "6400";
$a{ UserStatus           } = "10";

#------------------------------------------------------------------------------
# Document Validation
#------------------------------------------------------------------------------

# Validate that the input is a valid XML construct

my $parser = XML::Parser->new( ErrorContext => 2 );

eval { $parser->parse( $input ); };

if ( $@ ) {

    print "  Fatal: XML Input is not valid. Processing terminated.\n";
    $@ =~ s/at \/.*?$//s;       # remove module line number
    $tm->{ Debug } ge "2" ? ( print "  Debug: Error Data: $@\n" ):();
    $recOK = 0;
    $Fcount++;
    return;

} else {

    $tm->{ Debug } ge "2" ? ( print "  Debug: XML Input is well-formed\n"):();
}

#------------------------------------------------------------------------------
# Input Field Validation 
#------------------------------------------------------------------------------

# Strip out any newlines from the input string

print "   Info: Removing new line characters from input data.\n";

$input =~ tr/\n//d;

# Make a copy of the input data for searching

my $data = $input;


# Create a hash of all the input tags that contain values

while ( $input =~ m/(<)(.+?)(>)/g ) {

    my $m = $2;

    # If node is a start tag add the tag name to the input node name hash
    # Then search the input with closing tag to extract the accompanying data
    # 
    # Add Subroutine handlers or calls here for tags with nested data
    #
    
    if ( not $m =~ m/\// ) {       
    
        my $tag = $m;
        $n{ $tag } = "1";
        $tm->{ Debug } ge "2" ? ( print "  Debug: Identified Opening Tag: $m\n" ):();

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
                    print " Fatal: Filename [ ".$2." ] supplied for <PictureFile> longer than allowed length of ".$a{ PictureFile }.".\n";
                    $recOK = 0;
                    $Fcount++;               
                }
                else {
                    push ( @pics, $2 );
                }
            }

            if ( $Icount eq 0 ) {
                print "  Fatal: Required tag <PictureFile> not found in <Pictures> Node\n";
                $recOK = 0;
                $Fcount++;               
            }
        }

        if ( $Icount gt 3) {
            print "  Fatal: Number of Picture Files specified [ ".$Icount." ] greater than allowable maximum of 3.\n";
            $recOK = 0;
            $Fcount++;               
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
        
        $tm->{ Debug } ge "2" ? ( print "  Debug: Identified Empty Tag: $m\n" ):();
    }

    # If node is a not a start tage and is not empty, verify that it is an end tag
    
    elsif ( $m =~ m/(\/)(.+)/ ) {

        my $tag = $2;
        $tm->{ Debug } ge "2" ? ( print "  Debug: Identified End Tag: $m\n" ):();
    }
    
    else {
    
        $tm->{ Debug } ge "2" ? ( print "  Debug: Unable to identify Tag: $m\n" ):();
    }
}

# Check all required tags found in input list & have associated data

foreach my $key ( sort keys %m ) {
    if (not exists( $n{ $key } ) ) {
        print "  Fatal: Required tag <".$key."> missing from input.\n";
        $recOK = 0;
        $Fcount++;
    }
    if ( ( exists( $n{ $key } ) ) and ( not defined $i{ $key } ) ) {
        print "  Fatal: Required tag <".$key."> has no associated data.\n";
        $recOK = 0;
        $Fcount++;
    }
}

# Identify tags which have associated data 

foreach my $key ( sort keys %n ) {
    if ( exists( $i{ $key } ) ) {
        $tm->{ Debug } ge "2" ? ( print "  Debug: Tag <".$key."> has associated data\n" ):();
    }
    else {
        print "Warning: Tag <".$key."> is empty. Default value for tag will be used\n";
        $Wcount++;
    }
}

# Check for unknown tags in input and verify known tags

foreach my $key ( sort keys %n ) {
    if (not exists( $v{ $key } ) ) {
        print "Warning: Tag <".$key."> is unknown. Tag and associated value will be ignored \n";
        $Wcount++;
    }
    else {
        $tm->{ Debug } ge "2" ? ( print "  Debug: Valid Tag found [ ".$key." ].Tag and associated value will be processed\n" ):();
    }    
}

#------------------------------------------------------------------------------
# Data Type and field length validation checks
#------------------------------------------------------------------------------

# True/false fields

foreach my $key ( keys %y ) {
    if ( exists ( $i{ $key } ) ) {
        if ( not ( $i{ $key } =~ m/TRUE|FALSE|NO|YES/i ) ) {
             print "  Fatal: Invalid value [ ".$i{ $key }." ] for tag <".$key.">. Input value must be YES, NO, TRUE OR FALSE\n";
             $recOK = 0;
             $Fcount++;
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
            print "  Fatal: Invalid value [ ".$i{ $key }." ] for tag <".$key.">. Input value must be of type Currency\n";
            $recOK = 0;
            $Fcount++;
        }
    }
}

# Integer fields

foreach my $key ( keys %w ) {
    if ( exists ( $i{ $key } ) ) {
        if ( not ( $i{ $key } =~ m/[0-9*]/ ) ) {
            print "  Fatal: Invalid value [ ".$i{ $key }." ] for tag <".$key.">. Input value must be of type Numeric\n";
            $recOK = 0;
            $Fcount++;
        }
    }
}

# Field length of character fields

foreach my $key ( keys %a ) {
    if ( exists ( $i{ $key } ) ) {
        if ( length ( $i{ $key } ) > $a{ $key } ) {
            print "Warning: Value supplied for tag <".$key."> longer than allowed length of ".$a{ $key }.". Input will be truncated\n";
            $Wcount++;
            
            print "    Old: [ ".$i{ $key }." ]\n";
            
            $i{ $key } = substr( $i{ $key }, 0, $a{ $key } );
            
            print "    New: [ ".$i{ $key }." ]\n";
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
    print "  Fatal: Invalid value [ ".$i{ $t }." ] for tag <".$t.">. Input value must be FIXEDEND or DURATION\n";
    $recOK = 0;
    $Fcount++;
}

# Auction Duration

if ( $i{ EndType } eq "DURATION" ) {

    $t = "DurationHours";

    if (not exists( $n{ $t } ) ) {
        print "  Fatal: Tag <".$t."> is a required tag when EndType DURATION is specified.\n";
        $recOK = 0;
        $Fcount++;
    }
    if ( ( exists( $n{ $t } ) ) and ( not defined $i{ $t } ) ) {
        print "  Fatal: Tag <".$t."> must contain data when EndType DURATION is specified.\n";
        $recOK = 0;
        $Fcount++;
    }

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
        print "  Fatal: Invalid value [ ".$i{ $t }." ] for tag <".$t.">. Input value must be one of: 6, 12, 24, 48, 72, 96, 120, 144, 168 or 240.\n";
        $recOK = 0;
        $Fcount++;
    }
}

# Scheduled end time

if ( $i{ EndType } eq "FIXEDEND" ) {

    $t = "EndDays";

    if (not exists( $n{ $t } ) ) {
        print "  Fatal: Tag <".$t."> is a required tag when EndType FIXEDEND is specified.\n";
        $recOK = 0;
        $Fcount++;
    }
    if ( ( exists( $n{ $t } ) ) and ( not defined $i{ $t } ) ) {
        print "  Fatal: Tag <".$t."> must contain data when EndType FIXEDEND is specified.\n";
        $recOK = 0;
        $Fcount++;
    }

    my $testval = int( $i{ $t } );

    # Check end days is a whole number between 0 and 10

    if    ( ( $i{ $t } lt 0 ) or ( $i{ $t } gt 10 ) or ( $testval != $i{ $t } ) ) { 
        print "  Fatal: Invalid value [ ".$i{ $t }." ] for tag <".$t.">. Input value must a whole number between 0 and 10.\n";
        $recOK = 0;
        $Fcount++;
    }

    # Check end time is a whole number between 0 and 95

    $t = "EndTime";

    if (not exists( $n{ $t } ) ) {
        print "  Fatal: Tag <".$t."> is a required tag when EndType FIXEDEND is specified.\n";
        $recOK = 0;
        $Fcount++;
    }
    if ( ( exists( $n{ $t } ) ) and ( not defined $i{ $t } ) ) {
        print "  Fatal: Tag <".$t."> must contain data when EndType FIXEDEND is specified.\n";
        $recOK = 0;
        $Fcount++;
    }

    $testval = int( $i{ $t } );

    if    ( ( $i{ $t } lt 0 ) or ( $i{ $t } gt 95 ) or ( $testval != $i{ $t } ) ) { 
        print "  Fatal: Invalid value [ ".$i{ $t }." ] for tag <".$t.">. Input value must a whole number between 0 and 95.\n";
        $recOK = 0;
        $Fcount++;
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
        print "  Fatal: Invalid value [ ".$i{ $t }." ] for tag <".$t.">. Input value must be NORELIST, UNTILSOLD, WHILESTOCK or PERMANENT\n";
        $recOK = 0;
        $Fcount++;
    }
}

# Pickup Option

$t = "PickupOption";

if    ( uc( $i{ $t } ) eq "ALLOW"      )     { $i{ $t } = 1 ; } 
elsif ( uc( $i{ $t } ) eq "DEMAND"     )     { $i{ $t } = 2 ; } 
elsif ( uc( $i{ $t } ) eq "FORBID"     )     { $i{ $t } = 3 ; } 
else {
    print "  Fatal: Invalid value [ ".$i{ $t }." ] for tag <".$t.">. Input value must be ALLOW, DEMAND or FORBID\n";
    $recOK = 0;
    $Fcount++;
}

# Shipping Option

$t = "ShippingOption";

if    ( uc( $i{ $t } ) eq "UNDECIDED"  )     { $i{ $t } = 1 ; } 
elsif ( uc( $i{ $t } ) eq "FREE"       )     { $i{ $t } = 2 ; } 
elsif ( uc( $i{ $t } ) eq "CUSTOM"     )     { $i{ $t } = 3 ; } 
else {
    print "  Fatal: Invalid value [ ".$i{ $t }." ] for tag <".$t.">. Input value must be UNDECIDED, FREE, or CUSTOM\n";
    $recOK = 0;
    $Fcount++;
}

# Processing for Custom Shipping Options

if ( $i{ ShippingOption } == 3 ) {

    my $text = $i{ ShippingDetails };

    while ( $text =~ m/(<DeliveryOption>)(.*?)(<\/DeliveryOption>)/g ) {

        my $do = $2;      # Delivery option data (container node)
        my $sc = "";      # Shipping cost
        my $st = "";      # Shipping text
        $DOcount++;
        
        # Extract the Shipping text and Shiping cost from the delivery option data
        
        if ( $do =~ m/(<ShippingCost>)(.*?)(<\/ShippingCost>)/ ) {
            $sc = $2;
        }
        else {
            print "  Fatal: Required tag <ShippingCost> not found in <DeliveryOption> Node.\n";
            $recOK = 0;
            $Fcount++;
        }
        
        if ( $do =~ m/(<ShippingText>)(.*?)(<\/ShippingText>)/ ) {
            $st = $2;
        }
        else {
            print "  Fatal: Required tag <ShippingText> not found in <DeliveryOption> Node.\n";
            $recOK = 0;
            $Fcount++;
        }
        
        if ( not ( $sc =~ m/[0-9\.*]/ ) ) {
            print "  Fatal: Invalid value [ ".$sc." ] for tag <ShippingCost>. Input value must be of type Currency\n";
            $recOK = 0;
            $Fcount++;
        }
        
        if ( length ( $st ) > $a{ ShippingText } ) {
            print "Warning: Value supplied for tag <ShippingText> longer than allowed length of ".$a{ ShippingText }.". Input will be truncated\n";
            $Wcount++;
            
            print "    Old: [ ".$st." ]\n";
            
            $st = substr( $st, 0, $a{ ShippingText } );
            
            print "    New: [ ".$st." ]\n";
        }

        push ( @shipopt, { ShippingCost => $sc, ShippingText => $st } );
    }

    if ( $DOcount > 10 ) {
        print "  Fatal: Number of Delivery Options specified [ ".$DOcount." ] greater than allowable maximum of 10.\n";
        $recOK = 0;
        $Fcount++;
    }

    if ( $DOcount == 0 ) {
        print "  Fatal: At least one Delivery Option must be supplied with shipping option CUSTOM.\n";
        $recOK = 0;
        $Fcount++;
    }

}

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
        print "  Fatal: Invalid value [ ".$i{ $t }." ] for tag <".$t.">. Input value must be blank or G, PG, M, R13, R15, R16, R18, or Not Classified\n";
        $recOK = 0;
        $Fcount++;
    }
}

# User Notes: Convert newlines to memo eol value in database 

$i{ UserNotes } =~ s/\n/\x0D\x0A/g;           # change newlines to mem cr/lf combo   

#------------------------------------------------------------------------------
# Category checks
#------------------------------------------------------------------------------

# Check category is valid

if ( not $tm->is_valid_category( $i{ Category } ) ) {
    print "  Fatal: Category Input error. Invalid category [ ".$i{ Category }." ].\n";
    $Fcount++;
    $recOK = 0;
}

# Check category value does NOT have any children

if ( $tm->has_children( $i{ Category } ) ) {
    print "  Fatal: Category Input error. Selection not complete for category [ ".$i{ Category }." ].\n";
    $recOK = 0;
    $Fcount++;
}

# Attribute category checks

# Determine whether the category has associated attributes
# Start with the initial category and test for the attribute category
# repeat until the test catgory value = 0 or the attribute test is true

my $ac = $i{ Category };

$tm->{ Debug } ge "2" ? ( print "  Debug: Checking category [ ".$ac." ] for attribute requirements .\n" ):();

until ( $tm->has_attributes( $ac ) or $ac eq 0 ) {
   
    $tm->{ Debug } ge "2" ? ( print "  Debug: Retrieve parent category [ ".$tm->get_parent( $ac )." ] for category [ ".$ac." ].\n" ):();
    $ac = $tm->get_parent( $ac );

}

if ( $ac  ) {
    $tm->{ Debug } ge "2" ? ( print "  Debug: Attribute category [ ".$ac." ] found for base input category [ ".$i{ Category }." ].\n" ):();
}

if ( not $ac ) {
    $tm->{ Debug } ge "2" ? ( print "  Debug: No attribute category found for base input category [ ".$i{ Category }." ].\n" ):();
}

# TODO: Complete about error messages for Attribute categories 

if ( $ac ne $i{ AttributeCategory } ) {
    print "  Fatal: Category Attribute error. Selection not complete for category [ ".$i{ Category }." ].\n";
    $recOK = 0;
    $Fcount++;
}

#------------------------------------------------------------------------------
# Check data for conformity to TradeMe Auction input rules 
#------------------------------------------------------------------------------

# Start Price greater than zero

if ( $i{ StartPrice } <= 0 ) {
    print "  Fatal: Invalid value [ ".$i{ StartPrice }." ] for tag <StartPrice>. Input value must be greater than 0.\n";
    $recOK = 0;
    $Fcount++;
}

# If specified Buy now price must be greater than or equal to the Start Price

if ( ( $i{ BuyNowPrice } > 0 ) and ( $i{ BuyNowPrice } < $i{ StartPrice } ) ) {
    print "  Fatal: Invalid value [ ".$i{ BuyNowPrice }." ] for tag <BuyNowPrice>. BuyNowPrice must be greater than or equal to StartPrice.\n";
    $recOK = 0;
    $Fcount++;
}

# Reserve Price must be greater than or equal to the Start Price; if no reserve specified set to Start price

if ( exists ( $i{ ReservePrice } ) ) {
    if ( $i{ ReservePrice } < $i{ StartPrice } ) {
        print "  Fatal: Invalid value [ ".$i{ ReservePrice }." ] for tag <ReservePrice>. ReservePrice must be greater than or equal to StartPrice.\n";
        $recOK = 0;
        $Fcount++;
    }
}
else {
    $i{ ReservePrice } = $i{ StartPrice };
    print "   Info: No Reserve Price specified; ReservePrice has been set to StartPrice [ ".$i{ StartPrice }." ].\n";
}

# Starting price must be at least 10% of the reserve price if the reserve is over exactly 100.00 

if ( ( $i{ ReservePrice } > 100 ) and ( $i{ StartPrice } < $i{ ReservePrice }/10 ) ) {

    print "  Fatal: Invalid value [ ".$i{ StartPrice }." ] for tag <StartPrice>. StartPrice must be at least 10% of the Reserve if Reserve is greater than 100.00.\n";
    $recOK = 0;
    $Fcount++;
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

    print "  Fatal: Tag <PaymentInfo> is empty but no other Payment M+ethod has been specified.\n";
    $recOK = 0;
    $Fcount++;
}

# Perform Picture file validation

foreach my $pic ( @pics ) {   

    # check that file exists and check size of file

    my @fstat = stat( $pic );
    
    if ( not @fstat ) {
        print "Warning: File ".$pic." specified in <PictureFile> tag not found or not accessible.\n";
        $Wcount++;
    }
    else {
        if ( $fstat[7] > 500000 ) {
            print "Warning: File ".$pic." specified in <PictureFile> exceeds 500,000 bytes and may not upload to TradeMe.\n";
            $Wcount++;
        }
    }
}

# Check that Picture count is at least 1 if any promotional options have been specified

if  ( $i{ Gallery } ==  1 and $Icount == 0 ) {
    print "  Fatal: Promotional option <Gallery> specified but no PictureFile name has been supplied.\n";
    $recOK = 0;
    $Fcount++;
}

if ( $i{ Featured } ==  1 and $Icount == 0 ) {
    print "  Fatal: Promotional option <Featured> specified but no PictureFile name has been supplied.\n";
    $recOK = 0;
    $Fcount++;
}

if ( $i{ FeatureCombo } ==  1 and $Icount == 0 ) {
    print "  Fatal: Promotional option <FeatureCombo> specified but no PictureFile name has been supplied.\n";
    $recOK = 0;
    $Fcount++;
}

if ( $i{ HomePage } ==  1 and $Icount == 0 ) {
    print "  Fatal: Promotional option <HomePage> specified but no PictureFile name has been supplied.\n";
    $recOK = 0;
    $Fcount++;
}

#------------------------------------------------------------------------------
# Additional checking for attribute data
#------------------------------------------------------------------------------

# TODO: Add validation section for each Attribute group (i.e. combobox values)

# TODO: Create function to extract Attribute type (i.e. Combo or fixed)

# TODO: Add code to handle empty description inlcuding empty paragraps being passed

#------------------------------------------------------------------------------
# Write extracted data to database if Record OK flag ($recOK) is true
#------------------------------------------------------------------------------

if ( $recOK ) {

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

    my $newkey = $tm->add_auction_record_202(
        AuctionStatus              =>  "PENDING"                                            ,
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

    print "   Info: Added new record [ ".$newkey." ].\n";

    # Add the shipping options paramaters if we have custom shipping options
    
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

            print "   Info: Added Shipping Details item [ ".$seq." ].\n";

            $seq++;
        }
    }
}



# Dump all the input fields except Description - it just gets in the way

if ( $tm->{ Debug} ge 1 ) {

    print "\n";
    print "Input Data dump\n";
    print "------------------------\n";
    
    foreach my $key ( sort keys %i ) {
    
        if ( $key ne "Description" and $key ne "AuctionRecord" ) {
          print "<".$key.">\t\t ".$i{ $key }."\n";
        }
    }
    
    print "\n";
    print "Extracted Shipping Options\n";
    print "------------------------\n";
    
    foreach my $do ( @shipopt ) {
        print "Shipping Cost: ".$do->{ ShippingCost }."\n";
        print "Shipping Text: ".$do->{ ShippingText }."\n";
    }
}

print "\n";
print "Document details Summary\n";
print "------------------------\n";
print "    Fatal Errors: ".$Fcount."\n";
print "        Warnings: ".$Wcount."\n";
print "      Paragraphs: ".$Pcount."\n";
print "        Pictures: ".$Icount."\n";
print "Delivery Options: ".$DOcount."\n";


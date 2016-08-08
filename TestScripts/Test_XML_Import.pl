#

# Simple program to extract/print the category data retrieved from eBay

#

use Auctionitis;
use XML::Parser;
use strict;

# Initialise Auctionitis and establish a database connection

my $tm = Auctionitis->new();
$tm->initialise(Product => "Auctionitis");      # Initialise the product
$tm->DBconnect();                               # Connect to the database

# Initialise the parser and set the category array record handler

my $parser = XML::Parser->new( Handlers=> {     Start   =>  \&elem_start    ,
                                                Char    =>  \&elem_data     ,
                                                End     =>  \&elem_end      } );

# Global Variables

my %rec;
my $e;
my $desc;
my $pic;
my $id;

my $file = shift @ARGV;

my $counter = 1;

if     ( $file ) {
         $parser->parsefile( $file ) ;
} else {
    
         my $input = "";
         while( <STDIN> ) { $input .= $_; }
         $parser->parse( $input ) ;
}         

exit;

#==============================================================================
# Event Handlers
#==============================================================================

#------------------------------------------------------------------------------
# Element start
#------------------------------------------------------------------------------

sub elem_start {

    my( $expat, $name, %atts ) = @_;
    $e = $name;

    if ( $name eq "AuctionRecord" ) {

        # Clear all the data from the previous record

        while(( my $key, my $value) = each(%rec)) {
            delete($rec{ $key });
        }
        
        print "Processing record: $counter\n";
        $counter++;
    }
}

#------------------------------------------------------------------------------
# Element data
#------------------------------------------------------------------------------

sub elem_data {

    my( $expat, $data ) = @_;
    
    # Clean the picture record
        
    if (( $e eq "PictureKey1"         )     or
        ( $e eq "PictureKey2"         )     or
        ( $e eq "PictureKey3"         )     or

        $pic    = "";
        $id     = "";
    }
    
    # clean out XML entities from the element data
    
    $data =~ s/&/&/g;
    $data =~ s/</&lt;/g;

    if (( $e eq "Held"                )     or
        ( $e eq "AuctionSold"         )     or 
        ( $e eq "NotifyWatchers"      )     or 
        ( $e eq "UseTemplate"         )     or 
        ( $e eq "MovieConfirm"        )     or 
        ( $e eq "IsNew"               )     or 
        ( $e eq "TMBuyerEmail"        )     or 
        ( $e eq "Closed"              )     or 
        ( $e eq "AutoExtend"          )     or 
        ( $e eq "Cash"                )     or 
        ( $e eq "Cheque"              )     or 
        ( $e eq "BankDeposit"         )     or 
        ( $e eq "FreeShippingNZ"      )     or 
        ( $e eq "Featured"            )     or 
        ( $e eq "Gallery"             )     or 
        ( $e eq "BoldTitle"           )     or 
        ( $e eq "FeatureCombo"        )     or 
        ( $e eq "HomePage"            ) )   { 
        
        if    ( $inval )          { $rec{ $e } = 1            ; } 
        else                      { $rec{ $e } = 0            ; }
        
        return
    }

    if ( $e eq "DurationHours" ) {

        $rec{ $e } = ( $data * 60 );
              
        return;
    }
    
    if ( $e eq "RelistStatus" ) {

        if    ( $data eq "NORELIST"     )     { $rec{ $e } = 0 ; } 
        elsif ( $data eq "UNTILSOLD"    )     { $rec{ $e } = 1 ; } 
        elsif ( $data eq "WHILESTOCK"   )     { $rec{ $e } = 2 ; } 
        elsif ( $data eq "PERMANENT"    )     { $rec{ $e } = 3 ; } 

        return;
    }

    if  ( $e eq "SafeTrader" ) {

        if    ( $data eq "Dont Accept"  )     { $rec{ $e } = 0 ; } 
        elsif ( $data eq "Seller Pays"  )     { $rec{ $e } = 1 ; } 
        elsif ( $data eq "50-50"        )     { $rec{ $e } = 2 ; } 
        elsif ( $data eq "Buyer Pays"   )     { $rec{ $e } = 3 ; } 

        return;
    }


    if ( $e eq "Description"          ) 

        $desc   = "";
        
        return
    }

    if ( $e eq "Paragraph"          ) 
    
        $desc   = $desc."\n\n".$data;

        return
    }

    if (( $e eq "PictureKey1"         )     or
        ( $e eq "PictureKey2"         )     or
        ( $e eq "PictureKey3"         )     or

        $pic    = "";
        $id     = ""'

        return
    }
        
    $rec{ $e } = $data;
   
}

#------------------------------------------------------------------------------
# Element End
#------------------------------------------------------------------------------

sub elem_end {

    my( $expat, $name ) = @_;

    if ( $name eq "Description"         ) 

        $rec{ Description } = $desc;
        
        return
    }

    if ( $e eq "PictureKey1"            )

        # Write picture record
        
        $tm->add_picture_record( PictureFileName => $pic );
        my $pickey = $tm->get_picture_key( PictureFileName => $pic );
        $tm->update_picture_record( PictureKey  => $pickey  ,
                                    PhotoId     => $id      );
        $rec{ PictureKey1 } = $pickey;
                
        return
    }

    if ( $e eq "PictureKey2"            )

        # Write picture record
        
        $tm->add_picture_record( PictureFileName => $pic );
        my $pickey = $tm->get_picture_key( PictureFileName => $pic );
        $tm->update_picture_record( PictureKey  => $pickey  ,
                                    PhotoId     => $id      );
        $rec{ PictureKey2 } = $pickey;
                
        return
    }

    if ( $e eq "PictureKey3"            )

        # Write picture record
        
        $tm->add_picture_record( PictureFileName => $pic );
        my $pickey = $tm->get_picture_key( PictureFileName => $pic );
        $tm->update_picture_record( PictureKey  => $pickey  ,
                                    PhotoId     => $id      );
        $rec{ PictureKey3 } = $pickey;
                
        return
    }

    if ( $name eq "AuctionRecord" ) {
    
        # Write auction record
         
        $tm->insert_DBauction_104( %rec );
    }
    
}

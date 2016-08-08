#

# Simple program to extract/print the category data retrieved from eBay

#


use XML::Parser;
use strict;

# Initialise the parser and set the category array record handler

my $parser = XML::Parser->new( Handlers=> {     Start   =>  \&elem_start    ,
                                                Char    =>  \&elem_data     ,
                                                End     =>  \&elem_end      } );

# Global Variables

my %rec;
my $e;
my $go;

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

#------------------------------------------------------------------------------
# Event Handlers
#------------------------------------------------------------------------------

sub elem_start {

    my( $expat, $name, %atts ) = @_;
    $e = $name;

    if ( $name eq "AuctionRecord" ) {
    
        print "Record: $counter\n";
        $counter++;
    }
}

sub elem_data {

    my( $expat, $data ) = @_;
    
    # clean out XML entities from the element data
    
    $data =~ s/&/&/g;
    $data =~ s/</&lt;/g;

    if ( $e eq 'PictureKey1'         ) {
         print "picture 1: $data\n";
    }

    elsif ( $e eq 'PictureKey2'         ) {
         print "picture 2: $data\n";
    }

    elsif ( $e eq 'PictureKey3'         ) {
         print "picture 3: $data\n";
    }

    else {

    }
    
}

sub elem_end {

    my( $expat, $name ) = @_;

    $e = "";
    
}

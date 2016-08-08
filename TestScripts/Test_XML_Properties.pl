#
# Simple program to extract properties from an Auctionitis XML export
#

use Auctionitis;
use XML::Parser;
use strict;

# Initialise Auctionitis

my $tm = Auctionitis->new();
$tm->initialise(Product => "Auctionitis");      # Initialise the product

# Initialise the parser and set the category array record handler

my $parser = XML::Parser->new( Handlers=> {     Start   =>  \&elem_start    ,
                                                Char    =>  \&elem_data     ,
                                                End     =>  \&elem_end      } );
# Global Variables

my %rec;
my $e;

my $file =  "C:\\Program Files\\Auctionitis\\Output\\Evan.xml";


my $counter = 1;

if     ( $file ) {
         $parser->parsefile( $file ) ;
} else {
    
         my $input = "";
         while( <STDIN> ) { $input .= $_; }
         $parser->parse( $input ) ;
}         

while((my $key, my $val) = each(%rec)) {

    print $key."  \t".$val."\n";

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
    
    if ( $name eq "Auctions" )   {

        print "\n----------------------------------------\n";
        print "   This is where I should end !!!!\n"        ;
        print "----------------------------------------\n"  ;
        
        return;
    }
    
}

#------------------------------------------------------------------------------
# Element data
#------------------------------------------------------------------------------

sub elem_data {

    my( $expat, $data ) = @_;
    
    chomp $data;    
    
    # clean out XML entities from the element data

    $data =~ s/&/&/g;
    $data =~ s/</&lt;/g;

    if (( $e eq "ExportVersion"       )     or
        ( $e eq "PublishDate"         )     or 
        ( $e eq "FileDescription"     )     or 
        ( $e eq "TradeMeID"           )     or 
        ( $e eq "CategoryServiceDate" )     or 
        ( $e eq "RecordCount"         ))    { 

            $rec{ $e } .= $data;
    }

}

#------------------------------------------------------------------------------
# Element End
#------------------------------------------------------------------------------

sub elem_end {

    my( $expat, $name ) = @_;

    print "$name\n";

    
}

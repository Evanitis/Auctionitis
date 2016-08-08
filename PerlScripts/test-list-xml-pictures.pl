#
# Program to import data created with the export function
#

use XML::Parser;


my $picdata;
my $piclist;
my $piccount = 1;

#------------------------------------------------------------------------------
# List XML Pictgures ; Element start
#------------------------------------------------------------------------------

# sub lxp_elem_start {
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

# sub lxp_elem_data {
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

# sub lxp_elem_end {
local *lxp_elem_end = sub {

    my( $expat, $name ) = @_;

    if ( $name eq "PictureFileName" ) {
        print $picname."\n";
        unless ( $picname eq "") {
            unless ( $piclist->{ $picname } eq "1" ) {
                $piclist->{ $picname } = "1";
                $piccount++;
            }
        }
    }
};

# Initialise the parser and set the category array record handler

my $parser = XML::Parser->new( Handlers => {    Start   =>  \&lxp_elem_start    ,
                                                Char    =>  \&lxp_elem_data     ,
                                                End     =>  \&lxp_elem_end      } );

# Global Variables for nested subroutines

my $e;
my $key;
my $picname;

$parser->parsefile( 'my-test-file.xml' ) ;



# End of XML Import scoping block

$picdata->{ Count } = $piccount;
$picdata->{ Data  } = $piclist;
    
return $picdata;

use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use File::Spec;
use File::Basename;
use XML::Parser;
use strict;

# Variables for zip processing

my $zip = Archive::Zip->new();

# variables for XML processing

my $parser = XML::Parser->new( Handlers=> { Start   =>  \&elem_start    ,
                                            Char    =>  \&elem_data     ,
                                            End     =>  \&elem_end      } );
my $e;
my $counter = 1;
my %piclist;
    
my $zipfile = shift;
my $xmlfile = shift;

process_xml();

chdir "\\";

foreach my $item (keys %piclist) {
    $item =~ m/C:\\(.+?$)/;
    $item = $1;
    $item =~ tr/\\/\//;
    print "$item \n";
    my $member = $zip->addFile( $item );
    $member->desiredCompressionMethod( COMPRESSION_DEFLATED );
    die 'write error' unless $zip->writeToFileNamed( $zipfile ) == AZ_OK;
}

# my $member = $zip->addFile( $xmlfile );
# $member->desiredCompressionMethod( COMPRESSION_DEFLATED );
# die 'write error' unless $zip->writeToFileNamed( $zipfile ) == AZ_OK;


# $xmlfile =~ s/C:(.+)/$1/;
# $xmlfile =~ tr/\\/\//;


print "Done !\n";
exit;

#------------------------------------------------------------------------------
# Event Handlers
#------------------------------------------------------------------------------

sub process_xml {

    $parser->parsefile( $xmlfile ) ;
    
}

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
         print "Found: $data\n";
         store_pic($data);
    }

    elsif ( $e eq 'PictureKey2'         ) {
         print "Found: $data\n";
         store_pic($data);
    }

    elsif ( $e eq 'PictureKey3'         ) {
         print "Found: $data\n";
         store_pic($data);
    }

    else {

    }
    
}

sub elem_end {

    my( $expat, $name ) = @_;

    $e = "";
    
}

sub store_pic {

    my $filename = shift;
    unless ( exists $piclist{$filename} ) {
        $piclist{$filename} = "1";
    }
}


sub old_store_pic {

    my $filename = shift;
    $filename =~ m/C:(.+)(\\)(.+$)/;
    my $picpath = $1;
    my $picfile = $3;

    chdir $picpath;
    
    unless ( $zip->memberNamed( $picfile ) ) {

        print "Zipping $picfile\n";
        my $member = $zip->addDirectory( $picpath );
        $member = $zip->addFile( $picfile );
        $member->desiredCompressionMethod( COMPRESSION_STORED );
        die 'write error' unless $zip->writeToFileNamed( $zipfile ) == AZ_OK;
        
    }

}
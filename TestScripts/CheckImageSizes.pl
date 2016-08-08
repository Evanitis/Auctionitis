#!perl -w

use strict;
use DBI;
use Digest::MD5;

my $dbh;    # SQLite datbase

initialise();
my $images = get_all_pictures();
compare_sizes( $images );

sub compare_sizes {
    print "\nRetrieved ".scalar( @$images )." picture file records from database\n";
    
    foreach my $image ( @$images ) {
        my @exists = stat( $image->{ PictureFileName } );
        if ( @exists ) {

            local $/;                                                      #slurp mode (undef)
            local *IMG;                                                    #create local filehandle
            open ( IMG, "$image->{ PictureFileName } \0");
            binmode IMG;
            my $imagedata = <IMG>;                                           #read whole file
            close(IMG);                                                      # ignore retval

            my $diff =  $exists[7]-length( $imagedata);

            if ( $diff gt 0 ) {
                my $msg = "Filename ".$image->{ PictureFileName }." Reported Size: ".$exists[7]."Calculate Size: ".length( $imagedata);
                $msg .= " Difference: ".( $exists[7]-length( $imagedata))."\n";
                print $msg;
            }
        }
        else {
            print "File not found: ".$image->{ PictureFileName }."\n";
        }
    }
}

sub initialise {

# Connect to the database
   
    my $dbfile = "toyplanet.db3";
    $dbh  = DBI->connect( "dbi:SQLite:dbname=$dbfile","","" );

}

sub get_all_pictures {

    my $sth = $dbh->prepare( qq { SELECT * FROM   Pictures } );
    
    $sth->execute;

    my $returndata = $sth->fetchall_arrayref({});

    # If the record was found return the details otherwise populate the error structure

    if ( defined( $returndata ) ) {    
        return $returndata;
    }
    else {
        print "problem accessing picture table in Auctionitis database\n";
    }
}


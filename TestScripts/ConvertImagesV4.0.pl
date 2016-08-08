#!perl -w

use strict;
use DBI;
use Digest::MD5;

my $dbh;    # SQLite datbase
my $sql_update_picture_data;
my $converted = 0;
my $notfound = 0;
my $md5;

# Get datbase and log file path from command line

my $path = shift;
$path = "C:\\Program Files\\Auctionitis" unless defined( $path );

# Open the Conversion Log file

open my $log, ">> $path\\Auctionitis-4.0-Conversion.log";

initialise();
my $images = get_all_pictures();
process_images( $images );

print $log "Summary: Pictures successfully converted:".$converted."\n";
print $log "         Pictures not found (ignored)   :".$notfound."\n";
print      "Summary: Pictures successfully converted:".$converted."\n";
print      "         Pictures not found (ignored)   :".$notfound."\n";


sub process_images {
    print $log "\nRetrieved ".scalar( @$images )." picture file records from database\n";
    
    foreach my $image ( @$images ) {

        print "Converting ".$image->{ PictureFileName }."\n";

        my @exists = stat( $image->{ PictureFileName } );
        if ( @exists ) {

            $image->{ PictureFileName } =~ m/(.*)\\(.*)$/;
            my $filename = $2;

            local $/;                                                      #slurp mode (undef)
            local *IMG;                                                    #create local filehandle
            open ( IMG, "$image->{ PictureFileName } \0");
            binmode IMG;
            my $imagedata = <IMG>;                                           #read whole file
            close(IMG);                                                      # ignore retval

            $md5->add( $imagedata );

            update_picture_data(
                ImageName   =>  $filename               ,
                ImageData   =>  $imagedata              ,
                ImageHash   =>  $md5->hexdigest()       ,
                ImageSize   =>  $exists[7]              ,
                PictureKey  =>  $image->{ PictureKey }  ,
            );
            $converted++;
        }
        else {
            print $log "File not found: ".$image->{ PictureFileName }."\n";
            print      "File not found: ".$image->{ PictureFileName }."\n";
            $notfound++;
        }
    }
}

sub initialise {


    print $log "\n------------------------------------------------------------------------\n";
    print $log "   Saving Image Data to Database\n";
    print $log "------------------------------------------------------------------------\n";
    print      "\n------------------------------------------------------------------------\n";
    print      "   Saving Image Data to Database\n";
    print      "------------------------------------------------------------------------\n";

    # Connect to the database
   
    my $dbfile = "$path\\auctionitis.db3";
    $dbh  = DBI->connect( "dbi:SQLite:dbname=$dbfile","","" );

    # SQL to insert row into table: AuctionImages

    my $SQL = qq {
        UPDATE  Pictures 
        SET     ImageName   = ?,
                ImageData   = ?,
                ImageHash   = ?,
                ImageSize   = ?
        WHERE   PictureKey  = ?
    };

    $sql_update_picture_data = $dbh->prepare( $SQL ) || die "Error preparing statement: $DBI::errstr\n";

    $md5 = Digest::MD5->new;
}

sub get_all_pictures {

    my $sth = $dbh->prepare( qq { SELECT * FROM Pictures } );
    
    $sth->execute;

    my $returndata = $sth->fetchall_arrayref({});

    # If the record was found return the details otherwise populate the error structure

    if ( defined( $returndata ) ) {    
        return $returndata;
    }
    else {
        print $log "Problem accessing PICTURE Table in Auctionitis database\n";
    }
}

sub update_picture_data {

    my $p   = { @_ };
    
    # Execute the SQL Statement           
    
    $sql_update_picture_data->execute(  
         $p->{ ImageName    },
         $p->{ ImageData    },
         $p->{ ImageHash    },
         $p->{ ImageSize    },
         $p->{ PictureKey   },
    ) 
    || die .((caller(0))[3])." - Error executing statement: $DBI::errstr\n";

}


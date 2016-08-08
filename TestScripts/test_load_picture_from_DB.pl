#!perl -w
#--------------------------------------------------------------------
# getauction.pl script to get auction details
# (prototype for bidding/watching robot)
#
# Other program notes:
#--------------------------------------------------------------------

use strict;
use Auctionitis;

my $tm = Auctionitis->new();

$tm->initialise( Product => "Auctionitis" );  # Initialise the product

$tm->DBconnect();           # Connect to the database

if ( $tm->{ ErrorStatus } eq "1" ) {
    print "$tm->{ ErrorMessage }\n"
}

print "Watermark value is: ".$tm->{ Watermark }."\n";

if ( $tm->{ ErrorStatus } eq "1" ) {
    print "$tm->{ ErrorMessage }\n"
}

$tm->login();

if ( $tm->{ ErrorStatus } eq "1" ) {
    print "$tm->{ ErrorMessage }\n"
}

my $pic = $tm->get_picture_record( PictureKey => 4 );

my $newpicture = $tm->load_picture_from_DB(
    PictureKey      =>   $pic->{ PictureKey },
    ImageName       =>   $pic->{ ImageName  },
);

if ( $tm->{ ErrorStatus } eq "1" ) {
    print "$tm->{ ErrorMessage }\n"
}

$tm->update_picture_record( 
   PictureKey       =>  $pic->{ PictureKey }    ,
   PhotoId          =>  $newpicture             ,
);
   
print "Loaded picture: $newpicture\n";

# Success.

print "Done\n";
exit(0);
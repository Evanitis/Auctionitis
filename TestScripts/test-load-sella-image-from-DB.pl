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
$tm->DBconnect();
$tm->connect_to_sella();

if ( $tm->{ ErrorStatus } eq "1" ) {
    print "$tm->{ ErrorMessage }\n"
}

my $pic = $tm->get_picture_record( PictureKey => 11363 );

my $newpicture = $tm->load_sella_image_from_DB(
    PictureKey      =>   $pic->{ PictureKey },
    ImageName       =>   $pic->{ ImageName  },
);

if ( $tm->{ ErrorStatus } eq "1" ) {
    print "$tm->{ ErrorMessage }\n"
}
   
print "Loaded picture: $newpicture\n";

# Success.

print "Done\n";
exit(0);
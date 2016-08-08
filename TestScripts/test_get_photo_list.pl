#!perl -w
#--------------------------------------------------------------------
# gettmdata.pl retrieve data from trademe for analysis and automation
# to run the script: perl.exe c:\evan\trademe\gettmdata.pl 
#
# Other program notes:
#--------------------------------------------------------------------

use strict;
use Auctionitis;

my @photos;

my $tm = Auctionitis->new();

$tm->initialise(Product => "Auctionitis");
$tm->DBconnect();                           # Connect to the database

$tm->login();


my @TMPictures = $tm->get_photo_list();

print "$#TMPictures Photo listings:\n";

foreach my $photo (@TMPictures) {

        print "Photo ID: $photo\n";
}

my %TMPictable;

foreach my $PhotoID ( @TMPictures ) {
    $TMPictable{ $PhotoID } = 1;
    print "my TM Picture: $TMPictable{ $PhotoID }\n";
}


my $currentpictures = $tm->get_all_pictures();

foreach my $picture ( @$currentpictures ) {
    print "my DB Picture:  $picture->{ PhotoId }\n";

}


my @expiredpics;

foreach my $picture ( @$currentpictures ) {

    if (not defined $TMPictable{ $picture->{ PhotoId } } ) {
        print "Expired Picture: $picture->{ PictureKey }\n";
    }   else {
        print "Current Picture: $picture->{ PictureKey }\n";
    }
}


print "$tm->{StatusMessage}\n";

# Success.

print "Done\n";
exit(0);

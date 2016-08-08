#!perl -w
#--------------------------------------------------------------------
# gettmdata.pl retrieve data from trademe for analysis and automation
# to run the script: perl.exe c:\evan\trademe\gettmdata.pl 
#
# Other program notes:
#--------------------------------------------------------------------

use strict;
use Auctionitis;
    
my $tm = Auctionitis->new();


$tm->initialise(Product => "Auctionitis");  # Initialise the product
$tm->DBconnect();                           # Connect to the database
$tm->login();


# Get list of pictures from TradeMe

my @TMPictures = $tm->get_photo_list();

my %TMPictable;

foreach my $PhotoID ( @TMPictures ) {
    $TMPictable{ $PhotoID } = 1;
    print "TradeMe picture ID: $PhotoID\n";
    
}



my $currentpictures = $tm->get_all_pictures();

my @expiredpics;

foreach my $picture ( @$currentpictures ) {

    print "Database Record: $picture->{PictureKey} Photo ID: $picture->{ PhotoId }\n";

    if (not defined $TMPictable{ $picture->{ PhotoId } } ) {

        print "Located expired Photo $picture->{PictureFileName} (Record $picture->{PictureKey})\n";
        push(@expiredpics, $picture->{ PictureKey });
    }
}

# If any expired pics are encountered upload them to TradeMe

if ( scalar(@expiredpics) > 0 ) {

    foreach my $expiredpic ( @expiredpics ) {
        print "expired key from expired pics array: $expiredpic\n";
    }
    

}

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

# $tm->login();


my %picturekeys         =   $tm->get_used_picture_keys();
my $currentpictures     =   $tm->get_all_pictures(); 

foreach my $picture ( @$currentpictures ) {
    if (not defined $picturekeys{ $picture->{ PictureKey } } ) {
        print "Unused picture $picture->{ PictureFileName } Key: $picture->{ PictureKey }\n";
    }
}

print "$tm->{StatusMessage}\n";

# Success.

print "Done\n";
exit(0);

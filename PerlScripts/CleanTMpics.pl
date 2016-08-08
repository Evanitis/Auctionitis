#!perl -w
#--------------------------------------------------------------------
# gettmdata.pl retrieve data from trademe for analysis and automation
# to run the script: perl.exe c:\evan\trademe\gettmdata.pl 
#
# Other program notes:
#--------------------------------------------------------------------

use strict;
use Auctionitis;
use Win32::OLE;

my ($tm, $pb, $estruct, $abend);

my @photos;

$tm = Auctionitis->new();

$tm->initialise(Product => "Auctionitis");

$tm->login();

print "Retrieving List of pictures to Delete\n";

my @TMPictures = $tm->get_tm_unused_photos();

print "\n";

my $total = scalar(@TMPictures);
print $total." Photos to be deleted\n\n";

sleep 1;
my $counter = 1;

foreach my $photo (@TMPictures) {

        print "Deleting Picture ID: ".$photo." (".$counter." of ".$total.")\n";
        $tm->delete_tm_photo($photo);
        $counter++;
        sleep 1;
}

# Success.

print "Done\n";
exit(0);

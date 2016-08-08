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

my $TMPictures = $tm->get_tm_unused_photos(\&progmsg);

my $count = scalar(@$TMPictures);

print scalar(@$TMPictures)." Photo listings:\n";

foreach my $photo (@$TMPictures) {

        print "Photo ID: $photo\n";
}

print "$tm->{StatusMessage}\n";

# Success.

print "Done\n";
exit(0);


sub progmsg {

    my $msgdta = shift;
    print "$msgdta\n";
} 


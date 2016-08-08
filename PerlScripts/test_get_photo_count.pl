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

my $pictotal = $tm->get_TM_photo_count();

$tm->set_DB_property(
    Property_Name       => "TMPictureCount" ,
    Property_Value      => $pictotal,
);


print "Total pictures on TM = $pictotal\n";

print "Done\n";
exit(0);

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

$tm->initialise( Product => "Auctionitis" );
$tm->DBconnect( "AuctionitisDEV" );                           # Connect to the database

$tm->login();

my %picturekeys = $tm->get_used_picture_keys();

foreach my $key ( keys %picturekeys ) {

        print "Photo key: $key = $picturekeys{$key}\n";
}

# Success.

print "Done\n";
exit(0);

#!perl -w
#--------------------------------------------------------------------
# gettmdata.pl retrieve data from trademe for analysis and automation
# to run the script: perl.exe c:\evan\trademe\gettmdata.pl 
#
# Other program notes:
#--------------------------------------------------------------------

use strict;
use Auctionitis;

my $keylist;
my @list;

my $keylist;

@list = ("10");

my $tm = Auctionitis->new();

$tm->initialise( Product => "Auctionitis" );
$tm->DBconnect( "AuctionitisDEV" );                           # Connect to the database

print "Key Count: ".scalar( @list )."\n";

my $pictures =  $tm->get_selected_unloaded_pictures(
    AuctionKeys =>  \@list      ,
    AuctionSite =>  "TradeMe"   ,
);

print "Picture Count: ".scalar(@$pictures)."\n";

foreach my $picture ( @$pictures ) {
    print "Retrieved ".$picture->{ PictureFileName }. " [ ".$picture->{ PictureKey }." ]\n"
}

if ( $tm->{ StatusMessage } ) {
    print $tm->{ StatusMessage }."\n";
}

my $pictures =  $tm->get_selected_unloaded_pictures(
    AuctionKeys =>  \@list      ,
    AuctionSite =>  "Sella"     , 
);

print "Picture Count: ".scalar(@$pictures)."\n";

foreach my $picture ( @$pictures ) {
    print "Retrieved ".$picture->{ PictureFileName }. " [ ".$picture->{ PictureKey }." ]\n"
}

if ( $tm->{ StatusMessage } ) {
    print $tm->{ StatusMessage }."\n";
}

# Success.

print "Done\n";
exit(0);

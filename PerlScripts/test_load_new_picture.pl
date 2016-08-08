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

$tm->DBconnect("Auctionitis");           # Connect to the database

   if ( $tm->{ErrorStatus} eq "1" ) {
        print "$tm->{ErrorMessage}\n"
   }
   
   $tm->initialise(Product => "Auctionitis");  # Initialise the product

   print "Watermark value is: ".$tm->{ Watermark }."\n";

   if ( $tm->{ErrorStatus} eq "1" ) {
        print "$tm->{ErrorMessage}\n"
   }
   
   $tm->login();

   if ( $tm->{ErrorStatus} eq "1" ) {
        print "$tm->{ErrorMessage}\n"
   }

my $picfile = "C:\\Evan\\Auctionitis103\\Images\\Magic Slippers 2\.jpg";

$tm->login();

my $newpicture = $tm->load_picture( FileName      =>   $picfile);

   if ( $tm->{ErrorStatus} eq "1" ) {
        print "$tm->{ErrorMessage}\n"
   }
   
print "Loaded picture: $newpicture\n";

# Success.

print "Done\n";
exit(0);
#!perl -w
#--------------------------------------------------------------------
# function to test the auction load process
# Other program notes:
#--------------------------------------------------------------------

use strict;
# use Auctionitis;
use Win32::OLE;

my $debug = 0;

my $fuckedpgm = Win32::OLE->new( 'TMLoader') or die;

my $hashdata = '122edddjjjtjshsgdfgfooitjubhagdfcjvlgpo????????????????????????????????????????????????????iiasopkjfahafgbf vulklkm1324u0854u600002';
my $hash    = $fuckedpgm->GetMD5HashFromFile( $hashdata );

print "Hash - ".$hash."\n";

# Success.

print "Done\n";
exit(0);

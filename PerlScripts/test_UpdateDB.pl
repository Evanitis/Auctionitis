#!perl -w
#--------------------------------------------------------------------
# function to test the auction load process
# Other program notes:
#--------------------------------------------------------------------

use strict;
# use Auctionitis;
use Win32::OLE;

my $debug = 0;

my $fuckedpgm = Win32::OLE->new('TMLoader') or die;
my $returncode = 0;


my $error = $fuckedpgm->UpdateDB();

if ( $error->{ ErrStatus } ) {
    print "$error->{ErrMsg}\n";
}

# Success.

print "Done\n";
exit(0);

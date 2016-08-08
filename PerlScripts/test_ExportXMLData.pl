#!perl -w
#--------------------------------------------------------------------
# function to test the auction load process
# Other program notes:
#--------------------------------------------------------------------

use strict;
use Auctionitis;
use Win32::OLE;

my $debug = 0;

my $fuckedpgm = Win32::OLE->new( 'TMLoader' ) or die;
my $returncode = 0;

# Parameters for ExportXMLData

my $SQLSelect   = qq{ SELECT * FROM Auctions };
my $outfile     = 'Test_ExportXMLData.xml';
my $filetext    = 'File to test XMP export function';
my $makezip     = '0';
my $includepics = '0';

my $error = $fuckedpgm->ExportXMLData(
    $SQLSelect  ,
    $outfile    ,
    $filetext   ,
    $makezip    ,
    $includepics,
);

if ( $error->{ ErrStatus } ) {
    print "$error->{ ErrMsg }\n";
}

# Success.

print "Done\n";
exit(0);

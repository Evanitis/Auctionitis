#!perl -w
#--------------------------------------------------------------------
# SetDefaultDatabase.pl
#
# Usage SetDefaultDatabase "<PathName>" 
#
# Compiled to .exe file
# Perlapp --force --GUI --exe SetDBProperty SetDBProperty.pl
#--------------------------------------------------------------------

use strict;
use Win32::OLE;
use Win32::Env;

use constant {
    eSourceType         => 1    ,
    eTypeText           => 1    ,
    eTypeBinary         => 3    ,
    eTypeDWORD          => 4    ,
    eTypeFloat          => 5    ,
    eTypeNone           => 0    ,
    eRegKeyLocalMachine => 1    ,
    eRegKeyCurrentUser  => 2    ,
};

# Create the new object

my $path = shift;

# Create the new object

my $db = Win32::OLE->new( 'EZTools.RegDb' ) or die;

# Set the license key

my $msg = $db->SetLicense(  '7542564C5C482E5C425E46', 'Auctionitis' );

# open the Registry DB

$db->Open( 'Auctionitis.profile', eSourceType , 1 );
$db->{ CipherKey } = 'Auctionitis' ;

my $regkey = $db->OpenKey( eRegKeyLocalMachine, 'Auctionitis/Properties', 0, 1 );
my $dftdb = $db->GetValue( $regkey, 'DefaultDatabase' );

$db->Close();

if ( defined $dftdb ) {
    my $ok = SetEnv( ENV_USER, 'AuctionitisDefaultDatabase', $dftdb );
    my $ok = SetEnv( ENV_USER, 'AuctionitisDB', $dftdb );
    print "OK: ".$ok."\n";
    print $dftdb."\n";
    exit(0);
}
else {
    SetEnv( ENV_USER, 'AuctionitisDefaultDatabase', 'NONE' );
    exit(1)
}


            

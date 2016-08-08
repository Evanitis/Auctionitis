use strict;
use Win32::OLE;
use Win32::TieRegistry; 
use Auctionitis;

use constant {
    eSourceType         => 1            ,
    eTypeText           => 1            ,
    eTypeBinary         => 3            ,
    eTypeDWORD          => 4            ,
    eTypeFloat          => 5            ,
    eTypeNone           => 0            ,
    eRegKeyLocalMachine => 1            ,
    eRegKeyCurrentUser  => 2            ,
};

             
my $xKey = Win32::OLE->new('AuctXKey.modAuctXKey') or die;
my $returncode = 0;

my $KeyExpiry   = "31/12/2012";
my $KeyInput    = "Auctionitis";
my $KeyValue    = "YJMDUMBUA60PMQ7B";
my $KeyProduct  = "Auctionitis";
my $KeyStatus;
my $KeyOK;

$xKey->{ KeyValue   } = $KeyValue;
$xKey->{ KeyInput   } = $KeyInput;
$xKey->{ KeyProduct } = $KeyProduct;
$xKey->{ KeyExpiry  } = $KeyExpiry;

print "Checking License for ID: ".$KeyInput." Key: ".$KeyValue." Expiry: ".$KeyExpiry."\n";

$xKey->CheckKey();

if   ($xKey->{KeyOK}) { print "Auctionitis Key validated successfully\n"; }
else                  { print "Auctionitis key Check Failed: $xKey->{KeyStatus}\n"; }

# Get License details from from registry

my $reg = Win32::OLE->new( 'EZTools.RegDb' ) or die "Couldnt Open Profile datastore\n";
my $regmsg = $reg->SetLicense( '7542564C5C482E5C425E46', 'Auctionitis' );   # Set the license key

$reg->Open( 'Auctionitis.Profile', eSourceType , 0 );                       # Open Registry Database

my $key     = 'Auctionitis/Properties';
my $regkey  = $reg->OpenKey( eRegKeyLocalMachine, $key, 0, 0 );

$KeyValue   = scalar( $reg->GetValue( $regkey, 'AuctionitisKey' ) );
$KeyInput   = scalar( $reg->GetValue( $regkey, 'TradeMeID' ) );
$KeyExpiry  = scalar( $reg->GetValue( $regkey, 'KeyExpiryDate' ) );
$KeyProduct = "Auctionitis";

$xKey->{ KeyValue   } = $KeyValue;
$xKey->{ KeyInput   } = $KeyInput;
$xKey->{ KeyProduct } = $KeyProduct;
$xKey->{ KeyExpiry  } = $KeyExpiry;

print "Checking License for ID: ".$KeyInput." Key: ".$KeyValue." Expiry: ".$KeyExpiry."\n";

$xKey->CheckKey();
                
if   ($xKey->{KeyOK}) { print "Auctionitis Key validated successfully\n"; }
else                  { print "Auctionitis key Check Failed: $xKey->{KeyStatus}\n"; }

print "     KeyOK: ".$xKey->{ KeyOK     }."\n";
print " KeyStatus: ".$xKey->{ Status    }."\n";
print "KeyExpired: ".$xKey->{ Expired   }."\n";

$xKey->KeyMessage("Sample of the key validator issuing a message");

print "Key Value: $xKey->{gKeyValue}\n"; 
print "Input:     $xKey->{gKeyinput}\n"; 
print "Product:   $xKey->{gKeyProduct}\n"; 
print "Expiry:    $xKey->{gKeyExpiry}\n";

my $tm = Auctionitis->new();
$tm->initialise( Product => "Auctionitis" );
print "Program product is: ".$tm->{ Product }."\n";
# Test that the license is valid
# the valid_license method returns '1' if the license is in error
# If the license is invalid hold the queue

$tm->valid_license();
if ( $tm->{ ErrorStatus } eq '1' ) {
    print $tm->{ ErrorMessage }."\n";
    print "Release the processing queue when the license has been entered correctly\n";
}

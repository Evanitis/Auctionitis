use strict;
use Win32::OLE;

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

my $db = Win32::OLE->new( 'EZTools.RegDb' ) or die;

# Set the license key

print "Calling Set License function called\n";

my $msg = $db->SetLicense(  '7542564C5C482E5C425E46', 'Auctionitis' );

print "Set License function called\n";
print $msg."\n";

# Check whether the Registry DB is open

$db->Open( 'config.regdb', eSourceType , 1 );

$db->{ CipherKey } = 'Auctionitis' ;

# Check whether the Registry DB is open

print "Open: ".$db->IsOpen()."\n";

# Open/Create a key

my $regkey = $db->OpenKey( eRegKeyLocalMachine, 'Hardware/is/a/pile/o/shit/', 0, 1 );
print "Reg Key: ".$regkey."\n";

# Store some values

$db->SetValue( $regkey, 'LicenseKey', eTypeText, 0, 'Evan is cool' );
$db->SetValue( $regkey, 'UserName', eTypeText, 0, 'Auctionitis' );
$db->SetValue( $regkey, 'Password', eTypeText, 0, 'crusher66' );
$db->SetValue( $regkey, 'EncryptedPassword', eTypeText, 1, 'crusher66' );

my $regkey = $db->OpenKey( eRegKeyLocalMachine, 'Hardware/is/a/pile/o/shit/', 0, 1 );
print "Reg Key: ".$regkey."\n";

# The Enum* function return OLE collections (refer to OLE Collection object)

my $namelist = $db->EnumValues( $regkey, 0 );
print "Name List: ".$namelist."\n";

print "number of items: ".$namelist->{ Count }."\n";

if ( ref( $namelist ) eq 'Win32::OLE' ) {
    foreach my $v ( in $namelist ) {
        print "Collection Item: ".$v."\n";
        print "Item value: ".scalar( $reg->GetValue( $regkey, $v ) )."\n";
    }
}
elsif ( ref( $namelist ) eq 'HASH' ) {
    foreach my $v ( %$namelist ) {
        print "Collection Item: ".$v."\n";
        print "Item value: ".$namelist->{ $v }."\n";
    }
}

my $vallist = $db->EnumValues( $regkey, 1 );
print "Val List: ".$vallist."\n";

print "number of items: ".$vallist->{ Count }."\n";

foreach my $v ( in $vallist ) {
    print "Collection Item: ".$v."\n";
    print "Item value: ".$vallist->{ $v }."\n";
}

# Get a specific value

my $regstring   = 'Auctionitis\Options';
my $regname     = 'BackupDirectory';

my $regkey = $db->OpenKey( eRegKeyLocalMachine, $regstring, 0, 0 );

my $regvalue = $db->GetValue( $regkey, $regname );

print "RegDB value for Section [".$regstring."] Key [".$regname."]: ".$regvalue."\n"; 

# Look for a value that won't be found a specific value

$regstring   = 'Auctionitis\DoesntExist';
$regname = 'Wont Be Found';

$regkey = $db->OpenKey( eRegKeyLocalMachine, $regstring, 0, 0 );

print "Regkey for wont be found is: ".$regkey."\n";

if ( $regkey ) {
    print "regkey for nonexistent key evaluates to TRUE\n";
}
else {
    print "regkey for nonexistent key evaluates to FALSE\n";
}

if ( $regkey eq '' ) {
    print "regkey for nonexistent key evaluates to Defined but empty\n";
}


$regvalue = $db->GetValue( $regkey, $regname );

print "RegDB value for Section [".$regstring."] Key [".$regname."]: ".$regvalue."\n"; 

if ( $regvalue ) {
    print "regvalue for nonexistent subkey evaluates to TRUE\n";
}
else {
    print "regvalue for nonexistent subkey evaluates to FALSE\n";
}

if ( $regvalue eq '' ) {
    print "regvalue for nonexistent subkey evaluates to Defined but empty\n";
}

my $key     = 'Auctionitis/Personalities'; 
my $regkey  = $db->OpenKey( eRegKeyLocalMachine, $key, 0, 0 );
my $profiles = $db->EnumKeys( $regkey );

foreach my $profile ( in $profiles ) {

    $key = 'Auctionitis/Personalities/'.$profile.'/Defaults';
    
    print "Checking personality: ".$key."\n";
    
    $regkey = $db->OpenKey( eRegKeyLocalMachine, $key, 0, 0 );
    
    print 'Default Catgeory: '.$db->GetValue( $regkey, 'Category' )."\n";
    
    if ( $db->GetValue( $regkey, 'Category' ) eq '2962' ) {
        $db->SetValue( $regkey, 'Category', eTypeText, 0, '2975' );
    }
}


$db->Close();
            
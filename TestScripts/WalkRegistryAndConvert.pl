#!perl -w

# TODO: Add Setting to add DefaultDatabase to Properties Section

use strict;

use Win32::TieRegistry;
use Win32::OLE;



use constant {
    eRegDbFile          => 1    ,
    eTypeText           => 1    ,
    eTypeBinary         => 3    ,
    eTypeDWORD          => 4    ,
    eTypeFloat          => 5    ,
    eTypeNone           => 0    ,
    eRegKeyLocalMachine => 1    ,
    eRegKeyCurrentUser  => 2    ,
};

# Registry processing variables

my $pound= $Registry->Delimiter("/");
my $regroot  = 'HKEY_CURRENT_USER/Software/iRobot Limited/';
my $startkey = 'Auctionitis';

# Create the new Registry DB object; set the license key then open the config

my $db = Win32::OLE->new( 'EZTools.RegDb' ) or die;
$db->SetLicense(  '7542564C5C482E5C425E46', 'Auctionitis' );
$db->Open( 'C:\evan\auctionitis103\config.regdb', eRegDbFile , 1 );
$db->{ CipherKey } = 'Auctionitis' ;

# Check whether the Registry DB is open

print "Open: ".$db->IsOpen()."\n";
sleep 2;
# Go!

ProcessKey( $startkey );

sub ProcessKey {

    my $keyval = shift;

    print "Processing branch: $keyval\n";

    my $key = $Registry->{ $regroot.$keyval };

    my $dbregkey = $db->OpenKey( eRegKeyLocalMachine, $keyval, 0, 1 );
    
    foreach my $name ( $key->ValueNames ) {
        print "    Name: ".$name." Value: ".$key->{ $name }."\n";

        # Store the values values

        $db->SetValue( $dbregkey, $name, eTypeText, 0, $key->{ $name } );

    }
    foreach my $subkey ( $key->SubKeyNames ) {
        ProcessKey( $keyval.'/'.$subkey );
    }

}

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

# Get database and log file path from command line

my $path = shift;
$path = "C:\\Program Files\\Auctionitis" unless defined( $path );

chdir $path;

# Open the Conversion Log file

open my $log, ">> $path\\Auctionitis-4.0-Conversion.log";

print $log "\n------------------------------------------------------------------------\n";
print $log "   Convert Auctionitis Registry Settings\n";
print $log "------------------------------------------------------------------------\n";

print      "\n------------------------------------------------------------------------\n";
print      "   Convert Auctionitis Registry Settings\n";
print      "------------------------------------------------------------------------\n";


# Registry processing variables

my $pound= $Registry->Delimiter("/");
my $regroot  = 'HKEY_CURRENT_USER/Software/iRobot Limited/';
my $startkey = 'Auctionitis';

# Create the new Registry DB object; set the license key then open the config

my $db = Win32::OLE->new( 'EZTools.RegDb' ) or die;
$db->SetLicense(  '7542564C5C482E5C425E46', 'Auctionitis' );
$db->Open( "$path\\Auctionitis.Profile", eRegDbFile , 1 );
$db->{ CipherKey } = 'Auctionitis' ;

# Create Key for defaults - this key must exist for the VB exe to work correctly

$db->OpenKey( eRegKeyLocalMachine, 'Auctionitis/Personalities/Default', 0, 1 );

# Walk the registry to creat all the other values

ProcessKey( $startkey );

sub ProcessKey {

    my $keyval = shift;

    print $log "\nProcessing Registry branch: $keyval\n";

    my $key = $Registry->{ $regroot.$keyval };

    my $dbregkey = $db->OpenKey( eRegKeyLocalMachine, $keyval, 0, 1 );
    
    foreach my $name ( $key->ValueNames ) {

        # Store the values values

        $db->SetValue( $dbregkey, $name, eTypeText, 0, $key->{ $name } );

        next if $name =~ m/password/i;

        my $spacer = " " x ( 20-length( $name ) );

        print $log $name.": ".$spacer.$key->{ $name }."\n";

    }
    foreach my $subkey ( $key->SubKeyNames ) {
        ProcessKey( $keyval.'/'.$subkey );
    }
}



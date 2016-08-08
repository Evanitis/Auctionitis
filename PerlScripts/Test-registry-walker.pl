#!perl -w

# TODO: Add Setting to add DefaultDatabase to Properties Section

use strict;

use Win32::TieRegistry;

# Registry processing variables

my $pound= $Registry->Delimiter("/");
my $regroot  = 'HKEY_CURRENT_USER/Software/iRobot Limited/';
my $startkey = 'Auctionitis';

# Create the new Registry DB object; set the license key then open the config

ProcessKey( $startkey );

my $indent = 0;

sub ProcessKey {

    my $keyval = shift;

    print "Processing branch: $keyval\n";

    my $key = $Registry->{ $regroot.$keyval };
    
    foreach my $name ( $key->ValueNames ) {
        my $spacer = '';
        $spacer = ' ' x $indent;
        print $spacer."Name: ".$name." Value: ".$key->{ $name }."\n";
    }
    foreach my $subkey ( $key->SubKeyNames ) {
        $indent+=2;
        ProcessKey( $keyval.'/'.$subkey );
    }
    $indent-=2;
}

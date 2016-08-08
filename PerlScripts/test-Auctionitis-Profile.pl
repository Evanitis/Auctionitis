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

pass_one();
pass_two();
print "DOne!";

sub pass_one {

    # Create the new object
    
    my $reg = Win32::OLE->new( 'EZTools.RegDb' ) or die;
    
    # Set the license key
    
    print "Calling Set License function\n";
    
    my $msg = $reg->SetLicense(  '7542564C5C482E5C425E46', 'Auctionitis' );
    
    print "Set License function called: $msg\n";
    
    # Check whether the Registry DB is open
    
    $reg->Open( 'Auctionitis.Profile', eSourceType , 0 );
    
    print "Open: ".$reg->IsOpen()."\n";
    
    my $key     = 'Auctionitis/Personalities'; 
    my $regkey  = $reg->OpenKey( eRegKeyLocalMachine, $key, 0, 0 );
    my $profiles = $reg->EnumKeys( $regkey );

    if ( ref( $profiles ) eq 'Win32::OLE' ) {
        foreach my $profile ( in $profiles ) {
        
            $key = 'Auctionitis/Personalities/'.$profile.'/Defaults';
            
            print "Checking personality: ".$key."\n";
            
            $regkey = $reg->OpenKey( eRegKeyLocalMachine, $key, 0, 0 );
            
            print 'Default Catgeory: '.$reg->GetValue( $regkey, 'Category' )."\n";
        }
    }
    elsif ( ref( $profiles ) eq 'HASH' ) {
        foreach my $profile ( %$profiles ) {
    
            $key = 'Auctionitis/Personalities/'.$profile.'/Defaults';
    
            print "Checking personality: ".$key."\n";
    
            $regkey = $reg->OpenKey( eRegKeyLocalMachine, $key, 0, 0 );
    
            print 'Default Catgeory: '.$reg->GetValue( $regkey, 'Category' )."\n";
        }
    }

    $reg->Open( 'Auctionitis.Profile', eSourceType , 0 );              # Open Registry Database
    
    my $key     = 'Auctionitis/Properties';
    my $regkey  = $reg->OpenKey( eRegKeyLocalMachine, $key, 0, 0 );

    print "\nAuctionitis/Properties\n";
    print "-----------------------\n";

    # The Enum* function return OLE collections (refer to OLE Collection object)
    
    my $values = $reg->EnumValues( $regkey, 1 );
    
    my $object;

    if ( ref( $values ) eq 'Win32::OLE' ) {
        foreach my $item ( in $values ) {
            $object->{ $item } = $values->{ $item };
        }
    }
    elsif ( ref( $profiles ) eq 'HASH' ) {
        foreach my $item ( in $values ) {
            $object->{ $item } = $values->{ $item };
        }
    }

    foreach my $p ( sort keys %$object ) {
        next if $p =~ m/password/i;
        my $spacer = " " x ( 30-length( $p ) ) ;
        print $p.$spacer.$object->{ $p }."\n";
    }

    # Retrieve all Auctionitis options that are stored in registry
    
    $key    = 'Auctionitis/Options';
    $regkey = $reg->OpenKey( eRegKeyLocalMachine, $key, 0, 0 );

    print "\nAuctionitis/Options\n";
    print "-------------------\n";

    # The Enum* function return OLE collections (refer to OLE Collection object)
    
    my $values = $reg->EnumValues( $regkey, 1 );
    
    my $object;

    if ( ref( $values ) eq 'Win32::OLE' ) {
        foreach my $item ( in $values ) {
            $object->{ $item } = $values->{ $item };
        }
    }
    elsif ( ref( $profiles ) eq 'HASH' ) {
        foreach my $item ( in $values ) {
            $object->{ $item } = $values->{ $item };
        }
    }
    
    foreach my $p ( sort keys %$object ) {
        next if $p =~ m/password/i;
        my $spacer = " " x ( 30-length( $p ) ) ;
        print $p.$spacer.$object->{ $p }."\n";
    }

    $reg->Close();

}

            
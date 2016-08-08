#!perl -w
#--------------------------------------------------------------------
# WriteAuctionitisSetupINI.pl
#
# Used to creat an .INI file for use with the QSETUP utility
#
#--------------------------------------------------------------------

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

my $datafile    = shift;
my $inifile     = shift;

$datafile   = "Auctionitis.profile" unless defined( $datafile );
$inifile    = "Auctionitis.INI"     unless defined( $inifile );

# Create the Setup INI file

open INI, "> $inifile";

# Create the new object

my $reg = Win32::OLE->new( 'EZTools.RegDb' ) or die "Couldnt Open Profile datastore\n";
my $regmsg = $reg->SetLicense( '7542564C5C482E5C425E46', 'Auctionitis' );           # Set the license key

$reg->Open( $datafile, eSourceType , 0 );              # Open Registry Database

# Extract the Auctionitis Properties from the Registry file

my $key     = 'Auctionitis/Properties';
my $regkey  = $reg->OpenKey( eRegKeyLocalMachine, $key, 0, 0 );

if ( defined( $regkey ) ) {

    print INI "[Properties]\n";
    
    my $values = $reg->EnumValues( $regkey, 0 );
    
    # The Enum* function return OLE collections (refer to OLE Collection object)
    # BUT when compiled by PerlCTRL this is handled as a HASH (presumably the
    # PerlCTRL compiler does some magic in the executable, maybe tie or something)
    # so we need to test the reference type to execute the correct type of loop
    
    if ( ref( $values ) eq 'Win32::OLE' ) {
        foreach my $item ( in $values ) {

            next if $item =~ m/password/i;

            print INI $item."=".scalar( $reg->GetValue( $regkey, $item ) )."\n";
            print $item."=".scalar( $reg->GetValue( $regkey, $item ) )."\n";
        }
    }
    elsif ( ref( $values ) eq 'HASH' ) {
        foreach my $item ( %$values ) {

            next if $item =~ m/password/i;

            print INI $item."=".$values->{ $item }."\n";;
            print $item."=".$values->{ $item }."\n";;
        }
    }
}

print "finished reading registry\n";

close( INI ) ;

$reg->Close();


            

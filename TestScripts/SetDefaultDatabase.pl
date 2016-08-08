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

# Set the path to the profile object

my $app_path = shift;
$app_path = "C:\\Program Files\\Auctionitis" unless defined( $app_path );

chdir $app_path;

# Set the database path
my $db_path = shift;
$db_path = "C:\\Program Files\\Auctionitis" unless defined( $db_path );

# Create the new object

my $db = Win32::OLE->new( 'EZTools.RegDb' ) or die;

# Set the license key

my $msg = $db->SetLicense(  '7542564C5C482E5C425E46', 'Auctionitis' );

# open the Registry DB

$db->Open( "$app_path\\Auctionitis.profile", eSourceType , 1 );

# Set the default database in the Properties Node

my $regkey = $db->OpenKey( eRegKeyLocalMachine, 'Auctionitis/Properties', 0, 1 );
$db->SetValue( $regkey, 'DefaultDatabase', eTypeText, 0, $db_path.'\\Auctionitis.db3' );
$db->SetValue( $regkey, 'DefaultDatabasePath', eTypeText, 0, $db_path );

# Set the default Directory values

$regkey = $db->OpenKey( eRegKeyLocalMachine, 'Auctionitis/Options', 0, 1 );

my $exists = $db->GetValue( $regkey, 'BackupDirectory' );
$db->SetValue( $regkey, 'BackupDirectory',  eTypeText, 0, $app_path.'\\Backups' ) unless $exists;

$exists = $db->GetValue( $regkey, 'DataDirectory' );
$db->SetValue( $regkey, 'DataDirectory',    eTypeText, 0, $app_path.'\\Data'    ) unless $exists;

$exists = $db->GetValue( $regkey, 'LogDirectory' );
$db->SetValue( $regkey, 'LogDirectory',     eTypeText, 0, $app_path.'\\Logs'    ) unless $exists;

$exists = $db->GetValue( $regkey, 'OutputDirectory' );
$db->SetValue( $regkey, 'OutputDirectory',  eTypeText, 0, $app_path.'\\Output'  ) unless $exists;

$exists = $db->GetValue( $regkey, 'PictureDirectory' );
$db->SetValue( $regkey, 'PictureDirectory', eTypeText, 0, $app_path.'\\Images'  ) unless $exists;

$db->Close();
            

#!perl -w
#---------------------------------------------------------------------------------------------
# Copyright 2002, Evan Harris.  All rights reserved.
#---------------------------------------------------------------------------------------------

use Win32::TieRegistry; 
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use Crypt::CBC;
use Net::FTP;
use strict;

my $pound = $Registry->Delimiter("/");

my $passkey = 'AuctionitisIsVeryKewl';

my $cipher = Crypt::CBC->new(
    -key         => $passkey    ,
    -header      => 'salt'  ,
);

my $key   = $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Properties"}
         or die "Package Auctionitis.pm can't read LMachine/System/Disk key: $^E\n";

my $securityxml;

$securityxml .= "<AccountName>".$key->{ "/AccountName"}."<\/AccountName>";
$securityxml .= "<AccountPassword>".$key->{ "/AccountPassword"}."<\/AccountPassword>";
$securityxml .= "<TradeMeID>".$key->{ "/TradeMeID"}."<\/TradeMeID>";

my $ciphertext = $cipher->encrypt( $securityxml );

# Variables for zip processing

my $zip = Archive::Zip->new();
    
my $zipfile     = "ziptesting.zip";
my $database    = "c:\\Program Files\\Auctionitis\\Auctionitis.mdb";

my $member = $zip->addFile( $database, $key->{ "/TradeMeID"}.'.mdb' );
my $string = $zip->addString( $ciphertext, 'encrypted.txt' );
$member->desiredCompressionMethod( COMPRESSION_DEFLATED );
die 'Error writing ZIP file' unless $zip->writeToFileNamed( $zipfile ) == AZ_OK;

print "Done !\n";
exit;


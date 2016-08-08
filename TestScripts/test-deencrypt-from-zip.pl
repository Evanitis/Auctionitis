#!perl -w
#---------------------------------------------------------------------------------------------
# Copyright 2002, Evan Harris.  All rights reserved.
#---------------------------------------------------------------------------------------------

use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use Archive::Zip::MemberRead;
use Crypt::CBC;
use strict;

my $passkey = 'AuctionitisIsVeryKewl';
#my $iv      = Crypt::CBC->random_bytes(8);

my $cipher = Crypt::CBC->new(
    -key         => $passkey    ,
#    -iv          => $iv     ,
    -header      => 'salt'  ,
);

my $securityxml;

my $zip = Archive::Zip->new( 'ziptesting.zip' );
my $fh  = Archive::Zip::MemberRead->new( $zip, 'encrypted.txt' );

while ( defined( my $line = $fh->getline() ) ) {
  $securityxml .= $line;
}
$fh->close();

my $xmltext  = $cipher->decrypt( $securityxml );

my $account     = GetXMLValue( $xmltext, 'AccountName' );
my $password    = GetXMLValue( $xmltext, 'AccountPassword' );
my $trademeid   = GetXMLValue( $xmltext, 'TradeMeID' );

print "Trade Me ID: ".$trademeid." Account: ".$account." Password: ".$password."\n";

print "Done !\n";
exit;

sub GetXMLValue {

    my $xml =shift;
    my $tag =shift;

    $xml =~ m/(<$tag>)(.+?)(<\/$tag>)/;
    return $2;

}

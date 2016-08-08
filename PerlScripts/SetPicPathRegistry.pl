use strict;
use Win32::TieRegistry;

my $pound= $Registry->Delimiter("/");
my $key = $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities"};

foreach my $subkey (  $key->SubKeyNames  ) {
    print "Subkey: $subkey\n";

    my $pn = $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities/".$subkey."/Defaults/PictureName"};
    print "PicName: ".$pn."\n"; 

    $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities/".$subkey."/Defaults/PicturePath"} = $pn;
    my $pth = $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities/".$subkey."/Defaults/PicturePath"};
    print "PicPath: ".$pth."\n";     
}

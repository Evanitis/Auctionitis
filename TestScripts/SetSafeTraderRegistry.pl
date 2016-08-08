use strict;
use Win32::TieRegistry;

my $pound= $Registry->Delimiter("/");
my $key = $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities"};

foreach my $subkey (  $key->SubKeyNames  ) {
    print "Subkey: $subkey\n";

    my $st = $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities/".$subkey."/Defaults/SafeTrader"};
    print "SafeTrader: ".$st."\n"; 

    $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities/".$subkey."/Defaults/SafeTrader"} = "0";
    $st = $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities/".$subkey."/Defaults/SafeTrader"};
    print "SafeTrader: ".$st."\n"; 
    
}


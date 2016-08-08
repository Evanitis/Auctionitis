use strict;
use Win32::TieRegistry; 

my $pound   = $Registry->Delimiter("/");

# Setup the registry value applicable to the product

my $regkey   = $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Options"}
          or die "Can't read HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Options key: $^E\n";

# Add 

$regkey->{ "/AlwaysMinimize" }  = "0";

# Done

print "Done\n";

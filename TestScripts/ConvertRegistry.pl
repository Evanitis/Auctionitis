#!perl -w
#---------------------------------------------------------------------------------------------
# ConvertRegistry.pl
# Prt of upgrade package to Auctionitis Version 2.0
# Copyright 2004, Evan Harris.  All rights reserved.
# Set up the new nodes/keys required in the registry before dealing with values
# Note: The Default key that is created in each node is deleted as part of the process
#---------------------------------------------------------------------------------------------
use strict;
use Win32::TieRegistry; 

my ($oldkey, $newkey, $key, $KeyValue);

my $pound   = $Registry->Delimiter("/");

#---------------------------------------------------------------------------------------------
# Add the product and company information into the HKCU Software portion of the registry
#---------------------------------------------------------------------------------------------

# Set the base key value to the new registry location/add the company value
            
$KeyValue   = $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited"};

if  ( not defined($KeyValue) || ($KeyValue = "") ) {
      $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/"} = {"/Default" => ""};
      delete $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited//Default"};
}

# Add the entry for Auctionitis under the company entry to the tree

$KeyValue   = $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis"};

if  ( not defined($KeyValue) || ($KeyValue = "") ) {
      $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/"} = {"/Default" => ""};
      delete $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis//Default"};
}

#---------------------------------------------------------------------------------------------
# Add the Options node
#---------------------------------------------------------------------------------------------

$KeyValue = $Registry->{"HKEY_CURRENT_USER/Software/Auctionitis/Options"};

if  ( not defined($KeyValue) || ($KeyValue = "") ) {
      $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Options"} = {"/Default" => ""};
      delete $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Options//Default"};
}

#---------------------------------------------------------------------------------------------
# Add the Output node
#---------------------------------------------------------------------------------------------

$KeyValue = $Registry->{"HKEY_CURRENT_USER/Software/Auctionitis/Output"};

if  ( not defined($KeyValue) || ($KeyValue = "") ) {
      $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Output"} = {"/Default" => ""};
      delete $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Output//Default"};
}

#---------------------------------------------------------------------------------------------
# add the Preferences node
#---------------------------------------------------------------------------------------------

$KeyValue = $Registry->{"HKEY_CURRENT_USER/Software/Auctionitis/Preferences"};

if  ( not defined($KeyValue) || ($KeyValue = "") ) {
      $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Preferences"} = {"/Default" => ""};
      delete $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Preferences//Default"};
}

#---------------------------------------------------------------------------------------------
# Add the Properties node
#---------------------------------------------------------------------------------------------

$KeyValue   = $Registry->{"HKEY_CURRENT_USER/Software/Auctionitis/Properties"};

if  ( not defined($KeyValue) || ($KeyValue = "") ) {
      $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Properties/"} = {"/Default" => ""};
      delete $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Properties//Default"};
}

#---------------------------------------------------------------------------------------------
# Add the Personalities node
# Extra processing required to alter this option to cater for multiple personalities
#---------------------------------------------------------------------------------------------

$KeyValue = $Registry->{"HKEY_CURRENT_USER/Software/Auctionitis/Personalities"};

if  ( not defined($KeyValue) || ($KeyValue = "") ) {
      $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities"} = {"/Default" => ""};
      delete $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities//Default"};
}

# Add the Default personality node

$KeyValue = $Registry->{"HKEY_CURRENT_USER/Software/Auctionitis/Personalities/Default"};

if  ( not defined($KeyValue) || ($KeyValue = "") ) {
      $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities/Default"} = {"/Default" => ""};
      delete $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities/Default//Default"};
}

# Add the Defaults node to the Default personality node

$KeyValue = $Registry->{"HKEY_CURRENT_USER/Software/Auctionitis/Personalities/Default/Defaults"};

if  ( not defined($KeyValue) || ($KeyValue = "") ) {
      $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities/Default/Defaults"} = {"/Default" => ""};
      delete $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities/Default/Defaults//Default"};
}

#---------------------------------------------------------------------------------------------
# Add the Schedule node
# Extra processing required to add nodes for each of the sceduling options
#---------------------------------------------------------------------------------------------

$KeyValue = $Registry->{"HKEY_CURRENT_USER/Software/Auctionitis/Schedule"};

if  ( not defined($KeyValue) || ($KeyValue = "") ) {
      $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Schedule"} = {"/Default" => ""};
      delete $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Schedule//Default"};
}

# Add a node for each scheduleing option/day number

my $days = 0;

while ( $days < 7 ) {

    $KeyValue = $Registry->{"HKEY_CURRENT_USER/Software/Auctionitis/Schedule/#".$days};

    if  ( not defined($KeyValue) || ($KeyValue = "") ) {
          $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Schedule/#0"} = {"/Default" => ""};
          delete $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Schedule/#".$days."//Default"};
    }

    $days++;
}

#---------------------------------------------------------------------------------------------
# Transfer the values from the old product if they exist
#---------------------------------------------------------------------------------------------

# Setup the registry value applicable to the product

$oldkey   = $Registry->{"HKEY_CURRENT_USER/Software/VB and VBA Program Settings/Auctionitis/Properties"}
          or die "Can't read HKEY_CURRENT_USER/Software/VB and VBA Program Settings/Auctionitis/Properties key: $^E\n";

$newkey   = $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Properties"}
          or die "Can't read HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Properties key: $^E\n";

# Convert entries from options into properties in new registry node for Auctionitis

$newkey->{ "/CategoryServiceDate"   }   = $oldkey->{ "/CategoryServiceDate" };


# Setup the registry value applicable to the product

$oldkey   = $Registry->{"HKEY_CURRENT_USER/Software/VB and VBA Program Settings/Auctionitis/Options"}
          or die "Can't read HKEY_CURRENT_USER/Software/VB and VBA Program Settings/Auctionitis/Options key: $^E\n";

$newkey   = $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Properties"}
          or die "HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Properties key: $^E\n";

# Convert entries from options into properties in new registry node for Auctionitis

$newkey->{ "/AccountName"           }   = $oldkey->{ "/UserID"              };
$newkey->{ "/AccountPassword"       }   = $oldkey->{ "/Password"            };
$newkey->{ "/AuctionitisKey"        }   = $oldkey->{ "/AuctionitisKey"      };
$newkey->{ "/KeyExpiryDate"         }   = $oldkey->{ "/KeyExpiryDate"       };

# Setup the registry value applicable to the product

$oldkey   = $Registry->{"HKEY_CURRENT_USER/Software/VB and VBA Program Settings/Auctionitis/Options"}
          or die "Can't read HKEY_CURRENT_USER/Software/VB and VBA Program Settings/Auctionitis/Options key: $^E\n";

$newkey   = $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Options"}
          or die "Can't read HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Options key: $^E\n";

# Convert entries from options into properties in new registry node for Auctionitis

$newkey->{ "/DripFeedInterval"      }   = $oldkey->{ "/DripFeedInterval"    };

# Setup the registry to transfer default values

$oldkey   = $Registry->{"HKEY_CURRENT_USER/Software/VB and VBA Program Settings/Auctionitis/Defaults"}
          or die "Can't read HKEY_CURRENT_USER/Software/VB and VBA Program Settings/Auctionitis/Defaults key: $^E\n";

$newkey   = $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities/Default/Defaults"}
          or die "Can't read HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities/Default/Defaults key: $^E\n";

# Update default preferences to Default user style

$newkey->{ "/AuctionDuration"       }   = $oldkey->{ "/AuctionDuration"     };
$newkey->{ "/AutoExtend"            }   = $oldkey->{ "/AutoExtend"          };
$newkey->{ "/BankDeposit"           }   = $oldkey->{ "/BankDeposit"         };
$newkey->{ "/BoldTitle"             }   = $oldkey->{ "/BoldTitle"           };
$newkey->{ "/BuyNow"                }   = $oldkey->{ "/BuyNow"              };
$newkey->{ "/Cash"                  }   = $oldkey->{ "/Cash"                };
$newkey->{ "/Category"              }   = $oldkey->{ "/Category"            };
$newkey->{ "/Cheque"                }   = $oldkey->{ "/Cheque"              };
$newkey->{ "/Closed"                }   = $oldkey->{ "/Closed"              };
$newkey->{ "/FeatureCombo"          }   = $oldkey->{ "/FeatureCombo"        };
$newkey->{ "/Featured"              }   = $oldkey->{ "/Featured"            };
$newkey->{ "/FreeShipNZ"            }   = $oldkey->{ "/FreeShipNZ"          };
$newkey->{ "/Gallery"               }   = $oldkey->{ "/Gallery"             };
$newkey->{ "/HomePage"              }   = $oldkey->{ "/HomePage"            };
$newkey->{ "/IsNew"                 }   = $oldkey->{ "/IsNew"               };
$newkey->{ "/PaymentInfo"           }   = $oldkey->{ "/PaymentInfo"         };
$newkey->{ "/PicDirectory"          }   = $oldkey->{ "/PicDirectory"        };
$newkey->{ "/SafeTrader"            }   = $oldkey->{ "/SafeTrader"          };
$newkey->{ "/ShipInfo"              }   = $oldkey->{ "/ShipInfo"            };

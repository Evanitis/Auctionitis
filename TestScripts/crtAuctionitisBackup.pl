#!perl -w
#---------------------------------------------------------------------------------------------
# crtAuctionitisBackup.pl
#
# Copyright 2002, Evan Harris.  All rights reserved.
# Copy the Auctionitis.database
#---------------------------------------------------------------------------------------------

use strict;
use File::Copy

unlink("##auctionitis.mdb");
copy("auctionitis.mdb", "##auctionitis.mdb");

# Success.

print "Done\n";
exit(0);

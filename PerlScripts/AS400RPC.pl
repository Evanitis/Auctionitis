#!perl -w
#

use strict;
use Win32::OLE;
use Win32::OLE::Const;

# --------------------------------------------------------------------

my($as400) = Win32::OLE -> new('cwbx.AS400System');

$as400 = cwbrcStartConversation("S30", "EVANSAPP");

print "$as400 \n";

$as400 = cwbrcEndConversation();

# Success.
print "Success \n";
exit(0);

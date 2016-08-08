#!perl -w
#

use strict;
use Win32::OLE;
use Win32::OLE::Const;
use Win32::OLE::Const;

# --------------------------------------------------------------------

my($cwberr) = Win32::OLE -> cwbsvSetup;
my($cwbdq) = Win32::OLE -> cwbdqOpen->({"OLETEST", "DEJHLIB", "ISAK170", $cwberr});
my($cwbdqatt) = Win32::OLE -> cwbdqSetup;
Win32::OLE->cwbdqGetQueueAttr({$cwbdqatt});


# Success.
print "Success \n";
exit(0);

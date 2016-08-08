#!perl -w
#

use strict;
use Win32::OLE;
use Win32::OLE::Const;
use Win32::OLE::Const;

# --------------------------------------------------------------------

my($as400) = Win32::OLE -> new('cwbx.AS400System');
my($dq) = Win32::OLE -> new('cwbx.DataQueue');

$as400->Define("ISAK170");
$as400->Connect("cwbcoServiceDataQueues");

# Success.
print "Success \n";
exit(0);

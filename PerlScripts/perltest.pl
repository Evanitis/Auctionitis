#!perl.exe
#ed.plx
# file perltest.plx (CGI)

use strict;
use warnings;
use CGI;
	
print "Content-type: text/html\n\n";
print "<html><head><title>Environment Dumper</title></head><body>";

print "<center><table border=1>";
foreach (sort keys %ENV) {
	print "<tr><td>$_</td><td>$ENV{$_}</td></tr>"
}
print "</table></center></body></html>";

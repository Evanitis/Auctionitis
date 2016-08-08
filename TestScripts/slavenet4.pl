#!C:\perl\bin\perl.exe
#slavenet.plx

use strict;
use warnings;
use Net::Telnet;

my ($ref, $FH, $FH2, $lines, $outfile, $outfile2, $screen, $username, $password, @data, @lines, $ok, $cmddata);

$outfile = "lilbrother.log";
$username = "HARRISE";
$password = "jugulator";


print "connecting to QSH session....\n";

$screen = Net::Telnet->new( Timeout => 10,
                            Prompt => '/===>/',
                            Host => '10.19.1.10');

print "Setting up logging to $outfile \n";
open ($FH,">$outfile");
$FH = $screen->input_log($FH);

print "signing on... \n";
$ok = $screen->print("$username\t$password");
$ok = $screen->print("");
$ok = $screen->print("");

#print "Sending message... \n";
#$ok = $screen->cmd("\tSNDBRKMSG MSG(HELLO) TOMSGQ(QPADEV0004)");
$ok = $screen->waitfor('/===>/');

print "working with active jobs... \n";
@lines = $screen->cmd("\tWRKACTJOB");
$ok = $screen->waitfor('/===>/');
print "Lines returned: $#lines \n";


print "Executing Signoff command to close session \n";
$ok = $screen->print("signoff");
$screen->close;
close ($FH);

print "Success \n";
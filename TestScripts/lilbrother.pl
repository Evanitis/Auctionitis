#!C:\perl\bin\perl.exe
#slavenet.plx

use strict;
use warnings;
use Net::Telnet;

my  ($screen, $username, $password, @cmddata, $ok, $FH, $outfile, $FH2, $outfile2, $outdata);

$username = "LILBROTHER";
$password = "lilbrother";
$outfile = "lilbro_in.log";
$outfile2 = "lilbro_out.log";

# Create a new connection object....
$screen = Net::Telnet->new(Timeout => 10);

print "Setting up logging to $outfile and $outfile2 \n";
open ($FH,">$outfile");
$FH = $screen->input_log($FH);
open ($FH2,">$outfile2");
$FH2 = $screen->output_log($FH2);

print "attempting to connect....\n";
$ok = $screen->open('10.19.1.50');

print "Connection status: $ok \n";

print "connected and evaluating prompts... \n";
 
$screen->waitfor('/User/');
$ok = $screen->print("$username$password");
$ok = $screen->print("");
$ok = $screen->print("");
$ok = $screen->print("");
$ok = $screen->print("");

$screen->waitfor('/$/');

print "Executing WRKACTJOB command \n";
$ok = $screen->print('system \'wrkactjob\'');
$outdata = $screen->waitfor('/$/');
print "Done; WRKACTJOB output: \n";
print "@cmddata\n";

print "Executing List files command \n";
$ok = $screen->print('ls -l');
@cmddata = $screen->waitfor('/$/');
print "Done; list data output: \n";
print "@cmddata\n";

print "Executing SIGNOFF command \n";
$ok = $screen->print("\tsignoff");
$screen->close;

close($FH);

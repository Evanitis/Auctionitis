#!C:\perl\bin\perl.exe
#slavenet.plx

use strict;
use warnings;
use Net::Telnet;

my  ($screen, $username, $password, @cmddata, $ok, $FH, $outfile, $FH2, $outfile2, $outdata);

$username = "HARRISE";
$password = "motorhead";
$outfile = "lilbro_in.log";
$outfile2 = "lilbro_out.log";

# Create a new connection object....
$screen = Net::Telnet->new(Timeout => 10,
						Prompt => '/===>/');

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
$ok = $screen->print("$username\t$password");
$ok = $screen->print("");

print "Executing WRKACTJOB command \n";
$screen->cmd("WRKACTJOB");
$screen->cmd("");
$screen->cmd("WRKSYSSTS");
$screen->cmd("");
$screen->cmd("WRKDSKSTS");
$screen->cmd("");
$screen->cmd("");
print "@cmddata\n";

print "Executing SIGNOFF command \n";
$ok = $screen->cmd("signoff *list");
$screen->close;

close($FH);
close($FH2);

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
$screen = Net::Telnet->new(Timeout => 30,
						Prompt => '/\$/');

print "Setting up logging to $outfile and $outfile2 \n";
open ($FH,">$outfile");
$FH = $screen->input_log($FH);
open ($FH2,">$outfile2");
$FH2 = $screen->output_log($FH2);

print "attempting to connect....\n";
$ok = $screen->open('10.19.1.50');
print "Connection status: $ok \n";
$ok=$screen->prompt;
print "prompt value: $ok\n";
print "connected and evaluating prompts... \n";
 
$screen->waitfor('/User/');
$ok = $screen->print("$username$password");
$ok = $screen->print("");
$ok = $screen->print("");
print "waiting for prompt...\n";
$ok = $screen->waitfor('/===>/');

print "prompt Status: $ok\n";

print "setting terminal type... \n";
$screen->cmd("env TERMINAL_TYPE=REMOTE");

#print "testing print function... \n";
#$screen->cmd("print Tambourine man");

$screen->cmd("ls -l");
$screen->cmd("");
$screen->cmd("system \'wrkactjob\'");
$screen->cmd("");
$screen->cmd("env'");
$screen->cmd("");
$screen->cmd("system \'SNDBRKMSG MSG(HELLO) TOMSGQ(QPADEV0001)\'");
$screen->cmd("");
$screen->cmd("ls -l");
$screen->cmd("");

print "Executing SIGNOFF command \n";
$ok = $screen->cmd("exit");
$ok = $screen->cmd("");
$screen->close;

close($FH);

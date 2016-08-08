#!C:\perl\bin\perl.exe
#slavenet.plx

use strict;
use warnings;
use Net::Telnet;

my ($ref, $dumplog,$optlog, $FH, $FH2, $lines, $outfile, $outfile2, $screen, $username, $password, @data, @lines, $ok, $cmddata);

$outfile = "lilbrother.log";
$dumplog = "dump_log.log";
$optlog = "opt_log.log";
$username = "lilbrother";
$password = "lilbrother";


print "connecting to QSH session....\n";

$screen = Net::Telnet->new( Timeout => 120,
                            Prompt => '/$/',
                            Host => '10.19.1.50',
                            Telnetmode => "ASCII");

print "Setting up logging to $outfile \n";
open ($FH,">$outfile");
$FH = $screen->input_log($FH);

$optlog = $screen->option_log($optlog);

print "signing on... \n";
$ok = $screen->print("$username$password");
$ok = $screen->print("");
$ok = $screen->print("");


$ok = $screen->print("env TERMINAL_TYPE=REMOTE");

print "running the WRKACTJOB command... \n";
$lines = $screen->print("system \'WRKACTJOB\'");
print "data: $lines \n";

print "running the LIST command... \n";
@lines = $screen->print('ls -l');
print "lines of data returned: $#lines \n";
print "@lines \n";

print "Executing Quit  command to close session \n";
# command is executed twice as first time it returns a message (basically requesting confirmation I guess)
$ok = $screen->cmd("exit");
$ok = $screen->cmd("exit");
$screen->close;
close ($FH);

print "Success \n";
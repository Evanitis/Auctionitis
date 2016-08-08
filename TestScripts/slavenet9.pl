#!C:\perl\bin\perl.exe
#slavenet.plx

use strict;
use warnings;
use Net::Telnet;

my ($ref, $dumplog,$optlog, $FH, $FH2, $lines, $outfile, $outfile2, $screen, $username, $password, @data, @lines, $ok, @cmddata);

$outfile = "lilbrother.log";
$dumplog = "dump_log.log";
$optlog = "opt_log.log";
$username = "harrise";
$password = "motorhead";


print "connecting to QSH session....\n";

$screen = Net::Telnet->new( Timeout => 120,
                            Prompt => '/[$>]/',
                            Host => '10.19.1.50',
                            Telnetmode => "ASCII");

print "Setting up logging to $outfile \n";
open ($FH,">$outfile");
$FH = $screen->input_log($FH);

$optlog = $screen->option_log($optlog);

print "signing on... \n";
$ok = $screen->print("$username\t$password");
$ok = $screen->print("");
$ok = $screen->print("");

$screen->waitfor('/>/');

print "running the QSH command... \n";
@lines = $screen->cmd(String => 'STRQSH', Prompt => '/$/');
print @lines;

print "setting terminal type... \n";
$ok = $screen->cmd(String => 'env TERMINAL_TYPE=REMOTE', Prompt => '/$/');

print "testing print function... \n";
$ok = $screen->cmd(String => "print Tambourine man", Prompt => '/$/');
print "$ok\n";

print "running the WRKACTJOB command... \n";
@lines = $screen->cmd(String => "system \'WRKACTJOB\'", Output => @cmddata, Prompt => '/$/');
print "$#lines\n";
print "$#cmddata\n";

print "running the LIST command... \n";
@lines = $screen->cmd(String => "ls -l", Output => @cmddata,  Prompt => '/$/');
print "$#lines\n";
print "$#cmddata\n";

print "Executing Quit  command to close session \n";
# command is executed twice as first time it returns a message (basically requesting confirmation I guess)
$ok = $screen->print("exit");
$ok = $screen->print("exit");
$screen->close;
close ($FH);

print "Success \n";
#!C:\perl\bin\perl.exe
#slavenet.plx

use strict;
use warnings;
use Net::Telnet;

my ($ref, $FH, $FH2, $line, $outfile, $outfile2, $screen, $username, $password, @wrkactjob, @lines, $ok, $cmddata);

$outfile = "netlog.log";
$username = "HARRISE";
$password = "jugulator";


print "attempting to connect....\n";

$screen = Net::Telnet->new( Timeout => 10,
                            Prompt => '/>/',
                            Host => '10.19.1.10');
#open ($FH2,">$outfile2");
#$FH2 = $screen->output_log($FH2);

print "connected and evaluating prompts... \n";
                            
#$ok = $screen->waitfor("User");
$ok = $screen->print("$username\t$password");
$ok = $screen->print("");
$ok = $screen->print("");
$ok = $screen->print("");
$ok = $screen->print("");

print "Executing WRKACTJOB command \n";
open ($FH,">$outfile");
$FH = $screen->input_log($FH);
@wrkactjob = $screen->cmd("\twrkactjob\n");
$ok = $screen->waitfor('/===>/');
print "@wrkactjob\n";
close ($FH);

$ok = $screen->print("\t");
$ok = $screen->waitfor('/===>/');

print "Printing Input buffer \n";
$ref = $screen->buffer;
print "$ref";

print "Executing WRKACTJOB command 2 \n";
$ok = $screen->cmd(String   => "WRKACTJOB",
                                Output  => @wrkactjob);
print "@wrkactjob\n";


print "Executing SIGNOFF command \n";
$ok = $screen->print("\tsignoff");
$screen->close;

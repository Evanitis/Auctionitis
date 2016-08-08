#!C:\perl\bin\perl.exe
#bot400.pl

use strict;
use warnings;
use Net::Telnet;

my ( $FH, $outfile, $screen, $username, $password, @wrkactjob, @lines, $ok, $cmddata);

$outfile = "netlog.log";
$username = "BOT400";
$password = "BOT400";


print "attempting to connect....\n";

$screen = Net::Telnet->new( Timeout => 10,
                            Prompt => '/>/',
                            Host => '10.19.1.10');

print "connected - attempting to sign on... \n";
                            
$ok = $screen->print("$username\t$password");
$ok = $screen->print("");
$ok = $screen->print("");
$ok = $screen->print("");
$ok = $screen->print("");

print "Executing BOT400 command \n";
@wrkactjob = $screen->buffer;
print "@wrkactjob\n";

 $screen->buffer_empty;
 
open ($FH,">$outfile");
$FH = $screen->input_log($FH);

$ok = $screen->cmd("call BOT400\n");
$ok = $screen->print("");
$ok = $screen->waitfor('/===>/');

close ($FH);

$ok = $screen->print("\t");
$ok = $screen->waitfor('/===>/');


print "Signing off... \n";
$ok = $screen->print("\tsignoff *list");

#!C:\perl\bin\perl.exe
#slavenet.plx

use strict;
use warnings;
use Net::FTP;

my ($ok, $ftp, $filename, $username, $password, $localdir, $remotedir, $host, @data);

$localdir = "C:\\evan\\source\\testdata";
$remotedir = "/qsys.lib/ejhlib.lib";
$filename = "EHSAVF.SAVF";
$username = "HARRISE";
$password = "jugulator";
$host = "10.19.1.10";

print "attempting to connect....\n";

$ftp = Net::FTP->new($host, Debug => 0);
print "FTP status: $ftp \n";
$ok = $ftp->login($username, $password);
print "Login Status: $ok \n";
$ok=$ftp->cwd($remotedir);

@data=$ftp->ls();
print "@data \n";

print "cwd:: $ok\n";
$ok=$ftp->pwd ();
print "pwd: $ok\n";
print "Rmt dir: $remotedir \n";
print "Rmt dir cmd sts: $ok \n";
print "\nGetting file now.... \n";
print "File to get:  $filename \n";
print "Target file:  $localdir\\$filename\n";
$ok=$ftp->binary;
print "TypeStatus: $ok \n";
$ok=$ftp->get($filename, "$localdir\\$filename");
print "get Status: $ok \n";
$ftp->quit;

print "Success ! \n";

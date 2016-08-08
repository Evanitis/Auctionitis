#!C:\perl\bin\perl.exe -w
#AddChgControl.plx

use strict;
use DBI;
use CGI;
use CGI qw (:standard);
use CGI::Carp qw(fatalsToBrowser);




UpdateChangeControl();

PrintUpdateScreen();

sub UpdateChangeControl{

my $cccusnam = param('CCCUSNAM');
my $cccusref = param('CCCUSREF');
my $cclogdat = param('CCLOGDAT');
my $ccreqdby = param('CCREQDBY');
my $ccsysnam = param('CCSYSNAM');
my $ccappnam = param('CCAPPNAM');
my $ccchgtyp = param('CCCHGTYP');
my $ccchgmgr = param('CCCHGMGR');
my $ccreqdat = param('CCREQDAT');
my $ccchgdsc = param('CCCHGDSC');
my $ccimpdtl = param('CCIMPDTL');
my $ccinsdtl = param('CCINSDTL');
my $cctestyn = param('CCTESTYN');
my $cctestby = param('CCTESTBY');
my $number = 0;
 # Connection variables - remove to another script or the environment at some stage
    local $ENV{"DBI_DRIVER"} = "mysql";
    local $ENV{"DBI_DSN"} = "ChangeControl";
    local $ENV{"DBI_USER"} = "DrMofo";
    local $ENV{"DBI_PASS"} = "Manson";    my ($dbh, $sth);
    $dbh=DBI->connect('dbi:mysql:ChangeControl') || die "Error opening database: $DBI::errstr\n";

    $sth = $dbh->prepare( qq { INSERT INTO Change_Control_Detail Values(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)}) || die "Error preparing statement: $DBI::errstr\n";
    
    $sth->execute($number, $cccusnam, $cccusref, $cclogdat, $ccreqdby, $ccsysnam, $ccappnam, $ccchgtyp, $ccchgmgr, $ccreqdat, $ccchgdsc, $ccimpdtl, $ccinsdtl, $cctestyn, $cctestby) || die "Error executing statement: $DBI::errstr\n";
    
    $dbh->disconnect || die "Error disconnecting: $DBI::errstr\n";
} #end of UpdateChangeControl
    
sub PrintUpdateScreen{

    my $cgi=new CGI;
    print $cgi->header();
    print $cgi->start_html("Change Control Confirmation screen");
    print "<a href=/chgcontrol/>Virtual Operations Change Control System</a><br>";
    print $cgi->end_html();

} #end of PrintUpdateScreen
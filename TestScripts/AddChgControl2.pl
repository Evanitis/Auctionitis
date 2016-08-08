#!C:\perl\bin\perl.exe -w
#AddChgControl.plx

use strict;
use DBI;
use CGI;
use CGI::Carp qw(fatalsToBrowser);



# Declare the incoming CGI varaiables
# my $cccusnam = 'Evan Harris';
# my $cccusref = 'EJH001';
# my $cclogdat = '16/04/2001';
# my $ccreqdby = '06/11/2001';
# my $ccsysnam = 'iRobot Websys';
# my $ccappnam = 'iRobot Virtual Dept';
# my $ccchgtyp = 'development';
# my $ccchgmgr = 'Evan Harris';
# my $ccreqdat = '05/11/2001';
# my $ccchgdsc = 'mighty long description of a change';
# my $ccimpdtl = 'details of when it is to happen and any requirements';
# my $ccinsdtl = 'how to make the change';
# my $cctestyn = 'yes';
# my $cctestby = 'Elmer Fudd';
my $cccusnam = param('cccusnam');
my $cccusref = param('cccusref');
my $cclogdat = param('cclogdat');
my $ccreqdby = param('ccreqdby');
my $ccsysnam = param('ccsysnam');
my $ccappnam = param('ccappnam');
my $ccchgtyp = param('ccchgtyp');
my $ccchgmgr = param('ccchgmgr');
my $ccreqdat = param('ccreqdat');
my $ccchgdsc = param('ccchgdsc');
my $ccimpdtl = param('ccimpdtl');
my $ccinsdtl = param('ccinsdtl');
my $cctestyn = param('cctestyn');
my $cctestby = param('cctestby');
my $number = 0;

UpdateChangeControl();

PrintUpdateScreen();

sub UpdateChangeControl{
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
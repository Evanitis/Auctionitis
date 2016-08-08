#!C:\perl\bin\perl.exe -w
#LstChgCtl.plx

use strict;
use DBI;
use CGI;
use CGI qw(:standard);
use lib qw(.);

my ($Data, $sth, $color);

tie $color, 'Colors', qw(ffffff 0e0e0e);

# Connection variables - remove to another script or the environment at some stage

local $ENV{"DBI_DRIVER"} = "mysql";
local $ENV{"DBI_DSN"} = "ChangeControl";
local $ENV{"DBI_USER"} = "DrMofo";
local $ENV{"DBI_PASS"} = "Manson";    my ($dbh, $sth);

$dbh=DBI->connect('dbi:mysql:ChangeControl') || die "Error opening database: $DBI::errstr\n";

print header;

GetChgCtlData();
print_output();

sub GetChgCtlData{

    $sth = $dbh->prepare( qq{ SELECT * from Change_Control_Detail Order by CCCUSREF});
    $sth->execute();
    $dbh->disconnect || die "Error disconnecting: $DBI::errstr\n";
}

sub print_output{
    print<<HTML;
        <HTML>
        <HEAD><TITLE>Change Control Listing</TITLE></HEAD>
        <BODY><CENTER>
        <TABLE BORDER="1" CELLSPACING="0">
        <TR BGCOLOR = "#C0C0C0">
        <TD><B>Reference</B></TD>
        <TD><B>Logged</B></TD>
        <TD><B>System</B></TD>
        <TD><B>Details</B></TD>
        </TR>
    HTML
    while($Data = $sth->fetchrow_hashref){
        print<<HTML;
        <HTML>
            <TR BGCOLOR = "$color">
            <TD>$Data->{CCCUSREF}</TD>
            <TD>$Data->{CCLOGDAT}</TD>
            <TD>$Data->{CCSYSNAM}</TD>
            <TD>$Data->{CCCHGDSC}</TD>
            </TR>
        HTML
        }
    print qq(</TABLE>);
    print qq(<P><A href=/chgcontrol/>Virtual Operations Change Control System</a><br>);
    print qq(</CENTER></BODY></HTML>;
}

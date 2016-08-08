use strict;
use warnings;
use Getopt::Std;

# Variable declarations
#-----------------------
my ($system, $year, $month);
my (%parm, $ABEND, @month_name);

@month_name=("January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December");

# Abend here document
$ABEND = <<EOD;
Parameter missing or incorrect;
The format for the command is:

programname -s <systemname> -y <4 digit year> -m <month>

All parameters are required for processing
EOD
# End of abend here document

# perform parameter checking; required parameters are:
# -s system name -y 4 digit year -m month (1-12)

getopt("sym", \%parm);

if  ($parm{s}) {
    $system = $parm{s};
} else {
    die $ABEND;
}
if  ($parm{y}) {
    $year = $parm{y};
} else {
    die $ABEND;
}
if  ($parm{m}) {
    $month = $parm{m};
} else {
    die $ABEND;
}

print "$system\n";
print "$year\n";
print "$month\n";
print "$#month_name\n";
print "$month_name[($month-1)]\n";

print "done...\n";

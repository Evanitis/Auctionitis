use strict;
use warnings;
use Getopt::Std;

# Variable declarations
#-----------------------
my ($dirname,@dirdata, $DH, $record);
my (%parm, $ABEND, @month_name);

# Abend here document
$ABEND = <<EOD;

Parameter missing or incorrect;
The format for the command is:

dirlist  -d <directory name> 

EOD
# End of abend here document

# perform parameter checking; required parameters are:
# -d file name

getopt("d", \%parm);

if  ($parm{d}) {
    $dirname = $parm{d};
} else {
    die $ABEND;
}

opendir ($DH, "$dirname") || die "Unable to open directory $dirname\n";

while ($record = readdir($DH)) {
	print "$record\n";
}

print "\nDone !\n";

use strict;
use warnings;
use Getopt::Std;

# Variable declarations
#-----------------------
my ($filename,@filedata, $FH, $record);
my (%parm, $ABEND, @month_name);

@month_name=("January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December");

# Abend here document
print "Usage for $0/n";
$ABEND = <<EOD;
Parameter missing or incorrect;
The format for the command is:

$0  -f <filename> 

All parameters are required for processing
EOD
# End of abend here document

# perform parameter checking; required parameters are:
# -f file name

getopt("f", \%parm);

if  ($parm{f}) {
    $filename = $parm{f};
} else {
    die $ABEND;
}

open ($FH,"<$filename");

while (<$FH> ) {
	$record = readline($FH);
#	print "$record\n";
	@filedata = split /,/,$record;
	print "@filedata[0]\t @filedata[1]\t @filedata[2]\t @filedata[3]";
}

print "\nDone !\n";

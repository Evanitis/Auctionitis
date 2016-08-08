#!perl -w

my $time = localtime;
print "$time\n";

sleep 5;

$time = localtime;
print "$time\n";

# End of processing
print "Processing completed normally\n";

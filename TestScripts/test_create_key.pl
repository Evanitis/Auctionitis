#--------------------------------------------------------------------
#!perl -w
#--------------------------------------------------------------------


($secs, $mins, $hrs, $dd, $mm, $yy, $dow, $jul, $isdst) = localtime;

my $count = 0;

until ( $count eq 25 ) {
    my $keygen  = "##-".rand;
    print "Key gen: ".$keygen."\n";
    sleep 1;
    $count++;
}
print "\nDone\n";


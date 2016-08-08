#!perl -w
#--------------------------------------------------------------------
use Date::Calc qw ( Delta_Days Delta_DHMS );
strict;

my @days = qw( Sunday Monday Tuesday Wednesday Thursday Friday Saturday );

($secs, $mins, $hrs, $dd, $mm, $yy, $dow, $jul, $isdst) = localtime;

my $weekday = ( localtime )[6];

my $local = time-3*24*60*60;

my $then = localtime($local);

my $lastsunday = localtime(time-((localtime)[6]*24*60*60));
my ($sdd, $smm, $syy) = (localtime(time-((localtime)[6]*24*60*60)))[3,4,5];
my $sundate = $sdd."-".($smm + 1)."-".($syy + 1900);

my $lastmonday  = localtime(time-(((localtime)[6]+6)*24*60*60));
my $lasttuesday = localtime(time-(((localtime)[6]+5)*24*60*60));
my $now = $dd."-".($mm + 1)."-".($yy + 1900);

my $curmth = (localtime)[4]+1;
my $curyr  = (localtime)[5]+1900;

my $nextmonday1  = time + 604800;
my($mdd, $mmm, $myy)   = (localtime($nextmonday1))[3,4,5];
my $nextmonday2 = $mdd."-".($mmm + 1)."-".($myy + 1900);

print "N Monday : $nextmonday1\n";
print "N Monday : $nextmonday2\n";
print "L Sunday : $lastsunday\n";
print "D Sunday : $sundate\n";
print "L Monday : $lastmonday\n";
print "Localtime: $local\n";
print "Then time: $then\n";
print "Time Now : $hrs:$mins:$secs\n";
print "Date now : $dd/$mm/$yy\n";
print "Date now : $now\n";
print "Weekday  : $dow\n";
print "Weekday2 : $weekday\n";
print "julian   : $jul\n";
print "d-saving : $isdst\n";
print "Today is : $days[ ( localtime )[6] ]\n";
print "... doing elapsed days calcs ...\n";

my @start   = ( 2008, 9, 1 );
my @end     = ( 2008, 9, 8 );
my $diff    = Delta_Days( @start, @end );
print "Difference was $diff\n";

print "... doing elapsed time calcs ...\n";

my @begtim  = ( 1960, 4, 16, 18, 31, 0 );
my @endtim  = ( 1960, 4, 16, 19, 30, 0 );

my @diftim  = Delta_DHMS( @begtim, @endtim );

print "Difference was: ".( $diftim[1]* 60 + $diftim[2] )."\n";

print "\nDone\n";



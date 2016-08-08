#!perl -w
#--------------------------------------------------------------------
use Auctionitis;

my $duration = shift;

my $tm = Auctionitis->new();
$tm->initialise(Product => "Auctionitis");  # Initialise the product
$tm->DBconnect();                          # Connect to the database

my $startd = datenow();
my $startt = timenow();
my $closed = closedate($duration);
my $closet = closetime($duration);

print "Calulcated values\n";
print "Start Date: $startd\n";
print "      Time: $startt\n";
print "  Duration: $duration\n";
print "Close Date: $closed\n";
print "      Time: $closet\n";

$startd = $tm->datenow();
$startt = $tm->timenow();
$closed = $tm->closedate($duration);
$closet = $tm->closetime($duration);

print "\nAuctionitis values\n";
print "Start Date: $startd\n";
print "      Time: $startt\n";
print "  Duration: $duration\n";
print "Close Date: $closed\n";
print "      Time: $closet\n";


print "\nDone\n";

#---------------------------------------------

sub datenow {

    my ($date, $day, $month, $year);

    # Set the day value

    if   ( (localtime)[3] < 10 )        { $day = "0".(localtime)[3]; }
    else                                { $day = (localtime)[3]; }

    # Set the month value
    
    if   ( ((localtime)[4]+1) < 10 )    { $month = "0".((localtime)[4]+1); }
    else                                { $month = ((localtime)[4]+1) ; }

    # Set the century/year value

    $year = ((localtime)[5]+1900);

    $date = $day."-".$month."-".$year;
    
    return $date;
}

sub timenow {

    my ($time, $hour, $min, $sec);

    # Set the hour value

    if   ( (localtime)[2] < 10 )                    { $hour = "0".(localtime)[2]; }
    else                                            { $hour = (localtime)[2] ; }
    
    # Set the minute value
    
    if   ( (localtime)[1] < 10 )                    { $min = "0".(localtime)[1]; }
    else                                            { $min = (localtime)[1] ; }

    # Set the second value

    if   ( (localtime)[0] < 10 )                    { $sec = "0".(localtime)[0]; }
    else                                            { $sec = (localtime)[0] ; }


    $time = $hour.":".$min.":".$sec;
    
    return $time;
}


sub closedate {

    my ($date, $day, $month, $year);

    my $elapsed = shift;

    my $closetime = time + ($elapsed * 60);

    # Set the day value

    if   ( ((localtime($closetime))[3]) < 10 )      { $day = "0".(localtime($closetime))[3]; }
    else                                            { $day = (localtime($closetime))[3]; }

    # Set the month value
    
    if   ( ((localtime($closetime))[4]+1) < 10 )    { $month = "0".((localtime($closetime))[4]+1); }
    else                                            { $month = ((localtime($closetime))[4]+1) ; }

    # Set the century/year value

    $year = ( (localtime($closetime))[5]+1900 );

    $date = $day."-".$month."-".$year;
    
    return $date;
}

sub closetime {

    my ($time, $hour, $min, $sec);

    my $elapsed = shift;

    my $closetime = time + ($elapsed * 60);

    # Set the hour value

    if   ( ((localtime($closetime))[2]) < 10 )      { $hour = "0".((localtime($closetime))[2]); }
    else                                            { $hour = ((localtime($closetime))[2]) ; }
    
    # Set the minute value
    
    if   ( ((localtime($closetime))[1]) < 10 )      { $min = "0".((localtime($closetime))[1]); }
    else                                            { $min = ((localtime($closetime))[1]) ; }


    # Set the second value

    if   ( ((localtime($closetime))[0]) < 10 )      { $sec = "0".((localtime($closetime))[0]); }
    else                                            { $sec = ((localtime($closetime))[0]) ; }

    $time = $hour.":".$min.":".$sec;
    
    return $time;
}

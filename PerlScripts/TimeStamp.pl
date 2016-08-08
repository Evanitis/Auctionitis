#!perl -w
# Progrma to provide timestamping capability to batch files etc
#--------------------------------------------------------------------
my $msg = shift;

$msg = "Timestamp:" if not defined( $msg );

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

    my ($time, $hour, $min, $sec);

    # Set the hour value

    if   ( (localtime)[2] < 10 )        { $hour = "0".(localtime)[2]; }
    else                                { $hour = (localtime)[2] ; }
    
    # Set the minute value
    
    if   ( (localtime)[1] < 10 )        { $min = "0".(localtime)[1]; }
    else                                { $min = (localtime)[1] ; }

    # Set the second value

    if   ( (localtime)[0] < 10 )        { $sec = "0".(localtime)[0]; }
    else                                { $sec = (localtime)[0] ; }


    $time = $hour.":".$min.":".$sec;

print $msg." ".$date." ".$time."\n";


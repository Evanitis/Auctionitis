#!perl.exe
#crtgraph.plx

use strict;
use warnings;
use DBI;
use CGI qw(:standard);
use GD::Text;
use GD::Graph::bars;
my $sth;
my $dbname='InterSect';
my $dbhost='localhost';
my (@SQLData, @res, @days, @CPUData1, @CPUData2, @CPUData3, @CPUData4, @CPUData5);
my $dsn="DBI:mysql:database=$dbname;host=$dbhost";
my ($system, $year, $month, $day, $SQLData, $CPUText1, $CPUText2, $CPUText3, $CPUText4, $CPUText5);
my $dbh=DBI->connect($dsn,"DrMofo","Manson");
if (!defined($dbh)) {
    print header;
    print "\nerror: There is a problem connecting to the MySQL database:\n";
    print DBI->errmsg;
    print "-" x 25;
    exit;
}

# Set month and year to the values entered on the command line
$system = $ARGV[0];
$year   = $ARGV[1];
$month  = $ARGV[2];

# Extract the values to be graphed and the headings from the managed systems files 

$sth=$dbh->prepare(qq{SELECT CPU_DATA_1, CPU_DATA_2, CPU_DATA_3, CPU_DATA_4, CPU_DATA_5 FROM managed_systems WHERE SYSTEM_NAME="$system"});
$sth->execute;
while ($SQLData = $sth->fetchrow_hashref) {
    $CPUText1 = $SQLData->{CPU_DATA_1};
    $CPUText2 = $SQLData->{CPU_DATA_2};
    $CPUText3 = $SQLData->{CPU_DATA_3};
    $CPUText4 = $SQLData->{CPU_DATA_4};
    $CPUText5 = $SQLData->{CPU_DATA_5};
}
# Extract days in month

$sth=$dbh->prepare(qq{SELECT DAYOFMONTH(COLLECTION_DATE) FROM performance_statistics WHERE (SYSTEM_NAME="$system" AND (MONTH(COLLECTION_DATE)=$month) AND (YEAR(COLLECTION_DATE)=$year)) ORDER BY DAYOFMONTH(COLLECTION_DATE)});
$sth->execute;
while (@SQLData = $sth->fetchrow_array) {
push @days, @SQLData;
}

# Extract the first CPU data set

if ($CPUText1) {
    $sth=$dbh->prepare(qq{SELECT CPU_DATA_1 FROM performance_statistics WHERE (SYSTEM_NAME="$system" AND (MONTH(COLLECTION_DATE)=$month) AND (YEAR(COLLECTION_DATE)=$year)) ORDER BY DAYOFMONTH(COLLECTION_DATE)});
    $sth->execute;
    while (@SQLData = $sth->fetchrow_array) {
    push @CPUData1, @SQLData;
    }
}

# Extract the second CPU data set (if used)

if ($CPUText2) {
    $sth=$dbh->prepare(qq{SELECT CPU_DATA_2 FROM performance_statistics WHERE (SYSTEM_NAME="$system" AND (MONTH(COLLECTION_DATE)=$month) AND (YEAR(COLLECTION_DATE)=$year)) ORDER BY DAYOFMONTH(COLLECTION_DATE)});
    $sth->execute;
    while (@SQLData = $sth->fetchrow_array) {
    push @CPUData2, @SQLData;
    }
}

# Extract the third CPU data set (if used)

if ($CPUText3) {
    $sth=$dbh->prepare(qq{SELECT CPU_DATA_3 FROM performance_statistics WHERE (SYSTEM_NAME="$system" AND (MONTH(COLLECTION_DATE)=$month) AND (YEAR(COLLECTION_DATE)=$year)) ORDER BY DAYOFMONTH(COLLECTION_DATE)});
    $sth->execute;
    while (@SQLData = $sth->fetchrow_array) {
    push @CPUData3, @SQLData;
    }
}

# Extract the fourth CPU data set (if used)

if ($CPUText4) {
    $sth=$dbh->prepare(qq{SELECT CPU_DATA_4 FROM performance_statistics WHERE (SYSTEM_NAME="$system" AND (MONTH(COLLECTION_DATE)=$month) AND (YEAR(COLLECTION_DATE)=$year)) ORDER BY DAYOFMONTH(COLLECTION_DATE)});
    $sth->execute;
    while (@SQLData = $sth->fetchrow_array) {
    push @CPUData4, @SQLData;
    }
}

# Extract the fifth CPU data set (if used)

if ($CPUText5) {
    $sth=$dbh->prepare(qq{SELECT CPU_DATA_5 FROM performance_statistics WHERE (SYSTEM_NAME="$system" AND (MONTH(COLLECTION_DATE)=$month) AND (YEAR(COLLECTION_DATE)=$year)) ORDER BY DAYOFMONTH(COLLECTION_DATE)});
    $sth->execute;
    while (@SQLData = $sth->fetchrow_array) {
    push @CPUData5, @SQLData;
    }
}

$dbh->disconnect;

# The graph data is the data from the four arrays.... (hopefully anyway)
my @data = ([@days],[@CPUData1],[@CPUData2],[@CPUData3],[@CPUData4],[@CPUData5]);

my $my_graph = new GD::Graph::bars(640,480);

$my_graph->set_legend($CPUText1, $CPUText2, $CPUText3, $CPUText4, $CPUText5);
$my_graph->set_title_font('arial', 10);
$my_graph->set_legend_font('times', 10);
$my_graph->set(
    dclrs=> [ qw(blue lyellow green dpink lblue) ],
    title => "CPU Usage by Workload type for $system",
    x_label => "Day",
    y_label => "CPU Utilization (%)",
    long_ticks => 1,
    x_ticks => 0,
    x_label_position => '.5',
    y_label_position => '.5',
    txtclr => 'black',
    bgclr => 'white',
    transparent => 0,
    interlaced => 1, 
    x_labels_vertical => 1,
    lg_cols =>2,
    bar_spacing => 4,
#    shadow_depth => 2,
    shadowclr => 'black',
    y_min_value => 0,
    y_max_value => 50,
    y_tick_number => 10,
    cumulate => 1,
  );
#my $format = $my_graph->export_format;

my $format = $my_graph->export_format;
open(IMG, ">evsgraph.$format") or die $!;
binmode IMG;
print IMG $my_graph->plot(\@data)->$format();
close IMG;

## original CGI Code
#print header("image/$format");
#binmode STDOUT;
#print $my_graph->plot(\@data)->$format();

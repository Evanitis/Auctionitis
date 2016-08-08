#!perl.exe
#crtgraph.plx

use strict;
use warnings;
use CGI qw(:standard);
use GD::Graph::bars;
use DBI;
my $sth;
my $dbname='Reports';
my $dbhost='localhost';
my (@SQLData, @res, @days, @batch, @inter, @system);
my $dsn="DBI:mysql:database=$dbname;host=$dbhost";
my ($year, $month, $day, $batch_CPU, $int_CPU, $sys_CPU, $storage);
my $dbh=DBI->connect($dsn,"DrMofo","Manson");
if (!defined($dbh)) {
    print header;
    print "\nerror: There is a problem connecting to the MySQL database:\n";
    print DBI->errmsg;
    print "-" x 25;
    exit;
}

# This line is the line that extracts the fields and will need to be changed !!!!!!!!!
# At the moment its verbatim from the book....
$year=2002;
$month=2;

# Extract days in month
$sth=$dbh->prepare(qq{SELECT PDay FROM performance_stats WHERE ((PMonth=$month) AND (PYear=$year)) ORDER BY PDay});
$sth->execute;
while (@SQLData = $sth->fetchrow_array) {
push @days, @SQLData;
}
# Extract the Batch CPU
$sth=$dbh->prepare(qq{SELECT batch_cpu FROM performance_stats WHERE ((PMonth=$month) AND (PYear=$year)) ORDER BY PDay});
$sth->execute;
while (@SQLData = $sth->fetchrow_array) {
push @batch, @SQLData;
}
# Extract the Interactive CPU
$sth=$dbh->prepare(qq{SELECT int_cpu FROM performance_stats WHERE ((PMonth=$month) AND (PYear=$year)) ORDER BY PDay});
$sth->execute;
while (@SQLData = $sth->fetchrow_array) {
push @inter, @SQLData;
}
# Extract the System CPU
$sth=$dbh->prepare(qq{SELECT sys_cpu FROM performance_stats WHERE ((PMonth=$month) AND (PYear=$year)) ORDER BY PDay});
$sth->execute;
while (@SQLData = $sth->fetchrow_array) {
push @system, @SQLData;
}
$dbh->disconnect;

# The graph data is the data from the four arrays.... (hopefully anyway)
my @data = ([@days],[@batch],[@inter],[@system]);

my $my_graph = new GD::Graph::bars(640,480);

$my_graph->set_legend("Batch", "Interactive","System");
$my_graph->set_title_font('arial', 14);
$my_graph->set_legend_font('arial',10);
$my_graph->set(
    dclrs=> [ qw(blue lyellow green) ],
    title => "CPU Usage by Workload type",
    x_label => "Day",
    y_label => "CPU Utilization (%)",
    long_ticks => 1,
    x_ticks => 0,
    x_label_position => '.5',
    y_label_position => '.5',
    txtclr => 'black',
    bgclr => 'white',
    transparent => 0,
    interlaced => 0, 
    x_labels_vertical => 1,
    lg_cols =>2,
    bar_spacing => 4,
#    shadow_depth => 2,
    shadowclr => 'black',
    y_min_value => 0,
    y_max_value => 100,
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

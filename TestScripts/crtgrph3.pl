#!perl.exe
#crtgraph.plx

use strict;
use warnings;
use CGI qw(:standard);
use GD::Graph::bars;
use DBI;
my $dbname='Reports';
my $dbhost='localhost';
my @res;
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
$month=3;
my $sth=$dbh->prepare(qq{SELECT PDay, batch_cpu, int_cpu FROM performance_stats WHERE ((PMonth=$month) AND (PYear=$year)) ORDER BY PDay});
#my $sth=$dbh->prepare(qq{SELECT day, storage FROM performance_stats ORDER BY day});
$sth->execute;
while (my @results = $sth->fetchrow_array) {
push @res, @results;
}
$dbh->disconnect;
# This line is where the data for the graphs is prepared....
# At the moment its verbatim from the book....
my @data = (
[$res[0],  $res[3],  $res[6],  $res[9],  $res[12], $res[15], $res[18], $res[21], $res[24], $res[27],
 $res[30], $res[33], $res[36], $res[39], $res[42], $res[45], $res[48], $res[51], $res[54], $res[57],
 $res[60], $res[63], $res[66], $res[69], $res[72], $res[75], $res[78], $res[81], $res[84], $res[87],
 $res[90]],
[$res[1],  $res[4],  $res[7],  $res[10], $res[13], $res[16], $res[19], $res[22], $res[25], $res[28],
 $res[31], $res[34], $res[37], $res[40], $res[43], $res[46], $res[49], $res[52], $res[55], $res[58],
 $res[61], $res[64], $res[67], $res[70], $res[73], $res[76], $res[79], $res[82], $res[85], $res[88],
 $res[91]],
[$res[2],  $res[5],  $res[8],  $res[11], $res[14], $res[17], $res[20], $res[23], $res[26], $res[29],
 $res[32], $res[35], $res[38], $res[41], $res[44], $res[47], $res[50], $res[53], $res[56], $res[59],
 $res[62], $res[65], $res[68], $res[71], $res[74], $res[77], $res[80], $res[83], $res[86], $res[89],
 $res[92]],
);

my $my_graph = new GD::Graph::bars(640,480);

$my_graph->set_legend("Batch", "Interactive");
$my_graph->set_title_font('arial', 14);
$my_graph->set_legend_font('arial',10);
$my_graph->set(
    dclrs=> [ qw(blue lyellow) ],
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

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
$month=1;
#my $sth=$dbh->prepare(qq{SELECT day, storage FROM performance_stats ORDER BY day WHERE((month=$month) AND (year=$year))});
my $sth=$dbh->prepare(qq{SELECT day, storage FROM performance_stats ORDER BY day});
$sth->execute;
while (my @results = $sth->fetchrow_array) {
push @res, @results;
}
$dbh->disconnect;
# This line is where the data for the graphs is prepared....
# At the moment its verbatim from the book....
my @data = (
    [$res[0],  $res[2],  $res[4],  $res[6],  $res[8],  $res[10], $res[12], $res[14], $res[16], $res[18],
     $res[20], $res[22], $res[24], $res[26], $res[28], $res[30], $res[32], $res[34], $res[36], $res[38],
     $res[40], $res[42], $res[44], $res[46], $res[48], $res[50], $res[52], $res[54], $res[56], $res[58],
     $res[60]],
    [$res[1],  $res[3],  $res[5],  $res[7],  $res[9],  $res[11], $res[13], $res[15], $res[17], $res[19],
     $res[21], $res[23], $res[25], $res[27], $res[29], $res[31], $res[33], $res[35], $res[37], $res[39],
     $res[41], $res[43], $res[45], $res[47], $res[49], $res[51], $res[53], $res[55], $res[57], $res[59],
     $res[61]],
);

my $my_graph = new GD::Graph::bars(640,480);

$my_graph->set_legend("Day", "Impressions");
$my_graph->set(
    dclrs=> [ qw(lgreen lyellow) ],
    title => "Top Banner stats",
    x_label => "Images",
    y_label => "Count",
    long_ticks => 1,
    x_ticks => 0,
    x_label_position => '.5',
    y_label_position => '.5',
    bgclr => 'white',
    transparent => 0,
    interlaced => 1, 
    x_labels_vertical => 1,
    lg_cols =>2,
    bar_spacing => 8,
    shadow_depth => 4,
    shadowclr => 'red',
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

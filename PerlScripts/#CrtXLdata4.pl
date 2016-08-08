#use strict;
use warnings;
use CGI qw(:standard);
use DBI;
use Getopt::Std;
use Win32::OLE;
use Win32::OLE::Const 'Microsoft Excel';

my $sth;
my $Data_Index;
my $xlfile;
my $Row_Start;
my $Row_End;
my $Cell_Ref;
my $Col_Start;
my $Col_End;
my $dbname='InterSect';
my $dbhost='localhost';
my (@SQLData, @res, @days, @CPUData1, @CPUData2, @CPUData3, @CPUData4, @CPUData5);
my $dsn="DBI:mysql:database=$dbname;host=$dbhost";
my ($system, $year, $month, $day, $SQLData, $CPUText1, $CPUText2, $CPUText3, $CPUText4, $CPUText5);
my $dbh=DBI->connect($dsn,"DrMofo","Manson");
my ($Excel, $Book, $Sheet, $Range, $Chart);

# Set month and year to the values entered on the command line

$system = $ARGV[0];
$year   = $ARGV[1];
$month  = $ARGV[2];

if ($system) {print "System Name $system\n"} else {die "System Name not specified"};
if ($year)  {print "Year $year\n"} else {die "Year not specified"};
if ($month)  {print "Month $month\n"} else {die "Month Name not specified"};

#------------------------------------------------------
# Get the data from the data base into the arrays
#------------------------------------------------------
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

print "Extracting day of month values\n";
$sth=$dbh->prepare(qq{SELECT DAYOFMONTH(COLLECTION_DATE) FROM performance_statistics WHERE (SYSTEM_NAME="$system" AND (MONTH(COLLECTION_DATE)=$month) AND (YEAR(COLLECTION_DATE)=$year)) ORDER BY DAYOFMONTH(COLLECTION_DATE)});
$sth->execute;
while (@SQLData = $sth->fetchrow_array) {
push @days, @SQLData;
}

# Extract the first CPU data set

if ($CPUText1) {
    print "Extracting data for $CPUText1\n";
    $sth=$dbh->prepare(qq{SELECT CPU_DATA_1 FROM performance_statistics WHERE (SYSTEM_NAME="$system" AND (MONTH(COLLECTION_DATE)=$month) AND (YEAR(COLLECTION_DATE)=$year)) ORDER BY DAYOFMONTH(COLLECTION_DATE)});
    $sth->execute;
    while (@SQLData = $sth->fetchrow_array) {
    push @CPUData1, @SQLData;
    }
}

# Extract the second CPU data set (if used)

if ($CPUText2) {
    print "Extracting data for $CPUText2\n";
    $sth=$dbh->prepare(qq{SELECT CPU_DATA_2 FROM performance_statistics WHERE (SYSTEM_NAME="$system" AND (MONTH(COLLECTION_DATE)=$month) AND (YEAR(COLLECTION_DATE)=$year)) ORDER BY DAYOFMONTH(COLLECTION_DATE)});
    $sth->execute;
    while (@SQLData = $sth->fetchrow_array) {
    push @CPUData2, @SQLData;
    }
}

# Extract the third CPU data set (if used)

if ($CPUText3) {
    print "Extracting data for $CPUText3\n";
    $sth=$dbh->prepare(qq{SELECT CPU_DATA_3 FROM performance_statistics WHERE (SYSTEM_NAME="$system" AND (MONTH(COLLECTION_DATE)=$month) AND (YEAR(COLLECTION_DATE)=$year)) ORDER BY DAYOFMONTH(COLLECTION_DATE)});
    $sth->execute;
    while (@SQLData = $sth->fetchrow_array) {
    push @CPUData3, @SQLData;
    }
}

# Extract the fourth CPU data set (if used)

if ($CPUText4) {
    print "Extracting data for $CPUText4\n";
    $sth=$dbh->prepare(qq{SELECT CPU_DATA_4 FROM performance_statistics WHERE (SYSTEM_NAME="$system" AND (MONTH(COLLECTION_DATE)=$month) AND (YEAR(COLLECTION_DATE)=$year)) ORDER BY DAYOFMONTH(COLLECTION_DATE)});
    $sth->execute;
    while (@SQLData = $sth->fetchrow_array) {
    push @CPUData4, @SQLData;
    }
}

# Extract the fifth CPU data set (if used)

if ($CPUText5) {
    print "Extracting data for $CPUText5\n";
    $sth=$dbh->prepare(qq{SELECT CPU_DATA_5 FROM performance_statistics WHERE (SYSTEM_NAME="$system" AND (MONTH(COLLECTION_DATE)=$month) AND (YEAR(COLLECTION_DATE)=$year)) ORDER BY DAYOFMONTH(COLLECTION_DATE)});
    $sth->execute;
    while (@SQLData = $sth->fetchrow_array) {
    push @CPUData5, @SQLData;
    }
}

$dbh->disconnect;

#------------------------------------------------------
# Build the excel stuff now that the data is extracted
#------------------------------------------------------

$xlfile = "c:\\evan\\source\\testdata\\$system\_$month\_$year\.xls";


$Excel = Win32::OLE->new("Excel.Application", "QUIT") or die ("Cannot create new object: ", Win32::OLE->LastError());
$Excel->{Visible} = 0;


$Book = $Excel->Workbooks->Add || print "Cannot Add worksheet" . Win32::OLE->LastError();
# $Book = $Excel->Workbooks->Open("$xlfile" )|| print "Cannot Open " . Win32::OLE->LastError();
$Sheet = $Book->Worksheets(1);

if ($CPUText1) {
    $Col_Start="A";
    $Row_Start="1";
    $Cell_Ref=$Col_Start.$Row_Start;
    $Range = $Sheet->Range("$Cell_Ref");
    $Range->{Value} = "Days";
    for ($Data_Index=0; $Data_Index <= $#days; $Data_Index++) {
        $Row_Start = $Data_Index+2;
        $Cell_Ref=$Col_Start.$Row_Start;
        $Range = $Sheet->Range("$Cell_Ref");
        $Range->{Value} = $days[$Data_Index];
        }
}

if ($CPUText1) {
    $Col_Start="B";
    $Row_Start="1";
    $Cell_Ref=$Col_Start.$Row_Start;
    $Range = $Sheet->Range("$Cell_Ref");
    $Range->{Value} = $CPUText1;
    for ($Data_Index=0; $Data_Index <= $#days; $Data_Index++) {
        $Row_Start = $Data_Index+2;
        $Cell_Ref=$Col_Start.$Row_Start;
        $Range = $Sheet->Range("$Cell_Ref");
        $Range->{Value} = $CPUData1[$Data_Index];
        }
}

if ($CPUText2) {
    $Col_Start="C";
    $Row_Start="1";
    $Cell_Ref=$Col_Start.$Row_Start;
    $Range = $Sheet->Range("$Cell_Ref");
    $Range->{Value} = $CPUText2;
    for ($Data_Index=0; $Data_Index <= $#days; $Data_Index++) {
        $Row_Start = $Data_Index+2;
        $Cell_Ref=$Col_Start.$Row_Start;
        $Range = $Sheet->Range("$Cell_Ref");
        $Range->{Value} = $CPUData2[$Data_Index];
        }
}

if ($CPUText3) {
    $Col_Start="D";
    $Row_Start="1";
    $Cell_Ref=$Col_Start.$Row_Start;
    $Range = $Sheet->Range("$Cell_Ref");
    $Range->{Value} = $CPUText3;
    for ($Data_Index=0; $Data_Index <= $#days; $Data_Index++) {
        $Row_Start = $Data_Index+2;
        $Cell_Ref=$Col_Start.$Row_Start;
        $Range = $Sheet->Range("$Cell_Ref");
        $Range->{Value} = $CPUData3[$Data_Index];
        }
}

if ($CPUText4) {
    $Col_Start="E";
    $Row_Start="1";
    $Cell_Ref=$Col_Start.$Row_Start;
    $Range = $Sheet->Range("$Cell_Ref");
    $Range->{Value} = $CPUText4;
    for ($Data_Index=0; $Data_Index <= $#days; $Data_Index++) {
        $Row_Start = $Data_Index+2;
        $Cell_Ref=$Col_Start.$Row_Start;
        $Range = $Sheet->Range("$Cell_Ref");
        $Range->{Value} = $CPUData4[$Data_Index];
        }
}

if ($CPUText5) {
    $Col_Start="F";
    $Row_Start="1";
    $Cell_Ref=$Col_Start.$Row_Start;
    $Range = $Sheet->Range("$Cell_Ref");
    $Range->{Value} = $CPUText5;
    for ($Data_Index=0; $Data_Index <= $#days; $Data_Index++) {
        $Row_Start = $Data_Index+2;
        $Cell_Ref=$Col_Start.$Row_Start;
        $Range = $Sheet->Range("$Cell_Ref");
        $Range->{Value} = $CPUData4[$Data_Index];
        }
}

# Calculate starting and ending column values for data range

$Col_Start = "B";
if      ($CPUText5) {$Col_End = "F";}
elsif   ($CPUText4) {$Col_End = "E";}
elsif   ($CPUText3) {$Col_End = "D";}
elsif   ($CPUText2) {$Col_End = "C";}
elsif   ($CPUText1) {$Col_End = "B";}
else    {$Col_End = "A";}

# Calculate starting and ending row values for data range

$Row_Start = "1";
$Row_End = $#days + 2;

# Set the graph to stacked column and populate data series

$Range = $Sheet->Range("$Col_Start$Row_Start:$Col_End$Row_End");
$Chart = $Excel->Charts->Add;
$Chart->{ChartType} = xlColumnStacked;
$Chart->SetSourceData({Source => $Range, PlotBy => xlColumns});

# Set the x-values series (This is a bit of a hack)
# I use an array to set the values rather than the rigmarole of referencing a range...

$Chart->SeriesCollection(1)->{XValues} = [@days];

# Set the scale characteristics

$Chart->Axes(xlValue)->{MaximumScale} = 100;

# Set chart title characteristics

$Chart->{HasTitle} = 1;
$Chart->ChartTitle->{Text} = "System Performance data for $system, $month/$year";

# Set X Axis title

$Chart->Axes(xlCategory, xlPrimary)->{HasTitle} = True;
$Chart->Axes(xlCategory, xlPrimary)->AxisTitle->Characters->{Text} = "Day of Month";

# Set Y Axis title
 
$Chart->Axes(xlValue, xlPrimary)->{HasTitle} = True;
$Chart->Axes(xlValue, xlPrimary)->AxisTitle->Characters->{Text} = "CPU Percentage";

# Make the chart visible
# $Excel->{Visible} = 1;

# save Excel worksheet and exit

$Book->SaveAs({FileName=>"$xlfile"});
$Excel->Quit;

print "Done !\n";

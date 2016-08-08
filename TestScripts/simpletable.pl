#!perl -w

use strict;
use WordLite;

my $chart = "C:\\evan\\source\\testdata\\insertgraph.doc";

my $doc = WordLite->new(filename => "C:\\evan\\source\\testdata\\simpletable.doc");

$doc->visible(1);

print "Filename being processed is: ", $doc->filename(), "\n";

my $list = WordLite->list();

$doc->write(text => "Table Testing and build example",
            style => "Heading 1",
            listformat => $list);

$doc->write();

$doc->write("This document will build a table (and test !) the table building functions");

$doc->write();

my @tabledata = ("Heading", "data", "column 3");
$doc->addtable(@tabledata);
@tabledata = ("Row 2", "crap", "yet more");
$doc->writerow(@tabledata);
@tabledata = ("Row 3", "more crap", "what the hell...");
$doc->writerow(@tabledata);
$doc->tableend();

$doc->write();

$doc->write(text => "Sample Monthly sales table",
            style => "Heading 2",
            listformat => $list);

$doc->write();

@tabledata = ("Heading", "data", "column 3", "fourth column", "fifth");
$doc->addtable(@tabledata);
@tabledata = ("January", "Fred", "12", "22", "17");
$doc->writerow(@tabledata);
@tabledata = ("January", "Mike", "11", "27", "16");
$doc->writerow(@tabledata);
@tabledata = ("February", "Fred", "15", "13", "2");
$doc->writerow(@tabledata);
@tabledata = ("February", "Mike", "14", "14", "14");
$doc->writerow(@tabledata);

$doc->tableend();

$doc->write();

$doc->write(text => "Budget variance demo table",
            style => "Heading 2",
            listformat => $list);
$doc->write();

@tabledata = ("Budget", "% variance");
$doc->addtable(@tabledata);
@tabledata = ("9500", "9.35");
$doc->writerow(@tabledata);
@tabledata = ("9500",  "16.20");
$doc->writerow(@tabledata);
@tabledata = ("10000",  "12.75");
$doc->writerow(@tabledata);
@tabledata = ("10000", "14.50");
$doc->writerow(@tabledata);
$doc->tableend();

$doc->pagebreak();
$doc->write(text => "First inserted graph",
            style => "Heading 3",
            listformat => $list);
$doc->write();
$doc->insertchart($chart);
$doc->write();
$doc->write(text => "Second inserted graph",
            style => "Heading 3",
            listformat => $list);
$doc->write();
$doc->insertchart($chart);
$doc->save();

# Success.



print "procesing complete \n";
exit(0);

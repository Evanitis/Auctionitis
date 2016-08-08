#!/usr/local/bin/perl

my $q="\"";
my $s=",";
my $n = "\n";

unless ( @ARGV[0] )   { print "input file not specified\n"; exit };
unless ( @ARGV[1] )   { print "output file not specified\n"; exit };

my ( $infile ) = @ARGV[0];
my ( $outfile ) = @ARGV[1];

print $outfile."\n";

unless ( -e $infile ) { print "input file $infile not found\n"; exit };

# Read all the data from the input file into a variable - makes it easier to parse

open ( INPUT, $infile );
undef $/;
my $data = <INPUT>;

# Open the output file

open ( OUTFILE, "> $outfile" );
print OUTFILE $q."Library Name".$q.$s.$q."Total Objects".$q.$s.$q."Can\'t Convert".$q.$n;
print $q."Library Name".$q.$s.$q."Total Objects".$q.$s.$q."Can\'t Convert".$q.$n;

while ( $data =~ m/Total\s+?Cannot\s+?Library\s+?Objects\s+?Convert\s+?-+\s+?-+\s+?-+\s+?(.+?)\s+?([0123456789,]+?)\s+?([0123456789,]+?)\s/gs ) { 

    my $lib    = $1;
    my $libobj = $2;
    my $liberr = $3;
    
    $lib    =~ tr/ //d;
    $libobj =~ tr/,//d;
    $liberr =~ tr/,//d;

    $libcount++;
    $objcount += $libobj;
    $errcount += $liberr;

    
    print OUTFILE $q.$lib.$q.$s.$libobj.$s.$liberr.$n;
    print $q.$lib.$q.$s.$libobj.$s.$liberr.$n;

}

print OUTFILE $q."$libcount Libraries".$q.$s.$objcount.$s.$errcount.$n;
print $q."$libcount Libraries".$q.$s.$objcount.$s.$errcount.$n;


close ( INPUT ); 
close ( OUTFILE );
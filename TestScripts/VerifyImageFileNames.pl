#!perl -w

# TODO: Revist this program based on Auction Images issues
# TODO: Add logic to open outpue file in Notepad on completion

use strict;
use DBI;

# Connect to the database

my $dbh=DBI->connect('dbi:ODBC:Auctionitis', {AutoCommit => 1} ) 
    || die "Error opening Auctions database: $DBI::errstr\n";

print "\nStart: Auctionitis Picture FileName validation\n";

my $count = 0;
my $duplicates = 0;

# Get the list of Images

my $images = get_all_pictures();

my %sizes;

print "\nRetrieved ".scalar( @$images )." picture file records from database\n";

foreach my $image ( @$images ) {
    my @exists = stat( $image->{ PictureFileName } );
    if ( not @exists ) {
        print "File not found: ".$image->{ PictureFileName }."\n";
        $count++;
    }
    else {
        if ( $sizes{ $exists[7] } ) {
            $sizes{ $exists[7] }++;
        }
        else {
            $sizes{ $exists[7] } = 1;
        }
    }
}

print "\nSummary: ".$count." Pictures have invalid Picture file names\n";

$count = 0;

foreach my $k ( sort keys %sizes ) {
    if ( $sizes{ $k } > 2 ) {
        $duplicates++;
    }
    $count++;
}

foreach my $image ( @$images ) {
    my @exists = stat( $image->{ PictureFileName } );
    if ( @exists ) {
        if ( $sizes{ $exists[7] } > 1 ) {
            print "File name: ".$image->{ PictureFileName }." Size: ".$exists[7]."\n";
        }
    }
}

print "\nSummary: ".$duplicates." Pictures have duplicate sizes (".$count." checked )\n";

sub get_all_pictures {

    my $sth = $dbh->prepare( qq { SELECT * FROM   Pictures });
    
    $sth->execute;

    my $returndata = $sth->fetchall_arrayref({});

    # If the record was found return the details otherwise populate the error structure

    if ( defined( $returndata ) ) {    
        return $returndata;
    }
    else {
        print "problem accessing picture table in Auctionitis database\n";
    }
}


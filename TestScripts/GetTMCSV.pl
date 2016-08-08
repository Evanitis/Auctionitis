#------------------------------------------------------------------------------------------------------------
# Download CSV Files from TradeMe to file
#------------------------------------------------------------------------------------------------------------
#!perl -w

use strict;
use Auctionitis;
use Getopt::Long;

my $type;
my $selection;
my $filename;

GetOptions (
    'Type=s'            => \$type       ,
    'Selection=s'       => \$selection  ,
    'Filename=s'        => \$filename   ,
);

# Check that the Download Type is correct

unless ( $type =~ m/Sold|Unsold|Current|Statement/i ) {
    print " Error: Invalid or Missing  Download Type\n";
    print_help();
    exit;
}

# Check that the Download Selection is correct

if ( uc( $type ) eq "SOLD" ) {
    
    if ( uc ( $selection ) eq "ALL" ) {
        $selection = "all";
    }
    elsif ( uc ( $selection ) eq "LAST7DAYS" ) {
        $selection = "last_7_days";
    }
    elsif ( uc ( $selection ) eq "LAST3DAYS" ) {
        $selection = "last_3_days";
    }
    elsif ( uc ( $selection ) eq "LAST24HOURS" ) {
        $selection = "last_24_hours";
    }
    else {
        print " Error: Invalid or Missing Selection Type\n";
        print_help();
        exit;
    }
}


if ( uc( $type ) eq "UNSOLD" ) {
    
    if ( uc ( $selection ) eq "ALL" ) {
        $selection = "all";
    }
    elsif ( uc ( $selection ) eq "LAST7DAYS" ) {
        $selection = "closed_this_week";
    }
    elsif ( uc ( $selection ) eq "LAST24HOURS" ) {
        $selection = "closed_today";
    }
    else {
        print " Error: Invalid or Missing Selection Type\n";
        print_help();
        exit;
    }
}

if ( uc( $type ) eq "CURRENT" ) {
    
    if ( uc ( $selection ) eq "ALL" ) {
        $selection = "all";
    }
    elsif ( uc ( $selection ) eq "CLOSINGTODAY" ) {
        $selection = "closing_today";
    }
    else {
        print " Error: Invalid or Missing Selection Type\n";
        print_help();
        exit;
    }
}

if ( uc( $type ) eq "STATEMENT" ) {

    if ( uc ( $selection ) eq "LAST45DAYS" ) {
        $selection = "45";
    }
    elsif ( uc ( $selection ) eq "LAST28DAYS" ) {
        $selection = "28";
    }
    elsif ( uc ( $selection ) eq "LAST14DAYS" ) {
        $selection = "14";
    }
    elsif ( uc ( $selection ) eq "LAST7DAYS" ) {
        $selection = "7";
    }
    elsif ( uc ( $selection ) eq "LAST24HOURS" ) {
        $selection = "1";
    }
    else {
        print " Error: Invalid or Missing  Selection Type\n";
        print_help();
        exit;
    }
}

# Test that file name was specified

if ( not defined( $filename )  ) {
    print " Error: No output file name specified\n";
    print_help();
    exit;
}

# Test that file name is valid and can be opened

my $validfilename = 1;

eval { open( FH, "> $filename" ) || die $validfilename = 0; };

if ( not $validfilename ) {
    print " Error: Invalid file name specified\n";
    print_help();
    exit;
}
else {
    unlink ( $filename );
}


# IF we get to here we have passed all the tests...

my $tm;

$tm = Auctionitis->new();
$tm->initialise( Product => "Auctionitis" );  # Initialise the product

my $connected = $tm->login();

if ( $tm->{ ErrorStatus } ) {
    print  " Error: ".$tm->{ ErrorMessage }."\n";
    exit;
}

if ( not $connected ) {
    print " Error: ".$tm->{ ErrorMessage }."\n";
    exit;
}

if ( uc( $type ) eq "SOLD" ) {
    $tm->get_TM_sold_csv_file(
        Filename    => $filename    ,
        Selection   => $selection   ,
    );
}
elsif ( uc( $type ) eq "UNSOLD" ) {
    $tm->get_TM_unsold_csv_file(
        Filename    => $filename    ,
        Selection   => $selection   ,
    );
}
elsif ( uc( $type ) eq "CURRENT" ) {
    $tm->get_TM_current_csv_file(
        Filename    => $filename    ,
        Selection   => $selection   ,
    );
}
elsif ( uc( $type ) eq "STATEMENT" ) {
    $tm->get_TM_statement_csv_file(
        Filename    => $filename    ,
        Selection   => $selection   ,
    );
}

sub print_help {

    print <<HELP

 Usage: GetTMCSV --Type <type> --Selection <selection> --Filename <name of file>

 Download Types:                 SOLD: Download data for Sold Auctions
                               UNSOLD: Download data for Unsold Auctions
                              CURRENT: Download data for Current Auctions
                            STATEMENT: Download Account Transaction data

 Selection Values (allowed value depends on Download Type)

 Download Type: SOLD              ALL: Auctions closed in last 45 Days
                            LAST7DAYS: Auctions closed in last 7 Days 
                            LAST3DAYS: Auctions closed in last 3 Days
                          LAST24HOURS: Auctions closed in last 24 Hours 

 Download Type: UNSOLD            ALL: Auctions closed in last 45 Days 
                            LAST7DAYS: Auctions closed in last 7 Days  
                          LAST24HOURS: Auctions closed in last 24 Hours 

 Download Type: CURRENT           ALL: All Current Listings
                         CLOSINGTODAY: Listings closing today

 Download Type: STATEMENT  LAST45DAYS: Transactions in last 45 days
                           LAST28DAYS: Transactions in last 28 days
                           LAST14DAYS: Transactions in last 14 days
                            LAST7DAYS: Transactions in last 7 days
                          LAST24HOURS: Transactions in last 24 hours
HELP
}

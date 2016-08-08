#!perl -w

use strict;
use Auctionitis;
use Getopt::Long;

my ( $delete, $selection, $daystokeep, $tm, $dd_today, $mm_today, $yy_today );


#---------------------------------------------------------------------------------------------
# --- Mainline ---
#---------------------------------------------------------------------------------------------

Initialise();

# Process Sold auctions if Sold or All specified

if ( ( uc( $selection ) eq "" ) 
or ( uc( $selection ) eq "ALL" ) ) {

    my $auctions = $tm->get_sold_listings;
    print "Building list of SOLD Auctions\n";

    foreach my $a ( @$auctions ) {
        if ( Auction_Age_In_Days( $a->{ CloseDate } ) > $daystokeep ) {
            print "SOLD Auction ".$a->{ AuctionRef }." closed on ". $a->{ CloseDate }." selected for deletion\n";
            if ( $delete ) {
                $tm->delete_auction( AuctionRef => $a->{ AuctionRef } );
            }
        }
    }
}

# Process Unsld auctions if Unsold or All specified

if ( ( uc( $selection ) eq "UNSOLD" )
or ( uc( $selection ) eq "ALL" ) ) {

    my $auctions = $tm->get_unsold_listings;
    print "Building list of UNSOLD Auctions\n";

    foreach my $a ( @$auctions ) {
        if ( Auction_Age_In_Days( $a->{ CloseDate } ) > $daystokeep ) {
            print "UNSOLD Auction ".$a->{ AuctionRef }." closed on ". $a->{ CloseDate }." selected for deletion\n";
            if ( $delete ) {
                    $tm->delete_auction( AuctionRef => $a->{ AuctionRef } );
            }
        }
    }
}

print "Done!\n";

##############################################################################################
# --- Methods/Subroutines ---
##############################################################################################

sub Initialise {

    $delete = 0;

    # Check input parameters to ensure opotions correctly selected
        
    GetOptions (
        'Case'              => \$case   ,
        'Status=s'          => \$status ,
    );
    
    # Check that the parameters are correct

    # Check that the Download Type is correct

    if ( not defined( $case ) ) {
        print "Error: Invalid or missing target case value\n";
        print_help();
        exit;
    }

    unless ( $case =~ m/Upper|Lower/i ) {
        print "Error: Invalid or missing target case value\n";
        print_help();
        exit;
    }

    if ( not defined( status ) ) {
        print "Error: Invalid or missing status selection value\n";
        print_help();
        exit;
    }

    unless ( $status =~ m/All|Pending|Current|Sold|Unsold|Clone|Relisted|Closed/i ) {
        print "Error: Invalid or missing status selection value\n";
        print_help();
        exit;
    }

    # Initialise Auctionitis and connect to the DataBase

    $tm = Auctionitis->new();
    
    $tm->initialise( Product => "Auctionitis" );
    $tm->DBconnect( "Auctionitis" );                # Connect to the Auctionitis database

}


sub print_help {

    print <<HELP

 Usage: UpdateTitles --Case <Value> --Status <Status Value>

 Case:      Case to convert Auction Title to
            UPPER    - Delete Sold Auctions Only
            LOWER    - Delete Unsold Auctions Only

 Status:    Status of auctions to be Converted. One of:
            ALL      - All Auctions will be processed
            CLONE    - Only CLONE Auctions will be processed
            CLOSED   - Only CLOSED Auctions will be processed
            CURRENT  - Only CURRENT Auctions will be processed
            PENDING  - Only PENDING Auctions will be processed
            RELISTED - Only RELISTED Auctions will be processed
            SOLD     - Only SOLD Auctions will be processed
            UNSOLD   - Only UNSOLD Auctions will be processed

 Example 1: UpdateTitles --Selection UPPER --Status PENDING

            Convert All PENDING Auction Titles to Upper Case


 Example 2: UpdateTitles --Selection LOWER --Status ALL

            Convert All Auction Titles to Lower Case
HELP
}




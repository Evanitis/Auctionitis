#!perl -w

use strict;
use Auctionitis;
use Getopt::Long;
use Date::Calc qw ( Delta_Days );

    my ( $delete, $selection, $daystokeep, $tm, $dd_today, $mm_today, $yy_today );


#---------------------------------------------------------------------------------------------
# --- Mainline ---
#---------------------------------------------------------------------------------------------

Initialise();

# Process Sold auctions if Sold or All specified

if ( ( uc( $selection ) eq "SOLD" ) 
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
        'Delete'            => \$delete     ,
        'Selection=s'       => \$selection  ,
        'Days=i'            => \$daystokeep ,
    );
    
    # Check that the Download Type is correct

    if ( not defined( $selection ) ) {
        print "Error: Invalid or Missing Selection value\n";
        print_help();
        exit;
    }

    unless ( $selection =~ m/Sold|Unsold|All/i ) {
        print "Error: Invalid or Missing Selection value\n";
        print_help();
        exit;
    }

    if ( not defined( $daystokeep ) ) {
        print "Error: Number of days to keep must be specified\n";
        print_help();
        exit;
    }

    # Print a message if the delete option is not specified advising the the auctions are a list only

    unless ( $delete ) {
        print "Auctions will not be deleted\n";
        print "Selected auction displayed for informational purposes only\n";
        print "Specify --Delete to auctions\n\n";
        sleep 3;
    }

    # Initialise Auctionitis and connect to Trade Me

    $tm = Auctionitis->new();
    
    $tm->initialise( Product => "Auctionitis" );
    $tm->DBconnect( "Auctionitis" );                # Connect to the Auctionitis database
    $tm->{ Debug } = 0;
    $tm->login();

    # Set the "today" values for the date calculations

    # Set the day value

    $dd_today = ( localtime )[3];

    # Set the month value
    
    $mm_today = ( ( localtime )[4] + 1 );

    # Set the century/year value

    $yy_today = ( ( localtime )[5] + 1900 );
}

sub Auction_Age_In_Days {

    # Caculate the difference between two dates passed in dd-mm-yyy format (e.g. Aug-21-2008)
    # Normally the start date will be passed in first

    my $enddate = shift;

    my ( $yy, $mm, $dd );

    $enddate =~ m/(.+?)(-)(.+?)(-)(.*)/; 

    $dd = $1;

    if      ( $3 eq 'Jan' ) { $mm =  1; }
    elsif   ( $3 eq 'Feb' ) { $mm =  2; }
    elsif   ( $3 eq 'Mar' ) { $mm =  3; }
    elsif   ( $3 eq 'Apr' ) { $mm =  4; }
    elsif   ( $3 eq 'May' ) { $mm =  5; }
    elsif   ( $3 eq 'Jun' ) { $mm =  6; }
    elsif   ( $3 eq 'Jul' ) { $mm =  7; }
    elsif   ( $3 eq 'Aug' ) { $mm =  8; }
    elsif   ( $3 eq 'Sep' ) { $mm =  9; }
    elsif   ( $3 eq 'Oct' ) { $mm = 10; }
    elsif   ( $3 eq 'Nov' ) { $mm = 11; }
    elsif   ( $3 eq 'Dec' ) { $mm = 12; }

    $yy = $5;

    my @begin = ( $yy, $mm, $dd );
    my @end = ( $yy_today, $mm_today, $dd_today );

    my $age    = Delta_Days( @begin, @end );

    return $age;
}

sub print_help {

    print <<HELP

 Usage: DeleteTMAuctions --Selection <Value> --Days <Days to keep> --Delete

 Selection: SOLD   - Delete Sold Auctions Only
            UNSOLD - Delete Unsold Auctions Only
            ALL    - Delete Unsold and Sold Auctions

 Days:      Number representing how many days auctions to retain

 Delete:    Delete the auctions; without this flag the command
            will just list the auctions that will be deleted if the 
            --Delete flas is specified

 Example 1: DeleteTMAuctions --Selection UNSOLD --Days 10

            List UNSOLD auctions older then 10 days

 Example 2: DeleteTMAuctions --Selection ALL --Days 7 --Delete

            Delete ALL aucions older then 7 days
HELP
}


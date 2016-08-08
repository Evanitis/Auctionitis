#!perl -w
#---------------------------------------------------------------------------------------------
# Auctionitis simple feedback tool
#
# Copyright 2004, Evan Harris.  All rights reserved.
# See user documentation at the end of this file.  Search for =head
#---------------------------------------------------------------------------------------------

use strict;
use Auctionitis;

# global/common variables

my ( $tm, @feedback, $choice, $auctions );

###############################################################################
#                            M A I N L I N E                                  #
###############################################################################

    load_feedback_array();

    $tm = Auctionitis->new();
    $tm->initialise( Product => "Auctionitis" );
    $tm->login();

    $auctions = $tm->get_completed_auction_feedback_list();

    foreach my $auction ( @$auctions ) {

        # get a random feedback quote from the feedback array

        $choice = int( rand($#feedback));

        print " Auction:".$auction->{ AuctionRef   }."\n";
        print "SaleType:".$auction->{ SaleType     }."\n";
        print "Buyer ID:".$auction->{ BuyerID      }."\n";
        print "Feedback:".$feedback[ $choice ]."\n";

        $tm->put_feedback(
            AuctionRef  => $auction->{ AuctionRef   } ,
            SaleType    => $auction->{ SaleType     } ,
            BuyerID     => $auction->{ BuyerID      } ,
            Feedback    => $feedback[ $choice ]       ,
        );
    }

# Success.

print "Done\n";
exit(1);

###############################################################################
#                            S U B R O U T I N E S                            #
###############################################################################

#==============================================================================
# Routine to load and populate the feedback response array
#==============================================================================

sub load_feedback_array {

    # read the feedback response file into the feedback response array.. one line to one element

    my    $fbackfile = "FeedbackResponseFile.txt";
    open  (FBACK, "< $fbackfile") or die "Cannot open $fbackfile: $!";

    while ( <FBACK> ) { push ( @feedback, $_ ); }
    close $fbackfile;

}


###############################################################################
#                          E N D   O F   S O U R C E                          #
###############################################################################


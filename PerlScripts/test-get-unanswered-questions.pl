#!perl -w
#--------------------------------------------------------------------
# gettmdata.pl retrieve data from trademe for analysis and automation
# to run the script: perl.exe c:\evan\trademe\gettmdata.pl 
#
# Other program notes:
#--------------------------------------------------------------------

use strict;
use Auctionitis;
use HTML::TokeParser;

my $tm = Auctionitis->new();
$tm->initialise( Product => "Auctionitis" );    # Initialise the product
$tm->DBconnect( "TestAuctionitis" );            # Connect to the test database

my $uq;

$tm->login(
    TradeMeID   => 'Auctionitis'                ,
    UserID      => 'evan@auctionitis.co.nz'     ,
    Password    => 'runestaff'                  ,
);

$uq = $tm->get_current_auctions( Filter => 'questions' );

print scalar( @$uq )." Auctions with Unanswered Questions\n";
print "-----------------------------------------\n";

foreach my $a ( @$uq) {

    print "Key for auction ".$a->{ AuctionRef }." is ".$tm->get_auction_key( $a->{ AuctionRef } )."\n";
    
    my $r = $tm->get_auction_record( $tm->get_auction_key( $a->{ AuctionRef } ) );

    print 'Getting Question data for Auction: '.$a->{ AuctionRef }." [ ".$r->{ AuctionKey }." ] Product Code ".$r->{ ProductCode }."\n";

    my $auctiontext = $tm->get_auction_content( AuctionRef => $a->{ AuctionRef } );

    # If auction text is defined (we gpt the data) extract the question data from the auction page

    if ( defined( $auctiontext ) ) {

        my $s = new HTML::TokeParser(\$auctiontext);

        my $state = 'I';

        while ( my $p = $s->get_token() ) {

            # Set state for subsequent processing based on class in opening DIV tag

            if ( $p->[0] eq 'S' and $p->[1] eq 'div' ) {

                if ( uc( $p->[2]{ class } ) eq 'QUESTION' ) {
                    $state = 'Q';                               # Question Block
                }

                elsif ( uc( $p->[2]{ class } ) eq 'ANSWER' ) {
                    $state = 'A';                               # Answer Block
                }

                elsif ( uc( $p->[2]{ class } ) eq 'COMMENT' ) {
                    $state = 'C';                               # Comment Block
                }
                else {
                    $state = 'I';                               # Other - ignore
                }
            }

            # When we hit some text check the mode to determine the type

            if ( $p->[0] eq 'S' and $p->[1] eq 'img' and uc( $p->[2]{ alt } ) eq 'QUESTION: ' and $state eq 'Q' ) {
                print "The question was:\n".$s->get_trimmed_text()."\n";
            }

            if ( $p->[0] eq 'S' and $p->[1] eq 'a' and $state eq 'Q' ) {
                if ( ( $p->[2]{ href } ) =~ m/member/i ) {
                    $p->[2]{ href } =~ m/(member=)(\d+)/;
                    print "Asked by Member ID: ".$2;
                }
            }

            if ( $p->[0] eq 'S' and $p->[1] eq 'b' and $state eq 'Q' ) {
                print " - ".$s->get_trimmed_text()."\n";
                $state = 'I';
            }

            if ( $p->[0] eq 'S' and $p->[1] eq 'a' and $state eq 'A' ) {
                if ( ( $p->[2]{ id } ) =~ m/AnswerThisLink/i ) {
                    $p->[2]{ href } =~ m/(qid=)(\d+)/;
                    print "Question not answered yet - ID is:".$2."\n";
                    $state = 'I';
                }
            }

            if ( $p->[0] eq 'S' and $p->[1] eq 'img' and uc( $p->[2]{ alt } ) eq 'ANSWER: ' and $state eq 'A' ) {
                print "The Answer was:\n".$s->get_trimmed_text()."\n";
                $state = 'I';
            }

            if ( $p->[0] eq 'T' and $state eq 'C' ) {
                if ( $p->[1] =~ m/Seller Comment/i ) {
                    print "The Comment was:\n".$s->get_trimmed_text()."\n";
                    $state = 'I';
                }
            }
        }
    }
    else {
        print "Error Retrieving Auction Data\n";
        print $tm->{ ErrorStatus }."\n";
        print $tm->{ ErrorMessage }."\n";
    }
}

# Success.

print "Done\n";
exit(0);

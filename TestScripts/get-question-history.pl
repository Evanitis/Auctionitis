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

###############################################################################
#                         V A R I A B L E S                                   #
###############################################################################

my ( $server, $dbname, $username, $password );
my ( $tm, $ua, $url, $req, $response, $content, $msg );
my ( $DSN, $masterdb, $reportdb, $dbh, $sth, $SQLStmt, $auctions);

# SQL statements

my $SQL_get_account_list;               # Get list of accounts to process
my $SQL_write_event_log;                # Write to the Event Log
my $SQL_exists_sales_extract_record;    # Check whether Sales Extract record exists
my $SQL_get_sales_extract_by_key;       # Get Sales Extract Record by Primary Key
my $SQL_get_sales_extract_by_ref;       # Get Sales Extract Record by Reference Val
my $SQL_add_sales_extract_record;       # Add new Sales Extract record
my $SQL_update_sales_extract_record;    # Update Sales Extract Record
my $SQL_get_auction_product_code;       # Get Auction Product Code by Reference Val
my $SQL_clear_extract_action;           # Clear the Extract_Action column

###############################################################################
#                            M A I N L I N E                                  #
###############################################################################

Initialise();
Mainline();

exit(0);

###############################################################################
#                            S U B R O U T I N E S                            #
###############################################################################

sub Mainline {

    $tm->login(
        TradeMeID   => 'ToyPlanet'                  ,
        UserID      => 'trademe1@toyplanet.co.nz'   ,
        Password    => 'hfd67wqe'                   ,
    );
    
    foreach my $a ( @$auctions ) {
    
        print 'Getting Question data for Auction: '.$a->{ Auction_Ref }." Product Code ".$a->{ Product_Code }."\n";

        # Initialize the current question id to 0

        my $questionkey = 0;

        # Get the auction text from Trade Me

        my $auctiontext = $tm->get_auction_content( AuctionRef => $a->{ Auction_Ref } );
    
        # If auction text is defined (we gpt the data) extract the question data from the auction page
    
        if ( defined( $auctiontext ) ) {
    
            my $s = new HTML::TokeParser(\$auctiontext);
    
            my $state = 'I';
            my $q_id = '';
            my $q_text = '';
            my $a_text = '';
            my $asked_by = '';
            my $asked_by_id = '';

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

                # extract the Question Text

                if ( $p->[0] eq 'S' and $p->[1] eq 'img' and uc( $p->[2]{ alt } ) eq 'QUESTION: ' and $state eq 'Q' ) {
                    $q_text = $s->get_trimmed_text();
                }

                # Extract the member ID

                if ( $p->[0] eq 'S' and $p->[1] eq 'a' and $state eq 'Q' ) {
                    if ( ( $p->[2]{ href } ) =~ m/member/i ) {
                        $p->[2]{ href } =~ m/(member=)(\d+)/;
                        $asked_by_id = $2;
                    }
                }

                # Extract the member name

                if ( $p->[0] eq 'S' and $p->[1] eq 'b' and $state eq 'Q' ) {
                    $asked_by = $s->get_trimmed_text();

                    # Create the question record

                    $questionkey = $tm->add_question_record(
                        AuctionSite         => 'TRADEME'            ,
                        AuctionRef          => $a->{ Auction_Ref }  ,
                        ProductCode         => $a->{ Product_Code } ,
                        Question_Reference  => '0'                  ,
                        Question_Text       => $q_text              ,
                        Answer_Text         => ''                   ,
                        Answered            => 0                    ,
                        Asked_By_Member     => $asked_by            ,
                        Asked_By_Member_ID  => $asked_by_id         ,
                    );

                    print "Added Question Key ".$questionkey."\n";

                    $state = 'I';
                }

                if ( $p->[0] eq 'S' and $p->[1] eq 'a' and $state eq 'A' ) {
                    if ( ( $p->[2]{ id } ) =~ m/AnswerThisLink/i ) {
                        $p->[2]{ href } =~ m/(qid=)(\d+)/;
                        $q_id = $2;

                        # Update the question record

                        $tm->update_question_record(
                            QuestionID          => $questionkey     ,
                            Question_Reference  => $q_id            ,
                        );

                        $questionkey = 0;

                        $state = 'I';
                    }
                }
    
                if ( $p->[0] eq 'S' and $p->[1] eq 'img' and uc( $p->[2]{ alt } ) eq 'ANSWER: ' and $state eq 'A' ) {

                    $a_text = $s->get_trimmed_text();

                    # Update the question record

                    $tm->update_question_record(
                        QuestionID          => $questionkey     ,
                        Answer_Text         => $a_text          ,
                        Answered            => 1                ,
                    );

                    $questionkey = 0;

                    $state = 'I';
                }
    
                if ( $p->[0] eq 'T' and $state eq 'C' ) {
                    if ( $p->[1] =~ m/Seller Comment/i ) {
                        $q_text = 'Seller Comment';
                        $a_text = $s->get_trimmed_text();

                        # Create the question record

                        $tm->add_question_record(
                            AuctionSite         => 'TRADEME'            ,
                            AuctionRef          => $a->{ Auction_Ref }  ,
                            ProductCode         => $a->{ Product_Code } ,
                            Question_Reference  => '0'                  ,
                            Question_Text       => $q_text              ,
                            Answer_Text         => $a_text              ,
                            Anwered             => '1'                  ,
                            Asked_By_Member     => ''                   ,
                            Asked_By_Member_ID  => ''                   ,
                        );

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
}

###############################################################################
#                            S U B R O U T I N E S                            #
###############################################################################

sub Initialise {

    # Setup the Auctionitis Object

    $tm = Auctionitis->new();
    $tm->initialise(Product => "Auctionitis");      # Initialise the product
    $tm->DBconnect();            # Connect to the test database

    # Set up auction history database connections

    $server    = "DEVBOX\\DEVSQL";
    $dbname    = "ToyPlanet";
    $username  = "TManalytics";
    $password  = "banana";

    $DSN          = "driver={SQL Server};Server=$server;Database=$dbname;uid=$username;pwd=$password;";
    $masterdb     = DBI->connect("dbi:ODBC:$DSN", $username, $password );

    $masterdb->{ LongReadLen } = 65555;            # cater for retrieval of memo fields

    my $SQL = $masterdb->prepare( qq { 
        SELECT  Auction_Ref          , 
                Product_Code          
        FROM    AuctionHistory
        WHERE   Questions > 0
    } );

    $SQL->execute;
    $auctions = $SQL->fetchall_arrayref( {} );
    $SQL->finish();

}

# Success.

print "Done\n";
exit(0);

use strict;
use Auctionitis;
use LWP::UserAgent;
use HTTP::Request;
use HTTP::Response;
use HTTP::Cookies;
use DBI;

###############################################################################
#                         V A R I A B L E S                                   #
###############################################################################

# HTTP request processing variables

my ($tm, $ua, $url, $req, $response, $content, $urlvar, $initial);

# SQL statements

my $SQL_get_auction_list;               # Get list of auctions to process

# category totals variables

my( $dbh, $sth, $inputdata );
my ($h, $ua, $url, $req, $response, $content);

Initialise();
Mainline();

###############################################################################
#                            S U B R O U T I N E S                            #
###############################################################################

sub Initialise {

    # Setup the pseudo-browser

    $ua = LWP::UserAgent->new();
    $ua->agent("Auctionitis/V1.0");
    $ua->cookie_jar(HTTP::Cookies->new(file       => "lwpcookies.txt",
                                       autosave   => 1));

    # Set up the Auctionitis object

    $tm = Auctionitis->new();
    $tm->initialise(Product => "Auctionitis");
    $tm->DBconnect();            # Connect to the database

    # Set up database connection

    $dbh=DBI->connect('dbi:ODBC:Auctionitis') || die "Error opening ToyPlanet database: $DBI::errstr\n";

    $dbh->{ LongReadLen } = 65555;            # cater for retrieval of memo fields

    # Select auctions to update from sales extract table
    # Image URL: http://www.toyplanet.co.nz/image.php?type=product_detail&image_file=images/products/lego/8632.jpg

    $SQL_get_auction_list = $dbh->prepare( qq { 
        SELECT  AuctionKey, 
                UserDefined01 
        FROM    Auctions
    } );

    $SQL_get_auction_list->execute;

    $inputdata = $SQL_get_auction_list->fetchall_arrayref( {} );
}

sub Mainline {

    my $tgtdir = "c:\\Evan\\Auctionitis103\\images\\";
    my $image = "zillion.ico";

    $url = "http://www.zillion.co.nz/favicon.ico";

    $response  = $ua->get( $url, ":content_file"=> $tgtdir."\\".$image );
    print "HTTP Response code for file request: ".$response->status_line."\n";

    my $image = "TandE.ico";

    $url = "http://www.te.co.nz/favicon.ico";

    $response  = $ua->get( $url, ":content_file"=> $tgtdir."\\".$image );
    print "HTTP Response code for file request: ".$response->status_line."\n";

    my $image = "Webuy.ico";

    $url = "http://www.webuy.co.nz/favicon.ico";

    $response  = $ua->get( $url, ":content_file"=> $tgtdir."\\".$image );
    print "HTTP Response code for file request: ".$response->status_line."\n";


}


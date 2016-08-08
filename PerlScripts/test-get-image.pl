use strict;
use LWP::Simple;
use LWP::UserAgent;
use URI::URL;
use URI::Escape;
use HTTP::Request;
use HTTP::Response;
use HTTP::Headers;
use HTTP::Response;
use HTTP::Cookies;
use HTTP::Request::Common qw(POST);
use HTML::TokeParser;

# class variables

my ($h, $ua, $url, $req, $response, $content);

my $userid   = "tracey\@irobot.co.nz";
my $password = "wicked99";

my $auctionref = shift;

# Set up the user agent pseudo-browser

$ua = LWP::UserAgent->new();
$ua->agent("Auctionitis/V1.0");
push @{$ua->requests_redirectable}, 'POST';  # Added 29/04/05
$ua->cookie_jar(HTTP::Cookies->new(file       => "lwpcookies.txt",
                                   autosave   => 1));

$url = "http://www.trademe.co.nz/Members/Login.aspx";

$req = POST $url, 
                  [url            =>  '/DEFAULT.ASP?'   ,
#                  test_auto      =>  ''                ,
                   email          =>  $userid           ,
                   password       =>  $password         ,
                   login_attempts =>  0                 ,
                   submitted      =>  'Y'               ];

$content = $ua->request($req)->as_string; # posts the data to the remote site i.e. logs in

$url="http://images.trademe.co.nz/photoserver/49/25922249_full.jpg";        # 21/05.2006

eval { system("mkdir C:\\evan\\auctionitis103\\ImportedPics" ); };

print "$@\n";

$ua->get( $url, ":content_file"=> "C:\\evan\\auctionitis103\\ImportedPics\\TMpicdata3.jpg" );

# $req        = HTTP::Request->new(GET => $url);
# $response   = $ua->request($req);


# open my $f1, ">  C:\\evan\\auctionitis103\\TMpicdata.jpg";
# binmode $f1;
# print $f1 $response->content();                                   #read whole file
# close $f1;                                                          # ignore retval


# print $content;

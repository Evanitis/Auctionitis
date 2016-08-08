#!perl -w

use strict;
use Auctionitis;

my $auctionref = shift;

unless ( $auctionref ) { print "You must supply an Aucion Reference to be activated\n"; exit; }

my $tm = Auctionitis->new();
$tm->initialise( Product => "Auctionitis" );  # Initialise the product

# Set the properties required to log in to Sella

$tm->{ SellaPassword    } = 'jaymz94';
$tm->{ SellaEmail       } = 'traceymackenzie@irobot.co.nz';

$tm->connect_to_sella();

if ( not defined $tm->{ SellaSessionID } ) {
    print "No session ID defined....\n";
}
else {
    print "Sella Session ID: ".$tm->{ SellaSessionID }."\n";
}

my $data = $tm->sella_get_listing_state( AuctionRef => $auctionref );

print "Data: ".$data."\n";

foreach my $key ( sort keys %$data ) {
    my $spacer = " " x ( 25-length( $key ) ) ;
    print $key.": ".$spacer.$data->{ $key }."\n";
}

$data->{ CloseDate } = $tm->format_sella_close_date(
    CloseDate   =>  $data->{ date_closed } ,
    Format      =>  'DATE'                  ,
);
$data->{ CloseTime } = $tm->format_sella_close_date(
    CloseDate   =>  $data->{ date_closed } ,
    Format      =>  'TIME'                  ,
);

print "\nData: ".$data."\n";

foreach my $key ( sort keys %$data ) {
    my $spacer = " " x ( 25-length( $key ) ) ;
    print $key.": ".$spacer.$data->{ $key }."\n";
}

exit(0);                                       

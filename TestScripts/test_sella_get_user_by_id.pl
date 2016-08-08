#!perl -w

use strict;
use Auctionitis;

my $cat = shift;

my $tm = Auctionitis->new();
$tm->initialise( Product => "Auctionitis" );  # Initialise the product

# Set the properties required to log in to Sella

$tm->{ SellaPassword    } = 'jaymz94';
$tm->{ SellaEmail       } = 'traceymackenzie@irobot.co.nz';

$tm->connect_to_sella();

# my $data = $tm->sella_get_user_id_properties( UserID => $tm->{ SellaSessionID } );

my $data = $tm->sella_get_user_id_properties();

if ( not defined ( $data ) ) {

    print "NO User data returned - check the log for details\n";
    exit(1);
}

print $data."\n";

foreach my $key ( sort keys %$data ) {
    my $spacer = " " x ( 25-length( $key ) ) ;
    print $key.": ".$spacer.$data->{ $key }."\n";
}

exit(0);                                       

#!perl -w
#--------------------------------------------------------------------
use Auctionitis;

my $tm = Auctionitis->new();
$tm->initialise( Product => 'Auctionitis' );

foreach my $property ( sort keys %$tm ) {
    my $spacer = " " x ( 40-length( $property ) ) ;
    print $property.":".$spacer.$tm->{ $property }."\n";
}



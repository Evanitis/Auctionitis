#!perl -w
#--------------------------------------------------------------------
# gettmdata.pl retrieve data from trademe for analysis and automation
# to run the script: perl.exe c:\evan\trademe\gettmdata.pl 
#
# Other program notes:
#--------------------------------------------------------------------

use strict;
use Auctionitis;

my $auction = shift;
my $status  = shift;

my $tm = Auctionitis->new();

$tm->initialise(Product => "Auctionitis");  # Initialise the product

$tm->DBconnect();           # Connect to the database

$tm->login();

my %auction = $tm->import_auction_details($auction, $status);

print "Auction: $auction\n";
print "Status : $status\n";
print "User ID: $tm->{UserID}\n";
print "Title  : $auction{Title}\n";
$auction{IsNew}             ?   (print "Is New : $auction{IsNew}             \n") : (print "Is New : \*N\n" );
$auction{Category}          ?   (print "Cat    : $auction{Category}          \n") : (print "Cat    : \*N\n" );
$auction{MovieConfirmation} ?   (print "Confirm: $auction{MovieConfirmation} \n") : (print "Confirm: \*N\n" );
$auction{MovieRating}       ?   (print "Rating : $auction{MovieRating}       \n") : (print "Rating : \*N\n" );
$auction{AttributeName}     ?   (print "A Name : $auction{AttributeName}     \n") : (print "A Name : \*N\n" );
$auction{AttributeValue}    ?   (print "A Value: $auction{AttributeValue}    \n") : (print "A Value: \*N\n" );
print "Closed : $auction{ClosedAuction}     \n";
$auction{AutoExtend}        ?   (print "A-Extnd: $auction{AutoExtend}        \n") : (print "A-Extnd: \*N\n" );
$auction{BuyNowPrice}       ?   (print "Buy now: $auction{BuyNowPrice}       \n") : (print "Buy now: \*N\n" );
$auction{StartPrice}        ?   (print "Start  : $auction{StartPrice}        \n") : (print "Start  : \*N\n" );
$auction{ReservePrice}      ?   (print "Reserve: $auction{ReservePrice}      \n") : (print "Reserve: \*N\n" );
$auction{Cash}              ?   (print "Cash   : $auction{Cash}              \n") : (print "Cash   : \*N\n" );
$auction{Cheque}            ?   (print "Cheque : $auction{Cheque}            \n") : (print "Cheque : \*N\n" );
$auction{BankDeposit}       ?   (print "BankDep: $auction{BankDeposit}       \n") : (print "BankDep: \*N\n" );
$auction{PaymentInfo}       ?   (print "P Info : $auction{PaymentInfo}       \n") : (print "P Info : \*N\n" );
print "Free NZ: $auction{FreeShippingNZ}    \n";
$auction{ShippingInfo}      ?   (print "S Info : $auction{ShippingInfo}      \n") : (print "S Info : \*N\n" );
print "Safe Tr: $auction{SafeTrader}        \n";
$auction{DurationHours}     ?   (print "Length : $auction{DurationHours}     \n") : (print "Length : \*N\n" );


# $auction{Description}       ?   (print "Desc   : \n$auction{Description}     \n") : (print "Desc   : \*N\n" );

print "Import auction summary debug summary\n";
print "---------------------------------------------------------------------------\n";

foreach my $property (sort keys %auction ) {
    if ( $property ne "Description" )   {
        my $spacer = " " x ( 20-length( $property ) );
        print $spacer.$property.": ".$auction{ $property }."\n";
    }
}


print "Error Status: $tm->{ErrorStatus}\n";


# Success.

print "Done\n";
exit(0);

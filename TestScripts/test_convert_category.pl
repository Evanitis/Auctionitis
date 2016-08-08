use Auctionitis;
use Win32::OLE;

my $localservicedate = shift;
my @auctions;

$tm = Auctionitis->new();
$tm->initialise(Product => "Auctionitis");  # Initialise the product
$tm->DBconnect();                           # Connect to the default database


# Print Service URL

print "Root Service URL: ".$tm->{ ServiceURL }."\n";

# Get Service dates

my $servicedates            = $tm->get_service_dates($localservicedate);

foreach my $record (@$servicedates) {
    
    print "Service URL: ".$record->{ ServiceURL }." Service Date: ".$record->{ ServiceDate }."\n";

}

# Process Service updates

foreach my $record (@$servicedates) {

    my $mapdata                 = $tm->get_remapping_data( $record->{ ServiceURL } );

    foreach my $update (@$mapdata) {

        print "Mapping Data: ".$update->{ Description }." Old: ".$update->{ OldCategory }." New: ".$update->{ NewCategory }."\n"
        
    }
}

# Get ReadMe

my $FH;
my $readmefile = $tm->{ DataDirectory }."\\readme.txt";
my $readmedata = $tm->get_category_readme();

print $readmedata;

unlink $readmefile;

open($FH, "> $readmefile");

print $FH $readmedata;

print "Done\n";

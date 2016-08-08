
use Auctionitis;
use strict;

my $tm = Auctionitis->new();

$tm->initialise(Product => "Auctionitis");
$tm->DBconnect();

my $XMLFile = "C:\\program Files\\Auctionitis\\Output\\evan.xml";

my $properties = $tm->get_xml_properties( Filename => $XMLFile );

print "Properties ref $properties\n";

while((my $key, my $val) = each(%$properties)) {
    print "XML Property: ".$key." Value: ".$val."\n";
}



use Auctionitis;

my $tm = Auctionitis->new();

$tm->initialise(Product => "Auctionitis");

my $picdata = $tm->list_xml_picturenames( Filename => "C:\\Program Files\\Auctionitis\\Output\\Evan.xml");

my $piclist = $picdata->{ Data  };
my $count   = $picdata->{ Count };

print "There are $count pictures\n\n";

while((my $pic, my $val) = each(%$piclist)) {

    print "Name: $pic\n";

}
#!perl -w

use Auctionitis;

my $tm = Auctionitis->new();

$tm->initialise( Product => "Auctionitis" );  # Initialise the product

$tm->connect_to_sella();

my $data = $tm->sella_api_definitions();

print $data."\n\n";

my $rectot = 0;

while ( $data =~ m/(<id>)(.+?)(<\/id><parent_id>)(.+?)(<\/parent_id><name>)(.+?)(<\/name>)/g ) {
    print "Category: ".$2." Parent: ".$4." Text: ".$6."\n";
    $rectot++;
}

print "Total records retrieved: ".$rectot."\n";

# Success.

print "Done\n";
exit(0);

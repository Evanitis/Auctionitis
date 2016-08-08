use XML::Parser;

my $xmlfile = "C:\\Program Files\\Auctionitis\\Output\\Evan.xml";

my $parser = XML::Parser->new( ErrorContext => 2 );

eval { $parser->parsefile( $xmlfile ); };

if ( $@ ) {

    $@ =~ s/at \/.*?$//s;       # remove module line number
    print "\nERROR in ".$xmlfile.":\n$@\n";

} else {

    print $xmlfile." is well-formed\n";
}
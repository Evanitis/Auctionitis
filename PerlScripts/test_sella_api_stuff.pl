#!perl -w
#--------------------------------------------------------------------
# gettmdata.pl retrieve data from trademe for analysis and automation
# to run the script: perl.exe c:\evan\trademe\gettmdata.pl 
#
# Other program notes:
#--------------------------------------------------------------------

use strict;
use Auctionitis;

my $tm = Auctionitis->new();
$tm->initialise(Product => "Auctionitis");  # Initialise the product
$tm->DBconnect();                          # Connect to the database


my $scrap1 = "A Sentence";
my $scrap2 = "A sentence & morestuff";
my $scrap3 = "A simple <TAG> tag with a question ?";

print "Test function set_sella_api_parm\n";

my $result = $tm->set_sella_api_parm( "TAG", $scrap1 );

print " Before: ".$scrap1."\n";
print "Beafter: ".$result."\n";

$result = $tm->set_sella_api_parm( "TAG", $scrap2 );

print " Before: ".$scrap2."\n";
print "Beafter: ".$result."\n";

$result = $tm->set_sella_api_parm( "TAG", $scrap3 );

print " Before: ".$scrap3."\n";
print "Beafter: ".$result."\n";

print "Test function set_sella_api_elem\n";

my $result = $tm->set_sella_api_elem( "TAG", $scrap1 );

print " Before: ".$scrap1."\n";
print "Beafter: ".$result."\n";

$result = $tm->set_sella_api_elem( "TAG", $scrap2 );

print " Before: ".$scrap2."\n";
print "Beafter: ".$result."\n";

$result = $tm->set_sella_api_elem( "TAG", $scrap3 );

print " Before: ".$scrap3."\n";
print "Beafter: ".$result."\n";

print "Test function set_XML_elem_value\n";

my $result = $tm->set_XML_elem_value( "TAG", $scrap1 );

print " Before: ".$scrap1."\n";
print "Beafter: ".$result."\n";

$result = $tm->set_XML_elem_value( "TAG", $scrap2 );

print " Before: ".$scrap2."\n";
print "Beafter: ".$result."\n";

$result = $tm->set_XML_elem_value( "TAG", $scrap3 );

print " Before: ".$scrap3."\n";
print "Beafter: ".$result."\n";


# Success.

print "Done\n";
exit(0);

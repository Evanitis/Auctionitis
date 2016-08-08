#!perl -w
#--------------------------------------------------------------------
# GetDBProperty.pl
#
# Usage GetDBProperty "<PropertyName>" 
#
# Compiled to .exe file
# Perlapp --force --GUI --exe SetDBProperty SetDBProperty.pl
#--------------------------------------------------------------------

use strict;
use Auctionitis;

my $tm;

my $pn = shift;

$tm = Auctionitis->new();
$tm->initialise( Product => "Auctionitis" );  # Initialise the product
$tm->DBconnect(); 

my $val = $tm->get_DB_property(
    Property_Name       => $pn,
    Property_Default    => "Not Found",
);


# Success.

print "Property $pn: $val\n";
exit(0);

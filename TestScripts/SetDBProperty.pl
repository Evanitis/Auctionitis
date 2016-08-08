#!perl -w
#--------------------------------------------------------------------
# SetDBProperty.pl
#
# Usage SetDBProperty "<PropertyName>" "<Property Value>"
#
# Compiled to .exe file
# Perlapp --force --GUI --exe SetDBProperty SetDBProperty.pl
#--------------------------------------------------------------------

use strict;
use Auctionitis;

my $tm;

my $pn = shift;
my $pv = shift;


$tm = Auctionitis->new();
$tm->initialise( Product => "Auctionitis" );  # Initialise the product
$tm->DBconnect(); 

$tm->set_DB_property(
    Property_Name       => $pn,
    Property_Value      => $pv,
);


# Success.

print "Done\n";
exit(0);

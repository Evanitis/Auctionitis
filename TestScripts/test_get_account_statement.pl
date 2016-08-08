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
$tm->initialise( Product => "Auctionitis" );  # Initialise the product

$tm->login();

my $statement = $tm->get_account_statement();

foreach my $i ( @$statement ) {

    # print "Date: ".$i->{ Item_Date }." Time: ".$i->{ Item_Time }." Amount: ".$i->{ Item_Amount }." Ref: ".$i->{ Reference }." Text: ".$i->{ Item_Description }."\n";
    print "Date: ".$i->{ Account_Date }." Amount: ".$i->{ Item_Amount }." Ref: ".$i->{ Reference }." Text: ".$i->{ Item_Description }."\n";

}


# Success.

print "Done\n";
exit(0);

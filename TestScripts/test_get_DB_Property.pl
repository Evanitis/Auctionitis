#!perl -w
#--------------------------------------------------------------------

use strict;
use Auctionitis;
use Win32::TieRegistry;

my $tm;
my $pound= $Registry->Delimiter("/");

$tm = Auctionitis->new();
$tm->initialise(Product => "Auctionitis");  # Initialise the product
$tm->DBconnect(); 
$tm->login(); 

my $pv = $tm->get_DB_property(
    Property_Name       => "Evan"       ,
    Property_Default    => "Anonymous"  ,
);

print "Returned Property Value is: ".$pv."\n";

$tm->set_DB_property(
    Property_Name       => "Evan"       ,
    Property_Value      => "Wiggins"  ,
);

$pv = $tm->get_DB_property(
    Property_Name       => "Evan"       ,
    Property_Default    => "Anonymous"  ,
);

print "Returned Property Value is: ".$pv."\n";
print "Error Status: ".$tm->{ErrorStatus}."\n";

my $DBPictotal  = $tm->get_DB_property(Property_Name => "TMPictureCount", Property_Default => 0);

print "Error Status: ".$tm->{ErrorStatus}."\n";

print "Pics: $DBPictotal\n";

$tm->set_DB_property(
    Property_Name       => "TMPictureCount" ,
    Property_Value      => $tm->get_DB_property(Property_Name => "TMPictureCount", Property_Default => 0) + 12,
);

$pv = $tm->get_DB_property(
    Property_Name       => "TMPIctureCount"       ,
    Property_Default    => 9030456  ,
);

my $pc = $tm->get_TM_photo_count();

print "PC: $pc\n";

$tm->set_DB_property(
    Property_Name   =>  "TMPictureCount"                    ,
    Property_Value  =>  $tm->get_TM_photo_count()           ,
);

my $csd = $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Properties/CategoryServiceDate"};

if ( $csd ) {
    print "CSD: $csd\n";
    $tm->set_DB_property(
        Property_Name   =>  "CategoryServiceDate"               ,
        Property_Value  =>  $csd                                ,
    );
}
else {
    print "CSD not found\n";
    $tm->set_DB_property(
        Property_Name   =>  "CategoryServiceDate"               ,
        Property_Value  =>  "01-01-2006"                        ,
    );
}

$csd = delete $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Properties/CategoryServiceDate"};
print "CSD: $csd\n";

# Success.

print "Done\n";
exit(0);

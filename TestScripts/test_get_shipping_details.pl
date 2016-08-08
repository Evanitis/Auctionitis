#!perl -w
#--------------------------------------------------------------------

use strict;
use Auctionitis;

my $tm;

my $key = shift;

$tm = Auctionitis->new();
$tm->initialise(Product => "Auctionitis");  # Initialise the product
$tm->DBconnect(); 


my $dopt = $tm->get_shipping_details( AuctionKey => $key );

foreach my $option (@$dopt) {

    print $option->{ Shipping_Details_Seq }." ".$option->{ Shipping_Details_Cost }." ".$option->{ Shipping_Details_Text }."\n";
}

$dopt->[0] ? ( print $dopt->[0]->{ Shipping_Details_Seq }." ".$dopt->[0]->{ Shipping_Details_Cost }." ".$dopt->[0]->{ Shipping_Details_Text }."\n"  )   :   ()  ,

$dopt->[1] ? ( print $dopt->[1]->{ Shipping_Details_Seq }." ".$dopt->[1]->{ Shipping_Details_Cost }." ".$dopt->[1]->{ Shipping_Details_Text }."\n"  )   :   ()  ,

$dopt->[2] ? ( print $dopt->[2]->{ Shipping_Details_Seq }." ".$dopt->[2]->{ Shipping_Details_Cost }." ".$dopt->[2]->{ Shipping_Details_Text }."\n"  )   :   ()  ,

$dopt->[3] ? ( print $dopt->[3]->{ Shipping_Details_Seq }." ".$dopt->[3]->{ Shipping_Details_Cost }." ".$dopt->[3]->{ Shipping_Details_Text }."\n"  )   :   ()  ,

$dopt->[4] ? ( print $dopt->[4]->{ Shipping_Details_Seq }." ".$dopt->[4]->{ Shipping_Details_Cost }." ".$dopt->[4]->{ Shipping_Details_Text }."\n"  )   :   ()  ,

$dopt->[5] ? ( print $dopt->[5]->{ Shipping_Details_Seq }." ".$dopt->[5]->{ Shipping_Details_Cost }." ".$dopt->[5]->{ Shipping_Details_Text }."\n"  )   :   ()  ,

$dopt->[6] ? ( print $dopt->[6]->{ Shipping_Details_Seq }." ".$dopt->[6]->{ Shipping_Details_Cost }." ".$dopt->[6]->{ Shipping_Details_Text }."\n"  )   :   ()  ,

$dopt->[7] ? ( print $dopt->[7]->{ Shipping_Details_Seq }." ".$dopt->[7]->{ Shipping_Details_Cost }." ".$dopt->[7]->{ Shipping_Details_Text }."\n"  )   :   ()  ,

$dopt->[8] ? ( print $dopt->[8]->{ Shipping_Details_Seq }." ".$dopt->[8]->{ Shipping_Details_Cost }." ".$dopt->[8]->{ Shipping_Details_Text }."\n"  )   :   ()  ,

$dopt->[9] ? ( print $dopt->[9]->{ Shipping_Details_Seq }." ".$dopt->[9]->{ Shipping_Details_Cost }." ".$dopt->[9]->{ Shipping_Details_Text }."\n"  )   :   ()  ,


my $a = $tm->get_auction_record( $key );

print "Title          : ".$a->{ Title           }."\n";
print "Shipping option: ".$a->{ ShippingOption  }."\n";
print "Pickup option  : ".$a->{ PickupOption    }."\n";

print "Error Status   : $tm->{ErrorStatus}\n";
print "Error message  : $tm->{ErrorMessage}\n";
print "Error Details  : $tm->{ErrorDetail}\n";

$a->{ Subtitle }   ?   (  print "Subtitle: ".$a->{ Subtitle }."\n"  )   :   ( print "No subtitle entered\n" );

$a->{ PickupOption    }   ?   (  print "Pickup option selected\n"  )   :   ( print "Pickup option NOT selected\n" );
$a->{ ShippingOption  }   ?   (  print "Pickup option selected\n"  )   :   ( print "Pickup option NOT selected\n" );
!($a->{ PickupOption    })   ?   (  print "Pickup option NOT selected\n"  )   :   ( print "Pickup option selected\n" );
not($a->{ ShippingOption  })   ?   (  print "Pickup option NOT selected\n"  )   :   ( print "Pickup option selected\n" );

# Success.

print "Done\n";
exit(0);

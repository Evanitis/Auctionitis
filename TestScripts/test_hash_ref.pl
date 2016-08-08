
my @ship_options;
my %ship_data;

undef @ship_options;

# 1

$ship_data{ Cost } .= 5.0000;
$ship_data{ Text } .= "Courier Nationwide via Courierpost";

if ( %ship_data ) {
    push( @ship_options, { %ship_data } );
}

delete( $ship_data{ Cost }  );
delete( $ship_data{ Text }  );

# 2

$ship_data{ Cost } .= .0000;    
$ship_data{ Text } .= "Free Courier with Buy Now Only";

if ( %ship_data ) {
    push( @ship_options, { %ship_data } );
}

delete( $ship_data{ Cost }  );
delete( $ship_data{ Text }  );

# 3

$ship_data{ Cost } .= .0000;    
$ship_data{ Text } .= "No additional charge for Rural Delivery";

if ( %ship_data ) {
    push( @ship_options, { %ship_data } );
}

delete( $ship_data{ Cost }  );
delete( $ship_data{ Text }  );

# 4

$ship_data{ Cost } .= .0000;    
$ship_data{ Text } .= "No additional charge for items sent in same parcel";

if ( %ship_data ) {
    push( @ship_options, { %ship_data } );
}

delete( $ship_data{ Cost }  );
delete( $ship_data{ Text }  );

# 5

$ship_data{ Cost } .= 10.0000;
$ship_data{ Text } .= "Shipping to Australia via Airmail";

if ( exists $ship_data{ Cost } ) {
    push( @ship_options, { %ship_data } );
}

delete( $ship_data{ Cost }  );
delete( $ship_data{ Text }  );

#  6

$ship_data{ Cost } .= 2.0000;
$ship_data{ Text } .= "Extra items in same parcel to Australia";

# if ( %ship_data ) {
    push( @ship_options, { %ship_data } );
# }

delete( $ship_data{ Cost }  );
delete( $ship_data{ Text }  );

# 7

$ship_data{ Cost } .= .0000    ;
$ship_data{ Text } .= "We do not ship via NZ Post";

if ( %ship_data ) {
    push( @ship_options, { %ship_data } );
} 

delete( $ship_data{ Cost }  );
delete( $ship_data{ Text }  );

if ( @ship_options ) {

    my $seq = 1;

    print "Adding Shipping Details\n";

    foreach my $option ( @ship_options ) {

        print  "Seq: ".$seq."\tCost: ".$option->{ Cost }."\t Text: ".$option->{ Text }."\n";
        $seq++;
    }
}

print "\n\nClearing and starting again ... \n\n";

undef @ship_options;

# 1

$ship_data{ Cost } .= 5.0000;
$ship_data{ Text } .= "Courier Nationwide via Courierpost";

if ( %ship_data ) {
    push( @ship_options, { %ship_data } );
}

delete( $ship_data{ Cost }  );
delete( $ship_data{ Text }  );

# 2

$ship_data{ Cost } .= .0000;    
$ship_data{ Text } .= "Free Courier with Buy Now Only";

if ( %ship_data ) {
    push( @ship_options, { %ship_data } );
}

delete( $ship_data{ Cost }  );
delete( $ship_data{ Text }  );

# 3

$ship_data{ Cost } .= .0000;    
$ship_data{ Text } .= "No additional charge for Rural Delivery";

if ( %ship_data ) {
    push( @ship_options, { %ship_data } );
}

delete( $ship_data{ Cost }  );
delete( $ship_data{ Text }  );

# 4

$ship_data{ Cost } .= .0000;    
$ship_data{ Text } .= "No additional charge for items sent in same parcel";

if ( %ship_data ) {
    push( @ship_options, { %ship_data } );
}

delete( $ship_data{ Cost }  );
delete( $ship_data{ Text }  );

# 5

$ship_data{ Cost } .= 10.0000;
$ship_data{ Text } .= "Shipping to Australia via Airmail";

if ( exists $ship_data{ Cost } ) {
    push( @ship_options, { %ship_data } );
}

delete( $ship_data{ Cost }  );
delete( $ship_data{ Text }  );

#  6

$ship_data{ Cost } .= 2.0000;
$ship_data{ Text } .= "Extra items in same parcel to Australia";

# if ( %ship_data ) {
    push( @ship_options, { %ship_data } );
# }

delete( $ship_data{ Cost }  );
delete( $ship_data{ Text }  );

# 7

$ship_data{ Cost } .= .0000    ;
$ship_data{ Text } .= "We do not ship via NZ Post";

if ( %ship_data ) {
    push( @ship_options, { %ship_data } );
} 

delete( $ship_data{ Cost }  );
delete( $ship_data{ Text }  );

if ( @ship_options ) {

    my $seq = 1;

    print "Adding Shipping Details\n";

    foreach my $option ( @ship_options ) {

        print  "Seq: ".$seq."\tCost: ".$option->{ Cost }."\t Text: ".$option->{ Text }."\n";
        $seq++;
    }
}

#!/usr/bin/perl
use strict;
# use constant LIB_DIR => '/evan/lib/';
# use lib LIB_DIR;
use Auctionitis::ProductMaintenance;

my $pm = Auctionitis::ProductMaintenance->new();

print "Object class: ".ref( $pm )."\n";
print "Constant: ".Z_REMOVE."\n";

$pm->initialise();

$pm->{ Test_Handler } = \&get_handler_value;

if ( $pm->{ PM_Console } ) {
    $pm->{ Console } = 1;
}

$pm->dump_properties();

print $pm->{ Test_Handler }->(  TestVal => "Hello" )."\n";


sub get_handler_value {

    my $p = { @_ };

    print "Handler got called\n";


    my $value = $p->{ TestVal };

    return $value;
}


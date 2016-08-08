#!/usr/bin/perl
use strict;
# use constant LIB_DIR => '/evan/lib/';
# use lib LIB_DIR;
use Auctionitis::ProductMaintenance;

my $pm = Auctionitis::ProductMaintenance->new();

print "Object class: ".ref( $pm )."\n";
print "Constant: ".Z_REMOVE."\n";

$pm->initialise();

if ( $pm->{ PM_Console } ) {
    $pm->{ Console } = 1;
}

$pm->dump_properties();




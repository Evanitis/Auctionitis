#!/usr/bin/perl
use strict;
use constant LIB_DIR => '/evan/lib/';
use lib LIB_DIR;
use Auctionitis::ProductMaintenance;

my $ar = Auctionitis::ProductMaintenance->new();

my $test = { Evan => 'clown', Tracey => 'queen', Jaymz => 'king' };

print "Initial Hash Key//pairs\n\n";

foreach my $key ( sort keys %$test ) {
    my $spacer = " " x ( 39-length( $key ) );
    print $key.": ".$spacer.$test->{ $key }."\n";
}

$ar->rename_hashkey( Hash    =>  $test   ,  OldKey  =>  'Evan'  ,   NewKey  =>  'ExEvan' );
$ar->rename_hashkey( Hash    =>  $test   ,  OldKey  =>  'Craig' ,   NewKey  =>  'ExCraig' );

print "Modified Hash Key//pairs\n\n";

foreach my $key ( sort keys %$test ) {
    my $spacer = " " x ( 39-length( $key ) );
    print $key.": ".$spacer.$test->{ $key }."\n";
}


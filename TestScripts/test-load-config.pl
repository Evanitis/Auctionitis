#!perl -w
#---------------------------------------------------------------------------------------------
# Copyright 2002, Evan Harris.  All rights reserved.
#---------------------------------------------------------------------------------------------

use TestPackage;

my $tp = TestPackage->new( 
    Config => 'AuctionitisReporting.config',
);
$tp->dump_properties();

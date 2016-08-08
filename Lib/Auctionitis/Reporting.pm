#!perl -w
#---------------------------------------------------------------------------------------------
# Copyright 2002, Evan Harris.  All rights reserved.
#---------------------------------------------------------------------------------------------

package Auctionitis::Reporting;

use strict;
use File::Copy;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use Fcntl qw(:DEFAULT :flock);                                # Supplies O_RDONLY and other constant file values

#=============================================================================================
# Method    : New 
#
# e.g. my $tm = TradeMe->new()
#=============================================================================================

sub new {

    my $class = shift;
    my $self  = {@_};
    bless ( $self, $class );

    unless ( defined $self-> { Config } ) {
        $self-> { Config } = 'AuctionitisReporting.config';
    }

    $self->_load_config;

    return $self;
}

#=============================================================================================
# Method    :  _Load_Config
#
# Load configuration file data
# Internal routine only...
#=============================================================================================

sub _load_config {

    my $self  = shift;
    sysopen( CONFIG, $self->{ Config }, O_RDONLY) or die "Cannot open $self->{ Config } $!";
    
    while  (<CONFIG>) {
            chomp;                       # no newline
            s/#.*//;                     # no comments
            s/^\s+//;                    # no leading white
            s/\s+$//;                    # no trailing white
            next unless length;          # anything left ?
            my ($ parm, $value ) = split( /\s*=\s*/, $_, 2 );
            $self->{ $parm} = $value;
    }
}

#=============================================================================================
# Method    : make_report_package 
#=============================================================================================

sub make_report_package {

    my $self    = shift;
    my $p       = { @_ };

    my $zip = Archive::Zip->new();

    # Create the required file names

    my $zipfile     = $self->{ OutfilePath }.'\\'.$p->{ TradeMeID }.'-'.$p->{ ReportDate }.'.zip';
    my $database    = $self->{ DatabasePath }.'\\'.$self->{ DatabaseFile };

    # Zip the data into the zip file

    my $member = $zip->addFile( $database, $self->{ DatabaseFile } );
    my $string = $zip->addString( $p->{ SalesData} , 'sold,csv' );
    $member->desiredCompressionMethod( COMPRESSION_DEFLATED );
    die 'Error writing ZIP file' unless $zip->writeToFileNamed( $zipfile ) == AZ_OK;
}

#=============================================================================================
# Method    : dump_properties
# Added     : 22/03/07
# Input     : 
# Returns   : dumps the Auctionitis properties to the auctionitis log
#=============================================================================================

sub dump_properties {

    my $self    = shift;
    
    foreach my $property (sort keys %$self ) {    
        my $spacer = " " x ( 20 - length( $property ) );
        print $property.":".$spacer.$self->{ $property }."\n";
    }
    
    return;
}

1;

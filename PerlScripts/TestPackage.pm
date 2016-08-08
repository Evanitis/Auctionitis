#!perl -w
#---------------------------------------------------------------------------------------------
# Copyright 2002, Evan Harris.  All rights reserved.
#---------------------------------------------------------------------------------------------

package TestPackage;

#=============================================================================================
# Method    : New 
# Added     : 22/03/07
#
# Create new Westgate object;
# e.g. my $tm = TradeMe->new()
#=============================================================================================

sub new {

    my $class = shift;
    my $self  = {@_};
    bless ( $self, $class );

    unless ( defined $self-> { Config } ) {
        $self-> { Config } = 'TestPackage.config';
    }

    $self->_load_config;

    return $self;
}

#=============================================================================================
# Method    :  _LoadConfig
# Added     : 22/03/07
#
# Load configuration file data
# Internal routine only...
#=============================================================================================

sub _load_config {

    my $self  = shift;
    sysopen(CONFIG, $self->{Config }, O_RDONLY) or die "Cannot open $config $!";
    
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
# Method    : dump_properties
# Added     : 22/03/07
# Input     : 
# Returns   : dumps the Auctionitis properties to the auctionitis log
#=============================================================================================

sub dump_properties {

    my $self    = shift;
    
    foreach my $property (sort keys %$self ) {    
        my $spacer = " " x ( 40 - length( $property ) );
        print $property.":".$spacer.$self->{ $property }."\n";
    }
    
    return;
}

1;

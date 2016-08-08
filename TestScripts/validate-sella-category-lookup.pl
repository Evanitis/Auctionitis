#!perl -w


# ! Comment out lines 8740-8744 in AuctionitisOld to elimiate the reference To DBProperties table
# ! Make sure the Auctionitis registry Optiosn are set appropriately
 


use strict;
use AuctionitisOld;

# Set up the Auctionitis object

my $tm = AuctionitisOld->new();
$tm->initialise( Product => "Auctionitis" );
$tm->DBconnect( "CategoryDB" );            # Connect to the Category database
$tm->{ Debug } = 0;

#    my $DSN     =   "driver={Microsoft Access Driver (*.mdb)};";    # Driver Name
#    $DSN        .=  "DBQ=\\\\".$server;                                                  # Server name

my $DSN =   "driver={Microsoft Access Driver (*.mdb)};";            # Driver Name
$DSN    .=  "DBQ=C:\\Evan\\Auctionitis Categories\\Auctionitis.mdb";    # File Name

my $dbh =   DBI->connect("dbi:ODBC:$DSN",'','');

my $SQL = $dbh->prepare( qq { 
        SELECT      *
        FROM        TMCategories
} );

$SQL->execute();

my $categories = $SQL->fetchall_arrayref( {} );

# Category
# Parent
# Sequence
# Description

foreach my $c ( @$categories ) {

    my $ok = $tm->sella_lookup_trademe_category( Category => $c->{ Category } );

    unless ( $ok ) {
        my $cattext = Get_Category_Text(
            Category    =>  $c->{ Category }    ,
        );
        while ( length ( $c->{ Category } ) < 5 ) {
            $c->{ Category } = " ".$c->{ Category };
        }
        print $c->{ Category }." ".$cattext."\n";
    }
}

sub Get_Category_Text {

    my $p = { @_ };
    my @catstack;           # array used as stack for storing category list

    # If the category spearator is not defined set it to the default ( "\" )

    if ( not defined( $p->{ Separator } ) ) {
        $p->{ Separator } = "\\";
    }

    # IF the category has not been passed or is 0 return an undefined value

    if ( ( not defined( $p->{ Category } ) )
    or ( $p->{ Category } eq"0" ) ) {
        return undef;
    }

    # put the starting category in the array then add each parent at the beginnning
    # of the array until we reach the category root value ( 0 )

    while ( $p->{ Category } ) {
        unshift @catstack, ( $p->{ Category } );
        $p->{ Category } = $tm->get_parent( $p->{ Category } );
    }

    # Starting at the beginning of the array get each categories description and 
    # add it to the return string inserting the separator value after the first element

    my $get_category_text = "";

    while ( scalar( @catstack ) > 0 ) {
        if ( $get_category_text eq "" ) { $get_category_text =  $tm->get_category_description( shift( @catstack) ); }
        else                            { $get_category_text .= $p->{ Separator }.$tm->get_category_description( shift( @catstack ) ); }
    }

    return $get_category_text;
}

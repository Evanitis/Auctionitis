use strict;
use DBI;

#  Connect to the Auctions database to get input data

my $dbh=DBI->connect('dbi:ODBC:Auctionitis')  ||  die "Error opening Auctions database: $DBI::errstr\n";

my $category = 473;
print "Attribute Category $category\n";

my $category_exists = check_attribute_cat( Category => $category );
print "Attribute Category Exists $category_exists\n";

unless ( $category_exists ) {

    # Prepare the insert statement for the new records

    my $update = qq {   INSERT   INTO     Attributes
                                        ( AttributeName         ,
                                          AttributeField        ,
                                          AttributeCategory     ,
                                          AttributeSequence     ,
                                          AttributeText         ,
                                          AttributeValue        ,
                                          AttributeCombo        ,
                                          AttributeProcedure    )
                        VALUES          ( ?,?,?,?,?,?,?,?       ) } ;                

    my $sth = $dbh->prepare($update)  ||  die "Error preparing statement: $DBI::errstr\n";

    # Insert the PC Games values

    $sth->execute(
        "Gconfirm"          ,
        "137"               ,
        $category           ,
        0                   ,
        ""                  ,
        ""                  ,
        0                   ,
        "EnableGameRating"  ,
    );
    print "Added Attribute Category $category\n";
}
else {

    print "Attribute Category $category Already exists\n";
}

print "Done\n";

sub check_attribute_cat {

    my $parms   = { @_ };

    # Create SQL Statement string

    my $SQLstmt = qq {
        SELECT        AttributeCategory
        FROM          Attributes
        WHERE       ( AttributeCategory = ? )
    };

    my $sth = $dbh->prepare($SQLstmt) || die "Error preparing statement: $DBI::errstr\n";
    
    $sth->execute(
        $parms->{ Category }    ,
    )   || die "Error exexecuting statement: $DBI::errstr\n";
    
    my $category = $sth->fetchrow_array;

    $sth->finish;
    
    return $category;

}

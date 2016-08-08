use strict;
use DBI;

my $dbh=DBI->connect('dbi:ODBC:Auctionitis') 
   || die "Error opening Auctions database: $DBI::errstr\n";
   $dbh->{LongReadLen} = 65555;            # caters for retrieval of memo fields

#------------------------------------------------------------------------------------------------------------
# Create SQL Statement Handles
# ------------------------------------------------------------------------------------------------------------

my $SQL_update_picture = $dbh->prepare( qq {
    UPDATE  Pictures
    SET     PictureFileName = ?
    WHERE   PictureKey      = ?
} );

my $SQL_get_picture_list = $dbh->prepare( qq {
    SELECT  *
    FROM    Pictures
} );

$SQL_get_picture_list->execute();
my $pictures =$SQL_get_picture_list->fetchall_arrayref( {} );

foreach my $p ( @$pictures ) {

    print "Before: ".$p->{ PictureFileName   }."\n";

    $p->{ PictureFileName   } =~ s/c:\\Program Files/c:\\Program Files \(x86\)/;

    print " After: ".$p->{ PictureFileName   }."\n";
    
    $SQL_update_picture->execute(
       "$p->{ PictureFileName   }" ,
        $p->{ PictureKey        }  ,
    );
};

print "Done!\n";

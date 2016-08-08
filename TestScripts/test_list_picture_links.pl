#!perl -w
#--------------------------------------------------------------------
# gettmdata.pl retrieve data from trademe for analysis and automation
# to run the script: perl.exe c:\evan\trademe\gettmdata.pl 
#
# Other program notes:
#--------------------------------------------------------------------

use strict;
use Auctionitis;

my $tm = Auctionitis->new();
$tm->initialise(Product => "Auctionitis");  # Initialise the product
$tm->DBconnect("Auctionitis103");
$tm->login();

eval { system("mkdir C:\\evan\\auctionitis103\\ImportedPics" ); };

my $picturekey1;

my $auctions = $tm->get_curr_listings();

foreach my $auction (@$auctions) {

    my $picfile = write_pic_file( $auction );
    sleep 2;

    
    if ( $picfile ne "NOPIC" ) {
        print "Adding Picture file $picfile to database\n";
        $picturekey1 = add_pic_record( $picfile );
    }
}

$auctions = $tm->get_sold_listings();

foreach my $auction (@$auctions) {

    my $picfile = write_pic_file( $auction );
    sleep 2;
    
    if ( $picfile ne "NOPIC" ) {
    
        $picturekey1 = add_pic_record( $picfile );
    }
}

$auctions = $tm->get_unsold_listings();

foreach my $auction (@$auctions) {

    my $picfile = write_pic_file( $auction );
    sleep 2;
    
    if ( $picfile ne "NOPIC" ) {
    
        $picturekey1 = add_pic_record( $picfile );
    }
}

# Success.

print "Done\n";
exit(0);


sub write_pic_file {

    my $auction = shift;
    
    my $filename = "NOPIC";
    
    my $url="http://www.trademe.co.nz/Browse/Listing.aspx?id=".$auction->{ AuctionRef };
    print "$url\n";

    my $link = $tm->get_picture_link( $auction->{ AuctionRef } );

    if ( $link ne "NOPIC" ) {

        $link =~ m/(^.*)(\/med)(.+$)/;
        $link = $1.$3;

        $link =~ m/(.*)(\/)(.+?)(\.)(.+?)($)/;
        $link = $1.$2.$3."_full".$4.$5;
        $filename = "C:\\evan\\auctionitis103\\ImportedPics\\".$3.$4.$5;

        print " Pic link: $link\n";
        print "File Name: $filename\n";

        $tm->import_picture(
            URL         =>  $link       ,
            FileName    =>  $filename   ,
        );
    }
    
    return $filename;
}

sub add_pic_record {

    my $filename = shift;

    # Check if the picture is in the picture table

    my $pickey = $tm->get_picture_key( PictureFileName => $filename );        

    if ( $pickey )   {
    
        print "Picture record $pickey for $filename already exists\n";

        return $pickey;
    }
    else {        

        # Write picture record

        $tm->add_picture_record( PictureFileName => $filename );
        $pickey = $tm->get_picture_key( PictureFileName => $filename );

        print "Record $pickey for $filename added\n";

        $filename =~ m/(.*)(\\)(.+?)(\.)(.+?)($)/;
        my $TMid  = $3;
        
        $tm->update_picture_record(
            PictureKey  => $pickey  ,
            PhotoId     => $TMid    ,
        );

        print "Record $pickey updated with TM Picture ID $TMid\n";
        
        return $pickey;
    }
}


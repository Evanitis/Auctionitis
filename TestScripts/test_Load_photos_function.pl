#!perl -w
#--------------------------------------------------------------------
# function to test the auction relist process
# Other program notes:
#--------------------------------------------------------------------

use strict;
use Auctionitis;
use Win32::OLE;

my $pb = Win32::OLE->new('MultiPB.clsMultiPB') or die;
my $returncode = 0;

### insert some text into the window header

$pb->InitialiseMultiBar();
$pb->{SetWindowTitle} = "Auctionitis: Task Progress Meter";
$pb->AddTask("Load All Photographs");
$pb->{SetCurrentTask} = 1;
$pb->{SetCurrentOperation} = "Retrieving Picture data for upload";
$pb->{SetTaskAction} = "Loading photos to TradeMe:";
$pb->UpdateMultiBar();

$pb->ShowMultiBar();

my $tm = Auctionitis->new();
$tm->initialise(Product => "Auctionitis");  # Initialise the product
$tm->DBconnect("Auctionitis103");           # Connect to the database

$pb->UpdateMultiBar();

my $pictures =  $tm->get_unloaded_pictures();

$pb->{SetCurrentOperation} = $tm->{ErrorMessage};
$pb->UpdateMultiBar();
sleep 3;

my $piccount = @$pictures;
print "No. Pics: ".$piccount."\n\n";

$pb->{SetProgressTotal} = $piccount;
$pb->UpdateMultiBar();

my $counter = 1;

$pb->{SetCurrentOperation} = "Logging on to TradeMe";
$pb->UpdateMultiBar();
$tm->login();

foreach my $picture (@$pictures) {

    $pb->{SetProgressCurrent} = $counter;
    $pb->UpdateMultiBar();

    if      ( $picture->{PictureFileName} )     {
    
            $pb->{SetCurrentOperation} = "Loading ".$picture->{PictureFileName};
            my $photoid = $tm->load_picture(FileName    =>$picture->{PictureFileName} );

            $tm->update_picture_record(PictureKey       =>$picture->{PictureKey},
                                       PhotoId          =>$photoid);
            sleep 3;
    } else {                                      
            $pb->{SetCurrentOperation} = "Bad picture Name";
    }
    
    $counter++;

    if ($pb->{Cancelled}) {
            $pb->QuitMultiBar();        
            exit;
    }

}

$pb->MarkTaskCompleted(1);
$pb->UpdateMultiBar();
sleep 2;
$pb->QuitMultiBar();

# Success.

print "Done\n";
exit(0);

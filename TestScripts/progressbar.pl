#! perl -w
    use strict;
    use Win32::OLE;
    #
    my $pb = Win32::OLE->new('AuctionBar.AuctionPB') or die;

    ### insert some text into the document
    $pb->{WindowTitle} = "Trademe Auction Upload";
    $pb->{AuctionTotal} = 50;
    $pb->{PhotoTotal} = 40;
    $pb->{AuctionsLoaded} = 0;
    $pb->{PhotosLoaded} = 0;
    
    my $counter = 0;
    while ($counter <= 40) {
        $pb->{PhotosLoaded} = $counter;
        $pb->UpdateBar();
        $counter++;
        sleep 1;
    }
    
    $counter = 0;
    while ($counter <= 50) {
        $pb->{AuctionsLoaded} = $counter;
        $pb->UpdateBar();
        $counter++;
        sleep 1;
    }
    
    $pb->QuitBar();

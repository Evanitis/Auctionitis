#!perl -w
#--------------------------------------------------------------------
# gettmdata.pl retrieve data from trademe for analysis and automation
# to run the script: perl.exe c:\evan\trademe\gettmdata.pl 
#
# Other program notes:
#--------------------------------------------------------------------

use strict;

my $data;

# my $input = "C:\\Evan\\AuctionitisBase\\TradeMe pages\\New Auction\\New Auction with 3 photos to be removed.txt";
my $input = "C:\\Evan\\AuctionitisBase\\TradeMe pages\\Photo Pages\\Photo Extract information #2.txt";

# C:\Evan\AuctionitisBase\TradeMe pages\Photo Pages\Photo Extract information #2.txt

$data = parse($input);

# Success.

print "Done\n";


#---------------------------------------------------------------------------------------------------

sub parse {

    my $infile = shift;
    my @auctions;

    print "processing file: $infile\n\n";

    local $/;                                                       #slurp mode (undef)
    local *F;                                                       #create local filehandle
    open(F, "< $infile") || die "Cant find file $input";
    my $content = <F>;                                              #read whole file
    close(F);                                                       # ignore retval


    print "Evaluating data with expression #1\n\n";                 

    my $data = $content;


#    if ($content =~ m/(<a href=")(\/Sell\/RemovePhoto\.aspx\?photoid=)(\d+)(&type=mult)(">)/gs) {
    if ($data =~ m/(<a href=")(\/Sell\/RemovePhoto\.aspx\?photoid=)(\d+)(&amp;type=mult)(">)/gs) {
#                      <a href="   /Sell /RemovePhoto .aspx ?photoid=17223946&amp;type=mult"

        
        my $url = "http://www.TradeMe.co.nz".$2.$3.$4; 

        print "Remove URL: $url\n";

    }

    print "Evaluating data with expression #2\n\n";                 

    if ($data =~ m/(<a href=")(\/Sell\/RemovePhoto\.aspx\?photoid=)(\d+)(&amp;type=mult)(">)/gs) {

        my $url = "http://www.TradeMe.co.nz".$2.$3.$4; 

        print "Remove URL: $url\n";

    }

    $data = $content;
    
    print "Evaluating data with while loop\n\n";                 

    while ($data =~ m/<a href="\/Sell\/RemovePhoto\.aspx\?photoid=(\d+)&amp;type=mult">/gs) {

#        <a href="/Sell/RemovePhoto.aspx?photoid=17223646&amp;type=mult">

        print "Remove Picture: $1\n";

    }

   
}


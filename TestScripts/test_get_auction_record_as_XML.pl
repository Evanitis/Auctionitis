#------------------------------------------------------------------------------------------------------------
# Test/prototype program to get single record as XML string
# This script uses the export XML function to write the standard XML export file to a temporary file
# The temporary file is read from disk into a string
# It then modifies the export data to look like the XML input datastream expected by the
# PUT_AUCTIONITIS_RECORD API
#------------------------------------------------------------------------------------------------------------

use Auctionitis; 
use IO::File; 

use POSIX qw(tmpnam);

my $record      = shift;



my $SQL         = "SELECT * FROM Auctions WHERE AuctionKey = ".$record;
my $filetext    = "XML extract for $record";
my $outfile;
my $XMLtext;

# Create a temporary file to hold the exported XML record

do { $outfile = tmpnam()  }
    until my $fh = IO::File->new($outfile, O_RDWR|O_CREAT|O_EXCL);
    
# Call the XML export function

$tm = Auctionitis->new();
$tm->initialise(Product => "Auctionitis");  # Initialise the product
$tm->DBconnect();                          # Connect to the database
 

$tm->export_XML(
    SQL        => $SQL                  ,
    Outfile    => $outfile              ,
    FileText   => $filetext             ,
);

    
# read the while file into a single variable

local $/;                                                      #slurp mode (undef)
local *F;                                                      #create local filehandle
open(F, "< $outfile\0") || exit;
$XMLtext = <F>;                                                #read whole file
close(F);                                                      # ignore retval

# Delete the temporary file

unlink($outfile);

# Reformat the XML string to the format used for Auctionits XML Record input

# Retrieve the Export Version (which is the database version) from the XML header

$XMLtext =~ m/(<ExportVersion>)(.+?)(<\/ExportVersion>)/g;
my $xv = $2;

# Retrieve the Category Service date from the XML header

$XMLtext =~ m/(<CategoryServiceDate>)(.+?)(<\/CategoryServiceDate>)/g;
my $csd = $2;

# Retrieve the Record Data from the Auction record node and strip the newlines out

$XMLtext =~ m/(<AuctionRecord>\s*)(.+?)(\s*<\/AuctionRecord>)/gs;
my $rcd = $2;
$rcd =~ tr/\n//d;

while ( $rcd =~ m/(.*>)(\s+?)(<.*)/g ) {

    $rcd = $1.$3;

}

# get the picture input and modify it to just be picture names in a PICTURES tag

# Insert the Start and end Pictures tags around the existing Picture Key tags

$rcd =~ m/(.*?)(<PictureKey1>.*?)(<\/PictureKey3>)(.*)/;
$rcd = $1."<Pictures>".$2.$3."</Pictures>".$4;

# Extract the picture file name from picture key 1 if found

$rcd =~ m/(.*?)(<PictureKey1><PictureFileName>)(.*?)(<\/PictureFileName>)(.+?)(<\/PictureKey1>)(.*)/;

if ($3 ne "") {
   $rcd = $1."<PictureFile>".$3."</PictureFile>".$7;
}
else {
   $rcd = $1.$7;
}

# Extract the picture file name from picture key 2 if found

$rcd =~ m/(.*?)(<PictureKey2><PictureFileName>)(.*?)(<\/PictureFileName>)(.+?)(<\/PictureKey2>)(.*)/;

if ($3 ne "") {
   $rcd = $1."<PictureFile>".$3."</PictureFile>".$7;
}
else {
   $rcd = $1.$7;
}

# Extract the picture file name from picture key 2 if found

$rcd =~ m/(.*?)(<PictureKey3><PictureFileName>)(.*?)(<\/PictureFileName>)(.+?)(<\/PictureKey3>)(.*)/;

if ($3 ne "") {
   $rcd = $1."<PictureFile>".$3."</PictureFile>".$7;
}
else {
   $rcd = $1.$7;
}

# Remove obsolete and invalid fields from XML input string

$rcd =~ m/(.*?)(<AuctionKey>.*?<\/AuctionKey>)(.*)/;
$rcd = $1.$3;
$rcd =~ m/(.*?)(<AuctionRef>.*?<\/AuctionRef>)(.*)/;
$rcd = $1.$3;
$rcd =~ m/(.*?)(<AuctionStatus>.*?<\/AuctionStatus>)(.*)/;
$rcd = $1.$3;
$rcd =~ m/(.*?)(<AuctionSold>.*?<\/AuctionSold>)(.*)/;
$rcd = $1.$3;
$rcd =~ m/(.*?)(<AuctionSite>.*?<\/AuctionSite>)(.*)/;
$rcd = $1.$3;
$rcd =~ m/(.*?)(<CloseDate>.*?<\/CloseDate>)(.*)/;
$rcd = $1.$3;
$rcd =~ m/(.*?)(<CloseTime>.*?<\/CloseTime>)(.*)/;
$rcd = $1.$3;
$rcd =~ m/(.*?)(<DateLoaded>.*?<\/DateLoaded>)(.*)/;
$rcd = $1.$3;
$rcd =~ m/(.*?)(<FreeShippingNZ>.*?<\/FreeShippingNZ>)(.*)/;
$rcd = $1.$3;
$rcd =~ m/(.*?)(<Message>.*?<\/Message>)(.*)/;
$rcd = $1.$3;
$rcd =~ m/(.*?)(<RelistCount>.*?<\/RelistCount>)(.*)/;
$rcd = $1.$3;
$rcd =~ m/(.*?)(<ShippingInfo>.*?<\/ShippingInfo>)(.*)/;
$rcd = $1.$3;
$rcd =~ m/(.*?)(<TemplateKey>.*?<\/TemplateKey>)(.*)/;
$rcd = $1.$3;
$rcd =~ m/(.*?)(<UseTemplate>.*?<\/UseTemplate>)(.*)/;
$rcd = $1.$3;

$rcd =~ s/(.*?)(<AuctionRef \/>)(.*)/$1$3/;
$rcd =~ s/(.*?)(<AuctionStatus \/>)(.*)/$1$3/;
$rcd =~ s/(.*?)(<AuctionSite \/>)(.*)/$1$3/;
$rcd =~ s/(.*?)(<CloseDate \/>)(.*)/$1$3/;
$rcd =~ s/(.*?)(<CloseTime \/>)(.*)/$1$3/;
$rcd =~ s/(.*?)(<DateLoaded \/>)(.*)/$1$3/;
$rcd =~ s/(.*?)(<FreeShippingNZ \/>)(.*)/$1$3/;
$rcd =~ s/(.*?)(<Message \/>)(.*)/$1$3/;
$rcd =~ s/(.*?)(<RelistCount \/>)(.*)/$1$3/;
$rcd =~ s/(.*?)(<ShippingInfo \/>)(.*)/$1$3/;
$rcd =~ s/(.*?)(<TemplateKey \/>)(.*)/$1$3/;
$rcd =~ s/(.*?)(<UseTemplate \/>)(.*)/$1$3/;

my $XMLData = "<AuctionRecord><DatabaseVersion>".$xv."</DatabaseVersion><CategoryServiceDate>".$csd."</CategoryServiceDate>".$rcd."</AuctionRecord>";

# print the XML data

print $XMLData."\n";

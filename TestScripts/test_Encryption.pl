use strict;
use Crypt::CBC;
use DBI;

#my $cipher = Crypt::CBC->new(
#    -key        => 'AuctionitisIsVeryKewl'  ,
#    -cipher     => 'Blowfish'               ,
#);

my $key    = Crypt::CBC->random_bytes(8);  # assuming a 8-byte block cipher
my $iv     = Crypt::CBC->random_bytes(8);
my $cipher = Crypt::CBC->new(
    -literal_key => 1       ,
    -key         => $key    ,
    -iv          => $iv     ,
    -header      => 'none'  ,
);

my $ciphertext = $cipher->encrypt( "aBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz01234567890_\!\@\#\$%^\&\*\(\)\{\}\[\]\:\"\;\'\<\>\?\,\." );
my $plaintext  = $cipher->decrypt( $ciphertext );

print "    Encrypted Value: ".$ciphertext."\n";
print "  Unencrypted Value: ".$plaintext."\n";

$ciphertext = $cipher->encrypt( "password" );
$plaintext  = $cipher->decrypt( $ciphertext );

print "    Encrypted Value: ".$ciphertext."\n";
print "  Unencrypted Value: ".$plaintext."\n";


my ($sth, $SQLStmt);

my $dbh=DBI->connect('dbi:ODBC:Auctionitis') 
   || die "Error opening Auctions database: $DBI::errstr\n";
   $dbh->{LongReadLen} = 65555;            # caters for retrieval of memo fields

#------------------------------------------------------------------------------------------------------------
# SQL Statement to Set Database version property
#------------------------------------------------------------------------------------------------------------

my $SetProperty = qq {
    UPDATE  DBProperties
    SET     Property_Value  = ?
    WHERE   Property_Name   = ?
};


#------------------------------------------------------------------------------------------------------------
# SQL Statement to Set Database version property
#------------------------------------------------------------------------------------------------------------

my $GetProperty = qq {
    SELECT      Property_Value
    FROM        DBProperties
    WHERE     ( Property_Name = ? )
};

#------------------------------------------------------------------------------------------------------------
# Update the database property
#------------------------------------------------------------------------------------------------------------

$sth = $dbh->prepare( $SetProperty )          || die "Error preparing statement\n: $DBI::errstr\n";
$sth->execute(  $ciphertext , "TMPassword",)  || die "Set Property - Error executing statement: $DBI::errstr\n";

#------------------------------------------------------------------------------------------------------------
# Retrieve the database property
#------------------------------------------------------------------------------------------------------------

$sth = $dbh->prepare( $GetProperty )            || die "Error preparing statement\n: $DBI::errstr\n";
$sth->execute( "TMPassword" )                   || die "Get property - Error executing statement: $DBI::errstr\n";

my $dbcipher = $sth->fetchrow_array;

print " DB Encrypted Value: ".$dbcipher."\n";

my $dbplain  = $cipher->decrypt( $dbcipher );

print "DB Unencrypted Value: ".$dbplain."\n";


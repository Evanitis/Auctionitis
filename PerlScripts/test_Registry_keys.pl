use strict;
use Win32::TieRegistry;

my $pound= $Registry->Delimiter("/");
my $key = $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Personalities"};
# my @key_names= $key->SubKeyNames;

foreach my $subkey (  $key->SubKeyNames  ) {
    print "Subkey: $subkey\n";
}

$key = $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Output"};
# my @key_names= $key->SubKeyNames;

foreach my $field ( keys( %$key ) ) {
    print "Field: $field\n";
}

$key   = $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Options"}
         or die "Can't read LMachine/System/Disk key: $^E\n";

foreach my $field ( keys(%$key) ) {
    print "Key: ".substr( $field,1 )." Value: ".$key->{ $field }."\n";
}

$key = $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Auctionitis/Preferences"};

if  ( defined( $key ) ) {

    my $data = $key->{"/SortColumn" };
    $data++;
    $key->{"/SortColumn" } = $data;
}

# Check license key exists




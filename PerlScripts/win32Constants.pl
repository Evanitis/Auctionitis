use strict;
use Win32::OLE;
use Win32::OLE::Const;

my $xl = Win32::OLE::Const->Load("Microsoft Word");
printf "Word type library contains %d constants:\n", scalar keys %$xl;
foreach my $Key (sort keys %$xl) {
    print "$Key = $xl->{$Key}\n";
}


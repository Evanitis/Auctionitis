#!perl -w

use strict;
use Win32::OLE;

my($Object, $Class);

        my $Count = Win32::OLE->EnumAllObjects(sub {
            my $Object = shift;
            my $Class = Win32::OLE->QueryObjectType($Object);
            printf "# Object=%s Class=%s\n", $Object, $Class;
        });



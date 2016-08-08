#!perl -w

use strict;
use Win32::OLE;
use Win32::OLE::Variant;
use Win32::OLE::Const;

my $eu = Win32::OLE::Const->Load("Eudora Type Library");
# my $eu = Win32::OLE::Const->Load("EudoraLib");
# $word = Win32::OLE -> new('Word.Application', 'Quit');
# my($mail) = Win32::OLE->new('EudoraLib.EuApplication');

my($mail) = Win32::OLE->new('Eudora.EuApplication.1');
$mail->{Visible} = 0;    # Watch what happens
#$mail->CheckMail();    # Check the mail

# Print mail in "Inbox"

my $folder = $mail->Folder("In", 0); 
my $msgs = $folder->{Messages};
for (my $i = 1; $i <= $msgs->Count(); $i++) {
    print "Mail subject is ".$msgs->Item($i)->{Subject}."\n";
    }

# Print list of folders in root directory

my $folders = $mail->{Folders};
for (my $i = 1; $i <= $folders->Count(); $i++) {
    print "Folder Name:".$folders->Item($i)->{Name}."\n";
    listfolder($folders->Item($i)->{Name});
    }

# Print list of sub folders in directory

sub listfolder {
    my $parent = shift;
    my $folder = $mail->Folder($parent, 0);
    my $folders = $folder->{Folders};
    for (my $i = 1; $i <= $folders->Count(); $i++) {
        print "            ->".$folders->Item($i)->{Name}."\n";
        listfolder($folders->Item($i)->{Name});
    }
}

$mail->CloseEudora();

# Success.
print "Success \n";
exit(0);

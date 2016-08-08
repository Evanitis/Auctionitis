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

my $folder = $mail->Folder("EH", 0); 
$folder->Resynchronize();
my $folders = $folder->{Folders};
print "Folder Name:        ".$folder->Name."\n";
print "File Path:          ".$folder->Path."\n";
print "Full Name:          ".$folder->Name."\n";
print "Folder Count:       ".$folders->Count()."\n";
print "Folder Level:       ".$folder->Level()."\n";
print "Can have subfolders:".$folder->bCanContainSubFolders()."\n";
print "Is IMap Folder:     ".$folder->bIsImapFolder()."\n";

for (my $i = 1; $i <= $folders->Count(); $i++) {
    print "Folder Name:".$folders->Item($i)->{Name}."\n";
    }

$mail->CloseEudora();

# Success.
print "Success \n";
exit(0);

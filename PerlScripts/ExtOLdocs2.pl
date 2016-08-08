#! perl -w
#Extract Outlook notes and couments to text files..... 
use strict;
use Win32::OLE;
use Win32::OLE::Const 'Microsoft Outlook';

### open Outlook
### (will die if outlook not installed on your machine)

my $ol = Win32::OLE->new('Outlook.Application', 'Quit') or die;
# $ol->{Visible} = 1;

# set the name space value
my $ns=$ol->GetNameSpace("MAPI");

# set the folder type to mail folders 
my $rootflr=$ns->GetDefaultFolder(olFolderInbox);

# Setup the input and output folder names
my $infolder = $rootflr->Folders("TMPending");
my $outfolder = $rootflr->Folders("TMProcessed");

# get the list of email items in the folder    
my $items = $infolder->Items;

my $count = $items->Count;
print "Emails to process : $count\n";
    
#process each email item    
my $current_item = $items->GetFirst;

while (defined($current_item)) {
    my $email_subject = $current_item->subject;

    my $email_body = $current_item->body;

    print "Subject   : $email_subject\n\n";
    # print "Email Data: $email_body\n\n";
    $current_item->Move($outfolder);
   
    $current_item = $items->GetNext;
}

### close the document and the application

# $ol->Quit();

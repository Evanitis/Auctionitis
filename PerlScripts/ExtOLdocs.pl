#! perl -w
#Extract Outlook notes and couments to text files..... 
    use strict;
    use Win32::OLE;
    use Win32::OLE::Const 'Microsoft Outlook 9.0 Object Library';
    ### open Outlook
    ### (will die if outlook not installed on your machine)
    my $ol = Win32::OLE->new('Outlook.Application', 'Quit') or die;
    # $ol->{Visible} = 1;
    my $ns=$ol->GetNameSpace("MAPI");
    my $rootflr=$ns->GetDefaultFolder(olFolderInbox);
    my $flr = $rootflr->Folders("Technotes");
    # my $docs = $flr->Items;

   ## Position the read at the start of the folder and then start reading....
   
   my $subject=();
   my $count = 1;
   my $limit = $flr->Count();
   print "Number of docs in folder: $count\n";
   my $doc = $flr->Items->GetFirst();

    ### read text from the document and print to the console
    
    while ($count < $limit) {
        $subject = $doc->Subject;
        print ">> Document $count : $subject\n";
    $doc = $flr->Items->GetNext();
    $count=$count+1;
    }

    ### close the document and the application
   
    $ol->Quit();

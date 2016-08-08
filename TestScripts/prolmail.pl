#! perl -w
#Extract Outlook notes and couments to text files..... 
use strict;
use Win32::OLE;
use Win32::OLE::Const 'Microsoft Outlook';

my ($inputdata, $item, $email_body, $email_subject);

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

while ($count > 0) {

    $item = $infolder->Items(1);
    $email_subject = $item->subject;
    $email_body = $item->body;

    $inputdata = $email_subject."\n".$email_body;
    parse_item($inputdata);   
    
    $item->Move($outfolder);
    $items = $infolder->Items;
    $count = $items->Count;
}

### close the document and the application

# $ol->Quit();

sub parse_item {

    my $text = shift;
    my $ar = Responder->new();

    my $response = $ar->process_mail_in($text);

    # Get the configured form name and subject from the registry

    my $pound= $Registry->Delimiter("/");
    my $key  = $Registry->{"HKEY_CURRENT_USER/Software/iRobot Limited/Responder/Forms"}
               or die "Can't read LMachine/System/Disk key: $^E\n";

    if ( $key->{"/FormDir"             } )  { $FormDir = $key->{"/FormDir"            }; }

    if ($response->{TYPE} eq "RESERVEMET")  {
        if ( $key->{"/Sold"            } )  { $Form    = $FormDir."\\".$key->{"/Sold" }; }
        if ( $key->{"/SoldSubject"     } )  { $Subject = $key->{"/SoldSubject"        }; }

        print "Template   : $Form\n";
        print "Subject    : $Subject\n";    
        print "Type       : $response->{TYPE       }\n";
        print "Buyer Name : $response->{BUYERNAME  }\n";
        print "Buyer Email: $response->{BUYEREMAIL }\n";
        print "Description: $response->{DESCRIPTION}\n";
        print "Close Price: $response->{CLOSEPRICE }\n";
        print "Ship Info  : $response->{SHIPINFO   }\n";
        print "Auction Ref: $response->{AUCTIONREF }\n";

        send_mail();
    }

    if ($response->{TYPE} eq "BUYNOW")      {
        if ( $key->{"/BuyItNow"        } )  { $Form    = $FormDir."\\".$key->{"/BuyItNow"        }; }
        if ( $key->{"/BuyItNowSubject" } )  { $Subject = $key->{"/BuyItNowSubject" }; }

        print "Template   : $Form\n";
        print "Subject    : $Subject\n";    
        print "Type       : $response->{TYPE       }\n";
        print "Buyer Name : $response->{BUYERNAME  }\n";
        print "Buyer Email: $response->{BUYEREMAIL }\n";
        print "Description: $response->{DESCRIPTION}\n";
        print "Close Price: $response->{CLOSEPRICE }\n";
        print "Ship Info  : $response->{SHIPINFO   }\n";
        print "Auction Ref: $response->{AUCTIONREF }\n";


        send_mail();
    }

    if ($response->{TYPE} eq "OFFERYES"  )  {
        if ( $key->{"/OfferYes"        } )  { $Form    = $FormDir."\\".$key->{"/OfferYes"        }; }
        if ( $key->{"/OfferYesSubject" } )  { $Subject = $key->{"/OfferYesSubject" }; }

        print "Template   : $Form\n";
        print "Subject    : $Subject\n";    
        print "Type       : $response->{TYPE       }\n";
        print "Buyer Name : $response->{BUYERNAME  }\n";
        print "Buyer Email: $response->{BUYEREMAIL }\n";
        print "Description: $response->{DESCRIPTION}\n";
        print "Close Price: $response->{CLOSEPRICE }\n";
        print "Auction Ref: $response->{AUCTIONREF }\n";


        send_mail();
}

sub send_mail {

$ar->send_email( TEMPLATE    => $Form,
                 SUBJECT     => $Subject,
                 TOADDRESS   => $response->{BUYEREMAIL},
                 AUCTIONREF  => $response->{AUCTIONREF} );
}

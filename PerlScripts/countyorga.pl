#!perl -w
#--------------------------------------------------------------------
# countyorga.pl was inspired by Peter Cook (well the name was !)
# It's intended use is to be called from Eudora email application
# to process mail identified by a filter.
# This prototype version will recieve the piece of mail, write it to
# a log file, analyze it, then send a response to the cunt in charge
# of email. 
#--------------------------------------------------------------------
use strict;
use MIME::Lite;

my $msgfile = "c:\\evan\\source\\testdata\\countyorga.msg";

open my $log,  "> c:\\evan\\source\\testdata\\countyorga.log." or die "Cannot open countyorga.log: $!";
open my $msg,  "> $msgfile" or die "Cannot open countyorga.msg: $!";

# Get the senders email address

my $whofrom = shift;

# Write the email from Eudora into the log file

while (<>) {
    print $log "$_\n";
}

my $msgdata = <<EOF;
Dear cunt in charge of email,

I have recieved your email and wish to acknowledge its arrival. 

You can be sure that your privacy has been properly respected and I have disposed of the copies I have made by handing it out to the gentlemen entering the "self service booths" at the back of the the local porn shop. Your email looked rather fetching against a grey plastic raincoat.

Please send more email as the wankers have spunked all over your last lot already.

Your sincerely,
Count Yorga
Shitsucker.
EOF

my $mimedata = MIME::Lite->new(
                    From     =>'countyorga@www.dr-mofo.co.nz',
                    To       =>$whofrom,
                    Subject  =>'Hello',
                    Data     =>$msgdata);

$mimedata->print($msg);

my $cmd = "c:\\Progra~1\\qualcomm\\eudora\\eudora.exe $msgfile";
print "$cmd\n";
system($cmd);

# Success.
print "Success \n";

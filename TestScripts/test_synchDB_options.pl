#!perl -w
#--------------------------------------------------------------------
# gettmdata.pl retrieve data from trademe for analysis and automation
# to run the script: perl.exe c:\evan\trademe\gettmdata.pl 
#
# Other program notes:
#--------------------------------------------------------------------

use strict;
use Auctionitis;

my $auction = shift;

my $tm = Auctionitis->new();

$tm->login();

my %options = $tm->get_synch_options();

# print "$options{DBNoSiteDelete}\n";
# print "$options{SiteNoDBAddNew}\n";
# print "$options{SiteNoDBDeleteOld}\n";

if     ( $options{DBNoSiteDelete} )     { print "Delete from DataBase if not in site:           Yes\n"; }
else                                    { print "Delete from DataBase if not in site:           No\n"; }

if     ( $options{SiteNoDBAddNew} )     { print "Add New items to DataBase if found on site:    Yes\n"; }
else                                    { print "Add New items to DataBase if found on site:    No\n"; }

if     ( $options{SiteNoDBDeleteOld} )  { print "Remove completed items from site if not in DB: Yes\n"; }
else                                    { print "Remove completed items from site if not in DB: No\n"; }

print "Done\n";
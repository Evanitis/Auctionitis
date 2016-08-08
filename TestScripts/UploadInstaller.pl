#!perl -w
#---------------------------------------------------------------------------------------------
# Copyright 2002, Evan Harris.  All rights reserved.
# 
# What the program will do:
# BuildAuctionitis
#---------------------------------------------------------------------------------------------

use strict;
use Net::FTP;

my $ok;

send_web4biz();
send_zillion();

print "Done\n";

###############################################################################
#                            S U B R O U T I N E S                            #
###############################################################################

#---------------------------------------------------------------------------------------------
# Subroutine to transmit updated installer to web site9s)
#---------------------------------------------------------------------------------------------


sub send_web4biz {

    my $localdir   = "c:\\evan\\Auctionitis103";
    my $exefiles   = "c:\\evan\\Auctionitis103\\QSetup-Installer";
    my $installer  = "Auctionitis-3.0.0-Install.exe";

    my $host       = "75.126.222.122";
    my $username   = "auctis";
    my $password   = 'OxGJJ!4zc)HF';
    my $rootdir    = "/public_html";
    my $downdir    = "/public_html/download";

    my $ftp        = Net::FTP->new($host);

    print "$@\n";

    # This is where the transfers occur

    print "Logging into Web4biz\n"; 
    
    $ok         = $ftp->login($username, $password);

    if  ( $ok ) { print "Logged in succesfully\n"; }
    else        { print "Error encountered logging in: $@\n"; }
    
    $ok         = $ftp->cwd($downdir);
    unless ( $ok ) { print "FTP Error: $@\n"; }

    $ok         = $ftp->binary;
    unless ( $ok ) { print "FTP Error: $@\n"; }
    
    print "Sending Installer\n";    
    
    $ok         = $ftp->delete($installer);
    unless ( $ok ) { print "FTP Error: $@\n"; }
    $ok         = $ftp->put($exefiles."\\".$installer, $installer);
    unless ( $ok ) { print "FTP Error: $@\n"; }


    $ok         = $ftp->quit;
    unless ( $ok ) { print "FTP Error: $@\n"; }
}


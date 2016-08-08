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

send_webhaven();
send_web4biz();
send_domainz();

print "Done\n";

###############################################################################
#                            S U B R O U T I N E S                            #
###############################################################################

#---------------------------------------------------------------------------------------------
# Subroutine to transmit generated data to website
#---------------------------------------------------------------------------------------------

sub send_webhaven {

    # Set up variables to manage the transfers

    my $localdir   = "c:\\evan\\Auctionitis103";
    my $exefiles   = "c:\\evan\\Auctionitis103\\Output";
    my $installer  = "Auctionitis-2.0.0-Install.exe";

    my $host       = "ftp.auctionitis.web-haven.net";
    my $username   = "auctis";
    my $password   = "auc0805";
    my $rootdir    = "/public_html/auctionitis";
    my $downdir    = "/public_html/download";
    
    # Transfer files to the Web-Haven Site

    
    my $ftp        = Net::FTP->new($host);
    
    # This is where the transfers occur

    print "Logging into WEB-HAVEN\n"; 
    
    $ok         = $ftp->login($username, $password);
    
    if  ( $ok ) { print "Logged in succesfully\n"; }
    else        { print "Error encountered logging in: $@\n"; }
    
    $ok         = $ftp->cwd($rootdir);
    unless ( $ok ) { print "FTP Error: $@\n"; }
    
    print "Sending Installer\n";    
    
    $ok         = $ftp->delete($installer);
    unless ( $ok ) { print "FTP Error: $@\n"; }
    $ok         = $ftp->put($exefiles."\\".$installer, $installer);
    unless ( $ok ) { print "FTP Error: $@\n"; }

    $ok         = $ftp->quit;
    unless ( $ok ) { print "FTP Error: $@\n"; }

}

sub send_web4biz {

    my $localdir   = "c:\\evan\\Auctionitis103";
    my $exefiles   = "c:\\evan\\Auctionitis103\\Output";
    my $installer  = "Auctionitis-2.0.0-Install.exe";

    my $host       = "web4.web-wide-hosting.biz";
    my $username   = "auctis";
    my $password   = "evantrace115";
    my $rootdir    = "/auctionitis.web-wide-hosting.biz";
    my $downdir    = "/auctionitis.web-wide-hosting.biz/download";

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

sub send_domainz {

    my $localdir   = "c:\\evan\\Auctionitis103";
    my $exefiles   = "c:\\evan\\Auctionitis103\\Output";
    my $installer  = "Auctionitis-2.0.0-Install.exe";

    my $host       = "ftp.domainz.net.nz";
    my $username   = "auctionitis.co.nz";
    my $password   = "if93vy";
    my $rootdir    = "/";
    my $downdir    = "/download";

    my $ftp        = Net::FTP->new($host);

    # This is where the transfers occur

    print "Logging into DOMAINZ\n"; 
    
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

    # exit the FTP agent
    
    $ok = $ftp->quit;
    unless ( $ok ) { print "FTP Error: $@\n"; }

}
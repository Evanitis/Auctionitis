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

send_auctionitis();

print "Done\n";

###############################################################################
#                            S U B R O U T I N E S                            #
###############################################################################

sub send_auctionitis {

    my $localdir   = "c:\\evan\\Auctionitis103";
    my $exefiles   = "c:\\evan\\Auctionitis103\\QSetup-Installer";
    my $updfiles   = "c:\\evan\\Auctionitis103\\QSetup-Updater";
    my $upgrades   = "c:\\evan\\Auctionitis103\\Output";
    my $bldfile    = "BuildHistory.txt";
    my $fixfile    = "FixHistory.txt";
    my $installer  = "Auctionitis-4.0.0-Install.exe";
    my $update     = "Auctionitis-4.0.0-Update.exe";
    my $autofile   = "AuctionitisAutoUpdate.info";
    my $autodata   = "AuctionitisAutoUpdate.update";
    my $currbuild  = "CurrentBuild.txt";

    my $username   = "auctis";
    my $host       = "ftp.auctionitis.info";
    my $password   = "OxGJJ!4zc)HF";
    my $rootdir    = "/public_html";
    my $downdir    = "/public_html/download";
    my $upddir     = "/public_html/Updates/Auctionitis";

    my $ftp        = Net::FTP->new( $host );

    # This is where the transfers occur

    # Log into the web site
    
    print "Logging into Auctionitis Info Site\n"; 

    $ok         = $ftp->login( $username, $password );

    if  ( $ok ) { print "Logged in succesfully\n"; }
    else        { print "Error encountered logging in: $@\n"; }

    #-----------------------------------------------------------------
    # Set binary mode on
    #-----------------------------------------------------------------

    $ok         = $ftp->binary;
    unless ( $ok ) { print "FTP Error: $@\n"; }

    #-----------------------------------------------------------------
    # Set the download directory
    #-----------------------------------------------------------------

    $ok         = $ftp->cwd($downdir);
    unless ( $ok ) { print "FTP Error: $@\n"; }

    #-----------------------------------------------------------------
    # Transmit the installation file
    #-----------------------------------------------------------------
    
    print "Sending Installer\n";    
    
    $ok         = $ftp->delete($installer);
    unless ( $ok ) { print "FTP Error: $@\n"; }

    $ok         = $ftp->put($exefiles."\\".$installer, $installer);
    unless ( $ok ) { print "FTP Error: $@\n"; }

    #-----------------------------------------------------------------
    # Transmit the update installer 
    #-----------------------------------------------------------------

    print "Sending Update\n";    
 
    $ok         = $ftp->delete($update);
    unless ( $ok ) { print "FTP Error: $@\n"; }

    $ok         = $ftp->put($updfiles."\\".$update, $update);
    unless ( $ok ) { print "FTP Error: $@\n"; }

    #-----------------------------------------------------------------
    # Set Auto update directory
    #-----------------------------------------------------------------

    print "Sending Current Build Number\n\n";    

    $ok         = $ftp->delete($currbuild);
    unless ( $ok ) { print "FTP Error: $@\n"; }

    $ok         = $ftp->put($localdir."\\".$currbuild, $currbuild);
    unless ( $ok ) { print "FTP Error: $@\n"; }

    #-----------------------------------------------------------------
    # Set Auto update directory
    #-----------------------------------------------------------------

    $ok         = $ftp->cwd($upddir);
    unless ( $ok ) { print "FTP Error: $@\n"; }

    #-----------------------------------------------------------------
    # Set Auto update file
    #-----------------------------------------------------------------

    print "Sending AutoUpdate\n";    
    
    $ok         = $ftp->delete($autodata);
    unless ( $ok ) { print "FTP Error: $@\n"; }

    $ok         = $ftp->put($updfiles."\\".$autodata, $autodata);
    unless ( $ok ) { print "FTP Error: $@\n"; }

    #-----------------------------------------------------------------
    # Set Auto update info file
    #-----------------------------------------------------------------

    print "Sending AutoUpdate Info file \n\n";    

    $ok         = $ftp->delete($autofile);
    unless ( $ok ) { print "FTP Error: $@\n"; }

    $ok         = $ftp->put($updfiles."\\".$autofile, $autofile);
    unless ( $ok ) { print "FTP Error: $@\n"; }

    #-----------------------------------------------------------------
    # End the FTP Session
    #-----------------------------------------------------------------

    $ok         = $ftp->quit;
    unless ( $ok ) { print "FTP Error: $@\n"; }

}


#!perl -w
#---------------------------------------------------------------------------------------------
# Copyright 2002, Evan Harris.  All rights reserved.
# 
# What the program will do:
# BuildAuctionitis
#---------------------------------------------------------------------------------------------

use strict;
use Auctionitis;

my ($ob, $nb);                          # old build number; new build number;

my $tm = Auctionitis->new();

update_current_build_number();

update_VB_build_number();

update_build_script();

update_install_script();

update_build_history();

print "Build: ".$nb."  Build Date: ".$tm->datenow()."  Build Time: ".$tm->timenow()."\n";

print "Done\n";

###############################################################################
#                            S U B R O U T I N E S                            #
###############################################################################

#---------------------------------------------------------------------------------------------
# get the current build file, read the current number into memory, increment
# the number then write it back to the file
#---------------------------------------------------------------------------------------------

sub update_current_build_number {

    my $f       =   "CurrentBuild.txt";                             # current build file
    my $data;                                                       # file data

    local $/;                                                       # slurp mode (undef)
    local *F;                                                       # create local filehandle

    open(F, "< $f\0") || return;                                    

    $data = <F>;                                                    # read whole file

    close(F);                                                       # ignore retval

    $ob = $data;                                                    # old build number

    $data++;                                                        # increment build number
    $data=500;

    $nb = $data;                                                    # new build number

    unlink $f;                                                      # delete build file

    open(F, "> $f") || return;                                      # open file for output

    print F "$data";                                                # write new build number

    close(F);                                                       # ignore retval

    # replace old build number with new build number

    # $data =~ s/($cb)/($nb)/g;


}

#---------------------------------------------------------------------------------------------
# Look for the old build number in the vb file and update with the new one
#---------------------------------------------------------------------------------------------

sub update_VB_build_number {

    my $f       =   "modAuctionitis.bas";                           # current build file
    my $data;                                                       # file data

    local $/;                                                       # slurp mode (undef)
    local *F;                                                       # create local filehandle

    open(F, "< $f\0") || return;                                    

    $data = <F>;                                                    # read whole file

    close(F);                                                       # ignore retval

    $data =~ s/$ob/$nb/g;                                           # replace old build number with new build number

    unlink $f;                                                      # delete build file

    open(F, "> $f") || return;                                      # open file for output

    print F "$data";                                                # write new build number

    close(F);                                                       # ignore retval

}

#---------------------------------------------------------------------------------------------
# Look for the old build number in the build batch file and update with the new one
#---------------------------------------------------------------------------------------------

sub update_build_script {

    my $f       =   "BuildAuctionitis2.bat";                        # current build file
    my $data;                                                       # file data

    local $/;                                                       # slurp mode (undef)
    local *F;                                                       # create local filehandle

    open(F, "< $f\0") || return;                                    

    $data = <F>;                                                    # read whole file

    close(F);                                                       # ignore retval

    $data =~ s/$ob/$nb/g;                                           # replace old build number with new build number

    unlink $f;                                                      # delete build file

    open(F, "> $f") || return;                                      # open file for output

    print F "$data";                                                # write new build number

    close(F);                                                       # ignore retval


}

#---------------------------------------------------------------------------------------------
# Look for the old build number in the beta update file and update with the new one
#---------------------------------------------------------------------------------------------

sub update_install_script {

    my $f       =   "Auctionitis-2.0.0-Beta-Update.iss";            # current build file
    my $data;                                                       # file data

    local $/;                                                       # slurp mode (undef)
    local *F;                                                       # create local filehandle

    open(F, "< $f\0") || return;                                    

    $data = <F>;                                                    # read whole file

    close(F);                                                       # ignore retval

    $data =~ s/$ob/$nb/g;                                           # replace old build number with new build number

    unlink $f;                                                      # delete build file

    open(F, "> $f") || return;                                      # open file for output

    print F "$data";                                                # write new build number

    close(F);                                                       # ignore retval

}

#---------------------------------------------------------------------------------------------
# Update the build history text file
#---------------------------------------------------------------------------------------------

sub update_build_history {

    my $f       =   "BuildHistory.txt";                             # current build file
    my $data;                                                       # file data

    local $/;                                                       # slurp mode (undef)
    local *F;                                                       # create local filehandle

    open(F, "< $f\0") || return;                                    

    $data = <F>;                                                    # read whole file

    close(F);                                                       # ignore retval

#      ***             LATEST BUILD: 0044 AS AT 19:52:21 09-08-2005                ***  

    my $newstring = "***             LATEST BUILD: $nb AS AT ".$tm->timenow()." ".$tm->datenow()."                ***";
    
    $data =~ s/^.+?LATEST BUILD.+?$/$newstring/mg;

    unlink $f;                                                      # delete build file

    open(F, "> $f") || return;                                      # open file for output

    print F "$data";                                                # write new build number
    
    print F "-> Build: ".$nb."  Build Date: ".$tm->datenow()."  Build Time: ".$tm->timenow()."\n";

    close(F);                                                       # ignore retval

}

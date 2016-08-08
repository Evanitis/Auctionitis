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
update_agent_number();
update_TMLoader();
update_AuctionTray();
update_JobHandler();
update_SetDBProperty();
update_GetDBProperty();
update_CreateAuctionitisINI();
update_VB_build_number();
update_this_release_doc();
update_build_script();
update_install_script();
update_build_history();

print "Build: ".$nb."  Build Date: ".$tm->datenow()."  Build Time: ".$tm->timenow()."\n";

print "Updated scripts with details of New Build ".$nb."\n";

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

    $nb = $data;                                                    # new build number

    unlink $f;                                                      # delete build file

    open(F, "> $f") || return;                                      # open file for output

    print F "$data";                                                # write new build number

    close(F);                                                       # ignore retval

    # replace old build number with new build number

    # $data =~ s/($cb)/($nb)/g;


}

#---------------------------------------------------------------------------------------------
# Look for the old build number in the TMLoader Project file and update with the new one
#---------------------------------------------------------------------------------------------

sub update_TMLoader {

    my $f       =   "TMLoader.perlctrl";                            # current build file
    my $data;                                                       # file data

    local $/;                                                       # slurp mode (undef)
    local *F;                                                       # create local filehandle

    open(F, "< $f\0") || return;                                    

    $data = <F>;                                                    # read whole file

    close(F);                                                       # ignore retval

    my $oldstr = "Version-FileVersion: 2.1.0.$ob";
    my $newstr = "Version-FileVersion: 2.1.0.$nb";

    $data =~ s/$oldstr/$newstr/g;                                   # replace old build number with new build number

    $oldstr = "Version-ProductVersion: 2.1.0.$ob";
    $newstr = "Version-ProductVersion: 2.1.0.$nb";

    $data =~ s/$oldstr/$newstr/g;                                   # replace old build number with new build number

    unlink $f;                                                      # delete build file

    open(F, "> $f") || return;                                      # open file for output

    print F "$data";                                                # write new build number

    close(F);                                                       # ignore retval

}

#---------------------------------------------------------------------------------------------
# Look for the old build number in the AuctionTray project file and update with the new one
#---------------------------------------------------------------------------------------------

sub update_AuctionTray {

    my $f       =   "AuctionTray.perltray";                         # current build file
    my $data;                                                       # file data

    local $/;                                                       # slurp mode (undef)
    local *F;                                                       # create local filehandle

    open(F, "< $f\0") || return;                                    

    $data = <F>;                                                    # read whole file

    close(F);                                                       # ignore retval

    my $oldstr = "Version-FileVersion: 1.0.0.$ob";
    my $newstr = "Version-FileVersion: 1.0.0.$nb";

    $data =~ s/$oldstr/$newstr/g;                                   # replace old build number with new build number

    $oldstr = "Version-ProductVersion: 1.0.0.$ob";
    $newstr = "Version-ProductVersion: 1.0.0.$nb";

    $data =~ s/$oldstr/$newstr/g;                                   # replace old build number with new build number

    unlink $f;                                                      # delete build file

    open(F, "> $f") || return;                                      # open file for output

    print F "$data";                                                # write new build number

    close(F);                                                       # ignore retval

}

#---------------------------------------------------------------------------------------------
# Look for the old build number in the JobHandler project file and update with the new one
#---------------------------------------------------------------------------------------------

sub update_JobHandler {

    my $f       =   "JobHandler.perlapp";                           # current build file
    my $data;                                                       # file data

    local $/;                                                       # slurp mode (undef)
    local *F;                                                       # create local filehandle

    open(F, "< $f\0") || return;                                    

    $data = <F>;                                                    # read whole file

    close(F);                                                       # ignore retval

    my $oldstr = "Version-FileVersion: 1.0.0.$ob";
    my $newstr = "Version-FileVersion: 1.0.0.$nb";

    $data =~ s/$oldstr/$newstr/g;                                   # replace old build number with new build number

    $oldstr = "Version-ProductVersion: 1.0.0.$ob";
    $newstr = "Version-ProductVersion: 1.0.0.$nb";

    $data =~ s/$oldstr/$newstr/g;                                   # replace old build number with new build number

    unlink $f;                                                      # delete build file

    open(F, "> $f") || return;                                      # open file for output

    print F "$data";                                                # write new build number

    close(F);                                                       # ignore retval

}

#---------------------------------------------------------------------------------------------
# Look for the old build number in the GetDBProperty project file and update with the new one
#---------------------------------------------------------------------------------------------

sub update_GetDBProperty {

    my $f       =   "GetDProperty.perlapp";                         # current build file
    my $data;                                                       # file data

    local $/;                                                       # slurp mode (undef)
    local *F;                                                       # create local filehandle

    open(F, "< $f\0") || return;                                    

    $data = <F>;                                                    # read whole file

    close(F);                                                       # ignore retval

    my $oldstr = "Version-FileVersion: 1.0.0.$ob";
    my $newstr = "Version-FileVersion: 1.0.0.$nb";

    $data =~ s/$oldstr/$newstr/g;                                   # replace old build number with new build number

    $oldstr = "Version-ProductVersion: 1.0.0.$ob";
    $newstr = "Version-ProductVersion: 1.0.0.$nb";

    $data =~ s/$oldstr/$newstr/g;                                   # replace old build number with new build number

    unlink $f;                                                      # delete build file

    open(F, "> $f") || return;                                      # open file for output

    print F "$data";                                                # write new build number

    close(F);                                                       # ignore retval

}

#---------------------------------------------------------------------------------------------
# Look for the old build number in the SetDBProperty project file and update with the new one
#---------------------------------------------------------------------------------------------

sub update_SetDBProperty {

    my $f       =   "SetDBProperty.perlapp";                        # current build file
    my $data;                                                       # file data

    local $/;                                                       # slurp mode (undef)
    local *F;                                                       # create local filehandle

    open(F, "< $f\0") || return;                                    

    $data = <F>;                                                    # read whole file

    close(F);                                                       # ignore retval

    my $oldstr = "Version-FileVersion: 1.0.0.$ob";
    my $newstr = "Version-FileVersion: 1.0.0.$nb";

    $data =~ s/$oldstr/$newstr/g;                                   # replace old build number with new build number

    $oldstr = "Version-ProductVersion: 1.0.0.$ob";
    $newstr = "Version-ProductVersion: 1.0.0.$nb";

    $data =~ s/$oldstr/$newstr/g;                                   # replace old build number with new build number

    unlink $f;                                                      # delete build file

    open(F, "> $f") || return;                                      # open file for output

    print F "$data";                                                # write new build number

    close(F);                                                       # ignore retval

}

#---------------------------------------------------------------------------------------------
# Update CreateAuctionitisINI project file with new build number
#---------------------------------------------------------------------------------------------

sub update_CreateAuctionitisINI {

    my $f       =   "CreateAuctionitisINI.perlapp";                 # current build file
    my $data;                                                       # file data

    local $/;                                                       # slurp mode (undef)
    local *F;                                                       # create local filehandle

    open(F, "< $f\0") || return;                                    

    $data = <F>;                                                    # read whole file

    close(F);                                                       # ignore retval

    my $oldstr = "Version-FileVersion: 1.0.0.$ob";
    my $newstr = "Version-FileVersion: 1.0.0.$nb";

    $data =~ s/$oldstr/$newstr/g;                                   # replace old build number with new build number

    $oldstr = "Version-ProductVersion: 1.0.0.$ob";
    $newstr = "Version-ProductVersion: 1.0.0.$nb";

    $data =~ s/$oldstr/$newstr/g;                                   # replace old build number with new build number

    unlink $f;                                                      # delete build file

    open(F, "> $f") || return;                                      # open file for output

    print F "$data";                                                # write new build number

    close(F);                                                       # ignore retval

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

    my $oldstr = "Public Const BuildNumber As String = \"$ob\"";
    my $newstr = "Public Const BuildNumber As String = \"$nb\"";

    $data =~ s/$oldstr/$newstr/g;                                   # replace old build number with new build number

    unlink $f;                                                      # delete build file

    open(F, "> $f") || return;                                      # open file for output

    print F "$data";                                                # write new build number

    close(F);                                                       # ignore retval

}

#---------------------------------------------------------------------------------------------
# Update the Build number in the Auctionitis User Agent string
#---------------------------------------------------------------------------------------------

sub update_agent_number {

    my $f = "c://evan//lib//Auctionitis.pm";                        # current base library
    my $data;                                                       # file data

    local $/;                                                       # slurp mode (undef)
    local *F;                                                       # create local filehandle

    open(F, "< $f\0") || return;                                    

    $data = <F>;                                                    # read whole file

    close(F);                                                       # ignore retval

    my $oldstr = "\"Auctionitis\/V4.0.$ob\"";
    my $newstr = "\"Auctionitis\/V4.0.$nb\"";;

    $data =~ s/$oldstr/$newstr/g;                                   # replace old build number with new build number

    unlink $f;                                                      # delete build file

    open(F, "> $f") || return;                                      # open file for output

    print F "$data";                                                # write new build number

    close(F);                                                       # ignore retval

}


#---------------------------------------------------------------------------------------------
# Update the Build number in the "This release" readme document
#---------------------------------------------------------------------------------------------

sub update_this_release_doc {

    my $f = "c://evan//auctionitis103//ReadMe - this release.txt";  # current base library
    my $data;                                                       # file data

    local $/;                                                       # slurp mode (undef)
    local *F;                                                       # create local filehandle

    open(F, "< $f\0") || return;                                    

    $data = <F>;                                                    # read whole file

    close(F);                                                       # ignore retval

    my $oldstr = "Build $ob";
    my $newstr = "Build $nb";

    $data =~ s/$oldstr/$newstr/g;                                   # replace old build number with new build number

    unlink $f;                                                      # delete build file

    open(F, "> $f") || return;                                      # open file for output

    print F "$data";                                                # write new build number

    close(F);                                                       # ignore retval

}

#---------------------------------------------------------------------------------------------
# Look for the old build number in the build batch file and update with the new one
#---------------------------------------------------------------------------------------------

sub update_build_script {

    my $f = "./QSetup-Installer/Install-Package.qsp";               # current build file
    my $data;                                                       # file data

    local $/;                                                       # slurp mode (undef)
    local *F;                                                       # create local filehandle

    open(F, "< $f\0") || return;                                    

    $data = <F>;                                                    # read whole file

    close(F);                                                       # ignore retval
    
    my $oldstr = "Build $ob";
    my $newstr = "Build $nb";

    $data =~ s/$oldstr/$newstr/g;                                   # replace old build number with new build number

    unlink $f;                                                      # delete build file

    open(F, "> $f") || return;                                      # open file for output

    print F "$data";                                                # write new build number

    close(F);                                                       # ignore retval


}

#---------------------------------------------------------------------------------------------
# Look for the old build number in the beta update file and update with the new one
#---------------------------------------------------------------------------------------------

sub update_install_script {

    my $f = "./QSetup-Updater/Upgrade-Package.qsp";                 # current build file
    my $data;                                                       # file data

    local $/;                                                       # slurp mode (undef)
    local *F;                                                       # create local filehandle

    open(F, "< $f\0") || return;                                    

    $data = <F>;                                                    # read whole file

    close(F);                                                       # ignore retval

    my $oldstr = "Build $ob";
    my $newstr = "Build $nb";

    $data =~ s/$oldstr/$newstr/g;                                   # replace old build number with new build number

    $oldstr = "VersionNew=$ob";
    $newstr = "VersionNew=$nb";

    $data =~ s/$oldstr/$newstr/g;                                   # replace old build number with new build number

    unlink $f;                                                      # delete build file

    open(F, "> $f") || return;                                      # open file for output

    print F "$data";                                                # write new build number

    close(F);                                                       # ignore retval

}

#---------------------------------------------------------------------------------------------
# Update the build history text file
#---------------------------------------------------------------------------------------------

sub update_build_history {

    my $f = "BuildHistory.txt";                                     # current build file
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

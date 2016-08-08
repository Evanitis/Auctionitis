#!/usr/bin/perl
#
#  This is a sample perl script for demonstrating the control
#   of Anzio features from the host end. These short example scripts
#   can be translated easily in to shell scripts or included in C
#   or Java programs. These are meant as examples only and no warranty
#   is made as to the functionality.
#
#  Commands can be sent to Anzio Lite and AnzioWin by inclusion of
#   an Anzio command within a  /034 and /035. This program demonstrates
#   this capability in numerous examples.
#
# Program:   anziosample.pl
# Format:    [option] filename 
# Option:	   putftp   (put file on host)
#	  	   getftp   (get file from host)
#		   putzm    (put file on host)
#		   getzm    (get file from host)
#		   putkerm  (put file on host)
#		   getkerm  (get file from host)
#		   web      (start PC browser)
#		   cs132    (change to 132 col)
#		   cs80     (change to 80 col)
#		   chpr     (choose printer)
#		   clone    (clone a new session)
#		   capprint (capture and print)
#		   pprint   (passthrough print)
#		   start    (transfer & start a file)
#		   info     (show PC info)			
#		   img      (move and show an image)
#		   pscreen  (print screen)
#		   wintitle (set Anzio's window title)
#		   sound    (play a wave file)
#		   scrape   (do screen scrape to file)
#  
# 3 May 2001 -- Assumes perl at above location and bash as shell on 
#		Linux 7.0. Also assumes vt terminal type for this example.
#

###### Constants ######
$begCMD  = "\034";			# Start a command for Anzio
$endCMD  = "\035";			# End a command for Anzio
$cs132   = "\033[?3h";	 	       	# This may vary by term type, try 
$cs80    = "\033[?3l";			#  it in zoomed and not-zoomed
$ptON    = "\033[5i";	  		# Passthrough print on
$ptOFF   = "\033[4i";	   	 	# Passthrough print off
$quote   = '"';
$ftphost = "ftp.host.com";		# Must code a host, username,
$ftpuser = "username";			#  and password for Anzio Lite
$ftppass = "password";			#  to use MS ftp.
$TempFile = "fstemp";
$Temp    = ">$TempFile";

###### Initialize ######
print "$begCMD env/s ANZ_PROGRAM$endCMD"; # Get the Anzio program name
$anzioprogram = <STDIN>;
#chop $anzioprogram; commented out by evan.....

if ($anzioprogram ne "ANZIOLITE") {	  # Turn on quiet if available to
  print "$begCMD receive quiet $endCMD";  #  suppress misc displays
}

print "$begCMD env/s ANZ_DOWNDIR$endCMD"; # Get the download dir
$downdir = <STDIN>;
chop $downdir;

print "$begCMD env/s ANZ_CURDIR$endCMD";  # Get the current directory
$curdir = <STDIN>;
chop $curdir;

# system clear;				# Clear screen and give header commented out by evan
print "Rasmussen Software Sample Scripts\n";
print "\n";

print "$begCMD version/s $endCMD";	# Get Anzio version 
$anzioversion = <STDIN>;

$option = shift(@ARGV);			# Extract option and filename
$filename = $ARGV[0]; 
print "Command line: $option $filename\n";


###### Main ######

if ($option eq "putftp") {	&putftp;
  }
if ($option eq "getftp") {	&getftp;
  }
if ($option eq "putzm")  {	&putzm;
  }
if ($option eq "getzm")  {	&getzm;
  }
if ($option eq "putkerm") {	&putkerm;
  }
if ($option eq "getkerm") {	&getkerm;
  }
if ($option eq "clone") {	&clone;
  }
if ($option eq "cs132") {	&cs132;
  }
if ($option eq "cs80") {	&cs80;
  }
if ($option eq "web") {		&web;
  }
if ($option eq "chpr") {	&chpr;
  }
if ($option eq "capprint") {	&capprint;
  }
if ($option eq "pprint") {	&pprint;
  }
if ($option eq "start") {	&start;
  }
if ($option eq "info") {	&info;
  }
if ($option eq "img") {		&img;
  }
if ($option eq "pscreen") {	&pscreen;
  }
if ($option eq "wintitle") {	&wintitle;
  }
if ($option eq "sound") {	&sound;
  }
if ($option eq "scrape") {	&scrape;
  }


###### Cleanup & Conclude ######
if ($anzioprogram ne "ANZIOLITE") {	# Reset receive quiet
  print "$begCMD receive quiet off $endCMD";
}

exit;


###### Subroutines ######

sub putftp {
  # Put <filename> on the host using AnzioWin ftpput. If running
  # Anzio Lite, use the DOS ftp with a script file (making this much 
  # more complicated).
  
  if ($anzioprogram eq "ANZIOLITE") {
    # First create a script file for Windows default ftp
    # and then run with it. This assumes a host, user and password
    # constant are set. By the way, this seems "dumb" because we do a
    # zmodem to set the script file. We could also do a capture or have
    # the script file already present. Also this is useful if the transfer
    # is from a different host than you are logged in to.
    open (TF, $Temp) || die "Can't open temp file";
    print TF "open $ftphost\r\n"; 
    print TF "$ftpuser\r\n";
    print TF "$ftppass\r\n";
    print TF "bi\r\n"; 
    print TF "ha\r\n";
    print TF "put $filename testfile\r\n"; 
    print TF "quit\r\n";
    close TF;
    # Transfer this script using zmodem
    system "sz $TempFile";
    # Now run the script
    print "$begCMD winstart ftp -s:$downdir\\$TempFile $endCMD";
  } else {
    # This assumes that a username and password are set in Anzio (see the
    # "login" menu item under the Communicate menu). Always goes to
    # users default directory.
    print "$begCMD ftpput $filename $endCMD";
  }

}

sub getftp {
  # Get <filename> from the host using AnzioWin ftpget. If running
  # Anzio Lite, use the DOS ftp with a script file.

  if ($anzioprogram eq "ANZIOLITE") {
    # See notes above on Anzio Lite and putftp...
    open (TF, $Temp) || die "Can't open temp file";
    print TF "open $ftphost\r\n";
    print TF "$ftpuser\r\n";
    print TF "$ftppass\r\n";
    print TF "bi\r\n";
    print TF "ha\r\n";
    print TF "get $filename\r\n";
    print TF "quit\r\n";
    close TF;
    # Transfer the script using zmodem
    system "sz $TempFile";
    # Now run the script
    print "$begCMD winstart ftp -s:$downdir\\$TempFile $endCMD";
  } else {
    # This assumes that a username and password are set (see the
    # "login" menu item under the Communicate menu). This assumes
    # the users default directory unless you specify otherwise in
    # the $filename.
    print "$begCMD ftpget $filename $endCMD";
  }

}

sub putzm {
  # Put <filename> on the host using zsend.
  print "$begCMD zsend $filename $endCMD";
}

sub getzm {
  # Get <filename> from the host using zreceive. For this
  # example we assume zmodem auto receive is on.
  system "sz $filename";
}

sub putkerm {
  # Put <filename> on the host using ksend.
  print "$begCMD ksend $filename $endCMD";
}

sub getkerm {
  # Get <filename> from the host using kreceive. For kermit to
  # work properly, kermit needs to start the kreceive. This can
  # be done by embedding a separate file inside the kermit command, 
  # though it takes som monkeying around to get it to work through perl.
  # It does not work to simply run the command in the string because
  # kermit will not handle the printf - so use a separate file, i.e
  # kr.bash (printf "\034kreceive as $1 replace\035 \n").
  #
  #$k1 = 'set file names literal, !kr.bash, send $filename, quit';
  #system 'kermit -C $k1';
  #
  # - for this example, we assume auto-receive is on and simply do it.
  system "kermit -s $filename";
}

sub clone {
  # Clone a new session
  print "$begCMD clone $endCMD";	
}

sub cs132 {
  # Change the screen size to 132 columns on the fly
  print $cs132;
}

sub cs80 {
  # Change the screen size to 80 columns on the fly
  print $cs80;
}

sub web {
  # Start the web browser using filename as argument
  # File name should start with 'http://'. If not you may
  # want to force it in this script.
  print "$begCMD winstart $filename $endCMD";
}

sub chpr {
  # Force user to choose printer
  print "$begCMD chooseprinter$endCMD";
}

sub capprint {
  # Turn on capture to printer, cat the file, turn off capture
  print "$begCMD capture WPRN $endCMD";
  system "cat $filename"; ## ###
  print "$begCMD capture off $endCMD";
}

sub pprint {
  # Use standard passthrough print to print file
  print $ptON;
  system "cat $filename";  ## ###
  print $ptOFF;  
}

sub start {
  # Transfer a file to the PC and then start it
  getzm;
  # Assume zm puts file in download dir
  print "$begCMD winstart $downdir\\$filename $endCMD";
}

sub info {
  # Grab and show information about the PC
  print "\n";
  print "PC is running $anzioprogram VERSION $anzioversion\n";
  print "PC Download directory:  $downdir\n";
  print "   Current directory:   $curdir\n";
    
  print "$begCMD env/s ANZ_TITLE$endCMD";     	# Get Windows title
  $wintitle = <STDIN>;
  print "   Anzio window title:  $wintitle";
  print "$begCMD env/s ANZ_COMPUTERNAME$endCMD";# Get PC Name
  $pcname = <STDIN>;
  print "   Computer name:       $pcname";
  print "$begCMD env/s ANZ_IP$endCMD";     	# Get PC ip
  $pcip = <STDIN>;
  print "   IP address:          $pcip";
  print "$begCMD env/s ANZ_HOSTNAME$endCMD";    # Get hostname
  $hostname = <STDIN>;
  print "   Hostname logged to:  $hostname";
  print "$begCMD env/s ANZ_TCPNAME$endCMD";     # Get Windows TCP/IP
  $pctcp = <STDIN>;
  print "   Window TCP name:     $pctcp";
  print "$begCMD env/s ANZ_WINNAME$endCMD";     # Get Windows Logged User
  $winname = <STDIN>;
  print "   Window username:     $winname";
  print "$begCMD env/s ANZ_USERNAME$endCMD";  # Get Anzio params username
  $anzname = <STDIN>;
  print "   Anzio username:      $anzname";
  print "$begCMD env/s ANZ_WINDIR$endCMD";     	# Get Windows Dir
  $windir = <STDIN>;
  print "   Window directory:    $windir";
  print "$begCMD env/s ANZ_SYSDIR$endCMD";     	# Get System Dir
  $sysdir = <STDIN>;
  print "   System directory:    $sysdir";
  print "$begCMD env/s ANZ_LAST_LAUNCH$endCMD"; # Get last prog launched
  $lastlaunch = <STDIN>;
  print "   Last launched:       $lastlaunch";
  print "$begCMD env/s ANZ_LAST_RECD$endCMD";  # Get last file recvd
  $lastrecv = <STDIN>;
  print "   Last file recvd:     $lastrecv";

}

sub img {
  # move an image and then show it in the AnzioWin window
  if ($anzioprogram eq "ANZIOWIN") {
    if ($filename ne "off") {
      getzm;    
    }
    print "$begCMD bmp $downdir\\$filename 300 100 0 0 $endCMD";
  }
}

sub pscreen {
  # print the screen
  print "$begCMD printer WPRN$endCMD";   # Need to force it to use
		  		         #  Windows drivers
  print "$begCMD print $endCMD";   
}

sub wintitle {
  # change the Anzio window title
  print "$begCMD title A test window title $endCMD";
}

sub sound {
  # play a Windows wave file
  print "$begCMD playsound c:\\windows\\media\\exclamation.wav$endCMD";
}

sub scrape {
  # scrape screen to file and move to host
  if ($anzioprogram eq "ANZIOLITE" ){
    print "$begCMD Not available in Anzio Lite.$endCMD";
  } else {
    if ($filename ne "") {
      print "$begCMD Openo/n $downdir\\$filename $endCMD";
      # could do keep with screen params to scrape only a certain
      #area
      print "$begCMD keep $endCMD";
      print "$begCMD closeo $endCMD";
      print "$begCMD zsend $downdir\\$filename $endCMD";
      # you could now do something with the file, either at
      # the host or on the PC.
    }
  }
}

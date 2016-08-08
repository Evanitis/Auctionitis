#!perl -w
#---------------------------------------------------------------------------------------------
# Copyright 2002, Evan Harris.  All rights reserved.
# 
# What the program will do:
# This program updates the remapped categories with the category path name
#---------------------------------------------------------------------------------------------

use strict;
use LWP::UserAgent;
use MIME::Lite;
use Net::SMTP;
use CGI;
use Net::FTP;
use HTTP::Request;
use HTTP::Response;
use HTTP::Cookies;
use HTTP::Request::Common qw(POST);
use DBI;

# HTTP request processing variables

my ($ua, $url, $req, $response, $content);

# database request processing variables

my ($f1, $SQLStmt, $dbh, $sth, @parent, $inputdata, $fullname, $currentcat, $current_service_date);

# todays date for processing and archiving database changes

# my $today = today();

initialise();

print "CSD: $current_service_date\n";

update_remapper();

print_remapdata();

crt_control_html();

crt_remap_html();

crt_table_html();

transmit_html();

print "Done\n";

###############################################################################
#                            S U B R O U T I N E S                            #
###############################################################################


sub initialise {

    $dbh=DBI->connect('dbi:ODBC:CategoryDB') || die "Error opening Auctions database: $DBI::errstr\n";

    set_current_service_date();
    
#    open $f1, "> c:\\evan\\Auctionitis Categories\\Remapped categories ".$current_service_date.".txt";
    open $f1, "> c:\\evan\\Auctionitis103\\Data\\Remapped categories ".$current_service_date.".txt";

}

sub set_current_service_date {

    # Load all the service history records into the service dates referenced hash

    $SQLStmt = "SELECT * FROM CategoryServiceDates";
    $sth     = $dbh->prepare($SQLStmt)|| die "Error preparing statement: $DBI::errstr\n";
    $sth->execute() || die "Error executing statement: $DBI::errstr\n";
    my $servicedates = $sth->fetchall_arrayref({});

    # read through the service dates array to get the most recent service date
    # reverse the date for each auction  and if greater than previous date overwrite current service date value
 
    $current_service_date = "01-01-1900";
 
    foreach my $record (@$servicedates) {
        print "Retrieved service date: $record->{ CategoryServiceDate } \n";
        my $revdate1 = substr( $record->{ CategoryServiceDate },6,4 ) * 10000 +
                       substr( $record->{ CategoryServiceDate },3,2 ) * 100 +
                       substr( $record->{ CategoryServiceDate },0,2 );
                      
        my $revdate2 = substr( $current_service_date,6,4 ) * 10000 +
                       substr( $current_service_date,3,2 ) * 100 +
                       substr( $current_service_date,0,2 );
                      
        if ( $revdate2 < $revdate1 ) { $current_service_date = $record->{ CategoryServiceDate }; }
    }
}

sub update_remapper {

    # Get all records from the the category remapper file
    
    $SQLStmt = "SELECT NewCategory FROM CategoryRemapper";
    $sth = $dbh->prepare($SQLStmt)|| die "Error preparing statement: $DBI::errstr\n";
    $sth->execute() || die "Error executing statement: $DBI::errstr\n";

    # Update category remapper records with text of remapped path
    # Use the New category data to build the "path" to the new category
    # strip out the " >" from the lower level categories 
    
    $inputdata = $sth->fetchall_arrayref();

    $SQLStmt = "UPDATE CategoryRemapper SET NEWCategoryText = ? WHERE NewCategory = ?";
    $sth = $dbh->prepare($SQLStmt)|| die "Error preparing statement: $DBI::errstr\n";
    
    # foreach my $category (@$inputdata) {
    #      $sth->execute($category->[0])
    # }
            
    foreach my $category (@$inputdata) {
    
        my $currentcat = $category->[0];
        my $fullname = "";
        while (hasparent($currentcat)) {
              my @parent = getcategory($currentcat);
              @parent->[2] =~ s/(.+?)(\s+>)/$1/;
              if ($fullname eq "")  {$fullname = @parent->[2];}
              else                  {$fullname = @parent->[2]."/".$fullname;}
              $currentcat = @parent->[0]
        }
        $sth->execute($fullname, $category->[0]);
    }
}

# Subroutine to create remapped category output for readme doc and installer file

sub print_remapdata {

    # get the data from the remapper file
    
    my $sth = $dbh->prepare("SELECT * FROM CategoryRemapper")|| die "Error preparing statement: $DBI::errstr\n";
    $sth->execute() || die "Error exexecuting statement: $DBI::errstr\n";
    $inputdata = $sth->fetchall_arrayref();

    # output the update for use in the category update readme file

    print $f1 "==============================================================================\n";
    print $f1 " TradeMe Category changes: ".$current_service_date."             [Created by Auctionitis]\n";
    print $f1 "==============================================================================\n";
    print $f1 "\n";

    foreach my $record (@$inputdata) {
        print $f1 " $record->[1]\t-> $record->[3] \n";
    }

    # output the instructions for category updates to add into the installer update

    print $f1 "\n";
    print $f1 "------------------------------------------------------------------------------\n";
    print $f1 "Inno Installer category conversion instructions\n";
    print $f1 "------------------------------------------------------------------------------\n";
    print $f1 "\n";

    print $f1 ";\n";
    print $f1 "; Conversions for categories dropped on ".$current_service_date."\n";
    print $f1 ";\n";
    
    foreach my $record (@$inputdata) {
        print $f1 "Filename: {app}\\convertdroppedcategories.exe; Parameters: ".$record->[0]." ".$record->[2]."; WorkingDir: {app}; StatusMsg: Converting: ".$record->[1]."; Flags: waituntilidle; Tasks: Update_".$current_service_date."\n";
    }

}

# Create control lookup header for category updates

sub crt_control_html {

#    open my $x1, "> c:\\evan\\Auctionitis Categories\\category_control.html";
#    open my $x2, "> c:\\evan\\Auctionitis Categories\\category_control ".$current_service_date.".html";

    open my $x1, "> c:\\evan\\Auctionitis103\\Data\\category_control.html";
    open my $x2, "> c:\\evan\\Auctionitis103\\Data\\category_control ".$current_service_date.".html";

    print $x1 "<HTML><HEAD><TITLE>Category Update Control Data</TITLE></HEAD><BODY>\n";
    print $x2 "<HTML><HEAD><TITLE>Category Update Control Data</TITLE></HEAD><BODY>\n";
    print $x1 "<META HTTP-EQUIV=\"pragma\" CONTENT=\"no-cache\">\n";
    print $x2 "<META HTTP-EQUIV=\"pragma\" CONTENT=\"no-cache\">\n";
    print $x1 "<META HTTP-EQUIV=\"Cache-Control\" CONTENT=\"no-cache\">\n";
    print $x2 "<META HTTP-EQUIV=\"Cache-Control\" CONTENT=\"no-cache\">\n";
    print $x1 "<META HTTP-EQUIV=\"Expires\" CONTENT=\"-1\">\n";
    print $x2 "<META HTTP-EQUIV=\"Expires\" CONTENT=\"-1\">\n";
    
    $dbh=DBI->connect('dbi:ODBC:CategoryDB') || die "Error opening Auctions database: $DBI::errstr\n";
    
    # Load all the service history records into the service dates referenced hash

    $SQLStmt = "SELECT * FROM CategoryServiceDates";
    $sth     = $dbh->prepare($SQLStmt)|| die "Error preparing statement: $DBI::errstr\n";
    $sth->execute() || die "Error executing statement: $DBI::errstr\n";
    my $servicedates = $sth->fetchall_arrayref({});

    # Load all the category records into the categories referenced hash

    $SQLStmt = "SELECT * FROM TMCategories";
    $sth     = $dbh->prepare($SQLStmt)|| die "Error preparing statement: $DBI::errstr\n";
    $sth->execute() || die "Error executing statement: $DBI::errstr\n";

    my $categories = $sth->fetchall_arrayref({});

    # Read through the categories array and calculate the checksum value for the categories table
    # This is the sum of all the category values and is used to check the integrity of the client category table
 
    my $category_checksum = 0;
 
    foreach my $record (@$categories) {
       $category_checksum = $category_checksum + $record->{ Category }        
    }

    print $x1 "<H2>Service Information Control Data</H2>\n";
    print $x2 "<H2>Service Information Control Data</H2>\n";

    print $x1 "<BR><TABLE>\n";
    print $x2 "<BR><TABLE>\n";
    
    print $x1 "<TR><TD>Current Service Date</TD><TD>$current_service_date</TD></TR>\n";
    print $x2 "<TR><TD>Current Service Date</TD><TD>$current_service_date</TD></TR>\n";

    print $x1 "<TR><TD>Current Version</TD><TD>2.00</TD></TR>\n";
    print $x2 "<TR><TD>Current Version</TD><TD>2.00</TD></TR>\n";

    print $x1 "<TR><TD>Category Checksum</TD><TD>$category_checksum</TD></TR>\n";
    print $x2 "<TR><TD>Category Checksum</TD><TD>$category_checksum</TD></TR>\n";

    print $x1 "</TABLE>\n";
    print $x2 "</TABLE>\n";

    print $x1 "<BR><TABLE><TR><TD>Service History Reference Table</TD></TR>\n";
    print $x2 "<BR><TABLE><TR><TD>Service History Reference Table</TD></TR>\n";
           
    foreach my $record (@$servicedates) {

        print $x1 "<TR><TD>Service Date</TD>";
        print $x1 "<TD>$record->{ CategoryServiceDate }</TD>";
        print $x1 "<TD>http://www.auctionitis.web-haven.net/auctionitis/service/Category_Update_$record->{ CategoryServiceDate }.html</TD></TR>\n";

        print $x2 "<TR><TD>Service Date</TD>";
        print $x2 "<TD>$record->{ CategoryServiceDate }</TD>";
        print $x2 "<TD>http://www.auctionitis.web-haven.net/auctionitis/service/Category_Update_$record->{ CategoryServiceDate }.html</TD></TR>\n";
    }

    print $x1 "</TABLE>\n";
    print $x2 "</TABLE>\n";

    
    # Close the Category Service Control XML document

    print $x1 "</BODY></HTML>\n";
    print $x2 "</BODY></HTML>\n";
    
    close $x1;
    close $x2;
}

# Create category rempapping document

sub crt_remap_html {

#    open my $x1, "> c:\\evan\\Auctionitis Categories\\Category_Update_".$current_service_date.".html";
    open my $x1, "> c:\\evan\\Auctionitis103\\Data\\Category_Update_".$current_service_date.".html";

    # Get all records from the the category remapper file
    
    $SQLStmt = "SELECT * FROM CategoryRemapper";
    $sth = $dbh->prepare($SQLStmt)|| die "Error preparing statement: $DBI::errstr\n";
    $sth->execute() || die "Error executing statement: $DBI::errstr\n";
    
    my $mapdata = $sth->fetchall_arrayref({});
    
    # Write the Category Service Control XML data header

    print $x1 "<HTML><HEAD><TITLE>Category Service Update ".$current_service_date."</TITLE></HEAD><BODY>\n";

    print $x1 "<META HTTP-EQUIV=\"pragma\" CONTENT=\"no-cache\">\n";
    print $x1 "<META HTTP-EQUIV=\"Cache-Control\" CONTENT=\"no-cache\">\n";
    print $x1 "<META HTTP-EQUIV=\"Expires\" CONTENT=\"-1\">\n";

    # Write service date into document
    
    print $x1 "<H2>Category Remapping data for $current_service_date</H2><BR>\n";

    print $x1 "<TABLE>\n";

    # Specify category Rempapping data

    foreach my $record (@$mapdata) {

        print $x1 "<TR>";
        print $x1 "<TD>$record->{ OldCategoryText   }</TD>";
        print $x1 "<TD>$record->{ OldCategory       }</TD>";
        print $x1 "<TD>$record->{ NewCategory       }</TD>";
        print $x1 "</TR>\n";
    }

    print $x1 "</TABLE>\n";

    # Close the Category Update XML document

    print $x1 "</BODY></HTML>\n";
    close $x1;
}

# Create category data table

sub crt_table_html {

#    open my $x1, "> c:\\evan\\Auctionitis Categories\\category_data.html";
#    open my $x2, "> c:\\evan\\Auctionitis Categories\\category_data ".$current_service_date.".html";

    open my $x1, "> c:\\evan\\Auctionitis103\\data\\category_data.html";
    open my $x2, "> c:\\evan\\Auctionitis103\\data\\category_data ".$current_service_date.".html";

    print $x1 "<HTML><HEAD><TITLE>Auctionitis Category Data</TITLE></HEAD><BODY>\n";
    print $x2 "<HTML><HEAD><TITLE>Auctionitis Category  Data</TITLE></HEAD><BODY>\n";
    
    print $x1 "<META HTTP-EQUIV=\"pragma\" CONTENT=\"no-cache\">\n";
    print $x2 "<META HTTP-EQUIV=\"pragma\" CONTENT=\"no-cache\">\n";
    print $x1 "<META HTTP-EQUIV=\"Cache-Control\" CONTENT=\"no-cache\">\n";
    print $x2 "<META HTTP-EQUIV=\"Cache-Control\" CONTENT=\"no-cache\">\n";
    print $x1 "<META HTTP-EQUIV=\"Expires\" CONTENT=\"-1\">\n";
    print $x2 "<META HTTP-EQUIV=\"Expires\" CONTENT=\"-1\">\n";

    $dbh=DBI->connect('dbi:ODBC:CategoryDB') || die "Error opening Auctions database: $DBI::errstr\n";
    
    # Load all the category records into the categories referenced hash

    $SQLStmt = "SELECT * FROM TMCategories ORDER BY Parent, Sequence";
    $sth     = $dbh->prepare($SQLStmt)|| die "Error preparing statement: $DBI::errstr\n";
    $sth->execute() || die "Error executing statement: $DBI::errstr\n";
    my $categories = $sth->fetchall_arrayref({});

    # Load up the table Header

    print $x1 "<H2>Category Master File</H2><BR>\n";
    print $x2 "<H2>Category master File</H2><BR>\n";
    

    # read all the categories and load them into the catory data table

    print $x1 "<TABLE>\n";
          
    foreach my $record (@$categories) {

        print $x1 "<TR>";
        print $x1 "<TD>$record->{ Category     }</TD>";
        print $x1 "<TD>$record->{ Description  }</TD>";
        print $x1 "<TD>$record->{ Parent       }</TD>";
        print $x1 "<TD>$record->{ Sequence     }</TD>";
        print $x1 "</TR>\n";

        print $x2 "<TR>";
        print $x2 "<TD>$record->{ Category     }</TD>";
        print $x2 "<TD>$record->{ Description  }</TD>";
        print $x2 "<TD>$record->{ Parent       }</TD>";
        print $x2 "<TD>$record->{ Sequence     }</TD>";
        print $x2 "</TR>\n";

    }

    print $x1 "</TABLE>\n";
    print $x2 "</TABLE>\n";

    
    # Close the Category Service Control XML document

    print $x1 "</BODY></HTML>\n";
    print $x2 "</BODY></HTML>\n";
    
    close $x1;
    close $x2;
}



# Subroutine to transmit generated XML documents to website

sub transmit_html {

    my ($ok, $ftp, $ctlfile, $updfile, $tblfile, $username, $password, $localdir, $remotedir, $host);

    # Set up variables to manage the transfers

#    $localdir   = "c:\\evan\\Auctionitis Categories";
    $localdir   = "c:\\evan\\Auctionitis103\\data";
    $remotedir  = "public_html/auctionitis/service";
    $ctlfile    = "Category_Control.html";
    $tblfile    = "Category_Data.html";
    $updfile    = "Category_Update_".$current_service_date.".html";
#    $username   = "auctionitis.co.nz";
#    $password   = "if93vy";
#    $host       = "ftp.domainz.net.nz";
    $username   = "auctis";
    $password   = "auc0805";
    $host       = "ftp.auctionitis.web-haven.net";

    $ftp        = Net::FTP->new($host);
    
    # This is where the transfers occur

    print "Logging into Auctionitis\.co\.nz\n";    
    $ok         = $ftp->login($username, $password);
    print "Setting Remote Directory\n";    
    $ok         = $ftp->cwd($remotedir);
    print "Sending Service control table\n";    
    $ok         = $ftp->put($localdir."\\".$ctlfile, $ctlfile);
    print "Sending Category Master File\n";    
    $ok         = $ftp->put($localdir."\\".$tblfile, $tblfile);
    print "Sending Category Remap File\n";    
    $ok         = $ftp->put($localdir."\\".$updfile, $updfile);

    # exit the FTP agent
    
    $ftp->quit;

}

# Subroutine to check whether category has parent in old categories

sub hasparent {

    my $parent = shift;
    
    my $sth = $dbh->prepare("SELECT COUNT(*) FROM TMCategories WHERE Category=?")|| die "Error preparing statement: $DBI::errstr\n";
    $sth->execute($parent) || die "Error exexecuting statement: $DBI::errstr\n";
    my $found=$sth->fetchrow_array;

    return $found;
}

# Subroutine to get details of old category and return them in an array

sub getcategory {

    my $parent = shift;

    my $sth = $dbh->prepare("SELECT TMCategories.Parent, TMCategories.Sequence, TMCategories.Description, TMCategories.Category FROM TMCategories WHERE Category=?")|| die "Error preparing statement: $DBI::errstr\n";
    $sth->execute($parent) || die "Error exexecuting statement: $DBI::errstr\n";
    my @data=$sth->fetchrow_array;

    return @data;
}


# Subroutine to return todays date in standard reverse date format

sub today() {

    my ($day, $month, $year);

    # Set the day value

    if   ( (localtime)[3] < 10 )        { $day = "0".(localtime)[3]; }
    else                                { $day = (localtime)[3]; }

    # Set the month value
    
    if   ( ((localtime)[4]+1) < 10 )    { $month = "0".((localtime)[4]+1); }
    else                                { $month = ((localtime)[4]+1) ; }

    # Set the century/year value

    $year = ((localtime)[5]+1900);

    my $current_service_date = $year."-".$month."-".$day;
    
    return $current_service_date;
}

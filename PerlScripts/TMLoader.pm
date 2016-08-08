package TMLoader;
use strict;
use Auctionitis;
use Win32::OLE;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );

our $version = "2.5";   # Version number

my ($tm, $pb, $estruct, $abend, @clonekeys);

##############################################################################################
# --- Exported Methods/Subroutines ---
############################################################################################

#=============================================================================================
# UpdateLog - Update the Auctionitis Log file
#=============================================================================================

sub UpdateLog {

    my $LogText = shift;

    $tm = Auctionitis->new();
    $tm->initialise(Product => "Auctionitis");

    $tm->update_log( $LogText );

}

#=============================================================================================
# PropertyDump - Update the Auctionitis Log file
#=============================================================================================

sub PropertyDump {

    $tm = Auctionitis->new();
    $tm->initialise( Product => "Auctionitis" );

    $tm->dump_properties;
}

#=============================================================================================
# Get MD5 Hash - get MD5 hash (for images mostly) using the Auctionitis module for consistency
#=============================================================================================

sub GetMD5HashFromFile {

    my $filename = shift;

    $tm = Auctionitis->new();
    $tm->initialise( Product => "Auctionitis" );

    $tm->update_log("Invoked Method: ". (caller(0))[3]);
    $tm->dump_properties;

    my $hashdata    = $tm->get_imagedata_from_file( PictureFileName => $filename );
    my $hash        = $tm->get_md5_hash( Data => $hashdata );

    return $hash;
}

#=============================================================================================
# GetDVDList
#=============================================================================================

sub GetDVDList {

    my $searchstring = shift;

    # foreach my $i (@ARGV) {
    #    if ( $searchstring eq "") {
    #        $searchstring = $i;
    #    }
    #    else {
    #        $searchstring = $searchstring." ".$i;
    #    }
    # }

    my $tm = Auctionitis->new();
    $tm->initialise(Product => "Auctionitis");
    $tm->update_log("Invoked Method: ". (caller(0))[3]);
    $tm->update_log("DVD Search for: ". $searchstring);
    $tm->login();

    my $HTMLPage = $tm->get_movie_search_list($searchstring);

    if ( $tm->{ ErrorStatus } ) {
        UpdateErrorStatus();   
        return $estruct;
    }
    else {
        return $HTMLPage ;
    }

}

#=============================================================================================
# is internet connected - check whether the internet is accessible
#=============================================================================================

sub IsInternetConnected {

    $tm = Auctionitis->new();
    $tm->initialise(Product => "Auctionitis");

    $tm->update_log("Invoked Method: ". (caller(0))[3]);

    my $retval = $tm->is_internet_connected();

    if ( $tm->{ ErrorStatus } ) {
        UpdateErrorStatus();   
        return $estruct;
    }
    
    else {

        my $ReturnData = { 
            "ErrorStatus"   =>  "0" ,
            "ErrorCode"     =>  "0" ,
            "ErrorMessage"  =>  "No Errors encountered"  ,
            "ErrorDetail"   =>  ""  ,
            "IsConnected"   =>  $retval ,
        };
        return $ReturnData ;
    }

}

#=============================================================================================
# ReplaceText - call the uctionitis serch and replace operation
#=============================================================================================

sub ReplaceText {

    my $keylist             = shift;
    my $searchstring        = shift;    
    my $replacestring       = shift;
    my $updatetitle         = shift;
    my $updatedescription   = shift;
    my $errorcount          = 0;

    $tm = Auctionitis->new();
    $tm->initialise(Product => "Auctionitis");

    $tm->update_log("Invoked Method: ". (caller(0))[3]);

    $tm->update_log("Connecting to Database");
    $tm->DBconnect();                           # Connect to the database

    foreach my $auction ( @$keylist ) {
        my $ok = $tm->replace_auction_text(
            AuctionKey          => $auction             ,
            SearchString        => $searchstring        ,
            ReplaceString       => $replacestring       ,
            UpdateTitle         => $updatetitle         ,
            UpdateDescription   => $updatedescription   ,
        );
        $ok += $errorcount;
    }

    if ( $errorcount > 0 ) {
    
        my $ReturnData = { 
            "ErrorStatus"   =>  "1" ,
            "ErrorCode"     =>  "1" ,
            "ErrorMessage"  =>  "Errors encountered while processing selected auctions. Check the log for more details"  ,
            "ErrorDetail"   =>  ""  ,
        };
        return $ReturnData ;
    }
    else {

        my $ReturnData = { 
            "ErrorStatus"   =>  "0" ,
            "ErrorCode"     =>  "0" ,
            "ErrorMessage"  =>  "No Errors encountered"  ,
            "ErrorDetail"   =>  ""  ,
        };
        return $ReturnData ;
    }
}

#=============================================================================================
# GetDBProprty - Get Database Property Value
#=============================================================================================

sub GetDBProperty {

    my $PropertyName = shift;
    my $DefaultValue = shift;
    my $pv;

    $tm = Auctionitis->new();
    $tm->initialise(Product => "Auctionitis");  # Initialise the product

    $tm->update_log("Invoked Method: ". (caller(0))[3]);

    $tm->update_log("Connecting to Database");
    $tm->DBconnect();                           # Connect to the database

    $pv = $tm->get_DB_property( 
        Property_Name       =>  $PropertyName   ,
        Property_Default    =>  $DefaultValue   ,
    );

    $tm->DBdisconnect();                        # disconnect from the database

    if ( $tm->{ ErrorStatus } ) {
        UpdateErrorStatus();   
        return $estruct;
    }
    
    else {

        my $ReturnData = { 
            "ErrorStatus"   =>  "0" ,
            "ErrorCode"     =>  "0" ,
            "ErrorMessage"  =>  "No Errors encountered"  ,
            "ErrorDetail"   =>  ""  ,
            "PropertyValue" =>  $pv ,
        };
        return $ReturnData ;
    }

}

#=============================================================================================
# ExportData - Export data in CSV Format
#=============================================================================================

sub ExportData {

    my $SQL         =   shift;
    my $outfile     =   shift;

    $tm = Auctionitis->new();
    $tm->initialise(Product => "Auctionitis");  # Initialise the product

    $tm->update_log("Invoked Method: ". (caller(0))[3]);

    $tm->{ Debug } ge "1" ? ( $tm->dump_properties() ) : () ;

    $tm->update_log("Connecting to Database");
    $tm->DBconnect();                          # Connect to the database

    $tm->export_data(SQL        => $SQL,
                     Outfile    => $outfile);

    $tm->DBdisconnect();                       # disconnect from the database

    UpdateErrorStatus();   
    return $estruct;
}

#=============================================================================================
# ExportHTMLData - Export data in HTML Format
#=============================================================================================

sub ExportHTMLAsPages {

    my $SQL         =   shift;
    my $outfile     =   shift;

    $tm = Auctionitis->new();
    $tm->initialise(Product => "Auctionitis");  # Initialise the product
    
    $tm->update_log("Invoked Method: ". (caller(0))[3]);

    $tm->{ Debug } ge "1" ? ( $tm->dump_properties() ) : () ;

    $tm->update_log("Connecting to Database");
    $tm->DBconnect();                          # Connect to the database

    $tm->export_HTML_as_pages(  SQL        => $SQL,
                                Outfile    => $outfile);

    $tm->DBdisconnect();                          # disconnect from the database

    UpdateErrorStatus();   
    return $estruct;
}

#=============================================================================================
# ExportHTMLData - Export data in HTML Format
#=============================================================================================

sub ExportHTMLAsRecords {

    my $SQL         =   shift;
    my $outfile     =   shift;

    $tm = Auctionitis->new();
    $tm->initialise( Product => "Auctionitis" );  # Initialise the product
    
    $tm->update_log( "Invoked Method: ". ( caller(0) )[3] );

    $tm->{ Debug } ge "1" ? ( $tm->dump_properties() ) : () ;

    $tm->update_log("Connecting to Database");
    $tm->DBconnect();                          # Connect to the database

    $tm->export_HTML_as_records(SQL        => $SQL,
                                Outfile    => $outfile);

    $tm->DBdisconnect();                          # disconnect from the database

    UpdateErrorStatus();   
    return $estruct;
}

#=============================================================================================
# ExportXMLData - Export data in XML Format
#=============================================================================================

sub ExportXMLData {

    my $SQL         =   shift;
    my $outfile     =   shift;
    my $filetext    =   shift;
    my $makezip     =   shift;

    $tm = Auctionitis->new();
    $tm->initialise( Product => "Auctionitis" );  # Initialise the product
    
    $tm->update_log( "Invoked Method: ". (caller(0))[3]);

    $tm->update_log( "SQL      : ". $SQL         );
    $tm->update_log( "Outfile  : ". $outfile     );
    $tm->update_log( "File Text: ". $filetext    );
    $tm->update_log( "Make Zip : ". $makezip     );

    $tm->{ Debug } ge "1" ? ( $tm->dump_properties() ) : () ;

    $pb = Win32::OLE->new('MultiPB.clsMultiPB') or die;

    ### insert some text into the window header

    $pb->InitialiseMultiBar();
    $pb->{ AlwaysMinimize       }   =   $tm->{ AlwaysMinimize };
    $pb->{ SetWindowTitle       }   =   "Auctionitis: Create XML Export File";
    $pb->{ SetTaskAction        }   =   "Creating XML Data Extract file";
    $pb->{ SetProgressCurrent   }   =   0;
    $pb->{ SetProgressTotal     }   =   0;

    # Add the tasks to be executed by this option
    
    $pb->AddTask("Create XML File");
    
    if ( $makezip ) {
        $pb->AddTask("Create Zip File");
    }

    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    $tm->update_log("Connecting to Database");
    $tm->DBconnect();                          # Connect to the database

    #-----------------------------------------------------------------------------------------
    # Task 1 - Create XML File
    #-----------------------------------------------------------------------------------------

    $tm->update_log("Started: Create XML File");

    $pb->{ SetCurrentTask       }   =   1;
    $pb->{ SetCurrentOperation  }   =   "Extracting Auction Records to XML";
    $pb->{ SetTaskAction        }   =   "Formatting record:";
    $pb->UpdateMultiBar();

    $tm->export_XML(SQL        => $SQL                  ,
                    Outfile    => $outfile              ,
                    FileText   => $filetext             ,
                    Feedback   => \&UpdateStatusBar     ,
                    Progress   => \&UpdateProgressBar   ,
                    Total      => \&UpdateProgressTotal );

    $pb->MarkTaskCompleted(1);
    $pb->UpdateMultiBar();
    sleep 2;
    
    $tm->update_log("Completed: Create XML File");

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ( $tm->{ ErrorStatus } ) {
        UpdateErrorStatus();   
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # Task 2 - Create Zip File
    #-----------------------------------------------------------------------------------------

    if ( $makezip ) {

        $tm->update_log("Started: Create Zip File");

        $pb->{ SetCurrentTask       }   =   2;
        $pb->{ SetCurrentOperation  }   =   "Creating Zip Archive for XML data";
        $pb->{ SetTaskAction        }   =   "Zipping file:";
        $pb->UpdateMultiBar();

        # Build the Zip file name using the XML file name and changing the extension

        $outfile =~ m/C:\\(.+?$)/;
        my $zipfile = $1."\.zip";

        chdir "\\";
        my $zip = Archive::Zip->new();
        
        # write the XML file into the zip file

        my $member = $zip->addFile( $outfile );
        die 'write error' unless $zip->writeToFileNamed( $zipfile ) == AZ_OK;
      
        $pb->MarkTaskCompleted(2);
        $pb->UpdateMultiBar();
        sleep 2;

        $tm->update_log("Completed: Create Zip File");

        # Handle the task being cancelled via the CANCEL button or ending abnormally

        if ($abend) {
            return $estruct;
        }
    }

    #-----------------------------------------------------------------------------------------
    # All Tasks completed
    #-----------------------------------------------------------------------------------------

    $tm->DBdisconnect();                          # disconnect from the database
    
    $tm->update_log("Completed: Export XML Data");
    
    # Handle the task being cancelled via the CANCEL button or ending abnormally

    $tm->set_always_minimize( $pb->AlwaysMinimize() );
    $pb->QuitMultiBar();

    UpdateErrorStatus();   
    return $estruct;
}

#=============================================================================================
# GetXMLProperties - Get the properties from the identified XML file
#=============================================================================================

sub GetXMLProperties {

    my $XMLFile     =   shift;
    
    $tm = Auctionitis->new();
    $tm->initialise( Product => "Auctionitis" );  # Initialise the product

    $tm->update_log("Invoked Method: ". (caller(0))[3]); 

    $tm->{ Debug } ge "1" ? ( $tm->dump_properties() ) : () ;

    # Place the error indicators in an anonymous hash to return all properties

    my $properties = $tm->get_xml_properties( Filename => $XMLFile );
    
    while((my $key, my $val) = each(%$properties)) {
        $tm->update_log("XML Property: ".$key." Value: ".$val);
    }

    if ( $tm->{ ErrorStatus } ) {
            UpdateErrorStatus();   
            return $estruct;
    } else {
            return $properties;
    }
}

#=============================================================================================
# ExportXMLData - Import data in XML Format
#=============================================================================================

sub ImportXMLData {

    my $infile      =   shift;          # Input XML data file 
    my $action      =   shift;          # Update Action (Add/Replace)
    my $reccount    =   shift;          # Update Action (Add/Replace)
    my $SQL         =   shift;          # SQL Selection to delete records to be replaced
    my $aAS         =   shift;          # Selection Array of Auction Statuses
    my $aRS         =   shift;          # Selection Array of Relist Statuses
    my $aPT         =   shift;          # Selection Array of Product Types
    my $aAC         =   shift;          # Selection Array of Auction Cycles
    my $aHS         =   shift;          # Selection Array of Held statuses

    # Hashes to hold selections for XML processing testing

    my $AS;                             # Auction Statuses
    my $RS;                             # Relist Statuses
    my $PT;                             # Product Types
    my $AC;                             # Auction Cycles
    my $HS;                             # Held statuses

    $tm = Auctionitis->new();
    $tm->initialise( Product => "Auctionitis" );  # Initialise the product
    
    $tm->update_log( "Invoked Method: ".( caller(0) )[3] );

    $tm->update_log( "Import Selection Data"            );
    $tm->update_log( "        Infile: ". $infile        );
    $tm->update_log( "        Action: ". $action        );
    $tm->update_log( "           SQL: ". $SQL           );
    $tm->update_log( "   XML Records: ". $reccount      );
    
    foreach my $status ( @$aAS ) {
        $AS->{ $status } = "1";
        $tm->update_log( "Auction Status: ". $status ); 
    }

    foreach my $status ( @$aRS ) {
        $RS->{ $status } = "1";
        $tm->update_log( " Relist Status: ". $status ); 
    }
    
    foreach my $status ( @$aPT)  {
        $PT->{ $status } = "1";
        $tm->update_log( "  Product Type: ". $status ); 
    }
    
    foreach my $status ( @$aAC ) {
        $AC->{ $status } = "1";
        $tm->update_log( " Auction Cycle: ". $status ); 
    }
    
    foreach my $status ( @$aHS ) {
        $HS->{ $status } = "1";
        $tm->update_log( "   Held Status: ". $status ); 
    }

    $tm->update_log("Connecting to Database");
    $tm->DBconnect();                          # Connect to the database

    $pb = Win32::OLE->new( 'MultiPB.clsMultiPB' ) or die;

    ### insert some text into the window header

    $pb->InitialiseMultiBar();
    $pb->{ AlwaysMinimize       }   =   $tm->{ AlwaysMinimize };
    $pb->{ SetWindowTitle       }   =   "Auctionitis: Import from XML File";
    $pb->{ SetTaskAction        }   =   "Reading XML Data Import file";
    $pb->{ SetProgressCurrent   }   =   0;
    $pb->{ SetProgressTotal     }   =   $reccount;

    # Add the tasks to be executed by this option
    
    $pb->AddTask("Read XML File");

    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    #-----------------------------------------------------------------------------------------
    # Task 1 - Read XML File
    #-----------------------------------------------------------------------------------------

    $tm->update_log("Started: Read XML File");

    $pb->{ SetCurrentTask       }   =   1;
    $pb->{ SetCurrentOperation  }   =   "Extracting Auction Records from XML file";
    $pb->{ SetTaskAction        }   =   "Reading record:";
    $pb->UpdateMultiBar();

    $tm->import_XML(FileName        => $infile               ,
                    Action          => $action               ,
                    AuctionStatus   => $AS                   ,
                    RelistStatus    => $RS                   ,
                    ProductType     => $PT                   ,
                    AuctionCycle    => $AC                   ,
                    HeldStatus      => $HS                   ,
                    Feedback        => \&UpdateStatusBar     ,
                    Progress        => \&UpdateProgressBar   ,
                    Total           => \&UpdateProgressTotal );

    $pb->MarkTaskCompleted(1);
    $pb->UpdateMultiBar();
    sleep 2;
    
    $tm->update_log("Completed: import XML File");

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ( $abend ) {
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # All Tasks completed
    #-----------------------------------------------------------------------------------------

    $tm->DBdisconnect();                          # disconnect from the database
    
    $tm->update_log("Completed: Import XML Data");

    $tm->set_always_minimize( $pb->AlwaysMinimize() );
    $pb->QuitMultiBar();

    UpdateErrorStatus();   
    return $estruct;

}
 
#=============================================================================================
# LoadSelectedPhotos - Load photos selected in Auctionitis grid
#=============================================================================================

sub LoadSelectedPhotos {

    my $keylist     =   shift;

    $tm = Auctionitis->new();
    $tm->initialise(Product => "Auctionitis");  # Initialise the product
    
    $tm->update_log("Invoked Method: ". (caller(0))[3]); 

    $tm->{ Debug } ge "1" ? ( $tm->dump_properties() ) : () ;

    $pb = Win32::OLE->new('MultiPB.clsMultiPB') or die;

    ### insert some text into the window header

    $pb->InitialiseMultiBar();
    $pb->{ AlwaysMinimize       }   =   $tm->{ AlwaysMinimize };
    $pb->{ SetWindowTitle       }   =   "Auctionitis: Load Selected Photographs";
    $pb->{ SetTaskAction        }   =   "Loading picture";
    $pb->{ SetProgressCurrent   }   =   0;
    $pb->{ SetProgressTotal     }   =   0;

    # Add the tasks to be executed by this option
    
    $pb->AddTask("Load New Pictures");
    $pb->AddTask("Check Picture Files on TradeMe");
    
    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    $tm->update_log("Connecting to Database");
    $tm->DBconnect();                           # Connect to the database

    $tm->update_log("Logging in to TradeMe");
    $tm->login();

    # if login was not OK update error structure and return

    if ( $tm->{ ErrorStatus } ) {
        $tm->set_always_minimize( $pb->AlwaysMinimize() );
        $pb->QuitMultiBar();
        UpdateErrorStatus();   
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # Task 1 - Process New pictures
    #-----------------------------------------------------------------------------------------

    $tm->update_log("Started: Load New Pictures");

    $pb->{ SetCurrentTask       }   =   1;
    $pb->{ SetCurrentOperation  }   =   "Loading New pictures to TradeMe";
    $pb->{ SetTaskAction        }   =   "Uploading file:";
    $pb->UpdateMultiBar();

    my $pictures =  $tm->get_selected_unloaded_pictures(
         AuctionSite    => "TRADEME"    ,
         AuctionKeys    =>  $keylist    ,
    );

    $pb->{ SetProgressTotal     }   =   scalar( @$pictures );
    $pb->UpdateMultiBar();
    
    if ( scalar( @$pictures ) ne 0 ) {

         my $uploadedpics = PictureUpload( $pictures );

        # Adjust the Auctionitis TM Picture total

        $tm->set_DB_property(
            Property_Name       => "TMPictureCount" ,
            Property_Value      => $tm->get_DB_property( Property_Name => "TMPictureCount", Property_Default => 0 ) + $uploadedpics,
        );
        $tm->update_log("Adjust TMPictureCount Property  - ".$uploadedpics." new pictures");
    }
    
    $pb->MarkTaskCompleted(1);
    $pb->UpdateMultiBar();
    sleep 2;
    
    $tm->update_log("Completed: Load New Pictures");

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # Task 2 - Process Expired Pictures
    #-----------------------------------------------------------------------------------------

    $tm->update_log("Started: Check Picture Files on TradeMe");
    
    $pb->{ SetCurrentTask       }   =   2;
    $pb->{ SetCurrentOperation  }   =   "Comparing Picture Totals";
    $pb->{ SetTaskAction        }   =   "";
    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    # Compare the TradeMe picture count with the Auctionitis picture count

    my $TMPictotal  = $tm->get_TM_photo_count();
    my $DBPictotal  = $tm->get_DB_property( Property_Name => "TMPictureCount", Property_Default => 0 );
    
    $tm->update_log("Picture Total on TradeMe  - $TMPictotal");
    $tm->update_log("Calculated Picture total  - $DBPictotal");

    # If the database total equals the TM picture total there are no expired pics (in theory...)
    
    if ( $DBPictotal eq $TMPictotal ) {

        $tm->update_log("Picture Totals reconciled - processing complete");
        $pb->{ SetTaskAction }   =   "Picture Totals reconciled - processing complete";

    }
    
    else {

        $pb->{ SetCurrentOperation  }   =   "Retrieving TradeMe Picture data";

        my @TMPictures = $tm->get_photo_list(\&UpdateStatusBar);

        my %TMPictable;

        foreach my $PhotoId ( @TMPictures ) {
            $TMPictable{ $PhotoId } = 1;
        }

        my @expiredpics;
        my $selectedpictures;

        # my $picturekeys         =   $tm->get_selected_used_picture_keys(@$keylist);

        my $picturekeys = $tm->get_selected_used_picture_keys(  
            AuctionSite => "TRADEME"    ,
            AuctionKeys => $keylist    ,
        );

        $tm->{ Debug } ge "1" ? ( $tm->update_log( "get_selected_used_picture_keys returned: ".$picturekeys ) ) : () ;

        # Build the expired pics array if the auctions actually have pictures

        if ( scalar( @$picturekeys ) > 0 ) {

             $selectedpictures = $tm->get_picture_records( @$picturekeys );

             foreach my $picture ( @$selectedpictures ) {

                  if  ( not defined $TMPictable{ $picture->{ PhotoId } } ) {
                       $tm->update_log("Located expired Photo $picture->{ PictureFileName } (Record $picture->{ PictureKey })");
                       $pb->{ SetCurrentOperation  }   =   "Expired: $picture->{ PictureFileName }";
                       push(@expiredpics, $picture->{ PictureKey });
                  }
             }
        }

        # If we have some expired pictures then load them

        if ( scalar(@expiredpics) > 0 ) {

            my $pictures =  $tm->get_picture_records( @expiredpics );

            $pb->{ SetProgressTotal     }   =   @$pictures;
            $pb->UpdateMultiBar();

            PictureUpload($pictures);
        }

        #set the picture total in the database properties file

        my $TMPictotal  = $tm->get_TM_photo_count();

        $tm->set_DB_property(
            Property_Name       => "TMPictureCount" ,
            Property_Value      => $TMPictotal,
        );            
    }
    
    $pb->MarkTaskCompleted(2);
    $pb->UpdateMultiBar();
    sleep 2;
    
    $tm->update_log("Completed: Check Picture Files on TradeMe");
    
    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # All Tasks completed
    #-----------------------------------------------------------------------------------------

    $tm->DBdisconnect();                          # disconnect from the database

    $tm->set_always_minimize( $pb->AlwaysMinimize() );
    $pb->QuitMultiBar();

    UpdateErrorStatus();   
    return $estruct;    
}

#=============================================================================================
# LoadAllPhotos - Load all photos that have not been loaded to TradeMe
#=============================================================================================

sub LoadAllPhotos {

    $tm = Auctionitis->new();
    $tm->initialise(Product => "Auctionitis");  # Initialise the product
    
    $tm->update_log("Invoked Method: ". (caller(0))[3]); 

    $tm->{ Debug } ge "1" ? ( $tm->dump_properties() ) : () ;

    $pb = Win32::OLE->new('MultiPB.clsMultiPB') or die;

    ### insert some text into the window header

    $pb->InitialiseMultiBar();
    $pb->{ AlwaysMinimize       }   =   $tm->{ AlwaysMinimize };
    $pb->{ SetWindowTitle       }   =   "Auctionitis: Load All Photographs";
    $pb->{ SetProgressCurrent   }   =   0;
    $pb->{ SetProgressTotal     }   =   0;
    $pb->{ SetTaskAction        }   =   "Loading picture";
    
    $pb->AddTask("Load New Pictures");
    $pb->AddTask("Check Picture Files on TradeMe");
    $pb->UpdateMultiBar();

    $pb->ShowMultiBar();

    $tm->update_log("Connecting to Database");
    $tm->DBconnect();                           # Connect to the database

    $tm->update_log("Logging in to TradeMe");
    $tm->login();

    # if login was not OK update error structure and return

    if ( $tm->{ ErrorStatus } ) {
        $tm->set_always_minimize( $pb->AlwaysMinimize() );
        $pb->QuitMultiBar();
        UpdateErrorStatus();   
        return $estruct;
    }    

    #-----------------------------------------------------------------------------------------
    # Task 1 - Process New pictures
    #-----------------------------------------------------------------------------------------

    $tm->update_log("Started: Load New Pictures");

    $pb->{ SetCurrentTask       }   =   1;
    $pb->{ SetCurrentOperation  }   =   "Loading New pictures to TradeMe";
    $pb->{ SetTaskAction        }   =   "Uploading file:";
    $pb->UpdateMultiBar();

    my $pictures =  $tm->get_unloaded_pictures( AuctionSite => "TRADEME" );

    $pb->{ SetProgressTotal     }   =   scalar(@$pictures);
    $pb->UpdateMultiBar();

    if ( scalar( @$pictures ) ne 0 ) {

        my $uploadedpics = PictureUpload( $pictures );

        # Adjust the Auctionitis TM Picture total

        $tm->set_DB_property(
            Property_Name       => "TMPictureCount" ,
            Property_Value      => $tm->get_DB_property( Property_Name => "TMPictureCount", Property_Default => 0 ) + $uploadedpics,
        );

        $tm->update_log("Adjust TMPictureCount Property  - ".$uploadedpics." new pictures");
    }

    $pb->MarkTaskCompleted(1);
    $pb->UpdateMultiBar();

    $tm->update_log("Completed: Load New Pictures");

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
        return $estruct;
    }
    
    #-----------------------------------------------------------------------------------------
    # Task 2 - Process Expired Pictures
    #-----------------------------------------------------------------------------------------

    $tm->update_log("Started: Check Picture Files on TradeMe");

    $pb->{ SetCurrentTask       }   =   2;
    $pb->{ SetCurrentOperation  }   =   "Retrieving TradeMe Picture data";
    $pb->{ SetTaskAction        }   =   "";

    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    # Compare the TradeMe picture count with the Auctionitis picture count

    my $TMPictotal  = $tm->get_TM_photo_count();
    my $DBPictotal  = $tm->get_DB_property(Property_Name => "TMPictureCount", Property_Default => 0);
    
    $tm->update_log("Picture Total on TradeMe  - $TMPictotal");
    $tm->update_log("Calculated Picture total  - $DBPictotal");

    # If the database total equals the TM picture total there are no expired pics (in theory...)
    
    if ( $DBPictotal eq $TMPictotal ) {

        $tm->update_log("Picture Totals reconciled - processing complete");
        $pb->{ SetTaskAction }   =   "Picture Totals reconciled - processing complete";

    }
    
    else {
    
        my @TMPictures = $tm->get_photo_list(\&UpdateStatusBar);

        my %TMPictable;

        foreach my $PhotoId ( @TMPictures ) {
            $TMPictable{ $PhotoId } = 1;
        }

        my $currentpictures = $tm->get_all_pictures();

        my @expiredpics;

        foreach my $picture ( @$currentpictures ) {

            if (not defined $TMPictable{ $picture->{ PhotoId } } ) {

                $tm->update_log("Located expired Photo $picture->{PictureFileName} (Record $picture->{PictureKey})");
                $pb->{ SetCurrentOperation  }   =   "Expired: $picture->{PictureFileName}";
                push(@expiredpics, $picture->{ PictureKey });
            }
        }

        # If any expired pics are encountered upload them to TradeMe

        if ( scalar(@expiredpics) > 0 ) {

            $pictures =  $tm->get_picture_records( @expiredpics );

            $pb->{ SetProgressTotal     }   =   scalar(@$pictures);
            $pb->UpdateMultiBar();

            PictureUpload($pictures);

        }

        #set the picture total in the database properties file

        my $TMPictotal  = $tm->get_TM_photo_count();

        $tm->set_DB_property(
            Property_Name       => "TMPictureCount" ,
            Property_Value      => $TMPictotal,
        );            
    }
    
    $pb->MarkTaskCompleted(2);
    $pb->UpdateMultiBar();
    sleep 2;
    
    $tm->update_log("Completed: Check Picture Files on TradeMe");

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # All Tasks completed
    #-----------------------------------------------------------------------------------------

    $tm->DBdisconnect();                          # disconnect from the database

    $tm->set_always_minimize( $pb->AlwaysMinimize() );
    $pb->QuitMultiBar();
    
    UpdateErrorStatus();   
    return $estruct;
}

#=============================================================================================
# PictureUpload - Procedure to actually perform the transmission to TradeMe
#=============================================================================================

sub PictureUpload {

    my $pictures    =   shift;
    my $counter     =   1;
    my $uploaded    =   0;

    $tm->update_log("Invoked Method: ". (caller(0))[3]); 

    $tm->{ Debug } ge "1" ? ( $tm->dump_properties() ) : () ;

    foreach my $picture (@$pictures) {

        $tm->update_log("Picture Upload: Processing record $picture->{ PictureKey }");

        $pb->{ SetProgressCurrent       }   =   $counter;
        $pb->UpdateMultiBar();

        $pb->{SetCurrentOperation} = "Processing ".$picture->{ PictureFileName };

        my $newpicture = $tm->load_picture_from_DB(
            PictureKey  =>  $picture->{ PictureKey  }   ,
            ImageName   =>  $picture->{ ImageName   }   ,
        );

        if ( not defined $newpicture ) {
            $tm->update_log("Error uploading $picture->{ PictureFileName } to TradeMe (record $picture->{PictureKey})");
        } 
        else {
            $tm->update_picture_record( 
                PictureKey       =>  $picture->{ PictureKey }   ,
                PhotoId          =>  $newpicture                ,
            );
            $tm->update_log( "Loaded $picture->{ PictureFileName } to TradeMe (record $picture->{ PictureKey })" );
            $uploaded++;
        }

        sleep 1;

        $counter++;

        if ( $pb->{ Cancelled } ) {
            CancelHandler();
            return $estruct;
        }
    }
    
    UpdateErrorStatus();   
    return $uploaded;
}

#=============================================================================================
# Load a single Auction to TradeMe
#=============================================================================================

sub Load {

    my $keylist  =   shift;

    $tm = Auctionitis->new();
    $tm->initialise(Product => "Auctionitis");  # Initialise the product
    
    $tm->update_log("Invoked Method: ". (caller(0))[3]); 

    $tm->{ Debug } ge "1" ? ( $tm->dump_properties() ) : () ;
    
    $pb = Win32::OLE->new('MultiPB.clsMultiPB') or die;

    ### insert some text into the window header

    $pb->InitialiseMultiBar();
    $pb->{ AlwaysMinimize       }   =   $tm->{ AlwaysMinimize };
    $pb->{ SetWindowTitle       }   =   "Auctionitis: Load Auction";
    $pb->{ SetProgressCurrent   }   =   0;
    $pb->{ SetProgressTotal     }   =   0;
    
    $pb->AddTask("Loading New Pictures to TradeMe");
    $pb->AddTask("Check Picture Files on TradeMe");
    $pb->AddTask("Loading Auction to TradeMe");

    $tm->update_log("Started: Loading Auction to TradeMe");

    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    $tm->update_log("Connecting to Database");
    $tm->DBconnect();                          # Connect to the database

    $tm->update_log("Logging in to TradeMe");
    $tm->login();

    # if login was not OK update error structure and return

    if ( $tm->{ ErrorStatus } ) {
        $tm->set_always_minimize( $pb->AlwaysMinimize() );
        $pb->QuitMultiBar();
        UpdateErrorStatus();   
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # Task 1 - Process New pictures
    #-----------------------------------------------------------------------------------------

    $tm->update_log("Started: Load New Pictures");

    $pb->{ SetCurrentTask       }   =   1;
    $pb->{ SetCurrentOperation  }   =   "Loading New pictures to TradeMe";
    $pb->{ SetTaskAction        }   =   "Uploading file:";
    $pb->UpdateMultiBar();

    my $pictures =  $tm->get_selected_unloaded_pictures(
         AuctionSite    => "TRADEME"    ,
         AuctionKeys    =>  $keylist    ,
    );

    $pb->{ SetProgressTotal     }   =   scalar(@$pictures);
    $pb->UpdateMultiBar();
    
    if ( scalar(@$pictures) ne 0 ) {
         my $uploadedpics = PictureUpload($pictures);

        # Adjust the Auctionitis TM Picture total

        $tm->set_DB_property(
            Property_Name       => "TMPictureCount" ,
            Property_Value      => $tm->get_DB_property(Property_Name => "TMPictureCount", Property_Default => 0) + $uploadedpics,
        );

        $tm->update_log("Adjust TMPictureCount Property  - ".$uploadedpics." new pictures");
    }
    
    $pb->MarkTaskCompleted(1);
    $pb->UpdateMultiBar();
    sleep 2;
    
    $tm->update_log("Completed: Load New Pictures");

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # Task 2 - Process Expired Pictures
    #-----------------------------------------------------------------------------------------

    $tm->update_log("Started: Check Picture Files on TradeMe");
    
    $pb->{ SetCurrentTask       }   =   2;
    $pb->{ SetCurrentOperation  }   =   "Retrieving TradeMe Picture data";
    $pb->{ SetTaskAction        }   =   "";
    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();
    
    # Compare the TradeMe picture count with the Auctionitis picture count

    my $TMPictotal  = $tm->get_TM_photo_count();
    my $DBPictotal  = $tm->get_DB_property(Property_Name => "TMPictureCount", Property_Default => 0);
    
    $tm->update_log("Picture Total on TradeMe  - $TMPictotal");
    $tm->update_log("Calculated Picture total  - $DBPictotal");

    # If the database total equals the TM picture total there are no expired pics (in theory...)
    
    if ( $DBPictotal eq $TMPictotal ) {

        $tm->update_log("Picture Totals reconciled - processing complete");
        $pb->{ SetTaskAction }   =   "Picture Totals reconciled - processing complete";

    }
    
    else {

        my @TMPictures = $tm->get_photo_list(\&UpdateStatusBar);

        my %TMPictable;

        foreach my $PhotoId ( @TMPictures ) {
            $TMPictable{ $PhotoId } = 1;
        }

        my @expiredpics;
        my $selectedpictures;

        my $picturekeys = $tm->get_selected_used_picture_keys(  
            AuctionSite => "TRADEME"    ,
            AuctionKeys => $keylist    ,
        );

        # Build the expired pics array if the auctions actually have pictures

        if ( scalar( @$picturekeys > 0 ) ) {

             $selectedpictures = $tm->get_picture_records( @$picturekeys );

             foreach my $picture ( @$selectedpictures ) {

                if  ( not defined $TMPictable{ $picture->{ PhotoId } } ) {
                     $tm->update_log("Located expired Photo $picture->{ PictureFileName } (Record $picture->{ PictureKey })");
                     $pb->{ SetCurrentOperation  }   =   "Expired: $picture->{PictureFileName}";
                     push(@expiredpics, $picture->{ PictureKey });
                }
             }
        }

        # If we have some expired pictures then load them


        if ( scalar(@expiredpics > 0 ) ) {

            my $pictures =  $tm->get_picture_records( @expiredpics );

            $pb->{ SetProgressTotal     }   =   @$pictures;
            $pb->UpdateMultiBar();

            PictureUpload($pictures);
        }

        #set the picture total in the database properties file

        my $TMPictotal  = $tm->get_TM_photo_count();

        $tm->set_DB_property(
            Property_Name       => "TMPictureCount" ,
            Property_Value      => $TMPictotal,
        );            
        
    }
    
    $pb->MarkTaskCompleted(2);
    $pb->UpdateMultiBar();
    sleep 2;

    $tm->update_log("Completed: Check Picture Files on TradeMe");
    
    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # Task 3 - Load new Auction
    #-----------------------------------------------------------------------------------------

    $tm->update_log("Started: Load Auction to Trademe");

    $pb->{ SetCurrentTask       }   =   3;
    $pb->{ SetCurrentOperation  }   =   "Preparing Auction for upload";
    $pb->{ SetTaskAction        }   =   "Loading auctions to TradeMe:";

    my $auctions = $tm->get_auction_records(
         AuctionSite    => "TRADEME"    ,
         AuctionKeys    =>  $keylist    ,
    );

    $pb->{ SetProgressTotal     }   = @$auctions;
    $pb->{ SetCurrentOperation  }   = "Logging on to TradeMe";
    
    $pb->UpdateMultiBar();
    
    AuctionUpload( $auctions );

    $pb->MarkTaskCompleted(3);
    $pb->UpdateMultiBar();
    sleep 2;
    
    $tm->update_log("Completed: Load Auction to TradeMe");

    #-----------------------------------------------------------------------------------------
    # All Tasks completed
    #-----------------------------------------------------------------------------------------

    $tm->DBdisconnect();                          # disconnect from the database

    $tm->set_always_minimize( $pb->AlwaysMinimize() );
    $pb->QuitMultiBar();
    
    UpdateErrorStatus();   
    return $estruct;
}

#=============================================================================================
# LoadSelected - Load Auctions selected in Auctionitis grid
#=============================================================================================

sub LoadSelected {

    my $keylist     =   shift;

    $tm = Auctionitis->new();
    $tm->initialise(Product => "Auctionitis");  # Initialise the product
    
    $tm->update_log("Invoked Method: ". (caller(0))[3]); 

    $tm->{ Debug } ge "1" ? ( $tm->dump_properties() ) : () ;

    $pb = Win32::OLE->new('MultiPB.clsMultiPB') or die;

    ### insert some text into the window header

    $pb->InitialiseMultiBar();
    $pb->{ AlwaysMinimize       }   =   $tm->{ AlwaysMinimize };
    $pb->{ SetWindowTitle       }   =   "Auctionitis: Load Selected Auctions";
    $pb->{ SetProgressCurrent   }   =   0;
    $pb->{ SetProgressTotal     }   =   0;

    $pb->AddTask("Load New Pictures");
    $pb->AddTask("Check Picture Files on TradeMe");
    $pb->AddTask("Loading Selected Auctions to TradeMe");

    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    $tm->update_log("Connecting to Database");
    $tm->DBconnect();                           # Connect to the database

    $tm->update_log("Logging in to TradeMe");
    $tm->login();

    # if login was not OK update error structure and return

    if ( $tm->{ ErrorStatus } ) {
        $tm->set_always_minimize( $pb->AlwaysMinimize() );
        $pb->QuitMultiBar();
        UpdateErrorStatus();   
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # Task 1 - Process New pictures
    #-----------------------------------------------------------------------------------------

    $tm->update_log("Started: Load New Pictures");

    $pb->{ SetCurrentTask       }   =   1;
    $pb->{ SetCurrentOperation  }   =   "Loading New pictures to TradeMe";
    $pb->{ SetTaskAction        }   =   "Uploading file:";
    $pb->UpdateMultiBar();

    my $pictures =  $tm->get_selected_unloaded_pictures(
         AuctionSite    => "TRADEME"    ,
         AuctionKeys    =>  $keylist    ,
    );

    $pb->{ SetProgressTotal     }   =   scalar( @$pictures );
    $pb->UpdateMultiBar();
    
    if ( scalar(@$pictures) ne 0 ) {
         my $uploadedpics = PictureUpload( $pictures );

        # Adjust the Auctionitis TM Picture total

        $tm->set_DB_property(
            Property_Name       => "TMPictureCount" ,
            Property_Value      => $tm->get_DB_property(Property_Name => "TMPictureCount", Property_Default => 0) + $uploadedpics,
        );

        $tm->update_log("Adjust TMPictureCount Property  - ".scalar(@$pictures)." new pictures");
    }
    
    $pb->MarkTaskCompleted(1);
    $pb->UpdateMultiBar();
    sleep 2;
    
    $tm->update_log("Completed: Load New Pictures");

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # Task 2 - Process Expired Pictures
    #-----------------------------------------------------------------------------------------

    $tm->update_log("Started: Check Picture Files on TradeMe");
    
    $pb->{ SetCurrentTask       }   =   2;
    $pb->{ SetCurrentOperation  }   =   "Retrieving TradeMe Picture data";
    $pb->{ SetTaskAction        }   =   "";
    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();
    
    # Compare the TradeMe picture count with the Auctionitis picture count

    my $TMPictotal  = $tm->get_TM_photo_count();
    my $DBPictotal  = $tm->get_DB_property(Property_Name => "TMPictureCount", Property_Default => 0);
    
    $tm->update_log("Picture Total on TradeMe  - $TMPictotal");
    $tm->update_log("Calculated Picture total  - $DBPictotal");

    # If the database total equals the TM picture total there are no expired pics (in theory...)
    
    if ( $DBPictotal eq $TMPictotal ) {

        $tm->update_log("Picture Totals reconciled - processing complete");
        $pb->{ SetTaskAction }   =   "Picture Totals reconciled - processing complete";

    }
    
    else {
    
        my @TMPictures = $tm->get_photo_list(\&UpdateStatusBar);

        my %TMPictable;

        foreach my $PhotoId ( @TMPictures ) {
            $TMPictable{ $PhotoId } = 1;
        }

        my @expiredpics;
        my $selectedpictures;

        my $picturekeys = $tm->get_selected_used_picture_keys(  
            AuctionSite => "TRADEME"    ,
            AuctionKeys => $keylist    ,
        );

        # Build the expired pics array if the auctions actually have pictures

        if ( ( defined( $picturekeys ) ) and ( scalar( @$picturekeys ) > 0 ) ) {

    #    if ( scalar( @$picturekeys ) > 0 ) {

             $selectedpictures = $tm->get_picture_records(@$picturekeys);

             foreach my $picture ( @$selectedpictures ) {

                if  (not defined $TMPictable{ $picture->{ PhotoId } } ) {
                     $tm->update_log("Located expired Photo $picture->{PictureFileName} (Record $picture->{PictureKey})");
                     $pb->{ SetCurrentOperation  }   =   "Expired: $picture->{PictureFileName}";
                     push(@expiredpics, $picture->{ PictureKey });
                }
             }
        }

        # If we have some expired pictures then load them

        if ( scalar(@expiredpics) > 0 ) {

            my $pictures =  $tm->get_picture_records( @expiredpics );

            $pb->{ SetProgressTotal     }   =   @$pictures;
            $pb->UpdateMultiBar();

            PictureUpload($pictures);
        }

        #set the picture total in the database properties file

        my $TMPictotal  = $tm->get_TM_photo_count();

        $tm->set_DB_property(
            Property_Name       => "TMPictureCount" ,
            Property_Value      => $TMPictotal,
        );            
    }
    
    $pb->MarkTaskCompleted(2);
    $pb->UpdateMultiBar();
    sleep 2;

    $tm->update_log("Completed: Check Picture Files on TradeMe");
    
    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # Task 3 - Load selected autions
    #-----------------------------------------------------------------------------------------
    
    $pb->{ SetCurrentTask       }   =   3;
    $pb->{ SetCurrentOperation  }   =   "Preparing Auctions for upload";
    $pb->{ SetTaskAction        }   =   "Loading auctions to TradeMe:";

    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    $tm->update_log("Started: Loading Selected Auctions to TradeMe");

    my $auctions = $tm->get_auction_records( 
         AuctionSite    => "TRADEME"    ,
         AuctionKeys    =>  $keylist    ,
    );

    my $upload_total = 0;

    foreach my $auction (@$auctions) {
            $upload_total = $upload_total + $auction->{CopyCount};
    }

    $pb->{ SetProgressTotal     }   =   @$auctions;
    $pb->{ SetCurrentOperation  }   =   "Logging on to TradeMe";
    $pb->UpdateMultiBar();

    $tm->update_log("Logging in to TradeMe");
    $tm->login();

    # if login was not OK update error structure and return

    if ( $tm->{ ErrorStatus } ) {
        $tm->set_always_minimize( $pb->AlwaysMinimize() );
        $pb->QuitMultiBar();
        UpdateErrorStatus();   
        return $estruct;
    }

    AuctionUpload($auctions);

    $pb->MarkTaskCompleted(1);
    $pb->UpdateMultiBar();
    sleep 2;

    $tm->update_log("Completed: Loading Selected Auctions to TradeMe");

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # All Tasks completed
    #-----------------------------------------------------------------------------------------

    $tm->DBdisconnect();                          # disconnect from the database

    $tm->set_always_minimize( $pb->AlwaysMinimize() );
    $pb->QuitMultiBar();

    UpdateErrorStatus();   
    return $estruct;
}

#=============================================================================================
# LoadCycle - Load Auctions for the selected Auction Cycle
#=============================================================================================

sub LoadCycle {

    my $cycle   =   shift;

    $tm = Auctionitis->new();
    $tm->initialise(Product => "Auctionitis");  # Initialise the product
    
    $tm->update_log("Invoked Method: ". (caller(0))[3]); 

    $tm->{ Debug } ge "1" ? ( $tm->dump_properties() ) : () ;

    $pb = Win32::OLE->new('MultiPB.clsMultiPB') or die;

    ### insert some text into the window header

    $pb->InitialiseMultiBar();
    $pb->{ AlwaysMinimize       } = $tm->{ AlwaysMinimize };
    $pb->{SetWindowTitle        } = "Auctionitis: Load Auction Cycle $cycle";
    $pb->AddTask("Clone Auctions for Auction Cycle ".$cycle);
    $pb->AddTask("Load New Pictures");
    $pb->AddTask("Check Picture Files on TradeMe");
    $pb->AddTask("Load Pending auctions for Auction Cycle ".$cycle);

    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    # Instantatiate the TradeMe object

    $tm->update_log("Connecting to Database");
    $tm->DBconnect();                          # Connect to the database

    $tm->update_log("Logging in to TradeMe");
    $tm->login();

    # if login was not OK update error structure and return

    if ( $tm->{ ErrorStatus } ) {
        $tm->set_always_minimize( $pb->AlwaysMinimize() );
        $pb->QuitMultiBar();
        UpdateErrorStatus();   
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # Task 1 - Clone auctions
    #-----------------------------------------------------------------------------------------
    
    $tm->update_log("Started: Clone Auctions for Auction Cycle ".$cycle);

    $pb->{ SetCurrentTask       }   =   1;
    $pb->{ SetCurrentOperation  }   =   "Cloning Auctions";
    $pb->{ SetTaskAction        }   =   "Cloning Auctions from database for upload:";

    my $clones                      =  $tm->get_clone_auctions(
        AuctionSite     => "TRADEME"    ,
        AuctionCycle    => $cycle       ,
    );

    my $counter                     =   0;
    
    $pb->{ SetProgressTotal     }   =   scalar( @$clones );
    $pb->{ SetProgressCurrent   }   =   $counter;    
    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    foreach my $clone ( @$clones ) {
    
        $pb->{SetProgressCurrent} = $counter;    
        $pb->UpdateMultiBar();
        $pb->ShowMultiBar();

        my $newkey = $tm->copy_auction_record(
            AuctionKey       =>  $clone->{ AuctionKey } ,
            AuctionStatus    =>  "PENDING"              ,
        );

        push (@clonekeys, $newkey);    # Store the key of the new clone record

        $tm->update_log("Cloned Auction $clone->{AuctionTitle} (Record $clone->{auctionTitle})");

        $counter++;

        if      ( $pb->{ Cancelled } ) {
                CancelHandler();
                return $estruct;
        }
    }

    $pb->MarkTaskCompleted(1);
    $pb->UpdateMultiBar();

    $tm->update_log("Completed: Clone Auctions for Auction Cycle ".$cycle);

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # Task 2 - Process new photograhs
    #-----------------------------------------------------------------------------------------

    $tm->update_log("Started: Upload new picture files");

    $pb->{ SetCurrentTask       }   =   2;
    $pb->{ SetCurrentOperation  }   =   "Loading New pictures to TradeMe";
    $pb->{ SetTaskAction        }   =   "Uploading file:";
    $pb->UpdateMultiBar();

    my $pictures =  $tm->get_unloaded_pictures( AuctionSite => "TRADEME" );

    if ( scalar( @$pictures ) > 0 ) {

        $pb->{ SetProgressTotal     }   =   scalar( @$pictures );
        $pb->UpdateMultiBar();

        $tm->update_log("Logging in to Database");
        $tm->login();

        # if login was not OK update error structure and return

        if ( $tm->{ ErrorStatus } ) {
            $tm->set_always_minimize( $pb->AlwaysMinimize() );
            $pb->QuitMultiBar();
            UpdateErrorStatus();   
            return $estruct;
        }    

        PictureUpload( $pictures );

        # Adjust the Auctionitis TM Picture total

        $tm->set_DB_property(
            Property_Name       => "TMPictureCount" ,
            Property_Value      => $tm->get_DB_property( Property_Name => "TMPictureCount", Property_Default => 0 ) + scalar( @$pictures ),
        );

        $tm->update_log( "Adjust TMPictureCount Property  - ".scalar( @$pictures )." new pictures" );
    }

    $pb->MarkTaskCompleted(2);
    $pb->UpdateMultiBar();

    $tm->update_log("Completed: Upload new picture files");

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # Task 3 - Process expired photographs
    #-----------------------------------------------------------------------------------------

    $tm->update_log("Started: Upload expired picture files");
    
    $pb->{ SetCurrentTask       }   =   3;
    $pb->{ SetCurrentOperation  }   =   "Retrieving TradeMe Picture data";
    $pb->{ SetTaskAction        }   =   "";

    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();
    
    # Compare the TradeMe picture count with the Auctionitis picture count

    my $TMPictotal  = $tm->get_TM_photo_count();
    my $DBPictotal  = $tm->get_DB_property(Property_Name => "TMPictureCount", Property_Default => 0);
    
    $tm->update_log("Picture Total on TradeMe  - $TMPictotal");
    $tm->update_log("Calculated Picture total  - $DBPictotal");

    # If the database total equals the TM picture total there are no expired pics (in theory...)
    
    if ( $DBPictotal eq $TMPictotal ) {

        $tm->update_log("Picture Totals reconciled - processing complete");
        $pb->{ SetTaskAction }   =   "Picture Totals reconciled - processing complete";

    }
    
    else {

        my @TMPictures = $tm->get_photo_list(\&UpdateStatusBar);

        my %TMPictable;

        foreach my $PhotoId ( @TMPictures ) {
            $TMPictable{ $PhotoId } = 1;
        }

        my $currentpictures = $tm->get_all_pictures();

        my @expiredpics;

        foreach my $picture ( @$currentpictures ) {

            if (not defined $TMPictable{ $picture->{ PhotoId } } ) {

                $tm->update_log("Located expired Photo $picture->{PictureFileName} (Record $picture->{PictureKey})");
                $pb->{ SetCurrentOperation  }   =   "Expired: $picture->{PictureFileName}";
                push(@expiredpics, $picture->{ PictureKey });
            }
        }

        # If any expired pics are encountered upload them to TradeMe

        if ( scalar(@expiredpics) > 0 ) {

            $pictures =  $tm->get_picture_records( @expiredpics );

            $pb->{ SetProgressTotal     }   =   scalar(@$pictures);
            $pb->UpdateMultiBar();

            PictureUpload($pictures);            
        }

        #set the picture total in the database properties file

        my $TMPictotal  = $tm->get_TM_photo_count();

        $tm->set_DB_property(
            Property_Name       => "TMPictureCount" ,
            Property_Value      => $TMPictotal,
        );            
    }
    
    $pb->MarkTaskCompleted(3);
    $pb->UpdateMultiBar();

    $tm->update_log("Completed: Upload expired picture files");

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # Task 4 - Retrieve and Load auctions in auction cycle
    #-----------------------------------------------------------------------------------------

    $tm->update_log("Started: Load Pending auctions for Auction Cycle ".$cycle);

    $pb->{ SetCurrentTask       }   =   4;
    $pb->{ SetCurrentOperation  }   =   "Retrieving Auctions in Cycle $cycle";
    $pb->{ SetTaskAction        }   =   "Loading auctions to TradeMe:";
    $pb->UpdateMultiBar();

    my $auctions =  $tm->get_cycle_auctions(
        AuctionSite     =>  "TRADEME"   ,
        AuctionCycle    =>  $cycle      ,
    );
    my $upload_total = 0;

    foreach my $auction ( @$auctions ) {
       $upload_total = $upload_total + $auction->{ CopyCount} ;
    }

    $pb->{ SetProgressTotal     }   =   $upload_total;
    $pb->{ SetCurrentOperation  }   =   "Logging on to TradeMe";
    $pb->UpdateMultiBar();

    $tm->update_log("Logging in to TradeMe");
    $tm->login();

    # if login was not OK update error structure and return

    if ( $tm->{ ErrorStatus } ) {
        $tm->set_always_minimize( $pb->AlwaysMinimize() );
        $pb->QuitMultiBar();
        UpdateErrorStatus();   
        return $estruct;
    }

    AuctionUpload($auctions);

    $pb->MarkTaskCompleted(4);
    $pb->UpdateMultiBar();

    # Housekeeping for any clones that have been created but not loaded

    if ( scalar(@clonekeys) > 0 ) {

        foreach my $clonekey ( @clonekeys ) {

            $pb->{ SetCurrentOperation  }   =   "Performing clean up operations";
            $pb->UpdateMultiBar();
            $pb->ShowMultiBar();

            my $clonedata = $tm->get_auction_record( $clonekey );
            
            if ( $clonedata->{ AuctionStatus } = "PENDING" ) {
                $tm->delete_auction_record( $clonekey );
                $tm->update_log("Deleted Cloned Auction $clonedata->{ AuctionTitle } (Record $clonekey) - Aution did not load");
            }
        }
    }

    sleep 2;
    
    $tm->update_log("Completed: Load Pending auctions for Auction Cycle ".$cycle);

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # All Tasks completed
    #-----------------------------------------------------------------------------------------

    $tm->DBdisconnect();                          # disconnect from the database
    
    $tm->set_always_minimize( $pb->AlwaysMinimize() );
    $pb->QuitMultiBar();

    UpdateErrorStatus();   
    return $estruct;
}

#=============================================================================================
# LoadAll - Load all Pending Auctions
#=============================================================================================

sub LoadAll {

    $tm = Auctionitis->new();
    $tm->initialise(Product => "Auctionitis");  # Initialise the product

    $tm->update_log("Invoked Method: ". (caller(0))[3]); 

    $tm->{ Debug } ge "1" ? ( $tm->dump_properties() ) : () ;

    $pb = Win32::OLE->new('MultiPB.clsMultiPB') or die;

    ### insert some text into the window header

    $pb->InitialiseMultiBar();
    $pb->{ AlwaysMinimize       }   =   $tm->{ AlwaysMinimize };
    $pb->{ SetWindowTitle       }   =   "Auctionitis: Load All Auctions";
    
    # Tasks to be performed in this operation
    
    $pb->AddTask("Clone Auctions for upload");
    $pb->AddTask("Upload new picture files");
    $pb->AddTask("Check Picture Files on TradeMe");
    $pb->AddTask("Load all Pending auctions");

    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    # Initialise the TradeMe object
    
    $tm->update_log("Connecting to Database");
    $tm->DBconnect();                          # Connect to the database

    $tm->update_log("Logging in to TradeMe");
    $tm->login();

    # if login was not OK update error structure and return

    if ( $tm->{ ErrorStatus } ) {
        $tm->set_always_minimize( $pb->AlwaysMinimize() );
        $pb->QuitMultiBar();
        UpdateErrorStatus();   
        return $estruct;
    }    

    #-----------------------------------------------------------------------------------------
    # Task 1 - Clone auctions
    #-----------------------------------------------------------------------------------------
    
    $tm->update_log("Started: Clone Auctions for upload");

    $pb->{ SetCurrentTask       }   =   1;
    $pb->{ SetCurrentOperation  }   =   "Cloning Auctions";
    $pb->{ SetTaskAction        }   =   "Cloning Auctions from database for upload:";

    my $clones                      =   $tm->get_clone_auctions( AuctionSite => "TRADEME" );
    my $counter                     =   0;
    my $clone_total                 =   0;
    
    $pb->{ SetProgressTotal     }   =   scalar(@$clones);
    $pb->{ SetProgressCurrent   }   =   $counter;    
    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    foreach my $clone ( @$clones ) {
    
            $pb->{SetProgressCurrent} = $counter;    
            $pb->UpdateMultiBar();
            $pb->ShowMultiBar();
    
            my $newkey = $tm->copy_auction_record(
                AuctionKey       =>  $clone->{ AuctionKey } ,
                AuctionStatus    =>  "PENDING"              ,
            );

            push (@clonekeys, $newkey);    # Store the key of the new clone record

            $tm->update_log("Cloned Auction $clone->{AuctionTitle} (Record $clone->{AuctionTitle})");

            $counter++;

            if      ( $pb->{ Cancelled } ) {
                    CancelHandler();
                    return $estruct;
            }
    }

    $pb->MarkTaskCompleted(1);
    $pb->UpdateMultiBar();
    sleep 2;
    
    $tm->update_log("Completed: Clone Auctions for upload");

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # Task 2 - Process new photograhs
    #-----------------------------------------------------------------------------------------

    $tm->update_log("Started: Upload new picture files");

    $pb->{ SetCurrentTask       }   =   2;
    $pb->{ SetCurrentOperation  }   =   "Loading New pictures to TradeMe";
    $pb->{ SetTaskAction        }   =   "Uploading file:";
    $pb->UpdateMultiBar();

    my $pictures =  $tm->get_unloaded_pictures( AuctionSite => "TRADEME" );

    $pb->{ SetProgressTotal     }   =   scalar( @$pictures );
    $pb->UpdateMultiBar();

    if ( scalar(@$pictures) > 0 ) {

        PictureUpload($pictures);

        # Adjust the Auctionitis TM Picture total

        $tm->set_DB_property(
            Property_Name       => "TMPictureCount" ,
            Property_Value      => $tm->get_DB_property(Property_Name => "TMPictureCount", Property_Default => 0) + scalar(@$pictures),
        );

        $tm->update_log("Adjust TMPictureCount Property  - ".scalar( @$pictures )." new pictures");
    }
    
    $pb->MarkTaskCompleted(2);
    $pb->UpdateMultiBar();

    $tm->update_log("Completed: Load New Pictures");

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # Task 3 - Process expired photograhs
    #-----------------------------------------------------------------------------------------

    $tm->update_log("Started: Upload expired picture files");
    
    $pb->{ SetCurrentTask       }   =   3;
    $pb->{ SetCurrentOperation  }   =   "Retrieving TradeMe Picture data";
    $pb->{ SetTaskAction        }   =   "";

    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    # Compare the TradeMe picture count with the Auctionitis picture count

    my $TMPictotal  = $tm->get_TM_photo_count();
    my $DBPictotal  = $tm->get_DB_property(Property_Name => "TMPictureCount", Property_Default => 0);
    
    $tm->update_log("Picture Total on TradeMe  - $TMPictotal");
    $tm->update_log("Calculated Picture total  - $DBPictotal");

    # If the database total equals the TM picture total there are no expired pics (in theory...)
    
    if ( $DBPictotal eq $TMPictotal ) {

        $tm->update_log("Picture Totals reconciled - processing complete");
        $pb->{ SetTaskAction }   =   "Picture Totals reconciled - processing complete";

    }
    
    else {
    
        my @TMPictures = $tm->get_photo_list(\&UpdateStatusBar);

        my %TMPictable;

        foreach my $PhotoId ( @TMPictures ) {
            $TMPictable{ $PhotoId } = 1;
        }

        my $currentpictures = $tm->get_all_pictures();

        my @expiredpics;

        foreach my $picture ( @$currentpictures ) {

            if (not defined $TMPictable{ $picture->{ PhotoId } } ) {

                $tm->update_log("Located expired Photo $picture->{PictureFileName} (Record $picture->{PictureKey})");
                $pb->{ SetCurrentOperation  }   =   "Expired: $picture->{PictureFileName}";
                push(@expiredpics, $picture->{ PictureKey });
            }
        }

        # If any expired pics are encountered upload them to TradeMe

        if ( scalar(@expiredpics) > 0 ) {

            $pictures =  $tm->get_picture_records( @expiredpics );

            $pb->{ SetProgressTotal     }   =   scalar(@$pictures);
            $pb->UpdateMultiBar();

            PictureUpload($pictures);
        }

        #set the picture total in the database properties file

        my $TMPictotal  = $tm->get_TM_photo_count();

        $tm->set_DB_property(
            Property_Name       => "TMPictureCount" ,
            Property_Value      => $TMPictotal,
        );            
    }
    
    $pb->MarkTaskCompleted(3);
    $pb->UpdateMultiBar();

    $tm->update_log("Completed: Upload expired picture files");

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # Task 4 - Upload auctions
    #-----------------------------------------------------------------------------------------

    $tm->update_log("Started: Load all Pending auctions");

    $pb->{ SetCurrentTask       }   =   4;
    $pb->{ SetCurrentOperation  }   =   "Logging on to TradeMe";
    $pb->UpdateMultiBar();

    $tm->update_log("Logging in to TradeMe");
    $tm->login();
    
    # if login was not OK update error structure and return

    if ( $tm->{ ErrorStatus } ) {
        $tm->set_always_minimize( $pb->AlwaysMinimize() );
        $pb->QuitMultiBar();
        UpdateErrorStatus();   
        return $estruct;
    }

    $pb->{ SetTaskAction        }   =   "Loading auctions to TradeMe:";
    $pb->{ SetCurrentOperation  }   =   "Retrieving Auctions requiring upload";
    $pb->UpdateMultiBar();

    my $auctions = $tm->get_pending_auctions(
        AuctionSite =>  "TRADEME"   ,
    );

    my $upload_total =  0;

    foreach my $auction ( @$auctions ) {
       $upload_total = $upload_total + $auction->{ CopyCount };
    }

    $pb->{ SetProgressTotal } =  $upload_total;
    $pb->UpdateMultiBar();

    AuctionUpload($auctions);

    $pb->MarkTaskCompleted(4);
    $pb->UpdateMultiBar();

    # Housekeeping for any clones that have been created but not loaded

    if ( scalar(@clonekeys) > 0 ) {

        foreach my $clonekey ( @clonekeys ) {

            $pb->{ SetCurrentOperation  }   =   "Performing clean up operations";
            $pb->UpdateMultiBar();
            $pb->ShowMultiBar();

            my $clonedata = $tm->get_auction_record( $clonekey );
            
            if ( $clonedata->{ AuctionStatus } = "PENDING" ) {
                $tm->delete_auction_record( $clonekey );
                $tm->update_log("Deleted Cloned Auction $clonedata->{ AuctionTitle } (Record $clonekey) - Aution did not load");
            }
        }
    }

    $tm->update_log("Completed: Load all Pending auctions");

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
        return $estruct;
    }    

    #-----------------------------------------------------------------------------------------
    # All Tasks completed
    #-----------------------------------------------------------------------------------------

    $tm->DBdisconnect();                          # disconnect from the database
    
    sleep 2;
    $tm->set_always_minimize( $pb->AlwaysMinimize() );
    $pb->QuitMultiBar();

    UpdateErrorStatus();   
    return $estruct;
}

#=============================================================================================
# Relist - Relist an individual auction
#=============================================================================================

sub Relist {

    my $keylist =   shift;

    $tm = Auctionitis->new();
    $tm->initialise(Product => "Auctionitis");  # Initialise the product

    $tm->update_log("Invoked Method: ". (caller(0))[3]); 

    $tm->{ Debug } ge "1" ? ( $tm->dump_properties() ) : () ;

    $pb = Win32::OLE->new('MultiPB.clsMultiPB') or die;

    ### insert some text into the window header

    $pb->InitialiseMultiBar();
    $pb->{ AlwaysMinimize       }   =   $tm->{ AlwaysMinimize };
    $pb->{ SetWindowTitle       }   =   "Auctionitis: Relist Auction";

    $pb->AddTask("Relisting Auction on TradeMe");    

    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    $tm->update_log("Connecting to Database");
    $tm->DBconnect();                           # Connect to the database

    $tm->update_log("Logging in to TradeMe");
    $tm->login();
    
    # if login was not OK update error structure and return

    if ( $tm->{ ErrorStatus } ) {
        $tm->set_always_minimize( $pb->AlwaysMinimize() );
        $pb->QuitMultiBar();
        UpdateErrorStatus();   
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # Task 1 - Relist the actual auction
    #-----------------------------------------------------------------------------------------

    $tm->update_log("Started: Relist Auction");

    $pb->{ SetCurrentTask       }   =   1;
    $pb->{ SetCurrentOperation  }   =   "Preparing Auction for relist";
    $pb->{ SetTaskAction        }   =   "Loading auctions to TradeMe:";

    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();
    my $auctions                    =   $tm->get_auction_records(
        AuctionSite    => "TRADEME"    ,
        AuctionKeys    => $keylist     ,
   );


    $pb->{ SetProgressTotal     }   =   scalar(@$auctions);
    $pb->{ SetCurrentOperation  }   =   "Logging on to TradeMe";
    
    $pb->UpdateMultiBar();

    AuctionRelist($auctions);

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
        return $estruct;
    }

    $pb->MarkTaskCompleted(1);
    $pb->UpdateMultiBar();
    sleep 2;

    #-----------------------------------------------------------------------------------------
    # All Tasks completed
    #-----------------------------------------------------------------------------------------

    $tm->DBdisconnect();                          # disconnect from the database

    $tm->update_log("Completed: Relist Auction");

    $tm->set_always_minimize( $pb->AlwaysMinimize() );
    $pb->QuitMultiBar();

    UpdateErrorStatus();   
    return $estruct;
}

#=============================================================================================
# RelistSelected - Relist Selected Auctions
#=============================================================================================

sub RelistSelected {

    my $keylist = shift;

    $tm = Auctionitis->new();
    $tm->initialise(Product => "Auctionitis");  # Initialise the product

    $tm->update_log("Invoked Method: ". (caller(0))[3]); 

    $tm->{ Debug } ge "1" ? ( $tm->dump_properties() ) : () ;

    $pb = Win32::OLE->new('MultiPB.clsMultiPB') or die;

    ### insert some text into the window header

    $pb->InitialiseMultiBar();
    $pb->{ AlwaysMinimize       }   =   $tm->{ AlwaysMinimize };
    $pb->{ SetWindowTitle       }   =   "Auctionitis: Relist Selected Auctions";

    $pb->AddTask("Load New Pictures to TradeMe");
    $pb->AddTask("Check Picture Files on TradeMe");
    $pb->AddTask("Relisting Selected Auctions to TradeMe");

    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    # Initialise the Trademe object
    
    $tm->update_log("Connecting to Database");
    $tm->DBconnect();                           # Connect to the database

    $tm->update_log("Logging in to TradeMe");
    $tm->login();
    
    # if login was not OK update error structure and return

    if ( $tm->{ ErrorStatus } ) {
        $tm->set_always_minimize( $pb->AlwaysMinimize() );
        $pb->QuitMultiBar();
        UpdateErrorStatus();   
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # Task 1 - Process New pictures
    #-----------------------------------------------------------------------------------------

    $tm->update_log("Started: Load New Pictures");

    $pb->{ SetCurrentTask       }   =   1;
    $pb->{ SetCurrentOperation  }   =   "Loading New pictures to TradeMe";
    $pb->{ SetTaskAction        }   =   "Uploading file:";
    $pb->UpdateMultiBar();

    my $pictures =  $tm->get_selected_unloaded_pictures(
         AuctionSite    => "TRADEME"    ,
         AuctionKeys    =>  $keylist    ,
    );

    $pb->{ SetProgressTotal     }   =   scalar( @$pictures );
    $pb->UpdateMultiBar();
    
    if ( scalar( @$pictures ) ne 0 ) {

         my $uploadedpics = PictureUpload( $pictures );

        # Adjust the Auctionitis TM Picture total

        $tm->set_DB_property(
            Property_Name       => "TMPictureCount" ,
            Property_Value      => $tm->get_DB_property( Property_Name => "TMPictureCount", Property_Default => 0 ) + $uploadedpics,
        );
        $tm->update_log("Adjust TMPictureCount Property  - ".$uploadedpics." new pictures");
    }
    
    $pb->MarkTaskCompleted(1);
    $pb->UpdateMultiBar();
    sleep 2;
    
    $tm->update_log("Completed: Load New Pictures");

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # Task 2 - Process Expired Pictures
    #-----------------------------------------------------------------------------------------

    $tm->update_log("Started: Check Picture Files on TradeMe");
    
    $pb->{ SetCurrentTask       }   =   2;
    $pb->{ SetCurrentOperation  }   =   "Retrieving TradeMe Picture data";
    $pb->{ SetTaskAction        }   =   "";
    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();
    
    # Compare the TradeMe picture count with the Auctionitis picture count

    my $TMPictotal  = $tm->get_TM_photo_count();
    my $DBPictotal  = $tm->get_DB_property(Property_Name => "TMPictureCount", Property_Default => 0);
    
    $tm->update_log("Picture Total on TradeMe  - $TMPictotal");
    $tm->update_log("Calculated Picture total  - $DBPictotal");

    # If the database total equals the TM picture total there are no expired pics (in theory...)
    
    if ( $DBPictotal eq $TMPictotal ) {

        $tm->update_log("Picture Totals reconciled - processing complete");
        $pb->{ SetTaskAction }   =   "Picture Totals reconciled - processing complete";

    }
    
    else {

        my @TMPictures = $tm->get_photo_list(\&UpdateStatusBar);

        my %TMPictable;

        foreach my $PhotoId ( @TMPictures ) {
            $TMPictable{ $PhotoId } = 1;
        }

        my @expiredpics;
        my $selectedpictures;

        my $picturekeys = $tm->get_selected_used_picture_keys(  
            AuctionSite => "TRADEME"    ,
            AuctionKeys => $keylist    ,
        );

        # Build the expired pics array if the auctions actually have pictures

        if ( ( defined( $picturekeys ) ) and ( scalar( @$picturekeys ) > 0 ) ) {

             $selectedpictures = $tm->get_picture_records( @$picturekeys );

             foreach my $picture ( @$selectedpictures ) {

                if  ( not defined $TMPictable{ $picture->{ PhotoId } } ) {
                     $tm->update_log( "Located expired Photo $picture->{ PictureFileName } (Record $picture->{ PictureKey })");
                     $pb->{ SetCurrentOperation  }   =   "Expired: $picture->{ PictureFileName }";
                     push( @expiredpics, $picture->{ PictureKey } );
                }
             }
        }

        # If we have some expired pictures then load them

        if ( scalar(@expiredpics) > 0 ) {

            my $pictures =  $tm->get_picture_records( @expiredpics );

            $pb->{ SetProgressTotal     }   =   @$pictures;
            $pb->UpdateMultiBar();

            PictureUpload($pictures);
        }

        #set the picture total in the database properties file

        my $TMPictotal  = $tm->get_TM_photo_count();

        $tm->set_DB_property(
            Property_Name       => "TMPictureCount" ,
            Property_Value      => $TMPictotal,
        );            
    }
    
    $pb->MarkTaskCompleted(2);
    $pb->UpdateMultiBar();
    sleep 2;

    $tm->update_log("Completed: Check Picture Files on TradeMe");

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
        return $estruct;
    }
    
    sleep 2;

    #-----------------------------------------------------------------------------------------
    # Task 3 - Relist Selected Auctions
    #-----------------------------------------------------------------------------------------

    $tm->update_log("Started: Relist Selected Auctions");

    $pb->{ SetCurrentTask       }   =   3;
    $pb->{ SetCurrentOperation  }   =   "Preparing Auctions for relist";
    $pb->{ SetTaskAction        }   =   "Relisting auctions to TradeMe:";

    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    my $auctions                    =   $tm->get_auction_records(
        AuctionSite    => "TRADEME"    ,
        AuctionKeys    =>  $keylist    ,
   );

    my $upload_total                =   0;

    foreach my $auction ( @$auctions ) {
            $upload_total = $upload_total + $auction->{ CopyCount };
    }

    $pb->{ SetProgressTotal     }   =   @$auctions;
    $pb->{ SetCurrentOperation  }   =   "Logging on to TradeMe";
    $pb->UpdateMultiBar();

    AuctionRelist($auctions);

    $pb->MarkTaskCompleted(3);
    $pb->UpdateMultiBar();
    sleep 2;
    
    $tm->update_log("Completed: Relist Selected Auctions");
 
    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # All Tasks completed
    #-----------------------------------------------------------------------------------------
    
    $tm->DBdisconnect();                          # disconnect from the database

    $tm->set_always_minimize( $pb->AlwaysMinimize() );
    $pb->QuitMultiBar();

    UpdateErrorStatus();   
    return $estruct;
}

#=============================================================================================
# RelistCycle - Relist Auctions for a selected Auction Cycyle
#=============================================================================================

sub RelistCycle {

    my $cycle       =   shift;

    $tm = Auctionitis->new();
    $tm->initialise(Product => "Auctionitis");  # Initialise the product

    $tm->update_log("Invoked Method: ". (caller(0))[3]); 

    $tm->{ Debug } ge "1" ? ( $tm->dump_properties() ) : () ;

    $pb = Win32::OLE->new('MultiPB.clsMultiPB') or die;

    ### insert some text into the window header

    $pb->InitialiseMultiBar();
    $pb->{ AlwaysMinimize       }   =   $tm->{ AlwaysMinimize };
    $pb->{ SetWindowTitle       }   =   "Auctionitis: Relist Auction Cycle $cycle";

    $pb->AddTask("Update Sold Auction Data");
    $pb->AddTask("Update Unsold Auction Data");
    $pb->AddTask("Check Picture Files on TradeMe");
    $pb->AddTask("Relist all auctions in cycle ".$cycle);

    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    # Initialise the TradeMe object

    $tm->update_log("Connecting to Database");
    $tm->DBconnect();                          # Connect to the database
    
    $tm->update_log("Logging in to TradeMe");
    $tm->login();
    
    # if login was not OK update error structure and return

    if ( $tm->{ ErrorStatus } ) {
        $tm->set_always_minimize( $pb->AlwaysMinimize() );
        $pb->QuitMultiBar();
        UpdateErrorStatus();   
        return $estruct;
    }

    $tm->update_log("Relist all auctions in cycle ".$cycle); 

    #-----------------------------------------------------------------------------------------
    # Task 1 - Process Sold Auctions
    #-----------------------------------------------------------------------------------------
    
    $tm->update_log("Started: Process Sold Auctions");
    
    my $auctions;
    
    $pb->{ SetCurrentTask       }   =   1;
    $pb->{ SetCurrentOperation  }   =   "Retrieving Sold Auction Data";
    $pb->{ SetTaskAction        }   =   "Updating auction:";
    
    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    $auctions = $tm->new_get_sold_listings( StatusHandler => \&UpdateStatusBar );

    if ( defined(@$auctions) ) {
         UpdateSoldAuctions($auctions, "SOLD");
    }
    
    $pb->MarkTaskCompleted(1);
    $pb->UpdateMultiBar();
    sleep 2;
    
    $tm->update_log("Completed: Process Sold Auctions");

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # Task 2 - Process Unsold Auctions
    #-----------------------------------------------------------------------------------------

    $tm->update_log("Started: Process Unsold Auctions");

    $pb->{ SetCurrentTask       }   =   2;
    $pb->{ SetCurrentOperation  }   =   "Retrieving Unsold Auction Data";
    $pb->{ SetTaskAction        }   =   "Updating auction:";
    
    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    $auctions = $tm->get_unsold_listings(\&UpdateStatusBar);

    if ( defined(@$auctions) ) {
         UpdateUnsoldAuctions($auctions, "UNSOLD");
    }
    
    $pb->MarkTaskCompleted(2);
    $pb->UpdateMultiBar();
    sleep 2;
    
    $tm->update_log("Completed: Process Unsold Auctions");

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
        return $estruct;
    }
    
    #-----------------------------------------------------------------------------------------
    # Task 3 - Process Expired Pictures
    #-----------------------------------------------------------------------------------------

    $tm->update_log("Started: Check Picture Files on TradeMe");
    
    $pb->{ SetCurrentTask       }   =   3;
    $pb->{ SetCurrentOperation  }   =   "Retrieving TradeMe Picture data";
    $pb->{ SetTaskAction        }   =   "";
    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    # Compare the TradeMe picture count with the Auctionitis picture count

    my $TMPictotal  = $tm->get_TM_photo_count();
    my $DBPictotal  = $tm->get_DB_property(Property_Name => "TMPictureCount", Property_Default => 0);
    
    $tm->update_log("Picture Total on TradeMe  - $TMPictotal");
    $tm->update_log("Calculated Picture total  - $DBPictotal");

    # If the database total equals the TM picture total there are no expired pics (in theory...)
    
    if ( $DBPictotal eq $TMPictotal ) {

        $tm->update_log("Picture Totals reconciled - processing complete");
        $pb->{ SetTaskAction }   =   "Picture Totals reconciled - processing complete";

    }
    
    else {
    
        my @TMPictures = $tm->get_photo_list(\&UpdateStatusBar);

        my %TMPictable;

        foreach my $PhotoId ( @TMPictures ) {
            $TMPictable{ $PhotoId } = 1;
        }

        my $currentpictures = $tm->get_all_pictures();

        my @expiredpics;

        foreach my $picture ( @$currentpictures ) {

            if (not defined $TMPictable{ $picture->{ PhotoId } } ) {
                $tm->update_log("Located expired Photo $picture->{PictureFileName} (Record $picture->{PictureKey})");
                $pb->{ SetCurrentOperation  }   =   "Expired: $picture->{PictureFileName}";
                push(@expiredpics, $picture->{ PictureKey });
            }
        }

        if ( scalar(@expiredpics) > 0 ) {

            my $pictures =  $tm->get_picture_records( @expiredpics );

            $pb->{ SetProgressTotal     }   =   @$pictures;
            $pb->UpdateMultiBar();

            PictureUpload($pictures);
        }

        #set the picture total in the database properties file

        my $TMPictotal  = $tm->get_TM_photo_count();

        $tm->set_DB_property(
            Property_Name       => "TMPictureCount" ,
            Property_Value      => $TMPictotal,
        );            
    }
    
    $pb->MarkTaskCompleted(3);
    $pb->UpdateMultiBar();
    sleep 2;

    $tm->update_log("Completed: Check Picture Files on TradeMe");

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # Task 4 - Relist Auction cycle
    #-----------------------------------------------------------------------------------------

    $tm->update_log("Started: Relist Auction cycle $cycle");
    
    $pb->{ SetCurrentTask       }   =   4;
    $pb->{ SetCurrentOperation  }   =   "Retrieving Auctions for $cycle";
    $pb->{ SetTaskAction        }   =   "Relistinging auctions to TradeMe:";

    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    my $auctions                    =   $tm->get_cycle_relists(
        AuctionSite     => "TRADEME",
        AuctionCycle    => $cycle   ,
    );

    my $upload_total                =   0;

    foreach my $auction ( @$auctions ) {
       $upload_total = $upload_total + $auction->{ CopyCount };
    }

    $pb->{ SetProgressTotal     }   =   $upload_total;
    $pb->UpdateMultiBar();
    
    if ( scalar( @$auctions ) > 0 ) {
        AuctionRelist($auctions);
    }

    $pb->MarkTaskCompleted(4);
    $pb->UpdateMultiBar();
    sleep 2;
    
    $tm->update_log("Completed: Relist Auction cycle $cycle");

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # All Tasks completed
    #-----------------------------------------------------------------------------------------

    $tm->DBdisconnect();                          # disconnect from the database
   
    $tm->set_always_minimize( $pb->AlwaysMinimize() );
    $pb->QuitMultiBar();

    UpdateErrorStatus();   
    return $estruct;
}

#=============================================================================================
# RelistAll - Relist all eligible auctions
#=============================================================================================

sub RelistAll {

    $tm = Auctionitis->new();
    $tm->initialise(Product => "Auctionitis");  # Initialise the product

    $tm->update_log("Invoked Method: ". (caller(0))[3]); 

    $tm->{ Debug } ge "1" ? ( $tm->dump_properties() ) : () ;

    $pb = Win32::OLE->new('MultiPB.clsMultiPB') or die;

    ### insert some text into the window header

    $pb->InitialiseMultiBar();
    $pb->{ AlwaysMinimize       }   =   $tm->{ AlwaysMinimize };
    $pb->{ SetWindowTitle       }   =   "Auctionitis: Relist All Auctions";
    
    $pb->AddTask("Update Sold Auction Data");
    $pb->AddTask("Update Unsold Auction Data");
    $pb->AddTask("Check Picture Files on TradeMe");
    $pb->AddTask("Relist All Eligible auctions");

    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();
    
    $pb->{ SetCurrentTask       }   =   1;
    $pb->{ SetCurrentOperation  }   =   "Retrieving Auctions eligible for relist";
    $pb->{ SetTaskAction        }   =   "Loading auctions to TradeMe:";
    
    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    # Instantiate the TradeMe object

    $tm->update_log("Connecting to Database");
    $tm->DBconnect();                          # Connect to the database

    $tm->update_log("Logging in to TradeMe");
    $tm->login();
    
    # if login was not OK update error structure and return

    if ( $tm->{ ErrorStatus } ) {
        $tm->set_always_minimize( $pb->AlwaysMinimize() );
        $pb->QuitMultiBar();
        UpdateErrorStatus();   
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # Task 1 - Process Sold Auctions
    #-----------------------------------------------------------------------------------------
    
    $tm->update_log("Started: Process Sold Auctions");
    
    my $auctions;
    
    $pb->{ SetCurrentTask       }   =   1;
    $pb->{ SetCurrentOperation  }   =   "Retrieving Sold Auction Data";
    $pb->{ SetTaskAction        }   =   "Updating auction:";
    
    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    $auctions = $tm->new_get_sold_listings( StatusHandler => \&UpdateStatusBar );
    
    if ( defined(@$auctions) ) {
         UpdateSoldAuctions($auctions, "SOLD");
    }
    
    $pb->MarkTaskCompleted(1);
    $pb->UpdateMultiBar();
    sleep 2;
    
    $tm->update_log("Completed: Process Sold Auctions");

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # Task 2 - Process Unsold Auctions
    #-----------------------------------------------------------------------------------------

    $tm->update_log("Started: Process Unsold Auctions");

    $pb->{ SetCurrentTask       }   =   2;
    $pb->{ SetCurrentOperation  }   =   "Retrieving Unsold Auction Data";
    $pb->{ SetTaskAction        }   =   "Updating auction:";
    
    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    $auctions = $tm->get_unsold_listings(\&UpdateStatusBar);
    
    if ( defined(@$auctions) ) {
         UpdateUnsoldAuctions($auctions, "UNSOLD");
    }
    
    $pb->MarkTaskCompleted(2);
    $pb->UpdateMultiBar();

    $tm->update_log("Completed: Process Unsold Auctions");

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
        return $estruct;
    }
 

    #-----------------------------------------------------------------------------------------
    # Task 3 - Process Expired Pictures
    #-----------------------------------------------------------------------------------------

    $tm->update_log("Started: Check Picture Files on TradeMe");
    
    $pb->{ SetCurrentTask       }   =   3;
    $pb->{ SetCurrentOperation  }   =   "Retrieving TradeMe Picture data";
    $pb->{ SetTaskAction        }   =   "";
    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();
    
    # Compare the TradeMe picture count with the Auctionitis picture count

    my $TMPictotal  = $tm->get_TM_photo_count();
    my $DBPictotal  = $tm->get_DB_property(Property_Name => "TMPictureCount", Property_Default => 0);
    
    $tm->update_log("Picture Total on TradeMe  - $TMPictotal");
    $tm->update_log("Calculated Picture total  - $DBPictotal");

    # If the database total equals the TM picture total there are no expired pics (in theory...)
    
    if ( $DBPictotal eq $TMPictotal ) {

        $tm->update_log("Picture Totals reconciled - processing complete");
        $pb->{ SetTaskAction }   =   "Picture Totals reconciled - processing complete";

    }
    
    else {

        my @TMPictures = $tm->get_photo_list(\&UpdateStatusBar);

        my %TMPictable;

        foreach my $PhotoId ( @TMPictures ) {
            $TMPictable{ $PhotoId } = 1;
        }

        my $currentpictures = $tm->get_all_pictures();

        my @expiredpics;

        foreach my $picture ( @$currentpictures ) {

            if (not defined $TMPictable{ $picture->{ PhotoId } } ) {
                $tm->update_log("Located expired Photo $picture->{PictureFileName} (Record $picture->{PictureKey})");
                $pb->{ SetCurrentOperation  }   =   "Expired: $picture->{PictureFileName}";
                push(@expiredpics, $picture->{ PictureKey });
            }
        }

        if ( scalar(@expiredpics) > 0 ) {

            my $pictures =  $tm->get_picture_records( @expiredpics );

            $pb->{ SetProgressTotal     }   =   @$pictures;
            $pb->UpdateMultiBar();

            PictureUpload($pictures);
        }

        #set the picture total in the database properties file

        my $TMPictotal  = $tm->get_TM_photo_count();

        $tm->set_DB_property(
            Property_Name       => "TMPictureCount" ,
            Property_Value      => $TMPictotal,
        );            
    }
    
    $pb->MarkTaskCompleted(3);
    $pb->UpdateMultiBar();
    sleep 2;

    $tm->update_log("Completed: Check Picture Files on TradeMe");

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
        return $estruct;
    }
    
    #-----------------------------------------------------------------------------------------
    # Task 4 - Process auctions elgible for relists
    #-----------------------------------------------------------------------------------------

    $tm->update_log("Started: Relist Elegible Auctions");

    $pb->{ SetCurrentTask       }   =   4;
    $pb->{ SetTaskAction        }   =   "Relisting auction:";

    my $auctions                    =   $tm->get_standard_relists();
    my $upload_total                =   0;

    foreach my $auction (@$auctions) {
       $upload_total = $upload_total + $auction->{CopyCount};
    }

    $pb->{ SetProgressTotal     }   =   $upload_total;
    $pb->UpdateMultiBar();

    AuctionRelist($auctions);

    $pb->MarkTaskCompleted(4);
    $pb->UpdateMultiBar();
    sleep 2;
    
    $tm->update_log("Started: Relist Elegible Auctions");

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # All Tasks completed
    #-----------------------------------------------------------------------------------------
        
    $tm->DBdisconnect();                          # disconnect from the database

    $tm->set_always_minimize( $pb->AlwaysMinimize() );
    $pb->QuitMultiBar();

    UpdateErrorStatus();   
    return $estruct;
}

#=============================================================================================
# Offer a single Auction on TradeMe
#=============================================================================================

sub Offer {

    my $keylist  =   shift;

    $tm = Auctionitis->new();
    $tm->initialise(Product => "Auctionitis");  # Initialise the product
    
    $tm->update_log("Invoked Method: ". (caller(0))[3]); 

    $tm->{ Debug } ge "1" ? ( $tm->dump_properties() ) : () ;
    
    $pb = Win32::OLE->new('MultiPB.clsMultiPB') or die;

    ### insert some text into the window header

    $pb->InitialiseMultiBar();
    $pb->{ AlwaysMinimize       }   =   $tm->{ AlwaysMinimize };
    $pb->{ SetWindowTitle       }   =   "Auctionitis: Offer Auction";
    $pb->{ SetProgressCurrent   }   =   0;
    $pb->{ SetProgressTotal     }   =   0;
    
    $pb->AddTask("Offering Auction on TradeMe");

    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    $tm->update_log("Connecting to Database");
    $tm->DBconnect();                          # Connect to the database

    $tm->update_log("Logging in to TradeMe");
    $tm->login();

    # if login was not OK update error structure and return

    if ( $tm->{ ErrorStatus } ) {
        $tm->set_always_minimize( $pb->AlwaysMinimize() );
        $pb->QuitMultiBar();
        UpdateErrorStatus();   
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # Task 1 - Offer Auction
    #-----------------------------------------------------------------------------------------

    $tm->update_log("Started: Offer Auction on Trademe");

    $pb->{ SetCurrentTask       }   =   1;
    $pb->{ SetCurrentOperation  }   =   "Preparing Auction for upload";
    $pb->{ SetTaskAction        }   =   "Loading auctions to TradeMe:";

    my $auctions = $tm->get_auction_records(
        AuctionSite    => "TRADEME"    ,
        AuctionKeys    =>  $keylist    ,
   );

    $pb->{ SetProgressTotal     }   = @$auctions;
    $pb->{ SetCurrentOperation  }   = "Logging on to TradeMe";
    
    $pb->UpdateMultiBar();

    if ( scalar( @$auctions ) gt 0 ) {
        AuctionOffer( $auctions );
    }

    $pb->MarkTaskCompleted(1);
    $pb->UpdateMultiBar();
    sleep 2;
    
    $tm->update_log("Completed: Offer Auction on TradeMe");

    #-----------------------------------------------------------------------------------------
    # All Tasks completed
    #-----------------------------------------------------------------------------------------

    $tm->DBdisconnect();                          # disconnect from the database

    $tm->set_always_minimize( $pb->AlwaysMinimize() );
    $pb->QuitMultiBar();
    
    UpdateErrorStatus();   
    return $estruct;
}


#=============================================================================================
# Offer selected Auction on TradeMe
#=============================================================================================

sub OfferSelected {

    my $keylist  =   shift;

    $tm = Auctionitis->new();
    $tm->initialise(Product => "Auctionitis");  # Initialise the product
    
    $tm->update_log("Invoked Method: ". (caller(0))[3]); 

    $tm->{ Debug } ge "1" ? ( $tm->dump_properties() ) : () ;
    
    $pb = Win32::OLE->new('MultiPB.clsMultiPB') or die;

    ### insert some text into the window header

    $pb->InitialiseMultiBar();
    $pb->{ AlwaysMinimize       }   =   $tm->{ AlwaysMinimize };
    $pb->{ SetWindowTitle       }   =   "Auctionitis: Offer Selected Auctions";
    $pb->{ SetProgressCurrent   }   =   0;
    $pb->{ SetProgressTotal     }   =   0;
    
    $pb->AddTask("Offering Auction on TradeMe");

    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    $tm->update_log("Connecting to Database");
    $tm->DBconnect();                          # Connect to the database

    $tm->update_log("Logging in to TradeMe");
    $tm->login();

    # if login was not OK update error structure and return

    if ( $tm->{ ErrorStatus } ) {
        $tm->set_always_minimize( $pb->AlwaysMinimize() );
        $pb->QuitMultiBar();
        UpdateErrorStatus();   
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # Task 1 - Offer Auction
    #-----------------------------------------------------------------------------------------

    $tm->update_log("Started: Offer Auction on Trademe");

    $pb->{ SetCurrentTask       }   =   1;
    $pb->{ SetCurrentOperation  }   =   "Preparing Auction for upload";
    $pb->{ SetTaskAction        }   =   "Loading auctions to TradeMe:";

    my $auctions = $tm->get_auction_records(
        AuctionSite    => "TRADEME"    ,
        AuctionKeys    =>  $keylist    ,
   );

    $pb->{ SetProgressTotal     }   = @$auctions;
    $pb->{ SetCurrentOperation  }   = "Logging on to TradeMe";
    
    $pb->UpdateMultiBar();
    
    if ( scalar( @$auctions ) gt 0 ) {
        AuctionOffer( $auctions );
    }

    $pb->MarkTaskCompleted(1);
    $pb->UpdateMultiBar();
    sleep 2;
    
    $tm->update_log("Completed: Offer Auction on TradeMe");

    #-----------------------------------------------------------------------------------------
    # All Tasks completed
    #-----------------------------------------------------------------------------------------

    $tm->DBdisconnect();                          # disconnect from the database

    $tm->set_always_minimize( $pb->AlwaysMinimize() );
    $pb->QuitMultiBar();
    
    UpdateErrorStatus();   
    return $estruct;
}

#=============================================================================================
# OfferAll - Make offers on all eligible auctions
#=============================================================================================

sub OfferAll {

    $tm = Auctionitis->new();
    $tm->initialise(Product => "Auctionitis");  # Initialise the product

    $tm->update_log("Invoked Method: ". (caller(0))[3]); 

    $tm->{ Debug } ge "1" ? ( $tm->dump_properties() ) : () ;

    $pb = Win32::OLE->new('MultiPB.clsMultiPB') or die;

    ### insert some text into the window header

    $pb->InitialiseMultiBar();
    $pb->{ AlwaysMinimize       }   =   $tm->{ AlwaysMinimize };
    $pb->{ SetWindowTitle       }   =   "Auctionitis: Process All Offers";
    
    # Tasks to be performed in this operation
    
    $pb->AddTask("Update Sold Auctions");
    $pb->AddTask("Update Unsold Auctions");
    $pb->AddTask("Process Fixed Price Offers");

    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    # Initialise the TradeMe object
    
    $tm->update_log("Connecting to Database");
    $tm->DBconnect();                          # Connect to the database

    $tm->update_log("Logging in to TradeMe");
    $tm->login();

    # if login was not OK update error structure and return

    if ( $tm->{ ErrorStatus } ) {
        $tm->set_always_minimize( $pb->AlwaysMinimize() );
        $pb->QuitMultiBar();
        UpdateErrorStatus();   
        return $estruct;
    }    

    #-----------------------------------------------------------------------------------------
    # Task 1 - Process Sold Auctions
    #-----------------------------------------------------------------------------------------
    
    $tm->update_log("Started: Process Sold Auctions");
    
    my $auctions;
    
    $pb->{ SetCurrentTask       }   =   1;
    $pb->{ SetCurrentOperation  }   =   "Retrieving Sold Auction Data";
    $pb->{ SetTaskAction        }   =   "Updating auction:";
    
    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    $auctions = $tm->new_get_sold_listings(  StatusHandler => \&UpdateStatusBar  );

    if ( defined( @$auctions ) ) {
         UpdateSoldAuctions( $auctions, "SOLD" );
    }
    
    $pb->MarkTaskCompleted(1);
    $pb->UpdateMultiBar();
    sleep 2;
    
    $tm->update_log( "Completed: Process Sold Auctions" );

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # Task 2 - Process Unsold Auctions
    #-----------------------------------------------------------------------------------------

    $tm->update_log("Started: Process Unsold Auctions");

    $pb->{ SetCurrentTask       }   =   2;
    $pb->{ SetCurrentOperation  }   =   "Retrieving Unsold Auction Data";
    $pb->{ SetTaskAction        }   =   "Updating auction:";
    
    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    $auctions = $tm->get_unsold_listings( \&UpdateStatusBar );

    if ( defined( @$auctions ) ) {
         UpdateUnsoldAuctions( $auctions, "UNSOLD" );
    }
    
    $pb->MarkTaskCompleted(2);
    $pb->UpdateMultiBar();
    sleep 2;
    
    $tm->update_log( "Completed: Process Unsold Auctions" );

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # Task 3 - process all Eligible Offers
    #-----------------------------------------------------------------------------------------

    $tm->update_log("Started: Process All Offers");
    
    $pb->{ SetCurrentTask       }   =   3;
    $pb->{ SetCurrentOperation  }   =   "Processing All Outstanding Offers";
    $pb->{ SetTaskAction        }   =   "";

    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    # Get the list auctions to be offered from the database
    # Select list type based on what kind of offers have been selected

    my $offers;

    if ( ( $tm->{ OfferSold } eq "1" ) and ( $tm->{ OfferUnsold } eq "1" ) ) {
        $offers = $tm->get_pending_offers( "ALL" );
    }

    if ( ( $tm->{ OfferSold } eq "1" ) and ( $tm->{ OfferUnsold } eq "0" ) ) {
        $offers = $tm->get_pending_offers( "SOLD" );
    }

    if ( ( $tm->{ OfferSold } eq "0" ) and ( $tm->{ OfferUnsold } eq "1" ) ) {
        $offers = $tm->get_pending_offers( "UNSOLD" );
    }

    my $offertotal = 0;

    if ( defined( @$offers ) ) {
        $offertotal = scalar( @$offers );
    }

    $pb->{ SetProgressTotal } = $offertotal;
    $tm->update_log( $offertotal." Pending Offers Retrieved from database" );

    if ( scalar( @$offers ) gt 0 ) {
        AuctionOffer( $offers );
    }

    # Finished processing
    
    $pb->MarkTaskCompleted(3);
    $pb->UpdateMultiBar();

    $tm->update_log("Completed: Process All Offers");

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # All Tasks completed
    #-----------------------------------------------------------------------------------------

    $tm->DBdisconnect();                          # disconnect from the database
    
    sleep 2;
    $tm->set_always_minimize( $pb->AlwaysMinimize() );
    $pb->QuitMultiBar();

    UpdateErrorStatus();   
    return $estruct;
}

#=============================================================================================
# LoadSchedule - Load items as per the Auctionitis schedule value
#=============================================================================================

sub LoadSchedule {

    my $day         = shift;
    my $currenttask = 0;
    my @clonekeys;

    $tm = Auctionitis->new();
    $tm->initialise(Product => "Auctionitis");  # Initialise the product

    $tm->update_log("Invoked Method: ". (caller(0))[3]); 

    $tm->{ Debug } ge "1" ? ( $tm->dump_properties() ) : () ;

    $pb = Win32::OLE->new('MultiPB.clsMultiPB') or die;

    ### insert some text into the window header

    $pb->InitialiseMultiBar();
    $pb->{ AlwaysMinimize       }   =   $tm->{ AlwaysMinimize };
    $pb->{ SetWindowTitle       }   =   "Auctionitis: Process Schedule Items";

    # Get the schedule data

    $tm->set_Schedule_properties( $day );
    
    # Tasks to be performed in this operation

    $pb->AddTask("Upload new picture files");
    $pb->AddTask("Check Picture Files on TradeMe");
    $pb->AddTask("Update Sold Auction Data");
    $pb->AddTask("Update Unsold Auction Data");
    
    if ( $tm->{ LoadAll } ) {
        $pb->AddTask("Clone Auctions for upload");
        $pb->AddTask("Load all Pending auctions");
    }

    if ( $tm->{ LoadCycle } ) {
        $pb->AddTask("Clone Auctions for Auction Cycle ".$tm->{ LoadCycleName });
        $pb->AddTask("Load Pending auctions for Auction Cycle ".$tm->{ LoadCycleName });
    }

    if ( $tm->{ OfferAll } ) {
        $pb->AddTask("Process Fixed Price Offers");
    }

    if ( $tm->{ RelistAll } ) {
        $pb->AddTask("Relist All Eligible auctions");
    }
    
    if ( $tm->{ RelistCycle } ) {
        $pb->AddTask("Relist all auctions in cycle ".$tm->{ RelistCycleName });
    }

    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();
    
    # Instantiate the TradeMe object

    $tm->update_log("Connecting to Database");
    $tm->DBconnect();                          # Connect to the database

    $tm->update_log("Logging in to TradeMe");
    $tm->login();
    
    # if login was not OK update error structure and return

    if ( $tm->{ ErrorStatus } ) {
        $tm->set_always_minimize( $pb->AlwaysMinimize() );
        $pb->QuitMultiBar();
        UpdateErrorStatus();   
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # Task 1 - Process new photograhs
    #-----------------------------------------------------------------------------------------

    $tm->update_log("Started: Upload new picture files");

    $currenttask++;

    $pb->{ SetCurrentTask       }   =   $currenttask;
    $pb->{ SetCurrentOperation  }   =   "Loading New pictures to TradeMe";
    $pb->{ SetTaskAction        }   =   "Uploading file:";
    $pb->UpdateMultiBar();

    my $pictures =  $tm->get_unloaded_pictures( AuctionSite => "TRADEME" );

    if ( scalar(@$pictures) > 0 ) {

        $pb->{ SetProgressTotal     }   =   scalar(@$pictures);
        $pb->UpdateMultiBar();

        $tm->update_log("Logging in to TradeMe");
        $tm->login();

        # if login was not OK update error structure and return

        if ( $tm->{ ErrorStatus } ) {
            $tm->set_always_minimize( $pb->AlwaysMinimize() );
            $pb->QuitMultiBar();
            UpdateErrorStatus();   
            return $estruct;
        }    

        PictureUpload($pictures);

        # Adjust the Auctionitis TM Picture total

        $tm->set_DB_property(
            Property_Name       => "TMPictureCount" ,
            Property_Value      => $tm->get_DB_property(Property_Name => "TMPictureCount", Property_Default => 0) + scalar(@$pictures),
        );

        $tm->update_log("Adjust TMPictureCount Property  - ".scalar(@$pictures)." new pictures");
    }

    $pb->MarkTaskCompleted($currenttask);
    $pb->UpdateMultiBar();
    sleep 2;

    $tm->update_log("Completed: Upload new picture files");

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # Task 2 - Process expired photograhs
    #-----------------------------------------------------------------------------------------

    $tm->update_log("Started: Upload expired picture files");
    
    $currenttask++;

    $pb->{ SetCurrentTask       }   =   $currenttask;
    $pb->{ SetCurrentOperation  }   =   "Retrieving TradeMe Picture data";
    $pb->{ SetTaskAction        }   =   "";

    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    # Compare the TradeMe picture count with the Auctionitis picture count

    my $TMPictotal  = $tm->get_TM_photo_count();
    my $DBPictotal  = $tm->get_DB_property(Property_Name => "TMPictureCount", Property_Default => 0);
    
    $tm->update_log("Picture Total on TradeMe  - $TMPictotal");
    $tm->update_log("Calculated Picture total  - $DBPictotal");

    # If the database total equals the TM picture total there are no expired pics (in theory...)
    
    if ( $DBPictotal eq $TMPictotal ) {

        $tm->update_log("Picture Totals reconciled - processing complete");
        $pb->{ SetTaskAction }   =   "Picture Totals reconciled - processing complete";

    }
    
    else {

        my @TMPictures = $tm->get_photo_list(\&UpdateStatusBar);

        my %TMPictable;

        foreach my $PhotoId ( @TMPictures ) {
            $TMPictable{ $PhotoId } = 1;
        }

        my $currentpictures = $tm->get_all_pictures();

        my @expiredpics;

        foreach my $picture ( @$currentpictures ) {

            if (not defined $TMPictable{ $picture->{ PhotoId } } ) {

                $tm->update_log("Located expired Photo $picture->{PictureFileName} (Record $picture->{PictureKey})");
                $pb->{ SetCurrentOperation  }   =   "Expired: $picture->{PictureFileName}";
                push(@expiredpics, $picture->{ PictureKey });
            }
        }

        # If any expired pics are encountered upload them to TradeMe

        if ( scalar(@expiredpics) > 0 ) {

            $pictures =  $tm->get_picture_records( @expiredpics );

            $pb->{ SetProgressTotal     }   =   scalar(@$pictures);
            $pb->UpdateMultiBar();

            PictureUpload($pictures);
        }

        #set the picture total in the database properties file

        my $TMPictotal  = $tm->get_TM_photo_count();

        $tm->set_DB_property(
            Property_Name       => "TMPictureCount" ,
            Property_Value      => $TMPictotal,
        );            
    }
    
    $pb->MarkTaskCompleted($currenttask);
    $pb->UpdateMultiBar();
    sleep 2;

    $tm->update_log("Completed: Upload expired picture files");
    
    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
        return $estruct;
    }


    #-----------------------------------------------------------------------------------------
    # Task 3 - Process Sold Auctions
    #-----------------------------------------------------------------------------------------
    
    $tm->update_log("Started: Process Sold Auctions");
    
    my $auctions;
    
    $currenttask++;

    $pb->{ SetCurrentTask       }   =   $currenttask;
    $pb->{ SetCurrentOperation  }   =   "Retrieving Sold Auction Data";
    $pb->{ SetTaskAction        }   =   "Updating auction:";
    
    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    $auctions = $tm->new_get_sold_listings( StatusHandler => \&UpdateStatusBar );

    if ( defined(@$auctions) ) {
         UpdateSoldAuctions($auctions, "SOLD");
    }
    
    $pb->MarkTaskCompleted($currenttask);
    $pb->UpdateMultiBar();
    sleep 2;

    $tm->update_log("Completed: Process Sold Auctions");

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # Task 4 - Process Unsold Auctions
    #-----------------------------------------------------------------------------------------

    $tm->update_log("Started: Process Unsold Auctions");

    $currenttask++;

    $pb->{ SetCurrentTask       }   =   $currenttask;
    $pb->{ SetCurrentOperation  }   =   "Retrieving Unsold Auction Data";
    $pb->{ SetTaskAction        }   =   "Updating auction:";
    
    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    $auctions = $tm->get_unsold_listings(\&UpdateStatusBar);

    if ( defined(@$auctions) ) {
         UpdateUnsoldAuctions($auctions, "UNSOLD");
    }
    
    $pb->MarkTaskCompleted($currenttask);
    $pb->UpdateMultiBar();
    sleep 2;

    $tm->update_log("Completed: Process Unsold Auctions");

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
        return $estruct;
    }
    
    #-----------------------------------------------------------------------------------------
    # Task 5 - Clone auctions
    #-----------------------------------------------------------------------------------------
    
    if ( $tm->{ LoadAll } ) {

        $tm->update_log("Started: Clone Auctions for upload");

        $currenttask++;

        $pb->{ SetCurrentTask       }   =   $currenttask;
        $pb->{ SetCurrentOperation  }   =   "Cloning Auctions";
        $pb->{ SetTaskAction        }   =   "Cloning Auctions from database for upload:";

        my $clones                      =   $tm->get_clone_auctions( AuctionSite => "TRADEME" );
        my $counter                     =   0;
        my $clone_total                 =   0;

        $pb->{ SetProgressTotal     }   =   scalar(@$clones);
        $pb->{ SetProgressCurrent   }   =   $counter;    
        $pb->UpdateMultiBar();
        $pb->ShowMultiBar();

        foreach my $clone ( @$clones ) {

                $pb->{SetProgressCurrent} = $counter;    
                $pb->UpdateMultiBar();
                $pb->ShowMultiBar();

                my $newkey = $tm->copy_auction_record(
                    AuctionKey       =>  $clone->{ AuctionKey } ,
                    AuctionStatus    =>  "PENDING"              ,
                );

                push (@clonekeys, $newkey);    # Store the key of the new clone record

                $tm->update_log("Cloned Auction $clone->{AuctionTitle} (Record $clone->{AuctionTitle})");

                $counter++;

                if      ( $pb->{ Cancelled } ) {
                        CancelHandler();
                        return $estruct;
                }
        }

        $pb->MarkTaskCompleted($currenttask);
        $pb->UpdateMultiBar();
        sleep 2;

        $tm->update_log("Completed: Clone Auctions for upload");
    }

    #-----------------------------------------------------------------------------------------
    # Task 6 - Upload auctions
    #-----------------------------------------------------------------------------------------

    if ( $tm->{ LoadAll } ) {

        $tm->update_log("Started: Load all Pending auctions");

        $currenttask++;

        $pb->{ SetCurrentTask       }   =   $currenttask;
        $pb->{ SetCurrentOperation  }   =   "Logging on to TradeMe";
        $pb->UpdateMultiBar();

        $tm->update_log("Logging in to TradeMe");
        $tm->login();

        # if login was not OK update error structure and return

        if ( $tm->{ ErrorStatus } ) {
            $tm->set_always_minimize( $pb->AlwaysMinimize() );
            $pb->QuitMultiBar();
            UpdateErrorStatus();   
            return $estruct;
        }

        $pb->{ SetTaskAction        }   =   "Loading auctions to TradeMe:";
        $pb->{ SetCurrentOperation  }   =   "Retrieving Auctions requiring upload";
        $pb->UpdateMultiBar();

        my $upload_total = 0;
        my $auctions = $tm->get_pending_auctions(
            AuctionSite =>  "TRADEME"   ,
        );


        foreach my $auction (@$auctions) {
           $upload_total = $upload_total + $auction->{ CopyCount };
        }

        $pb->{ SetProgressTotal } = $upload_total;
        $pb->UpdateMultiBar();

        AuctionUpload($auctions);

        $pb->MarkTaskCompleted( $currenttask );
        $pb->UpdateMultiBar();
        sleep 2;

        $tm->update_log("Completed: Load all Pending auctions");

        # Handle the task being cancelled via the CANCEL button or ending abnormally

        if ($abend) {
            return $estruct;
        }

    }

    #-----------------------------------------------------------------------------------------
    # Task 7 - Clone Cycle auctions
    #-----------------------------------------------------------------------------------------
    
    if ( $tm->{ LoadCycle } ) {

        $tm->update_log("Started: Clone Auctions for Auction Cycle ".$tm->{ LoadCycleName });

        $currenttask++;

        $pb->{ SetCurrentTask       }   =   $currenttask;
        $pb->{ SetCurrentOperation  }   =   "Cloning Auctions";
        $pb->{ SetTaskAction        }   =   "Cloning Auctions from database for upload:";

        my $counter =   0;

        my $clones = $tm->get_clone_auctions(
            AuctionSite     => "TRADEME"                ,
            AuctionCycle    => $tm->{ LoadCycleName }   ,
        );

        $pb->{ SetProgressTotal     }   =   scalar(@$clones);
        $pb->{ SetProgressCurrent   }   =   $counter;    
        $pb->UpdateMultiBar();
        $pb->ShowMultiBar();

        foreach my $clone ( @$clones ) {

                $pb->{SetProgressCurrent} = $counter;    
                $pb->UpdateMultiBar();
                $pb->ShowMultiBar();

                my $newkey = $tm->copy_auction_record(
                    AuctionKey       =>  $clone->{ AuctionKey } ,
                    AuctionStatus    =>  "PENDING"              ,
                );

                push (@clonekeys, $newkey);    # Store the key of the new clone record

                $tm->update_log("Cloned Auction $clone->{AuctionTitle} (Record $clone->{auctionTitle})");

                $counter++;

                if      ( $pb->{ Cancelled } ) {
                        CancelHandler();
                        return $estruct;
                }
        }

        $pb->MarkTaskCompleted($currenttask);
        $pb->UpdateMultiBar();
        sleep 2;

        $tm->update_log("Completed: Clone Auctions for Auction Cycle ".$tm->{ LoadCycleName });

    }

    #-----------------------------------------------------------------------------------------
    # Task 8 - Retrieve and Load auctions in auction cycle
    #-----------------------------------------------------------------------------------------

    if ( $tm->{ LoadCycle } ) {

        $tm->update_log("Started: Load Pending auctions for Auction Cycle ".$tm->{ LoadCycleName });

        $currenttask++;

        $pb->{ SetCurrentTask       }   =   $currenttask;
        $pb->{ SetCurrentOperation  }   =   "Retrieving Auctions in Cycle $tm->{ LoadCycleName }";
        $pb->{ SetTaskAction        }   =   "Loading auctions to TradeMe:";
        $pb->UpdateMultiBar();


        my $auctions =  $tm->get_cycle_auctions(
            AuctionSite     =>  "TRADEME"               ,
            AuctionCycle    =>  $tm->{ LoadCycleName }  ,
        );

        my $upload_total = 0;

        foreach my $auction ( @$auctions ) {
           $upload_total = $upload_total + $auction->{ CopyCount };
        }

        $pb->{ SetProgressTotal     }   =   $upload_total;
        $pb->{ SetCurrentOperation  }   =   "Logging on to TradeMe";
        $pb->UpdateMultiBar();

        $tm->update_log("Logging in to TradeMe");
        $tm->login();

        # if login was not OK update error structure and return

        if ( $tm->{ ErrorStatus } ) {
            $tm->set_always_minimize( $pb->AlwaysMinimize() );
            $pb->QuitMultiBar();
            UpdateErrorStatus();   
            return $estruct;
        }

        AuctionUpload($auctions);

        $pb->MarkTaskCompleted($currenttask);
        $pb->UpdateMultiBar();
        sleep 2;

        $tm->update_log("Completed: Load Pending auctions for Auction Cycle ".$tm->{ LoadCycleName });

        # Handle the task being cancelled via the CANCEL button or ending abnormally

        if ($abend) {
            return $estruct;
        }
    }

    #-----------------------------------------------------------------------------------------
    # Task 9 - Process all Eligible Offers
    #-----------------------------------------------------------------------------------------

    if ( $tm->{ OfferAll } ) {

        $tm->update_log("Started: Processing Offers");

        $currenttask++;

        $pb->{ SetCurrentTask       }   =   $currenttask;
        $pb->{ SetCurrentOperation  }   =   "Processing Offers";
        $pb->{ SetTaskAction        }   =   "Making Offers on TradeMe:";
        $pb->UpdateMultiBar();

        # Get the list auctions to be offered from the database
        # Select list type based on what kind of offers have been selected

        $tm->update_log("Logging in to TradeMe");
        $tm->login();

        # if login was not OK update error structure and return

        if ( $tm->{ ErrorStatus } ) {
            $tm->set_always_minimize( $pb->AlwaysMinimize() );
            $pb->QuitMultiBar();
            UpdateErrorStatus();   
            return $estruct;
        }

        my $offers;

        if ( ( $tm->{ OfferSold } eq "1" ) and ( $tm->{ OfferUnsold } eq "1" ) ) {
            $offers = $tm->get_pending_offers( "ALL" );
        }

        if ( ( $tm->{ OfferSold } eq "1" ) and ( $tm->{ OfferUnsold } eq "0" ) ) {
            $offers = $tm->get_pending_offers( "SOLD" );
        }

        if ( ( $tm->{ OfferSold } eq "0" ) and ( $tm->{ OfferUnsold } eq "1" ) ) {
            $offers = $tm->get_pending_offers( "UNSOLD" );
        }

        my $offertotal = 0;

        if ( defined( @$offers ) ) {
            $offertotal = scalar( @$offers );
        }

        $pb->{ SetProgressTotal } = $offertotal;
        $tm->update_log( $offertotal." Pending Offers Retrieved from database");

        if ( scalar( @$offers ) gt 0 ) {
            AuctionOffer( $offers );
        }

        $pb->MarkTaskCompleted($currenttask);
        $pb->UpdateMultiBar();
        sleep 2;

        $tm->update_log("Completed: Processing offers");

        # Handle the task being cancelled via the CANCEL button or ending abnormally

        if ($abend) {
            return $estruct;
        }
    }

    #-----------------------------------------------------------------------------------------
    # Task 10 - Process auctions elgible for relists
    #-----------------------------------------------------------------------------------------

    if ( $tm->{ RelistAll } ) {

        $tm->update_log("Started: Relist Elegible Auctions");

        $currenttask++;

        $pb->{ SetCurrentTask       }   =   $currenttask;
        $pb->{ SetTaskAction        }   =   "Relisting auction:";

        my $auctions                    =   $tm->get_standard_relists();
        my $upload_total                =   0;

        foreach my $auction (@$auctions) {
           $upload_total = $upload_total + $auction->{CopyCount};
        }

        $pb->{ SetProgressTotal     }   =   $upload_total;
        $pb->UpdateMultiBar();

        AuctionRelist($auctions);

        $pb->MarkTaskCompleted($currenttask);

        $pb->UpdateMultiBar();
        sleep 2;

        $tm->update_log("Started: Relist Elegible Auctions");

        # Handle the task being cancelled via the CANCEL button or ending abnormally

        if ($abend) {
            return $estruct;
        }
    }

    #-----------------------------------------------------------------------------------------
    # Task 11 - Relist Auction cycle
    #-----------------------------------------------------------------------------------------

    if ( $tm->{ RelistCycle } ) {

        $tm->update_log("Started: Relist Auction cycle ".$tm->{ RelistCycleName });

        $currenttask++;

        $pb->{ SetCurrentTask       }   =   $currenttask;
        $pb->{ SetCurrentOperation  }   =   "Retrieving Auctions for $tm->{ RelistCycleName }";
        $pb->{ SetTaskAction        }   =   "relistinging auctions to TradeMe:";

        $pb->UpdateMultiBar();
        $pb->ShowMultiBar();

        my $upload_total = 0;
        my $auctions = $tm->get_cycle_relists(
            AuctionSite     => "TRADEME"                ,
            AuctionCycle    => $tm->{ RelistCycleName } ,
        );

        foreach my $auction ( @$auctions ) {
           $upload_total = $upload_total + $auction->{ CopyCount };
        }

        $pb->{ SetProgressTotal     }   =   $upload_total;
        $pb->UpdateMultiBar();

        if ( scalar(@$auctions) > 0 ) {
            AuctionRelist($auctions);
        }

        $pb->MarkTaskCompleted($currenttask);
        $pb->UpdateMultiBar();
        sleep 2;

        $tm->update_log("Completed: Relist Auction cycle ".$tm->{ RelistCycleName });

        # Handle the task being cancelled via the CANCEL button or ending abnormally

        if ($abend) {
            return $estruct;
        }
    }

    # Housekeeping for any clones that have been created but not loaded

    if ( scalar(@clonekeys) > 0 ) {

        foreach my $clonekey ( @clonekeys ) {

            $pb->{ SetCurrentOperation  }   =   "Performing clean up operations";
            $pb->UpdateMultiBar();
            $pb->ShowMultiBar();

            my $clonedata = $tm->get_auction_record( $clonekey );
            
            if ( $clonedata->{ AuctionStatus } = "PENDING" ) {
                $tm->delete_auction_record( $clonekey );
                $tm->update_log("Deleted Cloned Auction $clonedata->{ AuctionTitle } (Record $clonekey) - Aution did not load");
            }
        }
    }

    #-----------------------------------------------------------------------------------------
    # All Tasks completed
    #-----------------------------------------------------------------------------------------

    $tm->DBdisconnect();                          # disconnect from the database

    $tm->set_always_minimize( $pb->AlwaysMinimize() );
    $pb->QuitMultiBar();

    UpdateErrorStatus();   
    return $estruct;
    
}


#=============================================================================================
# ProcessAll - Load all Pending Auctions and relist all eligible auctions
#=============================================================================================

sub ProcessAll {

    $tm = Auctionitis->new();
    $tm->initialise(Product => "Auctionitis");  # Initialise the product

    $tm->update_log("Invoked Method: ". (caller(0))[3]); 

    $tm->{ Debug } ge "1" ? ( $tm->dump_properties() ) : () ;

    $pb = Win32::OLE->new('MultiPB.clsMultiPB') or die;

    ### insert some text into the window header

    $pb->InitialiseMultiBar();
    $pb->{ AlwaysMinimize       }   =   $tm->{ AlwaysMinimize };
    $pb->{ SetWindowTitle       }   =   "Auctionitis: Load All Auctions";
    
    # Tasks to be performed in this operation
    
    $pb->AddTask("Clone Auctions for upload");
    $pb->AddTask("Upload new picture files");
    $pb->AddTask("Check Picture Files on TradeMe");
    $pb->AddTask("Load all Pending auctions");
    $pb->AddTask("Update Sold Auction Data");
    $pb->AddTask("Update Unsold Auction Data");
    $pb->AddTask("Process Fixed Price offers");
    $pb->AddTask("Relist All Eligible auctions");

    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    # Initialise the TradeMe object
    $tm->update_log("Connecting to Database");
    $tm->DBconnect();                          # Connect to the database

    $tm->update_log("Logging in to TradeMe");
    $tm->login();

    # if login was not OK update error structure and return

    if ( $tm->{ ErrorStatus } ) {
        $tm->set_always_minimize( $pb->AlwaysMinimize() );
        $pb->QuitMultiBar();
        UpdateErrorStatus();   
        return $estruct;
    }    

    #-----------------------------------------------------------------------------------------
    # Task 1 - Clone auctions
    #-----------------------------------------------------------------------------------------
    
    $tm->update_log("Started: Clone Auctions for upload");

    $pb->{ SetCurrentTask       }   =   1;
    $pb->{ SetCurrentOperation  }   =   "Cloning Auctions";
    $pb->{ SetTaskAction        }   =   "Cloning Auctions from database for upload:";

    my $clones                      =   $tm->get_clone_auctions( AuctionSite => "TRADEME" );
    my $counter                     =   0;
    my $clone_total                 =   0;
    
    $pb->{ SetProgressTotal     }   =   scalar(@$clones);
    $pb->{ SetProgressCurrent   }   =   $counter;    
    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    foreach my $clone ( @$clones ) {
    
        $pb->{SetProgressCurrent} = $counter;    
        $pb->UpdateMultiBar();
        $pb->ShowMultiBar();
    
        my $newkey = $tm->copy_auction_record(
            AuctionKey       =>  $clone->{ AuctionKey } ,
            AuctionStatus    =>  "PENDING"              ,
        );
    
        push (@clonekeys, $newkey);    # Store the key of the new clone record
    
        $tm->update_log("Cloned Auction $clone->{AuctionTitle} (Record $clone->{AuctionTitle})");
    
        $counter++;
    
        if      ( $pb->{ Cancelled } ) {
                CancelHandler();
                return $estruct;
        }
    }

    $pb->MarkTaskCompleted(1);
    $pb->UpdateMultiBar();

    $tm->update_log("Completed: Clone Auctions for upload");

    sleep 2;

    #-----------------------------------------------------------------------------------------
    # Task 2 - Process new photographs
    #-----------------------------------------------------------------------------------------

    $tm->update_log("Started: Upload new picture files");

    $pb->{ SetCurrentTask       }   =   2;
    $pb->{ SetCurrentOperation  }   =   "Loading New pictures to TradeMe";
    $pb->{ SetTaskAction        }   =   "Uploading file:";
    $pb->UpdateMultiBar();

    my $pictures =  $tm->get_unloaded_pictures( AuctionSite => "TRADEME" );

    if ( scalar(@$pictures) > 0 ) {

        $pb->{ SetProgressTotal     }   =   scalar(@$pictures);
        $pb->UpdateMultiBar();

        $tm->update_log("Logging in to TradeMe");
        $tm->login();

        # if login was not OK update error structure and return

        if ( $tm->{ ErrorStatus } ) {
            $tm->set_always_minimize( $pb->AlwaysMinimize() );
            $pb->QuitMultiBar();
            UpdateErrorStatus();   
            return $estruct;
        }    

        PictureUpload($pictures);

        # Adjust the Auctionitis TM Picture total

        $tm->set_DB_property(
            Property_Name       => "TMPictureCount" ,
            Property_Value      => $tm->get_DB_property(Property_Name => "TMPictureCount", Property_Default => 0) + scalar(@$pictures),
        );

        $tm->update_log("Adjust TMPictureCount Property  - ".scalar(@$pictures)." new pictures");
    }

    $pb->MarkTaskCompleted(2);
    $pb->UpdateMultiBar();

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
        return $estruct;
    }

    $tm->update_log("Completed: Upload new picture files");

    #-----------------------------------------------------------------------------------------
    # Task 3 - Process expired photograhs
    #-----------------------------------------------------------------------------------------

    $tm->update_log("Started: Upload expired picture files");
    
    $pb->{ SetCurrentTask       }   =   3;
    $pb->{ SetCurrentOperation  }   =   "Retrieving TradeMe Picture data";
    $pb->{ SetTaskAction        }   =   "";

    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    # Compare the TradeMe picture count with the Auctionitis picture count

    my $TMPictotal  = $tm->get_TM_photo_count();
    my $DBPictotal  = $tm->get_DB_property(Property_Name => "TMPictureCount", Property_Default => 0);
    
    $tm->update_log("Picture Total on TradeMe  - $TMPictotal");
    $tm->update_log("Calculated Picture total  - $DBPictotal");

    # If the database total equals the TM picture total there are no expired pics (in theory...)
    
    if ( $DBPictotal eq $TMPictotal ) {

        $tm->update_log("Picture Totals reconciled - processing complete");
        $pb->{ SetTaskAction }   =   "Picture Totals reconciled - processing complete";

    }
    
    else {
    
        my @TMPictures = $tm->get_photo_list(\&UpdateStatusBar);

        my %TMPictable;

        foreach my $PhotoId ( @TMPictures ) {
            $TMPictable{ $PhotoId } = 1;
        }

        my $currentpictures = $tm->get_all_pictures();

        my @expiredpics;

        foreach my $picture ( @$currentpictures ) {

            if (not defined $TMPictable{ $picture->{ PhotoId } } ) {

                $tm->update_log("Located expired Photo $picture->{PictureFileName} (Record $picture->{PictureKey})");
                $pb->{ SetCurrentOperation  }   =   "Expired: $picture->{PictureFileName}";
                push(@expiredpics, $picture->{ PictureKey });
            }
        }

        # If any expired pics are encountered upload them to TradeMe

        if ( scalar(@expiredpics) > 0 ) {

            $pictures =  $tm->get_picture_records( @expiredpics );

            $pb->{ SetProgressTotal     }   =   scalar(@$pictures);
            $pb->UpdateMultiBar();

            PictureUpload($pictures);
        }

        #set the picture total in the database properties file

        my $TMPictotal  = $tm->get_TM_photo_count();

        $tm->set_DB_property(
            Property_Name       => "TMPictureCount" ,
            Property_Value      => $TMPictotal,
        );            
    }
    
    $pb->MarkTaskCompleted(3);
    $pb->UpdateMultiBar();

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
        return $estruct;
    }

    $tm->update_log("Completed: Upload expired picture files");

    #-----------------------------------------------------------------------------------------
    # Task 4 - Upload auctions
    #-----------------------------------------------------------------------------------------

    $tm->update_log("Started: Load all Pending auctions");

    $pb->{ SetCurrentTask       }   =   4;
    $pb->{ SetCurrentOperation  }   =   "Logging on to TradeMe";
    $pb->UpdateMultiBar();

    $tm->update_log("Logging in to TradeMe");
    $tm->login();
    
    # if login was not OK update error structure and return

    if ( $tm->{ ErrorStatus } ) {
        $tm->set_always_minimize( $pb->AlwaysMinimize() );
        $pb->QuitMultiBar();
        UpdateErrorStatus();   
        return $estruct;
    }

    $pb->{ SetTaskAction        }   =   "Loading auctions to TradeMe:";
    $pb->{ SetCurrentOperation  }   =   "Retrieving Auctions requiring upload";
    $pb->UpdateMultiBar();

    my $upload_total = 0;
    my $auctions = $tm->get_pending_auctions(
        AuctionSite =>  "TRADEME"   ,
    );

    foreach my $auction ( @$auctions ) {
       $upload_total = $upload_total + $auction->{ CopyCount };
    }

    $pb->{ SetProgressTotal } = $upload_total;
    $pb->UpdateMultiBar();

    AuctionUpload($auctions);

    $pb->MarkTaskCompleted(4);
    $pb->UpdateMultiBar();

    $tm->update_log("Completed: Load all Pending auctions");

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
        return $estruct;
    }    

    #-----------------------------------------------------------------------------------------
    # Task 5 - Process Sold Auctions
    #-----------------------------------------------------------------------------------------
    
    $tm->update_log("Started: Process Sold Auctions");
    
    my $auctions;
    
    $pb->{ SetCurrentTask       }   =   5;
    $pb->{ SetCurrentOperation  }   =   "Retrieving Sold Auction Data";
    $pb->{ SetTaskAction        }   =   "Updating auction:";
    
    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    $auctions = $tm->new_get_sold_listings( StatusHandler => \&UpdateStatusBar );

    if ( defined(@$auctions) ) {
         UpdateSoldAuctions($auctions, "SOLD");
    }
    
    $pb->MarkTaskCompleted(5);
    $pb->UpdateMultiBar();

    $tm->update_log("Completed: Process Sold Auctions");

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # Task 6 - Process Unsold Auctions
    #-----------------------------------------------------------------------------------------

    $tm->update_log("Started: Process Unsold Auctions");

    $pb->{ SetCurrentTask       }   =   6;
    $pb->{ SetCurrentOperation  }   =   "Retrieving Unsold Auction Data";
    $pb->{ SetTaskAction        }   =   "Updating auction:";
    
    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    $auctions = $tm->get_unsold_listings(\&UpdateStatusBar);

    if ( defined(@$auctions) ) {
         UpdateUnsoldAuctions($auctions, "UNSOLD");
    }
    
    $pb->MarkTaskCompleted(6);
    $pb->UpdateMultiBar();

    $tm->update_log("Completed: Process Unsold Auctions");

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # Task 7 - Process all Eligible Offers
    #-----------------------------------------------------------------------------------------

    $tm->update_log("Started: Processing Offers");

    $pb->{ SetCurrentTask       }   =   7;
    $pb->{ SetCurrentOperation  }   =   "Processing Offers";
    $pb->{ SetTaskAction        }   =   "Making Offers on TradeMe:";
    $pb->UpdateMultiBar();

    # Get the list auctions to be offered from the database
    # Select list type based on what kind of offers have been selected

    $tm->update_log("Logging in to TradeMe");
    $tm->login();

    # if login was not OK update error structure and return

    if ( $tm->{ ErrorStatus } ) {
        $tm->set_always_minimize( $pb->AlwaysMinimize() );
        $pb->QuitMultiBar();
        UpdateErrorStatus();   
        return $estruct;
    }

    my $offers;

    if ( ( $tm->{ OfferSold } eq "1" ) and ( $tm->{ OfferUnsold } eq "1" ) ) {
        $offers = $tm->get_pending_offers( "ALL" );
    }

    if ( ( $tm->{ OfferSold } eq "1" ) and ( $tm->{ OfferUnsold } eq "0" ) ) {
        $offers = $tm->get_pending_offers( "SOLD" );
    }

    if ( ( $tm->{ OfferSold } eq "0" ) and ( $tm->{ OfferUnsold } eq "1" ) ) {
        $offers = $tm->get_pending_offers( "UNSOLD" );
    }

    my $offertotal = 0;

    if ( defined( @$offers ) ) {
        $offertotal = scalar( @$offers );
    }

    $pb->{ SetProgressTotal } = $offertotal;
    $tm->update_log( $offertotal." Pending Offers Retrieved from database");

    if ( scalar( @$offers ) gt 0 ) {
         AuctionOffer( $offers );
    }

    # Finished processing

    $pb->MarkTaskCompleted(7);
    $pb->UpdateMultiBar();
    sleep 2;

    $tm->update_log("Completed: Processing offers");

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # Task 8 - Process auctions elgible for relists
    #-----------------------------------------------------------------------------------------

    $tm->update_log("Started: Relist Elegible Auctions");

    $pb->{ SetCurrentTask       }   =   8;
    $pb->{ SetTaskAction        }   =   "Relisting auction:";

    my $auctions                    =   $tm->get_standard_relists();
    my $upload_total                =   0;

    foreach my $auction (@$auctions) {
       $upload_total = $upload_total + $auction->{CopyCount};
    }

    $pb->{ SetProgressTotal     }   =   $upload_total;
    $pb->UpdateMultiBar();

    AuctionRelist($auctions);

    $pb->MarkTaskCompleted(7);
    $pb->UpdateMultiBar();
    
    $tm->update_log("Completed: Relist Elegible Auctions");

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
        return $estruct;
    }

    # Housekeeping for any clones that have been created but not loaded

    if ( scalar(@clonekeys) > 0 ) {

        foreach my $clonekey ( @clonekeys ) {

            $pb->{ SetCurrentOperation  }   =   "Performing clean up operations";
            $pb->UpdateMultiBar();
            $pb->ShowMultiBar();

            my $clonedata = $tm->get_auction_record( $clonekey );
            
            if ( $clonedata->{ AuctionStatus } = "PENDING" ) {
                $tm->delete_auction_record( $clonekey );
                $tm->update_log("Deleted Cloned Auction $clonedata->{ AuctionTitle } (Record $clonekey) - Aution did not load");
            }
        }
    }

    #-----------------------------------------------------------------------------------------
    # All Tasks completed
    #-----------------------------------------------------------------------------------------

    $tm->DBdisconnect();                          # disconnect from the database
        
    sleep 2;
    $tm->set_always_minimize( $pb->AlwaysMinimize() );
    $pb->QuitMultiBar();

    UpdateErrorStatus();   
    return $estruct;
}

#=============================================================================================
# AuctionUpload - Subroutine to do the actual upload work
#=============================================================================================

sub AuctionUpload {

    my $auctions    =   shift;
    my $counter     =   1;
    my $dopt;
    
    $tm->update_log("Invoked Method: ". (caller(0))[3]); 

    # Set Auction loading delay values to a minimum of 5 seconds
    # Multiply the retrieved delay value * 60 to convert to seconds

    my $delay       =   $tm->{DripFeedInterval};
    $delay          =   $delay * 60;
    
    if ($delay == 0) {$delay = 5;}
    
    # Calculate total no. of auctions to be uploaded
    
    my $uploadtotal = 0;
    
    foreach my $auction (@$auctions) {
        $uploadtotal = $uploadtotal + $auction->{CopyCount};
    }

    $pb->{ SetProgressTotal   }   =   $uploadtotal;

    foreach my $auction (@$auctions) {

        $tm->update_log( "AuctionUpload: Loading auction $auction->{Title} (Record $auction->{ AuctionKey })" );

        if ( $auction->{ AuctionStatus } eq 'PENDING' ) {

            $pb->{ SetProgressCurrent   }   =   $counter;
            $pb->{ SetCurrentOperation  }   =   "Loading ".$auction->{Title};
            $pb->UpdateMultiBar();

            # if a shipping option is specified retrieve the delivery options
            
            if ( $auction->{ ShippingOption } ) {
                $dopt = $tm->get_shipping_details( AuctionKey => $auction->{ AuctionKey } );

                $tm->update_log( "Delivery Options specified on Auction: ".scalar( @$dopt ) );

                # Format the number fields to have a decimal point - TM appears not to like 0 as a single number

                foreach my $o ( @$dopt ) {
                    $o->{ Shipping_Details_Cost } = sprintf "%.2f", $o->{ Shipping_Details_Cost };
                    $tm->{ Debug } ge "1" ? $tm->update_log( "Shipping: ".$o->{ Shipping_Details_Text }." @ ".$o->{ Shipping_Details_Cost } ) : ();
                }
            }
            my $copies_loaded = 0;

            while ( $copies_loaded < $auction->{ CopyCount } ) {

                # Check whether the Free Listing Limit has been exceeded if abort property is true

                if ( $tm->{ ListLimitAbort } ) {

                    my $ca = $tm->get_current_auction_count();
                    
                    if ($tm->{ ListLimitAllowance } eq "") {
                        $tm->{ ListLimitAllowance } = 0;
                    }

                    my $ll = $tm->get_free_listing_limit() + $tm->{ ListLimitAllowance };

                    $tm->update_log("List Limit Allowance Checking");
                    $tm->update_log("Current Auction Count: $ca");
                    $tm->update_log("Free Listing Limit   : $ll");
                    $tm->update_log("List Limit Allowance : $tm->{ ListLimitAllowance }");

                    if ( $ca >= $ll ) {
                        ListingLimitAbend();
                        return $estruct;
                    }
                }

                # If the auction is not the first auction and
                # if the delay is greater then 5 seconds log in for each auction
                # this is to ensure the session is not disconnected while waiting
                # as usual we test that the connection is oK before proceeding

                if ( $counter > 1 ) {

                    if ( $delay > 5 ) {
                        $pb->{ SetCurrentOperation } = "Drip-feed delay: ".$tm->load_interval()." minutes";
                        $pb->UpdateBar();
                    }

                    sleep $delay;

                    if ($delay > 5) {
                        my $connected = $tm->login();

                        if ( $tm->{ ErrorStatus } ) {
                            $tm->set_always_minimize( $pb->AlwaysMinimize() );
                            $pb->QuitMultiBar();
                            UpdateErrorStatus();   
                            return $estruct;
                        }

                        if (not $connected) {
                            $tm->set_always_minimize( $pb->AlwaysMinimize() );
                            $pb->QuitMultiBar();
                            UpdateErrorStatus();   
                            return $estruct;
                        }
                    }
                }

                if  ( $tm->{ Debug } ge "1" ) {    
                    foreach my $k (sort keys %$auction) {
                        if ( $k ne 'Description' ) {
                            $tm->update_log( "$k \t: $auction->{ $k }" );
                        }
                    }
                }

                # Append the Standard terms to the Auction Desription

                my $terms       = $tm->get_standard_terms( AuctionSite => "TRADEME" );
                my $description = $auction->{ Description }."\n\n".$terms;

                my $maxlength = 2018;

                if ( length( $description ) > $maxlength ) {
                    $description = $auction->{ Description };
                    $tm->update_log( "Auction $auction->{ Title } (Record $auction->{ AuctionKey }) - standard terms not applied.");
                    $tm->update_log( "Combined length of standard terms and description would exceed allowable length");
                    $tm->update_log( "Description [".length( $description )."] Terms [".length( $description )."] Threshold [".$maxlength."]");

                    $description = $a->{ Description };
                }

                # Set the message field to blank and load the auction...                

                my $message = "";

                my $newauction = $tm->load_new_auction(
                    AuctionKey                      =>  $auction->{ AuctionKey      }   ,
                    CategoryID                      =>  $auction->{ Category        }   ,
                    Title                           =>  $auction->{ Title           }   ,
                    Subtitle                        =>  $auction->{ Subtitle        }   ,
                    Description                     =>  $description                    ,
                    IsNew                           =>  $auction->{ IsNew           }   ,
                    TMBuyerEmail                    =>  $auction->{ TMBuyerEmail    }   ,
                    EndType                         =>  $auction->{ EndType         }   ,
                    DurationHours                   =>  $auction->{ DurationHours   }   ,
                    EndDays                         =>  $auction->{ EndDays         }   ,
                    EndTime                         =>  $auction->{ EndTime         }   ,
                    !($auction->{ ShippingOption }) ?   (   FreeShippingNZ  =>  $auction->{ FreeShippingNZ          }   )   :   ()  ,
                    !($auction->{ ShippingOption }) ?   (   ShippingInfo    =>  $auction->{ ShippingInfo            }   )   :   ()  ,
                    $auction->{ PickupOption    }   ?   (   PickupOption    =>  $auction->{ PickupOption            }   )   :   ()  ,
                    $auction->{ ShippingOption  }   ?   (   ShippingOption  =>  $auction->{ ShippingOption          }   )   :   ()  ,
                    $dopt->[0]                      ?   (   DCost1          =>  $dopt->[0]->{ Shipping_Details_Cost }   )   :   ()  ,
                    $dopt->[0]                      ?   (   DText1          =>  $dopt->[0]->{ Shipping_Details_Text }   )   :   ()  ,
                    $dopt->[1]                      ?   (   DCost2          =>  $dopt->[1]->{ Shipping_Details_Cost }   )   :   ()  ,
                    $dopt->[1]                      ?   (   DText2          =>  $dopt->[1]->{ Shipping_Details_Text }   )   :   ()  ,
                    $dopt->[2]                      ?   (   DCost3          =>  $dopt->[2]->{ Shipping_Details_Cost }   )   :   ()  ,
                    $dopt->[2]                      ?   (   DText3          =>  $dopt->[2]->{ Shipping_Details_Text }   )   :   ()  ,
                    $dopt->[3]                      ?   (   DCost4          =>  $dopt->[3]->{ Shipping_Details_Cost }   )   :   ()  ,
                    $dopt->[3]                      ?   (   DText4          =>  $dopt->[3]->{ Shipping_Details_Text }   )   :   ()  ,
                    $dopt->[4]                      ?   (   DCost5          =>  $dopt->[4]->{ Shipping_Details_Cost }   )   :   ()  ,
                    $dopt->[4]                      ?   (   DText5          =>  $dopt->[4]->{ Shipping_Details_Text }   )   :   ()  ,
                    $dopt->[5]                      ?   (   DCost6          =>  $dopt->[5]->{ Shipping_Details_Cost }   )   :   ()  ,
                    $dopt->[5]                      ?   (   DText6          =>  $dopt->[5]->{ Shipping_Details_Text }   )   :   ()  ,
                    $dopt->[6]                      ?   (   DCost7          =>  $dopt->[6]->{ Shipping_Details_Cost }   )   :   ()  ,
                    $dopt->[6]                      ?   (   DText7          =>  $dopt->[6]->{ Shipping_Details_Text }   )   :   ()  ,
                    $dopt->[7]                      ?   (   DCost8          =>  $dopt->[7]->{ Shipping_Details_Cost }   )   :   ()  ,
                    $dopt->[7]                      ?   (   DText8          =>  $dopt->[7]->{ Shipping_Details_Text }   )   :   ()  ,
                    $dopt->[8]                      ?   (   DCost9          =>  $dopt->[8]->{ Shipping_Details_Cost }   )   :   ()  ,
                    $dopt->[8]                      ?   (   DText9          =>  $dopt->[8]->{ Shipping_Details_Text }   )   :   ()  ,
                    $dopt->[9]                      ?   (   DCost10         =>  $dopt->[9]->{ Shipping_Details_Cost }   )   :   ()  ,
                    $dopt->[9]                      ?   (   DText10         =>  $dopt->[9]->{ Shipping_Details_Text }   )   :   ()  ,
                    StartPrice                      =>  $auction->{ StartPrice      }   ,
                    ReservePrice                    =>  $auction->{ ReservePrice    }   ,
                    BuyNowPrice                     =>  $auction->{ BuyNowPrice     }   ,
                    ClosedAuction                   =>  $auction->{ ClosedAuction   }   ,
                    AutoExtend                      =>  $auction->{ AutoExtend      }   ,
                    BankDeposit                     =>  $auction->{ BankDeposit     }   ,
                    CreditCard                      =>  $auction->{ CreditCard      }   ,
                    CashOnPickup                    =>  $auction->{ CashOnPickup    }   ,
                    Paymate                         =>  $auction->{ Paymate         }   ,
                    Pago                            =>  $auction->{ Pago            }   ,
                    SafeTrader                      =>  $auction->{ SafeTrader      }   ,
                    PaymentInfo                     =>  $auction->{ PaymentInfo     }   ,
                    Gallery                         =>  $auction->{ Gallery         }   ,
                    BoldTitle                       =>  $auction->{ BoldTitle       }   ,
                    Featured                        =>  $auction->{ Featured        }   ,
                    FeatureCombo                    =>  $auction->{ FeatureCombo    }   ,
                    HomePage                        =>  $auction->{ HomePage        }   ,
                    Permanent                       =>  $auction->{ Permanent       }   ,
                    MovieRating                     =>  $auction->{ MovieRating     }   ,
                    MovieConfirm                    =>  $auction->{ MovieConfirm    }   ,
                    TMATT038                        =>  $auction->{ TMATT038        }   ,
                    TMATT163                        =>  $auction->{ TMATT163        }   ,
                    TMATT164                        =>  $auction->{ TMATT164        }   ,
                    AttributeName                   =>  $auction->{ AttributeName   }   ,
                    AttributeValue                  =>  $auction->{ AttributeValue  }   ,
                    TMATT104                        =>  $auction->{ TMATT104        }   ,
                    TMATT104_2                      =>  $auction->{ TMATT104_2      }   ,
                    TMATT106                        =>  $auction->{ TMATT106        }   ,
                    TMATT106_2                      =>  $auction->{ TMATT106_2      }   ,
                    TMATT108                        =>  $auction->{ TMATT108        }   ,
                    TMATT108_2                      =>  $auction->{ TMATT108_2      }   ,
                    TMATT111                        =>  $auction->{ TMATT111        }   ,
                    TMATT112                        =>  $auction->{ TMATT112        }   ,
                    TMATT115                        =>  $auction->{ TMATT115        }   ,
                    TMATT117                        =>  $auction->{ TMATT117        }   ,
                    TMATT118                        =>  $auction->{ TMATT118        }   ,
                );

                # TODO: Add code to check if new auction already exists in database and log a severe error

                if (not defined $newauction) {

                    $tm->update_log("*** Error loading auction to TradeMe - Auction not Loaded");
                    $copies_loaded = $auction->{CopyCount};
                }
                
                else {

                    my ($closetime, $closedate);

                    if ( $auction->{ EndType } eq "DURATION" ) {
                    
                        $closedate = $tm->closedate( $auction->{ DurationHours } );
                        $closetime = $tm->closetime( $auction->{ DurationHours } );
                    }

                    if ( $auction->{ EndType } eq "FIXEDEND" ) {
                    
                        $closedate = $tm->fixeddate( $auction->{ EndDays } );
                        $closetime = $tm->fixedtime( $auction->{ EndTime } );
                    }

                    $tm->update_log("Auction Uploaded to Trade me as Auction $newauction");

                    if  ($copies_loaded == 0 )  {                 #First copy of auction

                        $tm->update_auction_record(
                            AuctionKey       =>  $auction->{ AuctionKey }                       ,
                            AuctionStatus    =>  "CURRENT"                                      ,
                            AuctionRef       =>  $newauction                                    ,
                            DateLoaded       =>  $tm->datenow()                                 ,
                            CloseDate        =>  $closedate                                     ,
                            CloseTime        =>  $closetime                                     ,
                        );
                    } 
                    else {
                        $tm->copy_auction_record(
                            AuctionKey       =>  $auction->{ AuctionKey }                       ,
                            AuctionStatus    =>  "CURRENT"                                      ,
                            AuctionRef       =>  $newauction                                    ,
                            DateLoaded       =>  $tm->datenow()                                 ,
                            CloseDate        =>  $closedate                                     ,
                            CloseTime        =>  $closetime                                     ,
                        );
                    }
                    $copies_loaded++;
                }

                # Test whether the upload has been cancelled

                if ( $pb->{ Cancelled } ) {
                    CancelHandler();
                    return $estruct;
                }

                sleep 4;

                $counter++;
            }
        }
        else {
            $tm->update_log("Auction $auction->{Title} (Record $auction->{AuctionKey}) not loaded: Invalid Auction Status ($auction->{AuctionStatus})");
        }        
    }

    UpdateErrorStatus();   
    return $estruct;
}

#=============================================================================================
# AuctionRelist - Function to do the actual relist on TradeMe
#=============================================================================================

sub AuctionRelist {

    my $auctions        =   shift;
    my $counter         =   1;
    my $dopt;

    $tm->update_log( "Invoked Method: ".( caller(0) )[3] ) ; 

    # Set Auction loading delay values to a minimum of 5 seconds
    # Multiply the retrieved delay value * 60 to convert to seconds

    my $delay           =   $tm->{ DripFeedInterval };
    $delay              =   $delay * 60;
    my $copies_loaded   =   0;
    
    if ( $delay == 0 ) { $delay = 5; }

    foreach my $auction (@$auctions) {

        $tm->update_log("AuctionRelist: Relisting Auction $auction->{AuctionRef} - $auction->{Title} (Record $auction->{AuctionKey})");

        $pb->{ SetProgressCurrent   }   =   $counter;
        $pb->{ SetCurrentOperation  }   =   "Loading ".$auction->{Title};
        $pb->UpdateMultiBar();

        # If the auction is not the first auction and
        # if the delay is greater then 5 seconds log in for each auction
        # this is to ensure the session is not disconnected while waiting
        # as usual we test that the connection is oK before proceeding

        if  ($counter > 1) {

            if  ( $delay > 5 ) {
                 $pb->{ LoadStatus } = "Drip-feed delay: ".$tm->load_interval()." minutes";
                 $pb->UpdateBar();
            }

            sleep $delay;

            if ( $delay > 5) {
                my $connected = $tm->login();
    
                # if login was not OK update error structure and return

                if ( $tm->{ ErrorStatus } ) {
                    $tm->set_always_minimize( $pb->AlwaysMinimize() );
                    $pb->QuitMultiBar();
                    UpdateErrorStatus();   
                    return $estruct;
                }
                 
                if ( not $connected ) {
                    $tm->set_always_minimize( $pb->AlwaysMinimize() );
                    $pb->QuitMultiBar();
                    $tm->{ Debug } eq "1" ? ( $tm->update_log( "Exit due to no connection" ) ) : () ;
                    UpdateErrorStatus();   
                    return $estruct;
                }
            }
        }

        if  ( $tm->{ Debug } ge "1" ) {    
              $tm->update_log( "Auction record parameters::" );
              while( (my $key, my $value) = each( %$auction ) ) {
                  if ( $key ne 'Description' ) {
                      $tm->update_log( "$key \t: $auction->{ $key }" );
                  }
              }
        }

        $pb->{ SetProgressCurrent   }   =   $counter;
        $pb->UpdateMultiBar();

        $pb->{ SetCurrentOperation  }   =   "Relisting ".$auction->{Title};

        my $message = "";

        # If a template has been specified retrieve the template record and override the old auction values
        # with the values from the template record
        
        if ( $auction->{ UseTemplate } ) {
        
            $tm->update_log("Applying Template $auction->{ TemplateKey }");

            my $template = $tm->get_auction_record( $auction->{ TemplateKey } );
                
            $auction->{ Category       }    =   $template->{ Category       };
            $auction->{ Title          }    =   $template->{ Title          };
            $auction->{ Subtitle       }    =   $template->{ Subtitle       };
            $auction->{ Description    }    =   $template->{ Description    };
            $auction->{ IsNew          }    =   $template->{ IsNew          };
            $auction->{ TMBuyerEmail   }    =   $template->{ TMBuyerEmail   };
            $auction->{ DurationHours  }    =   $template->{ DurationHours  };
            $auction->{ StartPrice     }    =   $template->{ StartPrice     };
            $auction->{ ReservePrice   }    =   $template->{ ReservePrice   };
            $auction->{ BuyNowPrice    }    =   $template->{ BuyNowPrice    };
            $auction->{ ClosedAuction  }    =   $template->{ ClosedAuction  };
            $auction->{ AutoExtend     }    =   $template->{ AutoExtend     };
            $auction->{ BankDeposit    }    =   $template->{ BankDeposit    };
            $auction->{ CreditCard     }    =   $template->{ CreditCard     };
            $auction->{ SafeTrader     }    =   $template->{ SafeTrader     };
            $auction->{ PaymentInfo    }    =   $template->{ PaymentInfo    };
            $auction->{ FreeShippingNZ }    =   $template->{ FreeShippingNZ };
            $auction->{ ShippingInfo   }    =   $template->{ ShippingInfo   };
            $auction->{ ShippingOption }    =   $template->{ ShippingOption };
            $auction->{ PickupOption   }    =   $template->{ PickupOption   };
            $auction->{ Featured       }    =   $template->{ Featured       };
            $auction->{ Gallery        }    =   $template->{ Gallery        };
            $auction->{ BoldTitle      }    =   $template->{ BoldTitle      };
            $auction->{ Featured       }    =   $template->{ Featured       };
            $auction->{ FeatureCombo   }    =   $template->{ FeatureCombo   };
            $auction->{ HomePage       }    =   $template->{ HomePage       };
            $auction->{ Permanent      }    =   $template->{ Permanent      };
            $auction->{ MovieRating    }    =   $template->{ MovieRating    };
            $auction->{ MovieConfirm   }    =   $template->{ MovieConfirm   };
            $auction->{ AttributeName  }    =   $template->{ AttributeName  };
            $auction->{ AttributeValue }    =   $template->{ AttributeValue };
            $auction->{ TMATT104       }    =   $template->{ TMATT104       };
            $auction->{ TMATT104_2     }    =   $template->{ TMATT104_2     };
            $auction->{ TMATT106       }    =   $template->{ TMATT106       };
            $auction->{ TMATT106_2     }    =   $template->{ TMATT106_2     };
            $auction->{ TMATT108       }    =   $template->{ TMATT108       };
            $auction->{ TMATT108_2     }    =   $template->{ TMATT108_2     };
            $auction->{ TMATT111       }    =   $template->{ TMATT111       };
            $auction->{ TMATT112       }    =   $template->{ TMATT112       };
            $auction->{ TMATT115       }    =   $template->{ TMATT115       };
            $auction->{ TMATT117       }    =   $template->{ TMATT117       };
            $auction->{ TMATT118       }    =   $template->{ TMATT118       };

            # if a shipping option is specified retrieve the delivery options

            if ( $auction->{ ShippingOption } ) {
                $dopt = $tm->get_shipping_details( AuctionKey => $auction->{ TemplateKey } );

                $tm->update_log( "Delivery Options specified on Auction: ".scalar( @$dopt ) );

                # Format the number fields to have a decimal point - TM appears not to like 0 as a single number

                foreach my $o ( @$dopt ) {
                    $o->{ Shipping_Details_Cost } = sprintf "%.2f", $o->{ Shipping_Details_Cost };
                    $tm->{ Debug } ge "1" ? $tm->update_log( "Shipping: ".$o->{ Shipping_Details_Text }." @ ".$o->{ Shipping_Details_Cost } ) : ();
                }
            }
        }
        else {
        
            # if a shipping option is specified retrieve the delivery options

            if ( $auction->{ ShippingOption } ) {
                $dopt = $tm->get_shipping_details( AuctionKey => $auction->{ AuctionKey } );

                $tm->update_log( "Delivery Options specified on Auction: ".scalar( @$dopt ) );

                # Format the number fields to have a decimal point - TM appears not to like 0 as a single number

                foreach my $o ( @$dopt ) {
                    $o->{ Shipping_Details_Cost } = sprintf "%.2f", $o->{ Shipping_Details_Cost };
                    $tm->{ Debug } ge "1" ? $tm->update_log( "Shipping: ".$o->{ Shipping_Details_Text }." @ ".$o->{ Shipping_Details_Cost } ) : ();
                }
            }
        }
        
        if ( ( $auction->{ AuctionStatus } eq 'SOLD' ) or ( $auction->{ AuctionStatus } eq 'UNSOLD' ) ) {

            # Check whether the Free Listing Limit has been exceeded if abort property is true

            if ( $tm->{ ListLimitAbort } ) {

                my $ca = $tm->get_current_auction_count();

                if ($tm->{ ListLimitAllowance } eq "") {
                    $tm->{ ListLimitAllowance } = 0;
                }

                my $ll = $tm->get_free_listing_limit() + $tm->{ ListLimitAllowance };

                $tm->update_log("List Limit Allowance Checking");
                $tm->update_log("Current Auction Count: $ca");
                $tm->update_log("Free Listing Limit   : $ll");
                $tm->update_log("List Limit Allowance : $tm->{ ListLimitAllowance }");

                if ( $ca >= $ll ) {
                    ListingLimitAbend();
                    return $estruct;
                }
            }
            # Append the Standard terms to the Auction Desription

            my $terms       = $tm->get_standard_terms( AuctionSite => "TRADEME" );
            my $description = $auction->{ Description }."\n\n".$terms;

            my $maxlength = 2018;

            if ( length( $description ) > $maxlength ) {
                $description = $auction->{ Description };
                $tm->update_log( "Auction $auction->{ Title } (Record $auction->{ AuctionKey }) - standard terms not applied.");
                $tm->update_log( "Combined length of standard terms and description would exceed allowable length");
                $tm->update_log( "Description [".length( $description )."] Terms [".length( $description )."] Threshold [".$maxlength."]");

                $description = $a->{ Description };
            }

            my $newauction = $tm->relist_auction(
                AuctionKey                      =>  $auction->{ AuctionKey     },
                AuctionRef                      =>  $auction->{ AuctionRef     },
                AuctionRef                      =>  $auction->{ AuctionRef     },
                Category                        =>  $auction->{ Category       },
                Title                           =>  $auction->{ Title          },
                Subtitle                        =>  $auction->{ Subtitle       },
                Description                     =>  $description                ,
                IsNew                           =>  $auction->{ IsNew          },
                TMBuyerEmail                    =>  $auction->{ TMBuyerEmail   },
                !($auction->{ ShippingOption }) ?   (   FreeShippingNZ  =>  $auction->{ FreeShippingNZ          }   )   :   ()  ,
                !($auction->{ ShippingOption }) ?   (   ShippingInfo    =>  $auction->{ ShippingInfo            }   )   :   ()  ,           
                $auction->{ PickupOption    }   ?   (   PickupOption    =>  $auction->{ PickupOption            }   )   :   ()  ,
                $auction->{ ShippingOption  }   ?   (   ShippingOption  =>  $auction->{ ShippingOption          }   )   :   ()  ,
                $dopt->[0]                      ?   (   DCost1          =>  $dopt->[0]->{ Shipping_Details_Cost }   )   :   ()  ,
                $dopt->[0]                      ?   (   DText1          =>  $dopt->[0]->{ Shipping_Details_Text }   )   :   ()  ,
                $dopt->[1]                      ?   (   DCost2          =>  $dopt->[1]->{ Shipping_Details_Cost }   )   :   ()  ,
                $dopt->[1]                      ?   (   DText2          =>  $dopt->[1]->{ Shipping_Details_Text }   )   :   ()  ,
                $dopt->[2]                      ?   (   DCost3          =>  $dopt->[2]->{ Shipping_Details_Cost }   )   :   ()  ,  
                $dopt->[2]                      ?   (   DText3          =>  $dopt->[2]->{ Shipping_Details_Text }   )   :   ()  ,
                $dopt->[3]                      ?   (   DCost4          =>  $dopt->[3]->{ Shipping_Details_Cost }   )   :   ()  ,
                $dopt->[3]                      ?   (   DText4          =>  $dopt->[3]->{ Shipping_Details_Text }   )   :   ()  ,
                $dopt->[4]                      ?   (   DCost5          =>  $dopt->[4]->{ Shipping_Details_Cost }   )   :   ()  ,
                $dopt->[4]                      ?   (   DText5          =>  $dopt->[4]->{ Shipping_Details_Text }   )   :   ()  ,
                $dopt->[5]                      ?   (   DCost6          =>  $dopt->[5]->{ Shipping_Details_Cost }   )   :   ()  ,
                $dopt->[5]                      ?   (   DText6          =>  $dopt->[5]->{ Shipping_Details_Text }   )   :   ()  ,
                $dopt->[6]                      ?   (   DCost7          =>  $dopt->[6]->{ Shipping_Details_Cost }   )   :   ()  ,
                $dopt->[6]                      ?   (   DText7          =>  $dopt->[6]->{ Shipping_Details_Text }   )   :   ()  ,
                $dopt->[7]                      ?   (   DCost8          =>  $dopt->[7]->{ Shipping_Details_Cost }   )   :   ()  ,
                $dopt->[7]                      ?   (   DText8          =>  $dopt->[7]->{ Shipping_Details_Text }   )   :   ()  ,
                $dopt->[8]                      ?   (   DCost9          =>  $dopt->[8]->{ Shipping_Details_Cost }   )   :   ()  ,
                $dopt->[8]                      ?   (   DText9          =>  $dopt->[8]->{ Shipping_Details_Text }   )   :   ()  ,
                $dopt->[9]                      ?   (   DCost10         =>  $dopt->[9]->{ Shipping_Details_Cost }   )   :   ()  ,
                $dopt->[9]                      ?   (   DText10         =>  $dopt->[9]->{ Shipping_Details_Text }   )   :   ()  ,
                EndType         =>   $auction->{ EndType        },
                DurationHours   =>   $auction->{ DurationHours  },
                EndDays         =>   $auction->{ EndDays        },
                EndTime         =>   $auction->{ EndTime        },
                StartPrice      =>   $auction->{ StartPrice     },
                ReservePrice    =>   $auction->{ ReservePrice   },
                BuyNowPrice     =>   $auction->{ BuyNowPrice    },
                ClosedAuction   =>   $auction->{ ClosedAuction  },
                AutoExtend      =>   $auction->{ AutoExtend     },
                BankDeposit     =>   $auction->{ BankDeposit    },
                CreditCard      =>   $auction->{ CreditCard     },
                CashOnPickup    =>   $auction->{ CashOnPickup   },
                Paymate         =>   $auction->{ Paymate        },
                Pago            =>   $auction->{ Pago           },
                SafeTrader      =>   $auction->{ SafeTrader     },
                PaymentInfo     =>   $auction->{ PaymentInfo    },
                FreeShippingNZ  =>   $auction->{ FreeShippingNZ },
                ShippingInfo    =>   $auction->{ ShippingInfo   },
                Featured        =>   $auction->{ Featured       },
                Gallery         =>   $auction->{ Gallery        },
                BoldTitle       =>   $auction->{ BoldTitle      },
                Featured        =>   $auction->{ Featured       },
                FeatureCombo    =>   $auction->{ FeatureCombo   },
                HomePage        =>   $auction->{ HomePage       },
                MovieRating     =>   $auction->{ MovieRating    },
                MovieConfirm    =>   $auction->{ MovieConfirm   },
                TMATT038        =>   $auction->{ TMATT038       },
                TMATT163        =>   $auction->{ TMATT163       },
                TMATT164        =>   $auction->{ TMATT164       },
                AttributeName   =>   $auction->{ AttributeName  },
                AttributeValue  =>   $auction->{ AttributeValue },
                TMATT104        =>   $auction->{ TMATT104       },
                TMATT104_2      =>   $auction->{ TMATT104_2     },
                TMATT106        =>   $auction->{ TMATT106       },
                TMATT106_2      =>   $auction->{ TMATT106_2     },
                TMATT108        =>   $auction->{ TMATT108       },
                TMATT108_2      =>   $auction->{ TMATT108_2     },
                TMATT111        =>   $auction->{ TMATT111       },
                TMATT112        =>   $auction->{ TMATT112       },
                TMATT115        =>   $auction->{ TMATT115       },
                TMATT117        =>   $auction->{ TMATT117       },
                TMATT118        =>   $auction->{ TMATT118       },
            );

            if (not defined $newauction) {

                $tm->update_log("Error relisting Auction $auction->{AuctionRef} on TradeMe");

            }
            else {

                $tm->update_log("Auction $auction->{ AuctionRef } relisted on TradeMe as $newauction");

                # Create a new record for the relisted auction

                $message = "Auction relisted from auction ".$auction->{ AuctionRef };

                # Create a new auction record by copying the old record and updating the required details

                $message = "Auction relisted from auction ".$auction->{ AuctionRef };

                my ($closetime, $closedate);

                if ( $auction->{ EndType } eq "DURATION" ) {

                    $closedate = $tm->closedate( $auction->{ DurationHours } );
                    $closetime = $tm->closetime( $auction->{ DurationHours } );
                }

                if ( $auction->{ EndType } eq "FIXEDEND" ) {

                    $closedate = $tm->fixeddate( $auction->{ EndDays } );
                    $closetime = $tm->fixedtime( $auction->{ EndTime } );
                }

                $tm->copy_auction_record(
                    AuctionKey       =>  $auction->{ AuctionKey }                    ,
                    AuctionStatus    =>  "CURRENT"                                   ,
                    AuctionRef       =>  $newauction                                 ,
                    AuctionSold      =>  0                                           ,
                    PromotionFee     =>  0                                           ,
                    ListingFee       =>  0                                           ,
                    SuccessFee       =>  0                                           ,
                    CurrentBid       =>  0                                           ,
                    ShippingAmount   =>  0                                           ,
                    OfferProcessed   =>  0                                           ,
                    WasPayNow        =>  0                                           ,
                    RelistCount      =>  $auction->{ RelistCount  }++                ,
                    RelistStatus     =>  $auction->{ RelistStatus }                  ,
                    DateLoaded       =>  $tm->datenow()                              ,
                    CloseDate        =>  $closedate                                  ,
                    CloseTime        =>  $closetime                                  ,
                    Message          =>  $message                                    ,
                );

                # Delete from Auctionitis if delete from database flag set to True, otherwise update existing record 

                if  ( $tm->{ RelistDBDelete } ) {

                    $tm->delete_auction_record(
                        AuctionKey           =>  $auction->{ AuctionKey },
                    );
                    $tm->update_log("Auction $auction->{ AuctionRef}  (record $auction->{ AuctionKey }) deleted from Auctionitis database");

                }
                else {

                    $message = "Auction relisted as $newauction";
                    $tm->update_auction_record(
                        AuctionKey           =>  $auction->{AuctionKey}  ,
                        AuctionStatus        =>  "RELISTED"              ,
                        Message              =>  $message                ,
                    );
                }

                # Delete from TradeMe if delete from TradeMe flag set to True 

                if ( $tm->{ RelistTMDelete } ) {

                    $tm->delete_auction(
                        AuctionRef => $auction->{ AuctionRef }
                    );
                    $tm->update_log("Auction $auction->{AuctionRef} (record $auction->{AuctionKey}) deleted from TradeMe");
                }
            }
            sleep 2;
        }
        else {
            $tm->update_log("Auction $auction->{AuctionRef} not relisted: Invalid Auction Status ($auction->{AuctionStatus})");
        }

        $counter++;

        if      ( $pb->{ Cancelled } ) {
                CancelHandler();
                return $estruct;
        }
    }

    UpdateErrorStatus();   
    return $estruct;
}

#=============================================================================================
# AuctionOffer - Subroutine to process the actual offer
#=============================================================================================

sub AuctionOffer {

    my $auctions    =   shift;
    my $counter     =   1;
    
    $tm->update_log( "Invoked Method: ".( caller( 0 ) )[3] ); 

    # Calculate total no. of potential offers to be processed
    
    $pb->{ SetProgressTotal     }   =   scalar( @$auctions );
    $pb->UpdateMultiBar();

    $tm->update_log( "Settings for Offer Processing" );
    $tm->update_log( "-----------------------------" );
    $tm->update_log( "OfferDuration       : ".$tm->{ OfferDuration         } );
    $tm->update_log( "OfferHighBid        : ".$tm->{ OfferHighBid          } );
    $tm->update_log( "OfferAV             : ".$tm->{ OfferAV               } );
    $tm->update_log( "OfferWatchers       : ".$tm->{ OfferWatchers         } );
    $tm->update_log( "OfferBidders        : ".$tm->{ OfferBidders          } );
    $tm->update_log( "OfferAuthenticated  : ".$tm->{ OfferAuthenticated    } );
    $tm->update_log( "OfferFeedbackMinimum: ".$tm->{ OfferFeedbackMinimum  } );

    foreach my $auction ( @$auctions ) {

        $pb->{ SetProgressCurrent   }   =   $counter;
        $pb->{ SetCurrentOperation  }   =   "Processing ".$auction->{ AuctionRef }." - ".$auction->{ Title };
        $pb->UpdateMultiBar();

        # If Status is  not sold or unsold log message and move to next record

        unless ( ( $auction->{ AuctionStatus } eq 'SOLD'   ) or ( $auction->{ AuctionStatus } eq 'UNSOLD' ) ) {
            $tm->update_log( "Auction ".$auction->{ AuctionRef }." - ".$auction->{ Title }." Record ".$auction->{ AuctionKey }." not Offered - Invalid Auction Status" );
            $counter++;
            next;
        }

        # If record has no offer amount log message and move to next record

        unless ( $auction->{ OfferPrice } > 0 ) {
            $tm->update_log( "Auction ".$auction->{ AuctionRef }." - ".$auction->{ Title }." Record ".$auction->{ AuctionKey }." not Offered - No Offer price specified" );
            $tm->update_log( "(Stored Offer Price: ".$auction->{ OfferPrice }.")" );
            $counter++;
            next;
        }

        my $offer = $tm->make_offer(
            AuctionRef          => $auction->{ AuctionRef       } ,
            OfferPrice          => $auction->{ OfferPrice       } ,
            OfferDuration       => $tm->{ OfferDuration         } ,
            UseHighestBid       => $tm->{ OfferHighBid          } ,
            AVOnly              => $tm->{ OfferAV               } ,
            OfferWatchers       => $tm->{ OfferWatchers         } ,
            OfferBidders        => $tm->{ OfferBidders          } ,
            AuthenticatedOnly   => $tm->{ OfferAuthenticated    } ,
            FeedbackMinimum     => $tm->{ OfferFeedbackMinimum  } ,
        );

        if ( $offer ) {
    
            $tm->add_offer_record(
                Offer_Date          => $tm->datenow()                 ,
                AuctionRef          => $auction->{ AuctionRef       } ,
                Offer_Amount        => $auction->{ OfferAmount      } ,
                Offer_Duration      => $tm->{ OfferDuration         } ,
                Highest_Bid         => $offer->{ HighBid            } ,
                Offer_Reserve       => $offer->{ Reserve            } ,
                Actual_Offer        => $offer->{ OfferPrice         } ,
                Bidder_Count        => $offer->{ BidderCount        } ,
                Watcher_Count       => $offer->{ WatcherCount       } ,
                Offer_Count         => $offer->{ OfferCount         } ,
                Offer_Type          => $auction->{ AuctionStatus    } ,
                Offer_Successful    => 0                              ,
            );
    
            $tm->update_auction_record(
                AuctionKey          => $auction->{ AuctionKey       } ,
                OfferProcessed      => 1                              ,
            );
        }

        sleep 2;
        $counter++;
    }

    UpdateErrorStatus();   
    return $estruct;
}

#=============================================================================================
# ImportCurrent - Import all current auctions
#=============================================================================================

sub ImportCurrent {

    $tm = Auctionitis->new();
    $tm->initialise(Product => "Auctionitis");  # Initialise the product

    $tm->{ Debug } ge "1" ? ( $tm->dump_properties() ) : () ;

    $tm->update_log("Invoked Method: ". (caller(0))[3]); 

    $tm->update_log("Started: Import Current Auctions");

    $pb = Win32::OLE->new('MultiPB.clsMultiPB') or die;

    ### insert some text into the window header

    $pb->InitialiseMultiBar();
    $pb->{ AlwaysMinimize       }   =   $tm->{ AlwaysMinimize };
    $pb->{ SetWindowTitle       }   =   "Auctionitis: Import Current Auctions";
    
    $pb->AddTask("Import Current Auction Data");
    
    $pb->{ SetCurrentTask       }   =   1;
    $pb->{ SetCurrentOperation  }   =   "Retrieving Current Auction Data";
    $pb->{ SetTaskAction        }   =   "Adding TradeMe auction:";

    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    $tm->update_log("Connecting to Database");
    $tm->DBconnect();                          # Connect to the database

    $tm->update_log("Logging in to TradeMe");
    $tm->login();
    
    # if login was not OK update error structure and return

    if ( $tm->{ ErrorStatus } ) {
        $tm->set_always_minimize( $pb->AlwaysMinimize() );
        $pb->QuitMultiBar();
        UpdateErrorStatus();   
        return $estruct;
    }

    # my $auctions = $tm->get_curr_listings(\&UpdateStatusBar);
    my $auctions = $tm->get_current_auctions( StatusHandler => \&UpdateStatusBar );

    if ( defined(@$auctions) ) {
         ImportAuctions($auctions, "CURRENT");
    }

    $pb->MarkTaskCompleted(1);
    $pb->UpdateMultiBar();

    $tm->update_log("Completed: Import Current Auctions");

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # All Tasks completed
    #-----------------------------------------------------------------------------------------

    $tm->DBdisconnect();                          # disconnect from the database
    
    sleep 2;
    $tm->set_always_minimize( $pb->AlwaysMinimize() );
    $pb->QuitMultiBar();

    UpdateErrorStatus();   
    return $estruct;
}

#=============================================================================================
# ImportSold - Import all sold auctions
#=============================================================================================

sub ImportSold {

    $tm = Auctionitis->new();
    $tm->initialise(Product => "Auctionitis");  # Initialise the product

    $tm->{ Debug } ge "1" ? ( $tm->dump_properties() ) : () ;

    $tm->update_log("Invoked Method: ". (caller(0))[3]); 

    $pb = Win32::OLE->new('MultiPB.clsMultiPB') or die;

    $tm->update_log("Started: Import Sold Auctions");

    ### insert some text into the window header

    $pb->InitialiseMultiBar();
    $pb->{ AlwaysMinimize       }   =   $tm->{ AlwaysMinimize };
    $pb->{ SetWindowTitle       }   =   "Auctionitis: Import Sold Auctions";
    
    $pb->AddTask("Import Sold Auction Data");
    
    $pb->{ SetCurrentTask       }   =   1;
    $pb->{ SetCurrentOperation  }   =   "Retrieving Sold Auction Data";
    $pb->{ SetTaskAction        }   =   "Adding TradeMe auction:";
    
    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    $tm->update_log("Connecting to Database");
    $tm->DBconnect();                           # Connect to the database

    $tm->update_log("Logging in to TradeMe");
    $tm->login();
    
    # if login was not OK update error structure and return

    if ( $tm->{ ErrorStatus } ) {
        $tm->set_always_minimize( $pb->AlwaysMinimize() );
        $pb->QuitMultiBar();
        UpdateErrorStatus();   
        return $estruct;
    }

    my $auctions = $tm->new_get_sold_listings( 
        Filter          => 'all'                ,
        StatusHandler   => \&UpdateStatusBar    , 
    );
   
    if (  defined(@$auctions) ) {
         ImportAuctions($auctions, "SOLD");
    }

    $pb->MarkTaskCompleted(1);
    $pb->UpdateMultiBar();

    $tm->update_log("Completed: Import Sold Auctions");

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # All Tasks completed
    #-----------------------------------------------------------------------------------------

    $tm->DBdisconnect();                          # disconnect from the database

    sleep 2;
    $tm->set_always_minimize( $pb->AlwaysMinimize() );
    $pb->QuitMultiBar();

    UpdateErrorStatus();   
    return $estruct;
}

#=============================================================================================
# ImportUnsold - Import All Unsold Auctions
#=============================================================================================

sub ImportUnsold {

    $tm = Auctionitis->new();
    $tm->initialise(Product => "Auctionitis");  # Initialise the product

    $tm->{ Debug } ge "1" ? ( $tm->dump_properties() ) : () ;

    $tm->update_log("Invoked Method: ". (caller(0))[3]); 

    $tm->update_log("Started: Import Unsold Auctions");

    $pb = Win32::OLE->new('MultiPB.clsMultiPB') or die;

    ### insert some text into the window header

    $pb->InitialiseMultiBar();
    $pb->{ AlwaysMinimize       }    =  $tm->{ AlwaysMinimize };
    $pb->{ SetWindowTitle       }   =   "Auctionitis: Import Unsold Auctions";
    
    $pb->AddTask("Import Unsold Auction Data");
    
    $pb->{ SetCurrentTask       }   =   1;
    $pb->{ SetCurrentOperation  }   =   "Retrieving Unsold Auction Data";
    $pb->{ SetTaskAction        }   =   "Adding TradeMe auction:";
    
    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    $tm->update_log("Connecting to Database");
    $tm->DBconnect();                           # Connect to the database

    $tm->update_log("Logging in to TradeMe");
    $tm->login();
    
    # if login was not OK update error structure and return

    if ( $tm->{ ErrorStatus } ) {
        $tm->set_always_minimize( $pb->AlwaysMinimize() );
        $pb->QuitMultiBar();
        UpdateErrorStatus();   
        return $estruct;
    }

    my $auctions = $tm->get_unsold_listings(\&UpdateStatusBar);

    if ( defined(@$auctions) ) {
         ImportAuctions($auctions, "UNSOLD");
    }

    $pb->MarkTaskCompleted(1);
    $pb->UpdateMultiBar();

    $tm->update_log("Completed: Import Unold Auctions");

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # All Tasks completed
    #-----------------------------------------------------------------------------------------

    $tm->DBdisconnect();                          # disconnect from the database
    
    sleep 2;
    $tm->set_always_minimize( $pb->AlwaysMinimize() );
    $pb->QuitMultiBar();

    UpdateErrorStatus();   
    return $estruct;
}

#=============================================================================================
# ImportAll - Import All auctions in MyTradeMe (Sold, Unsold, Current)
#=============================================================================================

sub ImportAll {

    my $auctions;

    $tm = Auctionitis->new();
    $tm->initialise(Product => "Auctionitis");  # Initialise the product

    $tm->update_log("Invoked Method: ". (caller(0))[3]); 

    $tm->{ Debug } ge "1" ? ( $tm->dump_properties() ) : () ;

    $pb = Win32::OLE->new('MultiPB.clsMultiPB') or die;

    ### insert some text into the window header

    $pb->InitialiseMultiBar();
    $pb->{ AlwaysMinimize       }   =   $tm->{ AlwaysMinimize };
    $pb->{ SetWindowTitle       }   =   "Auctionitis: Import All Auctions";
    
    $pb->AddTask("Import Current Auction Data");
    $pb->AddTask("Import Sold Auction Data");
    $pb->AddTask("Import Unsold Auction Data");

    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    $tm->update_log("Connecting to Database");
    $tm->DBconnect();                          # Connect to the database

    $tm->update_log("Logging in to TradeMe");
    $tm->login();
    
    # if login was not OK update error structure and return

    if ( $tm->{ ErrorStatus } ) {
        $tm->set_always_minimize( $pb->AlwaysMinimize() );
        $pb->QuitMultiBar();
        UpdateErrorStatus();   
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # Task 1 - Process Current Auctions
    #-----------------------------------------------------------------------------------------

    $tm->update_log("Started: Import Current Auctions");

    $pb->{ SetCurrentTask       }   =   1;
    $pb->{ SetCurrentOperation  }   =   "Retrieving Current Auction Data";
    $pb->{ SetTaskAction        }   =   "Adding TradeMe auction:";
    
    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    # $auctions = $tm->get_curr_listings(\&UpdateStatusBar);
    $auctions = $tm->get_current_auctions( StatusHandler => \&UpdateStatusBar );

    if ( defined(@$auctions) ) {
        ImportAuctions($auctions, "CURRENT");
    }

    $pb->MarkTaskCompleted(1);
    $pb->UpdateMultiBar();

    $tm->update_log("Completed: Import Current Auctions");

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
        return $estruct;
    }
    
    #-----------------------------------------------------------------------------------------
    # Task 2 - Process Sold Auctions
    #-----------------------------------------------------------------------------------------

    $tm->update_log("Started: Import Sold Auctions");

    $pb->{ SetCurrentTask       }   =   2;
    $pb->{ SetCurrentOperation  }   =   "Retrieving Sold Auction Data";
    $pb->{ SetTaskAction        }   =   "Adding TradeMe auction:";
    
    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    $auctions = $tm->new_get_sold_listings( StatusHandler => \&UpdateStatusBar );

    if ( defined(@$auctions) ) {
         ImportAuctions($auctions, "SOLD");
    }

    $pb->MarkTaskCompleted(2);
    $pb->UpdateMultiBar();

    $tm->update_log("Completed: Import Sold Auctions");

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # Task 3 - Process Unsold Auctions
    #-----------------------------------------------------------------------------------------

    $tm->update_log("Started: Import Unsold Auctions");

    $pb->{ SetCurrentTask       }   =   3;
    $pb->{ SetCurrentOperation  }   =   "Retrieving Unsold Auction Data";
    $pb->{ SetTaskAction        }   =   "Adding TradeMe auction:";
    
    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    $auctions = $tm->get_unsold_listings(\&UpdateStatusBar);
    
    if ( defined(@$auctions) ) {
        ImportAuctions($auctions, "UNSOLD");
    }

    $pb->MarkTaskCompleted(3);
    $pb->UpdateMultiBar();

    $tm->update_log("Completed: Import unsold Auctions");

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # All Tasks completed
    #-----------------------------------------------------------------------------------------

    $tm->DBdisconnect();                          # disconnect from the database

    sleep 2;
    $tm->set_always_minimize( $pb->AlwaysMinimize() );
    $pb->QuitMultiBar();

    UpdateErrorStatus();   
    return $estruct;

}

#=============================================================================================
# ImportAuctions - Subroutine to do the actual Import processing
#=============================================================================================

sub ImportAuctions {

    my $auctions    = shift;
    my $status      = shift;

    $tm->update_log("Invoked Method: ". (caller(0))[3]); 

    $pb->{ SetProgressTotal     }   =   @$auctions;
    $pb->UpdateMultiBar();

    my $counter = 1;

    # Update current auction data from list of auctions
    
    my( $dd, $mm, $yy )   = ( localtime( time ) )[3,4,5];
    my $now = $dd."/".($mm + 1)."/".($yy + 1900);

    my $ImportMessage = "Imported from TradeMe on $now";

    # create the Imported Pictures directory if not already present

    eval { mkdir 'C:\\Program Files\\Auctionitis\\ImportedPics'; };

    foreach my $a ( @$auctions ) {

        $tm->update_log("AuctionImport: Importing TradeMe Auction $a->{ AuctionRef }");

        $pb->{ SetProgressCurrent   }   =   $counter;
        $pb->UpdateMultiBar();

        if ( not $tm->is_DBauction_104( $a->{ AuctionRef } ) ) {

            my %imp = $tm->import_auction_details( $a->{ AuctionRef } , $status );

            # Check that the category is valid before writing the imported record to the database

            if ( $tm->is_valid_category( $imp{ Category } ) ) {

                $a->{ Listing_Fee           } = 0 unless $a->{ Listing_Fee          };
                $a->{ Promotion_Fee         } = 0 unless $a->{ Promotion_Fee        };
                $a->{ Success_Fee           } = 0 unless $a->{ Success_Fee          };
                $a->{ Selected_Ship_Cost    } = 0 unless $a->{ Selected_Ship_Cost   };

                $a->{ CurrentBid            } = $a->{ Sale_Price     } if $a->{ Sale_Price };
                $a->{ CurrentBid            } = $a->{ Max_Bid_Amount } if $a->{ Max_Bid_Amount };
                $a->{ CurrentBid            } = 0 unless $a->{ CurrentBid };

                $imp{ AuctionSite           } = "TRADEME";
                $imp{ EFTPOS                } = 0;
                $imp{ Quickpay              } = 0;
                $imp{ AgreePayMethod        } = 0;

                $imp{ ListingFee            } = $a->{ Listing_Fee           };
                $imp{ PromotionFee          } = $a->{ Promotion_Fee         };
                $imp{ SuccessFee            } = $a->{ Success_Fee           };
                $imp{ CurrentBid            } = $a->{ CurrentBid            };
                $imp{ ShippingAmount        } = $a->{ Selected_Ship_Cost    };

                $imp{ DateLoaded            } = $a->{ Start_Date    } if $a->{ Start_Date   };

                $imp{ CloseDate             } = $a->{ CloseDate     } if $a->{ CloseDate    };  #UNSOLD
                $imp{ CloseTime             } = $a->{ CloseTime     } if $a->{ CloseTime    };

                $imp{ CloseDate             } = $a->{ End_Date      } if $a->{ End_Date     };  #CURRENT
                $imp{ CloseTime             } = $a->{ End_Time      } if $a->{ End_Time     };  

                $imp{ CloseDate             } = $a->{ Sold_Date     } if $a->{ Sold_Date    };  #SOLD
                $imp{ CloseTime             } = $a->{ Sold_Time     } if $a->{ Sold_Time    };
    
                $pb->{ SetCurrentOperation } = "Adding auction ".$a->{ AuctionRef } .": ".$imp{ Title };
    
                # Convert newlines to memo eol value in database
                # !!! Appears not to be necessary with new import using tokeparser
                # $data{Description} =~ s/\n/\x0D\x0A/g;         # change newlines to mem cr/lf combo   
    
                # use an eval statement to insert the auction so we can trap errors and continue processing
    
                my $auctionkey;
    
                eval { $auctionkey = $tm->add_auction_record_202( %imp ) };
                            
                if ( $@ ne '' ) { 
    
                    $pb->{SetCurrentOperation} = "Import Operation FAILED for auction $a->{ AuctionRef }";
                    $tm->update_log( "Import operation failed: $@");
                    $tm->update_log( "Import data: AuctionRef         $a->{ AuctionRef }    " );
    
                    foreach my $k ( sort keys %imp ) {
                        $tm->update_log( "$k:\t $imp{$k}" );
                    }
                }
                else {

                    # import the picture data

                    my $pickey = AddTradeMeImage( $a->{ AuctionRef } );

                    # Check the return file name is not NOPIC (auction has no picture) and the returned file is found in the file system

                    if ( defined( $pickey ) ) {

                        $tm->add_auction_images_record(
                            AuctionKey      =>  $auctionkey     ,          
                            PictureKey      =>  $pickey         ,          
                            ImageSequence   =>  1               ,           
                        );

                        $tm->update_log( "Added Image record for Auction Key: ".$auctionkey."; Picture Key: ".$pickey."; Seq: 1" );
                    }

                    # Add the individual shipping costs

                    my $x = 1;
    
                    while ( $x < 11 ) {
    
                        my $ck = "DCost".$x;    # Delivery cost Key
                        my $tk = "DText".$x;    # Delivery text key
    
                        if ( $imp{ $ck } ) {
    
                            $tm->add_shipping_details_record (
                                AuctionKey                 =>   $auctionkey ,
                                Shipping_Details_Seq       =>   $x          ,
                                Shipping_Details_Cost      =>   $imp{ $ck } ,
                                Shipping_Details_Text      =>   $imp{ $tk } ,          
                                Shipping_Option_Code       =>   ""          ,
                            );
                        }    
                        $x++;
                    }
                    $tm->update_log("Auction $a->{ AuctionRef } ($status) Imported to Auctionitis database");
                }

            }
            else {
                $pb->{ SetCurrentOperation } = "Auction ".$a->{ AuctionRef }. " not added - Category ".$imp{ Category }." not recognised by Auctionitis";
                $tm->update_log("Auction ".$a->{ AuctionRef }. " ($status) not added - Category ".$imp{ Category }." not recognised by Auctionitis");
            }
            sleep 1;
        }
        else {

            $pb->{ SetCurrentOperation } = "Auction ".$a->{ AuctionRef }. " not added - record already exists in database";
            $tm->update_log("Auction $a->{ AuctionRef }  ($status) not imported to Auctionitis database - record already exists");
        }

        $counter++;

        if      ( $pb->{ Cancelled } ) {
                CancelHandler();
                return $estruct;
        }

    }

    UpdateErrorStatus();   
    return $estruct;
}

#=============================================================================================
# GetTMImageData - Get Image Data from Trade me Auction
#=============================================================================================

sub AddTradeMeImage {

    my $auctionref = shift;
    
    my $url = "http://www.trademe.co.nz/Browse/Listing.aspx?id=".$auctionref ;

    $tm->update_log( "Importing Image from auction: ".$auctionref );

    # Get picture URL - returned format: "http://images.trademe.co.nz/photoserver/tq/42/83787342.jpg"

    my $link = $tm->get_picture_link( $auctionref );

    $tm->{ Debug } ge "1" ? ( $tm->update_log( "Extracted Picture URL: ".$link ) ) : () ;

    if ( $link eq "NOPIC" ) {
        $tm->update_log( "No Image found on TradeMe for Auction ".$auctionref );
        return;
     }

    # Image URL in format "http://images.trademe.co.nz/photoserver/tq/42/83787342.jpg"

    $link =~ m/(.*)(\/)(.+?)(\.)(.+?)($)/;
    my $photoid     = $3;
    my $imagename   = $3.$4.$5;

    $tm->update_log( "Extracted TradeMe Photo ID: ".$photoid." (".$imagename.")" );

    my $pickey = $tm->get_picturekey_by_PhotoId( PhotoId => $photoid );

    if ( defined( $pickey ) ) {
        $tm->update_log( "Existing Record found in table PICTURES for Photo ID: ".$photoid." - PictureKey: ".$pickey );
        return $pickey;
    } 
    else {
        $tm->update_log( "No record found in table PICTURES for Photo ID: ".$photoid );
        $tm->update_log( "Downloading picture file for auction: ".$auctionref );

        my $pickey = $tm->import_image_to_DB(
            URL         =>  $link       ,
            ImageName   =>  $imagename  ,
            PhotoId     =>  $photoid    ,
        );
        return $pickey;
    }
}

#=============================================================================================
# UpdateDB - Update the auction database with the latest details from tradeMe
#=============================================================================================

sub UpdateDB {

    my ($current, $sold, $unsold, $closed);

    $tm = Auctionitis->new();
    $tm->initialise(Product => "Auctionitis");  # Initialise the product

    $tm->update_log("Invoked Method: ". (caller(0))[3]); 

    $tm->{ Debug } ge "1" ? ( $tm->dump_properties() ) : () ;

    $pb = Win32::OLE->new('MultiPB.clsMultiPB') or die;

    ### insert some text into the window header

    $pb->InitialiseMultiBar();
    $pb->{ AlwaysMinimize       }   =   $tm->{ AlwaysMinimize };
    $pb->{ SetWindowTitle       }   =   "Auctionitis: Update Database";
    
    $pb->AddTask( "Update Sold Auction Data"    );
    $pb->AddTask( "Update Unsold Auction Data"  );
    $pb->AddTask( "Update Current Auction Data" );
    $pb->AddTask( "Update Closed Auctions"      );

    if ( $tm->{ DeleteClosed } ) {
         $pb->AddTask("Delete Closed Auctions");
    }
    
    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    $tm->update_log("Connecting to Database");
    $tm->DBconnect();                          # Connect to the database

    $tm->update_log("Logging in to TradeMe");
    $tm->login();
    
    # if login was not OK update error structure and return

    if ( $tm->{ ErrorStatus } ) {
         $tm->set_always_minimize( $pb->AlwaysMinimize() );
         $pb->QuitMultiBar();
         UpdateErrorStatus();   
         return $estruct;
    }

    $pb->{ SetCurrentOperation  }   =   "Retrieving Auction Status Data";

    # $current                        =   $tm->get_curr_listings(\&UpdateStatusBar);
    $current    = $tm->get_current_auctions( StatusHandler    => \&UpdateStatusBar );
    $sold       = $tm->new_get_sold_listings( StatusHandler   => \&UpdateStatusBar );
    $unsold     = $tm->get_unsold_listings(\&UpdateStatusBar);

    #-----------------------------------------------------------------------------------------
    # Task 1 Process Sold Auctions
    #-----------------------------------------------------------------------------------------

    $tm->update_log("Started: Update Sold Auctions");

    $pb->{ SetCurrentTask       }   =   1;
    $pb->{ SetCurrentOperation  }   =   "Retrieving Sold Auction Data";
    $pb->{ SetTaskAction        }   =   "Updating auction:";
    
    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    if ( defined( $sold ) ) {
         UpdateSoldAuctions($sold, "SOLD");
    }

    $pb->MarkTaskCompleted(1);
    $pb->UpdateMultiBar();
    sleep 2;

    $tm->update_log("Completed: Update Sold Auctions");

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # Task 2 Process Unsold Auctions
    #-----------------------------------------------------------------------------------------

    $tm->update_log("Started: Update Unsold Auctions");

    $pb->{ SetCurrentTask       }   =   2;
    $pb->{ SetCurrentOperation  }   =   "Retrieving Unsold Auction Data";
    $pb->{ SetTaskAction        }   =   "Updating auction:";

    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    if ( defined($unsold) ) {
         UpdateUnsoldAuctions($unsold, "UNSOLD");
    }

    $pb->MarkTaskCompleted(2);
    $pb->UpdateMultiBar();
    sleep 2;

    $tm->update_log("Completed: Update Unsold Auctions");

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
        return $estruct;
    }
    
    #-----------------------------------------------------------------------------------------
    # Task 3 Update Current Auctions
    #-----------------------------------------------------------------------------------------

    $tm->update_log("Started: Update Current Auctions");

    $pb->{ SetCurrentTask       }   =   3;
    $pb->{ SetCurrentOperation  }   =   "Updating Current Auction Data";
    $pb->{ SetTaskAction        }   =   "Updating auction:";

    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();
   
    # Update all current auction statuses & close dates to ensure they are current & correct

    if ( defined($current) ) {
         UpdateCurrentAuctions($current, "CURRENT");
    }

    $pb->MarkTaskCompleted(3);
    $pb->UpdateMultiBar();
    sleep 2;

    $tm->update_log("Completed: Update Current Auctions");

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # Task 4 Update Closed Auctions
    #-----------------------------------------------------------------------------------------

    $tm->update_log("Started: Update Closed Auctions");

    $pb->{ SetCurrentTask       }   =   4;
    $pb->{ SetCurrentOperation  }   =   "Updating Closed Auctions";
    $pb->{ SetTaskAction        }   =   "Updating auction:";
    $pb->UpdateMultiBar();
   
    $closed = IdentifyClosedAuctions($current, $sold, $unsold);

    if ( defined(@$closed) ) {
            UpdateClosedAuctions($closed);
    }

    $pb->MarkTaskCompleted(4);
    $pb->UpdateMultiBar();

    $tm->update_log("Completed: Update Closed Auctions");

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
        return $estruct;
    }
    
    #-----------------------------------------------------------------------------------------
    # Task 5 Delete Closed auctions
    #-----------------------------------------------------------------------------------------

    $tm->update_log("Started: Delete Closed Auctions");

    if ( $tm->{ DeleteClosed } ) {

        $pb->{SetCurrentTask} = 5;
        $pb->{SetCurrentOperation} = "Deleting Closed Auctions";
        $pb->{SetTaskAction} = "Deleting auction:";
        $pb->UpdateMultiBar();

        # Delete auction from list of closed auctions

        my $auctions = $tm->get_closed_auctions();        

        $pb->{SetProgressTotal} = scalar(@$auctions);
        $pb->UpdateMultiBar();

        my $counter = 1;

        foreach my $closed (@$auctions) {

        $pb->{ SetProgressCurrent   }   =   $counter;
        $pb->{ SetCurrentOperation  }   =   "Deleting closed auction ".$closed->{AuctionRef}.": ".$closed->{Title};
        $pb->UpdateMultiBar();

        $tm->delete_auction_record( AuctionKey  =>  $closed->{ AuctionKey } );

        $counter++;

            if      ( $pb->{ Cancelled } ) {
                    CancelHandler();
                    return $estruct;
            }
        }

        $pb->MarkTaskCompleted(5);
        $pb->UpdateMultiBar();

        $tm->update_log("Completed: Delete Closed Auctions");

        # Handle the task being cancelled via the CANCEL button or ending abnormally

        if ($abend) {
            return $estruct;
        }

    }

    #-----------------------------------------------------------------------------------------
    # All Tasks comnpleted - cleanup and return
    #-----------------------------------------------------------------------------------------

    $tm->DBdisconnect();                          # disconnect from the database

    $tm->update_log("Completed: Update DataBase procedure");

    # pause for 60 seconds to give the database a chance to quiesce

    $pb->{SetCurrentOperation} = "Quiescing";
    $pb->UpdateMultiBar();

    sleep 2;

    $tm->set_always_minimize( $pb->AlwaysMinimize() );
    $pb->QuitMultiBar();

    UpdateErrorStatus();   
    return $estruct;
}

#=============================================================================================
# UpdateDB - Update the auction database with the latest details from tradeMe
#=============================================================================================

sub UpdateDBSella {

    $tm = Auctionitis->new();
    $tm->initialise( Product => "Auctionitis" );  # Initialise the product

    $tm->update_log( "Invoked Method: ".(caller(0))[3] ); 

    $pb = Win32::OLE->new( 'MultiPB.clsMultiPB' ) or die;

    ### insert some text into the window header

    $pb->InitialiseMultiBar();
    $pb->{ AlwaysMinimize       }   =   $tm->{ AlwaysMinimize };
    $pb->{ SetWindowTitle       }   =   "Auctionitis: Update Sella Database";
    
    $pb->AddTask( "Retrieve Sella Auction Data" );
    $pb->AddTask( "Update Sella Auction Status" );
    
    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    $tm->update_log( "Connecting to Database" );
    $tm->DBconnect();                          # Connect to the database

    $tm->update_log( "Logging in to Sella" );
    $tm->connect_to_sella();
    
    # if login was not OK update error structure and return

    if ( $tm->{ ErrorStatus } ) {
         $tm->set_always_minimize( $pb->AlwaysMinimize() );
         $pb->QuitMultiBar();
         UpdateErrorStatus();   
         return $estruct;
    }

    $pb->{ SetCurrentOperation } = "Retrieving Sella Auction Status Data";

    #-----------------------------------------------------------------------------------------
    # Task 1: Retrieve Sella Auction Data
    #-----------------------------------------------------------------------------------------

    $tm->update_log( "Started: Retrieve Sella Auction Data" );

    $pb->{ SetCurrentTask       }   =   1;
    $pb->{ SetCurrentOperation  }   =   "Retrieving Status Data from Sella";
    $pb->{ SetTaskAction        }   =   "Retrieving auction: ";


    my $items = $tm->get_open_listings( 
        AuctionSite =>  'SELLA'         ,
    );

    $pb->UpdateMultiBar();

    my $counter = 1;

    $pb->{ SetProgressTotal } = scalar( @$items );

    # Get Auction state date for items in the list of open auctions

    my @listings;

    if ( scalar( $items ) > 0 ) {
        foreach my $i ( @$items ) {

            $pb->UpdateMultiBar();
            $pb->{ SetProgressCurrent } = $counter;

            my $state = $tm->sella_get_listing_state( AuctionRef => $i->{ AuctionRef } );

            if ( defined( $state ) ) {
                $state->{ AuctionKey } = $i->{ AuctionKey };

                if ( not $state->{ active } ) {
                    $state->{ CloseDate } = $tm->format_sella_close_date(
                        CloseDate   =>  $state->{ date_closed } ,
                        Format      =>  'DATE'                  ,
                    );
                    $state->{ CloseTime } = $tm->format_sella_close_date(
                        CloseDate   =>  $state->{ date_closed } ,
                        Format      =>  'TIME'                  ,
                    );
                    if ( $state->{ purchased_price } > 0 ) {
                        $state->{ Status } = 'SOLD';
                    }
                    else {
                        $state->{ Status } = 'UNSOLD';
                    }
                    push ( @listings, $state );
                }
            }
            $counter++;
        }
    }

    $pb->MarkTaskCompleted(1);
    $pb->UpdateMultiBar();

    $tm->update_log("Completed: Retrieve Sella Auction Data");

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ( $abend ) {
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # Task 2: Update Sella Auction Status
    #-----------------------------------------------------------------------------------------

    $tm->update_log( "Started: Update Sella Auction Status" );

    $pb->{ SetCurrentTask       }   =   2;
    $pb->{ SetCurrentOperation  }   =   "Processing Completed Auction Data";
    $pb->{ SetTaskAction        }   =   "Updating auction: ";
    $pb->{ SetProgressTotal     }   =   scalar( @$items );
    
    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    if ( scalar( @listings ) > 0 ) {

        my $counter = 1;

        foreach my $l ( @listings ) {

            $pb->{ SetProgressCurrent } = $counter;
            $pb->UpdateMultiBar();

            my $r = $tm->get_auction_record( $l->{ AuctionKey } );

            $pb->{ SetCurrentOperation } = "Updating auction ".$r->{ AuctionRef }.": ".$r->{ Title };

            $tm->update_log("Updating auction ".$r->{ AuctionRef }." [ $l->{ Status } ]: ".$r->{ Title });

            $pb->UpdateMultiBar();
            $pb->{ SetProgressCurrent } = $counter;

            # Check if the auction has finished and if it has mark it sold or unsold based
            # on whether there is a purchase price greater than 0

            if ( $l->{ Status } eq 'SOLD' ) {

                # If auction has status of CURRENT Decrement StockOnHand if StockOnHand > 0 
                # The Status test is to ensure the stock is only reduced once

                if ( $r->{ AuctionStatus } eq 'CURRENT' ) {
                    if ( $r->{ StockOnHand } > 0 )   { 
                        $r->{ StockOnHand }--; 
                        if (  $r->{ ProductCode } ne '' ) {
                            $tm->update_stock_on_hand(
                                ProductCode =>  $r->{ ProductCode } ,
                                StockOnHand =>  $r->{ StockOnHand } ,
                            );
                        }
                    }
                }

                $tm->update_log("Updating: AuctionKey       $l->{ AuctionKey }          ");
                $tm->update_log("          AuctionStatus    SOLD                        ");
                $tm->update_log("          AuctionSold      1                           ");
                # $tm->update_log("          SaleType         $sale->{ Sale_Type }        ");
                $tm->update_log("          StockOnHand      $r->{ StockOnHand }         ");
                $tm->update_log("          CloseDate        $l->{ CloseDate }        ");
                $tm->update_log("          CloseTime        $l->{ CloseTime }        ");

                $tm->update_auction_record(
                    AuctionKey      =>  $l->{ AuctionKey }     ,
                    AuctionStatus   =>  'SOLD'                 ,
                    AuctionSold     =>  1                      ,
                    StockOnHand     =>  $r->{ StockOnHand }    ,
                    CloseDate       =>  $l->{ CloseDate }      ,
                    CloseTime       =>  $l->{ CloseTime }      ,
                );
            }
            elsif ( $l->{ Status } eq 'UNSOLD' ) {
    
                $tm->update_log("Updating: AuctionKey       $l->{ AuctionKey }          ");
                $tm->update_log("          AuctionStatus    UNSOLD                      ");
                $tm->update_log("          AuctionSold      0                           ");

                $tm->update_auction_record(
                    AuctionKey      =>  $l->{ AuctionKey }     ,
                    AuctionStatus   =>  'UNSOLD'               ,
                    AuctionSold     =>  0                      ,
                    CloseDate       =>  $l->{ CloseDate }      ,
                    CloseTime       =>  $l->{ CloseTime }      ,
                );
            }
            $counter++;
        }
    }

    $pb->MarkTaskCompleted(1);
    $pb->UpdateMultiBar();
    sleep 2;

    $tm->update_log("Completed: Update Sella Auction Status");

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ( $abend ) {
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # All Tasks comnpleted - cleanup and return
    #-----------------------------------------------------------------------------------------

    $tm->DBdisconnect();                          # disconnect from the database

    $tm->update_log("Completed: Update DataBase procedure");

    # pause for 60 seconds to give the database a chance to quiesce

    $pb->{SetCurrentOperation} = "Quiescing";
    $pb->UpdateMultiBar();

    sleep 2;

    $tm->set_always_minimize( $pb->AlwaysMinimize() );
    $pb->QuitMultiBar();

    UpdateErrorStatus();   
    return $estruct;
}

#=============================================================================================
# UpdateSoldAuctions - Perform specific updates on auctions during UpdateDB processing
#=============================================================================================

sub UpdateSoldAuctions {

    my $solddata = shift;
    my $status = shift;

    $tm->update_log("Invoked Method: ". (caller(0))[3]); 

    $pb->{SetProgressTotal} = scalar(@$solddata);
    $pb->UpdateMultiBar();

    my $counter = 1;

    # Save the old autocommit value and then explicitly set autocommit off.

    my $oldcommitval = $tm->{ DBH }->{ AutoCommit  };
    $tm->{ DBH }->{ AutoCommit  } = 0;

    # Update current auction data from list of auctions


    foreach my $s ( @$solddata ) {

        # $s - refers sales records
        # $a - refers to auction records

        $pb->{ SetProgressCurrent } = $counter;
        $pb->UpdateMultiBar();

        # Next record if auction ref not found in database

        if ( not $tm->is_DBauction_104( $s->{ AuctionRef } ) ) {
            $pb->{ SetCurrentOperation} = "Auction ".$s->{ AuctionRef } . " not updated - record not found in database";
            $tm->update_log( "Auction ".$s->{ AuctionRef } . " not updated - record not found in database" );
            next;
        }

        # Get the auction key for the auction & saletype; If no key found for auction & sale type
        #  get key matching auction reference only as auction has not had a sales txn as yet

        my $auctionkey = $tm->get_auction_key_by_saletype(
            AuctionRef  => $s->{ AuctionRef  } ,
            SaleType    => $s->{ Sale_Type   } ,
        );

        $auctionkey = $tm->get_auction_key( $s->{ AuctionRef } ) unless defined $auctionkey;

        # Get the auction krecord for the retrieved key 

        my $a = $tm->get_auction_record( $auctionkey );

        $pb->{ SetCurrentOperation } = "Updating auction ".$s->{ AuctionRef }.": ".$a->{ Title };

        $tm->update_log( "Updating auction ".$s->{ AuctionRef }." [ $status ]: ".$a->{ Title } );

        # If the auction status is RELISTED then update shipping amount only;
        # all other actions processed when sale txn first received

        if ( $a->{ AuctionStatus } eq 'RELISTED' ) {

            $tm->update_log("Update Shipping Amount for RELISTED record             ");
            $tm->update_log("Updating: AuctionKey       $auctionkey                 ");
            $tm->update_log("          SaleType         $s->{ Sale_Type }           ");
            $tm->update_log("          ShippingAmount   $s->{ Selected_Ship_Cost }  ");

            $tm->update_auction_record(
                AuctionKey                  =>   $auctionkey                            ,
                ShippingAmount              =>   $s->{ Selected_Ship_Cost }             ,
                SuccessFee                  =>   $s->{ Success_Fee }                    ,
                PromotionFee                =>   $s->{ Promotion_Fee }                  ,
                ListingFee                  =>   $s->{ Listing_Fee }                    ,
                CurrentBid                  =>   $s->{ Sale_Price }                     ,

            );
        }

        # If the saletype in the sales update file is the same as the auction record sales type 
        # then update shipping amount only; all other actions processed when sale txn first received

        elsif ( $a->{ SaleType } eq $s->{ Sale_Type } ) {

            $tm->update_log("Update Shipping Amount for EXISTING sales record       ");
            $tm->update_log("Updating: AuctionKey       $auctionkey                 ");
            $tm->update_log("          SaleType         $s->{ Sale_Type }           ");
            $tm->update_log("          ShippingAmount   $s->{ Selected_Ship_Cost }  ");

            $tm->update_auction_record(
                AuctionKey                  =>   $auctionkey                            ,
                ShippingAmount              =>   $s->{ Selected_Ship_Cost }             ,
                SuccessFee                  =>   $s->{ Success_Fee }                    ,
                PromotionFee                =>   $s->{ Promotion_Fee }                  ,
                ListingFee                  =>   $s->{ Listing_Fee }                    ,
                CurrentBid                  =>   $s->{ Sale_Price }                     ,

            );
        }

        # If the auction hasnt been sold before (AuctionSold = 0 and SaleType = BLANK) then update
        # the auction record with the sales details and reduce stock onhand value for product code

        elsif ( $a->{ AuctionSold } == 0 ) {

            $tm->update_log("Update EXISTING Auction Record with NEW sales data     ");
            $tm->update_log("Updating: AuctionKey       $auctionkey                 ");
            $tm->update_log("          SaleType         $s->{ Sale_Type }           ");
            $tm->update_log("          AuctionStatus    SOLD                        ");
            $tm->update_log("          AuctionSold      1                           ");
            $tm->update_log("          SuccessFee       $s->{ Success_Fee }         ");
            $tm->update_log("          PromotionFee     $s->{ Promotion_Fee }       ");
            $tm->update_log("          ListingFee       $s->{ Listing_Fee }         ");
            $tm->update_log("          CurrentBid       $s->{ Sale_Price }          ");
            $tm->update_log("          ShippingAmount   $s->{ Selected_Ship_Cost }  ");
            $tm->update_log("          WasPayNow        $s->{ PayNow }              ");
            $tm->update_log("          CloseDate        $s->{ Sold_Date }           ");
            $tm->update_log("          CloseTime        $s->{ Sold_Time }           ");
            $tm->update_log("  Current StockOnHand      $a->{ StockOnHand }         ");

            $tm->update_auction_record(
                  AuctionKey                =>   $auctionkey                            ,
                  AuctionStatus             =>   "SOLD"                                 ,
                  AuctionSold               =>   1                                      ,
                  SuccessFee                =>   $s->{ Success_Fee }                    ,
                  PromotionFee              =>   $s->{ Promotion_Fee }                  ,
                  ListingFee                =>   $s->{ Listing_Fee }                    ,
                  CurrentBid                =>   $s->{ Sale_Price }                     ,
                  SaleType                  =>   $s->{ Sale_Type }                      ,
                  WasPayNow                 =>   $s->{ PayNow }                         ,
                  ShippingAmount            =>   $s->{ Selected_Ship_Cost }             ,
                  StockOnHand               =>   $a->{ StockOnHand }                    ,
                  DateLoaded                =>   $s->{ Start_Date    }                  ,
                ( $s->{ Sold_Date }  )      ?  ( CloseDate  => $s->{ Sold_Date } ) : () ,
                ( $s->{ Sold_Time }  )      ?  ( CloseTime  => $s->{ Sold_Time } ) : () ,
            );

            # IF stock on hand greater than 0, then decrement it; If The auction record 
            # has a product code set stock on hand to the new value for all product codes

            if ( $a->{ StockOnHand } > 0 )   { 
                $a->{ StockOnHand }--;

                $tm->update_log(" Adjusted StockOnHand      $a->{ StockOnHand }         ");

                $tm->update_auction_record(
                      AuctionKey                =>   $auctionkey                            ,
                      StockOnHand               =>   $a->{ StockOnHand }                    ,
                );

                if ( $a->{ ProductCode } ne '' ) {
                    $tm->update_log("Set StockOnHand value for Product Code $a->{ ProductCode }");
                    $tm->update_stock_on_hand(
                        ProductCode =>  $a->{ ProductCode } ,
                        StockOnHand =>  $a->{ StockOnHand } ,
                    );
                }
            }

        }

        # LEGACY support - Handle auctions previously flagged as sold but WITHOUT a Sale type
        # If the auction is SOLD but not Saletype exists, then the sale type was not updated
        # Add the saletype, fees etc to the existing record but DO NOT update stock as this
        # will already have been done when the records was marked as SOLD

        elsif ( $a->{ AuctionSold } == 1 and $a->{ SaleType } eq '' ) {

            $tm->update_log("UPDATE EXISTING Sold record with Sale Details          ");
            $tm->update_log("Updating  AuctionKey       $auctionkey                 ");
            $tm->update_log("          SaleType         $s->{ Sale_Type }           ");
            $tm->update_log("          SuccessFee       $s->{ Success_Fee }         ");
            $tm->update_log("          PromotionFee     $s->{ Promotion_Fee }       ");
            $tm->update_log("          ListingFee       $s->{ Listing_Fee }         ");
            $tm->update_log("          CurrentBid       $s->{ Sale_Price }          ");
            $tm->update_log("          ShippingAmount   $s->{ Selected_Ship_Cost }  ");
            $tm->update_log("          WasPayNow        $s->{ PayNow }              ");
            $tm->update_log("          CloseDate        $s->{ Sold_Date }           ");
            $tm->update_log("          CloseTime        $s->{ Sold_Time }           ");
            $tm->update_log("  Current StockOnHand      $a->{ StockOnHand }         ");

            $tm->update_auction_record(
                  AuctionKey                =>   $auctionkey                            ,
                  SuccessFee                =>   $s->{ Success_Fee }                    ,
                  PromotionFee              =>   $s->{ Promotion_Fee }                  ,
                  ListingFee                =>   $s->{ Listing_Fee }                    ,
                  CurrentBid                =>   $s->{ Sale_Price }                     ,
                  SaleType                  =>   $s->{ Sale_Type }                      ,
                  WasPayNow                 =>   $s->{ PayNow }                         ,
                  ShippingAmount            =>   $s->{ Selected_Ship_Cost }             ,
                  StockOnHand               =>   $a->{ StockOnHand }                    ,
                  DateLoaded                =>   $s->{ Start_Date    }                  ,
                ( $s->{ Sold_Date }  )      ?  ( CloseDate  => $s->{ Sold_Date } ) : () ,
                ( $s->{ Sold_Time }  )      ?  ( CloseTime  => $s->{ Sold_Time } ) : () ,
            );
        }

        # If the auction record has a different sales type than the sales record it is a new sale so 
        # add a NEW auction record with the NEW sales details and reduce stock onhand value for product code

        elsif ( $a->{ SaleType } ne $s->{ Sale_Type } ) {

            # Add new record by copying existing auction record

            $tm->update_log("ADD NEW Auction Record for NEW sales transaction      ");

            my $newkey = $tm->copy_auction_record(
                  AuctionKey                =>   $auctionkey                            ,
                  AuctionStatus             =>   "SOLD"                                 ,
                  AuctionSold               =>   1                                      ,
                  SuccessFee                =>   $s->{ Success_Fee }                    ,
                  PromotionFee              =>   $s->{ Promotion_Fee }                  ,
                  ListingFee                =>   $s->{ Listing_Fee }                    ,
                  CurrentBid                =>   $s->{ Sale_Price }                     ,
                  SaleType                  =>   $s->{ Sale_Type }                      ,
                  WasPayNow                 =>   $s->{ PayNow }                         ,
                  ShippingAmount            =>   $s->{ Selected_Ship_Cost }             ,
                  StockOnHand               =>   $a->{ StockOnHand }                    ,
                  DateLoaded                =>   $s->{ Start_Date    }                  ,
                ( $s->{ Sold_Date }  )      ?  ( CloseDate  => $s->{ Sold_Date } ) : () ,
                ( $s->{ Sold_Time }  )      ?  ( CloseTime  => $s->{ Sold_Time } ) : () ,
            );

            $tm->update_log("Adding    AuctionKey       $newkey                     ");
            $tm->update_log("          SaleType         $s->{ Sale_Type }           ");
            $tm->update_log("          AuctionStatus    SOLD                        ");
            $tm->update_log("          AuctionSold      1                           ");
            $tm->update_log("          SuccessFee       $s->{ Success_Fee }         ");
            $tm->update_log("          PromotionFee     $s->{ Promotion_Fee }       ");
            $tm->update_log("          ListingFee       $s->{ Listing_Fee }         ");
            $tm->update_log("          CurrentBid       $s->{ Sale_Price }          ");
            $tm->update_log("          ShippingAmount   $s->{ Selected_Ship_Cost }  ");
            $tm->update_log("          WasPayNow        $s->{ PayNow }              ");
            $tm->update_log("          CloseDate        $s->{ Sold_Date }           ");
            $tm->update_log("          CloseTime        $s->{ Sold_Time }           ");
            $tm->update_log("  Current StockOnHand      $a->{ StockOnHand }         ");

            # IF stock on hand greater than 0, then decrement it; If The auction record 
            # has a product code set stock on hand to the new value for all product codes

            if ( $a->{ StockOnHand } > 0 )   { 
                $a->{ StockOnHand }--;

                $tm->update_log("  Updated StockOnHand      $a->{ StockOnHand }         ");

                if ( $a->{ ProductCode } ne '' ) {
                    $tm->update_stock_on_hand(
                        ProductCode =>  $a->{ ProductCode } ,
                        StockOnHand =>  $a->{ StockOnHand } ,
                    );
                }
            }

        }
           
        $counter++;
    
        if ( $pb->{ Cancelled } ) {
            $tm->{ DBH }->commit();
            $tm->{ DBH }->{ AutoCommit  } = $oldcommitval;
            CancelHandler();
            return $estruct;
        }

    }

    # Commit the changes to the database & Restore the Autocommit property to 

    $tm->{ DBH }->commit();
    $tm->{ DBH }->{ AutoCommit  } = $oldcommitval;

    UpdateErrorStatus();   
    return $estruct;
}

#=============================================================================================
# UpdateUnsoldAuctions - Perform specific updates on auctions during UpdateDB processing
#=============================================================================================

sub UpdateUnsoldAuctions {

    my $unsdata = shift;
    my $status = shift;

    $tm->update_log("Invoked Method: ". (caller(0))[3]); 

    $pb->{SetProgressTotal} = scalar(@$unsdata);
    $pb->UpdateMultiBar();

    my $counter = 1;

    # Save the old autocommit value and then explicitly set autocommit off.

    my $oldcommitval = $tm->{ DBH }->{ AutoCommit  };
    $tm->{ DBH }->{ AutoCommit  } = 0;

    # Update current auction data from list of auctions

    foreach my $unsold (@$unsdata) {


        $pb->{SetProgressCurrent} = $counter;
        $pb->UpdateMultiBar();

        if ( $tm->is_DBauction_104($unsold->{ AuctionRef } ) ) {

            my $auctionkey = $tm->get_auction_key( $unsold->{ AuctionRef } );

            my $DBrecord = $tm->get_auction_record( $auctionkey );
            
            if ( $DBrecord->{ AuctionStatus } ne "RELISTED" ) {

                $pb->{SetCurrentOperation} = "Updating auction ".$unsold->{ AuctionRef }.": ".$DBrecord->{ Title };
            
                $tm->update_log("Updating auction ".$unsold->{ AuctionRef }." [$status]: ".$DBrecord->{ Title });

                $tm->update_auction_record(
                      AuctionKey                  =>   $auctionkey                                                       ,
                      AuctionStatus               =>   "UNSOLD"                                                          ,
                      AuctionSold                 =>   0                                                                 ,
                    ( $unsold->{ CloseDate }   )  ?  ( CloseDate     => $unsold->{ CloseDate } ) : ()                    ,
                    ( $unsold->{ CloseTime }   )  ?  ( CloseTime     => $unsold->{ CloseTime } ) : ()                    );
            }
               
        } 
        else {
            $pb->{SetCurrentOperation} = "Auction ".$unsold->{ AuctionRef } . " not updated - record not found in database";
        }

        $counter++;

        if      ( $pb->{ Cancelled } ) {
                $tm->{ DBH }->commit();
                $tm->{ DBH }->{ AutoCommit  } = $oldcommitval;
                CancelHandler();
                return $estruct;
        }

    }

    # Commit the changes to the database & Restore the Autocommit property to 

    $tm->{ DBH }->commit();
    $tm->{ DBH }->{ AutoCommit  } = $oldcommitval;

    UpdateErrorStatus();   
    return $estruct;
}

#=============================================================================================
# UpdateCurrentAuctions - Update auctions with status of CURRENT
#=============================================================================================

sub UpdateCurrentAuctions {

    my $currdata = shift;
    my $status = shift;

    $tm->update_log("Invoked Method: ". (caller(0))[3]); 

    $pb->{SetProgressTotal} = scalar(@$currdata);
    $pb->UpdateMultiBar();

    my $counter = 1;

    # Update current auction data from list of auctions

    # Save the old autocommit value and then explicitly set autocommit off.

    my $oldcommitval = $tm->{ DBH }->{ AutoCommit  };
    $tm->{ DBH }->{ AutoCommit  } = 0;

    foreach my $item ( @$currdata ) {

        $pb->{ SetProgressCurrent } = $counter;
        $pb->UpdateMultiBar();

        if     ($tm->is_DBauction_104($item->{ AuctionRef } )) {

                my $auctionkey = $tm->get_auction_key( $item->{ AuctionRef } );

                my $DBrecord = $tm->get_auction_record( $auctionkey );
                
                if ( $DBrecord->{ AuctionStatus } ne "RELISTED" ) {

                    $pb->{ SetCurrentOperation } = "Updating auction ".$item->{ AuctionRef }.": ".$DBrecord->{ Title };
                
                    $tm->update_log("Updating auction ".$item->{ AuctionRef }." [$status]: ".$DBrecord->{ Title });

                    $tm->update_auction_record(
                          AuctionKey                  =>   $auctionkey                                                       ,
                          AuctionStatus               =>   "CURRENT"                                                         ,
                          OfferProcessed              =>   0                                                                 ,
                          PromotionFee                =>   $item->{ Promotion_Fee   }                                        ,
                          ListingFee                  =>   $item->{ Listing_Fee     }                                        ,
                          CurrentBid                  =>   $item->{ Max_Bid_Amount  }                                        ,
                          DateLoaded                  =>   $item->{ Start_Date      }                                        ,
                        ( $item->{ End_Date }   )     ?  ( CloseDate     => $item->{ End_Date } ) : ()                       ,
                        ( $item->{ End_Time }   )     ?  ( CloseTime     => $item->{ End_Time } ) : ()                      );
               }
               
        } else {
                $pb->{SetCurrentOperation} = "Auction ".$item->{ AuctionRef }. " not updated - record not found in database";
        }

        $counter++;

        if      ( $pb->{ Cancelled } ) {
                $tm->{ DBH }->commit();
                $tm->{ DBH }->{ AutoCommit  } = $oldcommitval;
                CancelHandler();
                return $estruct;
        }

    }

    # Commit the changes to the database & Restore the Autocommit property to 

    $tm->{ DBH }->commit();
    $tm->{ DBH }->{ AutoCommit  } = $oldcommitval;

    UpdateErrorStatus();   
    return $estruct;
}

#=============================================================================================
# UpdateClosedAuctions - Update auctions with status of CLOSED
#=============================================================================================

sub UpdateClosedAuctions {

    my $closdata = shift;

    $tm->update_log("Invoked Method: ". (caller(0))[3]); 

    $pb->{SetProgressTotal} = scalar(@$closdata);
    $pb->UpdateMultiBar();

    my $counter = 1;
    my $auctionkey;

    # Save the old autocommit value and then explicitly set autocommit off.

    my $oldcommitval = $tm->{ DBH }->{ AutoCommit  };
    $tm->{ DBH }->{ AutoCommit  } = 0;   

    # Update current auction data from list of auctions

    foreach my $comp (@$closdata) {

        $pb->{ SetProgressCurrent   }   =   $counter;
        $pb->{ SetCurrentOperation  }   =   "Marking auction ".$comp->{ AuctionRef }. " Closed";
        $pb->UpdateMultiBar();

        $tm->set_auction_closed( AuctionKey     =>  $comp->{ AuctionKey } );
        
        $counter++;

        if      ( $pb->{ Cancelled } ) {
                $tm->{ DBH }->commit();
                $tm->{ DBH }->{ AutoCommit  } = $oldcommitval;
                CancelHandler();
                return $estruct;
        }
    }

    # Commit the changes to the database & Restore the Autocommit property to 

    $tm->{ DBH }->commit();
    $tm->{ DBH }->{ AutoCommit  } = $oldcommitval;

    UpdateErrorStatus();   
    return $estruct;
}

#=============================================================================================
# IdentifyCLosedAuctions
#=============================================================================================

sub IdentifyClosedAuctions {

    my $current     = shift;
    my $sold        = shift;
    my $unsold      = shift;
    
    my %TMAuctions;
    my @closed;

    # load up a hash with all auctions currently  on TradeMe

    foreach my $c ( @$current ) {
        $TMAuctions{ $c->{ AuctionRef } } = 1;
    }

    foreach my $s ( @$sold ) {
        $TMAuctions{ $s->{ AuctionRef } } = 1;
    }

    foreach my $u ( @$unsold ) {
        $TMAuctions{ $u->{ AuctionRef } } = 1;
    }
    
    my $loaded = $tm->get_uploaded_auctions();

    foreach my $l ( @$loaded ) {

        if (not defined $TMAuctions{ $l->{ AuctionRef } } ) {
            push (@closed, $l );
        }
    }
    
    return \@closed;
}

#=============================================================================================
# DeleteTradeMePictures - Delete all TradeMe pictures
#=============================================================================================

sub DeleteTradeMePictures {

    $tm = Auctionitis->new();
    $tm->initialise(Product => "Auctionitis");  # Initialise the product

    $tm->{ Debug } ge "1" ? ( $tm->dump_properties() ) : () ;

    $tm->update_log("Invoked Method: ". (caller(0))[3]); 

    $pb = Win32::OLE->new('MultiPB.clsMultiPB') or die;

    $tm->update_log("Started: DeleteTradeMePictures");

    ### insert some text into the window header

    $pb->InitialiseMultiBar();
    $pb->{ AlwaysMinimize       }   =   $tm->{ AlwaysMinimize };
    $pb->{ SetWindowTitle       }   =   "Auctionitis: Delete TradeMe Pictures";
    
    $pb->AddTask("Delete all TradeMe Picture Files");
    
    $pb->{ SetCurrentTask       }   =   1;
    $pb->{ SetCurrentOperation  }   =   "Retrieving Picture Data from TradeMe";
    $pb->{ SetTaskAction        }   =   "";
    
    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    $tm->update_log("Logging in to TradeMe");
    $tm->login();
    
    # if login was not OK update error structure and return

    if ( $tm->{ ErrorStatus } ) {
        $tm->set_always_minimize( $pb->AlwaysMinimize() );
        $pb->QuitMultiBar();
        UpdateErrorStatus();   
        return $estruct;
    }

    my $pictures = $tm->get_tm_unused_photos(\&UpdateStatusBar);
   
    if (defined @$pictures ) {

          my $counter = 1;

          $pb->{SetTaskAction   } =   "Deleting Picture:";
          $pb->{SetProgressTotal} = scalar(@$pictures);
          $pb->UpdateMultiBar();

          foreach my $photo (@$pictures) {

                $pb->{ SetProgressCurrent   }   =   $counter;
                $pb->{ SetCurrentOperation  }   =   "Removing picture from Trademe";
                $pb->UpdateMultiBar();

                $tm->delete_tm_photo($photo);

                sleep 1;
                $counter++;

                if  ( $pb->{ Cancelled } ) {
                      CancelHandler();
                      return $estruct;
                }
          }
    }

    $pb->MarkTaskCompleted(1);
    $pb->UpdateMultiBar();

    $tm->update_log("Completed: DeleteTradeMePictures");

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
        return $estruct;
    }

    sleep 2;
    $tm->set_always_minimize( $pb->AlwaysMinimize() );
    $pb->QuitMultiBar();

    UpdateErrorStatus();   
    return $estruct;
}

#=============================================================================================
# DeleteUnusedPictures - Select and delete pictures no longer referred to in auctions rcds
#=============================================================================================

sub DeleteUnusedPictures {

    $tm = Auctionitis->new();
    $tm->initialise(Product => "Auctionitis");  # Initialise the product

    $tm->update_log("Invoked Method: ". (caller(0))[3]); 

    my $pb = Win32::OLE->new('MultiPB.clsMultiPB') or die;

    $pb->InitialiseMultiBar();
    $pb->{ AlwaysMinimize       }   =   $tm->{ AlwaysMinimize };
    $pb->{ SetWindowTitle       }   =   "Delete Unused Pictures";

    $pb->AddTask("Removing unused pictures from Picture table");

    $pb->{ SetProgressTotal     }   =   0;
    $pb->{ SetProgressCurrent   }   =   0;
    $pb->{ SetCurrentTask       }   =   1;
    $pb->{ SetCurrentOperation  }   =   "Retrieving list of pictures currently in use";

    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    $tm->update_log("Connecting to Database");
    $tm->DBconnect();                           # Connect to the default database

    my %picturekeys = $tm->get_used_picture_keys();

    $pb->{ SetCurrentOperation  }   =   "Retrieving list of pictures in picture table";

    my $currentpictures             =   $tm->get_all_pictures(); 
    my $counter                     =   0;
    
    $pb->{ SetTaskAction        }   =   "Deleting:"; 
    $pb->{ SetProgressTotal     }   =   scalar(@$currentpictures);

    foreach my $picture ( @$currentpictures ) {

        if (not defined $picturekeys{ $picture->{ PictureKey } } ) {
            $pb->{ SetCurrentOperation } = "File $picture->{ PictureFileName }";
            $tm->delete_picture_record( $picture->{ PictureKey } );
        }
        $pb->{ SetProgressCurrent } = $counter;
        $counter++;

        if      ( $pb->{ Cancelled } ) {
                CancelHandler();
                return $estruct;
        }
    }

    $pb->MarkTaskCompleted(1);

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # All Tasks completed
    #-----------------------------------------------------------------------------------------

    $tm->DBdisconnect();                          # disconnect from the database
    
    sleep 2;
    $tm->set_always_minimize( $pb->AlwaysMinimize() );
    $pb->QuitMultiBar();

    UpdateErrorStatus();   
    return $estruct;
}

#=============================================================================================
# CheckServiceDates - Check the Category Service date  on the Auctionitis website
#=============================================================================================

sub CheckServiceDates {

    $tm = Auctionitis->new();
    $tm->initialise(Product => "Auctionitis");  # Initialise the product

    $tm->update_log("Invoked Method: ". (caller(0))[3]); 

    $tm->{ Debug } ge "1" ? ( $tm->dump_properties() ) : () ;

    $tm->update_log("Connecting to Database");
    $tm->DBconnect();                           # Connect to the default database

    $tm->get_remote_service_date();
    $tm->get_remote_current_version();

    # Place the error indicators in an anonymous hash to return all properties

    my $ServiceData = { "RemoteServiceDate"        => $tm->{ RemoteServiceDate      }   ,
                        "RemoteCurrentVersion"     => $tm->{ RemoteCurrentVersion   }   ,
    };

    $tm->DBdisconnect();                          # disconnect from the database

    if ( $tm->{ ErrorStatus } ) {
        UpdateErrorStatus();   
        return $estruct;
    }
    
    else {

        my $ReturnData = { 
            "ErrorStatus"           =>  "0"                                     ,
            "ErrorCode"             =>  "0"                                     ,
            "ErrorMessage"          =>  "No Errors encountered"                 ,
            "ErrorDetail"           =>  ""                                      ,
            "RemoteServiceDate"     =>  $ServiceData->{ "RemoteServiceDate" }   ,
            "RemoteCurrentVersion"  =>  $ServiceData->{ "RemoteCurrentVersion" },
        };
        
        return $ReturnData ;
    }
}

#=============================================================================================
# CheckChecksumData - Verify that the category table is valid using simple checksum routine
#=============================================================================================

sub CheckChecksumData {

    $tm = Auctionitis->new();
    $tm->initialise(Product => "Auctionitis");  # Initialise the product

    $tm->update_log("Invoked Method: ". (caller(0))[3]); 

    $tm->update_log("Connecting to Database");
    $tm->DBconnect();                           # Connect to the default database

    $tm->get_remote_checksum();
    $tm->get_local_checksum();

    # Place the error indicators in an anonymous hash to return all properties

    my $ChecksumData = { "RemoteChecksum"          => $tm->{ RemoteChecksum         }   ,
                         "LocalChecksum"           => $tm->{ LocalChecksum          }   ,
    };
                         
    $tm->DBdisconnect();                          # disconnect from the database

    if ( $tm->{ ErrorStatus } ) {
        UpdateErrorStatus();   
        return $estruct;
    }
    
    else {

        my $ReturnData = { 
            "ErrorStatus"           =>  "0"                                     ,
            "ErrorCode"             =>  "0"                                     ,
            "ErrorMessage"          =>  "No Errors encountered"                 ,
            "ErrorDetail"           =>  ""                                      ,
            "RemoteChecksum"        =>  $ChecksumData->{ "RemoteChecksum" }     ,
            "LocalChecksum"         =>  $ChecksumData->{ "LocalChecksum" }      ,
        };
        
        return $ReturnData ;
    }

}

#=============================================================================================
# UpdateCategoryData - Update Category table with new records
#=============================================================================================

sub UpdateCategoryData {

    my $localservicedate = shift;
    my @auctions;

    $tm = Auctionitis->new();
    $tm->initialise(Product => "Auctionitis");  # Initialise the product

    $tm->update_log("Invoked Method: ". (caller(0))[3]); 

    $tm->{ Debug } ge "1" ? ( $tm->dump_properties() ) : () ;

    $pb = Win32::OLE->new('MultiPB.clsMultiPB') or die;

    ### insert some text into the window header

    $pb->InitialiseMultiBar();
    $pb->{ AlwaysMinimize       }   =   $tm->{ AlwaysMinimize };
    $pb->{ SetWindowTitle       }   =   "Auctionitis: Update Category Data";
    
    $pb->AddTask("Load Master Category Table");
    $pb->AddTask("Get Category Service Dates");
    $pb->AddTask("Process Category Service Data");
    $pb->AddTask("Retrieving Category ReadMe document");

    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    $tm->update_log("Connecting to Database");
    $tm->DBconnect();                           # Connect to the default database

    #-----------------------------------------------------------------------------------------
    # Task 1 - Reload the category table
    #-----------------------------------------------------------------------------------------

    $pb->{ SetCurrentTask       }   =   1;
    $pb->{ SetCurrentOperation  }   =   "Clearing existing Category records";
    
    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    $tm->clear_category_table();

    $pb->{ SetCurrentOperation  }   =   "Downloading Current Category Data";
    
    $pb->UpdateMultiBar();
    
    my $categories                  =   $tm->get_remote_category_table();
    my $counter                     =   1;

    $pb->{ SetCurrentOperation  }   =   "Writing New Category records";
    $pb->{ SetProgressTotal     }   =   @$categories;
    $pb->{ SetTaskAction        }   =   "Adding Category record:";

    $pb->UpdateMultiBar();

    # Save the old autocommit value and then explicitly set autocommit off.

    my $oldcommitval = $tm->{ DBH }->{ AutoCommit  };
    $tm->{ DBH }->{ AutoCommit  } = 0;

    foreach my $record (@$categories) {

        $pb->{ SetCurrentOperation  } = "Adding Category $record->{ Description     }";
        $pb->{ SetProgressCurrent   } = $counter;
        $pb->UpdateMultiBar();

        $tm->update_log("Adding Category:\t".$record->{ Category }."\t(".$record->{Description}.")");

        $tm->insert_category_record( Description     => $record->{ Description     },
                                     Category        => $record->{ Category        },
                                     Parent          => $record->{ Parent          },
                                     Sequence        => $record->{ Sequence        },
        );
        
        $counter++;
        
    }

    # COmmit the changes to the database & Restore the Autocommit property to 

    $tm->{ DBH }->commit();
    $tm->{ DBH }->{ AutoCommit  } = $oldcommitval;

    $pb->MarkTaskCompleted(1);
    $pb->UpdateMultiBar();

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
        return $estruct;
    }
    
    #-----------------------------------------------------------------------------------------
    # Task 2 - Get Service dates
    #-----------------------------------------------------------------------------------------

    $pb->{ SetCurrentTask       }   = 2;
    $pb->{ SetCurrentOperation  }   = "Retrieving Category Service Information";
    $pb->{ SetTaskAction        }   = "Getting Category Service Data update details";
    $pb->{ SetProgressTotal     }   = 1;
    $pb->{ SetProgressCurrent   }   = 0;
    
    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    $tm->update_log("Checking for Category Service Updates; Local Service Date: ".$localservicedate);

    my $servicedates            = $tm->get_service_dates($localservicedate);

    if ( $tm->{ ErrorStatus } ) {
        UpdateErrorStatus();   
        return $estruct;
    }

    $pb->{SetProgressCurrent}   = 1;
    $pb->UpdateMultiBar();

    $pb->MarkTaskCompleted(2);
    $pb->UpdateMultiBar();

    #-----------------------------------------------------------------------------------------
    # Task 3 - Process Service updates
    #-----------------------------------------------------------------------------------------

    $pb->{ SetCurrentTask       }   =   3;
    $pb->{ SetCurrentOperation  }   =   "Processing Category Service Updates";
    
    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    foreach my $record (@$servicedates) {

        $pb->{ SetTaskAction        }   =   "Processing Service Update (".$record->{ ServiceDate }."):";
        $pb->UpdateMultiBar();
 
        $tm->update_log("Processing Service Update data for : ".$record->{ ServiceDate });
        $tm->update_log("Retrieving Service Update data from: ".$record->{ ServiceURL });

        my $mapdata                     =   $tm->get_remapping_data( $record->{ ServiceURL } );

        if ( $tm->{ ErrorStatus } ) {
            UpdateErrorStatus();   
            return $estruct;
        }

        $pb->{ SetProgressTotal     }   =   @$mapdata;
        $pb->{ SetProgressCurrent   }   =   0;
        
        my $counter = 1;

        foreach my $update (@$mapdata) {

            $pb->{SetCurrentOperation}  =   "Converting Category $update->{ Description     }";
            $pb->{SetProgressCurrent}   =   $counter;
            $pb->UpdateMultiBar();

            $tm->update_log("Converting: ".$update->{ OldCategory }."->".$update->{ NewCategory }."\t(".$update->{ Description }.")");

            $tm->convert_category( $update->{ OldCategory }, $update->{ NewCategory });

            $counter++;

            if      ( $pb->{ Cancelled } ) {
                    CancelHandler();
                    return $estruct;
            }
        }
    }
    
    $pb->MarkTaskCompleted(3);
    $pb->UpdateMultiBar();

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # Task 4 - Get Category Readme document
    #-----------------------------------------------------------------------------------------

    $pb->{ SetCurrentTask       }   =   4;
    $pb->{ SetCurrentOperation  }   =   "Retrieving Category ReadMe document";
    $pb->{ SetTaskAction        }   =   "Downloading";
    $pb->{ SetProgressTotal     }   = 1;
    $pb->{ SetProgressCurrent   }   = 0;
    
    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();
    
    my $FH;
    my $readmefile = $tm->{ DataDirectory }."\\readme.txt";
    my $readmedata = $tm->get_category_readme();

    if ( $tm->{ ErrorStatus } ) {
        UpdateErrorStatus();   
        return $estruct;
    }
    
    print $readmedata;
    
    unlink $readmefile;
    
    open($FH, "> $readmefile");
    
    print $FH $readmedata;

    $pb->{ SetProgressCurrent   }   = 1;

    $pb->MarkTaskCompleted(4);
    $pb->UpdateMultiBar();

    #-----------------------------------------------------------------------------------------
    # All Tasks completed
    #-----------------------------------------------------------------------------------------

    $tm->DBdisconnect();                          # disconnect from the database
    
    sleep 2;
    $tm->set_always_minimize( $pb->AlwaysMinimize() );
    $pb->QuitMultiBar();

    UpdateErrorStatus();   
    return $estruct;
}

#=============================================================================================
# UpdateCategorySilent - Update Category table with new records in SILENT mode
#=============================================================================================

sub UpdateCategorySilent {

    my $localservicedate = shift;
    my @auctions;

    $tm = Auctionitis->new();
    $tm->initialise(Product => "Auctionitis");  # Initialise the product

    $tm->update_log("Invoked Method: ". (caller(0))[3]); 

    $tm->{ Debug } ge "1" ? ( $tm->dump_properties() ) : () ;

    $tm->update_log("Connecting to Database");
    $tm->DBconnect();                           # Connect to the default database

    #-----------------------------------------------------------------------------------------
    # Task 1 - Reload the category table
    #-----------------------------------------------------------------------------------------

    $tm->clear_category_table();
    
    my $categories                  =   $tm->get_remote_category_table();

    foreach my $record (@$categories) {

        $tm->update_log("Adding Category:\t".$record->{ Category }."\t(".$record->{Description}.")");

        $tm->insert_category_record( Description     => $record->{ Description     },
                                     Category        => $record->{ Category        },
                                     Parent          => $record->{ Parent          },
                                     Sequence        => $record->{ Sequence        },
        );
    }
    
    #-----------------------------------------------------------------------------------------
    # Task 2 - Get Service dates
    #-----------------------------------------------------------------------------------------

    $tm->update_log("Checking for Category Service Updates; Local Service Date: ".$localservicedate);

    my $servicedates            = $tm->get_service_dates($localservicedate);

    if ( $tm->{ ErrorStatus } ) {
        UpdateErrorStatus();   
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # Task 3 - Process Service updates
    #-----------------------------------------------------------------------------------------

    foreach my $record (@$servicedates) {
 
        $tm->update_log("Processing Service Update data for : ".$record->{ ServiceDate });
        $tm->update_log("Retrieving Service Update data from: ".$record->{ ServiceURL });

        my $mapdata                     =   $tm->get_remapping_data( $record->{ ServiceURL } );

        if ( $tm->{ ErrorStatus } ) {
            UpdateErrorStatus();   
            return $estruct;
        }

        foreach my $update (@$mapdata) {
            $tm->update_log("Converting: ".$update->{ OldCategory }."->".$update->{ NewCategory }."\t(".$update->{ Description }.")");
            $tm->convert_category( $update->{ OldCategory }, $update->{ NewCategory });
        }
    }

    #-----------------------------------------------------------------------------------------
    # Task 4 - Get Category Readme document
    #-----------------------------------------------------------------------------------------
    
    my $FH;
    my $readmefile = $tm->{ DataDirectory }."\\readme.txt";
    my $readmedata = $tm->get_category_readme();

    if ( $tm->{ ErrorStatus } ) {
        UpdateErrorStatus();   
        return $estruct;
    }
    
    print $readmedata;
    
    unlink $readmefile;
    
    open($FH, "> $readmefile");
    
    print $FH $readmedata;

    #-----------------------------------------------------------------------------------------
    # All Tasks completed
    #-----------------------------------------------------------------------------------------

    $tm->DBdisconnect();                          # disconnect from the database

    UpdateErrorStatus();   
    return $estruct;
}


##############################################################################################
# ---  Sella Website interfaces ---
##############################################################################################

#=============================================================================================
# LoadAll - Load all Pending Auctions
#=============================================================================================

sub LoadAllSellaAuctions {

    $tm = Auctionitis->new();
    $tm->initialise( Product => "Auctionitis" );  # Initialise the product

    $tm->update_log("Invoked Method: ". ( caller(0))[3] ); 

    $tm->{ Debug } ge "1" ? ( $tm->dump_properties() ) : () ;

    $pb = Win32::OLE->new('MultiPB.clsMultiPB') or die;

    ### insert some text into the window header

    $pb->InitialiseMultiBar();
    $pb->{ AlwaysMinimize       }   =   $tm->{ AlwaysMinimize };
    $pb->{ SetWindowTitle       }   =   "Auctionitis: Load All Sella Auctions";
    
    # Tasks to be performed in this operation
    
    $pb->AddTask("Clone Auctions for upload");
    $pb->AddTask("Upload new picture files");
    $pb->AddTask("Load all Pending auctions");

    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    # Initialise the TradeMe object
    
    $tm->update_log("Connecting to Database");
    $tm->DBconnect();                          # Connect to the database

    # removed 12/22009 to test sessionidrequirements

    $tm->update_log("Connecting to Sella");
    $tm->connect_to_sella();

    # if login was not OK update error structure and return

    if ( $tm->{ ErrorStatus } ) {
        $tm->set_always_minimize( $pb->AlwaysMinimize() );
        $pb->QuitMultiBar();
        UpdateErrorStatus();   
        return $estruct;
    }    

    #-----------------------------------------------------------------------------------------
    # Task 1 - Clone auctions
    #-----------------------------------------------------------------------------------------
    
    $tm->update_log( "Started: Clone Auctions for upload" );

    $pb->{ SetCurrentTask       }   =   1;
    $pb->{ SetCurrentOperation  }   =   "Cloning Auctions";
    $pb->{ SetTaskAction        }   =   "Cloning Auctions from database for upload:";

    my $clones                      =   $tm->get_clone_auctions( AuctionSite => "SELLA" );
    my $counter                     =   0;
    my $clone_total                 =   0;
    
    $pb->{ SetProgressTotal     }   =   scalar( @$clones );
    $pb->{ SetProgressCurrent   }   =   $counter;    
    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    foreach my $clone ( @$clones ) {
    
        $pb->{SetProgressCurrent} = $counter;    
        $pb->UpdateMultiBar();
        $pb->ShowMultiBar();

        my $newkey = $tm->copy_auction_record(
            AuctionKey       =>  $clone->{ AuctionKey } ,
            AuctionStatus    =>  "PENDING"              ,
        );

        push ( @clonekeys, $newkey );    # Store the key of the new clone record

        $tm->update_log("Cloned Auction $clone->{AuctionTitle} (Record $clone->{AuctionTitle})");

        $counter++;

        if ( $pb->{ Cancelled } ) {
            CancelHandler();
            return $estruct;
        }
    }

    $pb->MarkTaskCompleted(1);
    $pb->UpdateMultiBar();
    sleep 2;
    
    $tm->update_log( "Completed: Clone Auctions for upload" );

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ( $abend ) {
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # Task 2 - Process new photograhs
    #-----------------------------------------------------------------------------------------

    $tm->update_log( "Started: Upload new picture files" );

    $pb->{ SetCurrentTask       }   =   2;
    $pb->{ SetCurrentOperation  }   =   "Loading New pictures to Sella";
    $pb->{ SetTaskAction        }   =   "Uploading file:";
    $pb->UpdateMultiBar();

    my $pictures =  $tm->get_unloaded_pictures( AuctionSite => "SELLA" );

    $pb->{ SetProgressTotal     }   =   scalar( @$pictures );
    $pb->UpdateMultiBar();

    if ( scalar( @$pictures ) > 0 ) {
        SellaImageUpload( $pictures );
    }
    
    $pb->MarkTaskCompleted(2);
    $pb->UpdateMultiBar();

    $tm->update_log( "Completed: Load New Pictures" );

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ( $abend ) {
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # Task 3 - Load All Pending Autions
    #-----------------------------------------------------------------------------------------

    $tm->update_log( "Started: Load all Pending auctions" );

    $pb->{ SetCurrentTask       }   =   3;
    $pb->{ SetTaskAction        }   =   "Loading auctions to Sella:";
    $pb->{ SetCurrentOperation  }   =   "Retrieving Auctions requiring upload";
    $pb->UpdateMultiBar();

    my $auctions = $tm->get_pending_auctions(
        AuctionSite =>  "SELLA"   ,
    );

    $pb->{ SetProgressTotal } =  scalar( @$auctions);
    $pb->UpdateMultiBar();

    if ( scalar( @$auctions ) > 0 ) {
        SellaAuctionUpload( $auctions );
    }

    $pb->MarkTaskCompleted(3);
    $pb->UpdateMultiBar();

    # Housekeeping for any clones that have been created but not loaded

    if ( scalar( @clonekeys) > 0 ) {

        foreach my $clonekey ( @clonekeys ) {

            $pb->{ SetCurrentOperation  }   =   "Performing clean up operations";
            $pb->UpdateMultiBar();
            $pb->ShowMultiBar();

            my $clonedata = $tm->get_auction_record( $clonekey );
            
            if ( $clonedata->{ AuctionStatus } = "PENDING" ) {
                $tm->delete_auction_record( $clonekey );
                $tm->update_log("Deleted Cloned Auction $clonedata->{ AuctionTitle } (Record $clonekey) - Auction did not load");
            }
        }
    }

    $tm->update_log("Completed: Load all Pending auctions");

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
        return $estruct;
    }    

    #-----------------------------------------------------------------------------------------
    # All Tasks completed
    #-----------------------------------------------------------------------------------------

    $tm->DBdisconnect();                          # disconnect from the database
    
    sleep 2;
    $tm->set_always_minimize( $pb->AlwaysMinimize() );
    $pb->QuitMultiBar();

    UpdateErrorStatus();   
    return $estruct;
}

#=============================================================================================
# LoadSellaCycle - Load Auctions for the selected Auction Cycle to Sella
#=============================================================================================

sub LoadSellaCycle {

    my $cycle   =   shift;

    $tm = Auctionitis->new();
    $tm->initialise( Product => "Auctionitis" );  # Initialise the product
    
    $tm->update_log("Invoked Method: ". (caller(0))[3]); 

    $tm->{ Debug } ge "1" ? ( $tm->dump_properties() ) : () ;

    $pb = Win32::OLE->new('MultiPB.clsMultiPB') or die;

    ### insert some text into the window header

    $pb->InitialiseMultiBar();
    $pb->{ AlwaysMinimize       } = $tm->{ AlwaysMinimize };
    $pb->{SetWindowTitle        } = "Auctionitis: Load Sella Auction Cycle $cycle";
    $pb->AddTask("Clone Auctions for Auction Cycle ".$cycle);
    $pb->AddTask("Load New Pictures");
    $pb->AddTask("Load Pending auctions for Auction Cycle ".$cycle);

    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    # Instantatiate the TradeMe object

    $tm->update_log( "Connecting to Database" );
    $tm->DBconnect();                          # Connect to the database

    $tm->update_log( "Logging in to Sella" );
    $tm->connect_to_sella();

    # if login was not OK update error structure and return

    if ( $tm->{ ErrorStatus } ) {
        $tm->set_always_minimize( $pb->AlwaysMinimize() );
        $pb->QuitMultiBar();
        UpdateErrorStatus();   
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # Task 1 - Clone auctions
    #-----------------------------------------------------------------------------------------
    
    $tm->update_log("Started: Clone Auctions for Auction Cycle ".$cycle);

    $pb->{ SetCurrentTask       }   =   1;
    $pb->{ SetCurrentOperation  }   =   "Cloning Auctions";
    $pb->{ SetTaskAction        }   =   "Cloning Auctions from database for upload:";

    my $clones                      =  $tm->get_clone_auctions(
        AuctionSite     => "SELLA"    ,
        AuctionCycle    => $cycle       ,
    );

    my $counter                     =   0;
    
    $pb->{ SetProgressTotal     }   =   scalar( @$clones );
    $pb->{ SetProgressCurrent   }   =   $counter;    
    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    foreach my $clone ( @$clones ) {
    
        $pb->{SetProgressCurrent} = $counter;    
        $pb->UpdateMultiBar();
        $pb->ShowMultiBar();

        my $newkey = $tm->copy_auction_record(
            AuctionKey       =>  $clone->{ AuctionKey } ,
            AuctionStatus    =>  "PENDING"              ,
        );

        push ( @clonekeys, $newkey );    # Store the key of the new clone record

        $tm->update_log( "Cloned Auction ".$clone->{ AuctionTitle }." (Record ".$clone->{auctionTitle}.")" );

        $counter++;

        if ( $pb->{ Cancelled } ) {
            CancelHandler();
            return $estruct;
        }
    }

    $pb->MarkTaskCompleted(1);
    $pb->UpdateMultiBar();

    $tm->update_log("Completed: Clone Auctions for Auction Cycle ".$cycle);

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ( $abend ) {
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # Task 2 - Process new photograhs
    #-----------------------------------------------------------------------------------------

    $tm->update_log("Started: Upload new picture files");

    $pb->{ SetCurrentTask       }   =   2;
    $pb->{ SetCurrentOperation  }   =   "Loading New pictures to Sella";
    $pb->{ SetTaskAction        }   =   "Uploading file:";
    $pb->UpdateMultiBar();

    my $pictures =  $tm->get_unloaded_pictures( AuctionSite => "SELLA" );

    if ( scalar( @$pictures ) > 0 ) {

        $pb->{ SetProgressTotal     }   =   scalar( @$pictures );
        $pb->UpdateMultiBar();

        SellaImageUpload( $pictures );
    }

    $pb->MarkTaskCompleted(2);
    $pb->UpdateMultiBar();

    $tm->update_log("Completed: Upload new picture files");

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ( $abend ) {
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # Task 3 - Retrieve and Load auctions in auction cycle
    #-----------------------------------------------------------------------------------------

    $tm->update_log("Started: Load Pending auctions for Auction Cycle ".$cycle);

    $pb->{ SetCurrentTask       }   =   3;
    $pb->{ SetCurrentOperation  }   =   "Retrieving Auctions in Cycle $cycle";
    $pb->{ SetTaskAction        }   =   "Loading auctions to Sella:";
    $pb->UpdateMultiBar();

    my $auctions =  $tm->get_cycle_auctions(
        AuctionSite     =>  "SELLA"   ,
        AuctionCycle    =>  $cycle      ,
    );

    $pb->{ SetProgressTotal     }   =   scalar( @$auctions );

    if ( scalar( @$auctions ) > 0 ) {
        SellaAuctionUpload( $auctions );
    }

    $pb->MarkTaskCompleted(3);
    $pb->UpdateMultiBar();

    # Housekeeping for any clones that have been created but not loaded

    if ( scalar( @clonekeys ) > 0 ) {

        foreach my $clonekey ( @clonekeys ) {

            $pb->{ SetCurrentOperation  }   =   "Performing clean up operations";
            $pb->UpdateMultiBar();
            $pb->ShowMultiBar();

            my $clonedata = $tm->get_auction_record( $clonekey );
            
            if ( $clonedata->{ AuctionStatus } = "PENDING" ) {
                $tm->delete_auction_record( $clonekey );
                $tm->update_log("Deleted Cloned Auction $clonedata->{ AuctionTitle } (Record $clonekey) - Auction did not load");
            }
        }
    }

    sleep 2;
    
    $tm->update_log("Completed: Load Pending auctions for Auction Cycle ".$cycle);

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # All Tasks completed
    #-----------------------------------------------------------------------------------------

    $tm->DBdisconnect();                          # disconnect from the database
    
    $tm->set_always_minimize( $pb->AlwaysMinimize() );
    $pb->QuitMultiBar();

    UpdateErrorStatus();   
    return $estruct;
}

#=============================================================================================
# LoadAllSellaImages - Load all images that have not been loaded to Sella
#=============================================================================================

sub LoadAllSellaImages {

    $tm = Auctionitis->new();
    $tm->initialise(Product => "Auctionitis");  # Initialise the product
    
    $tm->update_log("Invoked Method: ". (caller(0))[3]); 

    $tm->{ Debug } ge "1" ? ( $tm->dump_properties() ) : () ;

    $pb = Win32::OLE->new('MultiPB.clsMultiPB') or die;

    ### insert some text into the window header

    $pb->InitialiseMultiBar();
    $pb->{ AlwaysMinimize       }   =   $tm->{ AlwaysMinimize };
    $pb->{ SetWindowTitle       }   =   "Auctionitis: Load All Sella Images";
    $pb->{ SetProgressCurrent   }   =   0;
    $pb->{ SetProgressTotal     }   =   0;
    $pb->{ SetTaskAction        }   =   "Loading picture";
    
    $pb->AddTask("Load New Sella Images");
    $pb->UpdateMultiBar();

    $pb->ShowMultiBar();

    $tm->update_log("Connecting to Database");
    $tm->DBconnect();                           # Connect to the database

    $tm->update_log("Connecting to Sella");
    $tm->connect_to_sella();

    # if login was not OK update error structure and return

    if ( $tm->{ ErrorStatus } ) {
        $tm->set_always_minimize( $pb->AlwaysMinimize() );
        $pb->QuitMultiBar();
        UpdateErrorStatus();   
        return $estruct;
    }    

    #-----------------------------------------------------------------------------------------
    # Task 1 - Load Images
    #-----------------------------------------------------------------------------------------

    $tm->update_log("Started: Load New Sella Images");

    $pb->{ SetCurrentTask       }   =   1;
    $pb->{ SetCurrentOperation  }   =   "Loading Images to Sella";
    $pb->{ SetTaskAction        }   =   "Uploading file:";
    $pb->UpdateMultiBar();

    my $pictures =  $tm->get_unloaded_pictures( AuctionSite => "SELLA" );

    $pb->{ SetProgressTotal     }   =   scalar( @$pictures );
    $pb->UpdateMultiBar();

    if ( scalar( @$pictures ) ne 0 ) {
        SellaImageUpload( $pictures );
    }

    $pb->MarkTaskCompleted(1);
    $pb->UpdateMultiBar();

    $tm->update_log("Completed: Load New Pictures");

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
        return $estruct;
    }

    #-----------------------------------------------------------------------------------------
    # All Tasks completed
    #-----------------------------------------------------------------------------------------
    
    $tm->DBdisconnect();                          # disconnect from the database

    $tm->set_always_minimize( $pb->AlwaysMinimize() );
    $pb->QuitMultiBar();
    
    UpdateErrorStatus();   
    return $estruct;
}

#=============================================================================================
# LoadAll - Relist All Sella Auctions
#=============================================================================================

sub RelistAllSellaAuctions {

    $tm = Auctionitis->new();
    $tm->initialise( Product => "Auctionitis" );  # Initialise the product

    $tm->update_log("Invoked Method: ". ( caller(0))[3] ); 

    $tm->{ Debug } ge "1" ? ( $tm->dump_properties() ) : () ;

    $pb = Win32::OLE->new('MultiPB.clsMultiPB') or die;

    ### insert some text into the window header

    $pb->InitialiseMultiBar();
    $pb->{ AlwaysMinimize       }   =   $tm->{ AlwaysMinimize };
    $pb->{ SetWindowTitle       }   =   "Auctionitis: Relist All Sella Auctions";
    
    # Tasks to be performed in this operation
    
    $pb->AddTask( "Relist Sella auctions"   );

    $pb->UpdateMultiBar();
    $pb->ShowMultiBar();

    # Initialise the TradeMe object
    
    $tm->update_log( "Connecting to Database" );
    $tm->DBconnect();                          # Connect to the database

    # removed 12/22009 to test sessionidrequirements

    $tm->update_log( "Connecting to Sella" );
    $tm->connect_to_sella();

    # if login was not OK update error structure and return

    if ( $tm->{ ErrorStatus } ) {
        $tm->set_always_minimize( $pb->AlwaysMinimize() );
        $pb->QuitMultiBar();
        UpdateErrorStatus();   
        return $estruct;
    }    

    #-----------------------------------------------------------------------------------------
    # Task 1 - Load All Pending Autions
    #-----------------------------------------------------------------------------------------

    $tm->update_log( "Started: Relist All Sella auctions" );

    $pb->{ SetCurrentTask       }   =   1;
    $pb->{ SetTaskAction        }   =   "relisting Auctions on Sella:";
    $pb->{ SetCurrentOperation  }   =   "Retrieving Auctions requiring upload";
    $pb->UpdateMultiBar();

    my $auctions = $tm->get_relist_auctions(
        AuctionSite =>  "SELLA"   ,
    );

    $pb->{ SetProgressTotal } =  scalar( @$auctions );
    $pb->UpdateMultiBar();

    if ( scalar( @$auctions ) > 0 ) {
        SellaAuctionRelist( $auctions );
    }

    $pb->MarkTaskCompleted(3);
    $pb->UpdateMultiBar();

    $tm->update_log("Completed: Relist All Sella auctions");

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
        return $estruct;
    }    

    #-----------------------------------------------------------------------------------------
    # All Tasks completed
    #-----------------------------------------------------------------------------------------

    $tm->DBdisconnect();                          # disconnect from the database
    
    sleep 2;
    $tm->set_always_minimize( $pb->AlwaysMinimize() );
    $pb->QuitMultiBar();

    UpdateErrorStatus();   
    return $estruct;
}

#=============================================================================================
# SellaAuctionUpload - Procedure to actually perform the transmission to Sella
#=============================================================================================

sub SellaAuctionUpload {

    my $auctions    =   shift;
    my $counter     =   1;
    
    $tm->update_log("Invoked Method: ". (caller(0))[3]); 

    # Set Auction loading delay values to a minimum of 5 seconds
    # Multiply the retrieved delay value * 60 to convert to seconds

    my $delay       = 2;
    
    # Calculate total no. of auctions to be uploaded

    $pb->{ SetProgressTotal   }   =  scalar( @$auctions );

    foreach my $a ( @$auctions ) {

        $tm->update_log("AuctionUpload: Loading auction $a->{ Title } (Record $a->{ AuctionKey })");

        if ( $a->{ AuctionStatus } eq 'PENDING' ) {

            $pb->{ SetProgressCurrent   }   =   $counter;
            $pb->{ SetCurrentOperation  }   =   "Loading ".$a->{ Title};
            $pb->UpdateMultiBar();

            if  ( $tm->{ Debug } ge "1" ) {    
                foreach my $k ( sort keys %$a ) {
                    if ( $k ne 'Description' ) {
                        $tm->update_log( "$k \t: $a->{ $k }" );
                    }
                }
            }

            # Append the Standard terms to the Auction Desription

            my $terms       = $tm->get_standard_terms( AuctionSite => "SELLA" );
            my $description = $a->{ Description }."\n\n".$terms;

            my $maxlength = 3465;

            if ( length( $description ) > $maxlength ) {
                $description = $a->{ Description };
                $tm->update_log( "Auction $a->{ Title } (Record $a->{ AuctionKey }) - standard terms not applied.");
                $tm->update_log( "Combined length of standard terms and description would exceed allowable length");
                $tm->update_log( "Description [".length( $description )."] Terms [".length( $description )."] Threshold [".$maxlength."]");

                $description = $a->{ Description };
            }

            # Set the message field to blank and load the auction...                

            my $message = "";

            my $newauction = $tm->load_sella_auction(
                AuctionKey                      =>  $a->{ AuctionKey            }   ,
                Category                        =>  $a->{ Category              }   ,
                Title                           =>  $a->{ Title                 }   ,
                Subtitle                        =>  $a->{ Subtitle              }   ,
                Description                     =>  $description                    ,
                IsNew                           =>  $a->{ IsNew                 }   ,
                EndType                         =>  $a->{ EndType               }   ,
                DurationHours                   =>  $a->{ DurationHours         }   ,
                EndDays                         =>  $a->{ EndDays               }   ,
                EndTime                         =>  $a->{ EndTime               }   ,
                PickupOption                    =>  $a->{ PickupOption          }   ,
                ShippingOption                  =>  $a->{ ShippingOption        }   ,
                ShippingInfo                    =>  $a->{ ShippingInfo          }   ,
                StartPrice                      =>  $a->{ StartPrice            }   ,
                ReservePrice                    =>  $a->{ ReservePrice          }   ,
                BuyNowPrice                     =>  $a->{ BuyNowPrice           }   ,
                BankDeposit                     =>  $a->{ BankDeposit           }   ,
                CreditCard                      =>  $a->{ CreditCard            }   ,
                CashOnPickup                    =>  $a->{ CashOnPickup          }   ,
                EFTPOS                          =>  $a->{ EFTPOS                }   ,
                Quickpay                        =>  $a->{ Quickpay              }   ,
                AgreePayMethod                  =>  $a->{ AgreePayMethod        }   ,
                PaymentInfo                     =>  $a->{ PaymentInfo           }   ,
            );

            if ( not defined $newauction ) {
            
                $tm->update_log("*** Error loading auction to Sella - Auction not Loaded");
            }
            else {

                my ($closetime, $closedate);

                if ( $a->{ EndType } eq "DURATION" ) {
                
                    $closedate = $tm->closedate( $a->{ DurationHours } );
                    $closetime = $tm->closetime( $a->{ DurationHours } );
                }

                if ( $a->{ EndType } eq "FIXEDEND" ) {
                
                    $closedate = $tm->fixeddate( $a->{ EndDays } );
                    $closetime = $tm->fixedtime( $a->{ EndTime } );
                }

                $tm->update_log("Auction Uploaded to Sella as Auction $newauction");

                $tm->update_auction_record(
                    AuctionKey       =>  $a->{ AuctionKey }                       ,
                    AuctionStatus    =>  "CURRENT"                                      ,
                    AuctionRef       =>  $newauction                                    ,
                    DateLoaded       =>  $tm->datenow()                                 ,
                    CloseDate        =>  $closedate                                     ,
                    CloseTime        =>  $closetime                                     ,
                );
            }

            # Test whether the upload has been cancelled

            if ( $pb->{ Cancelled } ) {
                CancelHandler();
                return $estruct;
            }

            sleep 2;

            $counter++;
        }
        else {
            $tm->update_log("Auction $a->{Title} (Record $a->{AuctionKey}) not loaded: Invalid Auction Status ($a->{AuctionStatus})");
        }        
    }

    UpdateErrorStatus();   
    return $estruct;
}

#=============================================================================================
# SellaAuctionRelist - Procedure to actually perform the transmission to Sella
#=============================================================================================

sub SellaAuctionRelist {

    my $auctions    =   shift;
    my $counter     =   1;
    
    $tm->update_log("Invoked Method: ". (caller(0))[3]); 

    # Set Auction loading delay values to a minimum of 5 seconds
    # Multiply the retrieved delay value * 60 to convert to seconds

    my $delay       = 1;
    
    # Calculate total no. of auctions to be uploaded

    $pb->{ SetProgressTotal   }   =  scalar( @$auctions );

    foreach my $a ( @$auctions ) {

        $tm->update_log("AuctionRelist: Relisting auction $a->{ Title } (Record $a->{ AuctionKey })");

        if ( ( $a->{ AuctionStatus } eq 'SOLD' ) or ( $a->{ AuctionStatus } eq 'UNSOLD' ) ) {

            $pb->{ SetProgressCurrent   }   =   $counter;
            $pb->{ SetCurrentOperation  }   =   "Loading ".$a->{ Title};
            $pb->UpdateMultiBar();

            if  ( $tm->{ Debug } ge "1" ) {    
                foreach my $k ( sort keys %$a ) {
                    if ( $k ne 'Description' ) {
                        $tm->update_log( "$k \t: $a->{ $k }" );
                    }
                }
            }

            # Set the message field to blank and load the auction...                

            my $message = "";

            my $newauction = $tm->relist_sella_auction(     
                AuctionRef   =>  $a->{ AuctionRef },
            );


            if ( not defined $newauction ) {
            
                $tm->update_log("*** Error relisting auction on Sella - Auction not relistd");
            }
            else {

                my ( $closetime, $closedate );

                if ( $a->{ EndType } eq "DURATION" ) {
                
                    $closedate = $tm->closedate( $a->{ DurationHours } );
                    $closetime = $tm->closetime( $a->{ DurationHours } );
                }

                if ( $a->{ EndType } eq "FIXEDEND" ) {
                
                    $closedate = $tm->fixeddate( $a->{ EndDays } );
                    $closetime = $tm->fixedtime( $a->{ EndTime } );
                }

                $tm->copy_auction_record(
                    AuctionKey       =>  $a->{ AuctionKey }                     ,
                    AuctionStatus    =>  "CURRENT"                              ,
                    AuctionRef       =>  $newauction                            ,
                    AuctionSold      =>  0                                      ,
                    OfferProcessed   =>  0                                      ,
                    RelistStatus     =>  $a->{ RelistStatus }                   ,
                    DateLoaded       =>  $tm->datenow()                         ,
                    CloseDate        =>  $closedate                             ,
                    CloseTime        =>  $closetime                             ,
                    Message          =>  $message                               ,
                );

                # Delete from Auctionitis if delete from database flag set to True, otherwise update existing record 

                if  ( $tm->{ RelistDBDelete } ) {

                    $tm->delete_auction_record(
                        AuctionKey          =>  $a->{ AuctionKey }              ,
                    );
                    $tm->update_log( "Auction $a->{ AuctionRef}  (record $a->{ AuctionKey }) deleted from Auctionitis database" );

                }
                else {

                    $message = "Auction relisted as $newauction";
                    $tm->update_auction_record(
                        AuctionKey           =>  $a->{ AuctionKey }             ,
                        AuctionStatus        =>  "RELISTED"                     ,
                        Message              =>  $message                       ,
                    );
                }
            }

            # Test whether the upload has been cancelled

            if ( $pb->{ Cancelled } ) {
                CancelHandler();
                return $estruct;
            }

            sleep 2;

            $counter++;
        }
        else {
            $tm->update_log( "Auction $a->{ Title } (Record $a->{ AuctionKey }) not relisted: Invalid Auction Status ($a->{AuctionStatus})");
        }        
    }

    UpdateErrorStatus();   
    return $estruct;
}

#=============================================================================================
# SellaImageUpload - Procedure to actually perform the transmission to Sella
#=============================================================================================

sub SellaImageUpload {

    my $pictures    =   shift;
    my $counter     =   1;

    $tm->update_log( "Invoked Method: ". (caller(0))[3] ); 

    foreach my $pic ( @$pictures ) {

        $tm->update_log("Picture Upload: Processing record $pic->{ PictureKey }");

        $pb->{ SetProgressCurrent } = $counter;
        $pb->UpdateMultiBar();

        $pb->{ SetCurrentOperation } = "Processing ".$pic->{ PictureFileName };

        my $sellaid = $tm->load_sella_image_from_DB( 
            PictureKey  =>  $pic->{ PictureKey  }   ,
            ImageName   =>  $pic->{ ImageName   }   ,
        );

        if ( not defined $sellaid ) {
            $tm->update_log( "Error uploading File $pic->{ PictureFileName } to Sella (record $pic->{ PictureKey })" );
        }
        else {
            $tm->update_picture_record( 
                PictureKey       =>  $pic->{ PictureKey }   ,
                SellaID          =>  $sellaid               ,
            );
            $tm->update_log( "Loaded File $pic->{ PictureFileName } to Sella as $sellaid (record $pic->{ PictureKey })" );
        }

        # sleep for 1 second

        sleep 1;

        # increment loaded counter for progress bar

        $counter++;

        # check if operations has been cancelled

        if ( $pb->{ Cancelled } ) {
            CancelHandler();
            return $estruct;
        }
    }
    
    UpdateErrorStatus();   
    return $estruct;
    
}

##############################################################################################
# ---  General Utilits subroutines and callbacks ---
##############################################################################################

#=============================================================================================
# UpdateStatusBar - Update the Status Bar Text
#=============================================================================================

sub UpdateStatusBar {

    my $text = shift;

    $pb->{SetCurrentOperation} = $text;
    $pb->UpdateMultiBar();
}

#=============================================================================================
# UpdateProgressBar - Update the Progress Bar current value
#=============================================================================================

sub UpdateProgressBar {

    my $count = shift;

    $pb->{SetProgressCurrent} = $count;
    $pb->UpdateMultiBar();
}

#=============================================================================================
# UpdateProgressTotal - Update the Progress Bar Total
#=============================================================================================

sub UpdateProgressTotal {

    my $count = shift;

    $pb->{SetProgressTotal} = $count;
    $pb->UpdateMultiBar();
}

##############################################################################################
# ---  Internal Subroutines ---
##############################################################################################

sub UpdateErrorStatus {

    $estruct = { "ErrorStatus"  => "0",
                 "ErrorCode"    => "0",
                 "ErrorMessage" => "",
                 "ErrorDetail"  => ""
                };

    # If Error Status true write it to the log

    if ( $tm->{ ErrorStatus } ) {

        $tm->update_log("Error Status  : ".$tm->{ ErrorStatus   });
        $tm->update_log("Error Code    : ".$tm->{ ErrorCode     });
        $tm->update_log("Error Message : ".$tm->{ ErrorMessage  });
        $tm->update_log("Error Detail  : ".$tm->{ ErrorDetail   });

    }

    # Place the standard error indicators in an anonymous hash to return all properties

    $estruct = { "ErrorStatus"  => $tm->{ ErrorStatus   },
                 "ErrorCode"    => $tm->{ ErrorCode     },
                 "ErrorMessage" => $tm->{ ErrorMessage  },
                 "ErrorDetail"  => $tm->{ ErrorDetail   }
                };
}

sub CancelHandler {

    # Housekeeping for any clones that have been created but not loaded

    if ( scalar(@clonekeys) > 0 ) {

        foreach my $clonekey ( @clonekeys ) {

            $pb->{ SetCurrentOperation  }   =   "Performing clean up operations";
            $pb->UpdateMultiBar();
            $pb->ShowMultiBar();

            my $clonedata = $tm->get_auction_record( $clonekey );
            
            if ( $clonedata->{ AuctionStatus } = "PENDING" ) {
                $tm->delete_auction_record( $clonekey );
                $tm->update_log("Deleted Cloned Auction $clonedata->{ AuctionTitle } (Record $clonekey) - Aution did not load");
            }
        }
    }

    $tm->set_always_minimize( $pb->AlwaysMinimize() );
    $pb->QuitMultiBar();
    $tm->update_log("Process cancelled at User request");
    $abend = 1;

    # Place the standard error indicators in an anonymous hash to return all properties

    $estruct = { "ErrorStatus"  => "1",
                 "ErrorCode"    => "0",
                 "ErrorMessage" => "Process Cancelled at User request",
                 "ErrorDetail"  => ""
                };
}


sub ListingLimitAbend {

    # Housekeeping for any clones that have been created but not loaded

    if ( scalar(@clonekeys) > 0 ) {

        foreach my $clonekey ( @clonekeys ) {

            $pb->{ SetCurrentOperation  }   =   "Performing clean up operations";
            $pb->UpdateMultiBar();
            $pb->ShowMultiBar();

            my $clonedata = $tm->get_auction_record( $clonekey );
            
            if ( $clonedata->{ AuctionStatus } = "PENDING" ) {
                $tm->delete_auction_record( $clonekey );
                $tm->update_log("Deleted Cloned Auction $clonedata->{ AuctionTitle } (Record $clonekey) - Aution did not load");
            }
        }
    }

    $tm->set_always_minimize( $pb->AlwaysMinimize() );
    $pb->QuitMultiBar();
    $tm->update_log("Process aborted - Listing Limit Exceeded");
    $abend = 1;

    # Place the standard error indicators in an anonymous hash to return all properties

    $estruct = { "ErrorStatus"  => "1",
                 "ErrorCode"    => "0",
                 "ErrorMessage" => "Process aborted - Listing Limit Exceeded",
                 "ErrorDetail"  => ""
                };
}

1;

#####################################################################################
# Stuff below here talks to the perl control compiler                               #
#####################################################################################

=pod

=begin PerlCtrl

    %TypeLib = (
        PackageName         => 'TMLoader',
        DocString           => 'Auctionitis loader control',
        HelpFileName        => 'MyControl.chm',
        HelpContext         => 1,
        TypeLibGUID         => '{7BA4BEC5-880B-4E88-A6B5-217217E5546D}', # do NOT edit this line
        ControlGUID         => '{9A9938F5-A340-4DFC-8738-84DDBD061B1C}', # do NOT edit this line either
        DispInterfaceIID    => '{AB298571-EF7F-42DF-B866-8482AEFE7249}', # or this one
        ControlName         => 'TMLoader',
        ControlVer          => 1,  # increment if new object with same ProgID
                                   # create new GUIDs as well
        ProgID              => 'TMloader',
        LCID                => 0,
        DefaultMethod       => 'MyMethodName1',
        Methods             => {

            'UpdateLog'             => {
                                    DocString           =>  "Update the Auctionitis Log",
                                    TotalParams         =>  1,
                                    RetType             =>  VT_BSTR,
                                    NumOptionalParams   =>  0,
                                    ParamList           =>  [ 'LogText' => VT_BSTR ],
             },

            'GetMD5HashFromFile'    => {
                                    DocString           =>  "Get MD5 Hash from File",
                                    TotalParams         =>  1,
                                    RetType             =>  VT_BSTR,
                                    NumOptionalParams   =>  0,
                                    ParamList           =>  [ 'Filename' => VT_BSTR ],
             },

            'PropertyDump'          => {
                                    DocString           =>  "Dump Project Properties",
                                    TotalParams         =>  0,
                                    RetType             =>  VT_BSTR,
                                    NumOptionalParams   =>  0,
                                    ParamList           =>  [],
             },

            'ReplaceText'           => {
                                    DocString           =>  "Search and Replace Auction Text",
                                    TotalParams         =>  5,
                                    RetType             =>  VT_BSTR,
                                    NumOptionalParams   =>  0,
                                    ParamList           =>  [ 'Auction'           => VT_BSTR,
                                                              'SearchString'      => VT_BSTR,
                                                              'ReplaceString'     => VT_BSTR,
                                                              'UpdateTitle'       => VT_BSTR,
                                                              'UpdateDescription' => VT_BSTR ],
             },

             'GetDVDList'           => {
                                    DocString           =>  "Get DVD List",
                                    TotalParams         =>  1,
                                    RetType             =>  VT_BSTR,
                                    NumOptionalParams   =>  0,
                                    ParamList           =>  [ 'HTMLData' => VT_BSTR ],
             },

            'IsInternetConnected'   => {
                                    DocString           =>  "Is Internet connection available",
                                    TotalParams         =>  0,
                                    RetType             =>  VT_BSTR,
                                    NumOptionalParams   =>  0,
                                    ParamList           =>  [],
             },


            'GetDBProperty'         => {
                                    DocString           =>  "Get Database Properties",
                                    TotalParams         =>  2,
                                    RetType             =>  VT_BSTR,
                                    NumOptionalParams   =>  0,
                                    ParamList           =>  [ 'PropertyName' => VT_BSTR,
                                                              'DefaultValue' => VT_BSTR ],
             },

            'ExportData'            => {
                                    DocString           =>  "Export Data to CSV file",
                                    TotalParams         =>  2,
                                    RetType             =>  VT_BSTR,
                                    NumOptionalParams   =>  0,
                                    ParamList           =>  [ 'SQLSelection' => VT_BSTR,
                                                              'OutputFile'   => VT_BSTR ],
             },

            'ExportHTMLAsRecords'   => {
                                    DocString           =>  "Export Data to HTML Format",
                                    TotalParams         =>  2,
                                    RetType             =>  VT_BSTR,
                                    NumOptionalParams   =>  0,
                                    ParamList           =>  [ 'SQLSelection' => VT_BSTR,
                                                              'OutputFile'   => VT_BSTR ],
             },

            'ExportHTMLAsPages'     => {
                                    DocString           =>  "Export Data to HTML Format",
                                    TotalParams         =>  2,
                                    RetType             =>  VT_BSTR,
                                    NumOptionalParams   =>  0,
                                    ParamList           =>  [ 'SQLSelection' => VT_BSTR,
                                                              'OutputFile'   => VT_BSTR ],
             },

            'ExportXMLData'         => {
                                    DocString           =>  "Export Data to XML file",
                                    TotalParams         =>  5,
                                    RetType             =>  VT_BSTR,
                                    NumOptionalParams   =>  0,
                                    ParamList           =>  [ 'SQLSelection' => VT_BSTR,
                                                              'OutputFile'   => VT_BSTR,
                                                              'Description'  => VT_BSTR,
                                                              'CreateZip'    => VT_BSTR,
                                                              'IncludePics'  => VT_BSTR ],
             },
 
            'GetXMLProperties'      => {
                                    DocString           =>  "Get XML File properties",
                                    TotalParams         =>  1,
                                    RetType             =>  VT_BSTR,
                                    NumOptionalParams   =>  0,
                                    ParamList           =>  [ 'InputFile'    => VT_BSTR ],
             },

            'ImportXMLData'         => {
                                    DocString           =>  "Import Data from XML file",
                                    TotalParams         =>  9,
                                    RetType             =>  VT_BSTR,
                                    NumOptionalParams   =>  0,
                                    ParamList           =>  [ 'InputFile'       => VT_BSTR,
                                                              'Action'          => VT_BSTR,
                                                              'Count'           => VT_BSTR,
                                                              'SQL'             => VT_BSTR,
                                                              'AuctionStatus'   => VT_BSTR,
                                                              'RelistStatus'    => VT_BSTR,
                                                              'ProductType'     => VT_BSTR,
                                                              'AuctionCycle'    => VT_BSTR,
                                                              'HeldStatus'      => VT_BSTR ],
             },
 
            'LoadAllPhotos'         => {
                                    DocString           =>  "Load all outstanding photos",
                                    TotalParams         =>  0,
                                    RetType             =>  VT_BSTR,
                                    NumOptionalParams   =>  0,
                                    ParamList           =>  [],
             },
 

            'LoadSelectedPhotos'    => {
                                    DocString           =>  "Load a list of outstanding photos",
                                    TotalParams         =>  0,
                                    RetType             =>  VT_BSTR,
                                    NumOptionalParams   =>  0,
                                    ParamList           =>  [],
             },

            'Load'                  => {
                                    DocString           =>  "Load a single Auction",
                                    TotalParams         =>  1,
                                    RetType             =>  VT_BSTR,
                                    NumOptionalParams   =>  0,
                                    ParamList           =>  [ 'Auction' => VT_BSTR ],
             },

            'LoadSelected'          => {
                                    DocString           =>  "Load a list of Auctions",
                                    TotalParams         =>  1,
                                    RetType             =>  VT_BSTR,
                                    NumOptionalParams   =>  0,
                                    ParamList           =>  [ 'Auctions' => VT_BSTR ],
             },

            'LoadCycle'             => {
                                    DocString           =>  "Load all pending auctions in selected Cycle",
                                    TotalParams         =>  1,
                                    RetType             =>  VT_BSTR,
                                    NumOptionalParams   =>  0,
                                    ParamList           =>  ['AuctionCycle' => VT_BSTR ],
             },

            'LoadAll'               => {
                                    DocString           =>  "Load all Pending Auctions",
                                    TotalParams         =>  0,
                                    RetType             =>  VT_BSTR,
                                    NumOptionalParams   =>  0,
                                    ParamList           =>  [],
             },

            'Relist'                => {
                                    DocString           =>  "Relist a single Auction",
                                    TotalParams         =>  1,
                                    RetType             =>  VT_BSTR,
                                    NumOptionalParams   =>  0,
                                    ParamList           =>  [ 'Auction' => VT_BSTR ],
             },

            'RelistSelected'        => {
                                    DocString           =>  "Relist a list of Auctions",
                                    TotalParams         =>  1,
                                    RetType             =>  VT_BSTR,
                                    NumOptionalParams   =>  0,
                                    ParamList           =>  [ 'Auctions' => VT_BSTR ],
             },

            'RelistCycle'           => {
                                    DocString           =>  "Relist all eligible Auctions in selected Cycle",
                                    TotalParams         =>  1,
                                    RetType             =>  VT_BSTR,
                                    NumOptionalParams   =>  0,
                                    ParamList           =>  ['AuctionCycle' => VT_BSTR ],
             },

            'RelistAll'             => {
                                    DocString           =>  "Relist all Eligible Auctions",
                                    TotalParams         =>  0,
                                    RetType             =>  VT_BSTR,
                                    NumOptionalParams   =>  0,
                                    ParamList           =>  [],
             },

            'Offer'                 => {
                                    DocString           =>  "Offer a single Auction",
                                    TotalParams         =>  1,
                                    RetType             =>  VT_BSTR,
                                    NumOptionalParams   =>  0,
                                    ParamList           =>  [ 'Auction' => VT_BSTR ],
             },

            'OfferSelected'         => {
                                    DocString           =>  "Offer a list of Auctions",
                                    TotalParams         =>  1,
                                    RetType             =>  VT_BSTR,
                                    NumOptionalParams   =>  0,
                                    ParamList           =>  [ 'Auctions' => VT_BSTR ],
             },

            'OfferAll'              => {
                                    DocString           =>  "Offer all Eligible Auctions",
                                    TotalParams         =>  0,
                                    RetType             =>  VT_BSTR,
                                    NumOptionalParams   =>  0,
                                    ParamList           =>  [],
             },

            'ProcessAll'            => {
                                    DocString           =>  "Load Pending Auctions & eligible Relists",
                                    TotalParams         =>  0,
                                    RetType             =>  VT_BSTR,
                                    NumOptionalParams   =>  0,
                                    ParamList           =>  [],
             },

            'LoadSchedule'          => {
                                    DocString           =>  "Load Using Schedule Settings",
                                    TotalParams         =>  1,
                                    RetType             =>  VT_BSTR,
                                    NumOptionalParams   =>  0,
                                    ParamList           =>  [ 'ScheduleDay' => VT_BSTR ],
             },

            'ImportCurrent'         => {
                                    DocString           =>  "Import Current Auctions",
                                    TotalParams         =>  0,
                                    RetType             =>  VT_BSTR,
                                    NumOptionalParams   =>  0,
                                    ParamList           =>  [],
             },


            'ImportSold'            => {
                                    DocString           =>  "Import all Sold Auctions",
                                    TotalParams         =>  0,
                                    RetType             =>  VT_BSTR,
                                    NumOptionalParams   =>  0,
                                    ParamList           =>  [],
             },

            'ImportUnsold'          => {
                                    DocString           =>  "Import all unsold Auctions",
                                    TotalParams         =>  0,
                                    RetType             =>  VT_BSTR,
                                    NumOptionalParams   =>  0,
                                    ParamList           =>  [],
             },

            'ImportAll'             => {
                                    DocString           =>  "Import all Eligible Auctions",
                                    TotalParams         =>  0,
                                    RetType             =>  VT_BSTR,
                                    NumOptionalParams   =>  0,
                                    ParamList           =>  [],
             },

            'UpdateDB'              => {
                                    DocString           =>  "Update Auction database",
                                    TotalParams         =>  0,
                                    RetType             =>  VT_BSTR,
                                    NumOptionalParams   =>  0,
                                    ParamList           =>  [],
             },

            'UpdateDBSella'         => {
                                    DocString           =>  "Update Sella Auction database",
                                    TotalParams         =>  0,
                                    RetType             =>  VT_BSTR,
                                    NumOptionalParams   =>  0,
                                    ParamList           =>  [],
             },

            'DeleteUnusedPictures'  => {
                                    DocString           =>  "Delete Unused Pictures",
                                    TotalParams         =>  0,
                                    RetType             =>  VT_BSTR,
                                    NumOptionalParams   =>  0,
                                    ParamList           =>  [],
             },

            'DeleteTradeMePictures' => {
                                    DocString           =>  "Delete TradeMe Pictures",
                                    TotalParams         =>  0,
                                    RetType             =>  VT_BSTR,
                                    NumOptionalParams   =>  0,
                                    ParamList           =>  [],
             },

            'UpdateCategoryData'    => {
                                    DocString           =>  "Update Category Data",
                                    TotalParams         =>  0,
                                    RetType             =>  VT_BSTR,
                                    NumOptionalParams   =>  0,
                                    ParamList           =>  [],
             },

            'UpdateCategorySilent'  => {
                                    DocString           =>  "Category Update - Silent Mode",
                                    TotalParams         =>  0,
                                    RetType             =>  VT_BSTR,
                                    NumOptionalParams   =>  0,
                                    ParamList           =>  [],
             },


            'CheckServiceDates'     => {
                                    DocString           =>  "Import all Eligible Auctions",
                                    TotalParams         =>  0,
                                    RetType             =>  VT_BSTR,
                                    NumOptionalParams   =>  0,
                                    ParamList           =>  [],
             },

            'CheckChecksumData'     => {
                                    DocString           =>  "Import all Eligible Auctions",
                                    TotalParams         =>  0,
                                    RetType             =>  VT_BSTR,
                                    NumOptionalParams   =>  0,
                                    ParamList           =>  [],
             },

            'LoadAllSellaAuctions'  => {
                                    DocString           =>  "Load all Sella auctions",
                                    TotalParams         =>  0,
                                    RetType             =>  VT_BSTR,
                                    NumOptionalParams   =>  0,
                                    ParamList           =>  [],
             },

            'RelistAllSellaAuctions' => {
                                    DocString           =>  "Relist all Sella auctions",
                                    TotalParams         =>  0,
                                    RetType             =>  VT_BSTR,
                                    NumOptionalParams   =>  0,
                                    ParamList           =>  [],
             },
            'LoadSellaCycle'        => {
                                    DocString           =>  "Load selected Cycle to Sella",
                                    TotalParams         =>  1,
                                    RetType             =>  VT_BSTR,
                                    NumOptionalParams   =>  0,
                                    ParamList           =>  ['AuctionCycle' => VT_BSTR ],
             },
 
            'LoadAllSellaImages'    => {
                                    DocString           =>  "Load all Sella images",
                                    TotalParams         =>  0,
                                    RetType             =>  VT_BSTR,
                                    NumOptionalParams   =>  0,
                                    ParamList           =>  [],
             },

        },  # end of 'Methods'

        Properties        => {

            Version                 => {
                                    DocString           => "Version",
                                    Type                => VT_BSTR,
                                    ReadOnly            => 1,
            },

        },  # end of 'Properties'

    );  # end of %TypeLib

=end PerlCtrl

=cut

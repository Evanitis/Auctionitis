use strict;
use Auctionitis;
use Win32::OLE;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );

my ($tm, $pb, $estruct, $abend);

$tm = Auctionitis->new();

$tm->initialise(Product => "Auctionitis");
$tm->DBconnect();

my $SQL         =   "SELECT * FROM Auctions";
# my $outfile     =   "C:\\Program Files\\Auctionitis\\Output\\Evan.xml";
# my $filetext    =   "Exported XML data";
# my $makezip     =   "1";
# my $includepics =   "1";

# my $outfile     =   "C:\\Evan\\Auctionitis103\\Output\\CCFurniture.xml";
# my $filetext    =   "Clearance Company Furniture Data";
my $outfile     =   "C:\\Evan\\Auctionitis103\\Output\\CCElectronics.xml";
my $filetext    =   "Clearance Company Electronics Data";
my $makezip     =   "0";
my $includepics =   "0";

# $tm->export_XML(
#    Outfile     => "C:\\Program Files\\Auctionitis\\Output\\Evan.xml"   ,
#    SQL         => $SQL                                                 ,
#    Filetext    => $filetext                                            );

ExportXMLData(
    $SQL            ,
    $outfile        ,
    $filetext       ,
    $makezip        ,
    $includepics    ,
);


print " Error Status:".$estruct->{ ErrorStatus   }."\n";
print "   Error Code:".$estruct->{ ErrorCode     }."\n";
print "Error Message:".$estruct->{ ErrorMessage  }."\n";
print " Error Detail:".$estruct->{ ErrorDetail   }."\n";

print "Done!\n";

#=============================================================================================
# ExportXMLData - Export data in XML Format
#=============================================================================================
    
sub ExportXMLData {

    my $SQL         =   shift;
    my $outfile     =   shift;
    my $filetext    =   shift;
    my $makezip     =   shift;
    my $includepics =   shift;

    $tm = Auctionitis->new();
    $tm->initialise(Product => "Auctionitis");  # Initialise the product
    
    $tm->update_log("Invoked Method: ". (caller(0))[3]);

    $tm->dump_properties();

    $pb = Win32::OLE->new('MultiPB.clsMultiPB') or die;

    ### insert some text into the window header

    $pb->InitialiseMultiBar();
    
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
                    Filetext   => $filetext             ,
                    Feedback   => \&UpdateStatusBar     ,
                    Progress   => \&UpdateProgressBar   ,
                    Total      => \&UpdateProgressTotal );

    $pb->MarkTaskCompleted(1);
    $pb->UpdateMultiBar();
    sleep 2;
    
    $tm->update_log("Completed: Create XML File");

    # Handle the task being cancelled via the CANCEL button or ending abnormally

    if ($abend) {
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
      
        # If pictures are included get the list of pictures from the XML file

        if ( $includepics ) {

            my $picdata = $tm->list_xml_picturenames( Filename => $outfile );

            if ( $picdata->{ Count } > 0 ) {

                my $piclist = $picdata->{ Data  };
                my $counter = 1;

                $pb->{ SetTaskAction        }   =   "Zipping file:";
                $pb->{ SetProgressTotal     }   =   $picdata->{ Count };

                while((my $pic, my $val) = each(%$piclist)) {
                
                    $pb->{ SetCurrentOperation  }   =   "Adding file: $pic";
                    $pb->{ SetProgressCurrent   }   = $counter;
                    $pb->UpdateMultiBar();
        
                    my $member = $zip->addFile( $pic );
                    die 'write error' unless $zip->writeToFileNamed( $zipfile ) == AZ_OK;
                    $counter++;

                    if      ( $pb->{ Cancelled } ) {
                            CancelHandler();
                            return $estruct;
                    }
                }
            }
        }

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
    
    $tm->update_log("Completed: Exporting XML Data");
    
    # Handle the task being cancelled via the CANCEL button or ending abnormally

    $pb->QuitMultiBar();

    UpdateErrorStatus();   
    return $estruct;
}
 
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

#=============================================================================================
# UpdateStatusBar - Update the Status Bar Text
#=============================================================================================

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
 
use OLE;

$xlfile ="c:\\filename.xls";

##### OLE - Excel Connection

# Create OLE object - Excel Application Pointer
$xl_app = CreateObject OLE 'Excel.Application' || die $!;

# Set Application Visibility 
# 0 = Not Visible
# 1 = Visible
$xl_app->{'Visible'} = 1;

# Open Excel File
$workbook = $xl_app->Workbooks->Open($xlfile);
print $workbook;
# setup active worksheet
$worksheet = $workbook->Worksheets(1);

# retrieve value from worksheet
 $worksheet->Range("A1")->{'Value'}= $cellA1;
 $worksheet->Range("B1")->{'Value'}= $cellB1;

# Close It Up 
# $xl_app->ActiveWorkbook->Close(0);
# $xl_app->Quit();
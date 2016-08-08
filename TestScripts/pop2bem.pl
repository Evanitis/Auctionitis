# perl script to download pop3 email, save messages, and process into BEM via MSEND

use strict;
use warnings;

use Switch;	#case statement support
use Mail::POP3Client;  #cpan module for POP3 mailbox connectivity
use MIME::QuotedPrint;
use HTTP::Date;

#use MIME::Parser;

open (STDOUT, ">>C:/pop2bem/pop2bem.log");

my $pop = new Mail::POP3Client(
                 USER     => "alarmpointresponsema",
                 PASSWORD => "Password1",
                 HOST     => "nz-akl-excahub.datacraft-asia.com"
);

# test connection. -1 means failed connection, or else >=0 is num messages
#print "Message Count ", $pop->Count(), "\n";
switch ($pop->Count()) {
	case -1			{ Logger("Connection failed to POP3 Server: ", $pop->Host()); exit; }
	case 0			{ Logger("Connection Succeeded: ", $pop->Count(), " messages"); exit;}
	case {$_[0] >=1}	{ Logger("Connection Succeeded: ", $pop->Count(), " messages\n"); }
	else			{ Logger("Mailbox Connection Test returned: ", $pop->Count(), "\n"); exit; }
}


#Initialize stuff for MIME::Parser;
#my $outputdir = "./mimemail";
#my $parser = new MIME::Parser;
#$parser->output_dir($outputdir);


#process all messages in pop3 inbox

# filehandle for HeadAndBodyToFile() to use
my $fh = new IO::Handle();
my @fileList;
my @rimFileList;
my $i;
#print "\n";

my ($oldUIDL, $finalUIDL);
my $uidlFile = "uidl.txt";
if (-e $uidlFile) {
	open(UIDL, "$uidlFile");
	$oldUIDL = <UIDL>;
	close(UIDL);
}

if ($oldUIDL) {
	chomp $oldUIDL;
} else {
	$oldUIDL = 1;
}

#exit;

for ($i = 1; $i <= $pop->Count(); $i++) {
	my ($msgFile, $rimEmail, $quotedPrintable, $receiveDateEpochGMT, $sentDateEpochGMT, $msgUIDL, @uidl);

	@uidl = split(/\s+/,$pop->Uidl($i));
	$msgUIDL = $uidl[1];
	$finalUIDL = $msgUIDL;
		
	if ($msgUIDL <= $oldUIDL) {
		#print "Skipping UIDL: ", $msgUIDL, "\n";
		next;
	}

	$msgFile = "pop3.msg." . $msgUIDL;
	if (-e $msgFile) {
		Logger("Message already downloaded. Skipping file : ", $msgFile);
		next;
	}
	
	Logger("New Message");
	# print some basic message stats
	Logger("Msg# Size: ", $pop->List($i));
	#print "Msg# UIDL: ", $pop->Uidl($i);
	Logger("UIDL: ", $msgUIDL);
	Logger("File: ", $msgFile);
	
	# write full message to file
	open (MAILOUT, ">pop3.msg.$msgUIDL");
	$fh->fdopen( fileno( MAILOUT ), "w" );
	$pop->HeadAndBodyToFile( $fh, $i );
	close MAILOUT;
		
	# loop through header array 
	#	1. print out interesting headers
	#	2. decode and save body to file if MIME encoding is 'quoted-printable'

	# set up some variabls
	$quotedPrintable = 'No';
	$rimEmail = 'No';
	
	
	foreach ($pop->Head($i)) {
		#print "Header: ", $_, "\n";
		/^(Date|From|Subject|Content-Type|Content-Transfer-Encoding):\s+/i && 
			print $_, "\n";
		
		/^Subject:\s(RIM_INCIDENT).*/ && do {
			print $1, "\n";
			$rimEmail = 'Yes';
		};
		
		/^Content-Transfer-Encoding: (quoted-printable)/i && do {
			print $1,"\n";
			$quotedPrintable = 'Yes';
		};

		# get received date from header
		/^Date:\s(.+)/i && do {
			my $dateTime = str2time($1);
			if ($dateTime) {
				print "ReceiveDate Machine: ", $dateTime, "\n"; 		# Format as epoch
				print "ReceiveDate ReParsed: ", time2str($dateTime), "\n";   # Format as GMT ASCII time
				$receiveDateEpochGMT = $dateTime;
			} else {
				print "Cant Parse Date: $1\n";
			}
		};
	}
	
	# pull earliest sent date from Received fields
	my ($header, $receivedFields);
	$header = $pop->Head($i);
	$header =~ /(Received:.+)From:/ims;
	
	if ($1) {
		$receivedFields = $1;
		$receivedFields =~ s/[\t\r\n]//g;
		#print "ModifiedReceivedHeaders: \n", $receivedFields, "\n\n";
		
		$receivedFields =~ m/.*;(.+?)$/;
		if ($1) {
			$sentDateEpochGMT = str2time($1);								# Format as epoch
			print "SentDate Machine: ", $sentDateEpochGMT, "\n"; 			  
			print "SentDate ReParsed: ", time2str($sentDateEpochGMT), "\n";		# Format as GMT ASCII time
		}
	}
	
	if ($rimEmail eq 'Yes' and $quotedPrintable eq 'Yes') {
		my $headerFileName = "pop3.msg.$msgUIDL.head.txt";
		my $outputFileName = "pop3.msg.$msgUIDL.body.txt";

		open (DECODEDHEADER, ">$headerFileName");
		open (DECODEDBODY, ">$outputFileName");

		if ($msgUIDL ne '') {
			
			print DECODEDBODY "mc_tool_id=$msgUIDL;\n";
		}
		
		if ($receiveDateEpochGMT ne '') {
			print DECODEDBODY "mc_incident_report_time=$receiveDateEpochGMT;\n";
		}

		if ($sentDateEpochGMT ne '') {
			print DECODEDBODY "mc_incident_time=$sentDateEpochGMT;\n";
		}
		
		print DECODEDHEADER decode_qp($pop->Head($i));
		print DECODEDBODY decode_qp($pop->Body($i));
		close DECODEDBODY;
		push(@rimFileList, $outputFileName);
	} else {
		print "Email not a RIM Event or is not encoded in quotedPrintable format\n";
	}
	print "\n\n";
}

Logger("Old UIDL: ", $oldUIDL, "Final UIDL: ", $finalUIDL);

if ($finalUIDL > $oldUIDL) {
	open(UIDL, ">$uidlFile");
	print UIDL $finalUIDL, "\n";
	close(UIDL);
	Logger("UIDL now: ", $finalUIDL);
} else {
	Logger("No New Emails");
}

# process each file that was identified as a quoted-printable during pop download
my $parseGeneric = 'No';
if ($parseGeneric eq 'Yes') {
	foreach my $fileName (@fileList) {

		# if body larger than 2k its not likely to be an event record!!
		my $fileSize = -s "$fileName";
		my $maxFileSize = '2000';
		if ($fileSize >= $maxFileSize) {
			print "\n$fileName is > $maxFileSize ($fileSize bytes).\n Im NOT processing it!!\n";
			next;
		} else {
			print "\n$fileName is < $maxFileSize ($fileSize bytes). \nI'll process it!\n\n";
		}
			
		# passed filesize test so slurp in entire file
		my $slurpedFile = do { local( @ARGV, $/ ) = $fileName ; <> } ;
		#print "slurpedFile:\n$slurpedFile\n\nProcessing...\n";
		
		# parsing delimiters and field names for 'standard' records
		my $fieldStartDelimiter = '^';
		my $fieldEndDelimiter = ':';
		my $valueDelimiter = '$';
		my @fieldNames = ('Incident_ID','Client_Name','Client_Contract','Device','Summary','Priority','CI_Class',
			'IP_Address','Location','Impact','Urgency','Status','Previous action','Created','Closed','Ref');
		
		my @bemFieldNames = ('mc_tool_key','mc_account','mc_tool_rule','mc_host','msg','mc_tool_sev','mc_host_class',
			'mc_host_address','mc_location','mc_object','mc_object_class','mc_parameter','mc_parameter_unit','mc_service','mc_object_owner','mc_origin_key');
		
		# special-case fields, specify full regex 
		my @specialFields = (
			'^(WorkLog_Entry):(.+?[\r\n]{3,})', 
			'^(Detail):(.+)Priority:'
		);

		my %records;
		
		# parse full file for 'standard' records using delimiters and field names to hash
		# builds regex based on delimiters and listed fields and then tests full file
		foreach my $fieldName (@fieldNames) {
			my $matchRegEx = sprintf '%s%s%s(.+)%s', $fieldStartDelimiter, $fieldName, $fieldEndDelimiter,$valueDelimiter;
			if ($slurpedFile =~ m/$matchRegEx/im ) {
				my $value = $1;
				$value =~ s/^\s+//;
				$value =~ s/\s+$//;
				#print "FieldNameMatch=", $fieldName, "\t\tValue=", $value,"\n";
				$records{$fieldName}=$value;
			}
		}
		
		# do specific matches on full file text using the special-case regexes to hash
		# example, dealing with multi-line records
		foreach my $matchRegEx (@specialFields) {
			if ($slurpedFile =~ m/$matchRegEx/ims ) {
				my $fieldName = $1;
				my $value = $2;
				$value =~ s/^\s+//;
				$value =~ s/\s+$//;
				#print "FieldNameMatch=", $fieldName, "\t\tValue=", $value,"<ofv>\n";
				$records{$fieldName}=$value;
			}
		}
		
	# debug	
	#	print "\n SN ITSM Field              Value\n";
	#	print " ------------------------- ------------------------------------------------------------\n";
	#	foreach my $field(keys %records) {
	#		printf( " %-25s %-40s\n", $field, $records{$field} );
	#	}

		# do a print out and arrays matching for defined records / matched records + values / bem slots
		print "\n SN ITSM Field              Hash Key                  Value                                    BEM Field\n";
		print " ------------------------- ------------------------- ---------------------------------------- --------------------\n";
		my $arrayPos = 0;
		foreach my $fieldName(@fieldNames) {
			my $exists = '';
			my $recordValue = '';
			$exists = 'Exists' if exists $records{$fieldName};
			$recordValue = $records{$fieldName} if exists $records{$fieldName};
			printf( " %-25s %-25s %-40s %-20s\n", $fieldName, $exists, $recordValue, $bemFieldNames[$arrayPos]);
			$arrayPos += 1;
		}
		
		# create baroc file for BEM event
		my $bemArrayPos = 0; 
		open (BAROC, ">$fileName.baroc");

		# event setup
		print BAROC "EVENT;\n";
		print BAROC "severity=UNKNOWN;\n";
		print BAROC "mc_origin_class=RIM_INCIDENT_EMAIL;\n";
		print BAROC "mc_tool_class=RIM;\n";
		
		# special fields, need to deal with these properly yet
		print BAROC "mc_long_msg=(Detail:) $records{Detail};\n" if exists $records{Detail};
		print BAROC "mc_long_msg=(Worklog_Entry:) $records{Worklog_Entry};\n" if exists $records{Worklog_Entry};

		# loop through standard output BEM fieldnames array and pull input data values from associated
		# input fieldname array
		foreach my $bemField(@bemFieldNames) {
			my $fieldValue = '';
			my $fieldName = $fieldNames[$bemArrayPos];
			$fieldValue = $records{$fieldName} if exists $records{$fieldName};
			printf BAROC ("%s=%s;\n", $bemField, $fieldValue);
			$bemArrayPos += 1;
		}
		
		# end the event file
		print BAROC "END\n";
		close BAROC;
		
		# send the event to the impact-dev cell
		system("msend", "-n", "impact-dev", "$fileName.baroc");
		#system("set");
		
		print "\n\n";
	}
}
#end of generic record parser routine


#my $parseRim = 'No';
my $parseRim = 'Yes';
# RIM Incident Email specific parser
if (@rimFileList > 0 and $parseRim eq 'Yes') {
	foreach my $fileName (@rimFileList) {
		my $fileSize = -s "$fileName";
		my $maxFileSize = '5000';
		if ($fileSize >= $maxFileSize) {
			print "\n$fileName is > $maxFileSize ($fileSize bytes).\n Im NOT processing it!!\n";
			next;
		} else {
			print "\n$fileName is < $maxFileSize ($fileSize bytes). \nI'll process it!\n\n";
		}
		
		# passed filesize test so slurp in entire file
		my $slurpedFile = do { local( @ARGV, $/ ) = $fileName ; <> } ;
		#print "slurpedFile:\n$slurpedFile\n\nProcessing...\n";
		
		#put each record on seperate line if currently multiple on line
		$slurpedFile =~ s/\;m/\;\nm/g;

		# deal with prepended fields at top of file (above event class)
		my $mc_incident_report_time;
		$slurpedFile =~ s/(mc_incident_report_time=.*;)//;
		$mc_incident_report_time=$1 if $1;
		
		my $mc_incident_time;
		$slurpedFile =~ s/(mc_incident_time=.*;)//;
		$mc_incident_time=$1 if $1;

		my $mc_tool_id;
		$slurpedFile =~ s/(mc_tool_id=.*;)//;
		$mc_tool_id=$1 if $1;
		
		
		# rewrite mc_object_owner to mc_object 
		# ** need to get source events fixed - 17/10/2011
		$slurpedFile =~ s/mc_object_owner=/mc_owner=/;
		
		# fixes issue with missing semi-colon on itsm_product_vendor & re-writes to itsm_product_name
		# shouldnt need on prod system as latest events fixed, but not existing test events 17/10/2011
		# ** remove from production code or once all old events removed from mailbox - 17/10/2011
		# ** get Tony to fix itsm_product_vendor - 17/10/2011 - maybe put it to a rimEvent variable
		$slurpedFile =~ s/itsm_product_vendor=(.*);/gsoa_ci_model_manufacturer=$1;/;
		$slurpedFile =~ s/itsm_product_vendor=(.*)/gsoa_ci_model_manufacturer=$1;/;
		
		# massage and replace mc_long_msg
		$slurpedFile =~ s/mc_long_msg=/gsoa_worklog_note=/;
		
		if ($slurpedFile =~ m/(gsoa_worklog_note=.*)Ref:(.*)/ims) {
			my $workLogNote = $1;
			my $ref = $2;
			
			$workLogNote =~ s/^gsoa_worklog_note=\n/gsoa_worklog_note=/;
			$workLogNote =~ s/\n{2,}/\n/g;
			$workLogNote =~ s/;/:/g;
			chomp $workLogNote;
			$ref =~ s/\n//g;
			$ref =~ s/MSG//i;
			
			$slurpedFile =~ s/gsoa_worklog_note=.*//ims;
			my $append = $workLogNote . ";\n" . "mc_origin_key=" . $ref . ";\n";
			$slurpedFile .= $append;
			
		}
		#print $slurpedFile, "\n";

		# generic field remappings for new event architecture
		$slurpedFile =~ s/mc_owner=/gsoa_assignee_group=/;
		$slurpedFile =~ s/mc_host_class=/gsoa_ci_class=/;
		$slurpedFile =~ s/itsm_product_model=/gsoa_ci_model=/;
		$slurpedFile =~ s/mc_account=/gsoa_company=/;
		$slurpedFile =~ s/mc_tool_rule=/gsoa_contract=/;
		$slurpedFile =~ s/rim_Correlation_ID=/gsoa_correlation_id=/;
		$slurpedFile =~ s/mc_origin_key=/gsoa_email_ref=/;
		$slurpedFile =~ s/mc_object=/gsoa_impact=/;
		$slurpedFile =~ s/EVENT;/GSOA_INC;/;
		$slurpedFile =~ s/mc_tool_key=/gsoa_incident_number=/;
		$slurpedFile =~ s/mc_parameter_unit=/gsoa_previous_action=/;
		$slurpedFile =~ s/mc_tool_sev=/gsoa_priority=/;
		$slurpedFile =~ s/mc_parameter=/gsoa_status=/;
		$slurpedFile =~ s/mc_service=/gsoa_submitted=/;
		$slurpedFile =~ s/mc_object_class=/gsoa_urgency=/;
		$slurpedFile =~ s/mc_host=/gsoa_ci_name=/;
		$slurpedFile =~ s/mc_host_address=/gsoa_ci_ipaddress=/;
		$slurpedFile =~ s/mc_location=/gsoa_ci_location=/;
		$slurpedFile =~ s/mc_origin_class=/mc_origin_class=/;
		$slurpedFile =~ s/mc_tool_class=RIM_EMAIL_EVENT;/mc_tool_class=GSOA_INCIDENT_EMAIL;/;
		$slurpedFile =~ s/msg=/gsoa_summary=/;
		$slurpedFile =~ s/mc_tool_class=RIM;/mc_tool_class=Insite;/;
		
		# remove semi-colons from mid-string in gsoa_summary
		$slurpedFile =~ s/(gsoa_summary=.+);(.+;)/$1$2/g;
		
		
		# find gsoa_submitted text field, copy to gsoa_submitted_gmt text field
		# replace gsoa_submitted with epoch date data
		if ($slurpedFile =~ m/gsoa_submitted=(.*);/i) {
			$slurpedFile .= "gsoa_date_submitted=" . str2time($1) . ";\n";
		}
		
		if ($slurpedFile =~ m/gsoa_updated=(.*);/i) {
			$slurpedFile .= "gsoa_date_updated=" . str2time($1) . ";\n";
		} else {
			$mc_incident_time =~ m/mc_incident_time=(.*);/;
			if ($1) {
				$slurpedFile .= "gsoa_date_updated=" . $1 . ";\n";
			}
		}
			
				
		# add mc_incident_time based on email SENT date;
		$slurpedFile .= $mc_incident_report_time . "\n";
		$slurpedFile .= $mc_incident_time . "\n";
		$slurpedFile .= $mc_tool_id . "\n";
		
		$slurpedFile .= "END\n";
		# finish off file
		
		open (BAROC, ">$fileName.baroc");
		print BAROC $slurpedFile;
		close BAROC;
		
		# send the event to the impact-dev cell
		system("msend", "-n", "impact-dev", "$fileName.baroc");
		#system("set");
		
		print "\n\n";
	}
}
Logger("-------------");
close (STDOUT);

sub Logger {
	print scalar(localtime), " - ";
	foreach (@_) {
		my $arg = $_;
		chomp $arg;
		print $arg;
	}
	print "\n";
}

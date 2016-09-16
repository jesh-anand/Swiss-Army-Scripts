#=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
#
#	CMThresholdBreachRawDataExtraction.pl
#
#-------------------------------------------------------------------------------------
# File Name		: CMThresholdBreachRawDataExtraction.pl
# Author		: 608750727
# Date			: 24/02/2016
# Version		: 0.0.1
# Copyright(c)	: BT Global Technology (M) Sdn Bhd
#-------------------------------------------------------------------------------------
# Description	: Extract CM Threshold Breach Data from CM Server
#-------------------------------------------------------------------------------
# Modification History 
#---------------------
# Update : [Version] 	[Date] 			[Author] 			[Description]
# 			0.0.1		24/02/2016 		Harish Kumar		- Initial draft
#=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
#!/usr/local/bin/perl
use strict;
use warnings;
no warnings 'once';
use FindBin '$Bin';
use File::Path;
use File::Basename;
use Time::Local;
use lib "./lib";
use Log;
use Constant;

#---GLOBAL VARIABLES-----------------------------------------------------------#
my %CONF_HASH					= ();
my $IS_DEBUG_ENABLED 			= 0;	
my $LOG_RETENTION_PERIOD		= 0;
my $compression					= "";
my $MAX_WAIT_TIME 				= 0;
my $MAX_PROCESS_RUNTIME			= 0;	
my $MANUAL_RUN_FLAG				= 0;
my $CM_SERVER_PATH				= "";
my $CM_WORKING_DIR				= "";
my $HADOOP_DEST_PATH			= "";
my @FILTER_PARAMETER			= ();
my %cmFileHash					= ();
my $FILENAME_PREFIX				= "";
my $GZIP_ENABLED				= "";
my $curr 						= $$;
my $CONFIG_FILE_PATH			= "$Bin/conf/cmThresholdBreachDataExtract.cfg";

#---END GLOBAL VARIABLES-------------------------------------------------------#

#-- PREPARTION BEFORE EXECUTE MAIN FUNCTION -----------------------------------#

# Call the main sub
&Main();

sub Main{
	&readConf();
	Log::startLog(LOG_PATH, CONFIG_FILE_PATH);	
	&isProcessRunning();

	my @processDateArray = &getProcessingDate(@ARGV);

	foreach my $processDate (@processDateArray) {
		my $cmFilePath = buildCMFileName($CM_SERVER_PATH, $FILENAME_PREFIX, $processDate);
		if(checkValidCMRawFile($cmFilePath)) {
			&processCMRawData($cmFilePath, $processDate);
		}
	}
	
	Log::closeLog();	
}

#======================================================================================
# Name 		    : readConf
# Description	: Read and assign the configuration value from  .conf specific to the
#				  parameters initialized at global.
# Input		    : -
# Output	    : -
# Author	    : Harish Kumar
# Global Var	: -
# Date		    : 25 Feb 2016
#======================================================================================
sub readConf{

	my $func = "readConf";
	
	if (open(CONF,"<", CONFIG_FILE_PATH))
	{
		foreach my $Line (<CONF>) {
			if ( $Line !~ /^#/ && $Line =~ /\w+/ ) {
				chomp($Line);
				$Line =~ s/^\s|\s+$//;
				$Line =~ s/\s*=\s*/=/g;
				my ($param,$value) = split(/=/,$Line);
				$CONF_HASH{$param} = $value;
				Log::printInfoLine("$func: $param => $value") if ($IS_DEBUG_ENABLED);
			}
		}
		close (CONF);
	} else {
		Log::printErrorLine("$func: confPath " . CONFIG_FILE_PATH . "does not exist!");
		exit(1);
	}

	$LOG_RETENTION_PERIOD 	= $CONF_HASH{LOG_RETENTION_PERIOD};
	$IS_DEBUG_ENABLED 		= $CONF_HASH{DEBUG};
	$CM_SERVER_PATH 		= $CONF_HASH{CM_SERVER_PATH};
	$CM_WORKING_DIR 		= $CONF_HASH{CM_WORKING_DIR};
	$HADOOP_DEST_PATH		= $CONF_HASH{HADOOP_DEST_PATH};
	@FILTER_PARAMETER 		= split /,/, $CONF_HASH{FILTER_BY_PARAMETER};
	$FILENAME_PREFIX 		= $CONF_HASH{FILENAME_PREFIX};
	$GZIP_ENABLED 			= $CONF_HASH{GZIP_ENABLED};
	$MAX_WAIT_TIME 			= $CONF_HASH{MAX_WAIT_TIME_SCAN_IN_SEC};
	$MAX_PROCESS_RUNTIME 	= $CONF_HASH{MAX_ALLOWED_SCRIPT_RUNTIME_IN_MINUTE}
}

#======================================================================================
# Name 		    : getProcessingDate
# Description	: To retrieve the processing date based on the date given 
# 				  in the argv for manual run and last time process argv
# Input		    : Manual Run -> StartDate and EndDate 
#				  Auto pick -> LastProcessedDate 
# Output	    : Array of date to be processed 
# Author	    : Harish Kumar
# Global Var	: -
# Date		    : 26 Feb 2016
#======================================================================================
sub getProcessingDate(){
	my(@arg) 		= @_;
	my @tmpArry 	= ();
	my $func 		= "getProcessingDate";
	if(scalar(@arg)==2){
		Log::printInfoLine("$func: Processing request based on user input => startTime: ".$arg[0].", endTime: ".$arg[1]);
		foreach my $inputParam (@arg){
			if($inputParam!~/(\d{2,2}\-\d{2,2}\-\d{4,4})/){
				Log::printErrorLine("$func: Invalid format 'dd-mm-yyyy' given for startTime and endTime. Program is terminating..");	
				exit(1);
			}
		}
		@tmpArry = generateDailyProcessingDate(@arg);
		&writeLastProcessedTimestamp($arg[1]);
		$MANUAL_RUN_FLAG=1;
	} else {
		my $lastProcessingDate = getLastProcessedTimestamp();
		if ($lastProcessingDate) {
		
			$arg[0] = $lastProcessingDate;
			$arg[1] = &getCurrentProcessingDate(time);
			@tmpArry = generateDailyProcessingDate(@arg);
			&writeLastProcessedTimestamp($arg[1]);
		}
		else {
			my $curDate = &getCurrentProcessingDate(time);
			push (@tmpArry, $curDate);
			&writeLastProcessedTimestamp($curDate);
		}
	}

	foreach my $curDate (@tmpArry){
		Log::printInfoLine("$func: Processing files for date => ".$curDate);
	}

	return @tmpArry;
}

#======================================================================================
# Name 		    : generateDailyProcessingDate
# Description	: Generate the daily processing date during manual run trigger
# Input		    : StartDate, EndDate
# Output	    : Array of date to be processed 
# Author	    : Harish Kumar
# Global Var	: -
# Date		    : 26 Feb 2016
#======================================================================================
sub generateDailyProcessingDate(){
	my (@arg) 			= @_;
	my $func 			= "generateDailyProcessingDate";
	my @startDateArry 	= split(/-/,$arg[0]);
	my @endDateArry 	= split(/-/, $arg[1]);
	my $epochStartTime 	= timelocal("00","00","00",$startDateArry[0],$startDateArry[1]-1,$startDateArry[2]);
	my $epochEndTime 	= timelocal("00","00","00",$endDateArry[0],$endDateArry[1]-1,$endDateArry[2]);

	if($epochStartTime>$epochEndTime){
		Log::printErrorLine("$func: Invalid date given. startTime should not be greater than endTime. Program is terminating..");	
		exit(1);
	}

	my $generateDayCount = (($epochEndTime - $epochStartTime) / (3600 * 24)) + 1 ;

	my @timeArry = ();
	foreach (my $i=0;$i<$generateDayCount;$i++){
		if($i==0){
			push(@timeArry,&getCurrentProcessingDate($epochStartTime));
		} else {
			$epochStartTime += (3600 * 24);
			push(@timeArry,&getCurrentProcessingDate($epochStartTime));
		}
	}
	return @timeArry;
}

#======================================================================================
# Name 		    : getCurrentProcessingDate
# Description	: Generate the current processing date if scheduled run
# Input		    : Time()
# Output	    : dd-mm-yyy
# Author	    : Harish Kumar
# Global Var	: -
# Date		    : 26 Feb 2016
#======================================================================================
sub getCurrentProcessingDate(){
	my ($time)=@_;
	my @timeNow = localtime($time);
	my $lyear = $timeNow[5]+1900;
	my $lmonth = $timeNow[4]+1;
	my $lday = $timeNow[3];
	return sprintf("%02d-%02d-%04d",$lday,$lmonth,$lyear);
}

#======================================================================================
# Name 		    : formatTimestamp
# Description	: Formatting the date from dd-mm-yyyy into yyyy-mm-dd
# Input		    : Time() -> dd-mm-yyyy
# Output	    : Time() -> yyyy-mm-dd
# Author	    : Harish Kumar
# Global Var	: -
# Date		    : 29 Feb 2016
#======================================================================================
sub formatTimestamp{
	#11-10-2015
	my ($timestampStr) = @_;
	my @timeStampArry = split(/-/,$timestampStr);
	my $formattedTimestamp = ($timeStampArry[2]."-".$timeStampArry[1]."-".$timeStampArry[0]);
	return $formattedTimestamp;
}
#-----------------------------End of formatTimestamp---------------------------#

#======================================================================================
# Name 		    : buildCMFileName
# Description	: Building the CM FileName based on the prefix and process date
#				  Prefix -> SVLAN_Threshold_Breaches_CM_Automation_
#				  ProcessDate -> dd-mm-yyyy
# Input		    : CM FilePath, CM File Prefix, Date
# Output	    : CM FilePath -> /home/cm/raw/SVLAN_Threshold_Breaches_CM_Automation_29-02-2016.csv
# Author	    : Harish Kumar
# Global Var	: -
# Date		    : 29 Feb 2016
#======================================================================================
sub buildCMFileName(){
	my ($CM_SERVER_PATH, $FILENAME_PREFIX, $currDatePathFile) = @_;
	my $func = "buildCMFileName";
	my $cmFileToBeProcess = $CM_SERVER_PATH.$FILENAME_PREFIX.$currDatePathFile.".csv";
	
	Log::printInfoLine("$func: CM filename => ". $cmFileToBeProcess);
	
	return $cmFileToBeProcess;
}

#======================================================================================
# Name 		    : checkValidCMRawFile
# Description	: Check if the CM FileName is exist in the CM Server
# Input		    : CM FileName
# Output	    : 0 (!Exist) or 1(Exist) 
# Author	    : Harish Kumar
# Global Var	: -
# Date		    : 26 Feb 2016
#======================================================================================
sub checkValidCMRawFile(){
	my ($cmFileToBeProcess) = @_;
	my $func = "checkValidCMRawFile";

	Log::printInfoLine("$func: Searching CM FileName => ". $cmFileToBeProcess);
	
	if(-e $cmFileToBeProcess){
		Log::printInfoLine("$func: Found CM file => ". $cmFileToBeProcess);
		return 1;
	}
	else {
		if (&isExceedMaxProcessTime() || $MANUAL_RUN_FLAG) {
			Log::printInfoLine("$func: No CM file found => ". $cmFileToBeProcess);
			return 0;
		}
		else {
			sleep($MAX_WAIT_TIME);
			&checkValidCMRawFile($cmFileToBeProcess);
		}
	}
}

#======================================================================================
# Name 		    : getLastProcessedTimestamp
# Description	: Retrieve last porcessed date during schedule run
# Input		    : FILE
# Output	    : DATE - dd-mm-yyyy
# Author	    : Harish Kumar
# Global Var	: -
# Date		    : 25 Feb 2016
#======================================================================================

sub getLastProcessedTimestamp
{
	my $func = "getLastProcessedTimestamp";

	if (-e LAST_PROCESSED_TIMESTAMP_FILE)
	{
		open my $file, '<', LAST_PROCESSED_TIMESTAMP_FILE; 
		my $firstLine = <$file>; 
		close $file;

		Log::printInfoLine("INFO | $func: Found last processed directory timestamp - $firstLine");
		return $firstLine;
	}

	Log::printInfoLine("INFO | $func: Last processed directory timestamp not found");
	return 0;
}

#======================================================================================
# Name 		    : writeLastProcessedTimestamp
# Description	: Writing the last processing date in the file
# Input		    : DATE - dd-mm-yyyy
# Output	    : -
# Author	    : Harish Kumar
# Global Var	: -
# Date		    : 25 Feb 2016
#======================================================================================
sub writeLastProcessedTimestamp
{
	my ($tempLastprocessedDirTime) = @_;
	my $func = "writeLastProcessedTimestamp";

	Log::printDebugLine("DEBUG | $func: Write $tempLastprocessedDirTime to LAST_PROCESSED_TIMESTAMP_FILE" ) if ($IS_DEBUG_ENABLED);

	open(my $file, '>', LAST_PROCESSED_TIMESTAMP_FILE);
	print $file $tempLastprocessedDirTime;
	close $file;
}

#======================================================================================
# Name 		    : isProcessRunning
# Description	: To check if there is any process running by the time of this execution
# Input		    : -
# Output	    : Create lock file to avoid conflict with another process
# Author	    : Harish Kumar
# Global Var	: -
# Date		    : 26 Feb 2016
#======================================================================================
sub isProcessRunning()
{
	my $func = "isProcessRunning";
	my $processlockFile = PROCESS_LOCK_FILE;
	
	if(-e $processlockFile)
	{
		my $pid = `cat $processlockFile`;
		chomp($pid);
		my $cmd = "ps -p $pid";
		my @res = `$cmd`;
		if ($#res==0) {
		   #process not there, remove the lock file
		   unlink $processlockFile or printErrorLine("$func: Could not unlink $processlockFile $!");
		}
		 else {
	    	Log::printErrorLine("$func : Terminating process because another process is running => $processlockFile $!");
			Log::closeLog(); exit(1);
		}
	} else {
        #Creating process lock file
        if( open(LOCKFILE,">$processlockFile") )
        {
                print LOCKFILE $curr;
                close(LOCKFILE);
                Log::printInfoLine("$func : Main process lock is created with currPid $curr => $processlockFile"); 
        }
        else
        {
                Log::printErrorLine("$func : Fail to create $processlockFile $!");
				Log::closeLog(); exit(1);
        }
	}
}

#-------------------------------------------------------------------------------#
# Name          	: processCMRawData
# Description       : Read and filter the CM raw data based on the columns, gzip 
#					  and transfer to hadoop system using the shell script
# Input				: CM Raw Files and Processing Date
# Output			: -
# Author        	: Harish Kumar
# Date				: 01 March 2016
#------------------------------------------------------------------------------#
sub processCMRawData{
	my ($csvFiles, $processDate) 	= @_;
	my $func 						= "processCMRawData";
	my @rows 						= ();
	
	checkDir($CM_WORKING_DIR);
	my $csvOutputFile = $CM_WORKING_DIR."/cm-raw-".formatTimestamp($processDate);
	my $ctlOutputFile = $CM_WORKING_DIR."/done.ctl";
	
	# Open file for read
	open(IN, "<$csvFiles" ) or die "Can't open $csvFiles: $!";
	
	# Open file for write
	open (OUT, ">$csvOutputFile") or die "Failed to create file: $!";

	my @keys = split( /,/, <IN> );
	foreach my $line ( <IN> ) {
		# Skipping if the line is empty or a comment
		next if ( $line =~ /^\s*$/ );
		next if ( $line =~ /^\s*#/ );

		my %hash = ();
		@hash{ @keys } = split( /,/, $line );

		my $counter = 1;
		foreach my $row(@hash{@FILTER_PARAMETER}) {
			if ($counter++ == scalar(@FILTER_PARAMETER)) {
				print OUT $row;
			} 
			else {
				print OUT $row.","; 
			}
		}
		print OUT "\n";
	}
	
	# Close IN and OUT file handler
	close (OUT);
	close (IN);
	open CTLFILE, ">$ctlOutputFile"; close(CTLFILE);
	$cmFileHash{$csvOutputFile.".gz"} = formatTimestamp($processDate) if (! exists $cmFileHash{$csvOutputFile.".gz"});
	$cmFileHash{$ctlOutputFile} = formatTimestamp($processDate);
	
	#Compress all the working directory files
	if (uc($GZIP_ENABLED) eq "YES") {
		compressFile($CM_WORKING_DIR);
	}
	
	# Start SCP all working merged file to HAAS
	transferFile($CM_WORKING_DIR);
	
}



#-------------------------------------------------------------------------------#
# Name          	: checkDir
# Description       : Directory check, make, permission functions
# Input				: Directory Name
# Output			: SUCCESS OR FAIL
# Author        	: Harish Kumar
# Date				: 01 Mar 2016
#------------------------------------------------------------------------------#
sub checkDir {
	my ($dir) 	= @_;
	my $func 	= "checkDir";

	if (! -e $dir) {
		if (! mkdir($dir) ) {
			Log::printErrorLine("$func: Failed to create $dir directory. Exiting");
			Log::closeLog();	 
			exit(1);
		}
	} elsif (! -w  $dir) {
		my $mode = 0766;
		chmod $mode,$dir;
	}	
}

#-------------------------------------------------------------------------------#
# Name          	: compressFile
# Description       : Compress finalOutput final gzip
# Input				: Directory Name
# Output			: SUCCESS OR FAIL
# Author        	: Harish Kumar
# Date				: 01 Mar 2016
#------------------------------------------------------------------------------#
sub compressFile
{
	my ($targetDir) = @_;
	my $func 		= "compressFile";
	my $compressCmd = "gzip ".$targetDir."/cm-raw* > /dev/null 2>&1";

	Log::printInfoLine("$func: Compress Command : $compressCmd");
	system($compressCmd);
	Log::printInfoLine("$func: Compress $targetDir/cm-raw-* complete ");
	
	return "SUCCESS";
}
#-----------------------------End of compressFile------------------------------#

#-------------------------------------------------------------------------------#
# Name          	: transferFile
# Description       : Transfer the final outputFile as .gzip using curl into
#					  hadoop instances
# Input				: 
# Output			: SUCCESS OR FAIL
# Author        	: Harish Kumar
# Date				: 01 Mar 2016
#------------------------------------------------------------------------------#
sub transferFile
{
	my ($workingDirPath) 			= @_;
	my $func 						= "transferFile";
	my $count						= 0;
	my $haasPath 					= "";
	my %fileHash 					= ();
	my $csvFilePattern 				= $workingDirPath."/*.gz";
    my @csvFiles             		= glob($csvFilePattern);
    my $ctlFilePattern       		= $workingDirPath."/done.ctl";
    my @ctlFiles             		= glob($ctlFilePattern);
	my @allFiles 					= (@csvFiles , @ctlFiles);

	foreach my $file (@allFiles){
		
		$haasPath = $cmFileHash{$file} if (exists $cmFileHash{$file});
		
		my $finalDestPath = $HADOOP_DEST_PATH . $haasPath;

		# bash /npm/application/RawMetricFileMerge/lib/httpfs-file-transfer.sh test.csv.gz /user/HAASAAT0193_06487/npm/landing/file_landing/cm/2016-01-20/raw
		my $curlCmd = "bash ".LIB_PATH."/httpfs-file-transfer.sh ".$file." ".$finalDestPath."/raw";

		Log::printInfoLine("$func: CURL'g Command : $curlCmd");
		system($curlCmd);
		unlink $file;
		$count++;
	}
	if ($count > 0)
	{
		Log::printInfoLine("$func: Successfully transfered $count files to the HaaS server.");
	} else {
		Log::printInfoLine("$func: No files are transferred to the HaaS server.");
	}
}
#-----------------------------End of transferFile------------------------------#

#-------------------------------------------------------------------------------#
# Name          	: isExceedMaxProcessTime
# Description       : CM File waiting time (120 mins)
# Input				: 
# Output			: SUCCESS OR FAIL
# Author        	: Harish Kumar
# Date				: 01 Mar 2016
#------------------------------------------------------------------------------#
sub isExceedMaxProcessTime
{
	my ($timeNow) = time();
	my $func = "isExceedMaxProcessTime";
	#Get remainder to next hour
	my $remainder = 7200 - ($timeNow % 7200);
	my $nextHour = $timeNow + $remainder;
	
    # get max allowed process Run time => 59 minutes
	my $maxAllowedProcessRunTime = ($MAX_PROCESS_RUNTIME * 60);
    my $diffRunTime = $maxAllowedProcessRunTime - (($nextHour-$timeNow)-(7200 - $maxAllowedProcessRunTime));
    
    # terminating and exiting when process time reaches 59 minute
    # eg. exactly on minute 50, left time to terminate is 9 minute so cond would be like => (3540 - (600-60)) <= 3540
    my $remainingTimeInMinutes = sprintf("%.2f",(($maxAllowedProcessRunTime-$diffRunTime)/60));
    #sprintf("%.3f", $number);
    if($diffRunTime <= $maxAllowedProcessRunTime)
    {
    	Log::printDebugLine("$func: Remaining awake time before terminating => $remainingTimeInMinutes minutes") if($IS_DEBUG_ENABLED);
    	return 0;
    } else {
    	Log::printInfoLine("$func: Process has exceeded MAX_ALLOW_RUNTIME => \$diffRunTime = $diffRunTime ,");
    	Log::printInfoLine("$func: \$maxAllowedProcessRunTime => $maxAllowedProcessRunTime ! Terminating once the post processing process is completed...");
    	return 1;
    }
}

#sub processCMRawData{
#	my ($csvFiles, $processDate) 	= @_;
#	my $func 						= "processCMRawData";
#	my @fields 						= ();
#	my @rows 						= ();

	# Open file to read
#	open my $in, '<', "$csvFiles" or die "Can't open $csvFiles: $!";
	
	# Read and assign the first line (header) of the file into @fields
#	@fields = @{ $csv->getline( $in ) };

	# Loop and assign the subsequent lines according to the hash key which is the header of the file 
	# Then push the hash into @rows
#	while (my $row = $csv->getline ($in)) {
#		my %data;
#		@data{ @fields } = @$row;   
#		push @rows, \%data;
#	}
#	close $in; 
	
#	checkDir($CM_WORKING_DIR);
	
	# Open file for write
#	open my $out, ">", "$CM_WORKING_DIR/cm-raw-".formatTimestamp($processDate).".csv";

	# This will be printed after each call to $cvs->print()
#	$csv->eol ("\n");

	# Write out each CSV row to $out.  We use a hash slice again, 
	# to get out our fields in the desired order.
#	foreach my $row (@rows) {
#		$csv->print($out, [ @$row{ @FILTER_PARAMETER }]);
#	}

#	close $out;

	# Compress all the working directory files
#	if (uc($GZIP_ENABLED) eq "YES") {
#		compressFile($CM_WORKING_DIR);
#	}
#}


#=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
#
#	ADBaselineAlarmDataExtract.pl
#
#-------------------------------------------------------------------------------------
# Author          : yepchoon.wearn@bt.com
# Version         : v1.0 (05 Apr 2016)
# Copyright(c)    : BT Global Technology (M) Sdn Bhd
#-------------------------------------------------------------------------------------
# Description	  : BWCE-61618 : Analytic Dashboard
#                   Perl script to pig up the hourly baseline alarm trap and push it 
#                   into HAAS using curl and kerberos.
#-------------------------------------------------------------------------------
# Modification History 
#---------------------
# [Version]             [Author]                    [Description]
# v1.0 (05 Apr 2016) 	  yepchoon.wearn@bt.com       Initial draft
#=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
#!/usr/local/bin/perl
use strict;
use warnings;
use FindBin '$Bin';
use File::Path;
use File::Basename;
use Time::Local;
#use Time::Piece;
use lib "$FindBin::RealBin/lib";  
use Constants;
use Log;
use Commons;

#---GLOBAL VARIABLES-----------------------------------------------------------#
my $CUR_PID 			= $$;
my $DEBUG 				= 0;
my $PRINT_TO_CONSOLE 	= 0;
my %CONF_HASH 			= ();
my $COMP_NAME 			= "ADBaselineAlarmDataExtract";
my $CONFIG_FILE_PATH 	= "$Bin/conf/adBaselineAlarmDataExtract.cfg";
my $PROCESS_DATE 		= "current";

my %MONTH_LOOKUP		= ('Jan' => 1, 'Feb' => 2, 'Mar' => 3, 'Apr' => 4, 'May' => 5, 'Jun' => 6 , 'Jul' => 7, 'Aug' => 8, 'Sep' => 9, 'Oct' => 10, 'Nov' => 11, 'Dec' => 12);
#---END GLOBAL VARIABLES-------------------------------------------------------#


#-- PREPARTION BEFORE EXECUTE MAIN FUNCTION -----------------------------------#
if ( $ARGV[0] )
{
	$PROCESS_DATE = $ARGV[0];
}
&main($PROCESS_DATE);


#==============================================================
# Name 			: main
# Description 	: Main routine.
# Input 		: $passInDate|Date [yyyy-mm-dd-HH] to extract the baseline alarm. 
#                 Will take current date time if not pass in.
# Output 		: -  
# Author 		: yepchoon.wearn@bt.com
# Global Var 	: $CONFIG_FILE_PATH, $COMP_NAME, $PRINT_TO_CONSOLE, %CONF_HASH
# Date 			: 04/03/2016
#==============================================================
sub main()
{
	my ($passInDateHour)= @_;
	my $func 			= "main";
	my $confValid 		= Constants::FALSE;
	my $processValid 	= Constants::FALSE;
	my $folderValid 	= Constants::FALSE;
	my $completeFlag	= Constants::FALSE;
	my $curRun			= 0;
	
	Log::startLog(Constants::LOG_PATH, $CONFIG_FILE_PATH,$COMP_NAME,$PRINT_TO_CONSOLE);	
	
	Commons::readConf($CONFIG_FILE_PATH,\%CONF_HASH,$DEBUG);
	$confValid 		= &validateConf();
	&exitWithError() if( $confValid != Constants::TRUE );
	
	$processValid 	= &checkProcess();
	&exitWithError() if( $processValid != Constants::TRUE );
	
	$folderValid	= &prepareFolder();
	&exitWithError() if( $folderValid != Constants::TRUE );
	
	Log::printInfoLine( "$func : Start processing ..." );
	my $processDateTime = &generateDateTimeStr($passInDateHour);
	if( $processDateTime eq "" ) {
		Log::printErrorLine( "$func : Invalid date time input [$passInDateHour]." );
		&exitWithError();
	}
	
	Log::printInfoLine( "$func : processDateTime : [$processDateTime]." );
	my $fileListRef = &extractFileList();
	
	my $outputFile = &processAlarmFiles($fileListRef,$processDateTime);
	
	if( ! -f $outputFile ) {
		Log::printInfoLine( "$func : Not alarm log found. Create empty file, $outputFile" );
		if (open (OUT, ">$outputFile")) {
			close($outputFile);
		}
	}
	&transferFile($outputFile,$processDateTime);
	
	&cleanupOnExit();
}


sub transferFile()
{
	my ($outputFile,$processDateTime) 	= @_;
	my $func 							= "transferFile";
	my $hdfsPath						= $CONF_HASH{HDFS_DIRECTORY};
	my $outputPath						= $CONF_HASH{OUTPUT_DIRECTORY};
	my $ctlFile							= $CONF_HASH{HDFS_DONE_FILE_FORMAT};
	my $ctlAbsFile						= $outputPath."/".$ctlFile;


	if( -e $outputFile ) {
		# touch the done file
		if (open (OUT, ">$ctlAbsFile")) {
			close($ctlAbsFile);
		}
	
		my $pathTimestamp	 = &genPathTimestamp($processDateTime);
		my $rawFinalHdfsPath = $hdfsPath."/".$pathTimestamp;
		
		my $curlCmd = "bash ".LIB_PATH."/httpfs-file-transfer.sh ".$outputFile." ".$rawFinalHdfsPath."/raw";
		Log::printInfoLine("$func: CURL'g Command : $curlCmd");
		system($curlCmd);
		
		$curlCmd = "bash ".LIB_PATH."/httpfs-file-transfer.sh ".$ctlAbsFile." ".$rawFinalHdfsPath;
		Log::printInfoLine("$func: CURL'g Command : $curlCmd");
		system($curlCmd);
		
		unlink($ctlAbsFile);
	} else {
		Log::printErrorLine("$func: Output file not exist : $outputFile");
	}

}

#==============================================================
# Name 			: processAlarmFiles
# Description 	: Search through the folder and extract the baseline alarm 
#                 log files.
# Input 		: NA
# Output 		: Array of files that matched the alarm log pattern. 
# Author 		: yepchoon.wearn@bt.com
# Global Var 	: %CONF_HASH
# Date 			: 04/03/2016
#==============================================================
sub processAlarmFiles()
{
	my ($fileAryRef,$processDateTime)	= @_;
	my $func 			= "processAlarmFiles";
	my @fileAry 		= @{$fileAryRef};
	my $outputDir		= $CONF_HASH{OUTPUT_DIRECTORY};
	my $outputFilename	= 'alert-'.$processDateTime.'.log';
	my $absOutputFile	= $outputDir."/".$outputFilename;
	
	# remove the output file if already exists.
	if( -e $absOutputFile ) {
		Log::printInfoLine("$func : Output file already exists, remove it. | outputFile: $absOutputFile");
		unlink($absOutputFile);
	}
	
	foreach my $file (@fileAry) {
		Log::printInfoLine("$func : File = $file.");
		my $status = &processSingleFile($file,$absOutputFile,$processDateTime);
		#stop looking if detected older date record.
		if( $status == -1 ){
			last;
		}
	}
	
	return $absOutputFile;
}


sub processSingleFile()
{
	my ($alarmFile,$absOutputFile,$processDateTime)	= @_;
	
	my $func 			= "processSingleFile";
	my $baseDir			= $CONF_HASH{BASELINE_ALARM_PATH};
	my $absAlarmFile 	= $baseDir.$alarmFile;
	my $totalLineCount	= 0;
	my $recordCount 	= 0;
	my $status			= Constants::TRUE;
	
	if (open (OUT, ">>$absOutputFile")) {
	    
	    if(open (IN,"<".$absAlarmFile) ) {
	    	foreach my $line ( <IN> ) {
	    		chomp($line);
	    		$totalLineCount++; 
	    		if( $line =~ /formula_name\=Baseline Utilisation Deviation \(Percent\)/ ) {
	    			my @fieldAry 	= split(/,/,$line);
	    			my $fieldCnt	= scalar(@fieldAry);
	    			if(  $fieldCnt == 15) {
	    				my $tsStr	= $fieldAry[13];
	    				my $mValue	= $fieldAry[11];
	    				my $tsOnly	= (split(/=/,$tsStr))[1]; 
	    				my $propTs	= &convertTimestamp($tsOnly);
	    				
	    				Log::printDebugLine( "$func : $tsStr|$propTs|$mValue" ) if ($DEBUG); 
	    			
	    				my @timestampAry = split(/\-/,$propTs);
	    				my $dateHourOnly = sprintf("%04d-%02d-%02d-%02d",$timestampAry[0],$timestampAry[1],$timestampAry[2],$timestampAry[3]);
	    				my $recordTs	 = 	sprintf("%04d-%02d-%02d %02d:%02d",$timestampAry[0],$timestampAry[1],$timestampAry[2],$timestampAry[3],$timestampAry[4]);
	    			
	    				if(  $dateHourOnly eq $processDateTime ) {
	    					print OUT $line.",".$recordTs."\n";
	    					$recordCount++;	
	    				} elsif ( $propTs lt $processDateTime ){
	    					Log::printInfoLine( "$func : Detected record older than $processDateTime, stop looking after this file. Line timestamp = $tsOnly" ); 
	    					$status = -1;
	    				}
	    			}
	    		}
	    	}
	    	close(IN);
	    	
	    	Log::printInfoLine( "$func : Extracted $recordCount out of $totalLineCount line(s) for $processDateTime from $absAlarmFile." ); 
	    	
	    } else {
	    	Log::printErrorLine( "$func : Could not open $absAlarmFile file to read baseline alarm for $processDateTime" ); 
	    	$status = Constants::FALSE;
	    }
	    close(OUT);
	    
	    
	    
		return $status;
	} else {
		Log::printErrorLine( "$func : Could not open $absOutputFile file to write extracted baseline alarm for $processDateTime" ); 
		return Constants::FALSE;
	}		  
	
}

sub genPathTimestamp()
{
	my ($timestampStr)	= @_;
	my $func 			= "genPathTimestamp";
	
	#yyyy-MM-dd-HH
	my @timestampParts 	= split(/\-/,$timestampStr);
	
	my $feedTime	= timelocal(0,0,$timestampParts[3],$timestampParts[2],$timestampParts[1]-1,$timestampParts[0]);
	my @timeNow 	= localtime($feedTime+3600);
	my $lyear 		= $timeNow[5]+1900;
	my $lmonth 		= $timeNow[4]+1;
	my $lday 		= $timeNow[3];
	my $lhour   	=  $timeNow[2];
	return sprintf("%04d-%02d-%02d-%02d",$lyear,$lmonth,$lday,$lhour);
}

sub convertTimestamp()
{
	my ($timestampStr)	= @_;
	my $func 			= "convertTimestamp";
	
	
	#05-Apr-16 01.15.00.0 AM
	#07-Apr-16 12.00.00.0 AM 
	#06-Apr-16 11.45.00.0 PM
	
	my @timestampParts 	= split(/ /,$timestampStr);
	my $dateStr			= $timestampParts[0];
	my $timeStr			= $timestampParts[1];
	my $ampm			= $timestampParts[2];
	
	my @dateParts		= split(/-/,$dateStr);
	my $lday			= $dateParts[0];
	my $tmonth			= $dateParts[1];
	my $lmonth			= $MONTH_LOOKUP{$tmonth};
	my $lyear			= "20".$dateParts[2];
	
	my @timeParts		= split(/\./,$timeStr);
	my $lhour			= $timeParts[0];
	my $lmin			= $timeParts[1];
	
	if( $ampm eq 'PM' ) {
		if( $lhour != 12 ) {
			$lhour = $lhour + 12;	
		}
	} else {
		if( $lhour == 12 ) {
			$lhour = 0;
		}
	}
	
	return sprintf("%04d-%02d-%02d-%02d-%02d",$lyear,$lmonth,$lday,$lhour,$lmin);
}

#==============================================================
# Name 			: extractFileList
# Description 	: Search through the folder and extract the baseline alarm 
#                 log files.
# Input 		: NA
# Output 		: Array of files that matched the alarm log pattern. 
# Author 		: yepchoon.wearn@bt.com
# Global Var 	: %CONF_HASH
# Date 			: 04/03/2016
#==============================================================
sub extractFileList()
{
	my $func 		= "extractFileList";
	my $alarmDir	= $CONF_HASH{BASELINE_ALARM_PATH};
	my $filePrefix	= $CONF_HASH{BASELINE_FILE_PREFIX};
	my $filePostfix	= $CONF_HASH{BASELINE_FILE_POSTFIX};
	my @resultAry	= ();
	
	if (-e $alarmDir) {
		
		if( opendir (DIRH,$alarmDir) ) {	
			my $currentTime = time;	
			foreach my $file ( readdir(DIRH)) 
			{
				#---Excluding directory symbol
				next if ( $file =~ /^\.|^\.\./ );
				
				if( $file =~ /^$filePrefix/ && $file =~ /$filePostfix$/ ) {
					push(@resultAry,$file);
				}
			}
			closedir DIRH;
			my $totFileCount = scalar @resultAry; 
			
			if( $totFileCount > 0 ) {
				Log::printInfoLine("$func : Found $totFileCount files found from given directory $alarmDir.");
				
				my @sortedAry = sort{$b cmp $a} @resultAry;
				
				return \@sortedAry;
			} else {
				Log::printInfoLine("$func : No alarm log found in the given directory $alarmDir.");
			}
			
		} else {
			Log::printInfoLine("$func : Could not open the directory $alarmDir for reading baseline alarm log : $!");
		}
	}
	
	return \@resultAry;
}

#==============================================================
# Name 			: prepareFolder
# Description 	: Prepare the output and temp directory if it is not exist
# Input 		: NA
# Output 		: TRUE if directory exists or created succesfully. Otherwise FALSE
# Author 		: yepchoon.wearn@bt.com
# Global Var 	: %CONF_HASH
# Date 			: 04/03/2016
#==============================================================
sub prepareFolder()
{
	my $func 		= "prepareFolder";
	my $outputDir	= $CONF_HASH{OUTPUT_DIRECTORY};
	
	if (! -e $outputDir) {
		if (! mkdir($outputDir) ) {
			print("ERROR: Failed to create output directory.");
			Log::printErrorLine( "$func : Failed to create output directory to store final feed file. | outputDir=$outputDir" ); 
			return Constants::FALSE;
		}
	}
	
	return Constants::TRUE;
}


#==============================================================
# Name 			: generateLogTimeStr
# Description 	: Conver the date [yyyy-MM-dd-HH] to the 
#                 alarm log file timestamp format [].
# Input 		: $passInDateHour
#							The date [yyyy-MM-dd-HH] of the baseline that need to extract. 
#							Default to current which take current datetime minus 1 hour.
# Output 		: Date string in the format of yyyy-MM-dd-HH. 
#				  Otherwise it will return empty string.
# Author 		: yepchoon.wearn@bt.com
# Global Var 	: -
# Date 			: 04/03/2016
#==============================================================
sub generateLogTimeStr()
{
	my ($passInDate)	= @_;
	my $func = "generateLogTimeStr";
	
	if( $passInDate eq "current" ) {
		my @timeNow = localtime(time-3600);
		my $lyear 	= $timeNow[5]+1900;
		my $lmonth 	= $timeNow[4]+1;
		my $lday 	= $timeNow[3];
		my $lhour   =  $timeNow[2];
		return sprintf("%04d-%02d-%02d-%02d",$lyear,$lmonth,$lday,$lhour);
	} else {
		my @dateArry 	= split(/-/,$passInDate);		
		eval{ timelocal(0,0,$dateArry[3],$dateArry[2],$dateArry[1]-1,$dateArry[0]) };
		if( ! $@ ) {
			return $passInDate;
		}
	}
	return "";
}

#==============================================================
# Name 			: generateDateTimeStr
# Description 	: Check the pass in date [yyyy-MM-dd-HH] from argument. If current is pass in,
#				  It will return today datetime in YYYY-MM-DD-HH.
# Input 		: $passInDateHour
#							The date [yyyy-MM-dd-HH] of the baseline that need to extract. 
#							Default to current which take current datetime minus 1 hour.
# Output 		: Date string in the format of yyyy-MM-dd-HH. 
#				  Otherwise it will return empty string.
# Author 		: yepchoon.wearn@bt.com
# Global Var 	: -
# Date 			: 04/03/2016
#==============================================================
sub generateDateTimeStr()
{
	my ($passInDate)	= @_;
	my $func = "generateDateTimeStr";
	
	if( $passInDate eq "current" ) {
		my @timeNow = localtime(time-3600);
		my $lyear 	= $timeNow[5]+1900;
		my $lmonth 	= $timeNow[4]+1;
		my $lday 	= $timeNow[3];
		my $lhour   =  $timeNow[2];
		return sprintf("%04d-%02d-%02d-%02d",$lyear,$lmonth,$lday,$lhour);
	} else {
		my @dateArry 	= split(/-/,$passInDate);		
		eval{ timelocal(0,0,$dateArry[3],$dateArry[2],$dateArry[1]-1,$dateArry[0]) };
		if( ! $@ ) {
			return $passInDate;
		}
	}
	return "";
}

#==============================================================
# Name 			: validateConf
# Description 	: Validate if all the compulsory configuration is loaded.
# Input 		: NA
# Output 		: Return TRUE if all the mandatory configurations is provided 
#                 correctly. Otherwise, FALSE.
# Author 		: yepchoon.wearn@bt.com
# Global Var 	: $DEBUG, $CONF_HASH
# Date 			: 04/03/2016
#==============================================================
sub validateConf()
{
	my $func = "validateConf";
	
	my @mandatoryFields = ('HDFS_DIRECTORY', 'HDFS_DONE_FILE_FORMAT', 'OUTPUT_DIRECTORY'
								, 'BASELINE_ALARM_PATH', 'BASELINE_FILE_PREFIX', 'BASELINE_FILE_POSTFIX'
								, 'LOG_RETENTION_IN_HOUR', 'OUTPUT_RETENTION_IN_HOUR');
	
	if( %CONF_HASH ) {
		$DEBUG = ( $CONF_HASH{DEBUG} ) ? $CONF_HASH{DEBUG} : $DEBUG ; 
		
		#Add in configuration check
		foreach my $confKey ( @mandatoryFields ) {
			if( Commons::isStringEmpty( $CONF_HASH{$confKey} ) ) {
				Log::printErrorLine( "$func : Missing $confKey in the configuration file." );
				return Constants::FALSE;
			}
		}
		return Constants::TRUE;
	} else {
		Log::printErrorLine( "$func : Configuration file [$CONFIG_FILE_PATH] is empty or not valid." );
	}
	return Constants::FALSE;
}

#==============================================================
# Name 			: checkProcess
# Description 	: Check if there is another instance running. Stop if another instance is running. 
#				  Otherwise, it will log the current PID into a lck file. 
# Input 		: NA.
# Output 		: Return true if no other process is running and current PID is log into the lck file.
# Author 		: yepchoon.wearn@bt.com
# Global Var 	: $CUR_PID,Constants::PROCESS_LOCK_FILE
# Date 			: 04/03/2016
#==============================================================
sub checkProcess() 
{
	my $func 				= "checkProcess";
	my $isOldProcessRun 	= Constants::FALSE;
	my $createLockFileFlag	= Constants::FALSE;
	
	$isOldProcessRun 	= Commons::isProcessRunning(Constants::PROCESS_LOCK_FILE);
	
	if( $isOldProcessRun == Constants::TRUE ) {
		Log::printErrorLine( "$func : Another instance of the process is running. Going to exit...." );
		return Constants::FALSE;
	} 
	
	$createLockFileFlag = Commons::createProcessLockFile(Constants::PROCESS_LOCK_FILE,$CUR_PID);
	
	return $createLockFileFlag;
}

#==============================================================
# Name 			: exitWithError
# Description 	: Common housekeeping whenever the program exit in error. 
# Input 		: -
# Output 		: -
# Author 		: yepchoon.wearn@bt.com
# Global Var 	: -
# Date 			: 04/03/2016
#==============================================================
sub exitWithError()
{
	#my ($errorMsg) = @_;
	
	&cleanupOnExit();
	exit(1);
}

#==============================================================
# Name 			: cleanupOnExit
# Description 	: Common housekeeping whenever the program exit. 
# Input 		: NA
# Output 		: NA
# Author 		: yepchoon.wearn@bt.com
# Global Var 	: $CONF_HASH
# Date 			: 04/03/2016
#==============================================================
sub cleanupOnExit() 
{
	my $func = "cleanupOnExit";
	
	# remove process lock
	my $lockFile = Constants::PROCESS_LOCK_FILE;
	unlink($lockFile) if (-e $lockFile);   
	Log::printInfoLine( "$func : Removing process lock at $lockFile." );
	
	Commons::deleteOldFiles($CONF_HASH{OUTPUT_DIRECTORY},$CONF_HASH{OUTPUT_RETENTION_IN_HOUR});
	Log::printInfoLine( "$func : Cleanup output directory, ".$CONF_HASH{OUTPUT_DIRECTORY} );
	
	Commons::deleteOldFiles(Constants::LOG_PATH,$CONF_HASH{LOG_RETENTION_IN_HOUR});
	Log::printInfoLine( "$func : Cleanup log directory, ".Constants::LOG_PATH );
	
	Log::closeLog();
}

#===================== END OF FILE =============================================

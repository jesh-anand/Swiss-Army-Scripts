#=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
#
#	RawMetricsFileMerge.pl
#
#-------------------------------------------------------------------------------------
# File Name		: RawMetricsFileMerge.pl
# Author		: 607980248 , 607133064
# Date			: 02/11/2015
# Version		: 0.0.1
# Copyright(c)	: BT Global Technology (M) Sdn Bhd
#-------------------------------------------------------------------------------------
# Description	: N/A
#-------------------------------------------------------------------------------
# Modification History 
#---------------------
# Update : [Version] : [Date] : [Author] : [Description]
#02/11/2015 - Initial draft
#26/01/2016 - added support to extract traps and send to Haas
#04/04/2016 - added few columns in processTrapMetricFileMerge() to extract traps 
#			  and send to Haas.
#				--Element Id, PortName and Threshold Value
#09/04/2016 - Change the NPM Traps file landing to HaaS in processTrapMetricFileMerge()
#10/04/2016 - Change the NPM Raw Metric file landing to HaaS in processRawMetricFileMerge()
#=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
#!/usr/local/bin/perl
use strict;
use warnings;
use FindBin '$Bin';
use File::Path;
use File::Basename;
use Time::Local;
	
#---GLOBAL VARIABLES-----------------------------------------------------------#
my $DEBUG = 0;
my %CONF_HASH=();
my $confPath = "$Bin/conf/";
my $libPath = "$Bin/lib/";
my $confFilePath = $confPath."/rawMetricFileMerge.cfg";
my $logPath = "$Bin/log";
my $lastprocessedDirTime;
my $tempLastprocessedDirTime;
my $writeLastProcessedTimestampBol=0;
my @profileDirArry=();
my $workingDir="";
my $trapworkingDir="";
my $collectorId="";
my $logRetentionPeriod=0;
my $compression="";
my $metricIds="";
my @metricSet=();
my %metricHash=();
my %metricFileHash=();
my %trapFilterHash=();
my $MAX_WAIT_TIME = 0;	
my $MANUAL_RUN_FLAG=0;
#---END GLOBAL VARIABLES-------------------------------------------------------#
my $curr = $$;
my $processlockFile = $confPath."rawMetricFileMerge.lck";

#-- PREPARTION BEFORE EXECUTE MAIN FUNCTION -----------------------------------#

&main();


sub main(){
	
	&startLog($logPath);
	
	&isProcessRunning();
	
	&readConf($confFilePath);
	
	my @processHour = &getProcessingHour(@ARGV);
		
	foreach my $profilePath (@profileDirArry){
		
		my @profilesDirToProcessArry = getValidProfileDirAndCtlFile($profilePath,@processHour);

		foreach my $eachProfileDir (@profilesDirToProcessArry){
			
			&processRawMetricFileMerge($eachProfileDir,$profilePath);

			&processTrapMetricFileMerge($eachProfileDir,$profilePath);
						
		}
	}

}


# Purge old log files
deleteOldFiles($logPath, $logRetentionPeriod);

&writeLog("INFO | main: FINISHED");


#-- END OF EXECUTE MAIN FUNCTION ----------------------------------------------#





sub getProcessingHour(){
	my(@arg) = @_;
	my @tmpArry = ();
	my $func = "getProcessingHour";
	if(scalar(@arg)==2){
		&printInfoLine("$func: Processing request based on user input => startTime: ".$arg[0].", endTime: ".$arg[1]);
		foreach my $inputParam (@arg){
			if($inputParam!~/(\d{4,4}\-\d{2,2}\-\d{2,2}\s\d{2,2}\:\d{2,2}\:\d{2,2})/){
				&printErrorLine("$func: Invalid format 'yyyy-mm-dd hh24:mi:ss' given for startTime and endTime. Program is terminating..");	
				exit(1);
			}
		}
		@tmpArry = generateHourlyProcessingDate(@arg);
	} else {
		my $curHour = &getCurrentProcessingHour(time);
		push (@tmpArry, $curHour);
	}
	foreach my $currHour (@tmpArry){
		&printInfoLine("$func: Processing files for hour => ".$currHour);
	}
	return @tmpArry;
}
sub generateHourlyProcessingDate(){
	my (@arg) = @_;
	my $func = "generateHourlyProcessingDate";
	my $startTime = (split(" ",$arg[0]))[0];
	my $endTime = (split(" ",$arg[1]))[0];
	my @startDateArry = split(/-/,(split(" ",$arg[0]))[0]);
	my @startTimeArry = split(":",(split(" ",$arg[0]))[1]);
	my @endDateArry = split(/-/,(split(" ",$arg[1]))[0]);
	my @endTimeArry = split(":",(split(" ",$arg[1]))[1]);
	my $epochStartTime = timelocal("00","00",$startTimeArry[0],$startDateArry[2],$startDateArry[1]-1,$startDateArry[0]-1900);
	my $epochEndTime = timelocal("00","00",$endTimeArry[0],$endDateArry[2],$endDateArry[1]-1,$endDateArry[0]-1900);
		
	if($epochStartTime>$epochEndTime){
		&printErrorLine("$func: Invalid date given. startTime should not be greater than endTime. Program is terminating..");	
		exit(1);
	}
	
	my $generateHourCount = (($epochEndTime - $epochStartTime) / 3600) + 1 ;
	
	my @timeArry = ();
	foreach (my $i=0;$i<$generateHourCount;$i++){
		if($i==0){
			push(@timeArry,&getCurrentProcessingHour($epochStartTime));
		} else {
			$epochStartTime += 3600;
			push(@timeArry,&getCurrentProcessingHour($epochStartTime));
		}
	}
	$MANUAL_RUN_FLAG=1;
	return @timeArry;
}

sub processTrapMetricFileMerge(){
	my ($eachSubProfileDir,$profPath) = @_;
	my $func = "processTrapMetricFileMerge";
	my @matchedHourTrapFiles = ();
	my $csvCount = 0;
	
	my($trapDir,$curHour, $fileLandingHour) = getTrapDetails($eachSubProfileDir);

	&printInfoLine("$func: PROCESS $trapDir directory for trap hour => ".$curHour);

	my $workingTrapFile =$CONF_HASH{TRAPWORKINGDIR}."/COLLECTOR_" . $collectorId . "_" . basename($profPath);			
	my($year1,$month1,$day1,$hour1) = getMetricHourlyDirTimestamp($fileLandingHour);
	my $csvOutputFile = $workingTrapFile."_".$curHour.".csv";
	my $ctlOutputFile = $CONF_HASH{TRAPWORKINGDIR}."/done.ctl";
	
	@matchedHourTrapFiles = checkValidTrapFileToProcess($trapDir,$curHour);

	if(open(OUT,">>$csvOutputFile")){
		foreach my $trapFile (@matchedHourTrapFiles){
			my $trapFilePath = $trapDir . "/" . $trapFile;
			if(open(FH,"<$trapFilePath")){
				foreach my $line (<FH>){
					chomp($line);
					my @trapValues = split(/\^/,$line);
					my $metricName = (split(/\~/,$trapValues[8]))[-1];
					my @trapInfo = split(/\,/,$trapValues[23]);
					
					next if (!exists($trapFilterHash{$metricName}) || scalar(@trapValues) < 26);
					
					my $eltId = $trapInfo[3];
					my $seId = $trapValues[2];
					my $category = $trapValues[7];
					my $portName = $trapInfo[8];
					my $value = $trapValues[10];
					my $type = $trapFilterHash{$metricName};
					my $breachedDateTime = getBreachedThresholdDateTime($trapValues[11]);	
					my $finalOutput = $eltId .",". $seId .",". $category .",". $portName .",". $type .",". $breachedDateTime .",". $value;
					print OUT $finalOutput."\n";
				}
				&printDebugLine("$func: Finish writing ".basename($trapFilePath)." contents into $csvOutputFile") if ($DEBUG);
				$csvCount++;
				close(FH);
			} else 
			{
	        	printErrorLine("$func: Unable to open $trapFilePath file to read trap content!");
			}
		}
		close(OUT);
		open CTLFILE, ">$ctlOutputFile"; close(CTLFILE);
		$metricFileHash{$csvOutputFile.".gz"} = $year1."-".$month1."-".$day1."-".$hour1."/"."collector_".$collectorId if (! exists $metricFileHash{$csvOutputFile.".gz"});
		$metricFileHash{$ctlOutputFile} = $year1."-".$month1."-".$day1."-".$hour1."/"."collector_".$collectorId;
		
	} else {
       printErrorLine("$func: Unable to open $csvOutputFile file to write trap contents!");
	}
	
	
	&printInfoLine("$func: Finished merging $csvCount csv trap files for profile -> ".basename($profPath));	
	
	# Compress all the working directory files
	if (uc($compression) eq "YES") {
		compressFile($CONF_HASH{TRAPWORKINGDIR});
	}
		
	# Start SCP all working merged trap file to HAAS
	transferFile($CONF_HASH{TRAPWORKINGDIR},$CONF_HASH{TRAP_DEST_PATH});

}
sub checkValidTrapFileToProcess(){
	my ($trapPath,$trapHour) = @_;
	my $func = "checkValidTrapFileToProcess";
	my @trapFiles = ();
	my @newHourlyTrapFiles=();
	if(-d $trapPath){
		#ThresholdBreaches_SnmpNPM15MinAlcatel7750Group_SNMPProfile-alcatel_7750_17012016_120000.csv
		my @trap15MinsDir = &getHourlyTrapDirInterval($trapHour);
		foreach my $trap15Mins (@trap15MinsDir){
			opendir(TRAPDIR, $trapPath);
			@trapFiles = grep(/ThresholdBreaches\_(.*)15(.*)\_$trap15Mins\.csv$/, readdir(TRAPDIR));
			printDebugLine("$func: Found trap file to process for hour ".$trap15Mins." at => ".$trapPath) if ($DEBUG && scalar(@trapFiles)>0);
			push(@newHourlyTrapFiles,@trapFiles);
			close(TRAPDIR);
		}
		#printDebugLine("$func: No trap file found at this path => ". $trapPath . ", for hour => ".$trapHour) if ($DEBUG && (scalar(@trapFiles)==0));
	}
	printInfoLine("$func: Found total ".scalar(@newHourlyTrapFiles)." trap file to process.") ;
	return @newHourlyTrapFiles; 
}
sub getTrapDetails(){
	my ($tmpPath) = @_;
	my $trapPath = "";
	my $trapHour="";
	my $fileLandingHour="";

	my @tmpPath = split(/\//,$tmpPath);
	for(my $i=0;$i<(scalar(@tmpPath)-4);$i++){
		$trapPath .= $tmpPath[$i] ."/";
	}
	$trapPath.="traps";

	$tmpPath =~/(\d{8,8}\_\d{2,2})/;
	$trapHour=$1;
	$fileLandingHour=$trapHour;

	&printInfoLine(" trap hour => ".$fileLandingHour);
	
	#if(!$MANUAL_RUN_FLAG){
		$trapHour = getPreviousTrapHour($trapHour);
	#}

 	return $trapPath,$trapHour,$fileLandingHour;
}
sub processRawMetricFileMerge(){
	my ($metricHourlyDirPath,$profilePath) = @_;
	my $func = "processRawMetricFileMerge";
				
	&printInfoLine("$func: PROCESS $metricHourlyDirPath directory");
		
	my @csvFiles = getCSVFiles($metricHourlyDirPath);
		
	my $csvFileCount = 0;
	my($year1,$month1,$day1,$hour1) = getMetricHourlyDirTimestamp($metricHourlyDirPath);
	my $workingTargetfile=$workingDir."/COLLECTOR_" . $collectorId . "_" . basename($profilePath);					
	my $csvOutputFile = $workingTargetfile."_".$year1.$month1.$day1."_".$hour1.".csv";
	my $ctlOutputFile = $workingDir."/done.ctl";

	if(open(RAWOUT,">>$csvOutputFile")){
		foreach my $file (@csvFiles)
		{
			# file content timestamp
			my($year,$month,$day,$hour,$minute,$seconds) = getRawMetricFileTimeStamp($file);
			my $csvFile = $metricHourlyDirPath."/".$file;
			if (open my $in, '<', $csvFile)
			{
				while (my $line = <$in>) {
					my @lineArray = split /,/, $line;
					my $exludedtimestamp = substr $line, 0, rindex($line, ",");
					if (scalar @lineArray >= 5)
					{
						if(exists($metricHash{$lineArray[1]}))
						{
							my $formattedline = $exludedtimestamp.",".$year."-".$month."-".$day." ".$hour.":".$minute.":".$seconds."\n";
							print RAWOUT $formattedline;
						}
					}
				}
				&printDebugLine("$func: Finish writing ".basename($csvFile)." contents into $csvOutputFile") if ($DEBUG);
				$csvFileCount++;
				close $in;
			}
			else
			{
				&printErrorLine("$func: Could not open '$file' for reading");
			}
		}
		close(RAWOUT);
		open CTLFILE, ">$ctlOutputFile"; close(CTLFILE);
		$metricFileHash{$csvOutputFile.".gz"} = $year1."-".$month1."-".$day1."-".$hour1."/"."collector_".$collectorId if (! exists $metricFileHash{$csvOutputFile.".gz"});
		$metricFileHash{$ctlOutputFile} = $year1."-".$month1."-".$day1."-".$hour1."/"."collector_".$collectorId;
	} else {
			&printErrorLine("$func: Could not open '$csvOutputFile' for reading");
	}

	&printInfoLine("$func: Finished merging $csvFileCount csv files for profile -> ".basename($profilePath));	

	# Compress all the working directory files
	if (uc($compression) eq "YES") {
		compressFile($workingDir);
	}
	
	# Start SCP all working merged file to HAAS
	transferFile($workingDir,$CONF_HASH{DEST_PATH});
	
}
sub getValidProfileDirAndCtlFile(){
	my ($profilePath,@processingHours) = @_;
	my $func = "getValidProfileDirAndCtlFile";
	my @validProfileDirToProcess=();
	
	foreach my $processHour (@processingHours){	
		#SNMPProfile-alcatel_7750_20012016_111212_111
		my $profileDirNamePattern = basename($profilePath)."_".$processHour;
	
		my @matchedCurrentHourProfileDir=();
	
		printDebugLine("$func: Waiting current hour profile directory matching => ". $profileDirNamePattern."*") if ($DEBUG);
		
		while(scalar(@matchedCurrentHourProfileDir)==0){
			
			@matchedCurrentHourProfileDir = checkValidProfileDirToProcess($profileDirNamePattern,$profilePath);
			
			last if ( (scalar(@matchedCurrentHourProfileDir)>0) || &isExceedMaxProcessTime() || $MANUAL_RUN_FLAG);
			
			sleep($MAX_WAIT_TIME);
		}
		
		foreach my $currentHourDir (@matchedCurrentHourProfileDir){
			my @validCtlArry = ();
			my $currentHourPath = $profilePath ."/" .$currentHourDir;
	
			printDebugLine("$func: Waiting ctl file at dir => ". $currentHourPath) if ($DEBUG);
			
			while(scalar(@validCtlArry)==0){
				
				@validCtlArry = checkValidCtlFile($currentHourPath);
				if(scalar(@validCtlArry)>0){
					push @validProfileDirToProcess , $currentHourPath;
					last;
				}
				last if($MANUAL_RUN_FLAG);
				return sort @validProfileDirToProcess if &isExceedMaxProcessTime();
				sleep($MAX_WAIT_TIME);
			}
		}

	}
	
	foreach my $validDir (@validProfileDirToProcess){
		printInfoLine("$func: Found valid directories to process for profile -> ". basename($profilePath) . ", at hourly dir => " . basename($validDir));
	}
	
	return sort @validProfileDirToProcess;
}

sub getRawMetricFileTimeStamp(){
	my ($filetmp) = @_;
	my @fileArray = split /_/, $filetmp;
	my $fileArraySize = scalar @fileArray;
	my $datestr = $fileArray[$fileArraySize-2]; #11102015
	my $year = substr $datestr, 4, 4;
	my $month = substr $datestr, 2, 2;
	my $day = substr $datestr, 0, 2;
	my $timestr = $fileArray[$fileArraySize-1]; #180000
	my $hour = substr $timestr, 0, 2;
	my $minute= substr $timestr, 2, 2;
	my $seconds= substr $timestr, 4, 2;
	return ($year,$month,$day,$hour,$minute,$seconds);
}
sub getMetricHourlyDirTimestamp(){
	my($dirtmp)=@_;
	my $entryPathDirName = basename($dirtmp);
	$entryPathDirName =~/(\d{8,8}\_\d{2,2})/;
	my $year1 = substr $1, 4, 4;
	my $month1 = substr $1, 2, 2;				
	my $day1 = substr $1, 0, 2;
	my $hour1 = substr $1, 9, 10;	
	return ($year1,$month1,$day1,$hour1);
}
sub getPreviousTrapHour(){
	my ($tmpHr) = @_;
	my $year1 = substr $tmpHr, 4, 4;
	my $month1 = substr $tmpHr, 2, 2;				
	my $day1 = substr $tmpHr, 0, 2;
	my $hour1 = substr $tmpHr, 9, 10;	
	my $time = timelocal("00","00",$hour1,$day1,($month1-1),($year1-1900)); 
	my($sec,$min,$hhour,$dday,$mon,$yyear) = (localtime($time-3600))[0,1,2,3,4,5];
	$mon = $mon+1;
	$yyear = $yyear+1900;
	return sprintf("%02d%02d%04d_%02d",$dday,$mon,$yyear,$hhour);	
}
sub getHourlyTrapDirInterval(){
	my ($tmpHr) = @_;
	my $year1 = substr $tmpHr, 4, 4;
	my $month1 = substr $tmpHr, 2, 2;				
	my $day1 = substr $tmpHr, 0, 2;
	my $hour1 = substr $tmpHr, 9, 10;	
	my $time = timelocal("00","00",$hour1,$day1,($month1-1),($year1-1900)); 
	my @tmpTime = ();
	my @finalTime = ();
	
	for(my $i=0;$i<4;$i++){
		$time += 900;
		my($sec,$min,$hhour,$dday,$mon,$yyear) = (localtime($time))[0,1,2,3,4,5];
		$mon = $mon+1;
		$yyear = $yyear+1900;	
		push(@finalTime,sprintf("%02d%02d%04d_%02d%02d%02d",$dday,$mon,$yyear,$hhour,$min,$sec));
	}

	return @finalTime;	
}
sub getBreachedThresholdDateTime(){
	my($tmpTime)=@_;
	my($sec,$min,$hhour,$dday,$mon,$yyear) = (localtime($tmpTime))[0,1,2,3,4,5];
	$mon = $mon+1;
	$yyear = $yyear+1900;
	return sprintf("%04d-%02d-%02d %02d:%02d:%02d",$yyear,$mon,$dday,$hhour,$min,$sec);	
}

sub checkValidCtlFile(){
	my ($currHourPath) = @_;
	my $func="checkValidCtlFile";
	my @ctlFileArry=();
	if(-d $currHourPath){
		opendir(SUBPROFILEDIR, $currHourPath);
		@ctlFileArry = grep(/RAW.*\.ctl$/, readdir(SUBPROFILEDIR));	
		printInfoLine("$func: Found ctl file => ". $ctlFileArry[0]." at $currHourPath") if (scalar(@ctlFileArry)>0);
		printDebugLine("$func: Rejecting this hour profile directory because ctl file not found at => ". $currHourPath) if ($DEBUG && (scalar(@ctlFileArry)==0) && $MANUAL_RUN_FLAG);
		close(SUBPROFILEDIR);
	}
	return @ctlFileArry;
}

sub checkValidProfileDirToProcess(){
	my ($pattern,$path) = @_;
	my $func="checkValidProfileDirToProcess";
	my @tmpArry=();
	if(-d $path){
		opendir(PROFILEDIR, $path);
		@tmpArry = grep(/^$pattern\d{4,4}_\d+$/, readdir(PROFILEDIR));
		printDebugLine("$func: Found current hour profile directory => ". $tmpArry[0]) if ($DEBUG && scalar(@tmpArry)>0);
		printDebugLine("$func: Rejecting this hour profile directory because it does not exist based on this pattern=> ". $pattern ." , at => ". $path) if ($DEBUG && (scalar(@tmpArry)==0) && $MANUAL_RUN_FLAG);
		close(PROFILEDIR);
	}
	return @tmpArry;
}
sub getCurrentProcessingHour(){
	my ($time)=@_;
	my @timeNow = localtime($time);
	my $lyear = $timeNow[5]+1900;
	my $lmonth =  $timeNow[4]+1;
	my $lday =  $timeNow[3];
	my $lhour =  $timeNow[2];
	my $lmin =  $timeNow[1]; 
    my $lsec =  $timeNow[0]; 
	return sprintf("%02d%02d%04d_%02d",$lday,$lmonth,$lyear,$lhour); ;
}

sub getProfileDirectories(){
	my $func="getProfileDirectories";
	my @directories=();
		
	foreach my $profileDir (@profileDirArry){
		next if (!-d $profileDir);
		
		my $workingTargetfile=$workingDir."/COLLECTOR_" . $collectorId . "_" . 
			getDirName($profileDir) . "_" . 
			getCurrentTimestamp();
		
		&printDebugLine("$func: Get all directories from ". $profileDir) if ($DEBUG);

		opendir( my $DIR, $profileDir );
			while ( my $entry = readdir $DIR )
			{
				my $entryProfileDir = $profileDir . '/' . $entry;
				next unless -d $entryProfileDir;
				next if $entry eq '.' or $entry eq '..';
				push @directories, $entryProfileDir."|_|".$workingTargetfile;
			}
		closedir $DIR;
	} 
	
	return sort @directories;
}
#------------------------------------------------------------------------------#
# Name          : readConf
# Purpose       : Reads the configuration file and stores it to a hash
# Author        : Vivek Venudasan
# Arguments     : Config file path and reference to target hash
# ReturnValue   : SUCCESS or FAIL
#------------------------------------------------------------------------------#
sub readConf
{
	my ($ConfigFilePath) = @_;
	my $func="readConf";
	
	if (open(CONF,"<$ConfigFilePath"))
	{
		foreach my $Line (<CONF>) {
			if ( $Line !~ /^#/ && $Line =~ /\w+/ ) {
				chomp($Line);
				$Line =~ s/^\s|\s+$//;
				$Line =~ s/\s*=\s*/=/g;
				my ($param,$value) = split(/=/,$Line);
				$CONF_HASH{$param} = $value;
				printInfoLine("$func: $param => $value") if ($DEBUG);
			}
		}
		close CONF;
	} else {
		&writeLog("[ERROR]: confPath " . $ConfigFilePath . "does not exist!");
		exit(1);
	}
	# Collector profiles dir path
	@profileDirArry=split('\|_\|',$CONF_HASH{PROFILEDIR});
	if(scalar(@profileDirArry)==0){
		printErrorLine("$func: Collector profile directory is not provided. Please check configuration file!") ;
		exit(1);
	}
	$workingDir=$CONF_HASH{WORKINGDIR};
	checkDir($workingDir);
	$trapworkingDir=$CONF_HASH{TRAPWORKINGDIR};
	checkDir($trapworkingDir);
	$collectorId=$CONF_HASH{COLLECTORID};
	$logRetentionPeriod=$CONF_HASH{LOG_RETENTION_PERIOD};
	$compression=$CONF_HASH{GZIP_ENABLED};
	$metricIds=$CONF_HASH{METRIC_SET};
	@metricSet=split /,/, $metricIds;
	%metricHash = map { $_ => 1 } @metricSet;
	$DEBUG = $CONF_HASH{DEBUG};
	$MAX_WAIT_TIME = $CONF_HASH{MAX_WAIT_TIME_SCAN_IN_SEC};
	
	my @tmpTrapType = split(/,/,$CONF_HASH{TRAP_TYPE});
	foreach my $trapType (@tmpTrapType){
		my @trapMetricArry = split(/,/,$CONF_HASH{$trapType.".METRIC"});
		foreach my $trapMetric (@trapMetricArry){
			$trapFilterHash{$trapMetric} = $trapType if (!exists($trapFilterHash{$trapMetric}));
		}
	}
}
#-----------------------------End of readConf----------------------------------#

#------------------------------------------------------------------------------#
# Name          : getLastProcessedTimestamp
# Purpose       : 
# Author        : 607980248
# Arguments     : 
# ReturnValue   : Directory Name
#------------------------------------------------------------------------------#
=pod
sub getLastProcessedTimestamp
{

	my $func = "getLastProcessedTimestamp";

	if (-e $lastprocessedDirTimestampFile)
	{
		open my $file, '<', $lastprocessedDirTimestampFile; 
		my $firstLine = <$file>; 
		close $file;

		&writeLog("INFO | $func: Found last processed directory timestamp - $firstLine");
		return ($firstLine + 0);
	}

	&writeLog("INFO | $func: Last processed directory timestamp not found");
	return 0;
}
=cut
#-----------------------------End of getLastProcessedTimestamp-----------------#

#------------------------------------------------------------------------------#
# Name          : writeLastProcessedTimestamp
# Purpose       : 
# Author        : 607980248
# Arguments     : 
# ReturnValue   : Directory Name
#------------------------------------------------------------------------------#
=pod
sub writeLastProcessedTimestamp
{
	my $func = "writeLastProcessedTimestamp";
	&writeLog("DEBUG | $func: Write $tempLastprocessedDirTime to $lastprocessedDirTimestampFile" ) if ($DEBUG);

	open(my $file, '>', $lastprocessedDirTimestampFile);
		print $file $tempLastprocessedDirTime;
	close $file;

}
=cut
#-----------------------------End of writeLastProcessedTimestamp---------------#

#------------------------------------------------------------------------------#
# Name          : isCollectorMetricRawDircReady
# Purpose       : Check the collector directory is ok to transfer to HAAS
# Author        : 607980248
# Arguments     : Config file path and reference to target hash
# ReturnValue   : SUCCESS or FAIL
#------------------------------------------------------------------------------#
sub isCollectorMetricRawDircReady
{
	#directory expected name : SNMPProfile-alcatel_7750_11102015_040944_060

	my $func = "isCollectorMetricRawDircReady";
	my ($basePath,$directoryName) = @_;
	my $path = $basePath."/".$directoryName;
	my @directoryNameArray = split('_',$directoryName);
	my $dirTimestamp = formatTimestamp($directoryNameArray[2] . $directoryNameArray[3]);

	if ($dirTimestamp > $lastprocessedDirTime)
	{
		opendir(DIR, $path);
		my @files = grep(/RAW.*\.ctl$/, readdir(DIR));
		closedir(DIR);

		#Control file is found and indicate the csv files is ready for transfer
		foreach my $file (@files)
		{
			&writeLog("DEBUG | $func: Found control file $file at $path") if ($DEBUG);
			&writeLog("INFO | $func: ". getDirName($path) . " is ready for merge.");
			$tempLastprocessedDirTime = $dirTimestamp;
			return "SUCCESS";
		}
	}

	return "FAIL";
}
#-----------------------------End of isCollectorMetricRawDircReady-------------#

#------------------------------------------------------------------------------#
# Name          : getDirName
# Purpose       : 
# Author        : 607980248
# Arguments     : 
# ReturnValue   : Directory Name
#------------------------------------------------------------------------------#
sub getDirName
{
	my $func = "getDirName";
	my ($path) = @_;

	&printDebugLine("$func: Getting directory name from $path") if ($DEBUG);

	#my($filename, $dirs, $suffix) = fileparse($path);
	my $filename = basename($path);
	&printDebugLine("$func: Directory name is $filename") if ($DEBUG);

	return $filename;
}
#-----------------------------End of getDirName--------------------------------#

#------------------------------------------------------------------------------#
# Name          : getCSVFiles
# Purpose       : Check the collector directory is ok to transfer to HAAS
# Author        : 607980248
# Arguments     : Config file path and reference to target hash
# ReturnValue   : SUCCESS or FAIL
#------------------------------------------------------------------------------#
sub getCSVFiles
{
	my $func = "getCSVFiles";
	my ($path) = @_;

	&printDebugLine("$func: Lookup raw metrics csv files at $path") if ($DEBUG);

	opendir(DIR, $path);
		my @files = grep(/Metrics_RAW.*\.csv$/, readdir(DIR));
	closedir(DIR);

	&printInfoLine("$func: Found ". scalar @files . " cvs files to merge");
	return @files;
}
#-----------------------------End of getCSVFiles-------------------------------#

#------------------------------------------------------------------------------#
# Name          : formatTimestamp
# Purpose       : 
# Author        : 607980248
# Arguments     : 
# ReturnValue   : formatted timestamp
#------------------------------------------------------------------------------#
sub formatTimestamp
{
	#11102015040944
	my ($timestampStr) = @_;

	my $year = substr $timestampStr, 4, 4;
	my $month = substr $timestampStr, 2, 2;
	my $day = substr $timestampStr, 0, 2;
	my $hour = substr $timestampStr, 8, 2;
	my $minute = substr $timestampStr, 10, 2;
	my $seconds = substr $timestampStr, 12, 2;

	my $formattedTimestamp = ($year.$month.$day.$hour.$minute.$seconds) + 0;

	return $formattedTimestamp;
}
#-----------------------------End of formatTimestamp---------------------------#

#------------------------------------------------------------------------------#
# Name          : getCurrentTimestamp
# Description   : 
# Author        : 607980248
# Input         : 
# Output        : 
#------------------------------------------------------------------------------#
sub getCurrentTimestamp
{
	my ($logMsg) = @_;
	my @timeNow = localtime(time);
	my $lyear = $timeNow[5]+1900;
	my $lmonth =  $timeNow[4]+1;
	my $lday =  $timeNow[3];
	my $lhour =  $timeNow[2];
	my $lmin =  $timeNow[1];
	my $lsec =  $timeNow[0];
	return sprintf("%04d%02d%02d%02d%02d%02d",$lyear,$lmonth,$lday,$lhour,$lmin,$lsec);
}
#-----------------------------End of getCurrentTimestamp-----------------------#

#------------------------------------------------------------------------------#
# Name          : startLog
# Purpose       : Assigns Handle to Log file
# Author        : Vivek Venudasan
# Arguments     : None
# ReturnValue   : None
#------------------------------------------------------------------------------#
sub startLog
{
	my($logDirPath) = @_;
	my $func="startLog";
	my @timeData = localtime(time);
	my ($logday,$logmonth,$logyear);
	$logday = $timeData[3];
	$logmonth = $timeData[4]+1;
	$logyear = $timeData[5]+1900;
	my $temp = sprintf("RawMetricFileMergeLog.%04d%02d%02d",$logyear,$logmonth,$logday);
	my $logFile = $logDirPath."/".$temp.".log";
			
	#---Check log directory
	if (! -e $logDirPath) {
		if (! mkdir($logDirPath) ) {
			print("ERROR: Failed to create log directory. Exiting");
			exit (1);
		}
	} elsif (! -w  $logDirPath) {
		my $mode = 0766;
		chmod $mode,$logDirPath;
	}

	if (open (ALOG,">>$logFile"))
	{        
		&printInfoLine("============================================================");
		&printInfoLine(" FileName: $logFile");
		&printInfoLine(" Description: Raw Metric and Trap File Merge Log File");
		&printInfoLine(" Using cfg file: $confFilePath");     
		&printInfoLine("============================================================");
	}
	else
	{
		print ("[ERROR]: Either $logPath is not existing or No write access to $logPath! Log File will not be created!\n");
	}
	
}
#-----------------------------End of startLog----------------------------------#

#------------------------------------------------------------------------------#
# Name          : closeLog
# Purpose       : Releases Log File Handle
# Author        : Vivek Venudasan
# Arguments     : None
# ReturnValue   : None
#------------------------------------------------------------------------------#
sub closeLog
{
	&writeLog("================================================================");
	&writeLog("[END]: Raw Metric File Merge Log File");
	&writeLog("================================================================");
	close ALOG;
}
#-----------------------------End of closeLog----------------------------------#

#------------------------------------------------------------------------------#
# Name          : writeLog
# Description   : To print Log message to log file
# Author        : Vivek Venudasan
# Input         : Log message string
# Output        : An entry in log file
#------------------------------------------------------------------------------#
sub writeLog
{
	my ($logMsg) = @_;
	my @timeNow = localtime(time);
	my $lyear = $timeNow[5]+1900;
	my $lmonth =  $timeNow[4]+1;
	my $lday =  $timeNow[3];
	my $lhour =  $timeNow[2];
	my $lmin =  $timeNow[1];
	my $lsec =  $timeNow[0];
	my $thisTime = sprintf("%04d/%02d/%02d %02d:%02d:%02d",$lyear,$lmonth,$lday,$lhour,$lmin,$lsec);
	print ALOG "$thisTime | $logMsg \n";
	print "$thisTime | $logMsg \n";
}
#-----------------------------End of writeLog----------------------------------#

#------------------------------------------------------------------------------#
# Name          : compressFile
# Purpose       : 
# Author        : 607980248
# Arguments     : 
# ReturnValue   : SUCCESS OR FAIL
#------------------------------------------------------------------------------#
sub compressFile
{
	my $func 		= "compressFile";
	my ($targetDir) = @_;

	my $compressCmd = "gzip ".$targetDir."/*.csv > /dev/null 2>&1";

	&printInfoLine("$func: Compress Command : $compressCmd");
	system($compressCmd);
	&printInfoLine("$func: Compress $targetDir/*.csv complete ");
	
	return "SUCCESS";
}
#-----------------------------End of compressFile------------------------------#

#------------------------------------------------------------------------------#
# Name          : transferFile
# Purpose       : 
# Author        : 607980248
# Arguments     : 
# ReturnValue   : SUCCESS OR FAIL
#------------------------------------------------------------------------------#
sub transferFile
{
	my ($workingDirPath,$destPath) = @_;
	my $func 		= "transferFile";
	my $count		= 0;
	my $haasPath ="";
	my %fileHash = ();
    my $csvFilePattern       = $workingDirPath."/*.csv.gz";
    my @csvFiles             = glob($csvFilePattern);
    my $ctlFilePattern       = $workingDirPath."/done.ctl";
    my @ctlFiles             = glob($ctlFilePattern);
	my @allFiles = (@csvFiles , @ctlFiles);

	foreach my $file (@allFiles){
		
		$haasPath = $metricFileHash{$file} if (exists $metricFileHash{$file});
		
		my $finalDestPath = $destPath . $haasPath;

		# bash /npm/application/RawMetricFileMerge/lib/httpfs-file-transfer.sh test.csv.gz /user/HAASAAT0193_06487/npm/landing/metric/collector_1/2016/01/20/21
		my $curlCmd = "bash $libPath/httpfs-file-transfer.sh ".$file." ".$finalDestPath;

		&printInfoLine("$func: CURL'g Command : $curlCmd");
		system($curlCmd);
		unlink $file;
		$count++;
	}
	if ($count > 0)
	{
		&printInfoLine("$func: Successfully transfered $count files to the HaaS server.");
	} else {
		&printInfoLine("$func: No files are transferred to the HaaS server.");
	}
	
}
#-----------------------------End of transferFile------------------------------#

#===============================================================================
# Name		    : deleteOldFiles
# Description	: To delete the old log files
# Input 	    : The directory path of log files                 
# Output	    : 
# Author	    : Pawan Kumar
# Date		    : 26 March 2009
#===============================================================================

sub deleteOldFiles 
{
	my ( $dirPath, $retentionPeriod ) = @_;
	my $currentTime = time;
	my $func = "deleteOldFiles";

	if( opendir (DIRH,$dirPath) )
	{
		foreach my $file ( readdir(DIRH)) 
		{
			#---Excluding directory symbol
			next if (  $file =~ /^\.|^\.\./ );
			if ($file =~ /\.log$/)
			{
				my $absFileName = $dirPath."/".$file;

				#---File creation timestamp
				my $statTime = (stat($absFileName))[9];

				#---Deleting all files which are older than retaintion period
				if ( $retentionPeriod && ($currentTime - $statTime) > ($retentionPeriod* 24* 60 * 60) ) 
				{
					my $cmd=qq@rm -f $absFileName @;

					if(system($cmd) != 0)
					{
						&writeLog("ERROR | $func: Unable to delete old file: $absFileName");
					}
					else
					{
						&writeLog("DEBUG | $func: Removed $absFileName") if ($DEBUG);
					}
				}
			}
		}
	}
	else
	{
		&writeLog("ERROR | $func: Could not open the directory $dirPath for cleanup : $!");
	}
    closedir DIRH;   
}
#======================================================================================
# Name 		    : isProcessRunning
# Description	: To check if there is any process running by the time of this execution
# Input		    : -
# Output	    : Create lock file to avoid conflict with another process
# Author	    : Brandon
# Global Var	: -
# Date		    : Sept 2014
#======================================================================================
sub isProcessRunning()
{
	my $func = "isProcessRunning";
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
	    	printErrorLine("$func : Terminating process because another process is running => $processlockFile $!");
			close(LOG); exit(1);
		}
	} else {
        #Creating process lock file
        if( open(LOCKFILE,">$processlockFile") )
        {
                print LOCKFILE $curr;
                close(LOCKFILE);
                printInfoLine("$func : Main process lock is created with currPid $curr => $processlockFile"); 
        }
        else
        {
                printErrorLine("$func : Fail to create $processlockFile $!");
				close(LOG); exit(1);
        }
	}
}
#============================================================== 
# Name          	: printInfoLine 
# Description   	: To print Log message to log file 
# Input         	: Log message string 
# Output            : An entry in log file 
# Author            : Brandon
# Last updated  	: 16 Aug 2014 
#============================================================== 
sub printInfoLine 
{ 
    my ($logMsg) = @_; 
    # Current time stamps; l - log 
    my @timeNow = localtime(time); 
    my $lyear = $timeNow[5]+1900; 
    my $lmonth =  $timeNow[4]+1; 
    my $lday =  $timeNow[3]; 
    my $lhour =  $timeNow[2]; 
    my $lmin =  $timeNow[1]; 
    my $lsec =  $timeNow[0]; 

    my $thisTime = sprintf("%04d/%02d/%02d %02d:%02d:%02d",$lyear,$lmonth,$lday,$lhour,$lmin,$lsec); 
    print ALOG "$thisTime | INFO | $logMsg\n"; 
    #LOG->autoflush();
}
#============================================================== 
# Name          	: printErrorLine 
# Description   	: To print ERROR log message to log file 
# Input         	: Log message string 
# Output            : An entry in log file 
# Author            : brandon 
# Last updated  	: 18 Aug 2014 
#============================================================== 
sub printErrorLine
{ 
    my ($logMsg) = @_; 
    # Current time stamps; l - log 
    my @timeNow = localtime(time); 
    my $lyear = $timeNow[5]+1900; 
    my $lmonth =  $timeNow[4]+1; 
    my $lday =  $timeNow[3]; 
    my $lhour =  $timeNow[2]; 
    my $lmin =  $timeNow[1]; 
    my $lsec =  $timeNow[0]; 

    my $thisTime = sprintf("%04d/%02d/%02d %02d:%02d:%02d",$lyear,$lmonth,$lday,$lhour,$lmin,$lsec); 
    print ALOG "$thisTime | ERROR | $logMsg\n"; 
    #LOG->autoflush();
}
#============================================================== 
# Name          	: printDebugLine 
# Description   	: To print Debug log message to log file 
# Input         	: Log message string 
# Output            : An entry in log file 
# Author            : brandon 
# Last updated  	: 18 Aug 2014 
#============================================================== 
sub printDebugLine
{ 
    my ($logMsg) = @_; 
    # Current time stamps; l - log 
    my @timeNow = localtime(time); 
    my $lyear = $timeNow[5]+1900; 
    my $lmonth =  $timeNow[4]+1; 
    my $lday =  $timeNow[3]; 
    my $lhour =  $timeNow[2]; 
    my $lmin =  $timeNow[1]; 
    my $lsec =  $timeNow[0]; 

    my $thisTime = sprintf("%04d/%02d/%02d %02d:%02d:%02d",$lyear,$lmonth,$lday,$lhour,$lmin,$lsec); 
    print ALOG "$thisTime | DEBUG| $logMsg\n"; 
    #LOG->autoflush();
}
sub isExceedMaxProcessTime
{
	my ($timeNow) = time();
	my $func = "isExceedMaxProcessTime";
	#Get remainder to next hour
	my $remainder = 3600 - ($timeNow % 3600);
	my $nextHour = $timeNow + $remainder;
	
    # get max allowed process Run time => 59 minutes
	my $maxAllowedProcessRunTime = ($CONF_HASH{MAX_ALLOWED_SCRIPT_RUNTIME_IN_MINUTE} * 60);
    my $diffRunTime = $maxAllowedProcessRunTime - (($nextHour-$timeNow)-(3600 - $maxAllowedProcessRunTime));
    
    # terminating and exiting when process time reaches 59 minute
    # eg. exactly on minute 50, left time to terminate is 9 minute so cond would be like => (3540 - (600-60)) <= 3540
    my $remainingTimeInMinutes = sprintf("%.2f",(($maxAllowedProcessRunTime-$diffRunTime)/60));
    #sprintf("%.3f", $number);
    if($diffRunTime <= $maxAllowedProcessRunTime)
    {
    	printDebugLine("$func: Remaining awake time before terminating => $remainingTimeInMinutes minutes") if($DEBUG);
    	return 0;
    } else {
    	printInfoLine("$func: Process has exceeded MAX_ALLOW_RUNTIME => \$diffRunTime = $diffRunTime ,");
    	printInfoLine("$func: \$maxAllowedProcessRunTime => $maxAllowedProcessRunTime ! Terminating once the post processing process is completed...");
    	return 1;
    }
}
sub checkDir(){
	my ($dir) = @_;
	#---Check log directory
	if (! -e $dir) {
		if (! mkdir($dir) ) {
			print("ERROR: Failed to create $dir directory. Exiting");
			exit (1);
		}
	} elsif (! -w  $dir) {
		my $mode = 0766;
		chmod $mode,$dir;
	}	
}
#===================== END OF FILE =============================================

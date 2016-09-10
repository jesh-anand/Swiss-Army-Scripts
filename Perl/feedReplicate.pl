#!/usr/local/bin/perl
#==========================================================================
# Name                  : feedReplicate.pl
# Author				: yepchoon.wearn@bt.com
#--------------------------------------------------------------------------
# Description			: This code is to replicate Yukon IL2S EMS feed with updated time
# Code Version			: 1.0
# Release Date			: 19-Jun-2015
#==========================================================================
# Modified Date			:
# Description 			: 
# Author				: 
#=========================================================================


use strict;

my $BASE_PATH;

BEGIN
{
	#--- Check if ENV is sourced ---
	if(exists $ENV{BASE_PATH})
	{
		$BASE_PATH =  $ENV{BASE_PATH};
		# Append a / at the End of installPath, if the user missed it then add it.
		if($BASE_PATH !~ /\/$/)
		{
			$BASE_PATH = "$BASE_PATH/";
		}
		#--- Now Check Correctness of path in ENV ---
		if(! -e $BASE_PATH)
		{
			print "ERROR: $BASE_PATH Not exists!!\nPlease Enter Correct Path in ENV and source it Again\n\n";
			exit 1;
		}
	}
	else
	{
		print "ERROR : Please ensure the BASE_PATH is configure and Run the Script\n";
		exit 1;
	}
}


#---Directory Paths
my $LOG_DIR      	= $BASE_PATH . "logs/";
my $TEMP_DIR      	= $BASE_PATH . "temp/";
my $LOOKUP_DIR      = $BASE_PATH . "lookup/";
my $OUTPUT_DIR      = $BASE_PATH . "output/";

#ddmmyy
my $timestamp		= $ARGV[0];

&main($timestamp);

sub main
{
	
	my ($timestamp) = @_;
	
	my $func = 'main';
	
	&writeLog("$func : Processing $timestamp.");

	opendir DIR, $LOOKUP_DIR or die "cannot open dir $LOOKUP_DIR: $!";
	my @file= readdir DIR;
	closedir DIR;

	my $dd = substr($timestamp,0,2);
	my $mm = substr($timestamp,2,2);
	my $yy = substr($timestamp,4,2);

	&writeLog("$func : DD: $dd | MM: $mm | YY : $yy.");

	if (scalar @file == 1) {
		foreach(@file) {
			next if ($_ =~ m/^\./);
			&replicateHours($_,$dd,$mm,$yy);
		}
	} else {
		&writeLog("$func : Please insert 1 file only.");
	}

	


}

sub replicateHours
{
	my ($feedFile,$dd,$mm,$yy) = @_;
	
	my $func = 'replicateHours';


	
	&writeLog("$func : Processing $feedFile.");
	
	my $cpCmd = qq@cp $LOOKUP_DIR/$feedFile $TEMP_DIR/$feedFile@;
	system($cpCmd);
	
	my $gunzipCmd = qq@gunzip $TEMP_DIR/$feedFile@;
	system($gunzipCmd);
	
	my $tarFilename = $feedFile;
	$tarFilename =~ s/\.gz$//g;
	
	&writeLog("$func : TAR filename: $tarFilename.");
	
	my $tarCmd = qq@cd $TEMP_DIR && tar -xf $TEMP_DIR/$tarFilename@;
	system($tarCmd);
	
	my $rmtarCmd = qq@rm $TEMP_DIR/$tarFilename@;
	system($rmtarCmd);
	
	#read each file
	opendir DIR, $TEMP_DIR or die "cannot open dir $TEMP_DIR: $!";
	my @file= readdir DIR;
	closedir DIR;


	# Viewing the files

	# ECI_OYS953A111_BAADAB_IL2SSYS_20_06_2015_01_00
		foreach(@file)	{

			next if ($_ =~ m/^\./);
			&writeLog("$func : processing $_.");
			my $oriFilename = $_;
			my @filepart	= split(/\_/,$oriFilename);
			$filepart[4]	= $dd;
			$filepart[5]	= $mm;
			$filepart[6]	= '20'.$yy;

			# Copy EMS Feed hourly
			for my $i ("00" .. "23") {
				# prajesh - replace with the with a newer hour
				$filepart[7] = $i;
				my $newFilename = join("_",@filepart);
				my $cpCmd = qq@cp $TEMP_DIR/$oriFilename $TEMP_DIR/$newFilename@;
				system($cpCmd);

			}
			

			

			# processing ECI_OYS953A111_BAADAB_IL2SSYS_15_06_2015_22_00.
		 	# New filename : ECI_OYS953A111_BAADAB_IL2SSYS_16_06_2015_22_00
		 	# Ori GZ filename : ECI_OYS953A111_IL2SSYS_150615_2200.tar.
		 	# New GZ filename : ECI_OYS953A111_IL2SSYS_160615_2000.tar

			
			
			&writeLog("$func : New filename : $newFilename.");
			
			my $mvCmd = qq@mv $TEMP_DIR/$oriFilename $TEMP_DIR/$newFilename@;
			system($mvCmd);
	} 

	
	
	my @gzFileParts = split(/\_/,$tarFilename);
	$gzFileParts[3] = $dd . $mm . $yy;
	my $gzFilename = join("_",@gzFileParts);
	&writeLog("$func : Ori GZ filename : $tarFilename.");
	&writeLog("$func : New GZ filename : $gzFilename.");
	
	my $tarCmd = qq@cd $TEMP_DIR && tar -cvf $gzFilename *@;
	system($tarCmd);
	
	my $gzipCmd = qq@gzip $TEMP_DIR/$gzFilename@;
	system($gzipCmd);
	
	my $mvCmd = qq@mv $TEMP_DIR/${gzFilename}.gz $OUTPUT_DIR@;
	system($mvCmd);
	
	my $rmTempCmd = qq@rm $TEMP_DIR/*@;
	system($rmTempCmd);
	
	&writeLog("$func : Finish processing $feedFile.");
}


sub createLog {

	my $logDir    = $_[0];
	my $setupName = $_[1];
	my $func = "createLog";
	my @timeNow  = localtime(time);
	my $tyear    = $timeNow[5] + 1900;
	my $tmonth   = $timeNow[4] + 1;
	my $tday     = $timeNow[3];
	my $thour    = $timeNow[2];
	my $tmin     = $timeNow[1];
	my $tsec     = $timeNow[0];
	my $thisDate = sprintf( "%04d_%02d_%02d", $tyear, $tmonth, $tday );

	my $logFile = $logDir . $setupName . "_" . $thisDate . ".log";

	if ( open( LOG, ">>$logFile" ) ) {
		&writeLog("File: $logFile");
		&writeLog("Description: Starting $setupName Process!");
	}
	else {
	#	print "ERROR [" . $func . "] : Unable to create Log file handler at $logDir directory with $logFile file name!\n";
	}
}


sub writeLog
{
	my ($logMsg) = @_;

	# Current time stamps; l - log
	my @timeNow  = localtime(time);
	my $lyear    = $timeNow[5] + 1900;
	my $lmonth   = $timeNow[4] + 1;
	my $lday     = $timeNow[3];
	my $lhour    = $timeNow[2];
	my $lmin     = $timeNow[1];
	my $lsec     = $timeNow[0];
	my $thisTime = sprintf( "%04d/%02d/%02d %02d:%02d:%02d",
							$lyear, $lmonth, $lday, $lhour, $lmin, $lsec );

	print "$thisTime | $logMsg \n";
	# print LOG "$thisTime | $logMsg \n";
}

sub closeLog {
	close LOG;
}





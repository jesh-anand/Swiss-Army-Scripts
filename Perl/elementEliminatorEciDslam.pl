#!/usr/local/bin/perl
#==========================================================================
# Name                  : extractServiceLines.pl
# Author				: prajesh.ananthan@bt.com
#--------------------------------------------------------------------------
# Description			: This code extracts element that exist in NPM from NGY feed
# Code Version			: 2.0
# Release Date			: 10-January-2016
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
my $LOG_DIR      		= $BASE_PATH . "logs/";
my $TEMP_DIR      		= $BASE_PATH . "temp/";
# my $LOOKUP_DIR      	= $BASE_PATH . "lookup/";
#-- Insert Live Feed directory for lookup
my $LOOKUP_DIR      	= "/data/Yukon/Live_Feed/Eci/10_01_2016/Dslam";
my $PROCESS_DIR     	= $BASE_PATH . "process/";
# my $OUTPUT_DIR      	= $BASE_PATH . "output/";
my $OUTPUT_DIR      	= "/data/Yukon/npm_huawei_feed_simulator/output/Huawei_IL2S/batch_files/";

my $elementConfig		= $ARGV[0];

&main($elementConfig);

sub main
{
	
	my ($elementConfig) = @_;
	
	my $func			= 'main';
	my $tempElt 		= '';

	my $elementList		= &getElementList($elementConfig);

	&writeLog("$func : Number of elements to be extracted -> " . scalar @$elementList);

	opendir DIR, $LOOKUP_DIR or die "cannot open dir $LOOKUP_DIR: $!";
	my @file = readdir DIR;
	closedir DIR;

	if (scalar @file > 0) {
		foreach(@file) {
			next if ($_ =~ m/^\./);
			next if ($_ =~ m/batch_feeds/);
			&filterElements($_, $elementList);
		}
		&writeLog("$func : Output files can be found here -> $OUTPUT_DIR")
	} else {
		&writeLog("$func : No files found inside $LOOKUP_DIR");
	}
}


sub getElementList 
{
	my $func 		= 'getElementList';
	my $path 		= shift;
	my $elements 	= '';

	if (open (ELT , '<', $elementConfig)) {
		while (my $line = <ELT>) {
			chomp($line);
			$elements = $line;			
		}
	} else {
		&writeLog("$elementConfig not found!");
	}
	close (ELT);
	my @eltList = split(',', $elements);

	return \@eltList;
}


sub filterElements
{
	my ($feedFile,$elementList) = @_;
	
	my $func = 'filterElements';

	&writeLog("$func : Processing $feedFile.");
	
	my $mvCmd		= qq@cp $LOOKUP_DIR/$feedFile $TEMP_DIR/$feedFile@;
	system($mvCmd);
	

	my $gunzipCmd	= qq@gunzip $TEMP_DIR/$feedFile@;
	system($gunzipCmd);
	
	my $tarFilename = $feedFile;
	$tarFilename =~ s/\.gz$//g;
	
	my $tarCmd		= qq@cd $TEMP_DIR && tar -xf $TEMP_DIR/$tarFilename@;
	system($tarCmd);
	
	opendir DIR, $TEMP_DIR or die "cannot open dir $TEMP_DIR: $!";
	my @file = readdir DIR;
	closedir DIR;


	foreach my $fileName (sort @file) {
		foreach my $prefix (@$elementList)	{
			next if ($fileName =~ m/^\./);
			if ($fileName =~ /$prefix/) {
				my $mvCmd = qq@mv $TEMP_DIR/$fileName $PROCESS_DIR@;
				system($mvCmd);
			} 
		}	
	}

	my $rmtarCmd	= qq@rm $TEMP_DIR/*@;
	system($rmtarCmd);
	
	my $tarCmd = qq@cd $PROCESS_DIR && tar -cf $tarFilename *@;
	system($tarCmd);
	
	my $gzipCmd = qq@gzip $PROCESS_DIR/$tarFilename@;
	system($gzipCmd);
	
	my $mvCmd = qq@mv $PROCESS_DIR/${tarFilename}.gz $OUTPUT_DIR@;
	system($mvCmd);
	
	my $rmprocCmd = qq@rm $PROCESS_DIR/*@;
	system($rmprocCmd);
	
	&writeLog("$func : Finish processing $feedFile.");
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
}
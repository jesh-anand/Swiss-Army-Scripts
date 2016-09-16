#!/usr/local/bin/perl
#==========================================================================
# Name                  : FeedCompare.pl
# Author				: yepchoon.wearn@bt.com
#--------------------------------------------------------------------------
# Description			: This code compare the UII generated feed with feed generated from 
#						  ODI interface 
# Code Version			: 1.0
# Release Date			: 23-Oct-2014
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
my $DETAIL_DIR      = $BASE_PATH . "detail/";
my $LOOKUP_DIR      = $BASE_PATH . "lookup/";

my $SPLIT_CHAR		= 'Ç';


&extractMissing();

sub extractMissing
{

	opendir DIR, $DETAIL_DIR or die "cannot open dir $DETAIL_DIR: $!";
	my @file= readdir DIR;
	closedir DIR;

	foreach(@file)
	{
		next if ($_ =~ m/^\./);
		my %neIdMap = ();
		&readMissingNeId($_,\%neIdMap);
		&extractIPs($_,\%neIdMap);
		&dumpToFile($_,\%neIdMap);
	}

}

sub readMissingNeId
{
	my ($detailFeed,$neIdMap) = @_;
	
	my $func = 'readMissingNeId';
	
	&writeLog("$func : Processing $detailFeed.");
	
	if( open(FEED,$DETAIL_DIR.'/'.$detailFeed) )
	{
		while (my $line = <FEED>)
		{
			chomp($line);
			
			#&writeLog("$func : Line [$line]");
			
			my @fieldAry 	= split(/\|/,$line);
			my $neid		= $fieldAry[3];
			my $cat			= $fieldAry[-3];
			my $result		= $fieldAry[-2];
			 
			if( $result =~ /^MISSING$/ && $cat !~ /^IGNORE/ )
			{
				#&writeLog("$func : NEID: $neid, CAT: $cat, RESULT: $result");
				$neIdMap->{$neid} = '';
			}
		}
		close(FEED);
	}
	
	my $size = scalar(keys %{$neIdMap});
	&writeLog("$func : Finish processing $detailFeed. Total $size NE_ID found.");
}

sub extractIPs
{
	my ($sourceFeed,$neIdMap) = @_;
	
	my $func = 'extractIPs';
	my %headerHash 	= {};
	my $filename 	= 'SOURCE_'.$sourceFeed;
	
	
	&writeLog("$func : Processing $filename.");
	
	if( open(FEED,$TEMP_DIR.'/'.$filename) )
	{
		while (my $line = <FEED>)
		{
			chomp($line);
			
			#&writeLog("$func : Line [$line]");
			
			if($line =~ /^10/ ) 
			{
				#&writeLog("$func : Line [$line]");
				my @recArray 	= split(/$SPLIT_CHAR/,$line);
				my $neid		= $recArray[$headerHash{BT_NE_ID}];
				my $ip			= $recArray[$headerHash{BT_IP_ADDRESS}];
				if( exists $neIdMap->{$neid} )
				{
					&writeLog("$func : Matched [$neid] => $ip");
					$neIdMap->{$neid} = $ip	
				}
			}
			elsif ( $line =~ /^02/ )
			{
				#&writeLog("$func : Line [$line]");
				# read the header and store into an array reference
				my @headerArray = split(/$SPLIT_CHAR/,$line);
				my $size = scalar @headerArray;
				#&writeLog("$func : FIELDS: $size.");
				for(my $i=0; $i<scalar(@headerArray);$i++)
				{
					$headerHash{$headerArray[$i]} = $i;
				}
				
			}
		}
		close(FEED);
	}
	
	&writeLog("$func : Finish processing $filename.");
}


sub dumpToFile
{
	my ($feedName,$neIdMap) = @_;
	
	my $func = 'dumpToFile';
	my %headerHash 	= {};
	my $filename 	= 'IP_'.$feedName;
	
	if( open(FEED,'>'.$LOOKUP_DIR.'/'.$filename) )
	{
		foreach my $neId (keys %{$neIdMap} )
		{
			if( $neIdMap->{$neId} ne '' )
			{
				print FEED $neIdMap->{$neId}."\n";
			} 
		}
		close(FEED);
		
		if( -z $LOOKUP_DIR.'/'.$filename )
		{
			unlink $LOOKUP_DIR.'/'.$filename
		}
		else
		{
			my $shFilename = 'run'.$feedName.'.sh';
			&writeLog("$func : writing $shFilename..");
			if( open(FEED,'>'.$LOOKUP_DIR.'/'.$shFilename) )
			{
				print FEED "#!/bin/bash\n";
				print FEED "$BASE_PATH/runCompleteFeed.sh -i $LOOKUP_DIR$filename -o $LOOKUP_DIR$feedName.dat\n";
				close(FEED);
				system("chmod +x \"$LOOKUP_DIR$shFilename\"");
			}
		}
		
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
}





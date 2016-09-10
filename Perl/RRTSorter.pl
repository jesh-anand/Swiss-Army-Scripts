# Prajesh Ananthan 2016
# Sorts XML files by some unique pattern

use warnings;
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

my $LOOKUP_DIR     	= "/apps/LIVE_INTERFACE_FEEDS/RRT/FTTC/";

#-- List of directories
my $FTTC_CVLAN_DIR	= $BASE_PATH . "/FTTC_CVLAN/";
my $FTTC_DSLAM_DIR	= $BASE_PATH . "/FTTC_DSLAM/";
my $FVA_CVLAN_DIR	= $BASE_PATH . "/FVA_CVLAN/";
my $FTTP_CVLAN_DIR	= $BASE_PATH . "/FTTP_CVLAN/";
my $HLOG_QLN_DIR	= $BASE_PATH . "/HLOG_QLN/";

&main();

sub main {
	my $func			= 'main';
	
	opendir DIR, $LOOKUP_DIR or die "cannot open dir $LOOKUP_DIR: $!";
	my @file = readdir DIR;
	closedir DIR;
	
	&writeLog("$func : Number of files listed -> " . scalar @file);
	
	foreach(@file) {
		next if ($_ =~ m/^\./);
		&readFile("$LOOKUP_DIR/$_");
	}
	&writeLog("$func : Finished allocating files.");
}

sub readFile {
	my $func 		= 'readFile';
	my $file		= shift;
	my $moveCmd		= '';
	
	open my $fh, $file or die "$func: Could not open $file: $!";
	while( my $line = <$fh>)  {   
	   	if ($line =~ /\<action\>/) {
	   		if ($line =~ /FTTCDLMRequest/) {
	   			$moveCmd = qq@mv $file $FTTC_DSLAM_DIR@;
	   		} elsif ($line =~ /FTTCCVLANRequest/) {
	   			$moveCmd = qq@mv $file $FTTC_CVLAN_DIR@;
	   		} elsif ($line =~ /HLOGQLNRequest/) {
	   			$moveCmd = qq@mv $file $HLOG_QLN_DIR@;
	   		} 
	   	}
		system($moveCmd);
	}
	close $fh;
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


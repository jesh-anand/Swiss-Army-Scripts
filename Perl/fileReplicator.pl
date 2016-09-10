use strict;
use warnings;
use File::Copy qw(copy);

my $BASE_PATH	= "C:/Users/608156369/desktop/Yukon_Dev/myYukonScripts/Replicate_Orbit_Hourly_Feeds";

&main();

sub main {

	my $maxCollector 	= 2;
	my $maxHour			= 23;
	my $baseFilePath	= $BASE_PATH . "/base/C1_000000_2015_11_22";
	my $pattern 		= "C{number}_{hour}0000_2015_11_22";


	if (-e $baseFilePath) { 
		for (my $coll = 1; $coll <= $maxCollector; $coll++) {
			for (my $hour = 0; $hour <= $maxHour; $hour++) {
				my $file 			= &replicateFile($pattern, $coll, sprintf("%02d", $hour));
				copy $baseFilePath, $file;
				&writeLog("DEBUG | File: " . $file);
			}
		}
	} else {
		&writeLog("ERROR | File path does not exist: $baseFilePath");
	}
}

sub replicateFile {

	my ($pattern, $coll, $hour)	= @_;

	my $file 		= "";
	$pattern		=~ s/{number}/$coll/g;
	$pattern		=~ s/{hour}/$hour/g;
	$file			= "C:/Users/608156369/workspace/NPMCapability/data/npm-feed-output/custom/orbit/lr/output/$pattern";

	return $file;
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
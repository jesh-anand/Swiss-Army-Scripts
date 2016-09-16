#!/usr/local/bin/perl

package Log;

use strict;
use IO::Handle;

#------------------------------------------------------------------------------#
# Name          : startLog
# Purpose       : Assigns Handle to Log file
# Author        : Harish Kumar
# Arguments     : None
# ReturnValue   : None
#------------------------------------------------------------------------------#

my $ENABLE_PRINT_TO_CONSOLE=0;

sub startLog
{
	my($logDirPath) 	= shift;
	my $confFilePath 	= shift;
	my $logFilename		= shift;
	my $printToConsole  = shift;
	my $func 			="startLog";
	my @timeData 		= localtime(time);
	
	if( defined $printToConsole ) {
		$ENABLE_PRINT_TO_CONSOLE = $printToConsole;
	}
	
	#---Log file timestamp
	my ($logday,$logmonth,$logyear);
	$logday 	= $timeData[3];
	$logmonth 	= $timeData[4]+1;
	$logyear 	= $timeData[5]+1900;
	my $temp 	= $logFilename . "." . sprintf("%04d%02d%02d",$logyear,$logmonth,$logday);
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
		&printInfoLine("[LOG STARTED]: FileName: $logFile");
		&printInfoLine("[CONFIG_FILE_PATH]: $confFilePath");     
	}
	else
	{
		print ("[ERROR]: Either $logDirPath is not existing or No write access to $logDirPath! Log File will not be created!\n");
	}
	
}
#-----------------------------End of startLog----------------------------------#

#------------------------------------------------------------------------------#
# Name          : closeLog
# Purpose       : Releases Log File Handle
# Author        : Harish Kumar
# Arguments     : None
# ReturnValue   : None
#------------------------------------------------------------------------------#
sub closeLog
{
	&printInfoLine("[END]: End of log file");
	close ALOG;
}
#-----------------------------End of closeLog----------------------------------#

#------------------------------------------------------------------------------#
# Name          : writeLog
# Description   : To print Log message to log file
# Author        : Harish Kumar
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
	ALOG->autoflush();
	print "$thisTime | $logMsg \n" if( $ENABLE_PRINT_TO_CONSOLE );
}
#-----------------------------End of writeLog----------------------------------#

#============================================================== 
# Name          	: printInfoLine 
# Description   	: To print Log message to log file 
# Input         	: Log message string 
# Output            : An entry in log file 
# Author            : Brandon, Harish Kumar
# Last updated  	: 25 Feb 2016 
#============================================================== 
sub printInfoLine 
{ 
    my ($logMsg) = @_; 
    &writeLog("INFO  | $logMsg");
}
#============================================================== 
# Name          	: printErrorLine 
# Description   	: To print ERROR log message to log file 
# Input         	: Log message string 
# Output            : An entry in log file 
# Author            : Brandon, Harish Kumar
# Last updated  	: 25 Feb 2016 
#============================================================== 
sub printErrorLine
{ 
    my ($logMsg) = @_; 
    &writeLog("ERROR | $logMsg");
}
#============================================================== 
# Name          	: printDebugLine 
# Description   	: To print Debug log message to log file 
# Input         	: Log message string 
# Output            : An entry in log file 
# Author            : Brandon, Harish Kumar
# Last updated  	: 25 Feb 2016 
#============================================================== 
sub printDebugLine
{ 
    my ($logMsg) = @_; 
    &writeLog("DEBUG | $logMsg");
}

return 1;
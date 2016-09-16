#=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
#
#	Commons.pl
#
#-------------------------------------------------------------------------------------
# File Name		: Commons.pl
# Author		: yepchoon.wearn@bt.com
# Date			: 04/03/2016
# Version		: v1.0 (04/03/2016)
# Copyright(c)	: BT Global Technology (M) Sdn Bhd
#-------------------------------------------------------------------------------------
# Description	: Placeholder for common used subroutine for perl.
#-------------------------------------------------------------------------------
# Modification History 
#---------------------
# Update : [Version] 	[Date] 			[Author] 				[Description]
# 			1.0			04/03/2016 		yepchoon.wearn@bt.com	- Move readConf and isProcessRunning subroutines
#=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
#!/usr/local/bin/perl

package Commons;

use strict;
use FindBin '$Bin';
use lib "$Bin/lib";
use Constants;
use Log;

#======================================================================================
# Name 		    : readConf
# Description	: Read and assign the configuration value from .conf specific to the
#				  parameters initialized at global.
# Input		    : -
# Output	    : -
# Author	    : Harish Kumar
# Global Var	: -
# Date		    : 25 Feb 2016
#======================================================================================

sub readConf
{
	my ($confFilePath,$confHash,$debug) 	= @_;
	my $func = "readConf";
	
	if (open(CONF,"<", $confFilePath))
	{
		foreach my $Line (<CONF>) {
			if ( $Line !~ /^#/ && $Line =~ /\w+/ ) {
				chomp($Line);
				$Line =~ s/^\s|\s+$//;
				$Line =~ s/\s*=\s*/=/g;
				my ($param,$value) = split(/=/,$Line);
				$confHash->{$param} = $value;
				Log::printInfoLine("$func: $param => $value") if ($debug);
			}
		}
		close (CONF);
	} else {
		Log::printErrorLine("$func: confPath [" . $confFilePath . "] does not exist!");
	}
}
#-----------------------------End of readConf----------------------------------#

#======================================================================================
# Name 		    : isProcessRunning
# Description	: To check if there is any process running by the time of this execution
# Input		    : -
# Output	    : Create lock file to avoid conflict with another process
# Author	    : Harish Kumar
# Global Var	: -
# Date		    : 26 Feb 2016
#======================================================================================
sub isProcessRunning
{
	my ($processlockFile) 	= @_;
	my $func = "isProcessRunning";
	
	if(-e $processlockFile)
	{
		my $pid = `cat $processlockFile`;
		chomp($pid);
		my $cmd = "ps -p $pid";
		my @res = `$cmd`;
		if ($#res==0) {
		   #process not there, remove the lock file
		   unlink $processlockFile or Log::printErrorLine("$func: Could not unlink $processlockFile $!");
		} else {
	    	return Constants::TRUE;
		}
	} 
	return Constants::FALSE;
}
#-----------------------------End of isProcessRunning----------------------------------#

#======================================================================================
# Name 		    : createProcessLockFile
# Description	: To check if there is any process running by the time of this execution
# Input		    : -
# Output	    : Create lock file to avoid conflict with another process
# Author	    : Harish Kumar
# Global Var	: -
# Date		    : 26 Feb 2016
#======================================================================================
sub createProcessLockFile
{
	my $func = "createProcessLockFile";
	
	my ($processlockFile,$curPid) 	= @_;
	
	if( open(LOCKFILE,">$processlockFile") )
	{
		print LOCKFILE $curPid;
		close(LOCKFILE);
		Log::printInfoLine("$func : Main process lock is created with currPid $curPid => $processlockFile"); 
		return Constants::TRUE;
	}
	else
	{
		Log::printErrorLine("$func : Fail to create $processlockFile $!");
	}
	return Constants::FALSE;
}
#-----------------------------End of isProcessRunning----------------------------------#

#======================================================================================
# Name 		    : deleteOldFiles
# Description	: Delete files in a folder based on the specified retention period in second
# Input		    : $dirPath:Directory to check for files deletion.
#				  $retentionPeriodInMin: Retention period in minutes
# Output	    : -
# Author	    : Harish Kumar
# Global Var	: -
# Date		    : 26 Feb 2016
#======================================================================================
sub deleteOldFiles 
{
	my $func = "deleteOldFiles";
	
	my ( $dirPath, $retentionPeriodInHour ) = @_;
        
	if( opendir (DIRH,$dirPath) )
	{	
		my $currentTime = time;	
		foreach my $file ( readdir(DIRH)) 
		{
			#---Excluding directory symbol
			next if (  $file =~ /^\.|^\.\./ );
			my $absFileName = $dirPath.$file;
			#---File creation time stamp
			my $statTime = (stat($absFileName))[9];

			#---Deleting all files which are older than retaintion period
			if ( $retentionPeriodInHour && ($currentTime - $statTime) > ($retentionPeriodInHour * 60) ) 
			{
				my $cmd=qq@rm -rf $absFileName @;
				Log::printErrorLine("$func : Unable to delete old file: $absFileName") if(system($cmd) != 0);
			}       	        
		}
		closedir DIRH;
	}
	else
	{
		Log::printErrorLine("$func : Could not open the directory $dirPath for cleanup : $!");
	}
}
#-----------------------------End of deleteOldFiles----------------------------------#

#======================================================================================
# Name 		    : isStringEmpty
# Description	: Check if a given string is null or only contains space, tab (\t)
#				  , carriage-return (\r), new line (\n) or form-feed (\f)
# Input		    : $str:String to check.
# Output	    : True if string is empty otherwise false.
# Author	    : Harish Kumar
# Global Var	: -
# Date		    : 26 Feb 2016
#======================================================================================
sub isStringEmpty 
{	
	my $func = "isStringEmpty";
    my ( $str ) = @_;
    
    if( not defined $str ) {
    	return Constants::TRUE;
    } elsif ( $str =~ /^\s*$/ ) {
    	return Constants::TRUE;
    } else {
    	return Constants::FALSE;
    }
}
#-----------------------------End of isStringEmpty----------------------------------#

return 1;
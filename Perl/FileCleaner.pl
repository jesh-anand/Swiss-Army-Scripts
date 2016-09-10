#!/usr/bin/perl

##
# Temporary and archived files cleaner for ALU5620 SAM adaptor
# @author : Prajesh Ananthan
#
# 2014 Aug 01#
##

use strict;
use warnings;
use Time::Local;
use File::Basename;
use Data::Dumper;

# variable declaration
my $basePath   = $ENV{BASE_PATH};
my $configFile = $ARGV[0];
my $logLevel   = 1;
my $appName	= "FileCleaner";
my $logDir	 = $basePath."/log/";
my %configHash = ();
my @profiles;

# main
&initLogger();
&readConfig($configFile);
&initProfile();

foreach my $profile (@profiles) {
	&writeLog(1, " ");
	&writeLog(1, "Running archive for profile - $profile");
	&archiveTarget($profile);
	&cleanupArchive($profile);
	&writeLog(1, "Finished processes archive for profile - $profile");
}


##
# Initialize profiles
##
sub initProfile {
	if (exists $configHash{'profile'} && $configHash{'profile'} !~ /^\s*$/ ) {
		@profiles = split ( /\|_\|/, $configHash{'profile'} );
	}
}


##
# Archive files from target path based on retention period in config file
##
sub archiveTarget {
	
	my $profile = shift;
	
	if (exists $configHash{$profile . '.archive.target'} 
		&& exists $configHash{$profile . '.archive.folder'}
		&& exists $configHash{$profile . '.archive.retention'}) {
		
		return if ($configHash{$profile . '.archive.target'} eq '');
		return if ($configHash{$profile . '.archive.folder'} eq '');
		return if ($configHash{$profile . '.archive.retention'} eq '');
		
		
		my $target = $configHash{$profile . '.archive.target'};
		my $folder = $configHash{$profile . '.archive.folder'};
		my $retention = $configHash{$profile . '.archive.retention'};
		my $currentTime = time;
		
		if (!-e $folder) {
			mkdir $folder;
		}
		
		opendir(DIR, $target);
		my @files = grep(/^[^\.]/, readdir(DIR));
		closedir(DIR);
		
		chdir($target);
		foreach my $file (@files) {
			my $lastModified = (stat($file))[9];
			&writeLog(2, $file."\n".$currentTime."\n".$lastModified."\n".$retention."\n".($currentTime - $lastModified));
			if ($currentTime - $lastModified > $retention) {
				&writeLog(1, "moving $file to archive folder");
				#system(qq@mv $file $folder@);
			}
		}
	}
}

##
# Delete old archive files based on the target folder and retention period in config file
##
sub cleanupArchive {
	
	my $profile = shift;
	
	if (exists $configHash{$profile . '.archive.folder'} 
		&& exists $configHash{$profile . '.purge.retention'}) {
	
		return if ($configHash{$profile . '.archive.folder'} eq '');
		return if ($configHash{$profile . '.purge.retention'} eq '');
	
		my $folder = $configHash{$profile . '.archive.folder'};
		my $retention = $configHash{$profile . '.purge.retention'};
		my $currentTime = time;
		
		opendir(DIR, $folder);
		my @files = grep(/^[^\.]/, readdir(DIR));
		closedir(DIR);
		
		chdir($folder);
		foreach my $file (@files) {
			my $lastModified = (stat($file))[9];
			&writeLog(2, $file."\n".$currentTime."\n".$lastModified."\n".$retention."\n".($currentTime - $lastModified));
			if ($currentTime - $lastModified > $retention) {
				&writeLog(1, "Deleting old archive $file");
				system(qq@rm -f $file@);
			}
		}
	}
}

##
# Load configuration properties from file
# @param configFile : path to configuration file
##
sub readConfig {
	my ($configFile) = @_;
	if (open(CONFIG, "<", $configFile)) {
		while (my $line = <CONFIG>) {
			
			if ( $line !~ /^#/ && $line =~ /\w+/ ) {
				chomp($line);
				my ($property, $value) = split('=', $line);
				$configHash{$property} = $value;
			}
		}
	}
	else {
		&writeLog(3, "Config file not found.");
	}
}

##
# Initialize logger
##
sub initLogger {
	if (!-e $logDir) {
		mkdir $logDir;
	}
	my $logFile = $logDir.$appName."_".getTimestamp(3).".log";
	
	if (open(LOGGER, ">>", $logFile)) {
	}
	else {
		print "Unable to initialize Logger";
	}
}

##
# Check log level is DEBUG
# @return : 1 if logLevel >= 2
##
sub isLogDebugEnabled {
	return ($logLevel >= 2);
}

##
# Check log level is INFO
# @return : 1 if logLevel >= 1
##
sub isLogInfoEnabled {
	return ($logLevel >= 1);
}

##
# Write log message into log file
# @param level : logLevel
# @param message : message to be printed
##
sub writeLog {
	my ($level, $message) = @_;
	if ($level == 1 && isLogInfoEnabled()) {
		print LOGGER getTimestamp(1)." [INFO] $message \n";
	}
	elsif ($level == 2 && isLogDebugEnabled()) {
		print LOGGER getTimestamp(1)." [DEBUG] $message \n";
	}
	elsif ($level == 3) {
		print LOGGER getTimestamp(1)." [ERROR] $message \n";
	}
}

##
# Generate timestamp base on required formats to be used
# @param mode : 1 for logging purpose, 2 for filename with time, 3 for filename without time
##
sub getTimestamp {
	my ($mode) = @_;
	my @timeNow  = localtime(time);
	my $lyear	= $timeNow[5] + 1900;
	my $lmonth   = $timeNow[4] + 1;
	my $lday	 = $timeNow[3];
	my $lhour	= $timeNow[2];
	my $lmin	 = $timeNow[1];
	my $lsec	 = $timeNow[0];
	
	if ($mode == 1) {
		return sprintf("%04d/%02d/%02d %02d:%02d:%02d", $lyear, $lmonth, $lday, $lhour, $lmin, $lsec);
	}
	elsif ($mode == 2) {
		return sprintf("%04d%02d%02d%02d%02d%02d", $lyear, $lmonth, $lday, $lhour, $lmin, $lsec);
	}
	elsif ($mode == 3) {
		return sprintf("%04d%02d%02d", $lyear, $lmonth, $lday);
	}
}

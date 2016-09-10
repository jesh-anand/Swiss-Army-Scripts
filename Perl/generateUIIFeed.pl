#!/usr/bin/perl -w
use strict;
use warnings;
use POSIX;

my $feedFile;

main(@ARGV);

#--------------------------------------START MAIN-------------------------------------#

sub main {
	
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
	
	$year += 1900;
	$mon += 1;
	my $todayDate = sprintf( "%04d%02d%02d%02d%02d%02d", $year, $mon, $mday, $hour, $min ,$sec);
	
	&createUIIFeed($todayDate);
	&writeFeedHeader($todayDate);
	&write59RecordHeader();
	&write59Record($ARGV[0]);
	&writeFeedTail($ARGV[0] + 3);
	&closeUIIFeed();
}

#-------------------------------------------END MAIN----------------------------------#

#======================================================================================
# Name			: createUIIFeed
# Description	: create uii feed file
# Input			: none
# Output		: create uii feed file 
# Author		: Edwin Liong
# Global Var	:
# Date			: 17 June 2014
#======================================================================================

sub createUIIFeed {

	my ($todayDate) = $_[0];
	$feedFile = "input/uii_svmp_v1_MNH_" . $todayDate . ".dat";

	if ( open( FEED, ">$feedFile" ) ) {
		print "Generating feed file : " . $feedFile . "\n";
	}
	else {
		print "ERROR: Unable to create feed file $feedFile \n ";
	}
}

#======================================================================================
# Name			: writeFeedHeader
# Description	: print feed header to uii feed
# Input			: today date in YYYYMMDD
# Output		: print feed header 
# Author		: Edwin Liong
# Global Var	:
# Date			: 17 June 2014
#======================================================================================

sub writeFeedHeader {
	my ($todayDate) = $_[0];
	my $runningNum =  int(rand(100));
	
	print FEED "01«UII_SVMP_Inventory_InitialLoad«" . $todayDate . "«" . $runningNum . "«V6.0\n";
}

#======================================================================================
# Name			: write59RecordHeader
# Description	: print record header to uii feed
# Input			: today date in YYYYMMDD
# Output		: print record header 
# Author		: Edwin Liong
# Global Var	:
# Date			: 17 June 2014
#======================================================================================

sub write59RecordHeader {
	print FEED "09«TRANS_TYPE«CREATION_TIMESTAMP«MSAN_TERMINATION«SUBSCRIBER_NUMBER«ISDN_INTERFACE_ID«ISDN_INTERFACE_TYPE\n";
}

#======================================================================================
# Name			: write59Record
# Description	: print record to uii feed
# Input			: records count
# Output		: print record
# Author		: Edwin Liong
# Global Var	:
# Date			: 17 June 2014
#======================================================================================

sub write59Record {
	my $digit = $_[0];
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
	my $timestamp = sprintf ( "%04d%02d%02d%02d%02d%02d", $year+1900,$mon+1,$mday,$hour,$min,$sec);
	
	my $count=0;
	while ($count<$digit)
	{
		my $randNum =  int(rand(999));
		my $randNum2 =  int(rand(99));
		my $randNum3 =  int(rand(99));
		print FEED "59«I«" . $timestamp . "«aln/" . $randNum . "/3810." . $randNum2 . ".0." . $randNum3 . "«" . $timestamp . $count . "««\n";
		$count++;
	}
}

#======================================================================================
# Name			: writeFeedTail
# Description	: print feed tail to uii feed
# Input			: records count
# Output		: print feed tail to uii feed
# Author		: Edwin Liong
# Global Var	:
# Date			: 17 June 2014
#======================================================================================

sub writeFeedTail {
	my $count = $_[0];
	
	print FEED "99«" . $count . "\n";
}

#======================================================================================
# Name			: closeUIIFeed
# Description	: close uii feed file
# Input			: none
# Output		: close uii feed file 
# Author		: Edwin Liong
# Global Var	:
# Date			: 17 June 2014
#======================================================================================

sub closeUIIFeed {
	close (FEED);
	
	# -- zip up the feed file
	
	my $cmd = "gzip ".$feedFile;
	print "gizp for $feedFile \n";
	system($cmd);
	
	print "done!\n";
}
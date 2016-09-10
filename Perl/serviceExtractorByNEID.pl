#!/usr/local/bin/perl
#==========================================================================
# Name                  : serviceExtractor.pl
# Author				: prajesh.ananthan@bt.com
#--------------------------------------------------------------------------
# Description			: This code extracts service id from the service inventory by service id
# Code Version			: 1.0
# Release Date			: 27-January-2016
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
my $ELEMENT_CONFIG		= "/apps/SERVICE_INVENTORY_DUMP/20_01_2016/conf/element_list.conf";

&main($ARGV[0],$ARGV[1]);

sub main
{
#	my ( $serviceInventory, $outputFile )		= @_;
	my $serviceInventory	= '/apps/SERVICE_INVENTORY_DUMP/20_01_2016/Service_inventory_Dump.csv';
	my $outputFile			= "/apps/SERVICE_INVENTORY_DUMP/20_01_2016/rrt_services";
	my $func							= 'main';
	my $openFileCmd						= "";
	my $zipFile 						= ".gz";
	my $elementList 					= &getElementList();
	
	&writeLog("$func : Number of elements to be extracted	-> " . scalar @$elementList);

	if ($serviceInventory =~ /$zipFile/) {
		$openFileCmd = "gunzip -cq $serviceInventory |";	
	} else {
		$openFileCmd = "<$serviceInventory";
	}	
	# BAABMH,/shelf=0/slot=1/port=5,OGHP01636439,CABLELINK ,15-NOV-11 09:32:47,,,,,774447114,BSKYB LLU ASSETS LIMITED
	if ( open( FH, $openFileCmd ) ) {
		while ( my $line = <FH> ) {
			chomp($line);
			foreach my $elementId (@$elementList) {
				my @column	= (split(",", $line, -1));
				my $neId	= $column[0];
				if ($neId eq $elementId) {
					# write to file
					 if ( open ( LH, ">>", "$BASE_PATH/" . $outputFile ) ) {
					 	&writeLog("Service_ID: $column[2]");
						print LH $column[2] . "\n";
				 	}
				}

				# if ( $line =~ /$serviceId/) {
				# 	if ( open ( LH, ">>", "$BASE_PATH/" . $modifiedFeed ) ) {
				# 		print LH $line . "\n";
				# 	}
				# }
			}
		}
	}
	close LH;
	close FH;
}



sub getElementList 
{
	my $func 		= 'getElementList';
	my $elements 	= '';
	my @services = ();
	
	if (open (ELT , '<', $ELEMENT_CONFIG)) {
		while (my $service = <ELT>) {
			chomp($service);
			push(@services, $service);
		}
	} else {
		&writeLog(" $ELEMENT_CONFIG file not found!");
	}
	close (ELT);
	
	return \@services;
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
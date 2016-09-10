#!/usr/local/bin/perl
#==========================================================================
# Name                  : serviceExtractor.pl
# Author				: prajesh.ananthan@bt.com
#--------------------------------------------------------------------------
# Description			: This code extracts NPM service lines from NGY interface feed
# Code Version			: 1.0
# Release Date			: 26-October-2015
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
my $SERVICE_CONFIG		= $BASE_PATH . "/SERVICE_ID_ECI.txt";

&main($ARGV[0],$ARGV[1]);

sub main
{
	my ( $feedFile, $modifiedFeed )		= @_;
	my $func							= 'main';
	my $openFileCmd						= "";
	my $zipFile 						= ".gz";
	my $serviceList 					= &getServiceList();
	
	&writeLog("$func : Number of services to be extracted	-> " . scalar @$serviceList);

	if ($feedFile =~ /$zipFile/) {
		$openFileCmd = "gunzip -cq $feedFile |";	
	} else {
		$openFileCmd = "<$feedFile";
	}	

	if ( open( FH, $openFileCmd ) ) {
		while ( my $line = <FH> ) {
			chomp($line);
			foreach my $serviceId (@$serviceList) {
				# TODO: Why is this process taking so long to execute?
				my $serviceIdNGY = (split(",", $line, -1))[1];
				&writeLog("Service ID -> " .$serviceIdNGY);
				if ($serviceIdNGY eq $serviceId) {
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



sub getServiceList 
{
	my $func 		= 'getServiceList';
	my $elements 	= '';
	my @services = ();
	
	if (open (ELT , '<', $SERVICE_CONFIG)) {
		while (my $service = <ELT>) {
			chomp($service);
			push(@services, $service);
		}
	} else {
		&writeLog(" $SERVICE_CONFIG file not found!");
	}
	close (ELT);
	
	return \@services;
}


sub getSortedFileList 
{	
	my @sortedfileList;
	my $func = "getSortedFileList";
	opendir DIR, "/apps/prajesh/SANDPIT/temp" or &writeLog("[" . $func  . "] : ERROR: Unable to open temp directory!");

	#-- Files from input directory
	my @fileList = readdir(DIR);

	foreach my $entry ( sort @fileList ) {
		next if ( $entry eq "." or $entry eq ".." );
		push( @sortedfileList, $entry );
	}
	close(DIR);
	return \@sortedfileList;
}


# sub chunkFiles {

# 	my $func	= 'chunkFiles';

#     open (FH, $INTERFACE_FEED) or die "Could not open source file. $!";

#     my $i 		= 0;
#     while (1) {
#         my $chunk = "";
       
#         open(OUT, ">../temp/sandpit_$i.csv") or die "Could not open destination file";
#         $i++;

#         if (!eof(FH)) {
#             read(FH, $chunk, 1000000);
#             print OUT $chunk;
#         } 
#         if (!eof(FH)) {
#             $chunk = <FH>;
#             print OUT $chunk;
#         }
#         close(OUT);
#         last if eof(FH);
#     }

#     &writeLog("$func : File chunking completed!");
# }



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
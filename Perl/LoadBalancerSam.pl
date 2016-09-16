#################################################################################################################
#################################################################################################################
#  Name             :  LoadBalancerSam.pl      		                                                          	#
#  Description      :  1) Read input files from SAM                                                           	#
#                      2) Identify the IP and check against the load balances history to determine which UBA  	#
#                         to process each element																#
#					   3) Copy the processed files to UBA either to own server itself or SCP to other server	#
#					   4) Cleanup and housekeep based on retention period										#
#                      5) Sends an E-mail if the No of elements that are already allocated to the particular 	#
#                         UBA reaches 80% of it's maximum limit specified in the Properties file for the        #
#                         Corresponding UBA.                                                                    #
#  Author           :  Edwin Law               			                                              			#
#################################################################################################################

#------------------------------------------------------------------
# Global data structure declariation and environment initialization
#------------------------------------------------------------------

#---To make the library files referenciable. Add this lib path to Perl's known lib path
BEGIN {
    $BASE_PATH = $ENV{BASE_PATH};
    if ( $BASE_PATH =~ /\w+/ ) {
        my $libPath = $BASE_PATH . "lib";
        push( @INC, $libPath );
    }
    else {
        print "Not able to determine application installpath. Exiting..\n";
    }
}

#------------------------------------------------------------------
#Additional Library Modules to be used in this application
#------------------------------------------------------------------
use Time::Local;
use warnings;
use strict;
use File::Copy;
use List::Util qw(min max);
use MIME::Lite;

my $BASE_PATH  = $ENV{BASE_PATH};
my $configFile = $ARGV[0];

#---Directory Paths
my $tempDir     = $BASE_PATH . "temp/";
my $logDir      = $BASE_PATH . "log/";
my $configDir   = $BASE_PATH . "config/";
my $historyFile = $BASE_PATH . "LoadBalancer_History.txt";

#------------------------------------------------------------------
# Global Variables
#------------------------------------------------------------------
my $PROCESS_ID    = $$;
my %CONF_HASH     = ();
my %UBA_LOAD_HASH = ();
my $DEBUG         = 1;
my $SEPERATOR     = "================================================================";
my $emailMessage  = "";
my $exceedThreshold = 0;

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#		Starting Main
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

#---Starting Log to print any message in specific log file under /log directory
&createLog( $logDir, "LoadBalancer" );

#---Reading Configuration files
&processReadConf($configFile);
$DEBUG = $CONF_HASH{DEBUG};

#---Populate the UBA load hash from configuration files
&loadUBAConfig();

#---Environment initialization and dir creates
&processEnvManagement();

#---Populate the UBA-IP from history file
&loadHistoryFile($historyFile);

#---Load balance the file content
&processingLoadBalancing();

#---Flushing the UBA-IP Mapping back to history file
&flushHistoryFile($historyFile);

#---Log File cleanup
&deleteOldLogFiles( $logDir, $CONF_HASH{LOG_RETENTION_DAY} );

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#  		End of Main
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

#==================================================================================
# Name 			: loadUBAConfig
# Description	: Load the IP-UBA allocation from the history file
# Input			: None.
# Output		: None.
# Author		: YepChoon
# Child Funtion	:
# Global Var	: $confHash
# Date			: 4 Jun 2014
#==================================================================================
sub loadUBAConfig {
    my $func = "loadUBAConfig";

    &writeLog("$SEPERATOR");
    &writeLog("\t\t\t Starting $func ");
    &writeLog("$SEPERATOR");

    #load list of DL
    my @dlList = split( /,/, $CONF_HASH{DL_LIST} );

    foreach my $dl (@dlList) {
        my $ubaListStr      = $CONF_HASH{ $dl . '.DL_UBA_LIST' };
        my $ubaMaxElemStr   = $CONF_HASH{ $dl . '.DL_UBA_MAX_ELT_LIMIT' };
        my $ubaThresholdStr = $CONF_HASH{ $dl . '.DL_UBA_THRESHOLD_PERCENTAGE' };

        if ( !defined $ubaListStr || $ubaListStr eq "" ) {
            &writeLog( "ERROR | $func: Missing configuration for " . $dl . '.DL_UBA_LIST' );
            exit(1);
        }
        if ( !defined $ubaMaxElemStr || $ubaMaxElemStr eq "" ) {
            &writeLog( "ERROR | $func: Missing configuration for " . $dl . '.DL_UBA_MAX_ELT_LIMIT' );
            exit(1);
        }
        if ( !defined $ubaThresholdStr || $ubaThresholdStr eq "" ) {
            &writeLog( "ERROR | $func: Missing configuration for " . $dl . '.DL_UBA_THRESHOLD_PERCENTAGE' );
            exit(1);
        }

        my @ubaList      = split( /\|_\|/, $ubaListStr );
        my @ubsMaxElem   = split( /\|_\|/, $ubaMaxElemStr );
        my @ubaThreshold = split( /\|_\|/, $ubaThresholdStr );

        if ( scalar @ubaList != scalar @ubsMaxElem ) {
            &writeLog(
                "ERROR | $func: Missmatch UBA count for " . $dl . '.DL_UBA_LIST' . ' and ' . $dl . '.DL_UBA_MAX_ELT_LIMIT' );
            exit(1);
        }
        if ( scalar @ubaList != scalar @ubaThreshold ) {
            &writeLog( "ERROR | $func: Missmatch UBA count for "
                  . $dl . '.DL_UBA_LIST' . ' and '
                  . $dl . '.DL_UBA_THRESHOLD_PERCENTAGE' );
            exit(1);
        }

        my $count = 0;
        foreach my $uba (@ubaList) {
            $UBA_LOAD_HASH{$uba}{DL_INDEX}        = $dl;
            $UBA_LOAD_HASH{$uba}{MAX_ELEMENT}     = $ubsMaxElem[$count];
            $UBA_LOAD_HASH{$uba}{THRESHOLD}       = $ubaThreshold[$count];
            $UBA_LOAD_HASH{$uba}{ELEMENT_COUNT}   = 0;
            $UBA_LOAD_HASH{$uba}{ELEMENT_IP_LIST} = ();

            &writeLog( "DEBUG | $func: Initial UBA_LOAD_HASH "
                  . '[ DL_INDEX:' . $UBA_LOAD_HASH{$uba}{DL_INDEX}
                  . ', UBA: ' . $uba
                  . ', MAX_ELEMENT: ' . $UBA_LOAD_HASH{$uba}{MAX_ELEMENT}
                  . ',THRESHOLD: ' . $UBA_LOAD_HASH{$uba}{THRESHOLD}
                  . ' ]' )
              if ($DEBUG);

            $count++;
        }

    }

    &writeLog("\t\t\t Finished $func ");
}

#==================================================================================
# Name 			: loadHistoryFile
# Description	: Load the IP-UBA allocation from the history file
# Input			: None.
# Output		: None.
# Author		: YepChoon
# Child Funtion	:
# Global Var	: $UBA_LOAD_HASH
# Date			: 4 Jun 2014
#==================================================================================
sub loadHistoryFile {
    my $func            = "loadHistoryFile";
    my ($historyFile)   = @_;

    &writeLog("$SEPERATOR");
    &writeLog("\t\t\t Starting $func ");
    &writeLog("$SEPERATOR");

    if ( -e $historyFile ) {
        if ( open( HIST, "<$historyFile" ) ) {
            while ( my $line = <HIST> ) {
                chomp($line);
                $line =~ s/^\s|\s+$//;
                $line =~ s/\s*=\s*/=/g;
                my ( $uba, $ipListStr ) = split( '=', $line );

                if ( exists $UBA_LOAD_HASH{$uba} ) {
                    my @ipAry = split( /\|/, $ipListStr );
                    $UBA_LOAD_HASH{$uba}{ELEMENT_COUNT} = scalar @ipAry;
                    foreach my $ip (@ipAry) {
                        $UBA_LOAD_HASH{$uba}{ELEMENT_IP_MAP}{$ip} = 1;
                    }

                }
                else {
                    &writeLog("WARN | $func: Found UBA-$uba in history file but not configuration file. Please check.");
                }
            }
            close(HIST);
        }
        else {
            &writeLog("ERROR | $func: Unable to open history file. Please check. | $historyFile");
            exit(1);
        }
    }
    else {
        &writeLog("WARN | $func: No history file found. | HistoryFile: $historyFile");
    }

    &writeLog("\t\t\t Finished $func ");
}

#==================================================================================
# Name 			: processingLoadBalancing
# Description	: Load the IP-UBA allocation from the history file
# Input			: None.
# Output		: None.
# Author		: YepChoon
# Child Funtion	:
# Global Var	: $UBA_LOAD_HASH
# Date			: 4 Jun 2014
#==================================================================================
sub processingLoadBalancing {
    my $func       = "processingLoadBalancing";
    my $fileList   = undef;
    my $lbInputDir = $BASE_PATH . $CONF_HASH{INPUT_DIR};

    &writeLog("$SEPERATOR");
    &writeLog("\t\t\t Starting $func ");
    &writeLog("$SEPERATOR");

    $fileList = &retrieveFileLists();

    if ( defined $fileList && scalar @$fileList > 0 ) {
        foreach my $file (@$fileList) {
            &writeLog("DEBUG | $func: Processing file:$file.") if ($DEBUG);
            my $result = &processSingleFile($file);
            if ( $result eq "SUCCESS" ) {
                &transferFile($file);
                unlink( $lbInputDir . $file );
            }
        }
    }
    else {
        &writeLog("INFO | $func: No file to be process in this run.");
    }

    &writeLog("\t\t\t Finished $func ");
}

sub retrieveFileLists {
    my $func       = "retrieveFileLists";
    my $lbInputDir = $BASE_PATH . $CONF_HASH{INPUT_DIR};
    my %fileHash   = ();
    my $fileCount  = 0;
    my @fileList   = ();

    &writeLog("DEBUG | $func: Scanning directory for input: $lbInputDir.")
      if ($DEBUG);

    opendir( DIR, $lbInputDir ) or die $!;

    while ( my $file = readdir(DIR) ) {
        &writeLog("DEBUG | $func: Checking file: $file.") if ($DEBUG);

        next
          unless ( $file =~ /^AccountingStats\_(\d+)\.csv$/
            || $file =~ /^InterfaceStats\_(\d+)\.csv$/
            || $file =~ /^SystemStats\_(\d+)\.csv$/ );

        my $epochTimeMili = $1;

        &writeLog("DEBUG | $func: File epoch: $epochTimeMili") if ($DEBUG);

        if ( !exists $fileHash{$epochTimeMili} ) {
            $fileHash{$epochTimeMili} = ();
        }
        push( @{ $fileHash{$epochTimeMili} }, $file );

        $fileCount++;
        &writeLog("DEBUG | $func: Added $file to processing list.") if ($DEBUG);
    }
    close(DIR);

    if ( $fileCount > 0 ) {
        foreach my $key ( sort ( keys(%fileHash) ) ) {
            &writeLog("DEBUG | $func: Pushing file with epoch: $key")
              if ($DEBUG);
            push( @fileList, @{ $fileHash{$key} } );
        }
    }

    &writeLog( "INFO | $func: Read $fileCount file(s) from the input directory for processing:" . $lbInputDir );

    return \@fileList;
}

sub processSingleFile {
    my $func         = "processSingleFile";
    my ($lbFile)     = @_;
    my $lbInputDir   = $BASE_PATH . $CONF_HASH{INPUT_DIR};
    my %resultMap    = ();
    my $fullFilepath = $lbInputDir . $lbFile;

    if ( !-e $fullFilepath ) {
        &writeLog( "ERROR | $func: EMS file not exists. | " . $fullFilepath );
        return "FAIL";
    }

    if ( open( INPUT, "<$fullFilepath" ) ) {
        #init the result map
        foreach my $uba ( keys %UBA_LOAD_HASH ) {
            $resultMap{$uba} = ();
        }

        # First line is header
        my $line = <INPUT>;
        chomp($line);

        my @headerAry    = split( /\|/, $line );
        my $lbFieldName  = $CONF_HASH{LOAD_BALANCER_HEADER};
        my $lbFieldIndex = -1;
        my $count        = 0;
        my $rowCount     = 0;
        my $prevLBField  = "";
        my $prevUBA      = "";

        foreach my $headerName (@headerAry) {

            &writeLog("DEBUG | $func: Header: $headerName") if ($DEBUG);

            if ( $lbFieldName eq $headerName ) {
                $lbFieldIndex = $count;
                last;
            }
            $count++;
        }

        if ( $lbFieldIndex < 0 ) {
            &writeLog( "ERROR | $func: Cannot find the matching header for load balancing. | Expected Header: " . $lbFieldName
                  . ", Line: " . $line );
            return "FAIL";
        }

        while ( $line = <INPUT> ) {
            chomp($line);
            $rowCount++;
            my $allocatedUba = "FAIL";
            my @fieldAry     = split( /\|/, $line );
            my $lbFieldVal   = $fieldAry[$lbFieldIndex];

            $lbFieldVal =~ s/^\s|\s+$//;

            if ( $prevLBField ne $lbFieldVal ) {

                $allocatedUba = &checkAllocatedUBA($lbFieldVal);
                if ( $allocatedUba eq "FAIL" ) {
                    $allocatedUba = &assignToIdleUBA($lbFieldVal);
                }
                $prevLBField = $lbFieldVal;
                $prevUBA     = $allocatedUba;
            }
            else {
                $allocatedUba = $prevUBA;
            }

            if ( $allocatedUba ne "FAIL" ) {
                #&writeLog("DEBUG | $func: Allocated line UBA. | Identifier: " . $lbFieldVal . ", UBA: ". $allocatedUba . " | line: " . $line ) if ($DEBUG);
                push( @{ $resultMap{$allocatedUba} }, $line );
            }
            else {
                &writeLog(
                    "ERROR | $func: Fail to allocate UBA for given line. | Identifier: " . $lbFieldVal . " | line: " . $line );
            }
        }
        close(INPUT);

        &writeLog("INFO | $func: Loaded $rowCount records from $lbFile.");

        my $writeResult = &writeContentToFile( \%resultMap, $lbFile, join( '|', @headerAry ) );

        return $writeResult;
    }
    else {
        &writeLog( "ERROR | $func: Fail to open EMS File. | File: " + $lbFile );
    }
    return "FAIL";
}

sub checkAllocatedUBA {
    my $func         = "checkAllocatedUBA";
    my ($lbFieldVal) = @_;
    my $allocatedUBA = "FAIL";

    foreach my $uba ( keys %UBA_LOAD_HASH ) {
        if ( exists $UBA_LOAD_HASH{$uba}{ELEMENT_IP_MAP}{$lbFieldVal} ) {
            $allocatedUBA = $uba;
            last;
        }
    }

    return $allocatedUBA;
}

sub assignToIdleUBA {
    my $func           = "checkAllocatedUBA";
    my ($lbFieldVal)   = @_;
    my $idleUbaUtilize = 1.0;
    my $allocatedUBA   = "FAIL";

    foreach my $uba ( keys %UBA_LOAD_HASH ) {
        my $maxElem   = $UBA_LOAD_HASH{$uba}{MAX_ELEMENT};
        my $elemCount = $UBA_LOAD_HASH{$uba}{ELEMENT_COUNT};
        my $utilize   = $elemCount / $maxElem;

        if ( $utilize < $idleUbaUtilize ) {
            $idleUbaUtilize = $utilize;
            $allocatedUBA   = $uba;
        }
    }

    if ( $allocatedUBA ne "FAIL"
        && !exists $UBA_LOAD_HASH{$allocatedUBA}{ELEMENT_IP_MAP}{$lbFieldVal} ) {
        $UBA_LOAD_HASH{$allocatedUBA}{ELEMENT_COUNT} =
          $UBA_LOAD_HASH{$allocatedUBA}{ELEMENT_COUNT} + 1;
        $UBA_LOAD_HASH{$allocatedUBA}{ELEMENT_IP_MAP}{$lbFieldVal} = 1;
        
        my $currentIp = $UBA_LOAD_HASH{$allocatedUBA}{ELEMENT_COUNT};
        my $threshold = $UBA_LOAD_HASH{$allocatedUBA}{THRESHOLD};
        my $maximumIp = $UBA_LOAD_HASH{$allocatedUBA}{MAX_ELEMENT};
        if ( ( $currentIp / $maximumIp * 100 ) > $threshold ) {
            &writeLog("WARN | Threshold exceeded... on UBA $allocatedUBA");
            $exceedThreshold = $exceedThreshold + 1;
            $emailMessage    = $emailMessage
              . "UBA : $allocatedUBA<br>Current number of IP : $currentIp<br>Threshold : $threshold%<br>Maximum number of IP : $maximumIp<br><br>";
        }
    }

    return $allocatedUBA;
}

sub writeContentToFile {
    my $func = "writeContentToFile";
    my ( $resultMapRef, $oriFilename, $headerStr ) = @_;
    my $rowCount = 0;

    if ( !defined $resultMapRef ) {
        &writeLog("ERROR | $func: ResultMap is not defined.");
        return "FAIL";
    }

    my %resultMap = %{$resultMapRef};

    foreach my $uba ( keys %resultMap ) {
        my $outFile = $tempDir . 'UBA_' . $uba . '/' . $oriFilename;

        &writeLog("INFO | $func: Start writing content to $outFile");

        if ( open( OUTPUT, ">$outFile" ) ) {
            print OUTPUT $headerStr . "\n";
            foreach my $line ( @{ ${resultMap}{$uba} } ) {

                #&writeLog("DEBUG | $func: UBA[$uba] => $line" ) if($DEBUG);
                print OUTPUT $line . "\n";
                $rowCount++;
            }
            close(OUTPUT);
            &writeLog("INFO | $func: Finish writing $rowCount line(s) to $outFile");
        }
        else {
            &writeLog("ERROR | $func: Fail to open $outFile for writting.");
        }
    }
    return "SUCCESS";
}

sub transferFile {
    my $func       = "transferFile";
    my ($fileName) = @_;
    my $idrsaFile  = $CONF_HASH{ID_RSA_PATH};

    &writeLog( "INFO | $func: Going to transfer loadbalanced file: " . $fileName );

    foreach my $uba ( keys %UBA_LOAD_HASH ) {
        my $lbFile  = $tempDir . "/UBA_" . $uba . "/" . $fileName;
        my $dlIndex = $UBA_LOAD_HASH{$uba}{DL_INDEX};

        &writeLog("DEBUG | $func: dlIndex: $dlIndex") if ($DEBUG);

        my $destIP    = $CONF_HASH{ $dlIndex . '.DL_IP' };
        my $destUser  = $CONF_HASH{ $dlIndex . '.DL_USERNAME' };
        my $basePath  = $CONF_HASH{ $dlIndex . '.DL_BASE_PATH' };
        my $finalPath = $basePath . "UBA_" . $uba . "/";

        if ( -e $lbFile ) {

            if ( $idrsaFile ne "" && $destIP ne "" && $destUser ne "" && $basePath ne "" ) {

                my $scpCmd = "scp -o IdentityFile=" . $idrsaFile . " -o StrictHostKeyChecking=no "
                             . $lbFile . " " . $destUser . "\@" . $destIP . ":" . $finalPath;

                &writeLog("DEBUG | SCP'g $lbFile to the the DL : $destIP , Path:$finalPath") if ($DEBUG);
                &writeLog("DEBUG | SCP'g Command : $scpCmd") if ($DEBUG);
                system($scpCmd);
                unlink($lbFile);
                &writeLog( "INFO | Finish SCP'g $lbFile to the the DL : " . $destIP );

            }
            else {
                &writeLog( "ERROR | $func: Incomplete information for scp to $uba | DL_IP: " . $destIP
                      . ', DL_USERNAME:' . $destUser
                      . ', DL_BASE_PATH' . $basePath);
            }
        }
        else {
            &writeLog( "WARN | $func: Missing loadbalanced file [" . $fileName . "] for UBA:$uba" );
        }
    }
}

sub flushHistoryFile {
    my $func       = "flushHistoryFile";
    my ($histFile) = @_;
    my $lineCount  = 0;

    &writeLog("$SEPERATOR");
    &writeLog("\t\t\t Starting $func ");
    &writeLog("$SEPERATOR");

    if ( open( HIST, ">$histFile" ) ) {
        foreach my $uba ( keys %UBA_LOAD_HASH ) {
            next if not defined(%{$UBA_LOAD_HASH{$uba}{ELEMENT_IP_MAP}});
            my %ipHash = %{ $UBA_LOAD_HASH{$uba}{ELEMENT_IP_MAP} };
            my @ipAry  = keys %ipHash;
            my $temp   = join( '|', @ipAry );
            print HIST $uba;
            print HIST "=";
            print HIST $temp;
            print HIST "\n";
            $lineCount++;

            &writeLog( "INFO | $func: UBA [" . $uba . "] contains " . scalar @ipAry . " IP(s)." );
        }
        close(HIST);

        &writeLog("INFO | $func: Finish writing $lineCount line to $histFile.");
    }
    else {
        &writeLog("ERROR | $func: Fail to open $histFile for writing.");
    }
    
    if ($exceedThreshold > 0) {
        sendEmail( "ALU5620SAM Adaptor – LoadBalancer error", "Threshold exceeded...<br><br>" . $emailMessage );
    }

    &writeLog("\t\t\t Finished $func ");
}

#==================================================================================
# Name 			: processEnvManagement
# Description	: To start process initialization
# Input			: None.
# Output		: None.
# Author		: Edwin Law
# Child Funtion	: startLog
# Global Var	:
# Date			: 2 May 2014
#==================================================================================

sub processEnvManagement {
    my $func = "processEnvManagement";

    &writeLog("$SEPERATOR");
    &writeLog("\t\t\t Starting $func ");
    &writeLog("$SEPERATOR");

    if ( !-e $tempDir ) {
        if ( !mkdir($tempDir) ) {
            &writeLog("ERROR-101: Failed to create temp directory. Exiting");
            exit(1);
        }
    }

    #create all the UBA output directory
    foreach my $uba ( keys %UBA_LOAD_HASH ) {
        &writeLog("DEBUG | $func : Creating temporary directory for UBA: $uba.")
          if ($DEBUG);
        my $ubaTempDir = $tempDir . "/UBA_" . $uba;
        if ( !-e $ubaTempDir ) {
            if ( !mkdir($ubaTempDir) ) {
                &writeLog("ERROR-101: Failed to create uba temp directory: $ubaTempDir. Exiting");
                exit(1);
            }
        }
    }

    &writeLog("\t\t\t Finished $func ");
}

#======================================================================================
# Name 			: processReadConf
# Description	: To read config file and store in hash
# Input			: $configFile
# Output		: Content of both config file will be stored into global hashes
# Author		: Edwin Law
# Child Funtion	: None.
# Global Var	: None.
# Date			: 2 May 2014
#======================================================================================

sub processReadConf {
    my ($configFile) = @_;
    my $func = "processReadConf";

    &writeLog("$SEPERATOR");
    &writeLog("\t\t\t Starting $func ");
    &writeLog("$SEPERATOR");

    if ( !open( CONF, "<$configFile" ) ) {
        &writeLog("ERROR-103: Could not open configuration file $configFile to read: $!");
        exit(1);
    }
    &writeLog("SYSTEMCONF : Reading $configFile");

    while ( my $line = <CONF> ) {
        if ( $line !~ /^#/ && $line =~ /\w+/ ) {
            chomp($line);

            #---Remove any space from the conf file
            $line =~ s/^\s|\s+$//;
            $line =~ s/\s*=\s*/=/g;
            my ( $parameter, $value ) = split( '=', $line );

            #---Store configuration parameter and its value in global hash to be referenced by any modules
            $CONF_HASH{$parameter} = $value;
            &writeLog("SYSTEMCONF: $parameter => $value");
        }
    }
    close CONF;

    &writeLog("\t\t\t Finished $func ");
}

#==========================================================================================
# Name		    : deleteOldFiles
# Description	: To delete the old log files
# Input 	    : The directory path of log files
# Output	    :
# Author	    : Pawan Kumar
# Date		    : 26 March 2009
#===========================================================================================

sub deleteOldLogFiles {
    my ( $dirPath, $retentionPeriod ) = @_;
    my $func        = "deleteOldLogFiles";
    my $currentTime = time;

    if ( opendir( DIRH, $dirPath ) ) {
        foreach my $file ( readdir(DIRH) ) {

            #---Excluding directory symbol
            next if ( $file =~ /^\.|^\.\./ );

            my $absFileName = $dirPath . $file;

            #---File creation time stamp
            my $statTime = ( stat($absFileName) )[9];

            #---Deleting all files which are older than retaintion period (number of days)
            if ( ( $currentTime - $statTime ) > ( $retentionPeriod * 24 * 60 * 60 ) ) {
                my $cmd = qq@rm -rf $absFileName @;
                &writeLog("ERROR | $func : Unable to delete old file: $absFileName")
                  if ( system($cmd) != 0 );
            }
        }
    }
    else {
        &writeLog("ERROR | $func : Could not open the directory $dirPath for cleanup : $!\n");
    }
    closedir DIRH;
}

#====================================================================
# Name          	: createLog
# Description   	: To create a log file hadler. It also creates
#                     ManageInventory process lock through a file.
#                     Else exit processing it one instance is already
#                     in execution
# Input         	: Log directory path
# Output            : LOG file hadler will get created to be used
#                     by writeLog function
# Author            : Pawan Kumar
# Date              : 15 Sept 2008
# Last Updated      : 20 May 2012
#====================================================================

sub createLog {
    my $logDir    = $_[0];
    my $setupName = $_[1];

    my @timeNow  = localtime(time);
    my $tyear    = $timeNow[5] + 1900;
    my $tmonth   = $timeNow[4] + 1;
    my $tday     = $timeNow[3];
    my $thour    = $timeNow[2];
    my $tmin     = $timeNow[1];
    my $tsec     = $timeNow[0];
    my $thisDate = sprintf( "%04d%02d%02d", $tyear, $tmonth, $tday );

    my $logFile = $logDir . $setupName . "_" . $thisDate . ".log";

    if ( open( LOG, ">>$logFile" ) ) {
        &writeLog("$SEPERATOR");
        &writeLog("File: $logFile");
        &writeLog("Description: Starting $setupName Process!");
    }
    else {
        print "ERROR: Unable to create Log file handler at $logDir directory with $logFile file name!\n";
    }
}

#==================================================================================
# Name 			: writeLog
# Description	: To load the UBA with maximum element limit
# Author	    : Edwin Law
# Input 		: $CONF_HASH
# Return  		: None.
# Child Funtion	: None.
# Global var	: None.
# Date			: 2 May 2014
#==================================================================================

sub writeLog {
    my ($logMsg) = @_;

    # Current time stamps; l - log
    my @timeNow  = localtime(time);
    my $lyear    = $timeNow[5] + 1900;
    my $lmonth   = $timeNow[4] + 1;
    my $lday     = $timeNow[3];
    my $lhour    = $timeNow[2];
    my $lmin     = $timeNow[1];
    my $lsec     = $timeNow[0];
    my $thisTime = sprintf( "%04d/%02d/%02d %02d:%02d:%02d", $lyear, $lmonth, $lday, $lhour, $lmin, $lsec );

    #print "logMsg | $logMsg \n";
    print LOG "$thisTime | $logMsg \n";
}

#==================================================================================
# Name 			: getDateTime
# Description	: To getDateTime
# Author	    : Edwin Law
# Input 		: $CONF_HASH
# Return  		: None.
# Child Funtion	: None.
# Global var	: None.
# Date			: 2 May 2014
#==================================================================================

sub getDateTime {
    my $option   = shift;
    my $thisDate = "";
    my @timeNow  = localtime(time);
    my $tyear    = $timeNow[5] + 1900;
    my $tmonth   = $timeNow[4] + 1;
    my $tday     = $timeNow[3];
    my $thour    = $timeNow[2];
    my $tmin     = $timeNow[1];
    my $tsec     = $timeNow[0];

    return sprintf( "%04d_%02d_%02d", $tyear, $tmonth, $tday )
      if ( $option eq 1 );
    return sprintf( "%04d/%02d/%02d %02d:%02d:%02d", $tyear, $tmonth, $tday, $thour, $tmin, $tsec )
      if ( $option eq 2 );
    return sprintf( "%2d", $thour ) if ( $option eq 3 );
}

#==========================================================================================
# Name			: deleteOldFiles
# Description	: To delete old files
# Input			: $dirPath, $retentionPeriod
# Output		: None.
# Author		: Edwin Law
# Child Funtion	: None
# Global Var	: None
# Date			: 2 May 2014
#===========================================================================================

sub deleteOldFiles {
    my ( $dirPath, $retentionPeriod ) = @_;
    &writeLog("$SEPERATOR")                      if ($DEBUG);
    &writeLog("\t\t\t Starting deleteOldFiles ") if ($DEBUG);
    &writeLog("$SEPERATOR")                      if ($DEBUG);

    if ( opendir( DIRH, $dirPath ) ) {
        my $currentTime = time;
        foreach my $file ( readdir(DIRH) ) {

            #---Excluding directory symbol
            next if ( $file =~ /^\.|^\.\./ );
            my $absFileName = $dirPath . $file;

            #---File creation time stamp
            my $statTime = ( stat($absFileName) )[9];
            my $diff     = ( $currentTime - $statTime );

            #&writeLog("\$retentionPeriod:$retentionPeriod");
            #&writeLog("\$currentTime: $currentTime ");
            #&writeLog("\$statTime: $statTime ");
            #&writeLog("\$diff: $diff");

            #---Deleting all files which are older than retaintion period
            #if ( $retentionPeriod
            #	 && ( $currentTime - $statTime ) > ($retentionPeriod) )
            #{
            #&writeLog("Deleting file: $absFileName");
            my $cmd = qq@rm -rf $absFileName @;
            &writeLog("Unable to delete old file: $absFileName")
              if ( system($cmd) != 0 );

            #}
        }
    }
    else {
        &writeLog("ERROR: Could not open the directory $dirPath for cleanup : $!\n");
    }
    closedir DIRH;
}

##
# Send Email
# @author          azman.kudus@bt.com
# @param subject   Title
# @param message   Contents
##
sub sendEmail {
    my ( $subject, $message ) = @_;
    my $msg = MIME::Lite->new(
        From    => $CONF_HASH{EMAIL_FROM},
        To      => $CONF_HASH{EMAIL_TO},
        Subject => $subject,
        Data    => $message
    );
    $msg->attr( "content-type" => "text/html" );
    $msg->send( "smtp", $CONF_HASH{EMAIL_SMTP} );
}

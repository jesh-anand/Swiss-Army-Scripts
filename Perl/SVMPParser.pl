#!/usr/bin/perl

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

use strict;
use warnings;
use File::Copy;
use Time::Local;
use MIME::Lite; 
use Cwd;

my $BASE_PATH    = $ENV{BASE_PATH};

#--------------------------------------------------
#   Directory Paths
#--------------------------------------------------
my $INPUT_DIR   = "";
my $OUTPUT_DIR  = "";
my $ARCHIVE_DIR = "";
my $LOG_PATH    = $BASE_PATH . "log/";

#--------------------------------------------------
#   Global Variables
#--------------------------------------------------
my %CONF_HASH   	= ();
my $CONFIG_FILE  	= $ARGV[0];
my $DEBUG       	= 0;
my $PIDFILE       = "UIIPathFinderParser.lck";
my $SEPERATOR     = "===================================================================================";
my $CURRENT_TIME  = &currentTime();
my $START_TIME    = "";
my @HEADER_TYPE   = ();
my @RECORD_TYPE   = ();
my %RECORD_LINE   = ();
my $HEADER_LINE   = "";

main(@ARGV);

#======================================================================================================================
#					  			  MAIN FUNCTION						 		  
#======================================================================================================================
sub main {
	
	my $func = "main";
	&createLog( $LOG_PATH, "UII_PATH_FINDER_PARSER" );
	&intro();
	&processReadConf($CONFIG_FILE);
	&initConfig();
	&writePid();

	my $sortedfilelist = &getSortedFileList($INPUT_DIR);
	if ( scalar(@$sortedfilelist) > 0 ) {
		my $dbTimestamp = &getUniqueIdentifierFromDB();
		my $validFNames = &checkFilename($sortedfilelist);
		if (defined $validFNames) {
			foreach my $validFilename (@$validFNames) {
				&initRecordLineHash();

				
				my $isFileStagnant = &checkFileStagnant($validFilename);

				if ($isFileStagnant == 1) {
					&writeLog("INFO [" . $func . "] : Processing feed file >>>>> (" . $validFilename . ")");
					$START_TIME = time;
					my $result = &generateCSV( $dbTimestamp, $validFilename );
					if ($result eq "SUCCESS") {
						&processFeedInfo();
						my $timeDiff = time - $START_TIME;									
						if ($timeDiff == 0 ) {
							$timeDiff = 1;
						}				
						&writeLog("INFO [" . $func . "] : Finished processing feed file " . $validFilename . " in " . $timeDiff . " second(s)");
						&writeLog("INFO [" . $func . "] : Moving file (" . $validFilename . ") to archive.");
						$CURRENT_TIME++;
					} 
					&moveToPath("$INPUT_DIR/$validFilename", "$ARCHIVE_DIR/$validFilename");
				} else {
					&writeLog("WARN [" . $func . "] : Unable to process file (" . $validFilename . ") as its size is still growing.");	
				}
			}
		}		
	} else {
		&writeLog("ERROR [" . $func  . "] : There are no feeds in the input directory. Exiting..");
	}
	&removeOldFiles();
	&closeLog();
}
#=====================================================================================================================
#								END OF MAIN FUNCTION
##====================================================================================================================

sub intro {	
	my $func = "intro";
	&writeLog("$SEPERATOR");
	&writeLog(" \t\t\tDescription: UII_PATHFINDER_PARSER Log File");
	&writeLog("$SEPERATOR");
	&writeLog("INFO [" . $func . "] : Loading configuration file...");
}

sub outro {
	&writeLog("$SEPERATOR");
	&writeLog(" \t\t\t\t	End of Log File");
	&writeLog("$SEPERATOR");
}

sub getSortedFileList 
{	
	my $path = shift;
	my @sortedfileList;
	my $func = "getSortedFileList";
	opendir DIR, $path or &writeLog("[" . $func  . "] : ERROR: Unable to open directory!");

	#-- Files from input directory
	my @fileList = readdir(DIR);

	foreach my $entry ( sort @fileList ) {
		next if ( $entry eq "." or $entry eq ".." );
		push( @sortedfileList, $entry );
	}
	close(DIR);
	return \@sortedfileList;
}

sub checkFilename 
{	
	my $file = shift;
	
	my $func = "checkFilename";
	&writeLog("$SEPERATOR") if ($DEBUG);
    	&writeLog("\t\t\t Starting $func ") if ($DEBUG);
    	&writeLog("$SEPERATOR") if ($DEBUG);
	
	my $filterExpUIIOneTimeFeed = $CONF_HASH{UII_ONE_TIME_PREFIX_FILTER} . '\d+' . $CONF_HASH{UII_ONE_TIME_SUFFIX_FILTER};
	my $filterExpUIIDeltaFeed = $CONF_HASH{UII_DELTA_PREFIX_FILTER} . '\d+' . $CONF_HASH{UII_DELTA_SUFFIX_FILTER};
	my @validFilenames = ();
	
	foreach my $entry (@$file) {
		if ($entry =~ /$filterExpUIIOneTimeFeed/) {
			push( @validFilenames, $entry );
		} elsif ($entry =~ /$filterExpUIIDeltaFeed/) {
			push( @validFilenames, $entry );
		} else {
			&writeLog( "ERROR [" . $func . "] : Feed file (" . $entry . ") has invalid name format. Moved to archive." );
			my $message = "Hi ASG Team, <br><H3><u><b>ERROR</b> - INVALID NAME FORMAT</u></H3>
					The following error has been logged:<br><br>
					<blockquote><pre>ERROR [" . $func . "] : Feed file (" . $entry . ") has invalid name format. Moved to archive.</pre></blockquote><br><br>									
					<b>(" . $file . ")</b> has invalid naming format. Please look into the file located in the <b>$ARCHIVE_DIR</b> directory.<br><br><b>
					Best Regards,<b><br> SVMP Parser ";
			&sendEmail("UII PathFinder Parser <ERROR> - $file", $message);
			&moveToPath("$INPUT_DIR/$file", "$ARCHIVE_DIR/$file");			
		}
	}
	return \@validFilenames;
}

sub generateCSV 
{
	my ( $timestampfromDB, $file ) = @_;

	my $func = "generateCSV";
	&writeLog("$SEPERATOR") if ($DEBUG);
	&writeLog("\t\t\t Starting $func ") if ($DEBUG);
	&writeLog("$SEPERATOR") if ($DEBUG);
	
	my $status 			= "FAILED";
	my $openFileCmd 	= '';
	my $totalLines		= 0;
	my $headerTypeCount	= 0;
	my $rec01Header		= '';
	my $rec99Trailer	= '';
	my $rec01Check		= '';
	my $rec99Check		= '';
	my $headerTypeLine	= '';
	my $headerTypeField	= 0;
	my @tempAry			= ();
	my @finalRecordAry	= ();
	my $headertype		= '';
	my $recordtype		= '';
	my $recordErrorCount= 0;
	
	my $UiiOneTimeFeed 	= $CONF_HASH{UII_ONE_TIME_PREFIX_FILTER} . '\d+' . $CONF_HASH{UII_ONE_TIME_SUFFIX_FILTER};
	my $UiiDeltaFeed 	= $CONF_HASH{UII_DELTA_PREFIX_FILTER} . '\d+' . $CONF_HASH{UII_DELTA_SUFFIX_FILTER};
	
	if ($file =~ /$UiiOneTimeFeed/) {
		$openFileCmd = "gunzip -cq $INPUT_DIR/$file |";	
	} elsif ($file =~ /$UiiDeltaFeed/) {
		$openFileCmd = "<$INPUT_DIR/$file";
	}	
	
	if( open( FH, $openFileCmd ) )
	{
		# Load content into hash		
		while ( my $line = <FH> ) {
			chomp($line);			
			$totalLines++;
			foreach my $prefix (keys %RECORD_LINE) 
			{
				if( $line =~ /^$prefix/ )
				{
					push(@{$RECORD_LINE{$prefix}},$line);
					last;	
				}
			}
		}
		close(FH);
		&writeLog(" INFO [" . $func . "] : Finish loading $totalLines line from [$file].");
		
		
		if ($DEBUG) 
		{
			foreach my $prefix (keys %RECORD_LINE) 
			{
				&writeLog(" DEBUG [" . $func . "] : Printing record [$prefix]:");
				
				foreach my $line (@{$RECORD_LINE{$prefix}})
				{
					&writeLog(" DEBUG [" . $func . "] : Line: $line");
				}
			}
		}
		
		if( exists $RECORD_LINE{'01'} && scalar @{$RECORD_LINE{'01'}} > 0  )
		{
			$rec01Header = $RECORD_LINE{'01'}[0];
			$HEADER_LINE = $rec01Header;
			&writeLog(" INFO [" . $func . "] : rec01Header: $rec01Header");
		}
		
		if( exists $RECORD_LINE{99} && scalar @{$RECORD_LINE{99}} > 0  )
		{
			$rec99Trailer = $RECORD_LINE{99}[0];
			&writeLog(" INFO [" . $func . "] : rec99Trailer: $rec99Trailer");
		}
		
		$rec01Check = &fileHeaderValidation($timestampfromDB, $file, $rec01Header);
		$rec99Check	= &fileTrailerValidation($file, $rec99Trailer, $totalLines);
		
		if( $rec01Check eq 'SUCCESS' && $rec99Check eq 'SUCCESS' )
		{
			$headerTypeCount = scalar @HEADER_TYPE;
			#process each record type : example 59
			for (my $i = 0; $i < $headerTypeCount ; $i++) 
			{
				&writeLog(" INFO [" . $func . "] : Processing record header $HEADER_TYPE[$i] .");
				@tempAry			= @{$RECORD_LINE{ $HEADER_TYPE[$i] }};
				if( scalar @tempAry > 0 )
				{
					$headerTypeLine 	= $tempAry[0];	
					$headerTypeField 	= &countColumnLength($headerTypeLine);
					$recordErrorCount 	= 0;					
					$recordtype			= $RECORD_TYPE[$i];
					@tempAry			= @{$RECORD_LINE{ $recordtype }};
					if( scalar @tempAry > 0 )
					{
						&writeLog(" INFO [" . $func . "] : Processing record type $recordtype with ". scalar @tempAry . " records.");
						
						foreach my $recLine (@tempAry)
						{
							my $recordTypeField = &countColumnLength($recLine);
							if (int($headerTypeField) != int($recordTypeField)) {
								&writeLog(" ERROR [" . $func . "] : Given line inside (" . $file . ") does not have same of number of field with the record header line. Excluded this line.|_|$recLine");
								$recordErrorCount++;
								next;
							}
							push(@finalRecordAry,$recLine);
						}
					}
					
					if( $recordErrorCount > 0 )
					{
						my $errorCode	= 'E100';
						my $errorMsg	= " ERROR [" . $func . "] : <" . $status . "> Feed file (" . $file . ") has total "
											. $recordErrorCount .
											" line rejected for record ["
											. $recordtype .
											"] because number of field in record line is mismatch with number of field in header line."; 	
						&sendErrorEmail($func,$file,$errorCode,$errorMsg);
					}
					
					if( scalar @finalRecordAry > 0 )
					{
						&parseToCSV($recordtype, $headerTypeLine, \@finalRecordAry);
						$status = "SUCCESS";	
					}
					else
					{
						&writeLog("INFO [" . $func . "] : No record " . $recordtype . " present inside file (" . $file . ")");
						&writeLog("INFO [" . $func . "] : Check " . $OUTPUT_DIR . " directory for the generated feed info file.");
						&processSimpleFeedInfo();	
					}					
				}
				else
				{
					&writeLog( " WARN [" . $func . "] : Feed file (" . $file . ") do not have expected record header [". $HEADER_TYPE[$i] ."]. Skip all records correspondent to this header.");
			    	next;
				}
			}
		}
	}
	else
	{
		&writeLog(" ERROR [" . $func . "] : Unable to read $file .");
	}
	return $status;
}

sub countColumnLength {		
	my ($line) = @_;	
	my $func = "countColumnLength";
	&writeLog("$SEPERATOR") if ($DEBUG);
    	&writeLog("\t\t\t Starting $func ") if ($DEBUG);
    	&writeLog("$SEPERATOR") if ($DEBUG);
	my @columnsLength = split( /$CONF_HASH{INPUT_DELIMITER}/, $line , -1);
	return scalar @columnsLength;
}

sub fileHeaderValidation 
{
	my ( $timestampFromDB, $file, $headerLine ) = @_;
	
	my $func = "fileHeaderValidation";
	
	&writeLog("$SEPERATOR") if ($DEBUG);
	&writeLog("\t\t\t Starting $func ") if ($DEBUG);
    &writeLog("$SEPERATOR") if ($DEBUG);
    
    my $status 				= 'FAIL';
    my $errorMsg			= '';
    my @headerColumns 		= ();
    my $uiiTimestamp		= '';
    my $headerFieldCount 	= $CONF_HASH{UII_COLUMN_LENGTH};
    
    
    if( !defined $headerLine || $headerLine eq '' )
    {
    	# E001: 01 Header not exist
    	$status 	= 'E001';
    	$errorMsg	= " ERROR [" . $func . "] : <" . $status . "> Feed file (" . $file . ") has no 01 header. Moved to archive.";
 		&sendErrorEmail($func,$file,$status,$errorMsg);
    	&writeLog($errorMsg);
    	return $status;
    }
    
    #---------------------------------------------------------------------------
	#$header | $feed_name | $uiiTimestamp | $run_number | $interface_version |
	#---------------------------------------------------------------------------
	@headerColumns = split( /$CONF_HASH{INPUT_DELIMITER}/, $headerLine );
    if( ( scalar @headerColumns ) != int($headerFieldCount) )
    {
    	$status 	= 'E002';
    	$errorMsg	= " ERROR [" . $func . "] : " . $status . " : Feed file (" . $file . ") has invalid (01) header length! Moved to archive.";
    	&sendErrorEmail($func,$file,$status,$errorMsg);
    	&writeLog($errorMsg);
    	return $status;
    }
    
    $uiiTimestamp = $headerColumns[2];
    if ( $uiiTimestamp !~ /\d+/ ) {	
    	$status 	= 'E003';
    	$errorMsg	= " ERROR [" . $func . "] : " . $status . " : Feed file (" . $file . ") does not have a valid timestamp at the header! Moved to archive.";
    	&sendErrorEmail($func,$file,$status,$errorMsg);
    	&writeLog($errorMsg);
    	return $status;
    }
    
    if ( int($uiiTimestamp) <= int($timestampFromDB) ) 
    {
    	$status 	= 'E004';
    	$errorMsg	= " ERROR [" . $func . "] : " . $status . " : Feed file (" . $file . ") timestamp (" . $uiiTimestamp . ") is older than last processed timestamp (" . $timestampFromDB . "). Moved to archive.";
    	&sendErrorEmail($func,$file,$status,$errorMsg);
    	&writeLog($errorMsg);
    	return $status;
    }
	
	if ( $CONF_HASH{SKIP_UNIQUE_IDENTIFIER_CHECK} eq "FALSE" ) 
	{
		&checkUniqueIdentifier($file, $timestampFromDB, $uiiTimestamp);
	}	
	
	return 'SUCCESS';
}

sub fileTrailerValidation 
{
	my ( $file, $tailerLine, $fileLineCount ) = @_;
	
	my $func = "fileTrailerValidation";
	&writeLog("$SEPERATOR") if ($DEBUG);
	&writeLog("\t\t\t Starting $func ") if ($DEBUG);
	&writeLog("$SEPERATOR") if ($DEBUG);
	
	 my $status 	= 'FAIL';
	 my $errorMsg	= '';
	
	if( !defined $tailerLine || $tailerLine eq '' )
    {
    	# E006: 99 Footer not exist
    	$status 	= 'E006';
    	$errorMsg	= " ERROR [" . $func . "] : " . $status . " : Feed file (" . $file . ") has no 99 trailer record. Moved to archive.";
 		&sendErrorEmail($func,$file,$status,$errorMsg);
    	&writeLog($errorMsg);
    	return $status;
    }
    
    
    #--- Check if the number of lines counted tally with the one printed
    my ($trailerNumber, $lineNumber)  = split( /$CONF_HASH{INPUT_DELIMITER}/, $tailerLine );
	if (int($lineNumber) != int($fileLineCount)) 
	{
		# E007: 99 trailer line count do not match
    	$status 	= 'E007';
    	$errorMsg	= " ERROR [" . $func . "] : " . $status . " : Feed file (" . $file . ") has mistmatch line count (" . $fileLineCount . ") as presented in 99 trailer record (" . $lineNumber . "). Moved to archive.";
 		&sendErrorEmail($func,$file,$status,$errorMsg);
    	&writeLog($errorMsg);
    	return $status;
	}
    
    return 'SUCCESS';
}

sub sendErrorEmail()
{
	my ( $func, $file, $errorCode, $errorMsg ) = @_;
	
	my $message = '';
	
	if( $errorCode eq 'E001' )
	{
		# MISSING 01 HEADER
		$message = "Hi ASG Team, <br> <H3><u><b>ERROR</b> - NO '01' HEADER </u></H3><br><br>
					The following error has been logged:<br><br>
					<blockquote><pre>".$errorMsg."<br><br></pre></blockquote>									
					There is no 01 header present inside <b>$file</b>. 
					Please examine the file inside the <b>$ARCHIVE_DIR</b> directory.<br><br><b>
					Best Regards,<b><br> SVMP Parser ";	
	}
	elsif( $errorCode eq 'E002' ) 
	{
		# MISMATCH 01 HEADER fields
		$message = "Hi ASG Team, <br> <H3><u><b>ERROR</b> - INVALID '01' HEADER LENGTH </u></H3><br><br>
					The following error has been logged:<br><br>
					<blockquote><pre>". $errorMsg ."</pre></blockquote><br><br>
					Feed file <b>(" . $file . ")</b> does not have a valid '01' header length that is the same in the config file. 
					Please check if there is any lost of field content within the row in the <b>$ARCHIVE_DIR</b>. 
					Please check the config file if the length tallies with the 01 header length. <br><br><b> 
					Best Regards,<b><br> SVMP Parser ";
	}
	elsif( $errorCode eq 'E003')
	{
		# INVALID HEADER TIMESTAMP
		$message = "Hi ASG Team, <br> <H3><u><b>ERROR</b> - INVALID TIMESTAMP </u></H3><br><br>
					The following error has been logged:<br><br>
					<blockquote><pre>".$errorMsg."</pre></blockquote><br><br>
					Feed file <b>(" . $file . ")</b> does not have a valid timestamp. Please verify if there is a timestamp 
					along the <b>01</b> row in the <b>$ARCHIVE_DIR</b> directory.<br><br><b>
					Best Regards,<b><br> SVMP Parser ";
	}
	elsif( $errorCode eq 'E004')
	{
		# OLDER UII FEED TIMESTAMP	
		$message = "Hi ASG Team, <br> <H3><u><b>ERROR</b> - OLD FEED FILE </u></H3>
							The following error has been logged:<br><br>							
							<blockquote><pre>". $errorMsg ."</pre></blockquote><br><br>
							An older feed file <b>(" . $file . ")</b> has been detected in the input directory. Please examine the file
							located in the <b>$ARCHIVE_DIR</b> directory.<br><br><b>
							Best Regards,<b><br> SVMP Parser ";
	}
	elsif( $errorCode eq 'E005')
	{
		# NO UII FEED FOR MORE THAN 24 HOURS	
		$message = "Hi ASG Team, <br> <H3><u><b>ERROR</b> - NO UII FEED FOR MORE THAN 24 HOURS </u></H3><br><br>
					The following error has been logged:<br><br>
					<blockquote><pre>".$errorMsg."</pre></blockquote><br><br>					
					No feed file has been received for the past 1 day. Please verify with the UII Team to produce UII feed for the particular day.<br><br>
					Best Regards,<br> SVMP Parser ";	
	}
	elsif( $errorCode eq 'E006' )
	{
		# MISSING 99 TRAILER
		$message = "Hi ASG Team, <br> <H3><u><b>ERROR</b> - NO 99 TRAILER RECORD </u></H3><br><br>
					The following error has been logged:<br><br>
					<blockquote><pre>".$errorMsg."</pre></blockquote><br><br>					
					There is no trailer record '99' present in the feed file. Verify the file inside <b>$ARCHIVE_DIR</b> directory.<br><br>
					Best Regards,<br> SVMP Parser ";
	}
	elsif( $errorCode eq 'E007' )
	{
		# MISMATCH FILE LINE COUNT COMPARE TO 99 TRAILER
		$message = "Hi ASG Team, <br> <H3><u><b>ERROR</b> - INVALID NUMBER OF LINES </u></H3><br>
					The following error has been logged:<br><br>
					<blockquote><pre>".$errorMsg."</pre></blockquote><br><br>					
					The number of lines of the feed file is not the same as stated in '99' trailer row. 
					<br><b>(" . $file . ")</b> has been moved to  <b>$ARCHIVE_DIR</b> directory.<br><br>
					Best Regards,<br> SVMP Parser";
	}
	elsif( $errorCode eq 'E100' )
	{
		# RECORD FIELD MISMATCH WITH HEADER
		$message = "Hi ASG Team, <br><H3><u><b>ERROR</b> - REJECTED RECORD LINE</u></H3>
					The following error has been logged:<br><br>
					<blockquote><pre>".$errorMsg."</pre></blockquote><br><br>									
					Please check the reject line(s) from the error log and also the original feed located in the <b>$ARCHIVE_DIR</b> directory.<br><br><b>
					Best Regards,<b><br> SVMP Parser ";
	}
	
	if( $file ne '' && $message ne '' )
	{
		&sendEmail("SVMP UII PathFinder Parser [ERROR] - " . $file, $message);	
	}	
}

sub checkFileStagnant {
	
	my $file = shift;
	my $func = "checkFileStagnant";
	&writeLog("$SEPERATOR") if ($DEBUG);
    	&writeLog("\t\t\t Starting $func ") if ($DEBUG);
    	&writeLog("$SEPERATOR") if ($DEBUG);
	
	my ($fileSize) = -s $INPUT_DIR . "" . $file;
	&writeLog("INFO [" . $func . "] : Checking if file (" . $file . ") size is growing..");
	sleep($CONF_HASH{SLEEP_TIME});
	
	if ($fileSize == -s $INPUT_DIR . "" . $file) {
		return 1;
	} else {
		return 0;
	}
}


sub checkUniqueIdentifier {
	
	my ($file, $dbTimestamp, $uiiTimestamp) = @_;
	
	my $func = "uniqueIdentifierCheck";	
	
	my $uiiTime = &getEpochTime($uiiTimestamp);
	my $dbTime  = &getEpochTime($dbTimestamp);
	
	my $day = ($uiiTime - $dbTime) / (60 * 60 * 24);
	
	if ($day > 1) {
		my $errorCode 	= 'E005';
		my $errorMsg	= " ERROR [" . $func . "] : " .$errorCode. " : No UII Feed has been processed for the past " . int($day) . " day(s)! Process has been halted until previous day(s) UII Feed has been received.";		
		&sendErrorEmail( $func, $file , $errorCode, $errorMsg );						
		&writeLog($errorMsg);
		&writeLog("INFO [" . $func . "] : Exiting UII PathFinder Parser..");
		&closeLog();
		exit(1);		
	}	
}

sub getEpochTime {	
	my $timestamp = shift;	
	my $func = "getEpochTime";
	my $year   = substr($timestamp, 0, 4);
	my $month  = substr($timestamp, 4, 2);
	my $day    = substr($timestamp, 6, 2);
	my $hour   = substr($timestamp, 8, 2);
	my $minute = substr($timestamp, 10, 2);
	my $second = substr($timestamp, 12, 2);
	
	return timelocal($second,$minute,$hour,$day,$month,$year);	
}

sub getUniqueIdentifierFromDB {
	
	my $func = "getUniqueIdentifierFromDB";
	&writeLog("$SEPERATOR") if ($DEBUG);
    	&writeLog("\t\t\t Starting $func ") if ($DEBUG);
    	&writeLog("$SEPERATOR") if ($DEBUG);
	
	my $libjar            = "./lib/ojdbc14.jar";
	my $jarfile           = "./lib/dbexport.jar";
	my $sqlElmtConfigFile = "./dbexport/temp.conf";

	my $sqlQuery = "SELECT UNIQUE_IDENTIFIER FROM (SELECT * FROM SVMP_FEED_HISTORY WHERE PARSER_NAME = '$CONF_HASH{PARSER_NAME}' ORDER BY LAST_MODIFIED_DATE DESC) WHERE ROWNUM = 1";

	if ( open( SQLELT, ">$sqlElmtConfigFile" ) ) {
		print SQLELT "DEBUG=true\n";
		print SQLELT "SQL_URL=" . $CONF_HASH{SQL_URL} . "\n";
		print SQLELT "SQL_USER_NAME=" . $CONF_HASH{SQL_USER_NAME} . "\n";
		print SQLELT "SQL_DB_PWD=" . $CONF_HASH{SQL_DB_PWD} . "\n";
		print SQLELT "EXPORT_DIRECTORY=dbexport/\n";
		print SQLELT "FILENAME_PREFIX=SQL_QUERY_RESULT\n";
		print SQLELT "FILENAME_POSTFIX=.dat\n";
		print SQLELT "EXPORT_SQL=" . $sqlQuery . "\n";
		print SQLELT "EXPORT_SQL_KEY=FILENAME\n";
		print SQLELT "FILENAME=1";
		close(SQLELT);

		# ---------------------------------------------------------------
		my $cmd = qq@java -cp $libjar -jar $jarfile $sqlElmtConfigFile@;
		# ---------------------------------------------------------------

		eval( system($cmd) );
		if ($@) {
			&writeLog(" ERROR [" . $func . "] : Fail to execute sql command for element dbIndexes details. Terminating..");
		} else {
			&writeLog("INFO [" . $func . "] : Connection Established.");
			&writeLog("INFO [" . $func . "] : Element Export Command: $cmd") if ($DEBUG);
		}
	} else {
		&writeLog(" ERROR [" . $func . "] : Failed to create file $sqlElmtConfigFile. Exiting..");
	}

	open( DB, "<", "dbexport/SQL_QUERY_RESULT_1.dat" ) or &writeLog("[" . $func . "] || ERROR: Unable to open SQL Query result file");
	my $timestampDate = <DB>;
	chomp $timestampDate;
	&writeLog("INFO [" . $func . "] : Retrieving latest timestamp from SVMP_FEED_HISTORY table...");
	&writeLog("INFO [" . $func . "] : DB Timestamp (Latest) -> " . $timestampDate );
	close DB;

	return $timestampDate;
}

sub parseToCSV {
	
	my $func = "parseToCSV";
	&writeLog("$SEPERATOR") if ($DEBUG);
    	&writeLog("\t\t\t Starting $func ") if ($DEBUG);
    	&writeLog("$SEPERATOR") if ($DEBUG);
    	
	my ( $recordNo, $recHeaderline, $recordlines ) = @_;
	
	my @headerField 		= split( /$CONF_HASH{INPUT_DELIMITER}/, $HEADER_LINE );
	my $timeStampFromUII 	= $headerField[2];
	
	my $fileName    = "Record" . $recordNo . "_" . $timeStampFromUII . ".csv";
	
	if( open( SH, ">", "$OUTPUT_DIR/$fileName" ) )
	{
		my @recHeaderField 	= split( /$CONF_HASH{INPUT_DELIMITER}/, $recHeaderline );
		my $hline 			= join($CONF_HASH{OUTPUT_DELIMITER}, $recHeaderField[1], $recHeaderField[2], $recHeaderField[3], $recHeaderField[4], $recHeaderField[5], $recHeaderField[6]);
		
		&writeLog("Generating output file..") if ($DEBUG);
		&writeLog("$SEPERATOR") if ($DEBUG);
		&writeLog($hline) if ($DEBUG);
		print SH $hline . "\n";
		
		foreach my $line (@$recordlines) {
			chomp $line;
			my @recordTypeField = split( /$CONF_HASH{INPUT_DELIMITER}/, $line );
			$line = join($CONF_HASH{OUTPUT_DELIMITER}, $recordTypeField[1], $recordTypeField[2], $recordTypeField[3], $recordTypeField[4], '', '');
			&writeLog($line) if ($DEBUG);
			print SH $line . "\n";
		}
		&writeLog("$SEPERATOR") if ($DEBUG);
		close SH;
	}
	else
	{
		&writeLog(" ERROR [" . $func . "] : Cannot write to .csv file - [$fileName]");
	}
}

sub moveToPath {
	my $func = "moveToPath";
	my ( $inputFile, $targetFile ) = @_;
	&writeLog("INFO [" . $func . "] : Moving " . $inputFile . " to " . $targetFile) if ($DEBUG);
	move( $inputFile, $targetFile );
}

sub processSimpleFeedInfo {
    	
	my $func = "processSimpleFeedInfo";
	&writeLog("$SEPERATOR") if ($DEBUG);
    &writeLog("\t\t\t Starting $func ") if ($DEBUG);
    &writeLog("$SEPERATOR") if ($DEBUG);
    	
	my @headerField 		= split( /$CONF_HASH{INPUT_DELIMITER}/, $HEADER_LINE );
	my $timeStampFromUII 	= $headerField[2];
	my $feedInfoFilename 	= "Feed_Info_" . $timeStampFromUII . ".info";
	
	if( open( INFO, ">>", "$CONF_HASH{OUTPUT_PATH}/" . $feedInfoFilename ) )
	{
		print INFO "HEADER=" . $HEADER_LINE . "\n";
		print INFO "UNIQUE_IDENTIFIER=" . $timeStampFromUII . "\n";
		print INFO "PARSER_NAME=" . $CONF_HASH{PARSER_NAME} . "\n";
		print INFO "REQUIRED_RECORD=" . $CONF_HASH{REQUIRED_RECORDS} . "\n";
		print INFO "OUTPUT_DELIMITER=" . $CONF_HASH{OUTPUT_DELIMITER} . "\n";

		close INFO;	
	}
	else
	{
		&writeLog("ERROR [" . $func  . "] : Unable to generate feed info file [$feedInfoFilename]");
	}
	
	
}



sub processFeedInfo {
	
	my $func = "processFeedInfo";
	&writeLog("$SEPERATOR") if ($DEBUG);
	&writeLog("\t\t\t Starting $func ") if ($DEBUG);
	&writeLog("$SEPERATOR") if ($DEBUG);
    	
	my @headerField 		= split( /$CONF_HASH{INPUT_DELIMITER}/, $HEADER_LINE );
	my $timeStampFromUII 	= $headerField[2];
	my $feedInfoFilename 	= "Feed_Info_" . $timeStampFromUII . ".info";
	my @headerList 			= split( /\,/, $CONF_HASH{HEADER_RECORDS} );
	my @recordList 			= split( /\,/, $CONF_HASH{REQUIRED_RECORDS} );

	if( open( INFO, ">>", "$CONF_HASH{OUTPUT_PATH}/" . $feedInfoFilename ) )
	{
		print INFO "HEADER=" . $HEADER_LINE . "\n";
		print INFO "UNIQUE_IDENTIFIER=" . $timeStampFromUII . "\n";
		print INFO "PARSER_NAME=" . $CONF_HASH{PARSER_NAME} . "\n";
		print INFO "REQUIRED_RECORD=" . $CONF_HASH{REQUIRED_RECORDS} . "\n";
		print INFO "OUTPUT_DELIMITER=" . $CONF_HASH{OUTPUT_DELIMITER} . "\n";
		
		#-- CSV file details --
		foreach my $recordType (@recordList) 
		{
			my $fileName = $ENV{BASE_PATH} . $CONF_HASH{OUTPUT_PATH} . "Record" . $recordType . "_" . $timeStampFromUII . ".csv";
	
			if ( -e $fileName ) 
			{
				my ($fileSize) = ( -s $fileName ) / 1024;
				print INFO $recordType . "_FEED_FILE=" . $fileName . "\n";
				print INFO $recordType . "_FILE_SIZE_KB=" . sprintf( "%.3f", $fileSize ) . "\n";
				
				my $numberOfLines = 0;
				
				if( open( SH, "<", "$fileName" ) )
				{
					$numberOfLines++ while <SH>;
					close SH;
					print INFO $recordType . "_FILE_LINE_NUMBERS=" . $numberOfLines . "\n";
				}
				else
				{
					&writeLog("ERROR [" . $func . "] Unable to read file-[$fileName].");
				}
				
				# -- From config file
				print INFO $recordType . "_PRIMARY_KEY=" . $CONF_HASH{ $recordType . "_PRIMARY_KEY" } . "\n";
				print INFO $recordType . "_FIELD_TYPE=" . $CONF_HASH{ $recordType . "_FIELD_TYPE" } . "\n";
				print INFO $recordType . "_TABLE=" . $CONF_HASH{ $recordType . "_TABLE" } . "\n";
			}
			else
			{
				&writeLog("ERROR [" . $func . "] Unable to retrive file-[$fileName].");
			}
		}
		close INFO;
	}
	else
	{
		&writeLog("ERROR [" . $func  . "] : Unable to generate feed info file [$feedInfoFilename]");
	}
}

sub initConfig {	

	$INPUT_DIR   = "$BASE_PATH/$CONF_HASH{INPUT_PATH}";
	$OUTPUT_DIR  = "$BASE_PATH/$CONF_HASH{OUTPUT_PATH}";
	$ARCHIVE_DIR = "$BASE_PATH/$CONF_HASH{ARCHIVE_PATH}";
	
	$DEBUG = $CONF_HASH{DEBUG};
	
	@HEADER_TYPE = split( /\,/, $CONF_HASH{HEADER_RECORDS} );
	@RECORD_TYPE = split( /\,/, $CONF_HASH{REQUIRED_RECORDS} );
}

sub initRecordLineHash
{
	#-- Init hash keys -----------
	# $RECORD_LINE{09} = 09 LINE;
	# $RECORD_LINE{59} = 59 LINES;
	#-----------------------------
	
	$RECORD_LINE{'01'} = ();
	$RECORD_LINE{'99'} = ();
	
	foreach $_ (@HEADER_TYPE) {
		$RECORD_LINE{$_} = ();
	}

	foreach $_ (@RECORD_TYPE) {
		$RECORD_LINE{$_} = ();
	}
}

sub processReadConf {

	my ($cfgFilePath) = @_;
	my $func = "processReadConfig";
	open( CONF, "<$cfgFilePath" )
	  || ( &writeLog("ERROR : Could not open configuration file $cfgFilePath to read: $!")
		 && exit(1) );

	while ( my $line = <CONF> ) {
		if ( $line !~ /^#/ && $line =~ /\w+/ ) {
			chomp($line);

			#---Remove any space from the conf file
			$line =~ s/^\s|\s+$//;
			$line =~ s/\s*=\s*/=/g;
			my ( $parameter, $value ) = split( '=', $line );

			#---Store configuration parameter and its value in global hash to be referenced by any modules
			$CONF_HASH{$parameter} = $value;
			&writeLog("SYSTEMCONF [" . $func . "]: " . $parameter . " => " .  $value) if ($DEBUG);
		}
	}

	# --- Create directories that do not exist
	&makeDir();
	close CONF;
}

sub sendEmail {
    my ( $subject, $message ) = @_;
    my $func = "sendEmail";
    &writeLog("INFO [" . $func . "] : Error logged. Sending mail to ASG....") if ($DEBUG);
    my $msg = MIME::Lite->new(
        From    => $CONF_HASH{EMAIL_FROM},
        To      => $CONF_HASH{EMAIL_TO},
        Subject => $subject,
        Data    => $message
    );
    $msg->attr( "content-type" => "text/html" );
    $msg->send( "smtp", $CONF_HASH{EMAIL_SMTP} );
    &writeLog("INFO [" . $func . "] : Email sent to ASG.");
}

sub makeDir {
	my $func = "makeDir";
	
	if ( !-e $BASE_PATH . $INPUT_DIR ) {
		mkdir $BASE_PATH . $INPUT_DIR;
	}
	if ( !-e $BASE_PATH . $OUTPUT_DIR ) {
		mkdir $BASE_PATH . $OUTPUT_DIR;
	}
	if ( !-e $BASE_PATH . $ARCHIVE_DIR ) {
		mkdir $BASE_PATH . $ARCHIVE_DIR;
	}
	if ( !-e $BASE_PATH . "/dbexport" ) {
		mkdir $BASE_PATH . "/dbexport";
	}
}

sub createLog {

	my $logDir    = $_[0];
	my $setupName = $_[1];
	my $func = "createLog";
	my @timeNow  = localtime(time);
	my $tyear    = $timeNow[5] + 1900;
	my $tmonth   = $timeNow[4] + 1;
	my $tday     = $timeNow[3];
	my $thour    = $timeNow[2];
	my $tmin     = $timeNow[1];
	my $tsec     = $timeNow[0];
	my $thisDate = sprintf( "%04d_%02d_%02d", $tyear, $tmonth, $tday );

	my $logFile = $logDir . $setupName . "_" . $thisDate . ".log";

	if ( open( LOG, ">>$logFile" ) ) {
		&writeLog("$SEPERATOR") if ($DEBUG);
		&writeLog("File: $logFile");
		&writeLog("Description: Starting $setupName Process!");
	}
	else {
	#	print "ERROR [" . $func . "] : Unable to create Log file handler at $logDir directory with $logFile file name!\n";
	}
}

sub writePid {
	my $func = "writePid";
	&writeLog("$SEPERATOR") if ($DEBUG);
    	&writeLog("\t\t\t Starting $func ") if ($DEBUG);
    	&writeLog("$SEPERATOR") if ($DEBUG);
    	
	open( FH, '<', $BASE_PATH . $PIDFILE );
	my $pid = <FH>;
	chomp $pid;
	&writeLog("INFO [" . $func . "] : Process ID -> " . $pid);
	close FH;
}

sub writeLog {
	my ($logMsg) = @_;
	my @timeNow  = localtime(time);
	my $lyear    = $timeNow[5] + 1900;
	my $lmonth   = $timeNow[4] + 1;
	my $lday     = $timeNow[3];
	my $lhour    = $timeNow[2];
	my $lmin     = $timeNow[1];
	my $lsec     = $timeNow[0];
	my $thisTime = sprintf( "%04d/%02d/%02d %02d:%02d:%02d", $lyear, $lmonth, $lday, $lhour, $lmin, $lsec );

	# print "$thisTime | $logMsg \n";
	print LOG "$thisTime | $logMsg \n";
}

sub closeLog {
	&outro();
	close LOG;
}

sub currentTime {

	# Current time stamps; l - log
	my @timeNow  = localtime(time);
	my $lyear    = $timeNow[5] + 1900;
	my $lmonth   = $timeNow[4] + 1;
	my $lday     = $timeNow[3];
	my $lhour    = $timeNow[2];
	my $lmin     = $timeNow[1];
	my $lsec     = $timeNow[0];
	my $thisTime = sprintf( "%04d%02d%02d%02d%02d%02d", $lyear, $lmonth, $lday, $lhour, $lmin, $lsec );
	return $thisTime;
}

# ----------------------------------------- REMOVE FILES ------------------------------------------------

sub removeOldFiles {
	
	&writeLog("$SEPERATOR")                      if ($DEBUG);
	&writeLog("Starting deleteOldFiles... ") if ($DEBUG);
	&writeLog("$SEPERATOR")                      if ($DEBUG);
	my $func = "removeOldFiles";
	
	&writeLog("INFO [" . $func . "] : Removing old archived and log files.." ) if ($DEBUG);
	# Purge archive and log files
	&deleteOldFiles( $ARCHIVE_DIR, ( $CONF_HASH{RETENTION_DAY} * ( 24 * 60 * 60 ) ) );
	&deleteOldFiles( $LOG_PATH,     ( $CONF_HASH{RETENTION_DAY} * ( 24 * 60 * 60 ) ) );
	&deleteOldFiles( $BASE_PATH . "dbexport/", ( $CONF_HASH{RETENTION_DAY} * ( 24 * 60 * 60 ) ) );
}

sub deleteOldFiles {
	
	my $func = "deleteOldFiles";
	my ( $dirPath, $retentionPeriod ) = @_;
	&writeLog("INFO [" . $func . "] : Removing files older than " . $CONF_HASH{RETENTION_DAY} . " day(s) in " . $dirPath) if ($DEBUG);
	
	if ( opendir( DIRH, $dirPath ) ) {
		my $currentTime = time;
		foreach my $file ( readdir(DIRH) ) {

			#---Excluding directory symbol
			next if ( $file =~ /^\.|^\.\./ );
			my $absFileName = $dirPath . $file;

			#---File creation time stamp
			my $statTime = ( stat($absFileName) )[9];
			my $diff     = ( $currentTime - $statTime );
			
			#---Deleting all files which are older than retention period
			if ( $retentionPeriod && ( $currentTime - $statTime ) > ($retentionPeriod) ) {
				&writeLog("WARN [" . $func . "] : File (" . $absFileName . ") has exceeded the retention period.") if ($DEBUG);
				&writeLog("INFO [" . $func . "] : Deleting file: $absFileName") if ($DEBUG);
				unlink $absFileName;
			}
		}
	}
	else {
		&writeLog(" ERROR [" . $func . "] : Could not open the directory $dirPath for cleanup : $!\n");
	}
	closedir DIRH;
}

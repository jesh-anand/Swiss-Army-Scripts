#!/usr/bin/perl -w
#=================================================================================================================
# Name          : ThresholdUpdate.pl
# Description   : To set thresholds for cisco 6500 ,CRS-1/CRS-3,Alcatel 7750 SR-12, Juniper T640, T1600, TX Matrix, M320, Ericsson/Redback SE800  and Cisco NXD devices on basis of cardtype using the Card_Threshold.cfg file as reference.
# Author        : shankar.kashamshetty@bt.com,rajani.kalakuntla@bt.com,yepchoon.wearn@bt.com,tianhuat.tan@bt.com and venkatesh.chowla@bt.com
# Date          : 12 March 2014
#-----------------------------------------------------------------------------------------------------------------
# Copyright(c)  : BT Plc, UK, 2012
# Version       : 1.2
#-----------------------------------------------------------------------------------------------------------------


use warnings;
use strict;
use POSIX;

my $baseAppPath = $ARGV[0];
my $debug ;
my $dlcfg;
my $noArgs = scalar(@ARGV);
my $confDIR = $baseAppPath."/conf";
my $logDIR= $baseAppPath."/loadinfo/";
my $dataDIR = $baseAppPath."/data";
my $seDBFile = $dataDIR."/SEFromDB.txt";
my $lastRunFile = $dataDIR."/lastRun.txt";
my $configFile= $confDIR."/Card_Threshold.cfg";
my %configHash = ();
my @DiscFrmids = ();
my @elementDetails = ();
my %thresholdHash = ();
my $endtime;
my $runFormget = 0;
my $outputFile = "$dataDIR"."/Thresholds_subelements.dat";
my $ThresholdFile = "$dataDIR"."/Thresholds_Master.dat";
my $OptSEDBFile = $dataDIR."/OptSEFromDB.txt";


if (!-d "$logDIR")
 {
		`mkdir -p $logDIR`;
 }
&createLog($logDIR);

if (!-d "$confDIR")
 {
		writeLog("ERROR: Config directory $confDIR does not exist,cannot proceed...\nTerminating process");
		exit(0);
 }
if (!-d "$dataDIR")
 {
	`mkdir -p $dataDIR`;
 }
 
if(open (OFH, ">$outputFile"))
{
	print OFH "#frm.dbIndex segp.dbIndex se.dbIndex thrStat mode prdEnabled prdWrnngLevelbr stCrtclTime prdCrtclTime brstEnabled blMaxNbDays brstWrnngLevel blCalcMode blGenEvent prdCrtclLevel blMinNbDays prdGenEvent blTime thrCalc brstCrtclLevel blUpper blEnabled brstWrnngTime blMode brstGenEvent prdPeriod prdWrnngTime thrCalcValue blLower\n";
}
else
{
	writeLog("ERROR:Unable to open $outputFile");
}

#================ Main starts here =====================#
&readConfigFile($configFile);
&SEExportFromDB();
&RunFormget() if($runFormget);
&FindCardThreshold();
close OFH;
&setThreshold();
&deleteOldFiles($logDIR,3);
close LOG;

#================ Main ends here ======================#

#======================================================================================
# Name 		    : SEExportFromDB
# Description   : To extract sub-elements from Database for cisco CRS-1/CRS-3,6500 and Alcatel 7750 SR12 devices
# Input		    :  
# Output	    : Extracted Subelements are written into file SEFromDB.txt
# Author	    : Shankar kashamshetty
# Date		    : October 01
#======================================================================================
 
sub SEExportFromDB
{
	writeLog("Started SEExportFromDB") if ($debug);
	if($noArgs == 1)
	 {
		my $cisresmgrCommand;
		my $cisasrresmgrCommand;
		my $alnresmgrCommand;
		my $redresmgrCommand;
		my $junresmgrCommand;
		my $orcnxdresmgrCommand;
		my $cisharresmgrCommand;
		my $cisranresmgrCommand;
		my $junharresmgrCommand;
		my $junranresmgrCommand;
		$runFormget = 1;
		if(-e $lastRunFile)
		{
			my @startTimeArray = readFile($lastRunFile);	
			my $startTime = join('',@startTimeArray);
			$endtime = time;
			# 21CNCE-65949 Adding CISCO ASR 1002-X in BT_MODEL list : Rajani K 
			# BTWCE-34441 and BTWCE-34463 Adding Juniper MX960 in BT_MODEL list
			$cisresmgrCommand = qq@resmgr -noHead -ListForced "seprp.CardType:value" -export segp -colNames "se.dbIndex se.name se.instance se.label seprp.CardType:value seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_MODEL:value eprp.ipAddress:value dbIndex seprp.BT_SE_USAGE:value" -filterRule "%(eprp.BT_MODEL:value) IN ('CRS-1','CRS-3','CAT6500','CISCO ASR 1002-X') AND %(fam.name) IN ('Cisco_Temperature_Sensor','Cisco_CPU_Unit','Cisco_Memory_Pool','Cisco_Voltage_Sensor','Cisco_NVRAM')" -filter "npath(~NOC Reporting~21CN Reporting~Additional Granularity for Threshold~System*) se.date(between '$startTime and $endtime')" > $seDBFile@;
			#21CNCE-74060 Adding support for ASR9922 and Nexus 6004 devices : Rajani K
			$cisasrresmgrCommand = qq@resmgr -noHead -ListForced "seprp.CardType:value" -export segp -colNames "se.dbIndex se.name se.instance se.label seprp.CardType:value seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_MODEL:value eprp.ipAddress:value dbIndex seprp.BT_SE_USAGE:value" -filterRule "%(eprp.BT_MODEL:value) IN ('ASR-9922','Nexus 6004') AND %(fam.name) IN ('Cisco_Temperature_Sensor_RSN','Cisco_CPU_Unit_RSN','Cisco_Memory_Pool_RSN')" -filter "npath(~NOC Reporting~21CN Reporting~RSN*) se.date(between '$startTime and $endtime')" >> $seDBFile@;	
			#21CNCE-74060 Adding support for NXD Server Sun Fire X4150 : Venkatesh Chowla
			$orcnxdresmgrCommand = qq@resmgr -noHead -ListForced "seprp.storageType:value" -export segp -colNames "se.dbIndex se.name se.instance se.label seprp.storageType:value seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_MODEL:value eprp.ipAddress:value dbIndex npath" -filterRule "%(eprp.BT_MODEL:value) IN ('Sun Fire X4150') AND %(fam.name) IN ('Generic_Memory_RSN')" -filter "npath(~NOC Reporting~21CN Reporting~RSN*) se.date(between '$startTime and $endtime')" >> $seDBFile@;	
			$alnresmgrCommand = qq@resmgr -noHead -ListForced "seprp.AlcatelCardType:value" -export segp -colNames "se.dbIndex se.name se.instance se.label seprp.AlcatelCardType:value seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_MODEL:value eprp.ipAddress:value segp.dbIndex npath" -filterRule "%(seprp.BT_SE_MODEL:value) IN ('7750 SR-12') AND %(fam.name) IN ('7750_Temp_Sensor','7750_CPM_Card')" -filter "npath(~NOC Reporting~21CN Reporting~Additional Granularity for Threshold~System*) se.date(between '$startTime and $endtime')" >> $seDBFile@;	
			$redresmgrCommand = qq@resmgr -noHead -ListForced -export segp -colNames "se.dbIndex se.name se.instance se.label seprp.DeviceVendor:value seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_MODEL:value eprp.ipAddress:value segp.dbIndex fam.name npath" -filterRule "%(seprp.BT_SE_MODEL:value) IN ('SE800') AND %(fam.name) IN ('Redback_Env_Temperature','Redback_Sys_CPU','Redback_Sys_Memory')" -filter "npath(~NOC Reporting~21CN Reporting~Additional Granularity for Threshold~System*) se.date(between '$startTime and $endtime')" >> $seDBFile@;
			$junresmgrCommand = qq@resmgr -noHead -ListForced -export segp -colNames "se.dbIndex se.name se.instance se.label seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_MODEL:value eprp.ipAddress:value segp.dbIndex fam.name npath" -filterRule "%(seprp.BT_SE_MODEL:value) IN ('Juniper T640','T1600','Juniper TX Matrix','Juniper M320','MX960') AND %(fam.name) IN ('Juniper_Chassis')" -filter "npath(~NOC Reporting~21CN Reporting~Additional Granularity for Threshold~System*) se.date(between '$startTime and $endtime')" >> $seDBFile@;
			#21CNCE-72648 Adding support for Juniper MX960 for HAR and Juniper MX960,Cisco ASR 1006 for RAN:Brandon
			#21CNCE-83501 Adding support for Juniper EX4550 for HAR:Harish
			$junharresmgrCommand = qq@resmgr -noHead -ListForced -export segp -colNames "se.dbIndex se.name se.instance se.label seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_MODEL:value eprp.ipAddress:value segp.dbIndex fam.name npath" -filterRule "%(seprp.BT_SE_MODEL:value) IN ('MX960','EX4550-32F') AND %(fam.name) IN ('Juniper_Chassis')" -filter "npath(~NOC Reporting~21CN Reporting~HAR~System Stats*) se.date(between '$startTime and $endtime')" >> $seDBFile@;
			$junranresmgrCommand = qq@resmgr -noHead -ListForced -export segp -colNames "se.dbIndex se.name se.instance se.label seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_MODEL:value eprp.ipAddress:value segp.dbIndex fam.name npath" -filterRule "%(seprp.BT_SE_MODEL:value) IN ('MX960') AND %(fam.name) IN ('Juniper_Chassis')" -filter "npath(~NOC Reporting~21CN Reporting~RAN~System Stats*) se.date(between '$startTime and $endtime')" >> $seDBFile@;   
			#21CNCE-72648 Prajesh - Adding support for Cisco 10000 and CAT 4900 for both RAN and HAR
			#21CNCE-72622:Jan 13th 2015 Brandon - Adding support for Cisco 1113 and Cisco 9124 
            $cisharresmgrCommand = qq@resmgr -noHead -ListForced "seprp.CardType:value" -export segp -colNames "se.dbIndex se.name se.instance se.label seprp.CardType:value seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_MODEL:value eprp.ipAddress:value dbIndex seprp.BT_SE_USAGE:value" -filterRule "%(eprp.BT_MODEL:value) IN ('CAT6500','CISCO 10000','CAT 4900','MDS 9124','CSACS-Express 5.0') AND %(fam.name) IN ('1213_Device','Cisco_Temperature_Sensor','Cisco_CPU_Unit','Cisco_Memory_Pool','Cisco_10K_Temperature','Cisco_10K_Memory','Cisco_CAT49_Temperature','Cisco_CAT49_Memory','Cisco_1113_Memory','Cisco_1113_CPU')" -filter "npath(~NOC Reporting~21CN Reporting~HAR~System Stats*) se.date(between '$startTime and $endtime')" >> $seDBFile@;
            $cisranresmgrCommand = qq@resmgr -noHead -ListForced "seprp.CardType:value" -export segp -colNames "se.dbIndex se.name se.instance se.label seprp.CardType:value seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_MODEL:value eprp.ipAddress:value dbIndex seprp.BT_SE_USAGE:value" -filterRule "%(eprp.BT_MODEL:value) IN ('CAT6500','ASR-1006','ASR-1001','ASR-9010','CISCO 10000','CAT 4900','MDS 9124','CSACS-Express 5.0') AND %(fam.name) IN ('1213_Device','Cisco_Temperature_Sensor','Cisco_CPU_Unit','Cisco_Memory_Pool','Cisco_Temperature_Sensor_ASR_RAN','Cisco_Memory_Pool_ASR_RAN','Cisco_10K_Temperature','Cisco_10K_Memory','Cisco_CAT49_Temperature','Cisco_CAT49_Memory','Cisco_1113_Memory','Cisco_1113_CPU')" -filter "npath(~NOC Reporting~21CN Reporting~RAN~System Stats*) se.date(between '$startTime and $endtime')" >> $seDBFile@;
		}
		else
		{
			$endtime = time;
			# 21CNCE-65949 Adding CISCO ASR 1002-X in BT_MODEL list  
			# BTWCE-34441 and BTWCE-34463 Adding Juniper MX960 in BT_MODEL list
			$cisresmgrCommand = qq@resmgr -noHead -ListForced "seprp.CardType:value" -export segp -colNames "se.dbIndex se.name se.instance se.label seprp.CardType:value seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_MODEL:value eprp.ipAddress:value dbIndex seprp.BT_SE_USAGE:value" -filterRule "%(eprp.BT_MODEL:value) IN ('CRS-1','CRS-3','CAT6500','CISCO ASR 1002-X') AND %(fam.name) IN ('Cisco_Temperature_Sensor','Cisco_CPU_Unit','Cisco_Memory_Pool','Cisco_Voltage_Sensor','Cisco_NVRAM')" -filter "npath(~NOC Reporting~21CN Reporting~Additional Granularity for Threshold~System*)" > $seDBFile@;
			#21CNCE-74060 Adding support for ASR9922 and Nexus 6004 devices : Rajani K
			$cisasrresmgrCommand = qq@resmgr -noHead -ListForced "seprp.CardType:value" -export segp -colNames "se.dbIndex se.name se.instance se.label seprp.CardType:value seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_MODEL:value eprp.ipAddress:value dbIndex seprp.BT_SE_USAGE:value" -filterRule "%(eprp.BT_MODEL:value) IN ('ASR-9922','Nexus 6004') AND %(fam.name) IN ('Cisco_Temperature_Sensor_RSN','Cisco_CPU_Unit_RSN','Cisco_Memory_Pool_RSN')" -filter "npath(~NOC Reporting~21CN Reporting~RSN*)" >> $seDBFile@;
			#21CNCE-74060 Adding support for NXD Server Sun Fire X4150 : Venkatesh Chowla
			$orcnxdresmgrCommand = qq@resmgr -noHead -ListForced "seprp.storageType:value" -export segp -colNames "se.dbIndex se.name se.instance se.label seprp.storageType:value seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_MODEL:value eprp.ipAddress:value dbIndex npath" -filterRule "%(eprp.BT_MODEL:value) IN ('Sun Fire X4150') AND %(fam.name) IN ('Generic_Memory_RSN')" -filter "npath(~NOC Reporting~21CN Reporting~RSN*)" >> $seDBFile@;	
			$alnresmgrCommand = qq@resmgr -noHead -ListForced "seprp.AlcatelCardType:value" -export segp -colNames "se.dbIndex se.name se.instance se.label seprp.AlcatelCardType:value seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_MODEL:value eprp.ipAddress:value segp.dbIndex npath" -filterRule "%(seprp.BT_SE_MODEL:value) IN ('7750 SR-12') AND %(fam.name) IN ('7750_Temp_Sensor','7750_CPM_Card')" -filter "npath(~NOC Reporting~21CN Reporting~Additional Granularity for Threshold~System*)" >> $seDBFile@;
			$redresmgrCommand = qq@resmgr -noHead -ListForced -export segp -colNames "se.dbIndex se.name se.instance se.label seprp.DeviceVendor:value seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_MODEL:value eprp.ipAddress:value segp.dbIndex fam.name npath" -filterRule "%(seprp.BT_SE_MODEL:value) IN ('SE800') AND %(fam.name) IN ('Redback_Env_Temperature','Redback_Sys_CPU','Redback_Sys_Memory')" -filter "npath(~NOC Reporting~21CN Reporting~Additional Granularity for Threshold~System*)" >> $seDBFile@;
			$junresmgrCommand = qq@resmgr -noHead -ListForced -export segp -colNames "se.dbIndex se.name se.instance se.label seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_MODEL:value eprp.ipAddress:value segp.dbIndex fam.name npath" -filterRule "%(seprp.BT_SE_MODEL:value) IN ('Juniper T640','T1600','Juniper TX Matrix','Juniper M320','MX960') AND %(fam.name) IN ('Juniper_Chassis')" -filter "npath(~NOC Reporting~21CN Reporting~Additional Granularity for Threshold~System*)" >> $seDBFile@;
			#21CNCE-72648 Adding support for Juniper MX960 for HAR and Juniper MX960,Cisco ASR 1006 for RAN:Brandon
			#21CNCE-83501 Adding support for Juniper EX4550 for HAR:Harish
			$junharresmgrCommand = qq@resmgr -noHead -ListForced -export segp -colNames "se.dbIndex se.name se.instance se.label seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_MODEL:value eprp.ipAddress:value segp.dbIndex fam.name npath" -filterRule "%(seprp.BT_SE_MODEL:value) IN ('MX960','EX4550-32F') AND %(fam.name) IN ('Juniper_Chassis')" -filter "npath(~NOC Reporting~21CN Reporting~HAR~System Stats*)" >> $seDBFile@;
			$junranresmgrCommand = qq@resmgr -noHead -ListForced -export segp -colNames "se.dbIndex se.name se.instance se.label seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_MODEL:value eprp.ipAddress:value segp.dbIndex fam.name npath" -filterRule "%(seprp.BT_SE_MODEL:value) IN ('MX960') AND %(fam.name) IN ('Juniper_Chassis')" -filter "npath(~NOC Reporting~21CN Reporting~RAN~System Stats*)" >> $seDBFile@;
			#21CNCE-72648 Adding support for Cisco ASR 1006,1001,9010 for RAN:Brandon
            #21CNCE-72648 Adding support for Cisco 10000 and CAT 4900 for both RAN and HAR - Prajesh
			#21CNCE-72622:Jan 13th 2015 Brandon - Adding support for Cisco 1113 and Cisco 9124
            $cisharresmgrCommand = qq@resmgr -noHead -ListForced "seprp.CardType:value" -export segp -colNames "se.dbIndex se.name se.instance se.label seprp.CardType:value seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_MODEL:value eprp.ipAddress:value dbIndex seprp.BT_SE_USAGE:value" -filterRule "%(eprp.BT_MODEL:value) IN ('CAT6500','CISCO 10000','CAT 4900','MDS 9124','CSACS-Express 5.0') AND %(fam.name) IN ('1213_Device','Cisco_Temperature_Sensor','Cisco_CPU_Unit','Cisco_Memory_Pool','Cisco_10K_Temperature','Cisco_10K_Memory','Cisco_CAT49_Temperature','Cisco_CAT49_Memory','Cisco_1113_Memory','Cisco_1113_CPU')" -filter "npath(~NOC Reporting~21CN Reporting~HAR~System Stats*)" >> $seDBFile@;
           	$cisranresmgrCommand = qq@resmgr -noHead -ListForced "seprp.CardType:value" -export segp -colNames "se.dbIndex se.name se.instance se.label seprp.CardType:value seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_MODEL:value eprp.ipAddress:value dbIndex seprp.BT_SE_USAGE:value" -filterRule "%(eprp.BT_MODEL:value) IN ('CAT6500','ASR-1006','ASR-1001','ASR-9010','CISCO 10000','CAT 4900','MDS 9124','CSACS-Express 5.0') AND %(fam.name) IN ('1213_Device','Cisco_Temperature_Sensor','Cisco_CPU_Unit','Cisco_Memory_Pool','Cisco_Temperature_Sensor_ASR_RAN','Cisco_Memory_Pool_ASR_RAN','Cisco_10K_Temperature','Cisco_10K_Memory','Cisco_CAT49_Temperature','Cisco_CAT49_Memory','Cisco_1113_Memory','Cisco_1113_CPU')" -filter "npath(~NOC Reporting~21CN Reporting~RAN~System Stats*)" >> $seDBFile@;				
		}
		writeLog("sub-element export resmgr:$cisresmgrCommand started");
		`$cisresmgrCommand`;
		writeLog("sub-element export resmgr:$cisasrresmgrCommand started");
		`$cisasrresmgrCommand`;
		writeLog("sub-element export resmgr:$orcnxdresmgrCommand started");
		`$orcnxdresmgrCommand`;
		writeLog("sub-element export resmgr:$alnresmgrCommand started");
		`$alnresmgrCommand`;
		writeLog("sub-element export resmgr:$redresmgrCommand started");
		`$redresmgrCommand`;
		writeLog("sub-element export resmgr:$junresmgrCommand started");
		`$junresmgrCommand`;
		#21CNCE-72648 Adding suppoort for Juniper MX960 for HAR and RAN network
		writeLog("sub-element export resmgr:$junharresmgrCommand started");
		`$junharresmgrCommand`;
		writeLog("sub-element export resmgr:$junranresmgrCommand started");
		`$junranresmgrCommand`;        
		writeLog("sub-element export resmgr:$cisharresmgrCommand started");
		`$cisharresmgrCommand`;
		writeLog("sub-element export resmgr:$cisranresmgrCommand started");
		`$cisranresmgrCommand`;
		
		my @resmgroutput = readFile($seDBFile);
		if ($resmgroutput[0] =~ /^Error/)
		{
			writeLog("Extraction of sub-elements from DB failed,cannot continue....Terminating...");
				exit(0);
		}
		if (-e $ThresholdFile)
		{
			if(open (THRFILE, $ThresholdFile))
			{
					my @Thresholds = <THRFILE>;
					close THRFILE;
					foreach my $line(@Thresholds)
					{
							my($frmIndex,$npath,$sedbIndex) = split('\|_\|',$line);
							$thresholdHash{$sedbIndex} = 1;
					}
			}
			else
			{
				writeLog("ERROR: Unable to open  $ThresholdFile file ");
			}
			if(open (OPTF,">$OptSEDBFile"))
			{
				foreach my $line(@resmgroutput)
				{
						my($outputSedbIndex) = split('\|_\|',$line);
						if(!defined($thresholdHash{$outputSedbIndex}))
						{
							print OPTF "$line\n";
						}
				}
				close OPTF;
			}
			else
			{
			writeLog("ERROR: Unable to open $OptSEDBFile file");
			}
	    }     
		else
		{
			$OptSEDBFile = $seDBFile;
		}
		writeLog("sub-element export finished");
	}
	if($noArgs >= 2)
	{
		#21CNCE-65949 : Adding support for Cisco ASR Route Reflector and removing 'Cisco_Voltage_Sensor' from list of families as we are not monitoring voltage : Rajani K
		my $resmgrCommand;
		my $cisasrresmgrCommand;
		my $cisranresmgrCommand;
		my $orcnxdresmgrCommand;
		my $junharresmgrCommand;
		my $junranresmgrCommand;
		#Prajesh - 21CNCE-72648 Adding support for Cisco 10008 and CAT 4900 for HAR
		my $cisharresmgrCommand;
		if ($ARGV[1] eq 'CIS')
		{
			if(defined $ARGV[2])
			{
				if ($ARGV[2] eq 'CISCO ASR 1002-X')
				{
					#21CNCE-72795 May 12 2014 : Setting specific thresholds for Cisco ASR 1002-X devices based on BT_NE_USAGE : Rajani K
					if(defined $ARGV[3] && $ARGV[3] eq 'BB NAT Offload')
					{

							$resmgrCommand = qq@resmgr -noHead -ListForced "seprp.CardType:value" -export segp -colNames "se.dbIndex se.name se.instance se.label seprp.CardType:value seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_MODEL:value eprp.ipAddress:value dbIndex seprp.BT_SE_USAGE:value" -filterRule "%(eprp.BT_MODEL:value) IN ('CISCO ASR 1002-X') AND %(eprp.BT_NE_USAGE:value) IN ('BB NAT Offload') AND %(fam.name) IN ('Cisco_Temperature_Sensor','Cisco_CPU_Unit','Cisco_Memory_Pool')" -filter "npath(~NOC Reporting~21CN Reporting~Additional Granularity for Threshold~System*)" > $seDBFile@;
					}
					elsif(defined $ARGV[3] && $ARGV[3] eq 'Route Reflector')
					{
								$resmgrCommand = qq@resmgr -noHead -ListForced "seprp.CardType:value" -export segp -colNames "se.dbIndex se.name se.instance se.label seprp.CardType:value seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_MODEL:value eprp.ipAddress:value dbIndex seprp.BT_SE_USAGE:value" -filterRule "%(eprp.BT_MODEL:value) IN ('CISCO ASR 1002-X') AND %(eprp.BT_NE_USAGE:value) IN ('Route Reflector') AND %(fam.name) IN ('Cisco_Temperature_Sensor','Cisco_CPU_Unit','Cisco_Memory_Pool')" -filter "npath(~NOC Reporting~21CN Reporting~Additional Granularity for Threshold~System*)" > $seDBFile@;

					}
					else
					{
								$resmgrCommand = qq@resmgr -noHead -ListForced "seprp.CardType:value" -export segp -colNames "se.dbIndex se.name se.instance se.label seprp.CardType:value seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_MODEL:value eprp.ipAddress:value dbIndex seprp.BT_SE_USAGE:value" -filterRule "%(eprp.BT_MODEL:value) IN ('CISCO ASR 1002-X') AND %(fam.name) IN ('Cisco_Temperature_Sensor','Cisco_CPU_Unit','Cisco_Memory_Pool')" -filter "npath(~NOC Reporting~21CN Reporting~Additional Granularity for Threshold~System*)" > $seDBFile@;

					}
				}
				#21CNCE-74060 :Adding support for ASR9922 and Nexus 6004 devices : Rajani K
				if ($ARGV[2] eq 'ASR-9922')
				{
					$resmgrCommand = qq@resmgr -noHead -ListForced "seprp.CardType:value" -export segp -colNames "se.dbIndex se.name se.instance se.label seprp.CardType:value seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_MODEL:value eprp.ipAddress:value dbIndex npath" -filterRule "%(eprp.BT_MODEL:value) IN ('ASR-9922') AND %(fam.name) IN ('Cisco_Temperature_Sensor_RSN','Cisco_CPU_Unit_RSN','Cisco_Memory_Pool_RSN')" -filter "npath(~NOC Reporting~21CN Reporting~RSN*)" > $seDBFile@;
				}
				if ($ARGV[2] eq 'Nexus 6004')
				{
					$resmgrCommand = qq@resmgr -noHead -ListForced "seprp.CardType:value" -export segp -colNames "se.dbIndex se.name se.instance se.label seprp.CardType:value seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_MODEL:value eprp.ipAddress:value dbIndex npath" -filterRule "%(eprp.BT_MODEL:value) IN ('Nexus 6004') AND %(fam.name) IN ('Cisco_Temperature_Sensor_RSN')" -filter "npath(~NOC Reporting~21CN Reporting~RSN*)" > $seDBFile@;
				}
                
                # Azman - 21CNCE-72635 - Add support for Cisco CAT6500
                if ($ARGV[2] eq 'CAT6500') {
                    			$cisranresmgrCommand = qq@resmgr -noHead -ListForced "seprp.CardType:value" -export segp -colNames "se.dbIndex se.name se.instance se.label seprp.CardType:value seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_MODEL:value eprp.ipAddress:value dbIndex npath" -filterRule "%(eprp.BT_MODEL:value) IN ('CAT6500') AND %(fam.name) IN ('Cisco_Temperature_Sensor','Cisco_CPU_Unit','Cisco_Memory_Pool')" -filter "npath(~NOC Reporting~21CN Reporting~HAR~System Stats*)" > $seDBFile@;
                    			$cisharresmgrCommand = qq@resmgr -noHead -ListForced "seprp.CardType:value" -export segp -colNames "se.dbIndex se.name se.instance se.label seprp.CardType:value seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_MODEL:value eprp.ipAddress:value dbIndex npath" -filterRule "%(eprp.BT_MODEL:value) IN ('CAT6500') AND %(fam.name) IN ('Cisco_Temperature_Sensor','Cisco_CPU_Unit','Cisco_Memory_Pool')" -filter "npath(~NOC Reporting~21CN Reporting~RAN~System Stats*)" >> $seDBFile@;
				}
				#21CNCE-72648 Adding support for Cisco ASR 1006 for RAN:Brandon
				if ($ARGV[2] eq 'ASR-1006'){
					$resmgrCommand = qq@resmgr -noHead -ListForced "seprp.CardType:value" -export segp -colNames "se.dbIndex se.name se.instance se.label seprp.CardType:value seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_MODEL:value eprp.ipAddress:value dbIndex npath" -filterRule "%(eprp.BT_MODEL:value) IN ('ASR-1006') AND %(fam.name) IN ('Cisco_CPU_Unit','Cisco_Temperature_Sensor','Cisco_Memory_Pool_ASR_RAN')" -filter "npath(~NOC Reporting~21CN Reporting~RAN~System Stats*)" >> $seDBFile@;					
				}
				#Prajesh - 21CNCE-72648 Adding support for Cisco 10008 and CAT 4900 for RAN and HAR
				if ($ARGV[2] eq 'CISCO 10000') {
					$cisranresmgrCommand = qq@resmgr -noHead -ListForced "seprp.CardType:value" -export segp -colNames "se.dbIndex se.name se.instance se.label seprp.CardType:value seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_MODEL:value eprp.ipAddress:value dbIndex npath" -filterRule "%(eprp.BT_MODEL:value) IN ('CISCO 10000') AND %(fam.name) IN ('Cisco_CPU_Unit','Cisco_10K_Temperature','Cisco_10K_Memory')" -filter "npath(~NOC Reporting~21CN Reporting~RAN~System Stats*)" > $seDBFile@;
					$cisharresmgrCommand = qq@resmgr -noHead -ListForced "seprp.CardType:value" -export segp -colNames "se.dbIndex se.name se.instance se.label seprp.CardType:value seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_MODEL:value eprp.ipAddress:value dbIndex npath" -filterRule "%(eprp.BT_MODEL:value) IN ('CISCO 10000') AND %(fam.name) IN ('Cisco_CPU_Unit','Cisco_10K_Temperature','Cisco_10K_Memory')" -filter "npath(~NOC Reporting~21CN Reporting~HAR~System Stats*)" >> $seDBFile@;
				}
				if ($ARGV[2] eq 'CAT 4900') {
					$cisranresmgrCommand = qq@resmgr -noHead -ListForced "seprp.CardType:value" -export segp -colNames "se.dbIndex se.name se.instance se.label seprp.CardType:value seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_MODEL:value eprp.ipAddress:value dbIndex npath" -filterRule "%(eprp.BT_MODEL:value) IN ('CAT 4900') AND %(fam.name) IN ('Cisco_CPU_Unit','Cisco_CAT49_Temperature', 'Cisco_CAT49_Memory')" -filter "npath(~NOC Reporting~21CN Reporting~RAN~System Stats*)" > $seDBFile@;
					$cisharresmgrCommand = qq@resmgr -noHead -ListForced "seprp.CardType:value" -export segp -colNames "se.dbIndex se.name se.instance se.label seprp.CardType:value seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_MODEL:value eprp.ipAddress:value dbIndex npath" -filterRule "%(eprp.BT_MODEL:value) IN ('CAT 4900') AND %(fam.name) IN ('Cisco_CPU_Unit','Cisco_CAT49_Temperature', 'Cisco_CAT49_Memory')" -filter "npath(~NOC Reporting~21CN Reporting~HAR~System Stats*)" >> $seDBFile@;
				}
				#21CNCE-72648 Adding support for Cisco ASR 1001 for RAN:Brandon
				if ($ARGV[2] eq 'ASR-1001'){
					$resmgrCommand = qq@resmgr -noHead -ListForced "seprp.CardType:value" -export segp -colNames "se.dbIndex se.name se.instance se.label seprp.CardType:value seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_MODEL:value eprp.ipAddress:value dbIndex npath" -filterRule "%(eprp.BT_MODEL:value) IN ('ASR-1001') AND %(fam.name) IN ('Cisco_CPU_Unit','Cisco_Temperature_Sensor','Cisco_Memory_Pool_ASR_RAN')" -filter "npath(~NOC Reporting~21CN Reporting~RAN~System Stats*)" >> $seDBFile@;					
				}
				#21CNCE-72648 Adding support for Cisco ASR 9010 for RAN:Brandon
				if ($ARGV[2] eq 'ASR-9010'){
					$resmgrCommand = qq@resmgr -noHead -ListForced "seprp.CardType:value" -export segp -colNames "se.dbIndex se.name se.instance se.label seprp.CardType:value seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_MODEL:value eprp.ipAddress:value dbIndex npath" -filterRule "%(eprp.BT_MODEL:value) IN ('ASR-9010') AND %(fam.name) IN ('Cisco_CPU_Unit','Cisco_Temperature_Sensor_ASR_RAN','Cisco_Memory_Pool')" -filter "npath(~NOC Reporting~21CN Reporting~RAN~System Stats*)" >> $seDBFile@;					
				}
				#21CNCE-72622:Jan 13th 2015 Brandon - Adding support for Cisco 1113 and Cisco 9124 
				if ($ARGV[2] eq 'MDS 9124'){
					$cisranresmgrCommand = qq@resmgr -noHead -ListForced "seprp.CardType:value" -export segp -colNames "se.dbIndex se.name se.instance se.label seprp.CardType:value seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_MODEL:value eprp.ipAddress:value dbIndex npath" -filterRule "%(eprp.BT_MODEL:value) IN ('MDS 9124') AND %(fam.name) IN ('1213_Device','Cisco_Temperature_Sensor')" -filter "npath(~NOC Reporting~21CN Reporting~RAN~System Stats*)" > $seDBFile@;
					$cisharresmgrCommand = qq@resmgr -noHead -ListForced "seprp.CardType:value" -export segp -colNames "se.dbIndex se.name se.instance se.label seprp.CardType:value seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_MODEL:value eprp.ipAddress:value dbIndex npath" -filterRule "%(eprp.BT_MODEL:value) IN ('MDS 9124') AND %(fam.name) IN ('1213_Device','Cisco_Temperature_Sensor')" -filter "npath(~NOC Reporting~21CN Reporting~HAR~System Stats*)" >> $seDBFile@;
				}
				if ($ARGV[2] eq 'CSACS-Express 5.0'){
					$cisranresmgrCommand = qq@resmgr -noHead -ListForced "seprp.CardType:value" -export segp -colNames "se.dbIndex se.name se.instance se.label seprp.CardType:value seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_MODEL:value eprp.ipAddress:value dbIndex npath" -filterRule "%(eprp.BT_MODEL:value) IN ('CSACS-Express 5.0') AND %(fam.name) IN ('Cisco_1113_Memory','Cisco_1113_CPU')" -filter "npath(~NOC Reporting~21CN Reporting~RAN~System Stats*)" > $seDBFile@;
					$cisharresmgrCommand = qq@resmgr -noHead -ListForced "seprp.CardType:value" -export segp -colNames "se.dbIndex se.name se.instance se.label seprp.CardType:value seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_MODEL:value eprp.ipAddress:value dbIndex npath" -filterRule "%(eprp.BT_MODEL:value) IN ('CSACS-Express 5.0') AND %(fam.name) IN ('Cisco_1113_Memory','Cisco_1113_CPU')" -filter "npath(~NOC Reporting~21CN Reporting~HAR~System Stats*)" >> $seDBFile@;
				}
            }
			else
			{
				$resmgrCommand = qq@resmgr -noHead -ListForced "seprp.CardType:value" -export segp -colNames "se.dbIndex se.name se.instance se.label seprp.CardType:value seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_MODEL:value eprp.ipAddress:value dbIndex npath" -filterRule "%(eprp.BT_MODEL:value) IN ('CRS-1','CRS-3','CAT6500','CISCO ASR 1002-X') AND %(fam.name) IN ('Cisco_Temperature_Sensor','Cisco_CPU_Unit','Cisco_Memory_Pool','Cisco_NVRAM')" -filter "npath(~NOC Reporting~21CN Reporting~Additional Granularity for Threshold~System*)" > $seDBFile@;
				#21CNCE-74060 Adding support for ASR9922 and Nexus 6004 devices : Rajani K
				$cisasrresmgrCommand = qq@resmgr -noHead -ListForced "seprp.CardType:value" -export segp -colNames "se.dbIndex se.name se.instance se.label seprp.CardType:value seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_MODEL:value eprp.ipAddress:value dbIndex npath" -filterRule "%(eprp.BT_MODEL:value) IN ('ASR-9922','Nexus 6004') AND %(fam.name) IN ('Cisco_Temperature_Sensor_RSN','Cisco_CPU_Unit_RSN','Cisco_Memory_Pool_RSN')" -filter "npath(~NOC Reporting~21CN Reporting~RSN*)" >> $seDBFile@;
				#21CNCE-72648 Adding support for Cisco ASR 1006,1001,9010 for RAN:Brandon
				#21CNCE-72648 Adding support for Cisco 10008 and CAT 4900 devices for both RAN and HAR
				#21CNCE-72622:Jan 13th 2015 Brandon - Adding support for Cisco 1113 and Cisco 9124 
				$cisranresmgrCommand = qq@resmgr -noHead -ListForced "seprp.CardType:value" -export segp -colNames "se.dbIndex se.name se.instance se.label seprp.CardType:value seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_MODEL:value eprp.ipAddress:value dbIndex npath" -filterRule "%(eprp.BT_MODEL:value) IN ('ASR-1006','ASR-1001','ASR-9010','CAT 4900', 'CISCO 10000','MDS 9124','CSACS-Express 5.0') AND %(fam.name) IN ('1213_Device','Cisco_CPU_Unit','Cisco_Temperature_Sensor','Cisco_Memory_Sensor','Cisco_Temperature_Sensor_ASR_RAN','Cisco_Memory_Pool_ASR_RAN', 'Cisco_10K_Temperature','Cisco_10K_Memory', 'Cisco_CAT49_Temperature', 'Cisco_CAT49_Memory','Cisco_1113_Memory','Cisco_1113_CPU')" -filter "npath(~NOC Reporting~21CN Reporting~RAN~System Stats*)" >> $seDBFile@;
				$cisharresmgrCommand = qq@resmgr -noHead -ListForced "seprp.CardType:value" -export segp -colNames "se.dbIndex se.name se.instance se.label seprp.CardType:value seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_MODEL:value eprp.ipAddress:value dbIndex seprp.BT_SE_USAGE:value" -filterRule "%(eprp.BT_MODEL:value) IN ('CAT 4900', 'CISCO 10000','MDS 9124','CSACS-Express 5.0') AND %(fam.name) IN ('1213_Device','Cisco_CPU_Unit','Cisco_10K_Temperature','Cisco_10K_Memory', 'Cisco_CAT49_Temperature', 'Cisco_CAT49_Memory','Cisco_1113_Memory','Cisco_1113_CPU')" -filter "npath(~NOC Reporting~21CN Reporting~HAR~System Stats*)" >> $seDBFile@;
				$runFormget = 1;
			}
		}
		elsif($ARGV[1] eq 'ALN')
		{
			if(not defined $ARGV[2])
			{
				$resmgrCommand = "resmgr -noHead -ListForced \"seprp.AlcatelCardType:value\" -export segp -colNames \"se.dbIndex se.name se.instance se.label seprp.AlcatelCardType:value seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_MODEL:value eprp.ipAddress:value segp.dbIndex npath\" -filterRule \"%(seprp.BT_SE_MODEL:value) IN ('7750 SR-12') AND %(fam.name) IN ('7750_Temp_Sensor','7750_CPM_Card')\"  -filter \"npath(~NOC Reporting~21CN Reporting~Additional Granularity for Threshold~System*)\" > $seDBFile ";
			}
		}
		elsif($ARGV[1] eq 'RED')
		{
			if(not defined $ARGV[2])
			{
				$resmgrCommand = "resmgr -noHead -ListForced -export segp -colNames \"se.dbIndex se.name se.instance se.label seprp.DeviceVendor:value seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_MODEL:value eprp.ipAddress:value segp.dbIndex fam.name npath\" -filterRule \"%(seprp.BT_SE_MODEL:value) IN ('SE800') AND %(fam.name) IN ('Redback_Env_Temperature','Redback_Sys_CPU','Redback_Sys_Memory')\" -filter \"npath(~NOC Reporting~21CN Reporting~Additional Granularity for Threshold~System*)\" > $seDBFile ";
			}
		}
		elsif($ARGV[1] eq 'JUN')
		{
			#BTWCE-34441 and BTWCE-34463 - Tan Tian Huat
			if(defined $ARGV[2])
			{
				if ($ARGV[2] eq 'JUNIPER MX960' )
				{
					$resmgrCommand = "resmgr -noHead -ListForced -export segp -colNames \"se.dbIndex se.name se.instance se.label seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_MODEL:value eprp.ipAddress:value segp.dbIndex fam.name npath\" -filterRule \"%(seprp.BT_SE_MODEL:value) IN ('MX960') AND %(fam.name) IN ('Juniper_Chassis')\" -filter \"npath(~NOC Reporting~21CN Reporting~Additional Granularity for Threshold~System*)\" > $seDBFile ";
					#21CNCE-72648 Adding suppoort for Juniper MX960 for HAR and RAN network
					$junharresmgrCommand = "resmgr -noHead -ListForced -export segp -colNames \"se.dbIndex se.name se.instance se.label seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_MODEL:value eprp.ipAddress:value segp.dbIndex fam.name npath\" -filterRule \"%(seprp.BT_SE_MODEL:value) IN ('MX960') AND %(fam.name) IN ('Juniper_Chassis')\" -filter \"npath(~NOC Reporting~21CN Reporting~HAR~System Stats*)\" >> $seDBFile ";
					$junranresmgrCommand = "resmgr -noHead -ListForced -export segp -colNames \"se.dbIndex se.name se.instance se.label seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_MODEL:value eprp.ipAddress:value segp.dbIndex fam.name npath\" -filterRule \"%(seprp.BT_SE_MODEL:value) IN ('MX960') AND %(fam.name) IN ('Juniper_Chassis')\" -filter \"npath(~NOC Reporting~21CN Reporting~RAN~System Stats*)\" >> $seDBFile ";
				}
				if ($ARGV[2] eq 'JUNIPER EX4550' )
				{
					#21CNCE-83501 Adding support for Juniper EX4550 for HAR:Harish
					$junharresmgrCommand = "resmgr -noHead -ListForced -export segp -colNames \"se.dbIndex se.name se.instance se.label seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_MODEL:value eprp.ipAddress:value segp.dbIndex fam.name npath\" -filterRule \"%(seprp.BT_SE_MODEL:value) IN ('EX4550-32F') AND %(fam.name) IN ('Juniper_Chassis')\" -filter \"npath(~NOC Reporting~21CN Reporting~HAR~System Stats*)\" > $seDBFile ";
				}
			}
			else
			{
				$resmgrCommand = "resmgr -noHead -ListForced -export segp -colNames \"se.dbIndex se.name se.instance se.label seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_MODEL:value eprp.ipAddress:value segp.dbIndex fam.name npath\" -filterRule \"%(seprp.BT_SE_MODEL:value) IN ('Juniper T640','T1600','Juniper TX Matrix','Juniper M320','MX960') AND %(fam.name) IN ('Juniper_Chassis')\" -filter \"npath(~NOC Reporting~21CN Reporting~Additional Granularity for Threshold~System*)\" > $seDBFile ";
				#21CNCE-83501 Adding support for Juniper EX4550 for HAR:Harish
				$junharresmgrCommand = "resmgr -noHead -ListForced -export segp -colNames \"se.dbIndex se.name se.instance se.label seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_MODEL:value eprp.ipAddress:value segp.dbIndex fam.name npath\" -filterRule \"%(seprp.BT_SE_MODEL:value) IN ('EX4550-32F') AND %(fam.name) IN ('Juniper_Chassis')\" -filter \"npath(~NOC Reporting~21CN Reporting~HAR~System Stats*)\" >> $seDBFile ";

			}
		}
			#12 March 2014: Rel AN: 21CNCE-74060 Adding support for NXD Server Sun Fire X4150 : Venkatesh Chowla
		elsif($ARGV[1] eq 'ORC')
		{
			if(defined $ARGV[2])
			{
				if ($ARGV[2] eq 'Sun Fire X4150')
				{
					$resmgrCommand = qq@resmgr -noHead -ListForced "seprp.storageType:value" -export segp -colNames "se.dbIndex se.name se.instance se.label seprp.storageType:value seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_MODEL:value eprp.ipAddress:value dbIndex npath" -filterRule "%(eprp.BT_MODEL:value) IN ('Sun Fire X4150') AND %(fam.name) IN ('Generic_Memory_RSN')" -filter "npath(~NOC Reporting~21CN Reporting~RSN*)" > $seDBFile@;	
				}
			}
			else
			{
				$resmgrCommand = qq@resmgr -noHead -ListForced "seprp.storageType:value" -export segp -colNames "se.dbIndex se.name se.instance se.label seprp.storageType:value seprp.BT_SE_SUPPLIER_ID:value seprp.BT_SE_MODEL:value eprp.ipAddress:value dbIndex npath" -filterRule "%(eprp.BT_MODEL:value) IN ('Sun Fire X4150') AND %(fam.name) IN ('Generic_Memory_RSN')" -filter "npath(~NOC Reporting~21CN Reporting~RSN*)" > $seDBFile@;
			}
		}
		
		if(defined $resmgrCommand) {
			writeLog("sub-element export resmgr:$resmgrCommand started");
			`$resmgrCommand`;
		}
		#March 05 2014 : 21CNCE-74060 Adding support for ASR9922 and Nexus 6004 devices : Rajani K
		if(defined $cisasrresmgrCommand)
	 	{
			writeLog("sub-element export resmgr:$cisasrresmgrCommand started");
			`$cisasrresmgrCommand`;
		} 
		if(defined $junharresmgrCommand)
		{
			writeLog("sub-element export resmgr:$junharresmgrCommand started");
			`$junharresmgrCommand`;		
		} 
		if(defined $junranresmgrCommand)
		{
			writeLog("sub-element export resmgr:$junranresmgrCommand started");
			`$junranresmgrCommand`;			
		}
		if(defined $cisranresmgrCommand)
		{
			writeLog("sub-element export resmgr:$cisranresmgrCommand started");
			`$cisranresmgrCommand`;			
		}
		if(defined $cisharresmgrCommand)
		{
			writeLog("sub-element export resmgr:$cisharresmgrCommand started");
			`$cisharresmgrCommand`;			
		}

		my @resmgroutput = readFile($seDBFile);
	   	if ($resmgroutput[0] =~ /^Error/)
		{
			writeLog("Extraction of sub-elements from DB failed,cannot continue...Terminating....");
			exit(0);
		}
		writeLog("sub-element export finished");
		$OptSEDBFile = $seDBFile;
		$endtime = 0;
	 }
	writeLog("Finished SEExportFromDB") if ($debug);
}

#======================================================================================
# Name 		    : FindCardThreshold
# Description	: To read all Subelement details from SEFromDB.txt and call FindThresholds function
# Input		    :  
# Output	    : Call to FindThresholds function
# Author	    : Shankar kashamshetty
# Date		    : October 01
#======================================================================================
sub FindCardThreshold
{
	writeLog("Starting FindCardThreshold function") if ($debug);
	my @lines = readFile($OptSEDBFile);
	writeLog("Reading SE DB File");
	foreach my $line (@lines) 
	{
		chomp $line;
              	next if ($line =~ m/Device\sView\~BRAS~Alcatel/);
		my ($dbIndex,$name,$instance,$label,$seCardType,$seSupplierId,$seModel,$seEleIp,$npath,$seFamilyName) = split('\|_\|',$line);
		FindThresholds($line,$dbIndex,$name,$instance,$label,$seCardType,$seSupplierId,$seModel,$seEleIp,$npath,$seFamilyName);
	}
	writeLog("Finished FindCardThreshold function") if ($debug);
}

#======================================================================================
# Name 		    : FindThresholds
# Description	: To read Subelement details from above function,find appropriate threshold values on basis of cardtype and write the import threshold commands to a file
# Input		    : $line,$dbIndex,$name,$instance,$label,$seCardType,$seSupplierId,$seModel,$seEleIp 
# Output	    : Thresholds_subelements.dat
# Author	    : Shankar kashamshetty
# Date		    : October 01
#======================================================================================

sub FindThresholds
{
	
	my ($line,$dbIndex,$name,$instance,$label,$seCardType,$seSupplierId,$seModel,$seEleIp,$segpdbIndex,$seFamilyName) = @_;
	#---To filter only Voltage,Memory,temperature,CPU and NVRAM subelements
	#12 March 2014: Rel AN: 21CNCE-74060 Adding support for NXD Server Instance(systemStorage) : Venkatesh Chowla
	#13 Jan 2015: Rel AS: 21CNCE-72622 Adding support for SAN Switch Cisco 9124(NULL) : brandon
	if( $instance =~ m/Temp/i || $instance =~ m/CPU/i || $instance =~ m/MemPool/i || $instance =~ m/NVRAM/i || $instance =~ m/VoltageSensor/i || $instance =~ m/cpmModule/i || $instance =~ m/SystemCPU/i || $instance =~ m/SystemMemory/i || $instance =~ m/SystemTemperatureId/i || $instance =~ m/ChassisSubject/i || $instance =~ m/systemStorage/i || $instance =~ m/ciscoMemoryPool/i || $instance =~ m/<NULL>/i || $label =~ m/Memory/i)
	{
		if($seSupplierId eq 'CIS')
		{
			if($seModel =~ /CRS/i || $seModel =~ /CAT6500/i )
			{
				if($seModel =~ /CRS/i && ($instance =~ m/TemperatureSensor/i || $instance =~ m/VoltageSensor/i))
				{
					$seCardType=FindCRSCardName($label,$seEleIp);	
					$seCardType =~ s/^\s+|\s+$//;
				}
				my $SubEleType= findSEType($instance);
				if( $seModel =~ /CRS/i )
				{
					$seSupplierId=$seSupplierId."CRS";
				}
				elsif( $seModel =~ /CAT6500/i )
				{
					$seSupplierId=$seSupplierId."CAT6500";			
				}
				foreach my $CardType (keys %{$configHash{$seSupplierId}{$SubEleType}})
				{
					 my($cardName,$sensor) = split(':',$CardType);
					 $cardName =~ s/^\s+|\s+$//;
					 $sensor =~ s/^\s+|\s+$//; 
					if($instance =~ m/TemperatureSensor/i && $seModel =~ m/CAT6500/i)
					{
						if ($seCardType =~ m/($cardName)/i && $label =~ m/($sensor)/i)
						{
						writeLog("Sub-element label:$label,Subelement CardType:$seCardType matched with config cardtype :$CardType") if ($debug);
						my $frmdbIndex = $configHash{METRIC}{$SubEleType};
						my $waitTime = $configHash{$seSupplierId}{$SubEleType}{$CardType}->{WAITTIME};
						my $CritcThre = $configHash{$seSupplierId}{$SubEleType}{$CardType}->{THRCRITIC};
						my $polPeriod = $configHash{$seSupplierId}{$SubEleType}{$CardType}->{POLPERIOD};
						writeThresholdFile($dbIndex,$frmdbIndex,$CritcThre,$waitTime,$polPeriod,$segpdbIndex);
						last;                          
						}
					}	
					if(($instance =~ m/TemperatureSensor/i || $instance =~ m/VoltageSensor/i) && ($instance =~ m/$SubEleType/i)  && $seModel =~ m/CRS/i)
					{				
						my $seLabel = $label;
						$seLabel =~ s/^\"|\"$//;
						my @seLabelinfo = split(/_/,$seLabel); 
						my @seLabelDetails = split(/-/,$seLabelinfo[1]);
						my $seLabelsensor;
						my $revseLabelsensor;
						my $length = scalar(@seLabelDetails);
						
						if ($length > 3)
						{
							$seLabelsensor = $seLabelDetails[$length-1];
							$seLabelsensor =~ s/^\s+|\s+$//;
							$seLabelsensor =~ s/\"//;
							$seLabelsensor =~ s/\>//;
							$revseLabelsensor = $seLabelsensor;
						}
						else
						{
							my $sensor1 = $seLabelDetails[$length-2];$sensor1=~ s/^\s+|\s+$//;
							my $sensor2 = $seLabelDetails[$length-1];$sensor2=~ s/^\s+|\s+$//;
							$seLabelsensor = join('-',$sensor1,$sensor2);
							$revseLabelsensor = join('-',$sensor2,$sensor1);
							$seLabelsensor =~ s/\s+//;
							$seLabelsensor =~ s/\"//;
							$seLabelsensor =~ s/\>//;
							$revseLabelsensor =~ s/\s+//;
							$revseLabelsensor =~ s/\"//;
							$revseLabelsensor =~ s/\>//;
						}
						if ($seLabelsensor =~ /-/ && $sensor =~ /-/)
						{
							my @configsensor = split(/-/,$sensor);
							my $sensor1 = $configsensor[0]; $sensor1 =~ s/^\s+|\s+$//;
							my $sensor2 = $configsensor[1]; $sensor2 =~ s/^\s+|\s+$//;
							my @Sesensor = split(/-/,$seLabelsensor);;
							my $seSensor1 = $Sesensor[0]; $seSensor1 =~ s/^\s+|\s+$//;
							my $seSensor2 = $Sesensor[1]; $seSensor2 =~ s/^\s+|\s+$//;
							if (($seCardType eq $cardName) && ($seSensor1 eq $sensor1 || $seSensor1 eq $sensor2) && ($seSensor2 eq $sensor1 || $seSensor2 eq $sensor2))
								{
								    writeLog("Sub-element label:$label,Subelement CardType:$seCardType matched with config cardtype :$CardType") if ($debug);
									my $frmdbIndex = $configHash{METRIC}{$SubEleType};
									my $waitTime = $configHash{$seSupplierId}{$SubEleType}{$CardType}->{WAITTIME};
									my $CritcThre = $configHash{$seSupplierId}{$SubEleType}{$CardType}->{THRCRITIC};
									my $polPeriod = $configHash{$seSupplierId}{$SubEleType}{$CardType}->{POLPERIOD};
									writeThresholdFile($dbIndex,$frmdbIndex,$CritcThre,$waitTime,$polPeriod,$segpdbIndex);
									last;
								}
						}
						if ($seLabelsensor !~ /-/)
						{
							if (($seCardType eq $cardName) && ($seLabelsensor eq $sensor))
								{
									writeLog("Sub-element label:$label,Subelement CardType:$seCardType matched with config cardtype :$CardType") if ($debug);
									my $frmdbIndex = $configHash{METRIC}{$SubEleType};
									my $waitTime = $configHash{$seSupplierId}{$SubEleType}{$CardType}->{WAITTIME};
									my $CritcThre = $configHash{$seSupplierId}{$SubEleType}{$CardType}->{THRCRITIC};
									my $polPeriod = $configHash{$seSupplierId}{$SubEleType}{$CardType}->{POLPERIOD};
									writeThresholdFile($dbIndex,$frmdbIndex,$CritcThre,$waitTime,$polPeriod,$segpdbIndex);
									last;
								}
						}
					}
				
					#------For CRS & 6500 CPU and Memory sub-elements
					if($instance =~ m/CPU/i || $instance =~ m/MemPool/i)
					{	
						my ($cardName,$sensor) = split(':',$CardType);
						if ($seCardType=~ m/($cardName)/i && $label =~ m/($sensor)/i && $instance =~ m/$SubEleType/)
						{
							writeLog("Sub-element label:$label,Subelement CardType:$seCardType matched with config cardtype :$CardType") if ($debug);
							my $frmdbIndex = $configHash{METRIC}{$SubEleType};
							my $waitTime = $configHash{$seSupplierId}{$SubEleType}{$CardType}->{WAITTIME};
							my $CritcThre = $configHash{$seSupplierId}{$SubEleType}{$CardType}->{THRCRITIC};
							my $polPeriod = $configHash{$seSupplierId}{$SubEleType}{$CardType}->{POLPERIOD};
							writeThresholdFile($dbIndex,$frmdbIndex,$CritcThre,$waitTime,$polPeriod,$segpdbIndex);
							last;
						}
						if($cardName =~ m/Linecards/i && $label =~ m/CPU\sof\sModule/i && $instance =~ m/$SubEleType/)
						{
							writeLog("Sub-element label:$label,Subelement CardType:$seCardType matched with config cardtype :$CardType") if ($debug);
							my $frmdbIndex = $configHash{METRIC}{$SubEleType};
							my $waitTime = $configHash{$seSupplierId}{$SubEleType}{$CardType}->{WAITTIME};
							my $CritcThre = $configHash{$seSupplierId}{$SubEleType}{$CardType}->{THRCRITIC};
							my $polPeriod = $configHash{$seSupplierId}{$SubEleType}{$CardType}->{POLPERIOD};
							writeThresholdFile($dbIndex,$frmdbIndex,$CritcThre,$waitTime,$polPeriod,$segpdbIndex);
							last;
						}
					}
				
					#----For CRS and 6500 NVRAM sub-elemnts-----
					if ($instance =~ m/NVRAM/)
					{  
						if ($instance =~ m/$SubEleType/ && $label =~ m/($sensor)/i)
						{
							writeLog("Sub-element label:$label,Subelement CardType:$seCardType matched with config cardtype :$CardType") if ($debug);
							my $frmdbIndex = $configHash{METRIC}{$SubEleType};
							my $waitTime = $configHash{$seSupplierId}{$SubEleType}{$CardType}->{WAITTIME};
							my $CritcThre = $configHash{$seSupplierId}{$SubEleType}{$CardType}->{THRCRITIC};
							my $polPeriod = $configHash{$seSupplierId}{$SubEleType}{$CardType}->{POLPERIOD};
							writeThresholdFile($dbIndex,$frmdbIndex,$CritcThre,$waitTime,$polPeriod,$segpdbIndex);
							last;
						}
					}			
				}
			}
			#21CNCE-65949 - Rajani K
			elsif($seModel eq "CISCO ASR 1002-X")
			{
				#21CNCE-72795 - Rajani K - May 16 2014
				#seFamilyName has BT_SE_USAGE for Cisco devices
				my $seusage = $seFamilyName;
				my $SubEleType= findSEType($instance);
				$seSupplierId = $seSupplierId. "CISCO ASR 1002-X".$seusage;
				foreach my $CardType (keys %{$configHash{$seSupplierId}{$SubEleType}})
				{
					if( ($instance =~ m/TemperatureSensor/i || $instance =~ m/CPU/ || $instance =~ m/MemPool/) && $seCardType =~ m/($CardType)/i)
					{   
							writeLog("Sub-element label:$label,Subelement CardType:$seCardType matched with config cardtype :$CardType") if ($debug);
							my $frmdbIndex = $configHash{METRIC}{$SubEleType};
							my $waitTime = $configHash{$seSupplierId}{$SubEleType}{$CardType}->{WAITTIME};
							my $CritcThre = $configHash{$seSupplierId}{$SubEleType}{$CardType}->{THRCRITIC};
							my $polPeriod = $configHash{$seSupplierId}{$SubEleType}{$CardType}->{POLPERIOD};
							writeThresholdFile($dbIndex,$frmdbIndex,$CritcThre,$waitTime,$polPeriod,$segpdbIndex);
							last;  
					}
				}
			
			}
			#Rel AN : 21CNCE-74060 - March 05 :Rajani K
			#Adding support for Cisco ASR-9922 and Nexus 6004 devices
			elsif($seModel eq "ASR-9922" || $seModel eq "Nexus 6004" )
			{
				my $SubEleType= findSEType($instance);
				if($seModel eq "ASR-9922")
				{
					$seSupplierId = $seSupplierId. "ASR-9922";
				}
				elsif($seModel eq "Nexus 6004")
				{
					$seSupplierId = $seSupplierId. "Nexus 6004";
				}
				my $setThreshold = 0;
				foreach my $CardType (keys %{$configHash{$seSupplierId}{$SubEleType}})
				{
					#Ignore the default entry given in the configuration file,so that it doesnot match with sub-elements having cardtype as default
					next if( $CardType eq "default" );
					if( ($instance =~ m/TemperatureSensor/i || $instance =~ m/CPU/ || $instance =~ m/MemPool/) && ($seCardType =~ m/($CardType)/i ))
					{   
							writeLog("Sub-element label:$label,Subelement CardType:$seCardType matched with config cardtype :$CardType") if ($debug);
							my $frmdbIndex = $configHash{METRIC}{$SubEleType};
							my $waitTime = $configHash{$seSupplierId}{$SubEleType}{$CardType}->{WAITTIME};
							my $CritcThre = $configHash{$seSupplierId}{$SubEleType}{$CardType}->{THRCRITIC};
							my $polPeriod = $configHash{$seSupplierId}{$SubEleType}{$CardType}->{POLPERIOD};
							writeThresholdFile($dbIndex,$frmdbIndex,$CritcThre,$waitTime,$polPeriod,$segpdbIndex);
							$setThreshold = 1;
							last;  
					}
				}
				#If the sub-element cardtype doesnot match with the configuration , set the default values 
				if($setThreshold == 0)
				{
					writeLog("Sub-element label:$label,Subelement CardType:$seCardType matched with default cardtype") if ($debug);
					my $frmdbIndex = $configHash{METRIC}{$SubEleType};
					my $waitTime = $configHash{$seSupplierId}{$SubEleType}{default}->{WAITTIME};
					my $CritcThre = $configHash{$seSupplierId}{$SubEleType}{default}->{THRCRITIC};
					my $polPeriod = $configHash{$seSupplierId}{$SubEleType}{default}->{POLPERIOD};
					writeThresholdFile($dbIndex,$frmdbIndex,$CritcThre,$waitTime,$polPeriod,$segpdbIndex);
					$setThreshold = 1;
				}
			
			}
            # Azman - 21CNCE-72635 - Add support for Cisco CAT6500
            elsif($seModel eq "CAT6500") {
				my $seusage = $seFamilyName;
				my $SubEleType= findSEType($instance);
				$seSupplierId = $seSupplierId. "CAT6500".$seusage;
				foreach my $CardType (keys %{$configHash{$seSupplierId}{$SubEleType}})
				{
					if( ($instance =~ m/TemperatureSensor/i || $instance =~ m/CPU/ || $instance =~ m/MemPool/) && $seCardType =~ m/($CardType)/i)
					{   
							writeLog("Sub-element label:$label,Subelement CardType:$seCardType matched with config cardtype :$CardType") if ($debug);
							my $frmdbIndex = $configHash{METRIC}{$SubEleType};
							my $waitTime = $configHash{$seSupplierId}{$SubEleType}{$CardType}->{WAITTIME};
							my $CritcThre = $configHash{$seSupplierId}{$SubEleType}{$CardType}->{THRCRITIC};
							my $polPeriod = $configHash{$seSupplierId}{$SubEleType}{$CardType}->{POLPERIOD};
							writeThresholdFile($dbIndex,$frmdbIndex,$CritcThre,$waitTime,$polPeriod,$segpdbIndex);
							last;  
					}
				}
			
			}
			#21CNCE-72648 Adding support for Cisco ASR 1006,1001,9010 for RAN:Brandon	
			#Prajesh - 21CNCE-72648 - Add support for Cisco 10008 and CAT 4900			
            elsif($seModel =~ /^(ASR-1006|ASR-1001|ASR-9010|CAT 4900|CISCO 10000)$/) {
				my $SubEleType= findSEType($instance);
				$seSupplierId = $seSupplierId. $seModel;
				my $defaultFlag = -1;			
				$defaultFlag = 1 if($instance =~ /CPU/ || $instance =~ /MemPool/ || $instance =~ /TemperatureSensor/ || $instance =~ /ciscoMemoryPool/);	
				# traverse to all specific cards name in cfg file and see which matches the criteria. ie. Inlet,Left
				# if SE labels matches any specific cards name and set default flag to false
				foreach my $CardType (keys %{$configHash{$seSupplierId}{$SubEleType}}){
					if($label =~ m/$CardType/i ){
						writeLog("Sub-element label:$label,Subelement CardType:$seCardType matched with config cardtype :$CardType") if ($debug);
						my $frmdbIndex = $configHash{METRIC}{$SubEleType};
						my $waitTime = $configHash{$seSupplierId}{$SubEleType}{$CardType}->{WAITTIME};
						my $CritcThre = $configHash{$seSupplierId}{$SubEleType}{$CardType}->{THRCRITIC};
						my $polPeriod = $configHash{$seSupplierId}{$SubEleType}{$CardType}->{POLPERIOD};
						writeThresholdFile($dbIndex,$frmdbIndex,$CritcThre,$waitTime,$polPeriod,$segpdbIndex);
						$defaultFlag = 0; 
						last;
					}
				}
				# default cards applies to CPU, Memory and TemperatureSensor
				if( $defaultFlag == 1 ){
							writeLog("Sub-element label:$label,Subelement CardType:$seCardType matched with default cardtype") if ($debug);
							my $frmdbIndex = $configHash{METRIC}{$SubEleType};
							my $waitTime = $configHash{$seSupplierId}{$SubEleType}{default}->{WAITTIME};
							my $CritcThre = $configHash{$seSupplierId}{$SubEleType}{default}->{THRCRITIC};
							my $polPeriod = $configHash{$seSupplierId}{$SubEleType}{default}->{POLPERIOD};
							writeThresholdFile($dbIndex,$frmdbIndex,$CritcThre,$waitTime,$polPeriod,$segpdbIndex);
				}
			}
			#21CNCE-72622:Jan 13th 2015 Brandon - Adding support for Cisco 1113 and Cisco 9124 
            elsif($seModel eq "CSACS-Express 5.0") {
				my $SubEleType= findSEType($label);
				$seSupplierId = $seSupplierId. $seModel;
				my $defaultFlag = -1;			
				$defaultFlag = 1 if($label =~ /CPU/ || $label =~ /Memory/);	
				foreach my $CardType (keys %{$configHash{$seSupplierId}{$SubEleType}}){
					if($label =~ m/$CardType/i){
						writeLog("Sub-element label:$label,Subelement CardType:$seCardType matched with config cardtype :$CardType") if ($debug);
						my $frmdbIndex = $configHash{METRIC}{$SubEleType};
						my $waitTime = $configHash{$seSupplierId}{$SubEleType}{$CardType}->{WAITTIME};
						my $CritcThre = $configHash{$seSupplierId}{$SubEleType}{$CardType}->{THRCRITIC};
						my $polPeriod = $configHash{$seSupplierId}{$SubEleType}{$CardType}->{POLPERIOD};
						writeThresholdFile($dbIndex,$frmdbIndex,$CritcThre,$waitTime,$polPeriod,$segpdbIndex);
						$defaultFlag = 0; 
						last;
					}
				}
				# default cards applies to CPU, Memory
				if( $defaultFlag == 1 ){
							writeLog("Sub-element label:$label,Subelement CardType:$seCardType matched with default cardtype") if ($debug);
							my $frmdbIndex = $configHash{METRIC}{$SubEleType};
							my $waitTime = $configHash{$seSupplierId}{$SubEleType}{default}->{WAITTIME};
							my $CritcThre = $configHash{$seSupplierId}{$SubEleType}{default}->{THRCRITIC};
							my $polPeriod = $configHash{$seSupplierId}{$SubEleType}{default}->{POLPERIOD};
							writeThresholdFile($dbIndex,$frmdbIndex,$CritcThre,$waitTime,$polPeriod,$segpdbIndex);
				}
			}		
			#21CNCE-72622:Jan 13th 2015 Brandon - Adding support for Cisco 1113 and Cisco 9124 
            elsif($seModel eq "MDS 9124") {
				my $SubEleType= findSEType($instance);
				$seSupplierId = $seSupplierId. $seModel;
				my $defaultFlag = -1;			
				$defaultFlag = 1 if($instance =~ /<NULL>/ || $instance =~ /TemperatureSensor/);	
				# Only applicable for temperature because cpu and memory is collected at the 1213_device level 
				foreach my $CardType (keys %{$configHash{$seSupplierId}{$SubEleType}}){
					if($label =~ m/$CardType/i ){
						writeLog("Sub-element label:$label,Subelement CardType:$seCardType matched with config cardtype :$CardType") if ($debug);
						my $frmdbIndex = $configHash{METRIC}{$SubEleType};
						my $waitTime = $configHash{$seSupplierId}{$SubEleType}{$CardType}->{WAITTIME};
						my $CritcThre = $configHash{$seSupplierId}{$SubEleType}{$CardType}->{THRCRITIC};
						my $polPeriod = $configHash{$seSupplierId}{$SubEleType}{$CardType}->{POLPERIOD};
						writeThresholdFile($dbIndex,$frmdbIndex,$CritcThre,$waitTime,$polPeriod,$segpdbIndex);
						$defaultFlag = 0; 
						last;
					}
				}
				# default cards applies to CPU, Memory and Temperature
				if( $defaultFlag == 1 ){
							if($instance =~ /<NULL>/){
								#default threshold for CPU and Memory
								writeLog("Sub-element label:$label,Subelement CardType:$seCardType matched with default cardtype") if ($debug);
								my $frmdbIndex1 = $configHash{METRIC}{CPU};
								my $waitTime1 = $configHash{$seSupplierId}{CPU}{default}->{WAITTIME};
								my $CritcThre1 = $configHash{$seSupplierId}{CPU}{default}->{THRCRITIC};
								my $polPeriod1 = $configHash{$seSupplierId}{CPU}{default}->{POLPERIOD};
								writeThresholdFile($dbIndex,$frmdbIndex1,$CritcThre1,$waitTime1,$polPeriod1,$segpdbIndex);		
								my $frmdbIndex2 = $configHash{METRIC}{MemPool};
								my $waitTime2 = $configHash{$seSupplierId}{MemPool}{default}->{WAITTIME};
								my $CritcThre2 = $configHash{$seSupplierId}{MemPool}{default}->{THRCRITIC};
								my $polPeriod2 = $configHash{$seSupplierId}{MemPool}{default}->{POLPERIOD};
								writeThresholdFile($dbIndex,$frmdbIndex2,$CritcThre2,$waitTime2,$polPeriod2,$segpdbIndex);								
							} else { 
								#default threshold for temperature
								writeLog("Sub-element label:$label,Subelement CardType:$seCardType matched with default cardtype") if ($debug);
								my $frmdbIndex = $configHash{METRIC}{$SubEleType};
								my $waitTime = $configHash{$seSupplierId}{$SubEleType}{default}->{WAITTIME};
								my $CritcThre = $configHash{$seSupplierId}{$SubEleType}{default}->{THRCRITIC};
								my $polPeriod = $configHash{$seSupplierId}{$SubEleType}{default}->{POLPERIOD};
								writeThresholdFile($dbIndex,$frmdbIndex,$CritcThre,$waitTime,$polPeriod,$segpdbIndex);
							}
				}
			}			
		}
		elsif($seSupplierId eq 'ALN')
		{
			
			my $SubEleType= findSEType($instance);
			if($seFamilyName =~ m/Redback_Sys/ || $seFamilyName =~ m/Redback_Env/ )
			{
				$seSupplierId = $seSupplierId. "SE800";
				my $seCardType = '';
				if($label =~ m/slot 7/i || $label =~ m/slot 8/i || $seFamilyName =~ m/Redback_Sys/)
				{
					$seCardType = 'XCRP-4 Controller Card';
				}
				else
				{
					$seCardType = '10x1G DDR Line Card';
				}
				writeLog("Family Name: $seFamilyName, Label:$label, Instance:$instance, Card Type:$seCardType") if ($debug);

					if($instance =~ m/SystemTemperatureId/i)
					{
						my $frmdbIndex = $configHash{METRIC}{TemperatureSensor};
						my $waitTime = $configHash{$seSupplierId}{$SubEleType}{$seCardType}->{WAITTIME};
						my $CritcThre = $configHash{$seSupplierId}{$SubEleType}{$seCardType}->{THRCRITIC};
						my $polPeriod = $configHash{$seSupplierId}{$SubEleType}{$seCardType}->{POLPERIOD};
						writeLog("Threshold:$CritcThre, Wait Time: $waitTime, Poll Period:$polPeriod, Card Type:$seCardType") if ($debug);
						writeThresholdFile($dbIndex,$frmdbIndex,$CritcThre,$waitTime,$polPeriod,$segpdbIndex);
					}
					elsif($instance =~ m/CPU/i)
					{
							my $frmdbIndex = $configHash{METRIC}{CPU};
							my $waitTime = $configHash{$seSupplierId}{$SubEleType}{$seCardType}->{WAITTIME};
							my $CritcThre = $configHash{$seSupplierId}{$SubEleType}{$seCardType}->{THRCRITIC};
							my $polPeriod = $configHash{$seSupplierId}{$SubEleType}{$seCardType}->{POLPERIOD};
							writeLog("Threshold:$CritcThre, Wait Time: $waitTime, Poll Period:$polPeriod, Card Type:$seCardType") if ($debug);
							writeThresholdFile($dbIndex,$frmdbIndex,$CritcThre,$waitTime,$polPeriod,$segpdbIndex); 
					}
					elsif($instance =~ m/SystemMemory/i)
					{
							my $frmdbIndex = $configHash{METRIC}{MemPool};
							my $waitTime = $configHash{$seSupplierId}{$SubEleType}{$seCardType}->{WAITTIME};
							my $CritcThre = $configHash{$seSupplierId}{$SubEleType}{$seCardType}->{THRCRITIC};
							my $polPeriod = $configHash{$seSupplierId}{$SubEleType}{$seCardType}->{POLPERIOD};
							writeLog("Threshold:$CritcThre, Wait Time: $waitTime, Poll Period:$polPeriod, Card Type:$seCardType") if ($debug);
							writeThresholdFile($dbIndex,$frmdbIndex,$CritcThre,$waitTime,$polPeriod,$segpdbIndex);	
					}
			}
			else
			{
				$seSupplierId = $seSupplierId. "7750 SR-12";
			
				foreach my $CardType (keys %{$configHash{$seSupplierId}{$SubEleType}})
				{
					if($instance =~ m/cpmModule/i && $seCardType =~ m/($CardType)/i)
					{
							writeLog("Sub-element label:$label,Subelement CardType:$seCardType matched with config cardtype :$CardType");
							my $cfrmdbIndex = $configHash{METRIC}{CPU};
							my $waitTime = $configHash{$seSupplierId}{$SubEleType}{$CardType}->{WAITTIME};
							my $CritcThre = $configHash{$seSupplierId}{$SubEleType}{$CardType}->{THRCRITIC};
							my $polPeriod = $configHash{$seSupplierId}{$SubEleType}{$CardType}->{POLPERIOD};
							my ($cpuCritcThre,$memCritcThre)= split(',',$CritcThre);
							my ($cpuwaitTime,$memwaitTime)= split(',' ,$waitTime);
							my ($cpupolPeriod,$mempolPeriod)=split(',',$polPeriod);
							writeThresholdFile($dbIndex,$cfrmdbIndex,$cpuCritcThre,$cpuwaitTime,$cpupolPeriod,$segpdbIndex);
							my $mfrmdbIndex = $configHash{METRIC}{MemPool};
							writeThresholdFile($dbIndex,$mfrmdbIndex,$memCritcThre,$memwaitTime,$mempolPeriod,$segpdbIndex);
						   last;  
					}	
					if($instance =~ m/TempSensor/i && $seCardType =~ m/($CardType)/i)
					{   
							writeLog("Sub-element label:$label,Subelement CardType:$seCardType matched with config cardtype :$CardType");
							my $frmdbIndex = $configHash{METRIC}{$SubEleType};
							my $waitTime = $configHash{$seSupplierId}{$SubEleType}{$CardType}->{WAITTIME};
							my $CritcThre = $configHash{$seSupplierId}{$SubEleType}{$CardType}->{THRCRITIC};
							my $polPeriod = $configHash{$seSupplierId}{$SubEleType}{$CardType}->{POLPERIOD};
							writeThresholdFile($dbIndex,$frmdbIndex,$CritcThre,$waitTime,$polPeriod,$segpdbIndex);
							last;  
					}
				}
			}
		}
		# For Juniper scenario
		elsif( $seFamilyName eq 'Juniper_Chassis' && ($seModel eq 'Juniper T640' || $seModel eq 'T1600' || $seModel eq 'Juniper TX Matrix' || $seModel eq 'Juniper M320' || $seModel eq 'MX960' || $seModel eq 'EX4550-32F') )
		{
			$seSupplierId	= 'JUN';

			if($seModel eq 'Juniper T640' || $seModel eq 'T1600' || $seModel eq 'Juniper TX Matrix' || $seModel eq 'Juniper M320')
			{
				$seSupplierId = $seSupplierId."Juniper T640, T1600, TX Matrix and M320";
				#For Juniper TX Matrix, T1600 and T640 Temperature FPC card
				if( $label =~ m/temp sensor/i ) 
				{
					my $SubEleType = 'TemperatureSensor';
					foreach my $junCardType (keys %{$configHash{$seSupplierId}{$SubEleType}})
					{
						if($label =~ m/$junCardType/i ){
							writeLog("Sub-element label:$label") if ($debug); 
							my $frmdbIndex = $configHash{METRIC}{$SubEleType};
							my $waitTime = $configHash{$seSupplierId}{$SubEleType}{$junCardType}->{WAITTIME};
							my $CritcThre = $configHash{$seSupplierId}{$SubEleType}{$junCardType}->{THRCRITIC};
							my $polPeriod = $configHash{$seSupplierId}{$SubEleType}{$junCardType}->{POLPERIOD};
							writeThresholdFile($dbIndex,$frmdbIndex,$CritcThre,$waitTime,$polPeriod,$segpdbIndex); 
							writeLog("$SubEleType Threshold $seModel:$CritcThre, Wait Time: $waitTime, Poll Period:$polPeriod") if ($debug);
							last;
						}
					}
				}
				else #For CPU, MEMORY, NVRAM and Temperature(only for M320) 
				{
					foreach my $SubEleType (keys %{$configHash{$seSupplierId}})
					{
						foreach my $junCardType (keys %{$configHash{$seSupplierId}{$SubEleType}})
						{
							next if ($seModel ne 'Juniper M320' && $SubEleType eq 'TemperatureSensor' && $junCardType eq 'fpc' ); 
							if($label =~ m/$junCardType/i ){
								writeLog("Sub-element label:$label") if ($debug);
								my $frmdbIndex = $configHash{METRIC}{$SubEleType};
								my $waitTime = $configHash{$seSupplierId}{$SubEleType}{$junCardType}->{WAITTIME};
								my $CritcThre = $configHash{$seSupplierId}{$SubEleType}{$junCardType}->{THRCRITIC};
								my $polPeriod = $configHash{$seSupplierId}{$SubEleType}{$junCardType}->{POLPERIOD};
								writeThresholdFile($dbIndex,$frmdbIndex,$CritcThre,$waitTime,$polPeriod,$segpdbIndex); 
								writeLog("$SubEleType Threshold $seModel:$CritcThre, Wait Time: $waitTime, Poll Period:$polPeriod") if ($debug);
								last;
							}
						}
					}
				}
			}
			#BTWCE-34441 and BTWCE-34463 - Tan Tian Huat
			elsif($seModel eq 'MX960')
			{
				$seSupplierId = $seSupplierId."JUNIPER MX960";
				foreach my $SubEleType (keys %{$configHash{$seSupplierId}})
				{
					foreach my $junCardType (keys %{$configHash{$seSupplierId}{$SubEleType}})
					{
						if($label =~ m/$junCardType/i )
						{
							writeLog("Sub-element label:$label") if ($debug);
							my $frmdbIndex = $configHash{METRIC}{$SubEleType};
							my $waitTime = $configHash{$seSupplierId}{$SubEleType}{$junCardType}->{WAITTIME};
							my $CritcThre = $configHash{$seSupplierId}{$SubEleType}{$junCardType}->{THRCRITIC};
							my $polPeriod = $configHash{$seSupplierId}{$SubEleType}{$junCardType}->{POLPERIOD};
							writeThresholdFile($dbIndex,$frmdbIndex,$CritcThre,$waitTime,$polPeriod,$segpdbIndex); 
							writeLog("$SubEleType Threshold $seModel:$CritcThre, Wait Time: $waitTime, Poll Period:$polPeriod") if ($debug);
							last;
						}
					}
				}
			}
			#21CNCE-83501 - Harish
			elsif($seModel eq 'EX4550-32F')
			{
				$seSupplierId = $seSupplierId."EX4550-32F";
				my $defaultFlag = 1;				

				foreach my $SubEleType (keys %{$configHash{$seSupplierId}})
				{
					foreach my $junCardType (keys %{$configHash{$seSupplierId}{$SubEleType}})
					{
						next if (($configHash{$seSupplierId}{$SubEleType}{$junCardType}) eq 'default');
						writeLog("Sub-element label:$label") if ($debug);							
						if($label =~ m/$junCardType/i ){
							my $frmdbIndex = $configHash{METRIC}{$SubEleType};
							my $waitTime = $configHash{$seSupplierId}{$SubEleType}{$junCardType}->{WAITTIME};
							my $CritcThre = $configHash{$seSupplierId}{$SubEleType}{$junCardType}->{THRCRITIC};
							my $polPeriod = $configHash{$seSupplierId}{$SubEleType}{$junCardType}->{POLPERIOD};
							writeThresholdFile($dbIndex,$frmdbIndex,$CritcThre,$waitTime,$polPeriod,$segpdbIndex);
							writeLog("$SubEleType Threshold $seModel:$CritcThre, Wait Time: $waitTime, Poll Period:$polPeriod") if ($debug);
							$defaultFlag = 0; 
							last;
						}
					}

					if( $defaultFlag == 1){
						if(exists($configHash{$seSupplierId}{$SubEleType}{"default"})){
							my $frmdbIndex = $configHash{METRIC}{$SubEleType};
							my $waitTime = $configHash{$seSupplierId}{$SubEleType}{default}->{WAITTIME};
							my $CritcThre = $configHash{$seSupplierId}{$SubEleType}{default}->{THRCRITIC};
							my $polPeriod = $configHash{$seSupplierId}{$SubEleType}{default}->{POLPERIOD};
							writeThresholdFile($dbIndex,$frmdbIndex,$CritcThre,$waitTime,$polPeriod,$segpdbIndex);
							writeLog("$SubEleType Threshold $seModel:$CritcThre, Wait Time: $waitTime, Poll Period:$polPeriod") if ($debug);
						}
					}
				}	
			}
		}
		########################For NXD Server###########################
		elsif($seSupplierId eq 'ORC')
		{
			if($seModel eq "Sun Fire X4150")
			{
				my $SubEleType= findSEType($instance);
				$seSupplierId = $seSupplierId."Sun Fire X4150";
				foreach my $CardType (keys %{$configHash{$seSupplierId}{$SubEleType}})
				{
					if( ($instance =~ m/systemStorage/i) && ($seCardType =~ m/($CardType)/i ))
					{   
							writeLog("Sub-element label:$label,Subelement CardType:$seCardType matched with config cardtype :$CardType") if ($debug);
							my $frmdbIndex = $configHash{METRIC}{$SubEleType};
							my $waitTime = $configHash{$seSupplierId}{$SubEleType}{$CardType}->{WAITTIME};
							my $CritcThre = $configHash{$seSupplierId}{$SubEleType}{$CardType}->{THRCRITIC};
							my $polPeriod = $configHash{$seSupplierId}{$SubEleType}{$CardType}->{POLPERIOD};
							writeThresholdFile($dbIndex,$frmdbIndex,$CritcThre,$waitTime,$polPeriod,$segpdbIndex);
							last;  
					}
				}
			
			}
		}
	}
}

#======================================================================================
# Name 		    : FindCRSCardName
# Description   : To match the pattern with formget output and return CardName for CRS temperature and voltage sub-elements 
# Input		    :
# Output	    : CardName for CRS temperature and voltage sub-elements
# Author	    : Shankar kashamshetty
# Date		    : October 01
#======================================================================================

sub FindCRSCardName()
{
	writeLog("Function:FindCRSCardName() Starts..") if ($debug); 
	my ($seLabel,$seEleIp) = @_;
	my $file = $seEleIp."formget";
	$file = $dataDIR."/$file";
	if(!(-e $file))
	{
		writeLog("Error: $file doesnot exit,verify formget execution");
		return;
	}
	my @forgetlines = readFile($file);
	foreach my $forgetline (@forgetlines)
	{
		my @output = split(/\|\|/,$forgetline);
		my @selabel = split(/_/,$seLabel);
		my @selabelpart = split(/-/,$selabel[1]);
		my $sepattern = $selabelpart[0];
		$sepattern =~ s/\"//;
		$sepattern =~ s/^\<//;
		chop($sepattern);
		$output[2] =~ m/.*<(.*)>.*<(.*)>/;
		if ($sepattern eq $1)
		{
			writeLog("CardName: $2") if ($debug);
			return $2;
		}
	}
	writeLog("Fun:FindCRSCardName() Ends.") if ($debug);
}

#======================================================================================
# Name 		    : RunFormget
# Description   : To execute Formget for metrics given by $configFile
# Input		    :
# Output	    : 
# Author	    : Shankar kashamshetty
# Date		    : October 01
#======================================================================================


#-----This function executes Forget for metrics given $configFile------
sub RunFormget()
{
	writeLog("Function:RunFormget Starts....") if ($debug); 
	foreach my $discid (keys %{$configHash{DISC}})
	{
				
			@DiscFrmids = $configHash{DISC}{$discid};
			writeLog("Discovery formula id is @DiscFrmids") if ($debug);
	}
	my $resmgrCommand = qq@resmgr -noHead -export elt -colNames "eprp.ipAddress:value scf.rcommunity collector profil" -filterRule "%(eprp.BT_MODEL:value) IN ('CRS-1','CRS-3')"@;
	my @elementlines= `$resmgrCommand`;
	my $processCount = 0;
	foreach my $fid (@DiscFrmids)
	{
        foreach my $elementline (@elementlines)
		{
			next if ($elementline !~ /\d+\.\d+\./);	
			my @elementDetails = split(/\|_\|/,$elementline);
			my ($ip,$CommString,$profile) = ($elementDetails[0],$elementDetails[1],$elementDetails[3]);
			my $ipFileName = $dataDIR."/$ip"."formget";
			my $DLName = getDLName($profile);
			if($processCount < 15)
			{
				my $pid = fork;
				if ($pid == 0)
				{
					my $formGetCommand = "formGet $ip -fid $fid -c \"$CommString\" -S $DLName > $ipFileName 2>&1";
					writeLog("formget command: $formGetCommand");
					`$formGetCommand`;
					exit;
				}
				else
				{
					$processCount++;
				}
			}
			else
			{	
       		   	while (waitpid(-1, &WNOHANG) != -1)
                 {
					sleep (5);
                  }
				my $formGetCommand = "formGet $ip -fid $fid -c \"$CommString\" -S $DLName > $ipFileName 2>&1";
				writeLog("formget command: $formGetCommand");
				`$formGetCommand`;
				$processCount = 0;
            }
		}
	}
	while (waitpid(-1, &WNOHANG) != -1)
        {
        	sleep (5);
        }
	
	foreach my $elementline (@elementlines)
    {
		my ($ip) = split(/\|_\|/,$elementline);
		my $ipFileName = $dataDIR."/$ip"."formget";
		if(open (FORMGETOUTPUT,$ipFileName))
		{
			my @forGetLines = <FORMGETOUTPUT>;
			close FORMGETOUTPUT;
			my @OutLines = ();
			foreach my $line (@forGetLines) 
			{
				$line =~ s/^\s*$//;
				next if ($line eq "");
				chomp $line;
				push(@OutLines,$line);
		    }
			my $joinedOutput = join('',@OutLines);

			# Detect errors in formGet
			if ($joinedOutput eq "") {
				writeLog("MAIN","ERROR: No output from formGet on $ip using formula ID=@DiscFrmids") if($debug);
			}
			elsif ($joinedOutput =~ /Invalid FormID/) {
				writeLog("MAIN","ERROR: Invalid FormID @DiscFrmids against file $ipFileName") if($debug);
			}
			elsif ($joinedOutput =~ /Host unreachable/) {
				writeLog("MAIN","ERROR: Host $ip is unreachable using formula ID=@DiscFrmids") if($debug);
			}
			elsif ($joinedOutput =~ /imeout/) {
				writeLog("MAIN","ERROR: Timeouts occurred on $ip.") if($debug);
			}
	    }
		else
		{
		writeLog("ERROR: Unable to open $ipFileName file");
		}
	}
	writeLog("Function:RunFormget completed ..") if ($debug);
}

#======================================================================================
# Name 		    : getDLName
# Description   : To get the dataload name
# Input		    :
# Output	    : 
# Author	    : Shankar kashamshetty
# Date		    : October 01
#======================================================================================

sub getDLName()
{
	my $profile = shift;
	my @profiles = readFile($dlcfg);
	foreach my $profileline (@profiles)
	{
		#Profile Name|_|BT_SUPPLIER_ID:BT_MODEL:BT_NE_USAGE:BT_NE_TYPE|_|Max Elements|_|Warning:Critical|_|DL Name|_|Collector number|_|DESC	
		chomp $profileline;
		my @profileDetails = split (/\|_\|/,$profileline);
		my $deviceType = $profileDetails[1]; 
 
		if ( $deviceType =~ /CRS-1/ || $deviceType =~ /CRS-3/)
		{
			if($profile eq $profileDetails[0])
			{
				writeLog("$profile...$profileDetails[0]") if ($debug);
				writeLog("$profileDetails[4]") if ($debug);
				return $profileDetails[4];
			} 
		}
	}
}

#======================================================================================
# Name 		    : readFile
# Description   : To Read a Input file and store all lines to an array. 
# Input		    : Any File
# Output	    : Array which contains all lines of file
# Author	    : Shankar kashamshetty
# Date		    : October 01
#======================================================================================

sub readFile
{
	my $filename = shift;
	return -1 if (!-f $filename || !-r $filename);
	
    if(open (FILEREAD, $filename)) 
	{	
         	writeLog("Reading File:$filename") if ($debug);
			my @templines = <FILEREAD>;
			my @lines =();
			foreach my $templine(@templines)
			{
				chomp $templine;
				next if ($templine=~ /^#/ || $templine=~/^\s*$/);
				$templine =~ s/^\s+|\s+$//g;
				if ($templine ne '')
				{
					push(@lines,$templine);
				}
			}
		close FILEREAD;
		return @lines;
    }
	else
	{
	writeLog("ERROR: Unable to open $filename file") if ($debug);
	}
}


#======================================================================================
# Name 		    : readConfigFile
# Description   : To Read the Config file and store all lines to a Hash. 
# Input		    : Configuration File (Card_Threshold.cfg)
# Output	    : Hash 
# Author	    : Shankar kashamshetty
# Date		    : October 01
#======================================================================================

sub readConfigFile
{
	my $filename = shift;
	if (! -e $filename) 
	{
		writeLog("ERROR: $filename file does not exists. Can't Proceed. Exiting.");
		exit(0);
	}
	writeLog("Reading File:$filename") if($debug);
	if(open (FILEREAD, $filename)) 
	{   
		my @configlines = <FILEREAD>;
		foreach my $configline (@configlines)
		{
			chomp $configline;
			next if ($configline =~ /^#/ || $configline =~/^\s*$/);
			$configline =~ s/^\s+|\s+$//g;
			
			my @configlineArray = split('\|_\|',$configline);
			if ($configlineArray[0] eq "DEBUG")
			{
				$debug = $configlineArray[1];
			}
			elsif ($configlineArray[0] eq "UIIPATH")
			{	
				$dlcfg = $configlineArray[1]."/Profile_Device.cfg";
			}
			elsif ($configlineArray[0] eq "METRIC")
			{	
				#METRIC|_|23542|_|Voltage Level|_|~AP~Generic~Universal~Other|_|VoltageSensor
				#Hash:METRIC->MetricName=MetricId for E.g METRIC->VoltageSensor=23542
				$configHash{$configlineArray[0]}->{$configlineArray[4]}=$configlineArray[1];
			}
			elsif ($configlineArray[0] eq "DISC")
			{
				#DISC|_|116201214|_|Cisco_Card_CRS|_|~Alias Instance and Label Inventory~21 CN~Cisco
				#Hash:DISC->DiscFrmName=DiscFrmId for E.g DISC->Cisco_Card_CRS=116201214
				$configHash{$configlineArray[0]}->{$configlineArray[2]} = $configlineArray[1];
			}
			else
			{				
				my $length = scalar(@configlineArray);
				if ( $length == 8 )
				{
					#ALN|_|7750 SR-12|_|TempSensor|_|sf|_||_|75|_|0|_|60m
					#Rel AN 21CNCE-74060 Storing Model Name in Hash
					my $supplierId =  $configlineArray[0];
					$supplierId =~ s/^\s+|\s+$//g;
					my $model =  $configlineArray[1];
					$model =~ s/^\s+|\s+$//g;
					my $subelementType =  $configlineArray[2];
					$subelementType =~ s/^\s+|\s+$//g;
					my $cardType = $configlineArray[3];
					$cardType =~ s/^\s+|\s+$//g;
					my $criticalValue = $configlineArray[5];
					$criticalValue =~ s/^\s+|\s+$//g;
					my $waitTime = $configlineArray[6];
					$waitTime =~ s/^\s+|\s+$//g;
					my $pollPeriod = $configlineArray[7];
					$pollPeriod =~ s/^\s+|\s+$//g;
					#21CNCE RelAN 74060 : Adding BT_MODEL also to Supplier id to make the key more unique: Rajani K
					
					my $key1 = $supplierId.$model;
					my $key2 = $subelementType;
					my $key3 = $cardType;

					$configHash{$key1}{$key2}{$key3}->{THRCRITIC} = $criticalValue;
					$configHash{$key1}{$key2}{$key3}->{WAITTIME} = $waitTime;
					$configHash{$key1}{$key2}{$key3}->{POLPERIOD} = $pollPeriod;
				}
				else
				{
					my $supplierId =  $configlineArray[0];
					$supplierId =~ s/^\s+|\s+$//g;
					my $model =  $configlineArray[1];
					$model =~ s/^\s+|\s+$//g;
					my $usage =  $configlineArray[2];
					$model =~ s/^\s+|\s+$//g;
					my $subelementType =  $configlineArray[3];
					$subelementType =~ s/^\s+|\s+$//g;
					my $cardType = $configlineArray[4];
					$cardType =~ s/^\s+|\s+$//g;
					my $criticalValue = $configlineArray[6];
					$criticalValue =~ s/^\s+|\s+$//g;
					my $waitTime = $configlineArray[7];
					$waitTime =~ s/^\s+|\s+$//g;
					my $pollPeriod = $configlineArray[8];
					$pollPeriod =~ s/^\s+|\s+$//g;
					#21CNCE RelAN 72795 : Adding BT_MODEL and NE_USAGE also to Supplier id to make the key more unique: Rajani K
					
					my $key1 = $supplierId.$model.$usage;
					my $key2 = $subelementType;
					my $key3 = $cardType;

					$configHash{$key1}{$key2}{$key3}->{THRCRITIC} = $criticalValue;
					$configHash{$key1}{$key2}{$key3}->{WAITTIME} = $waitTime;
					$configHash{$key1}{$key2}{$key3}->{POLPERIOD} = $pollPeriod;
				

				}
;
			}				
		}
		close FILEREAD;
		writeLog("Completed reading Configuration file:$filename");
	}
	else
	{
		writeLog("ERROR: Unable to open $filename file");
	}
	
	if($debug)
	{
		foreach my $key (keys %configHash)
		{
			writeLog("Value of key is:$key") if($debug);
			if($key eq "METRIC")
			{
				foreach my $frmname (keys %{$configHash{$key}})
				{
					writeLog("Metric id: $configHash{$key}->{$frmname}");
				}
			}
			elsif($key eq "DISC")
			{
				foreach my $frmname (keys %{$configHash{$key}})
				{
					writeLog("Disc id: $configHash{$key}->{$frmname}");
				}	
			}
			else
			{
				foreach my $Setype (keys %{$configHash{$key}})
				{
					foreach my $cardtype (keys %{$configHash{$key}{$Setype}})
					{
						writeLog("Cardtype:$cardtype|_|Critical value:$configHash{$key}{$Setype}{$cardtype}->{THRCRITIC}|_|Wait time:$configHash{$key}{$Setype}{$cardtype}->{WAITTIME}|_|Poll period:$configHash{$key}{$Setype}{$cardtype}->{POLPERIOD}");
					}
				}
			}
		}
	}
}

#======================================================================================
# Name 		    : writeThresholdFile
# Description   : Writes the threshold values to a file
# Input		    : $sedbindex,$frmdbIndex,$burstwar,$burstCritic,$waitpolls,$polPeriod
# Output	    : Thresholds File (Thresholds_subelements.dat)
# Author	    : Shankar kashamshetty
# Date		    : October 01
#======================================================================================
sub writeThresholdFile
{
	my($sedbindex,$frmdbIndex,$burstCritic,$waitpolls,$polPeriod,$npath) = @_;
	$polPeriod =~ s/m//;
	my $waittime = $waitpolls*$polPeriod*60;
	my $ThresholdValue = "$frmdbIndex|_|$npath|_|$sedbindex|_|0|_|2|_|0|_||_|$waittime|_||_|1|_||_||_||_|0|_||_||_|0|_||_|0|_|$burstCritic|_||_|0|_||_|1|_|1|_|1|_||_||_||_|";
	print OFH "$ThresholdValue\n";

}

#======================================================================================
# Name 		    : setThreshold
# Description	: Reads the Thresholds File (Thresholds_subelements.dat) and sets thresholds
# Input		    : Thresholds File (Thresholds_subelements.dat)
# Output	    : 
# Author	    : Shankar kashamshetty
# Date		    : October 01
#======================================================================================

sub setThreshold
{
	writeLog("Started setThreshold function");
	if(open (IN, $outputFile)) 
	{
	my @tempArr = <IN>;
	close IN;
	my $noLines = scalar(@tempArr);
		if ($noLines le 1) 
		{
			writeLog("No sub-elements to update.");
			return;
		}
		else 
		{
			my $importcmd = qq@resmgr -import thrdv -colNames "frm.dbIndex segp.dbIndex se.dbIndex thrStat mode prdEnabled prdWrnngLevel brstCrtclTime prdCrtclTime brstEnabled blMaxNbDays brstWrnngLevel blCalcMode blGenEvent prdCrtclLevel blMinNbDays prdGenEvent blTime thrCalc brstCrtclLevel blUpper blEnabled brstWrnngTime blMode brstGenEvent prdPeriod prdWrnngTime thrCalcValue blLower" -file $outputFile@;
			my @finalResult = `$importcmd`;
			my $count = scalar(@finalResult);
			my $totalcount = $count-1;
			writeLog("Threshold Insert/Update completed.");
			writeLog("Output is : \n @finalResult") if($debug);
			writeLog("THRCOUNT:Total Thresholds to be imported : $totalcount");
			my $failurecount =0;
			foreach my $fresult (@finalResult)
			{
			if($fresult =~/^Error/)
			{   
				$failurecount = $failurecount+1;
				writeLog("$fresult");
			} 
			}
			writeLog("THRCOUNT:Count of Thresholds failed to be imported : $failurecount");
			if($failurecount == $count)
			{
				writeLog("No Thresholds set");
				return;
			}
			else
			{
				my $bkpfile = $dataDIR."/lastRun_bkp.txt";
				if (-e $lastRunFile)
				{
					`rm $bkpfile` if(-e $bkpfile);
					`cp $lastRunFile $bkpfile`;
				}
				if ($endtime)
				{
					if(open (IN,">$lastRunFile"))
					{	
						print IN "$endtime\n"; 	
						close IN;
					}
					else
					{
						writeLog("ERROR: Unable to open $lastRunFile file");
					}	
				}
				my @outputArr = readFile($outputFile); 
				if(open (IN ,">>$ThresholdFile"))
				{
					foreach my $var (@outputArr)
					{
						print IN "$var\n";
					}
					close IN;
				}
				else
				{
				writeLog("ERROR: Unable to open $ThresholdFile file");
				}
			}
		}	
	}
    else
	{
		writeLog("ERROR: Unable to open $outputFile file");
	}  
	writeLog("Finished setThreshold function");
}


#======================================================================================
# Name 		    : findSEType
# Description   : To find the subelementtype of the subelement i.e to find if it is TemperatureSensor,VoltageSensor,CPU etc ...
# Input		    : Name of Instance 
# Output	    : SEType
# Author	    : Shankar kashamshetty
# Date		    : October 01
#======================================================================================

sub findSEType
{
	my $instance = $_[0];
	if ($instance =~m/TemperatureSensor/i)
	{ 	
		return("TemperatureSensor");	
	}
	elsif($instance =~m/MemPool/i)
	{
		return("MemPool");
	}
	# Added ciscoMemoryPool for Cisco 10008 and CAT 4900 devices
	elsif($instance =~m/ciscoMemoryPool/i)
	{
		return("MemPool");
	}
	elsif($instance =~m/VoltageSensor/i)
	{
		return("VoltageSensor");
	}
	elsif($instance =~m/CPU/i)
	{
		return("CPU");
	}
	elsif($instance =~m/NVRAM/i)
	{
		return("NVRAM");
	}
	elsif($instance =~m/CPM/i)
	{
		return("cpmModule");
	}
	elsif($instance =~m/TempSensor/i)
	{
		return("TempSensor");
	}
	elsif($instance =~m/SystemTemperatureId/i)
	{
		return("TemperatureSensor");
	}
	elsif($instance =~m/SystemMemory/i)
	{
		return("MemPool");
	}
	elsif($instance =~m/systemStorage/i)
	{
		return("systemStorage");
	}
	elsif($instance =~m/Memory/i)
	{
		return("MemPool");
	}
}

#======================================================================================
# Name 		    : createLog
# Description   : To Create a log file handler,creates logs in directory (loadinfo)
# Input		    : 
# Output	    : CardThreshold_<currentDate>.log , the currentdate would be date when log gets created
# Author	    : Shankar kashamshetty
# Date		    : October 01
#======================================================================================

sub createLog
{	
	my $logDir = $_[0];
	my @timeNow = localtime(time); 
	my $tyear = $timeNow[5]+1900; 
	my $tmonth =  $timeNow[4]+1; 
	my $tday =  $timeNow[3];
	my $thour =  $timeNow[2]; 
	my $tmin =  $timeNow[1];
	my $tsec =  $timeNow[0];
	my $thisDate = sprintf("%04d_%02d_%02d_%02d_%02d_%02d",$tyear,$tmonth,$tday,$thour,$tmin,$tsec);
	my $logFile = $logDir."CardThreshold_$thisDate.log";

	if (open(LOG,">$logFile"))
	{  
		writeLog("Description: Starting ThresholdUpdate!");
	}
	else
	{
		print "ERROR: Unable to create Log file handler at $logDir directory with $logFile file name!\n";
	} 
}

#======================================================================================
# Name 		    : writeLog
# Description   : To writes message in to log file in directory (loadinfo)
# Input		    : 
# Output	    : CardThreshold_<currentDate>.log , the currentdate would be date when log gets created
# Author	    : Shankar kashamshetty
# Date		    : October 01
#======================================================================================

sub writeLog 
{ 
	my ($logMsg) = @_; 
	# Current time stamps; l - log 
	my @timeNow = localtime(time); 
	my $lyear = $timeNow[5]+1900; 
	my $lmonth =  $timeNow[4]+1; 
	my $lday =  $timeNow[3]; 
	my $lhour =  $timeNow[2]; 
	my $lmin =  $timeNow[1]; 
	my $lsec =  $timeNow[0]; 
	my $thisTime = sprintf("%04d/%02d/%02d %02d:%02d:%02d",$lyear,$lmonth,$lday,$lhour,$lmin,$lsec); 
	
	print LOG "$thisTime | $logMsg\n"; 
}

sub deleteOldFiles 
{
	writeLog("Started deleteOldFiles ");
    	my ($dirPath, $retentionPeriod) = @_;
    	my $currentTime = time;  
	if( opendir (DIRH,$dirPath) )
	{			
        	foreach my $file ( readdir(DIRH)) 
		{
			my $absFileName = $dirPath.$file;
		    	#---File creation time stamp
            		my $statTime = (stat($absFileName))[9];
    			#---Deleting all files which are older than retaintion period (number of days)
            		if ( $retentionPeriod && ($currentTime - $statTime) > ($retentionPeriod* 24* 60 * 60) ) 
		    	{
			    my $cmd=qq@rm -rf $absFileName @;
			    writeLog("Unable to delete old file: $absFileName") if(system($cmd) != 0);
            		}
      		}
	}
	else
	{
		&writeLog("ERROR: Could not open the directory $dirPath for cleanup : $!");
	}
    	closedir DIRH;   
	writeLog("Finished deleteOldFiles ");
}

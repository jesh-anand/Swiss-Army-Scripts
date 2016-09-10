#=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
#
#                     	 		SEMatching.pm
#
#-------------------------------------------------------------------------------------
# File Name	: SEMatching.pm
# Author(s)	: Vivek Venudasan,Amarnath Peddi,Syed Abubakkar Rizwan,Bijay Sahoo
# Date		: 11 May 2010
# Version	: 1.0.0
# Copyright(c)	: Infosys Technologies Ltd. 2010
#-------------------------------------------------------------------------------------
# Description	: To perform all the property updates,format changes,Subelement 
# 				  matching and the alarm enrichments,before doing synchronization,on 
# 				  the discovery files.For alarm Enrichments the call is made to 
#				  corrspodning functions which are a part of another module named 
#				  AlarmEnrichment.pm
#-------------------------------------------------------------------------------------
#  ######
#  #     #  #####    ####   #    #     #     ####    ####
#  #     #  #    #  #    #  #    #     #    #       #    #
#  ######   #    #  #    #  #    #     #     ####   #    #
#  #        #####   #    #  #    #     #         #  #    #
#  #        #   #   #    #   #  #      #    #    #  #    #
#  #        #    #   ####     ##       #     ####    ####
#
#                                         Copyright(c)Infosys Technologies Ltd. 2010 
#=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

package SEMatching;
# Required for package implimentation
require Exporter;
BEGIN { unshift(@INC, $ENV{'PVMHOME'} . "/customScripts/UII/pmmodules")};
# use warnings;
use strict;
use ProvCommon;
use AlarmEnrichment;
use UII;
use PropUpdate;
use Cwd;
#==================================
# Global Variables
#==================================
our($VERSION) = "1.0";
our(@ISA)=("Exporter");
# List of all subroutines in this package..only these mentioned sub routines 
# can be accessed from outside this package
our(@EXPORT)=qw(processPostDiscUpdate);

our %subelementHash=();
our %subelementSplitHash=();
our %UniqueMatchHash=();
our %InventoryResidueHash =();
# RelAQ 21CNCE-70998  Hash to store the value of testexpression
our %portdownResidueHash =();
our %subeltInvariantHash = ();
our %seInvMatchValueHash =();
our %UniqueSEInvMatchHash =();
our %MatchedinvariantKeysHash=();
our %MatchedKeysHash =();

my %UIIRecord10Hash = ();
my %UIIRecordHash = ();
my %UIIRecord20Hash =();
my %UIIRecord20InsertHash = ();
my %profileConfigHash = ();
my %profileHash = ();
my %MSIProperties = ();
my %IPFilterVlanHash = ();
my %LagInfoHash=();
my %LagMPLSUpdateHash = ();
my %SwitchKeyValueHash = ();
my $MSIfeedflag;
my $alnSAPMatchValue;

#---------------------------------------------------------------------------------
# processPostDiscUpdate
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Description  : all the property updates,format changes,Subelement matching and
# 				 alarm enrichments,before doing synchronization,on the discovery
# 				 files.
# Input        : path to the Discovery files and the reference to the hash 
#				 containing profile to elements mapping.
# Return       : SUCCESS or FAIL
# Author       : Vivek Venudasan
# Date 	       : 11th may 2010
#---------------------------------------------------------------------------------
sub processPostDiscUpdate
{
	my ($self, $profilDirectory,$profHash)=@_;
	my $verbose = $self->{LOGFILEVERBOSE};
	%UIIRecord10Hash=%{UII::UIIRecord10Hash};
    %UIIRecordHash=%{UII::UIIRecordHash};
    %UIIRecord20Hash=%{UII::UIIRecord20Hash};
	%UIIRecord20InsertHash=%{UII::UIIRecord20InsertHash};
	%profileConfigHash = %{UII::profileConfigHash};
	%MSIProperties=%{UII::MSIProperties};
	$MSIfeedflag=${UII::MSIfeedflag};
	%SwitchKeyValueHash=%{UII::SwitchKeyValueHash};
	%profileHash = %{$profHash};
	my $pLog=$self->{PLOG};
	my $rtnCode="SUCCESS";
	my $func="processPostDiscUpdate";
	my (@Record10Info)=split($self->{"HEADERSEP"},$self->{"UII10HEADER"});
	my (@Record20Info)=split($self->{"HEADERSEP"},$self->{"UII20HEADER"});
	my $myTransType=$self->{"TRANSTYPEPROP"};
	my $mysnmpprop=$self->{"SNMPSWITCH"};
	my (@mysnmppropKey)=split($self->{"SUBHEADERSEP"},$mysnmpprop);
	my %isSNMP=%{$self->{"SNMPTESTVALUES"}};
	# Ericsson Filter tool
	my $myericprop=$self->{"ERICSWITCH"};
	my (@myericpropKey)=split($self->{"SUBHEADERSEP"},$myericprop);
	my %isERIC=%{$self->{"ERICTESTVALUES"}};
	# SAM Filter tool : 21CNCE-69092 SAM story
	my $mysamprop=$self->{"SAMSWITCH"};
	my (@mysampropKey)=split($self->{"SUBHEADERSEP"},$mysamprop);	
	my %isSAM=%{$self->{"SAMTESTVALUES"}};
	
	my $matchlogs = $self->{"THISLOADDIR"}."/".$self->{"THISLOADINFO"}."/doDiscovery_MatchInfo";
	mkdir $matchlogs;	
	my $recordUpdateCount=0;
	my $groupIn="EIN_GROUP";
	my $segroupIn="SEIN_GROUP";
	my $InValue="true";
	%subelementSplitHash=();
	%subelementHash=();
	%subeltInvariantHash = ();
	%seInvMatchValueHash = ();
	%UniqueMatchHash =();
	%UniqueSEInvMatchHash =();
	%InventoryResidueHash = ();
	my $POIDDumpHashRef ;
	my $inputSEdatFile = $profilDirectory."subelement.dat";
	my $inputEltdatFile = $profilDirectory."element.dat";	
	my $inputSEInvdatFile = $profilDirectory."subelement_invariant.dat";	
	#to get the profile name
	$profilDirectory =~ /\/(\w+)\/inventory/;
	my $profil = $1;
	my $matchlog = $matchlogs."/".$self->{"LOGFILEPREFIX"}."_matchinfo_".$profil.".log";
	my $inventoryResidueLog = $matchlogs."/".$self->{"LOGFILEPREFIX"}."_InventoryResidue".".log";
	my $networkResidueLog = $matchlogs."/".$self->{"LOGFILEPREFIX"}."_NetworkResidue_".$profil.".log";	
	my $matchedAlnSEDetails = $matchlogs."/MatchedAlnSubElts.log";	
	
	#call to find what all property updates are applicable to the current profile in use.
	#my $applicableUpdates = findApplicableUpdates($profil);
	undef %profileConfigHash;
	$pLog->PrintInfo( "$func: Calling subelement matching for profile - $profil.");
	#============================================================================================
	# Add entire subelement.dat and subelement_invariant.dat to required datastructures (Hashes)
	#--------------------------------------------------------------------------------------------
	if (makeDiscoveryFilesHash($inputSEdatFile,\%subelementSplitHash,\%subelementHash) eq 'SUCCESS') {
		$pLog->PrintInfo( "$func: Succesfully created the subelement.dat file hashes.") if $verbose == 1;
	}
	else {
		$pLog->PrintError( "$func: Subelement.dat could not be accessed!.Matching and property updates could not be done!.");
		return 'FAIL';
	}
	if (makeDiscoveryFilesHash($inputSEInvdatFile,\%seInvMatchValueHash,\%subeltInvariantHash) eq 'SUCCESS') {
		$pLog->PrintInfo( "$func: Succesfully created the subelement_invariant.dat file hashes.") if $verbose == 1;
	}
	else {
		$pLog->PrintError( "$func: Subelement_invariant.dat could not be accessed!.Matching and updates could not be done!.");
		return 'FAIL';
	}	
	#if both subelement.dat and subelement_invariant.dat are empty then return FAIL
	if (((scalar keys %subelementHash) == 0) && ((scalar keys %subeltInvariantHash) == 0)){
		$pLog->PrintError( "$func: Subelement.dat and Subelement_invariant.dat are empty!.Matching and updates could not be done!.");
		return 'FAIL';
	}
	
	#Starting Property Updates on subelement.dat and subelement_invariant.dat.
	#Performing property updates based on devices and the elements applicable to the current profile.		
	if (exists ($profileHash{$profil}))
	{
		foreach my $eltdet ( keys %{$profileHash{$profil}})	
		{
			my $mydata = $profileHash{$profil}{$eltdet};
			$mydata =~ s#(\s+)$##;
			$mydata =~ s#^(\s+)##;
			$mydata =~ s/(.*)\s+(.*)/$2  $1/; 
			$mydata =~ s/\s+/\|_\|/; 
			$mydata =~ s#(\s+)$##;
			my $suppId = ${ $UIIRecord10Hash{$mydata} }[$UIIRecordHash{BT_SUPPLIER_ID}];
			my $model = ${$UIIRecord10Hash{$mydata}}[$UIIRecordHash{BT_MODEL}];
			my $neType = ${$UIIRecord10Hash{$mydata}}[$UIIRecordHash{BT_NE_TYPE}];
			my $neUsage = ${$UIIRecord10Hash{$mydata}}[$UIIRecordHash{BT_NE_USAGE}];
			my $host = ${$UIIRecord10Hash{$mydata}}[$UIIRecordHash{BT_IP_NAME}];
			
			# 21CNCE-69092: construct SNMP & SAM key value => BT_NE_TYPE:BT_MODEL:BT_NE_USAGE value as well for ERIC => BT_NE_TYPE 
			# match SNMP devices and store SNMP switch key values in hash 
			$self->getSwitchKeyValues(\@mysnmppropKey,\@mysampropKey,\@myericpropKey,\@{$UIIRecord10Hash{$mydata}},\%UIIRecordHash,\%isSNMP,\%isSAM,\%isERIC);
			
			#property update for Alcatel if applicable.	
			if( $suppId eq "ALN" && $model =~ /^7750/ ) 
			{
				if ((${ $UIIRecord10Hash{$mydata} }[$UIIRecordHash{$myTransType}] eq "I") || (exists $UIIRecord20InsertHash{$mydata}) )
				{				
					if ((scalar keys %subelementHash) > 0){
						$pLog->PrintInfo( "$func: Updating 7750 SAP labels of subelement.dat file for element $host..");
						update7750SAPLabel($self,\%subelementSplitHash,\%subelementHash,$mydata);
						$pLog->PrintInfo( "$func: Finished 7750 SAP label update for subelement.dat.") if $verbose == 1;
					}
					if ((scalar keys %subeltInvariantHash) > 0){
						$pLog->PrintInfo( "$func: Updating 7750 SAP labels of subelement_invariant.dat file for element $host..");
						update7750SAPLabel($self,\%seInvMatchValueHash,\%subeltInvariantHash,$mydata);
						$pLog->PrintInfo( "$func: Finished 7750 SAP label update for subelement_invariant.dat.") if $verbose == 1;
					}
				}
			}
			#property update for CISCO 6509 MAR if applicable.		
			elsif($suppId eq "CIS" && $model eq "CAT6500" && $neType =~ /ETH SW|VIRTUAL SW/ && $neUsage =~ /MAR/){
				if (( ${ $UIIRecord10Hash{$mydata} }[$UIIRecordHash{$myTransType}] eq "I" ) || (exists $UIIRecord20InsertHash{$mydata}) )
				{
					if ((scalar keys %subelementHash) > 0){
						$pLog->PrintInfo( "$func: Updating BT_MATCH_1 values for Cisco 6509 element $host..");
						my %trunkhash = ();
						my %portHash = ();
						&cisco6509vlan(\%subelementSplitHash,\%subelementHash,\%trunkhash,\%portHash,$host);
						undef  %trunkhash;
						undef  %portHash;
						$pLog->PrintInfo( "$func: Finished updating BT_MATCH_1 values for Cisco 6509.") if $verbose == 1;
					}
				}
			}
			#property update for CISCO BEA if applicable.	
			elsif ($suppId eq "CIS" && $model eq "CAT6500" && $neUsage =~ /STD|BEA|BEA-VS|HT BEA-VS/ && $neType =~ /ETH SW|VIRTUAL SW/){
				if (( ${ $UIIRecord10Hash{$mydata} }[$UIIRecordHash{$myTransType}] eq "I" ) || (exists $UIIRecord20InsertHash{$mydata}) )
				{													
					if ((scalar keys %subelementHash) > 0){
						$pLog->PrintInfo( "$func: Updating BT_MATCH_1 values for Cisco 6509 element $host..");
						my %trunkhash = ();
						my %portHash = ();
						&cisco6509vlan(\%subelementSplitHash,\%subelementHash,\%trunkhash,\%portHash,$host);
						undef  %trunkhash;
						undef  %portHash;
						$pLog->PrintInfo( "$func: Finished updating BT_MATCH_1 values for Cisco 6509..") if $verbose == 1;
					}
					if ((scalar keys %subeltInvariantHash) > 0){			
						$pLog->PrintInfo( "$func: Updating BEA CBQoS for element $host..");
						&cbqosObjectID(\%seInvMatchValueHash,\%subeltInvariantHash,$host);
						$pLog->PrintInfo( "$func: Finished updating BEA CBQoS.") if $verbose == 1;
						$pLog->PrintInfo( "$func: Adding APID property for BEA element $host..");
						&beaPropertyAdd(\%seInvMatchValueHash,\%subeltInvariantHash,$host);
						$pLog->PrintInfo( "$func: Finished updating APID property.") if $verbose == 1;						
					}
					$pLog->PrintInfo( "$func: Updating BEA properties for element $host..");
					&BEAVlanNameUpdate(\%subelementSplitHash,\%subelementHash,\%seInvMatchValueHash,\%subeltInvariantHash,$host);
					$pLog->PrintInfo( "$func: Finished updating BEA properties.") if $verbose == 1;
				}
			}
			#property update for CISCO FER if applicable.
			elsif ($suppId eq "CIS" && $model eq "CAT6500" && $neUsage =~ /FER|FER-VS/ && $neType eq "VIRTUAL SW"){
				if (( ${ $UIIRecord10Hash{$mydata} }[$UIIRecordHash{$myTransType}] eq "I" ) || (exists $UIIRecord20InsertHash{$mydata}) )
				{			
					if ((scalar keys %subelementHash) > 0){
						$pLog->PrintInfo( "$func: Updating BT_MATCH_1 values for Cisco 6509 element $host..");
						my %trunkhash = ();
						my %portHash = ();
						&cisco6509vlan(\%subelementSplitHash,\%subelementHash,\%trunkhash,\%portHash,$host);
						undef  %trunkhash;
						undef  %portHash;
						$pLog->PrintInfo( "$func: Finished updating BT_MATCH_1 values for Cisco 6509.") if $verbose == 1;
					}
					if ((scalar keys %subeltInvariantHash) > 0){
						$pLog->PrintInfo( "$func: Updating FER CBQoS for element $host..");
						&cbqosObjectID(\%seInvMatchValueHash,\%subeltInvariantHash,$host);
						$pLog->PrintInfo( "$func: Finished updating FER CBQoS.") if $verbose == 1;
						$pLog->PrintInfo( "$func: Adding APID property for FER element $host..");
						&beaPropertyAdd(\%seInvMatchValueHash,\%subeltInvariantHash,$host);
						$pLog->PrintInfo( "$func: Finished updating APID property.") if $verbose == 1;
					}
					$pLog->PrintInfo( "$func: Updating FER properties for FER element $host..");
					&BEAVlanNameUpdate(\%subelementSplitHash,\%subelementHash,\%seInvMatchValueHash,\%subeltInvariantHash,$host);
					$pLog->PrintInfo( "$func: Finished updating FER properties.") if $verbose == 1;
					$pLog->PrintInfo( "$func: Obtaining the dump of CBQoS subelments..");
					$POIDDumpHashRef = &createPOIDDump($matchlogs);	
				}
			}
			#property update for CISCO CRS-1 if applicable.
			elsif (($suppId eq "CIS" && $model eq "CRS-1" && $neType eq "Core Rt") || ($suppId eq "CIS" && $model eq "CRS-3" && $neType eq "Core Rt")) {
				if (( ${ $UIIRecord10Hash{$mydata} }[$UIIRecordHash{$myTransType}] eq "I" ) || (exists $UIIRecord20InsertHash{$mydata}) )
				{
					if ((scalar keys %subeltInvariantHash) > 0){
						$pLog->PrintInfo( "$func: Updating CRS-1 CBQoS for element $host..");
						&cbqosObjectID(\%seInvMatchValueHash,\%subeltInvariantHash,$host);
						$pLog->PrintInfo( "$func: Finished updating CRS-1 CBQoS.") if $verbose == 1;
						$pLog->PrintInfo("$func: Updating CRS-1 minimum guranteed bandwidth for classes in subelement_invariant.dat..");
						minGBandWidth($self,\%seInvMatchValueHash,\%subeltInvariantHash,$mydata);
						$pLog->PrintInfo( "$func: Finished CRS-1 minimum Bandwidth property updates.") if $verbose == 1;
					}
				}
			}
			#property update for CISCO MGW if applicable.
			elsif ($suppId eq "CIS" && $model eq "MGX 8880" && $neType eq "Trunk GW"){
				if (( ${ $UIIRecord10Hash{$mydata} }[$UIIRecordHash{$myTransType}] eq "I" ) || (exists $UIIRecord20InsertHash{$mydata}) )
				{
					if ((scalar keys %subelementHash) > 0){
						$pLog->PrintInfo("$func: Updating MGW labels in subelement.dat file for element $host..");
						updateMGWLabel($self,\%subelementSplitHash,\%subelementHash,$mydata);
						$pLog->PrintInfo( "$func: Finished MGW label update.") if $verbose == 1;
					}
				}
			}
			#property update for Juniper T640 if applicable.
			elsif (($suppId eq "LUC" || $suppId eq "JUN" || $suppId eq "SIE") && ($model eq "Juniper T640"||$model eq "T1600") && $neType eq "Trunk GW"){
			
			# firewall updates are not applicable as of now. can be enabled once firewall updates are applicable.
				
				# if (( ${ $UIIRecord10Hash{$mydata} }[$UIIRecordHash{$myTransType}] eq "I" ) || (exists $UIIRecord20InsertHash{$mydata}) )
				# {
					# if (defined ($$applicableUpdates[6]) && $$applicableUpdates[6] == 1){	
						# if ((scalar keys %subelementHash) > 0){
							# $pLog->PrintInfo( "$func: Performing Juniper Firewall updates for element $host..");
							# &T640FirewallUpdate(\%subelementSplitHash,\%subelementHash,$host);
							# $pLog->PrintInfo( "$func: Finished Juniper Firewall updates.");
						# }
					# }
				# }
			}
			#property update for CISCO 6509 MEA if applicable.		
			elsif($suppId eq "CIS" && $model eq "CAT6500" && $neType =~ /L3 SW/ && $neUsage =~ /MEA|MGMT SW/){
				if (( ${ $UIIRecord10Hash{$mydata} }[$UIIRecordHash{$myTransType}] eq "I" ) || (exists $UIIRecord20InsertHash{$mydata}) )
				{
					if ((scalar keys %subelementHash) > 0){
						$pLog->PrintInfo( "$func: Updating BT_MATCH_1 values for Cisco 6509 element $host..");
						my %trunkhash = ();
						my %portHash = ();
						&cisco6509vlan(\%subelementSplitHash,\%subelementHash,\%trunkhash,\%portHash,$host);
						undef  %trunkhash;
						undef  %portHash;
						$pLog->PrintInfo( "$func: Finished updating BT_MATCH_1 values for Cisco 6509.") if $verbose == 1;
					}
					if ((scalar keys %subeltInvariantHash) > 0){
						$pLog->PrintInfo( "$func: Updating Cisco 6509 $neUsage CBQoS for element $host..");
						&cbqosObjectID(\%seInvMatchValueHash,\%subeltInvariantHash,$host);
						$pLog->PrintInfo( "$func: Finished updating Cisco 6509 $neUsage CBQoS.") if $verbose == 1;
					}
					$pLog->PrintInfo( "$func: Updating MEA properties for element $host..");
					&BEAVlanNameUpdate(\%subelementSplitHash,\%subelementHash,\%seInvMatchValueHash,\%subeltInvariantHash,$host);
					$pLog->PrintInfo( "$func: Finished updating $neUsage properties.") if $verbose == 1;
				}
			}
			# 20130908 [YepChoon] Added Cisco Fixes for Cisco 6509 Infrastructure Ethernet
			elsif($suppId eq "CIS" && $model eq "CAT6500" && $neType =~ /ETH SW/ && $neUsage =~ /L2 BB SW|L3 BB SW|INFRA SW/)
			{
				if (( ${ $UIIRecord10Hash{$mydata} }[$UIIRecordHash{$myTransType}] eq "I" ) || (exists $UIIRecord20InsertHash{$mydata}) )
				{
					if ((scalar keys %subelementHash) > 0){
						$pLog->PrintInfo( "$func: Updating BT_MATCH_1 values for Cisco 6509 element $host..");
						my %trunkhash = ();
						my %portHash = ();
						&cisco6509vlan(\%subelementSplitHash,\%subelementHash,\%trunkhash,\%portHash,$host);
						undef  %trunkhash;
						undef  %portHash;
						$pLog->PrintInfo( "$func: Finished updating BT_MATCH_1 values for Cisco 6509.") if $verbose == 1;
					}
				}
			}
			#property update BRAS devices if applicable.
			if ($neType eq "BRAS"){
				if (( ${ $UIIRecord10Hash{$mydata} }[$UIIRecordHash{$myTransType}] eq "I" ) || (exists $UIIRecord20InsertHash{$mydata}) )
				{
					$pLog->PrintInfo( "$func: Starting BRAS property updates on subelement.dat & subelement_invariant.dat for element $host..");		
					if ((scalar keys %subelementHash) > 0){
						UpdateBRASrecords($self,\%subelementSplitHash,\%subelementHash,$mydata);
					}
					if ((scalar keys %subeltInvariantHash) > 0){
						UpdateBRASrecords($self,\%seInvMatchValueHash,\%subeltInvariantHash,$mydata);
					}
					$pLog->PrintInfo( "$func: Finished BRAS property updates on subelement.dat & subelement_invariant.dat for element $mydata.") if $verbose == 1;					
				}
			}
		}
	}
	else {
		$pLog->PrintError( "$func: No details available for this profile - $profil");
	}
	# All the system stats subelements like CPU,Memory,Temperature etc ,for which no records comes from UII, 
	# are not used for matching.So those records need to be filtered so that they will be directly added to the 
	# during synchronization.
	if ((scalar keys %subelementHash) > 0){
		filterDiscoveryFilesHash($self,\%subelementSplitHash,\%subelementHash,\%UniqueMatchHash);
	}
	if ((scalar keys %subeltInvariantHash) > 0){
		   filterDiscoveryFilesHash($self,\%seInvMatchValueHash,\%subeltInvariantHash,\%UniqueSEInvMatchHash);	
	}
	#Starting SEMatching on subelement.dat and subelement_invariant.dat.
	$recordUpdateCount	= 0;
	open (MATCHPROC ,">>$matchlog");
	open (ALNDELETEINPUT ,">>$matchedAlnSEDetails");
	$pLog->PrintInfo( "$func: Performing subelement matching on subelement.dat and subelement_invariant.dat..") if $verbose == 1;
	if (exists ($profileHash{$profil}))
	{
		foreach my $eltdet ( keys %{$profileHash{$profil}})	
		{
		   my $mydata = $profileHash{$profil}{$eltdet};
		   $mydata =~ s#(\s+)$##;
		   $mydata =~ s#^(\s+)##;
		   $mydata =~ s/(.*)\s+(.*)/$2  $1/; 
		   $mydata =~ s/\s+/\|_\|/; 
		   $mydata =~ s#(\s+)$##;
		   # Type I?
		   #We need to loop through each se key for the given element
		   # Do any operation if 10 record is present for 20 record.	   
		   if((exists $UIIRecord10Hash{$mydata}) and (exists $UIIRecord20Hash{$mydata}))
		   {
				my $btModel = ${$UIIRecord10Hash{$mydata}}[$UIIRecordHash{BT_MODEL}];
				my $btNeType = ${$UIIRecord10Hash{$mydata}}[$UIIRecordHash{BT_NE_TYPE}];
				my $btNeUsage = ${$UIIRecord10Hash{$mydata}}[$UIIRecordHash{BT_NE_USAGE}];
				foreach my $selines ( keys %{$UIIRecord20Hash{ $mydata }} ) 
				{
					my $PolID = ${$UIIRecord20Hash{$mydata}{$selines}}[$UIIRecordHash{BT_BBASVLAN_RT_POLICY_ID}]; 
					if ((${ $UIIRecord20Hash{$mydata}{$selines} }[$UIIRecordHash{$myTransType}]eq "I") ||
						((${ $UIIRecord20Hash{$mydata}{$selines} }[$UIIRecordHash{$myTransType}]eq "U") && (exists $UIIRecord20InsertHash{$mydata})))
					{

						# 21CNCE-69092: get the SNMP final switch value from hash if exist for every 20 records
						my $switchvalues="";
						if(exists $SwitchKeyValueHash{ ${$UIIRecord20Hash{$mydata}{$selines}}[$UIIRecordHash{BT_IP_ADDRESS}] . ${$UIIRecord20Hash{$mydata}{$selines}}[$UIIRecordHash{BT_IP_NAME}] } ){
							$switchvalues = $SwitchKeyValueHash{ ${$UIIRecord20Hash{$mydata}{$selines}}[$UIIRecordHash{BT_IP_ADDRESS}] . ${$UIIRecord20Hash{$mydata}{$selines}}[$UIIRecordHash{BT_IP_NAME}] };
						}
				
						#check for snmp
						if (exists $isSNMP{ $switchvalues }) {
							#check for Alcatel					
							if ( ${ $UIIRecord10Hash{$mydata} }[$UIIRecordHash{BT_SUPPLIER_ID}]eq"ALN" && ${ $UIIRecord10Hash{$mydata} }[$UIIRecordHash{BT_NE_TYPE}]eq"Edge Rt") {
								AlcatelPostDiscUpdate($self,$mydata,$selines);
							}
							#check for CISCO FER
							elsif ($btModel eq "CAT6500" && $btNeType eq "VIRTUAL SW" && $btNeUsage =~ /^FER$|^FER-VS$/ && $PolID !~ /^$/ ) {
								processPostFERDiscUpdate($self,$mydata,$selines,$POIDDumpHashRef);
							}
							#for all other SNMP devices
							else{
								processGenericDiscUpdate($self,\@{$UIIRecord20Hash{$mydata}{$selines}},$mydata,$selines);
							}
							delete $UIIRecord20Hash{$mydata}{$selines};
						} #end of isSNMP check 						
					} # end of transtype == I check		
				} #end of each 20 record line
			} #end of 10 Record check
		}
		$pLog->PrintInfo( "$func: Subelement matching completed for subelement.dat and subelement_invariant.dat.") if $verbose == 1;
		$pLog->PrintInfo( "$func: Details of matching can be found here : $matchlog");		
	}
	else{
		$pLog->PrintError( "$func: No details available for this profile - $profil");
		close MATCHPROC;
		return 'FAIL';
	}
	close MATCHPROC;
	close ALNDELETEINPUT;
	#perform AlarmEnrichment on subelement.dat and subelement_invariant.dat
	$pLog->PrintInfo( "$func: Performing alarm enrichment on subelement.dat and subelement_invariant.dat..");
	my $AlarmEnrichStatus = doPreSynchroAlarmEnrichment($self,\%profileHash,$profil,\%UIIRecord10Hash,\%UIIRecordHash,\%UniqueMatchHash,\%UniqueSEInvMatchHash,\%MatchedKeysHash,\%MatchedinvariantKeysHash);
	if ($AlarmEnrichStatus eq 'SUCCESS'){
		$pLog->PrintInfo( "$func: AlarmEnrichment completed for subelement.dat and subelement_invariant.dat for profile $profil.");
	}
	else{
		$pLog->PrintError( "$func: AlarmEnrichment failed!");
	}
	#Writing the updated data back into subelement.dat file and subelement_invariant.dat file
	$pLog->PrintInfo( "$func: Creating the updated subelement.dat and subelement_invariant.dat..") if $verbose == 1;
	if (createFile(\%UniqueMatchHash,$inputSEdatFile) eq 'SUCCESS') {
		$pLog->PrintInfo( "$func: Successfully created the updated subelement.dat!") if $verbose == 1 ;	
	}
	else{
		$pLog->PrintError( "$func: The updated subelement.dat is not created! Synchronization should not be performed. Please Check!");
		return 'FAIL';
	}
	if (createFile(\%UniqueSEInvMatchHash,$inputSEInvdatFile) eq 'SUCCESS') {
		$pLog->PrintInfo( "$func: Successfully created the updated subelement_invariant.dat!") if $verbose == 1;			
	}
	else{
		$pLog->PrintError( "$func: The updated subelement.dat is not created! Synchronization should not be performed. Please Check!");
		return 'FAIL';
	}
	#Creating the Inventory Residue Log
	createResidueLogs(\%InventoryResidueHash,\%UniqueMatchHash,$inventoryResidueLog,1);
	#Creating the Network Residue Log
	createResidueLogs(\%subelementHash,\%UniqueMatchHash,$networkResidueLog,2);	
	createResidueLogs(\%subeltInvariantHash,\%UniqueSEInvMatchHash,$networkResidueLog,3) if ((scalar keys %subeltInvariantHash) > 0);	
	$pLog->PrintInfo( "$func: Inventory Residue Log and Network Residue Logs are updated here: $matchlogs");		
	# RelAQ 21CNCE-70998 : Write the Failed Interfaces to Interface_Failure_Record.dat
	createFailedInterfaceFile($self,\%InventoryResidueHash);
	$pLog->PrintInfo( "$func: Leaving function") if $verbose == 1;
	undef %subelementHash;
	undef %subelementSplitHash;
	undef %UniqueMatchHash;
	undef %InventoryResidueHash;
	undef %subeltInvariantHash;
	undef %seInvMatchValueHash;
	undef %UniqueSEInvMatchHash;
	undef %MatchedinvariantKeysHash;
	undef %MatchedKeysHash;
	undef %profileHash;
	# RelAQ 21CNCE-70998
	undef %portdownResidueHash;
	return $rtnCode;
}
#------------------------------------End of processPostDiscUpdate--------------------------------------------#
#--------------------------------------------------------------------------------------------
# makeDiscoveryFilesHash
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Description  : To add the discovery files (subelement.dat and subelement_invariant.dat to
#				 required datastructures (hashes).
#Author        : Vivek Venudasan
# Input        : Input File and references to the target hashes.
# Return       : SUCCESS or FAIL
#----------------------------------------------------------------------------------------------
sub makeDiscoveryFilesHash
{
    my ($filePath,$MatchValHash,$CompleteFileHash)=@_;
	my $i;
	my $fileopen;
	my $rtnCode = 'SUCCESS';

	if (open (FH,$filePath) ){
		$fileopen = "SUCCESS";
	}
	if ($fileopen eq "SUCCESS"){
		foreach my $Line (<FH>){
			if ($Line !~ /^#/ && $Line =~ /\w+/ ){
				my @line = split(/\|_\|/, $Line);
				my $linesize = @line;
				$i=8;
				$$MatchValHash {$line[1]}{$line[2]}{"INVARIANT"} = $line[0];
				$$MatchValHash {$line[1]}{$line[2]}{"ELT.NAME"} = $line[1];
				$$MatchValHash {$line[1]}{$line[2]}{"NAME"} = $line[2];
				$$MatchValHash {$line[1]}{$line[2]}{"DATE"} = $line[3];
				$$MatchValHash {$line[1]}{$line[2]}{"INSTANCE"} = $line[4];
				$$MatchValHash {$line[1]}{$line[2]}{"LABEL"} = $line[5];
				$$MatchValHash {$line[1]}{$line[2]}{"STATE"} = $line[6];
				$$MatchValHash {$line[1]}{$line[2]}{"FAMILY"} = $line[7];
				while ($i<($linesize-2)){
					$$MatchValHash {$line[1]}{$line[2]}{$line[$i]} = $line[$i+1];
					$i=$i+2;
				}
				$$CompleteFileHash {$line[1]}{$line[2]} = $Line;
			}
		}
		close FH;		
		return $rtnCode;
	}
	else
	{
		return 'FAIL';
	}
}
#------------------------------------End of makeDiscoveryFilesHash--------------------------------------------#
#--------------------------------------------------------------------------------------------
# findApplicableUpdates
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Description  : To check whether the device specific updates are applicable for the current 
#			   : profile.The applicable updates are flagged in an array with its index
#				 representing the required update.
# Input        : The current profile name.
# Return       : the reference to array holding update flags 
#				 1 if updates are applicable 
# Author       : Vivek Venudasan
# Date         : 9th June 2010
#----------------------------------------------------------------------------------------------
sub findApplicableUpdates
{
    my ($profil)=@_;
	my @dothisUpdatelist;
	foreach my $device (keys %{$profileConfigHash{$profil}}){
		if (($profileConfigHash{$profil}{$device}{"BT_SUPPLIER_ID"} eq "ALN") && ($profileConfigHash{$profil}{$device}{"BT_MODEL"} =~ /^7750/)){
			$dothisUpdatelist[0]=1;
		}
		elsif (($profileConfigHash{$profil}{$device}{"BT_SUPPLIER_ID"} eq "CIS") && ($profileConfigHash{$profil}{$device}{"BT_MODEL"} eq "CAT6500")
				&& ($profileConfigHash{$profil}{$device}{"BT_NE_TYPE"} =~ /ETH SW|VIRTUAL SW/) && ($profileConfigHash{$profil}{$device}{"BT_NE_USAGE"} =~ /MAR/))
		{
			$dothisUpdatelist[1]=1;
		}
		elsif (($profileConfigHash{$profil}{$device}{"BT_SUPPLIER_ID"} eq "CIS") && ($profileConfigHash{$profil}{$device}{"BT_MODEL"} eq "CAT6500")
				&& ($profileConfigHash{$profil}{$device}{"BT_NE_TYPE"} =~ /ETH SW|VIRTUAL SW/) && ($profileConfigHash{$profil}{$device}{"BT_NE_USAGE"} =~ /STD|BEA|BEA-VS|HT BEA-VS/))
		{
			$dothisUpdatelist[2]=1;
		}
		elsif (($profileConfigHash{$profil}{$device}{"BT_SUPPLIER_ID"} eq "CIS") && ($profileConfigHash{$profil}{$device}{"BT_MODEL"} eq "CAT6500")
				&& ($profileConfigHash{$profil}{$device}{"BT_NE_TYPE"} eq "VIRTUAL SW") && ($profileConfigHash{$profil}{$device}{"BT_NE_USAGE"} =~ /FER|FER-VS/))
		{
			$dothisUpdatelist[3]=1;
		}
		elsif (($profileConfigHash{$profil}{$device}{"BT_SUPPLIER_ID"} eq "CIS") && (($profileConfigHash{$profil}{$device}{"BT_MODEL"} eq "CRS-1") || ($profileConfigHash{$profil}{$device}{"BT_MODEL"} eq "CRS-3"))
				&& ($profileConfigHash{$profil}{$device}{"BT_NE_TYPE"} eq "Core Rt"))
		{
			$dothisUpdatelist[4]=1;
		}
		elsif (($profileConfigHash{$profil}{$device}{"BT_SUPPLIER_ID"} eq "CIS") && ($profileConfigHash{$profil}{$device}{"BT_MODEL"} eq "MGX 8880")
				&& ($profileConfigHash{$profil}{$device}{"BT_NE_TYPE"} eq "Trunk GW"))
		{
			$dothisUpdatelist[5]=1;
		}
		elsif ((($profileConfigHash{$profil}{$device}{"BT_SUPPLIER_ID"} eq "LUC")||($profileConfigHash{$profil}{$device}{"BT_SUPPLIER_ID"} eq "SIE")||($profileConfigHash{$profil}{$device}{"BT_SUPPLIER_ID"} eq "JUN")) 
				&& (($profileConfigHash{$profil}{$device}{"BT_MODEL"} eq "Juniper T640")||($profileConfigHash{$profil}{$device}{"BT_MODEL"} eq "T1600"))	
				&& ($profileConfigHash{$profil}{$device}{"BT_NE_TYPE"} eq "Trunk GW"))
		{
			$dothisUpdatelist[6]=1;
		}
		elsif (($profileConfigHash{$profil}{$device}{"BT_SUPPLIER_ID"} eq "CIS") && ($profileConfigHash{$profil}{$device}{"BT_MODEL"} eq "CAT6500")
				&& ($profileConfigHash{$profil}{$device}{"BT_NE_TYPE"} =~ /L3 SW/) && ($profileConfigHash{$profil}{$device}{"BT_NE_USAGE"} =~ /MEA/))
		{
			$dothisUpdatelist[7]=1;
		}
		elsif (($profileConfigHash{$profil}{$device}{"BT_SUPPLIER_ID"} eq "CIS") && ($profileConfigHash{$profil}{$device}{"BT_MODEL"} eq "CAT6500") && ($profileConfigHash{$profil}{$device}{"BT_NE_TYPE"} =~ /L3 SW/) && ($profileConfigHash{$profil}{$device}{"BT_NE_USAGE"} =~ /MGMT SW/))
                {
                        $dothisUpdatelist[9]=1;
                }
		if ($profileConfigHash{$profil}{$device}{"BT_NE_TYPE"} eq "BRAS"){
			$dothisUpdatelist[8]=1;
		}
	}
	return \@dothisUpdatelist;
}
#------------------------------------End of findApplicableUpdates--------------------------------------------#	
#--------------------------------------------------------------------------------------------
# createPOIDDump
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Description  : 
# Input        : 
# Return       :  
# Author       : Vivek Venudasan
# Date         : 10th May 2011
#----------------------------------------------------------------------------------------------
sub createPOIDDump
{
   	# Directory path of the file to be used by this script
	my ($workingDir) =  @_;
	# File to store resmgr export/import data
	my $exportSEFile = $workingDir."/POIDDump.txt";
	my %existingPOIDsHash=();
	# Calling the resmgrexport sub-routine to export SE data from DB
	my $myExportType = 'se';
	my $myColNames = "dbIndex seprp.BT_MATCH_1:value invariant";
	my $myFilter = "seprp.ClassActionType:value(class) state(='on') seprp.ClassPolicyName:value(*POID*)";
	my $myOption = "-noHead -file '$exportSEFile' ";
	exportresmgr("$myExportType", "$myColNames", "$myFilter", "$myOption");
	
	if(open(RFH,"<$exportSEFile") )
	{
		while (my $line = <RFH> ) {
			chomp($line);
			my @lineDetails = split('\|_\|',$line);
			$existingPOIDsHash{$lineDetails[1]} = $lineDetails[2];
		}
		close(RFH);		
	}
	return \%existingPOIDsHash;
}
#------------------------------------End of createPOIDDump---------------------------------#
#-------------------------------------------------------------------------------
# update7750SAPLabel
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Description  : Update the labels of all 7750 SAP subelements 
# Author       : Vivek Venudasan
# Input        : references to the subelement hashes
# Return       : None
#-------------------------------------------------------------------------------
sub update7750SAPLabel
{
    my ($self,$MatchValHash,$CompleteFileHash,$mydata)=@_;
	my @nameIPVal = split(/\|_\|/, $mydata);
	my $eltkey = $nameIPVal[0];	
	if (exists(${$MatchValHash}{$eltkey})){
		foreach my $subeltkey (keys %{${$MatchValHash}{$eltkey}}){
			my $currentLabel = $$MatchValHash {$eltkey}{$subeltkey}{"LABEL"};
		#	print("value of label is : $currentLabel  ----divay\n");
			my $updatedVal = &AlcatelPreSyncDecodeID($currentLabel);
	#		print("value of updatedVal after the function AlcatelPreSyncDecodeID is : $updatedVal ----divay\n");
			my $subelementHashline = $$CompleteFileHash {$eltkey}{$subeltkey} ;
			if ($updatedVal ne "FAIL"){
				my @labelsplit = split(/\|_\|/, $updatedVal);
				$$MatchValHash {$eltkey}{$subeltkey}{"LABEL"} = $labelsplit[0];
				$$MatchValHash {$eltkey}{$subeltkey}{$labelsplit[1]} = $labelsplit[2];
				$subelementHashline =~ s/$currentLabel/$labelsplit[0]/i ;
				$subelementHashline =~ s#(\s+)$##;
				if ($subelementHashline =~ /$labelsplit[1]/){
					$subelementHashline =~ s/$labelsplit[1]\|_\|.*?\|_\|/$labelsplit[1]\|_\|$labelsplit[2]\|_\|/i ;
				}
				else{
					$subelementHashline .= $labelsplit[1]."|_|".$labelsplit[2]."|_|";
				}
			}
			#Update the VlanType Property based on BT_MATCH_1 value
			my $btMatch1 = "";
			my $vlanType = "SVLAN";
			$subelementHashline =~ s#(\s+)$##;
			if ($subelementHashline =~ m/BT_MATCH_1\|_\|(.*)/){
				$btMatch1 = $1;
			}
			if(($btMatch1 =~ m/\d+\/\d+\/\d+\.\d+\.\d+/) || ($btMatch1 =~ m/lag-\d+\.\d+\.\d+/i))
			{
				$vlanType = "CVLAN";
			}
			$subelementHashline .= "VlanType|_|".$vlanType."|_|";
	#		print("subelementHashLine is : $subelementHashline ----divay\n");
			$$CompleteFileHash{$eltkey}{$subeltkey} = $subelementHashline;
		}
	}
}
#------------------------------------End of update7750SAPLabel--------------------------------------------#
#-------------------------------------------------------------------------------
# updateMGWLabel
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Description  : Update the labels of all MediaGateway subelements 
# Input        : references to the subelement hashes
# Return       : SUCCESS or FAIL
# Author	   : Syed Aboobackar Rizwan
#-------------------------------------------------------------------------------
sub updateMGWLabel
{
    my ($self,$MatchValHash,$CompleteFileHash,$mydata)=@_;
	my $rtnCode = "SUCCESS";
	my $pLog=$self->{PLOG};
	my @nameIPVal = split(/\|_\|/, $mydata);
	my $eltkey = $nameIPVal[0];	
	if (exists(${$MatchValHash}{$eltkey})){
		foreach my $subeltkey (keys %{${$MatchValHash}{$eltkey}}){
			my $currentLabel = $$CompleteFileHash {$eltkey}{$subeltkey};
			my $updatedVal = &rttmDecode($currentLabel);
			if ($updatedVal ne "FAIL"){
				$$CompleteFileHash{$eltkey}{$subeltkey} = $updatedVal;
			}
			else
			{
				$rtnCode = "FAIL";
			}
		}
	}
	return $rtnCode;
}
#------------------------------------End of updateMGWLabel--------------------------------------------#
##===============================================================================
# Name		    : minGBandwidth
# Description:	: To calculate minimum guaranteed bandwidth for MPLS classes and 
# 		 		  populating against a new property
# Input		    : References to Subelement_invariant.dat hash and the hostname of 
#				  current element
# Return	    : None
# Author	    : Bijay Sahoo
# Date		    : 03 Jun 2010
# Version	    : 1.0
# Organization	: Infosys Technologies Ltd., Bangalore
##================================================================================ 
sub minGBandWidth
{  
	my ($self,$MatchValHash,$CompleteFileHash,$mydata)=@_;
	my ($ipAddress, $policyName);
	my (%co1Hash,%co2Hash, %cl1Hash, %cl2Hash, %c3Hash, %cntrlHash, %cntrlValueHash, %co2ValueHash);
	my (%finalcntrlHash, %finalco2Hash, %finalco1Hash, %finalcl1Hash, %finalcl2Hash, %finalc3Hash);
	my ( $key );
	my $subeltkey;
	my @nameIPVal = split(/\|_\|/, $mydata);
	my $eltkey = $nameIPVal[0];	
	$ipAddress=$nameIPVal[1];
	my ( $className ,$policeConformRate,$interfaceDescr,$classPolicyName,$queueClassBW,$REDIfType );
	my $btModel = ${$UIIRecord10Hash{$mydata}}[$UIIRecordHash{BT_MODEL}];
	if (exists(${$MatchValHash}{$eltkey})){
		foreach my $subeltkey (keys %{${$MatchValHash}{$eltkey}})
		{ 
			my $subelementHashline = $$CompleteFileHash {$eltkey}{$subeltkey} ;
			chomp ($subelementHashline);
			my $className = $$MatchValHash {$eltkey}{$subeltkey}{"ClassName"};
			my $policeConformRate = $$MatchValHash {$eltkey}{$subeltkey}{"PoliceConformRate"};
			my $interfaceDescr = $$MatchValHash {$eltkey}{$subeltkey}{"InterfaceDescr"};
			my $classPolicyName = $$MatchValHash {$eltkey}{$subeltkey}{"ClassPolicyName"};
			my $queueClassBW = $$MatchValHash {$eltkey}{$subeltkey}{"QueueClassBW"};
			my $REDIfType=$$MatchValHash {$eltkey}{$subeltkey}{"REDIfType"};
			if ($policeConformRate){
			}
			else{
			next;
			}
			# Getting required values of co1 and cl1 class variables to be updated for MGB
			if($btModel =~ /CR/ && $policeConformRate ne "NotConfigured"){
				if( $className =~ m/co1/i )
				{ 		
					$key = "$ipAddress"."_"."$interfaceDescr"."_"."$classPolicyName";
					chomp($key);
					$co1Hash{$key} =$policeConformRate;
					$subelementHashline .="Min Guaranteed BW"."|_|"."$policeConformRate"."|_|\n" if( $policeConformRate =~ /\w+/ );	
				}
				if( $className =~ m/cl1/i )
				{	 	
					$key = "$ipAddress"."_"."$interfaceDescr"."_"."$classPolicyName";
					chomp($key);
					$cl1Hash{$key} = $policeConformRate;
					$subelementHashline .="Min Guaranteed BW"."|_|"."$policeConformRate"."|_|\n" if( $policeConformRate =~ /\w+/ );				
				}	
				$$CompleteFileHash {$eltkey}{$subeltkey}=$subelementHashline;
			}
		}
		
		foreach my $subeltkey (keys %{${$MatchValHash}{$eltkey}})
		{ 
			my $subelementHashline = $$CompleteFileHash {$eltkey}{$subeltkey} ;
			chomp ($subelementHashline);	
			my $className = $$MatchValHash {$eltkey}{$subeltkey}{"ClassName"};
			my $policeConformRate = $$MatchValHash {$eltkey}{$subeltkey}{"PoliceConformRate"};
			my $interfaceDescr = $$MatchValHash {$eltkey}{$subeltkey}{"InterfaceDescr"};
			my $classPolicyName = $$MatchValHash {$eltkey}{$subeltkey}{"ClassPolicyName"};
			my $queueClassBW = $$MatchValHash {$eltkey}{$subeltkey}{"QueueClassBW"};
			my $REDIfType=$$MatchValHash {$eltkey}{$subeltkey}{"REDIfType"};
			if($btModel =~/CR/ ){
				if ($queueClassBW ){	
					if( $className =~ m/co2/i )
					{		
						$key = "$ipAddress"."_"."$interfaceDescr"."_"."$classPolicyName";
						chomp($key);
						$co2Hash{$key} = $queueClassBW;				
					}	
					if( $className =~ m/cl2/i )
					{ 
						$key = "$ipAddress"."_"."$interfaceDescr"."_"."$classPolicyName";
						chomp($key);
						$cl2Hash{$key} = $queueClassBW;
					}
					if( $className =~ m/default/i )
					{ 
						$key = "$ipAddress"."_"."$interfaceDescr"."_"."$classPolicyName";
						chomp($key);
						$c3Hash{$key} = $queueClassBW;						
					}
					if( $className =~ m/cntrl/i )
					{			 
						$key = "$ipAddress"."_"."$interfaceDescr"."_"."$classPolicyName";
						chomp($key);
						$cntrlHash{$key} = $queueClassBW;					
					}	
				}
			}
		}
		
		# calculating Minimum guaranteed bandwidth for cntrl class
		while ( my ($key, $mytempvalue) = (each %cntrlHash) )
		{  
			undef $mytempvalue;
			$co1Hash{$key} = 0 if( ! exists($co1Hash{$key} ) );
			$co2Hash{$key} = 0 if( ! exists($co2Hash{$key}) ) ;
			$cl1Hash{$key} = 0 if( ! exists($cl1Hash{$key}) );
			$cl2Hash{$key} = 0 if( ! exists($cl2Hash{$key}));
			$c3Hash{$key} = 0 if( ! exists($c3Hash{$key}) ); 
			my $cntrlMGB = ( $cntrlHash{$key}/( $co2Hash{$key} + $cl2Hash{$key} + $c3Hash{$key} + $cntrlHash{$key} ) )*(100 - $co1Hash{$key} - $cl1Hash{$key});
			$cntrlValueHash{$key} = $cntrlMGB;
		}
		
		# calculating Minimum guaranteed bandwidth for co2 class
		while ( my ($key, $mytempvalue) = (each %co2Hash) )
		{ 
			undef $mytempvalue;
			$co1Hash{$key} = 0 if( ! exists($co1Hash{$key} ) );
			$co2Hash{$key} = 0 if( ! exists($co2Hash{$key}) ) ;
			$cl1Hash{$key} = 0 if( ! exists($cl1Hash{$key}) );
			$cl2Hash{$key} = 0 if( ! exists($cl2Hash{$key}) );
			$c3Hash{$key} = 0 if( ! exists($c3Hash{$key}) ) ;
			my $co2MGB = ( $co2Hash{$key}/( $co2Hash{$key} + $cl2Hash{$key} + $c3Hash{$key} + $cntrlHash{$key} ) )*(100 - $co1Hash{$key} - $cl1Hash{$key});
			$co2ValueHash{$key} = $co2MGB;
		}
		%co1Hash = undef;
		%co2Hash = undef;
		%cl1Hash = undef;
		%cl2Hash = undef;
		%c3Hash = undef;
		%cntrlHash = undef;		
		foreach my $subeltkey (keys %{${$MatchValHash}{$eltkey}})
		{ 
			my $subelementHashline = $$CompleteFileHash {$eltkey}{$subeltkey} ;
			chomp ($subelementHashline);
			my $className = $$MatchValHash {$eltkey}{$subeltkey}{"ClassName"};
			my $policeConformRate = $$MatchValHash {$eltkey}{$subeltkey}{"PoliceConformRate"};
			my $interfaceDescr = $$MatchValHash {$eltkey}{$subeltkey}{"InterfaceDescr"};
			my $classPolicyName = $$MatchValHash {$eltkey}{$subeltkey}{"ClassPolicyName"};
			my $queueClassBW = $$MatchValHash {$eltkey}{$subeltkey}{"QueueClassBW"};
			my $REDIfType=$$MatchValHash {$eltkey}{$subeltkey}{"REDIfType"};
			if( $className =~ m/cl2/i )
			{			
				$subelementHashline .="Min Guaranteed BW"."|_|"."|_|\n" ;
			}
			if( $className=~ m/default/i )
			{
				$subelementHashline .="Min Guaranteed BW"."|_|"."|_|\n" ;			
			}	
			if( $className =~ m/co2/i )
			{  
				$key = "$ipAddress"."_"."$interfaceDescr"."_"."$classPolicyName";
				chomp($key);
				if( exists $co2ValueHash{$key} )
				{ 
					$subelementHashline .="Min Guaranteed BW"."|_|"."$co2ValueHash{$key}"."|_|\n" if( $co2ValueHash{$key} =~ /\w+/ );
				}
			}		
			if( $className =~ m/cntrl/i )
			{  
				$key = "$ipAddress"."_"."$interfaceDescr"."_"."$classPolicyName";
				chomp($key);
				if( exists $cntrlValueHash{$key} )
				{   
					$subelementHashline .="Min Guaranteed BW"."|_|"."$cntrlValueHash{$key}"."|_|\n" if( $cntrlValueHash{$key} =~ /\w+/ );
				}
			}			
			$$CompleteFileHash {$eltkey}{$subeltkey}=$subelementHashline;
		}
	}
}
#------------------------------------End of minGBandWidth--------------------------------------------#
#-------------------------------------------------------------------------------
# UpdateBRASrecords
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Description  : To update BT_MATCH_1 values of SE for BRAS devices
# Input        : references to the subelement hashes
# Return       : None
#-------------------------------------------------------------------------------
sub UpdateBRASrecords
{
    my ($self,$MatchValHash,$CompleteFileHash,$mydata)=@_;
	my $valToBeUpdated = "BT_MATCH_1";
	my @nameIPVal = split(/\|_\|/, $mydata);
	my $eltkey = $nameIPVal[0];
	if (exists(${$MatchValHash}{$eltkey})){
		foreach my $subeltkey (keys %{${$MatchValHash}{$eltkey}}){
			if (($$MatchValHash {$eltkey}{$subeltkey}{"FAMILY"}) =~ /IETF/){				
				my $currentVal = $$MatchValHash {$eltkey}{$subeltkey}{$valToBeUpdated};
				my $newVal = &brasPropertyUpdate($currentVal);
				if ($newVal ne "FAIL"){
					$$MatchValHash {$eltkey}{$subeltkey}{$valToBeUpdated} = $newVal;
					my $subelementHashline = $$CompleteFileHash {$eltkey}{$subeltkey} ;
					$subelementHashline =~ s#(\s+)$##;
					if ($subelementHashline =~ /$valToBeUpdated/){
						$subelementHashline =~ s/$valToBeUpdated\|_\|.*?\|_\|/$valToBeUpdated\|_\|$newVal\|_\|/i ;
					}
					else{
						$subelementHashline .= $valToBeUpdated."|_|".$newVal."|_|";
					}
					$$CompleteFileHash{$eltkey}{$subeltkey} = $subelementHashline;
				}
			}
		}
	}
}
#------------------------------------End of UpdateBRASrecords--------------------------------------------#
#-----------------------------------------------------------------------------------------------
# filterDiscoveryFilesHash
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Description  : To filter the records for which matching are not done from the discovery files.
#Author        : Vivek Venudasan
# Input        : references to the target hashes.
#-----------------------------------------------------------------------------------------------
sub filterDiscoveryFilesHash
{
    my ($self,$MatchValHash,$CompleteFileHash,$UniqueMatchesHash)=@_;
	my $pLog=$self->{PLOG};
	my $nonMatchFamList= $self->{"NONMATCHEDFAMILYLIST"};
	my $func = "filterDiscoveryFilesHash";
	my $verbose = $self->{LOGFILEVERBOSE};
	$pLog->PrintInfo( "$func: Filtering subelements that are not used for matching...") if $verbose == 1;	
	my @NonMatchedDeviceFamily = split(",",$nonMatchFamList);
	my %NonMatchedDeviceFamilyHash; 
	foreach my $entry (@NonMatchedDeviceFamily)
	{
		$NonMatchedDeviceFamilyHash{$entry} = 1;
	}
	undef @NonMatchedDeviceFamily;
	foreach my $eltkey (keys %{$CompleteFileHash}){
		 foreach my $subeltkey (keys %{${$CompleteFileHash}{$eltkey}}){
		 # 21CNCE-66590: UII Code Fix
		 # This code matches Alcatel lag entries from network without intervension of UII Feed
		 if ($$MatchValHash {$eltkey}{$subeltkey}{"LABEL"}=~ /aln/i && $$MatchValHash {$eltkey}{$subeltkey}{"FAMILY"}=~ /IETF/ && $$MatchValHash {$eltkey}{$subeltkey}{BT_MATCH_1} =~ /lag-/i) {
			$$UniqueMatchesHash{$eltkey}{$subeltkey} = $$CompleteFileHash{$eltkey}{$subeltkey};		 
		 }
			if ( $$MatchValHash {$eltkey}{$subeltkey}{"LABEL"}=~ /jun/i && $$MatchValHash {$eltkey}{$subeltkey}{"FAMILY"}=~ /IETF|Juniper_Chassis/ ){
				#$pLog->PrintInfo( "$func: ORIGINAL LINE[MatchValHash]: $$CompleteFileHash{$eltkey}{$subeltkey} ");
				$$CompleteFileHash{$eltkey}{$subeltkey} =~ s/[-.]re\d//g;
				#$pLog->PrintInfo( "$func: RESULT LINE[CompleteFileHash]: $$CompleteFileHash{$eltkey}{$subeltkey} ");
			}
			
			# 20140908 [YepChoon] : Update the condition to filter only specific cisco Lag (Port-channel<x>)
			if (	(
						$$MatchValHash {$eltkey}{$subeltkey}{"LABEL"}=~ /(core|acc|mbar|l2switch)-jun/i 
						&& 
						$$MatchValHash {$eltkey}{$subeltkey}{BT_MATCH_1} =~ /ae/i
					)
					|| 
					(
						$$MatchValHash {$eltkey}{$subeltkey}{"LABEL"}=~ /cis/i
						&&
						$$MatchValHash {$eltkey}{$subeltkey}{BT_MATCH_1} =~ /Bundle-Ether/i
					)
					||
					(
						$$MatchValHash {$eltkey}{$subeltkey}{"LABEL"}=~ /(ar|bea|bea-vs|ht-bea-vs|ca|fer|fer-vs|is|mea|core)-cis/i 
						&& 
						$$MatchValHash {$eltkey}{$subeltkey}{BT_MATCH_1} =~ /Port-channel/i 
					)
			)
			{
					$$UniqueMatchesHash{$eltkey}{$subeltkey} = $$CompleteFileHash{$eltkey}{$subeltkey};
					#matchValHash has the lag subelement names. unique matcheshash has the lag subelements for which we update the lag id.
#49924##########
					my $lagName=$$MatchValHash{$eltkey}{$subeltkey}{"InterfaceDescr"};
					my $ifHighSpeed = $$MatchValHash{$eltkey}{$subeltkey}{"AP_ifHighSpeed"};
					my $QoSFamily="";		
					if($$MatchValHash {$eltkey}{$subeltkey}{BT_MATCH_1} =~ /ae/i){
						$QoSFamily="Juniper_";
						UpdateLagIdandBandwidth($self,$eltkey,$subeltkey,$lagName,$CompleteFileHash,$UniqueMatchesHash,$QoSFamily,$ifHighSpeed);
					}elsif($$MatchValHash {$eltkey}{$subeltkey}{BT_MATCH_1} =~ /Bundle-Ether/i){
						$QoSFamily="Cisco_CBQoS";
						UpdateLagIdandBandwidth($self,$eltkey,$subeltkey,$lagName,\%subeltInvariantHash,$UniqueMatchesHash,$QoSFamily,$ifHighSpeed);
					}			
					
#49924#########		
					delete $$CompleteFileHash{$eltkey}{$subeltkey};
					delete $$MatchValHash{$eltkey}{$subeltkey};
					next;
			}
			if($$MatchValHash  {$eltkey}{$subeltkey}{"FAMILY"} =~/7750_IPFilters/){
				if(!($$MatchValHash  {$eltkey}{$subeltkey}{"IPFilters"} > 1049 && $$MatchValHash  {$eltkey}{$subeltkey}{"IPFilters"} < 1100 )){
					$pLog->PrintDebug( "$func: Ignored IpFilter $$MatchValHash{$eltkey}{$subeltkey}{IPFilters} ");
					delete $$CompleteFileHash{$eltkey}{$subeltkey};
					delete $$MatchValHash{$eltkey}{$subeltkey};
					next;
				}
			}

			if (exists $NonMatchedDeviceFamilyHash{$$MatchValHash {$eltkey}{$subeltkey}{"FAMILY"}}){					
				if ($$MatchValHash {$eltkey}{$subeltkey}{"LABEL"}=~ /FER|FER-VS/i && $$MatchValHash  {$eltkey}{$subeltkey}{"FAMILY"} =~/CBQoS/ ){
					next;
				}
				# elsif ($$MatchValHash {$eltkey}{$subeltkey}{"LABEL"}=~ /cis/i && $$MatchValHash {$eltkey}{$subeltkey}{BT_MATCH_1} =~ /Port-channel/i && $$MatchValHash {$eltkey}{$subeltkey}{"FAMILY"} =~ /IETF_IF/)
				# {
						# $$UniqueMatchesHash{$eltkey}{$subeltkey} = $$CompleteFileHash{$eltkey}{$subeltkey};
						# delete $$CompleteFileHash{$eltkey}{$subeltkey};
						# delete $$MatchValHash{$eltkey}{$subeltkey};
						# next;
				# }
				# else
				# {
					# if ($$MatchValHash {$eltkey}{$subeltkey}{"FAMILY"} =~ /IETF/)
					# {
						# next;
					# }
				# }
			
				$$UniqueMatchesHash{$eltkey}{$subeltkey} = $$CompleteFileHash{$eltkey}{$subeltkey};
				delete $$CompleteFileHash{$eltkey}{$subeltkey};
				delete $$MatchValHash{$eltkey}{$subeltkey};
			}
		}
	}
	$pLog->PrintInfo( "$func: Filtered the subelements that are not used for matching.") if $verbose == 1;
	undef %NonMatchedDeviceFamilyHash;
}
#------------------------------------End of filterDiscoveryFilesHash--------------------------------------------#
#---------------------------------------------------------------------------------
# AlcatelPostDiscUpdate
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Description  : process all the updates of ALCATEL devices on the dscovery files
#				 before synchronization after calling matching
# Author	   : Vivek Venudasan
# Date		   : 11 May 2010
# Input        : current element key,current subelement name
# Return       : None
#---------------------------------------------------------------------------------
sub AlcatelPostDiscUpdate
{
	my ($self,$mydata,$selines)=@_;
    my $pLog=$self->{PLOG};
	my $verbose = $self->{LOGFILEVERBOSE};
    my $rtnCode="SUCCESS";
    my $func="AlcatelPostDiscUpdate";
    my (@Record10Info)=split($self->{"HEADERSEP"},$self->{"UII10HEADER"});
    my (@Record20Info)=split($self->{"HEADERSEP"},$self->{"UII20HEADER"});
    my $mysnmpprop=$self->{"SNMPSWITCH"};
    my %isSNMP=%{$self->{"SNMPTESTVALUES"}};
    my $recordUpdateCount=0;
    my $groupIn="EIN_GROUP";
    my $segroupIn="SEIN_GROUP";
    my $InValue="true";
	my $updateFailover = 0;
	my $currSSID;
	my $currMPLSType;
	# my $whichHash;
	my $currentLine;
	my $seMatchStatus = "FAIL";
	my $MatchKey;
	my $ProvMap = $self->{PROVISOMAP};
	my $Provisomap = $ProvMap;
	if ($ProvMap =~ /\.(\w+):\w+/)
	{
		 $Provisomap = $1;
	}	
	my $currentHost = ${$UIIRecord20Hash{$mydata}{$selines} }[$UIIRecordHash{$self->{HOSTNAMEPROP}}] ;
	my $currentTransType = ${$UIIRecord20Hash{$mydata}{$selines} }[$UIIRecordHash{$self->{TRANSTYPEPROP}}] ;	
	my $currentServiceID = ${$UIIRecord20Hash{$mydata}{$selines}}[$UIIRecordHash{BT_SERVICE_ID}];
	#Check if current UII line is for IPFilter
	if(exists $UIIRecordHash{BT_CHANNEL_GROUP_IP_ADDRESS} && exists $UIIRecordHash{BT_IP_FILTER_ID})
	{
		if(${$UIIRecord20Hash{$mydata}{$selines}}[$UIIRecordHash{BT_CHANNEL_GROUP_IP_ADDRESS}] !~ /^$/ && ${$UIIRecord20Hash{$mydata}{$selines} }[$UIIRecordHash{BT_IP_FILTER_ID}] !~ /^$/){
		
			&IPFilterPreSyncSEMatching($self,\@{$UIIRecord20Hash{$mydata}{$selines}},\%subelementSplitHash,\%subelementHash,\%UniqueMatchHash,$Provisomap,$selines);
			
			my $supplierBTPortID = ${$UIIRecord20Hash{$mydata}{$selines}}[$UIIRecordHash{BT_SUPPLIER_PORT_ID}];
			my @vlanArr = split("::", ${$UIIRecord20Hash{$mydata}{$selines}}[$UIIRecordHash{BT_VLAN_ID}] );
			my $uniqueVlanKey = $supplierBTPortID.".".$vlanArr[-1];
			$pLog->PrintDebug( "IPFilterPreSyncSEMatching: uniqueVlanKey ->  $uniqueVlanKey");
			
			#IPFilter details will be populated against Vlan record.
			#Hence there will be duplicate records for Vlans on which IPFilter is configured.
			#check if Vlan matching is already done.
			if(! exists $IPFilterVlanHash{$mydata}{$uniqueVlanKey}){
				$IPFilterVlanHash{$mydata}{$uniqueVlanKey} = 1;
			}
			else{
				$pLog->PrintDebug( "IPFilterPreSyncSEMatching: uniqueVlanKey ->  $uniqueVlanKey  Exists!");
				return;
			}
		}
	}
	if (${$UIIRecord20Hash{$mydata}{$selines} }[$UIIRecordHash{BT_VLAN_ID}] !~ /^$/)
	{
		my @AlnFamily = ("7750_Shaper","7750_SAP","7750_QoS"); #56947
		my $sapMatchStatus = "PASS";
		my $shaperMatchStatus = "PASS";
		
		foreach my $family (@AlnFamily) 
		{
			$seMatchStatus = "FAIL";
			($seMatchStatus)=AlcatelPreSyncSEMatching($self,\@{ $UIIRecord20Hash{$mydata}{$selines} },$family,$Provisomap,$selines,\$MatchKey);			   	
			#$pLog->PrintInfo("value of seMatchstatus is @$seMatchStatus"); 															
			if(($seMatchStatus eq "FAIL") &&($family eq "7750_SAP")){
				print MATCHPROC "Current UII line is not matched.Adding to InventoryResidueHash\n" ;
				$pLog->PrintInfo( "$func: Current UII line is not matched.Adding to InventoryResidueHash") if $verbose == 1;
				#$InventoryResidueHash{$mydata}{$selines} = $UIIRecord20Hash{$mydata}{$selines};
				$sapMatchStatus = "FAIL";
				last;
			}
			elsif(($seMatchStatus eq "FAIL") &&($family eq "7750_QoS"))
			{
				print MATCHPROC "Could not find matching 7750_QoS subelements for current UII data!\n" ;
				$pLog->PrintInfo( "$func: Could not find matching 7750_QoS subelements for current UII data!") if $verbose == 1;
				#$InventoryResidueHash{$mydata}{$selines} = $UIIRecord20Hash{$mydata}{$selines};
				last;
			}
			elsif(($seMatchStatus eq "FAIL") &&($family eq "7750_Shaper"))  #56947
			{
				print MATCHPROC "Could not find matching 7750_Shaper subelements for current UII data!\n" ;
				$pLog->PrintInfo( "$func: Could not find matching 7750_Shaper subelements for current UII data!") if $verbose == 1;
				#$InventoryResidueHash{$mydata}{$selines} = $UIIRecord20Hash{$mydata}{$selines};
				 $shaperMatchStatus = "FAIL";
				next;
			}  #56947
			elsif ($seMatchStatus ne "FAIL") 
			{   #$pLog->PrintInfo("Value of SE matched is ${$seMatchStatus}[0]");
				if(scalar(@$seMatchStatus)>0)
				{   #$pLog->PrintInfo("Length of the seMatchStatus subelements is scalar(@{$seMatchStatus})");
				    
					foreach my $seMatchEntry (@{$seMatchStatus})
					{					
						$seMatchEntry =~ s#(\s+)$##;
						$currentLine = $UniqueMatchHash{$currentHost}{$seMatchEntry};
						my @tempArr = @{$UIIRecord20Hash{$mydata}{$selines}};
						$MatchedKeysHash{$mydata}{$seMatchEntry}=[@tempArr];					 
						$currentLine =~ s#(\s+)$##;
						print MATCHPROC "Updating UII properties to the matched record.\n";
						$pLog->PrintInfo( "$func: Updating UII properties to the matched record.") if $verbose == 1;
						for my $propertyName (@Record20Info) {
							if (${ $UIIRecord20Hash{$mydata}{$selines} }[$UIIRecordHash{$propertyName}]!~/^\s*$/) {
								$currentLine .= "$propertyName|_|${ $UIIRecord20Hash{$mydata}{$selines} }[$UIIRecordHash{$propertyName}]|_|";
							}					
						}
						print MATCHPROC "After UII property update: $currentLine\n";
						#To add Call server properties for FUJ and HWE CMSANs
						if ( ${ $UIIRecord20Hash{$mydata}{$selines} }[$UIIRecordHash{BT_NE_ALTERNATE_ID}] !~ /^\s*$/ )	
						{
							my $ALTERNATE_ID = ${ $UIIRecord20Hash{$mydata}{$selines} }[$UIIRecordHash{BT_NE_ALTERNATE_ID}];
							$currentLine .= "CallServerID|_|$ALTERNATE_ID|_|";
						}   
						# To add BT_SS_ID as Port_SS_ID
						if ( ${ $UIIRecord20Hash{$mydata}{$selines} }[$UIIRecordHash{BT_SS_ID}] !~ /^\s*$/ )	
						{
							my $portSSID = ${ $UIIRecord20Hash{$mydata}{$selines} }[$UIIRecordHash{BT_SS_ID}];
							$currentLine .= "Port_SS_ID|_|$portSSID|_|";
						}   

						$UniqueMatchHash{$currentHost}{$seMatchEntry} = $currentLine;
						print MATCHPROC "Updated UII properties to the matched record.\n";
						$pLog->PrintInfo( "$func: Updated UII properties to the matched record.") if $verbose == 1;
						if ( ${ $UIIRecord20Hash{$mydata}{$selines} }[$UIIRecordHash{BT_PORT_ID}] !~ /^\s*$/){
							$currSSID = ${$UIIRecord20Hash{$mydata}{$selines}}[$UIIRecordHash{BT_SS_ID}];
							UpdateSSID ($self,$mydata,$selines,$currentHost,$seMatchEntry,$currSSID,"7750_Network_QoS",\%UniqueMatchHash);
							print MATCHPROC "Finished SSID update on subelement.dat.\n";
							$pLog->PrintInfo( "$func: Finished SSID update on subelement.dat.") if $verbose == 1;
						}
						if ( ${ $UIIRecord20Hash{$mydata}{$selines} }[$UIIRecordHash{BT_PORT_MPLS_TYPE}] !~ /^\s*$/ ){
							my $currMPLSType = ${$UIIRecord20Hash{$mydata}{$selines}}[$UIIRecordHash{BT_PORT_MPLS_TYPE}];
							UpdateMPLSType ($self,$mydata,$currentHost,$seMatchEntry,$currMPLSType,"7750_Network_QoS",\%UniqueMatchHash);
							print MATCHPROC "Finished MPLS update on subelement.dat.\n";
							$pLog->PrintInfo( "$func: Finished MPLS update on subelement.dat.") if $verbose == 1;
						}					
						$recordUpdateCount++;
						#Added for ELAN
					}
					
				}
				#End of Addition for ELAN
				if($currentTransType eq "I")
				{
					print ALNDELETEINPUT "$mydata:$currentServiceID:$MatchKey\n" ;
				}
				if($family=~ /7750_Shaper/i) #56947
				{   
					last;
				}				
			}
			else 
			{
				#print MATCHPROC "Current UII line is not matched.Adding to InventoryResidueHash\n" ;
				#$pLog->PrintInfo( "$func: Current UII line is not matched.Adding to InventoryResidueHash") if $verbose == 1;
				#$InventoryResidueHash{$mydata}{$selines} = $UIIRecord20Hash{$mydata}{$selines};
			}
			
		}
		$seMatchStatus = "FAIL";
		
		if( $sapMatchStatus eq "FAIL" && $shaperMatchStatus eq "FAIL" )
		{
			$InventoryResidueHash{$mydata}{$selines} = $UIIRecord20Hash{$mydata}{$selines};
		}
	}
	else
	{
		($seMatchStatus) = AlcatelPreSyncSEMatching($self,\@{$UIIRecord20Hash{$mydata}{$selines}},$mydata,$Provisomap,$selines,\$MatchKey);
		if ( $seMatchStatus eq "FAIL" ) 
		{
			$updateFailover = 1;
		} else {
			
			# 2014 August 15 Edwin Liong
			# 21CNCE -RelAQ 77847 Continue lookup for Alcatel Lag matching
			if ( ${ $UIIRecord20Hash{$mydata}{$selines}}[$UIIRecordHash{BT_LAG_ID}] !~ /^$/ ) {
				my $seIETFMatchStatus = "FAIL";
				($seIETFMatchStatus) = AlcatelIETFPreSyncSEMatching($self,\@{$UIIRecord20Hash{$mydata}{$selines}},$mydata,$Provisomap,$selines,\$MatchKey);
				
				if ($seIETFMatchStatus ne 'FAIL') {
					push (@$seMatchStatus, @$seIETFMatchStatus);
				}
			}
		}
	}
	# if match is found
	if ($seMatchStatus ne "FAIL") 
	{
		if(scalar(@$seMatchStatus)>0)
		{
			foreach my $seMatchEntry (@$seMatchStatus)
			{
				$currentLine = $UniqueMatchHash{$currentHost}{$seMatchEntry};
				my @tempArr = @{$UIIRecord20Hash{$mydata}{$selines}};
				$MatchedKeysHash{$mydata}{$seMatchEntry}=[@tempArr];
				$seMatchEntry =~ s#(\s+)$##;
				$currentLine =~ s#(\s+)$##;
				print MATCHPROC "Updating UII properties to the matched record.\n";
				$pLog->PrintInfo( "$func: Updating UII properties to the matched record.") if $verbose == 1;
				for my $propertyName (@Record20Info) {
					if (${ $UIIRecord20Hash{$mydata}{$selines} }[$UIIRecordHash{$propertyName}]!~/^\s*$/) {
						$currentLine .= "$propertyName|_|${ $UIIRecord20Hash{$mydata}{$selines} }[$UIIRecordHash{$propertyName}]|_|";
					}
					#BS 21CNCE-23418 Changes
					#Update ZEND details as 'NULL' if UII feed contains null data for EES, EEA, IEA
					elsif (($propertyName eq "BT_ZEND_LOC_1141") || ($propertyName eq "BT_ZEND_SNE") || ($propertyName eq "BT_ZEND_TP")) {
						my $SupplierID = ${ $UIIRecord10Hash{$mydata} }[$UIIRecordHash{BT_SUPPLIER_ID}];
						my $NEType = ${ $UIIRecord10Hash{$mydata} }[$UIIRecordHash{BT_NE_TYPE}];
						my $NEUsage = ${ $UIIRecord10Hash{$mydata} }[$UIIRecordHash{BT_NE_USAGE}];

						if (( $SupplierID eq "ALN" && $NEType eq "Edge Rt" && $NEUsage eq "Edge Ethernet Switch") ||
						( $SupplierID eq "ALN" && $NEType eq "Edge Rt" && $NEUsage eq "Multi Service Edge") ||
						( $SupplierID eq "ALN" && $NEType eq "Edge Rt" && $NEUsage eq "Infra Edge Agg") ||
						( $SupplierID eq "ALN" && $NEType eq "Edge Rt" && $NEUsage eq "Multi Service Core") ||
						( $SupplierID eq "ALN" && $NEType eq "Edge Rt" && ($NEUsage eq "Flexible Build EEA" || $NEUsage eq "Ethernet Edge Router"))) {
							$currentLine .= "$propertyName|_|NULL|_|";
						}
					}
					# 2014 August 15 Edwin Liong
					# 21CNCE -RelAQ 77847 Update BT_CUSTOMER_NAME Attribute to NULL value for MSE/MSC if the BT_CUSTOMER_NAME is empty
					elsif (($propertyName eq "BT_CUSTOMER_NAME")) {
						my $btModel = ${ $UIIRecord10Hash{$mydata} }[$UIIRecordHash{BT_MODEL}];
						my $NEUsage = ${ $UIIRecord10Hash{$mydata} }[$UIIRecordHash{BT_NE_USAGE}];
						my $zendModel = ${ $UIIRecord20Hash{$mydata}{$selines} }[$UIIRecordHash{BT_ZEND_MODEL}];
						my $zendType = ${ $UIIRecord20Hash{$mydata}{$selines} }[$UIIRecordHash{BT_ZEND_TYPE}];
						my $lagId = ${ $UIIRecord20Hash{$mydata}{$selines} }[$UIIRecordHash{BT_LAG_ID}];
						
						if ( $btModel =~ /7750 SR-12/ && $NEUsage =~ /Multi Service Core|Multi Service Edge/ && 
							$zendModel =~ /GENERIC/ && $zendType =~ /XTS/ && $lagId !~ /^\s*$/ ) {
							$currentLine .= "$propertyName|_|NULL|_|";
						}
					}
				}
				print MATCHPROC "After UII property update: $currentLine\n";		
				#To add Call server properties for FUJ and HWE CMSANs
				# if ( ${ $UIIRecord20Hash{$mydata}{$selines} }[$UIIRecordHash{BT_NE_ALTERNATE_ID}] !~ /^\s*$/ )	
				# {
					# my $ALTERNATE_ID = ${ $UIIRecord20Hash{$mydata}{$selines} }[$UIIRecordHash{BT_NE_ALTERNATE_ID}];
					# $currentLine .= "CallServerID|_|$ALTERNATE_ID|_|";
				# }   
				# To add BT_SS_ID as Port_SS_ID
				if ( ${ $UIIRecord20Hash{$mydata}{$selines} }[$UIIRecordHash{BT_SS_ID}] !~ /^\s*$/ )	
				{
					my $portSSID = ${ $UIIRecord20Hash{$mydata}{$selines} }[$UIIRecordHash{BT_SS_ID}];
					$currentLine .= "Port_SS_ID|_|$portSSID|_|";
				}            

								$UniqueMatchHash{$currentHost}{$seMatchEntry} = $currentLine;
				print MATCHPROC "Updated UII properties to the matched record.\n";
				$pLog->PrintInfo( "$func: Updated UII properties to the matched record.") if $verbose == 1;
				if ( ${ $UIIRecord20Hash{$mydata}{$selines} }[$UIIRecordHash{BT_PORT_ID}] !~ /^\s*$/ ){
					$currSSID = ${$UIIRecord20Hash{$mydata}{$selines}}[$UIIRecordHash{BT_SS_ID}];
					UpdateSSID($self,$mydata,$selines,$currentHost,$seMatchEntry,$currSSID,"7750_Network_QoS",\%UniqueMatchHash);
					print MATCHPROC "Finished SSID update on subelement.dat.\n";
					$pLog->PrintInfo( "$func: Finished SSID update on subelement.dat.") if $verbose == 1;
				}
				if ( ${ $UIIRecord20Hash{$mydata}{$selines} }[$UIIRecordHash{BT_PORT_MPLS_TYPE}] !~ /^\s*$/ ){
					my $currMPLSType = ${$UIIRecord20Hash{$mydata}{$selines}}[$UIIRecordHash{BT_PORT_MPLS_TYPE}];
					UpdateMPLSType ($self,$mydata,$currentHost,$seMatchEntry,$currMPLSType,"7750_Network_QoS",\%UniqueMatchHash);
					print MATCHPROC "Finished MPLS update on subelement.dat.\n";
					$pLog->PrintInfo( "$func: Finished MPLS update on subelement.dat.") if $verbose == 1;
				}
				$recordUpdateCount++;
				#Added as part of ELAN Dev
			}
		}
	}
	# if match is not found
	else
	{
		if ($updateFailover == 1)
		{
			print MATCHPROC "Current UII line is not matched.Adding to InventoryResidueHash\n";
			$pLog->PrintInfo( "$func: Current UII line is not matched.Adding to InventoryResidueHash") if $verbose == 1;
			$InventoryResidueHash{$mydata}{$selines} = $UIIRecord20Hash{$mydata}{$selines};
		}
	}
}
#------------------------------------End of AlcatelPostDiscUpdate--------------------------------------------#
#===========================================================================================================
# Name 				: processPostFERDiscUpdate
# Author 			: Amarnath Peddi
# Description 		: Performs the property Updates for FER and BEA,performs SEMatching and updates the 
#					  corresponding subelement.dat with the properties and also Performs the alarm Enrichment
# Input 			: Path of the Profile Directory
# Output 			: Returns SUCCESS or FAIL
#============================================================================================================
sub processPostFERDiscUpdate
{
	my ($self, $mydata,$selines,$poidHashRef)=@_;
    my $pLog=$self->{PLOG};
	my $verbose = $self->{LOGFILEVERBOSE};
    my $rtnCode="FAIL";
    my $func="processPostFERDiscUpdate";
	my $mysnmpprop=$self->{"SNMPSWITCH"};
	my %isSNMP=%{$self->{"SNMPTESTVALUES"}};
	my $groupIn="EIN_GROUP";
    my $segroupIn="SEIN_GROUP";
    my $InValue="true";
	my $sedbIndex;
	my $recordUpdateCount=0;
	my $sematchhashflag=0;
	my $myTransType=$self->{"TRANSTYPEPROP"}; 
	my (@Record20Info)=split($self->{"HEADERSEP"},$self->{"UII20HEADER"});
	my $currentLine;
	my $seMatchStatus = "FAIL";
	my $currentHost=${$UIIRecord20Hash{$mydata}{$selines}}[$UIIRecordHash{BT_IP_NAME}];
	my (@ClassArr)=split($self->{"HEADERSEP"},$self->{"CLASSTYPE"});
	# Looping through each class present in the CLASSTYPE provided in the processUII.cfg
	foreach my $class (@ClassArr) 
	{
		$sedbIndex = "FAIL";
		# Calling the PreSyncSEMatching to find a match in the discovered subelement.dat
		$sedbIndex=preSyncSEFERMatching($self,\@{ $UIIRecord20Hash{$mydata}{$selines} },$class,$poidHashRef);
		# Checking the Match is found or not								
		if ( $sedbIndex !~ /^$/ && $sedbIndex ne "FAIL"  ) 
		{
			if(! exists($UniqueMatchHash{$currentHost}{$sedbIndex}))
			{
				$currentLine = $UniqueSEInvMatchHash{$currentHost}{$sedbIndex};
				chomp $currentLine;
				my @tempArr=();
				(@tempArr)=@{$UIIRecord20Hash{$mydata}{$selines}};
				$MatchedinvariantKeysHash{$mydata}{$sedbIndex}=[@tempArr];
				$sematchhashflag=1;
			}
			if(! exists($UniqueSEInvMatchHash{$currentHost}{$sedbIndex}))
			{
				$currentLine = $UniqueMatchHash{$currentHost}{$sedbIndex};
				my @tempArr=();
				(@tempArr)=@{$UIIRecord20Hash{$mydata}{$selines}};
				$MatchedKeysHash{$mydata}{$sedbIndex}=[@tempArr];
				chomp $currentLine;
			}
			print MATCHPROC "Updating UII properties to the matched record.\n";
			$pLog->PrintInfo( "$func: Updating UII properties to the matched record.") if $verbose == 1;
			# If the match is found the record UII properties are updated aganist the found Entry
			for my $propertyName (@Record20Info) 
			{
				if (${ $UIIRecord20Hash{$mydata}{$selines} }[$UIIRecordHash{$propertyName}]!~/^\s*$/) 
				{
					#Updating the matched record with the properties from the UII Feed
					$currentLine.= "$propertyName|_|${ $UIIRecord20Hash{$mydata}{$selines} }[$UIIRecordHash{$propertyName}]|_|";
				}
			}
			print MATCHPROC "After UII property update: $currentLine\n";
			# To add PolicerName property using below fields from UII (SE) for Cisco 6509 FER
			my ($cugID,$rtVal,$asVal,$ipscbeVal,$ipscasVal,$beVal) = (0,0,0,0,0,0);
			$cugID = ${$UIIRecord20Hash{$mydata}{$selines}}[$UIIRecordHash{BT_CUG_ID}] if (${$UIIRecord20Hash{$mydata}{$selines}}[$UIIRecordHash{BT_CUG_ID}] ne "");
			my $vlanVal = ${$UIIRecord20Hash{$mydata}{$selines}}[$UIIRecordHash{BT_VLAN_BANDWIDTH}];			
			$rtVal = ${$UIIRecord20Hash{$mydata}{$selines}}[$UIIRecordHash{BT_TOTAL_WBC_REAL_TIME_BW}];
			$asVal = ${$UIIRecord20Hash{$mydata}{$selines}}[$UIIRecordHash{BT_TOTAL_WBC_ASSURED_RATE_BW}];
			$ipscbeVal = ${$UIIRecord20Hash{$mydata}{$selines}}[$UIIRecordHash{BT_TOTAL_IPSC_BEST_EFFORT_BW}];
			$ipscasVal = ${$UIIRecord20Hash{$mydata}{$selines}}[$UIIRecordHash{BT_TOTAL_IPSC_ASSURED_RATE_BW}];	
			$beVal = ${$UIIRecord20Hash{$mydata}{$selines}}[$UIIRecordHash{BT_TOTAL_WBC_BEST_EFFORT_BW}];
			my ($rtbcVal,$asbcVal,$ipscbebcVal,$ipscasbcVal,$bebcVal,$poid,$DeviceIP) = (0,0,0,0,0,0,0);
			$rtbcVal = ${$UIIRecord20Hash{$mydata}{$selines}}[$UIIRecordHash{BT_MAX_WBC_REAL_TIME_BC}];
			$asbcVal = ${$UIIRecord20Hash{$mydata}{$selines}}[$UIIRecordHash{BT_MAX_WBC_ASSURED_RATE_BC}];
			$ipscbebcVal = ${$UIIRecord20Hash{$mydata}{$selines}}[$UIIRecordHash{BT_MAX_IPSC_BEST_EFFORT_BC}];
			$ipscasbcVal = ${$UIIRecord20Hash{$mydata}{$selines}}[$UIIRecordHash{BT_MAX_IPSC_ASSURED_RATE_BC}];	
			$bebcVal = ${$UIIRecord20Hash{$mydata}{$selines}}[$UIIRecordHash{BT_MAX_WBC_BEST_EFFORT_BC}];
			#POID Value
			$poid = ${$UIIRecord20Hash{$mydata}{$selines}}[$UIIRecordHash{BT_BBASVLAN_RT_POLICY_ID}];
			#IP ADDRESS of the device
			$DeviceIP = ${$UIIRecord20Hash{$mydata}{$selines}}[$UIIRecordHash{BT_IP_ADDRESS}];
			my $loaddir = $self->{"THISLOADDIR"}."/".$self->{"THISLOADINFO"}; 			
			#Varibales to store the value of Allocated BW for all classes
			my ($rtAlVal,$asAlVal,$ipscbeAlVal,$ipscasAlVal,$beAlVal) = (0,0,0,0,0);
			my $record = "";
			#------------------------------------------------------------------------------
			# Calling calAllocatedBW to calculate the bandwidth depending on the class-Type
			#------------------------------------------------------------------------------
			$rtAlVal = $self->calAllocatedBW(\$rtVal,\$rtbcVal,$poid,$DeviceIP,$class,$loaddir);
			$asAlVal = $self->calAllocatedBW(\$asVal,\$asbcVal,$poid,$DeviceIP,$class,$loaddir);
			$beAlVal = $self->calAllocatedBW(\$beVal,\$bebcVal,$poid,$DeviceIP,$class,$loaddir);
			$ipscasAlVal = $self->calAllocatedBW(\$ipscasVal,\$ipscasbcVal,,$poid,$DeviceIP,$class,$loaddir);
			$ipscbeAlVal = $self->calAllocatedBW(\$ipscbeVal,\$ipscbebcVal,$poid,$DeviceIP,$class,$loaddir);
			#Updating the allocated bandwidth in the Matched Record				
			if ($class =~ /WBMC-WBC-RT/) {
				$record = "BT_TOTAL_WBC_REAL_TIME_BW|_|$rtVal|_|BT_MAX_WBC_REAL_TIME_BC|_|$rtbcVal|_|BT_MAX_ALLOCATED_BW|_|$rtAlVal|_|";
				 $currentLine.=$record;
			}
			elsif ($class =~ /WBMC-WBC-AR/) {
				$record = "BT_TOTAL_WBC_ASSURED_RATE_BW|_|$asVal|_|BT_MAX_WBC_ASSURED_RATE_BC|_|$asbcVal|_|BT_MAX_ALLOCATED_BW|_|$asAlVal|_|";
				 $currentLine.=$record;
			}
			elsif ($class =~ /WBMC-WBC-BE/) {
				$record = "BT_TOTAL_WBC_BEST_EFFORT_BW|_|$beVal|_|BT_MAX_WBC_BEST_EFFORT_BC|_|$bebcVal|_|BT_MAX_ALLOCATED_BW|_|$beAlVal|_|";
				 $currentLine.=$record;
			}
			elsif ($class =~ /WBMC-IPSC-AR/) {
				$record = "BT_TOTAL_IPSC_ASSURED_RATE_BW|_|$ipscasVal|_|BT_MAX_IPSC_ASSURED_RATE_BC|_|$ipscasbcVal|_|BT_MAX_ALLOCATED_BW|_|$ipscasAlVal|_|";
				 $currentLine.=$record;
			}
			elsif ($class =~ /WBMC-IPSC-BE/) {
				$record = "BT_TOTAL_IPSC_BEST_EFFORT_BW|_|$ipscbeVal|_|BT_MAX_IPSC_BEST_EFFORT_BC|_|$ipscbebcVal|_|BT_MAX_ALLOCATED_BW|_|$ipscbeAlVal|_|";
				 $currentLine.=$record;
			}
			
			if( $vlanVal !~ /^$/ ) {
					my $policerName = $cugID."_".$vlanVal."_".$rtAlVal."_".$asAlVal."_".$ipscasAlVal."_".$ipscbeAlVal;
				 $currentLine.= "PolicerName|_|$policerName|_|";
			}
			# Writing back the updated entry to the Unique Match Hash
			print MATCHPROC "Updated UII properties to the matched record.\n";
			$pLog->PrintInfo( "$func: Updated UII properties to the matched record.") if $verbose == 1;
			if($sematchhashflag==0)
			{
				$UniqueMatchHash{$currentHost}{$sedbIndex} = $currentLine;
			}
			elsif($sematchhashflag==1)
			{
				$UniqueSEInvMatchHash{$currentHost}{$sedbIndex} = $currentLine;
			}
			$recordUpdateCount++;
		}
	}
	if ($recordUpdateCount == 0) {		
		print MATCHPROC "Current UII line is not matched.Adding to InventoryResidueHash\n";
		$pLog->PrintInfo( "$func: Current UII line is not matched.Adding to InventoryResidueHash") if $verbose == 1;
		$InventoryResidueHash{$mydata}{$selines} = $UIIRecord20Hash{$mydata}{$selines};
	}
}
#------------------------------------End of processPostFERDiscUpdate--------------------------------------------#
#===========================================================================================================
# Name 				: processGenericDiscUpdate
# Author 			: Amarnath Peddi
# Description 		: This method finds a match in the sub-element.dat 
# Input 			: Path of the Profile Directory
# Output 			: Returns SUCCESS or FAIL
# Calling Routines  : This sub-routine calls no sub-routines
#============================================================================================================
sub processGenericDiscUpdate
{
    my ($self, $arrSEData,$mydata,$selines)=@_;
	my $entry;
    my $pLog=$self->{PLOG};
	my $verbose = $self->{LOGFILEVERBOSE};
    my $rtnCode="FAIL";
    my $func="processGenericDiscUpdate";
	my (@Record20Info)=split($self->{"HEADERSEP"},$self->{"UII20HEADER"});
    my $currentDevice="";
    my (@matchList);
    my $testexpression;
    my $currentHost="";
    my $position=1;
    my $mysnmpprop=$self->{"SNMPSWITCH"};
	my $sematchhashflag=0;
	my $currentLine;
	my $groupIn="EIN_GROUP";
    my $segroupIn="SEIN_GROUP";
    my $InValue="true";
    $currentDevice=$$arrSEData[$UIIRecordHash{$self->{IPADDPROP}}];
    $currentHost=$$arrSEData[$UIIRecordHash{$self->{HOSTNAMEPROP}}];
    my $myData = $currentHost."|_|".$currentDevice;
	my $currNEID = $$arrSEData[$UIIRecordHash{BT_NE_ID}];
	my $PortID= $$arrSEData[$UIIRecordHash{BT_PORT_ID}];
	my $suppPortID = $$arrSEData[$UIIRecordHash{BT_SUPPLIER_PORT_ID}];
	my $VLANID = $$arrSEData[$UIIRecordHash{BT_VLAN_ID}];
	my $UIIdata = $myData.'|_|'.$currNEID.'|_|'.$PortID.'|_|'.$suppPortID.'|_|'.$VLANID.'|_|';
	my $btSupplier = ${$UIIRecord10Hash{$myData}}[$UIIRecordHash{BT_SUPPLIER_ID}];
	my $btModel = ${$UIIRecord10Hash{$myData}}[$UIIRecordHash{BT_MODEL}];
#49924	
	my $btLagID = $$arrSEData[$UIIRecordHash{BT_LAG_ID}];
#49924	
	my $flag = "";
	my @matchedSENames;
	if ($self->{FEEDMAP} ne "NULL")
	{
		@matchList=();
		# Create the default (BT_SUPPLIER_PORT_ID) matchkey array  
		push(@matchList,$self->{FEEDMAP});		
		if ($self->{FEEDALT}ne"NULL")
		{
			# Add all matching keys
			my (@altMatch)=split($self->{HEADERSEP},$self->{FEEDALT});
			chomp (@altMatch);
			push (@matchList,@altMatch);
		}
		my $vlanFlag =0;
		my $vlanNum ;		
		if ( ${$UIIRecord10Hash{$myData}}[$UIIRecordHash{BT_MODEL}] eq "MGX 8880" && $$arrSEData[$UIIRecordHash{BT_NE_TYPE}] eq "Trunk GW" && $$arrSEData[$UIIRecordHash{$matchList[3]}] !~ /^$/ )
		{
			# SE Matching Test Expression is value of only BT_VAG_ID (taken from 'this' line of SE)
			$testexpression = $$arrSEData[$UIIRecordHash{$matchList[3]}];
		}
        #---- CIS CDE-220 / CDE-250 device SE Matching for LAG & Port SE. Specific case to take care of no 1-1 match between OSS & N/W.
		#---- Rel AF(+). 21CNCE-54538. 22 Jan 2013.
		elsif (${$UIIRecord10Hash{$myData}}[$UIIRecordHash{BT_NE_TYPE}] =~ /CDE-220|CDE-250/ && ${$UIIRecord10Hash{$myData}}[$UIIRecordHash{BT_SUPPLIER_ID}] eq "CIS")
		{	
			# LAG SE. UII will have BT_LAG_ID=X (a number) where as network will have PortChannelX (string 'PortChannel' prefixed with number)
			# so create a test expression using UII record which can match with network format
			if ($$arrSEData[$UIIRecordHash{$matchList[2]}] !~ /^$/) {				
				my $lagNum = $$arrSEData[$UIIRecordHash{$matchList[2]}];					
				$testexpression = "PortChannel".$lagNum;
			}			
			# Port SE. If BT_LAG_ID is NULL, match Port SE using BT_SUPPLIER_PORT_ID from UII and BT_MATCH_1 from network for 1-1 match
			elsif ($$arrSEData[$UIIRecordHash{$matchList[2]}] =~ /^$/ && $$arrSEData[$UIIRecordHash{$matchList[0]}] !~ /^$/) {
				$testexpression = $$arrSEData[$UIIRecordHash{$matchList[0]}];					
			}                    
		}# -- END of 54538 changes ---
		## If value of VLAN ID is available along with BT_SUPPLIER_PORT ID
		elsif( $$arrSEData[$UIIRecordHash{$matchList[1]}] !~ /^$/ )
		{
			# creating expression to be used for matching
			my $vlanID = $$arrSEData[$UIIRecordHash{$matchList[1]}];
			my @vlanArr = split("::", $vlanID);
			$vlanNum = $vlanArr[scalar(@vlanArr) - 1];
			chomp($vlanNum);
			$testexpression = $$arrSEData[$UIIRecordHash{$matchList[0]}];
			chomp($testexpression);
			if( $vlanNum !~ /^$/ ){
				my $addedTestExpr = "$testexpression"."."."$vlanNum";
				chomp($addedTestExpr);
				$testexpression=$addedTestExpr;
				$vlanFlag = 1;
			}				
		}
		# Only FEEDMAP vlaue is present (BT_SUPPLIER_ID)
		else {
			$testexpression = $$arrSEData[$UIIRecordHash{$matchList[0]}];
		}
		print MATCHPROC "Current Element: $currentHost\n" if $verbose == 1; 
		print MATCHPROC "Current UII Line: @$arrSEData\n" if $verbose == 1;
		print MATCHPROC "Current Testexpression: $testexpression\n" if $verbose == 1;	
		print MATCHPROC "Current UII Data: $UIIdata$testexpression\n" if $verbose != 1; 
		$pLog->PrintInfo( "$func: Current UII Data - $UIIdata$testexpression") if $verbose == 1; 			
		if( $testexpression && $testexpression =~ /\w+/ )
		{	
			if( ${$UIIRecord10Hash{$myData}}[$UIIRecordHash{BT_SUPPLIER_ID}]eq"CIS" && $$arrSEData[$UIIRecordHash{BT_NE_TYPE}] eq "VIRTUAL SW" && $$arrSEData[$UIIRecordHash{$matchList[1]}] !~ /^$/ && $$arrSEData[$UIIRecordHash{$matchList[4]}] !~ /^poid/i && $MSIfeedflag eq "MSI")
			{
				$entry=findGenericMatch($self,$testexpression,$arrSEData,$MSIfeedflag);
			}
			else
			{
				# 20140908 [YepChoon] : Change logic to support all CAT6500 for vlan matching using trunkport
				#if(${$UIIRecord10Hash{$myData}}[$UIIRecordHash{BT_NE_USAGE}] =~ /BEA|BEA-VS/ && $$arrSEData[$UIIRecordHash{BT_VLAN_ID}] !~ /^$/ && $$arrSEData[$UIIRecordHash{BT_LAG_ID}] =~ /^$/)
				#{
				#	$MSIfeedflag="MSI";
				#}
				if( ${$UIIRecord10Hash{$myData}}[$UIIRecordHash{BT_MODEL}] eq "CAT6500"
						&& ${$UIIRecord10Hash{$myData}}[$UIIRecordHash{BT_NE_USAGE}] =~ /BEA|BEA-VS|HT BEA-VS|FER|FER-VS|MEA|MGMT SW|INFRA SW|L2 BB SW|L3 BB SW|MAR|AR|STD/ 
						&& $$arrSEData[$UIIRecordHash{BT_VLAN_ID}] !~ /^$/ 
						&& $$arrSEData[$UIIRecordHash{BT_LAG_ID}] =~ /^$/)
				{
					$MSIfeedflag="MSI";
				}
				else
				{
					$MSIfeedflag="NULL";
				}
				my $model = ${$UIIRecord10Hash{$myData}}[$UIIRecordHash{BT_MODEL}];
				my $usage = ${$UIIRecord10Hash{$myData}}[$UIIRecordHash{BT_NE_USAGE}];
				$pLog->PrintInfo( "$func: Test Expression: $testexpression, MSIfeedflag=$MSIfeedflag, BT_MODEL=$model, BT_NE_USAGE=$usage") if $verbose == 1; 
				$entry=findGenericMatch($self,$testexpression,$arrSEData,$MSIfeedflag);
				$MSIfeedflag="NULL";
			}
			if ( $entry !~ /^$/ && $entry ne "FAIL"  ) 
			{
				if(! exists($UniqueMatchHash{$currentHost}{$entry}))
				{
					$currentLine = $UniqueSEInvMatchHash{$currentHost}{$entry};
					chomp $currentLine;
					$MatchedinvariantKeysHash{$myData}{$entry}=$arrSEData if(! exists $MatchedinvariantKeysHash{$myData}{$entry});
					$sematchhashflag=1;
				}
				if(! exists($UniqueSEInvMatchHash{$currentHost}{$entry}))
				{
					$currentLine = $UniqueMatchHash{$currentHost}{$entry};					
					$MatchedKeysHash{$myData}{$entry}=$arrSEData if(! exists $MatchedKeysHash{$myData}{$entry});
					chomp $currentLine;
				}
				print MATCHPROC "Updating UII properties to the matched record.\n";
				$pLog->PrintInfo( "$func: Updating UII properties to the matched record.") if $verbose == 1;
				# If the match is found the record properties are updated aganist the found Entry
				if( ${$UIIRecord10Hash{$myData}}[$UIIRecordHash{BT_SUPPLIER_ID}]eq"CIS" && $$arrSEData[$UIIRecordHash{BT_NE_TYPE}] eq "VIRTUAL SW" && $$arrSEData[$UIIRecordHash{$matchList[1]}] !~ /^$/ && $$arrSEData[$UIIRecordHash{$matchList[4]}] !~ /^poid/i && $MSIfeedflag eq "MSI")
				{		
					for my $propertyName (@Record20Info)
					{
						if ($$arrSEData[$UIIRecordHash{$propertyName}]!~/^\s*$/)
						{   if($propertyName eq 'BT_TOTAL_WBC_BEST_EFFORT_BW'){
                               #$pLog->PrintInfo( "$func: Value of property $propertyName \= $$arrSEData[$UIIRecordHash{$propertyName}] before calculation"); 						
								$$arrSEData[$UIIRecordHash{$propertyName}] = $$arrSEData[$UIIRecordHash{$propertyName}]-($$arrSEData[$UIIRecordHash{BT_TOTAL_WBC_ASSURED_RATE_BW}]+($$arrSEData[$UIIRecordHash{BT_BBASVLAN_RT_BANDWIDTH}]/1000));
								#$pLog->PrintInfo( "$func: Value of property $propertyName \= $$arrSEData[$UIIRecordHash{$propertyName}] after calculation");
				
							}
							if($propertyName eq 'BT_BBASVLAN_RT_BANDWIDTH'){
							#$pLog->PrintInfo( "$func: Value of property $propertyName \= $$arrSEData[$UIIRecordHash{$propertyName}] before calculation"); 
								$$arrSEData[$UIIRecordHash{$propertyName}] = $$arrSEData[$UIIRecordHash{$propertyName}]*1000;
								#$pLog->PrintInfo( "$func: Value of property $propertyName \= $$arrSEData[$UIIRecordHash{$propertyName}] after calculation");
							} 
							if( exists $MSIProperties{$propertyName})
							{
								$currentLine.= "$propertyName|_|$$arrSEData[$UIIRecordHash{$propertyName}]|_|";
							}
							elsif($currentLine !~ /$propertyName/)
							{
								$currentLine.= "$propertyName|_|$$arrSEData[$UIIRecordHash{$propertyName}]|_|";
							}
						}
					}
				}
				else
				{
					for my $propertyName (@Record20Info) 
					{
#49924				
#Inserting BT_LAG_ID property for Ports		
						if($propertyName eq 'BT_LAG_ID' && $btModel =~ /CRS-1|CRS-3|Juniper T640|T1600|Juniper M320|Juniper Tx Matrix/) 
						{	
							if 	($$arrSEData[$UIIRecordHash{$propertyName}] =~ /^\s*$/)
							{
								$currentLine.= "$propertyName|_|no-lag|_|";		
								next;						
							}	
							else
							{
								my $lagId="" ;
								if(($btModel eq "CRS-1")||($btModel eq "CRS-3")){
									$lagId  = "Bundle-Ether".$btLagID;	
								}
								elsif(($btModel eq "Juniper T640")||($btModel eq "T1600")||($btModel eq "Juniper M320")||($btModel eq "Juniper Tx Matrix")){
									$lagId  = "ae".$btLagID; #from uii we get BT_LAG_ID as 1 or 2 and we have to get it as Bundle-Ether or ae so that is why we are adding it here.
								}
								$currentLine.= "$propertyName|_|$lagId|_|";	
								next;
							}
						}
#49924						
						if ($$arrSEData[$UIIRecordHash{$propertyName}]!~/^\s*$/) 
						{
							if($propertyName eq 'BT_TOTAL_WBC_BEST_EFFORT_BW'){						
								$$arrSEData[$UIIRecordHash{$propertyName}] = $$arrSEData[$UIIRecordHash{$propertyName}]-($$arrSEData[$UIIRecordHash{BT_TOTAL_WBC_ASSURED_RATE_BW}]+($$arrSEData[$UIIRecordHash{BT_BBASVLAN_RT_BANDWIDTH}]/1000));
				
							}
							if($propertyName eq 'BT_BBASVLAN_RT_BANDWIDTH'){
								$$arrSEData[$UIIRecordHash{$propertyName}] = $$arrSEData[$UIIRecordHash{$propertyName}]*1000;
							}
							#Updating the matched record with the properties from the UII Feed
							$currentLine.= "$propertyName|_|$$arrSEData[$UIIRecordHash{$propertyName}]|_|";
						}
						#BS 21CNCE-23418 Changes
						#Update ZEND details as 'NULL' if UII feed contains null data for P Router and PE Router devices
						elsif (($propertyName eq "BT_ZEND_LOC_1141") || ($propertyName eq "BT_ZEND_SNE") || ($propertyName eq "BT_ZEND_TP"))
						{
							my $SupplierID = ${ $UIIRecord10Hash{$mydata} }[$UIIRecordHash{BT_SUPPLIER_ID}];
							my $NEType = ${ $UIIRecord10Hash{$mydata} }[$UIIRecordHash{BT_NE_TYPE}];
							my $NEUsage = ${ $UIIRecord10Hash{$mydata} }[$UIIRecordHash{BT_NE_USAGE}];

							if (($SupplierID eq "CIS" && $NEType eq "Core Rt" && ($NEUsage eq "STD" || $NEUsage eq "Edge Rt")) ||
							(($SupplierID eq "LUC" || $SupplierID eq "SIE" || $SupplierID eq "JUN") && ($NEType eq "Edge Rt" || $NEType eq "Core Rt") && ($NEUsage eq "PE CO (Voice)" || $NEUsage eq "STD")))
							{
								$currentLine.= "$propertyName|_|NULL|_|";
							}
						}
					}
				}
				print MATCHPROC "After UII property update: $currentLine\n";			
				if ( $$arrSEData[$UIIRecordHash{BT_SS_ID}] !~ /^\s*$/ )	
				{
					my $portSSID = $$arrSEData[$UIIRecordHash{BT_SS_ID}];
					$currentLine .= "Port_SS_ID|_|$portSSID|_|";
				}
#49924
				 #if ( $$arrSEData[$UIIRecordHash{BT_PORT_MPLS_TYPE}] !~ /^\s*$/ )	
				#{
				#	my $portMPLS = $$arrSEData[$UIIRecordHash{BT_PORT_MPLS_TYPE}];
				#	$currentLine .= "BT_PORT_MPLS_TYPE|_|$portMPLS|_|";
				#}
#49924				
				print MATCHPROC "Updated UII properties to the matched record.\n";
				$pLog->PrintInfo( "$func: Updated UII properties to the matched record.") if $verbose == 1;	
				if($sematchhashflag==0)
				{
					$UniqueMatchHash{$currentHost}{$entry} = $currentLine;
					# if($btModel eq "3845"){
						#&probeDestUpdate($self,$currentHost,$entry,$myData);
					# }
					
					if ( ${ $UIIRecord10Hash{$myData} }[$UIIRecordHash{BT_SUPPLIER_ID}]eq"CIS" && ${ $UIIRecord10Hash{$myData} }[$UIIRecordHash{BT_NE_TYPE}]eq "VIRTUAL SW" && (${ $UIIRecord10Hash{$mydata} }[$UIIRecordHash{BT_NE_USAGE}] =~ /^BEA$|^BEA-VS|^HT BEA-VS$/) && ($$arrSEData[$UIIRecordHash{BT_VLAN_ID}] !~ /^\s*$/))
					{
						my $currBT_TOTAL_WBC_ASSURED_RATE_BW = $$arrSEData[$UIIRecordHash{BT_TOTAL_WBC_ASSURED_RATE_BW}];
						my $currBT_TOTAL_WBC_BEST_EFFORT_BW = $$arrSEData[$UIIRecordHash{BT_TOTAL_WBC_BEST_EFFORT_BW}];
						my $currBT_BBASVLAN_RT_BANDWIDTH = $$arrSEData[$UIIRecordHash{BT_BBASVLAN_RT_BANDWIDTH}];
						my $currAPID = $$arrSEData[$UIIRecordHash{BT_BBASVLAN_RT_POLICY_ID}];
						&updateBBASVLANBW($self,$myData,$currentHost,$entry,$currBT_TOTAL_WBC_ASSURED_RATE_BW,$currBT_TOTAL_WBC_BEST_EFFORT_BW,$currBT_BBASVLAN_RT_BANDWIDTH,$currAPID,\%UniqueSEInvMatchHash,\%subelementSplitHash) if($currAPID !~ /^\s*$/);
						print MATCHPROC "Finished Bandwidth update on BEA COS subelements\n";
						$pLog->PrintInfo( "$func: Finished Bandwidth update on BEA COS subelements") if $verbose == 1;
					}
					if ( $$arrSEData[$UIIRecordHash{BT_SS_ID}] !~ /^\s*$/ ){
						my $currSSID = $$arrSEData[$UIIRecordHash{BT_SS_ID}];
						if ($btSupplier eq "CIS"){
#49924 - Updated the argument from UniqueMatchHash to UniqueSEInvMatchHash							
							UpdateSSID($self,$myData,$selines,$currentHost,$entry,$currSSID,"Cisco_CBQoS",\%UniqueSEInvMatchHash);
#49924
							print MATCHPROC "Finished SSID update on subelement.dat\n";
							$pLog->PrintInfo( "$func: Finished SSID update on subelement.dat") if $verbose == 1;
						}
						elsif ($btSupplier eq "LUC" || $btSupplier eq "JUN" || $btSupplier eq "SIE")
						{
							UpdateSSID($self,$myData,$selines,$currentHost,$entry,$currSSID,"Juniper_",\%UniqueMatchHash);
							print MATCHPROC "Finished SSID update on subelement.dat\n";
							$pLog->PrintInfo( "$func: Finished SSID update on subelement.dat") if $verbose == 1;
						}						
					}
					if ( $$arrSEData[$UIIRecordHash{BT_PORT_MPLS_TYPE}] !~ /^\s*$/ ){
						my $currMPLSType = $$arrSEData[$UIIRecordHash{BT_PORT_MPLS_TYPE}];
						if ($btSupplier eq "CIS"){
						#	UpdateMPLSType($self,$myData,$currentHost,$entry,$currMPLSType,"Cisco_CBQoS",\%UniqueMatchHash);
UpdateMPLSType($self,$myData,$currentHost,$entry,$currMPLSType,"Cisco_CBQoS",\%UniqueSEInvMatchHash);						
							print MATCHPROC "Finished MPLS update on subelement.dat\n";
							$pLog->PrintInfo( "$func: Finished MPLS update on subelement.dat") if $verbose == 1;
						}
						elsif ($btSupplier eq "LUC" || $btSupplier eq "JUN" || $btSupplier eq "SIE")
						{
							UpdateMPLSType($self,$myData,$currentHost,$entry,$currMPLSType,"Juniper_",\%UniqueMatchHash);
							print MATCHPROC "Finished MPLS update on subelement.dat\n";
							$pLog->PrintInfo( "$func: Finished MPLS update on subelement.dat") if $verbose == 1;
						}
					}
				}
				elsif($sematchhashflag==1)
				{
					$UniqueSEInvMatchHash{$currentHost}{$entry} = $currentLine;
					if ( $$arrSEData[$UIIRecordHash{BT_SS_ID}] !~ /^\s*$/ ){
						my $currSSID = $$arrSEData[$UIIRecordHash{BT_SS_ID}];
						if ($btSupplier eq "CIS"){
							UpdateSSID($self,$myData,$selines,$currentHost,$entry,$currSSID,"Cisco_CBQoS",\%UniqueSEInvMatchHash);
							print MATCHPROC "Finished SSID update on subelement_invariant.dat\n";
							$pLog->PrintInfo( "$func: Finished SSID update on subelement_invariant.dat") if $verbose == 1;
						}
						elsif ($btSupplier eq "LUC" || $btSupplier eq "JUN" || $btSupplier eq "SIE")
						{
							UpdateSSID($self,$myData,$selines,$currentHost,$entry,$currSSID,"Juniper_",\%UniqueSEInvMatchHash);
							print MATCHPROC "Finished SSID update on subelement_invariant.dat\n";
							$pLog->PrintInfo( "$func: Finished SSID update on subelement_invariant.dat") if $verbose == 1;
						}
					}
					if ( $$arrSEData[$UIIRecordHash{BT_PORT_MPLS_TYPE}] !~ /^\s*$/ ){
						my $currMPLSType = $$arrSEData[$UIIRecordHash{BT_PORT_MPLS_TYPE}];
						if ($btSupplier eq "CIS"){
							UpdateMPLSType($self,$myData,$currentHost,$entry,$currMPLSType,"Cisco_CBQoS",\%UniqueSEInvMatchHash);
							print MATCHPROC "Finished MPLS update on subelement_invariant.dat\n";
							$pLog->PrintInfo( "$func: Finished MPLS update on subelement_invariant.dat") if $verbose == 1;
						}
						elsif ($btSupplier eq "LUC" || $btSupplier eq "JUN" || $btSupplier eq "SIE")
						{
							UpdateMPLSType($self,$myData,$currentHost,$entry,$currMPLSType,"Juniper_",\%UniqueSEInvMatchHash);
							print MATCHPROC "Finished MPLS update on subelement_invariant.dat\n";
							$pLog->PrintInfo( "$func: Finished MPLS update on subelement_invariant.dat") if $verbose == 1;
						}
					}
				}
			}
			else {	
				print MATCHPROC "Current UII line is not matched.Adding to InventoryResidueHash\n";
				$pLog->PrintInfo( "$func: Current UII line is not matched.Adding to InventoryResidueHash") if $verbose == 1;
				$InventoryResidueHash{$mydata}{$selines} = $arrSEData;
				# RelAQ 21CNCE-70998 : Store the test expression of matching failed interfaces
				$portdownResidueHash{$mydata}{$selines} = $testexpression;
			}
		}
		else{
			print MATCHPROC "Current UII line is not matched.Adding to InventoryResidueHash\n";
			$pLog->PrintInfo( "$func: Current UII line is not matched.Adding to InventoryResidueHash") if $verbose == 1;
			$InventoryResidueHash{$mydata}{$selines} = $arrSEData;
		}
	}
	#undef %LagMPLSUpdateHash;
	undef %LagInfoHash;
 }
#------------------------------------End of processGenericDiscUpdate--------------------------------------------#
#-------------------------------------------------------------------------------------------------
# AlcatelPreSyncSEMatching
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -------------------
# Description  : Performs the matching process for ALCATEL devices.
# Input        : current UII 20I record line,family of device,BT_MATCH_1,current UII line count
# Return       : returns matched subelement name and which file indicator (se.dat or se_inv.dat) 
#				 incase of match else FAIL.
#Author        : Vivek Venudasan
#Date          : 11th May 2010
#-------------------------------------------------------------------------------------------------
sub AlcatelPreSyncSEMatching
{
    my ($self, $arrSEData, $classID,$ProvisoMap,$count,$testExp)=@_;
    my $pLog=$self->{PLOG};
	my $verbose = $self->{LOGFILEVERBOSE};
    my $rtnCode="FAIL";
    my $func="AlcatelPreSyncSEMatching";
    my $currentDevice="";
    my @matchList;
    my $currentHost="";
    my $mysnmpprop=$self->{"SNMPSWITCH"};
    $currentDevice=$$arrSEData[$UIIRecordHash{$self->{IPADDPROP}}];
    $currentHost=$$arrSEData[$UIIRecordHash{$self->{HOSTNAMEPROP}}];
	my $currNEID = $$arrSEData[$UIIRecordHash{BT_NE_ID}];
	my $PortID= $$arrSEData[$UIIRecordHash{BT_PORT_ID}];
	my $suppPortID = $$arrSEData[$UIIRecordHash{BT_SUPPLIER_PORT_ID}];
	my $VLANID = $$arrSEData[$UIIRecordHash{BT_VLAN_ID}];
	my $CVLANID = $$arrSEData[$UIIRecordHash{BT_CVLAN_ID}];
	my $serviceID = $$arrSEData[$UIIRecordHash{BT_SERVICE_ID}]; #56947
    my $myData = $currentHost."|_|".$currentDevice;
	my $flag = "";
	my $currentmatchcount = 0;
	my $matchedSEnames;
	my $testexpression = " ";
	my $matchCallCnt = 1;
	my $UIIdata = $myData.'|_|'.$currNEID.'|_|'.$PortID.'|_|'.$suppPortID.'|_|'.$VLANID.'|_|'.$CVLANID.'|_|'.$serviceID.'|_|'; #56947
	#Read the feedmap entries from config file into an array
	if ($self->{FEEDMAP} ne "NULL")
	{
		@matchList=();
		# Create the default matchkey array  
		push(@matchList,$self->{FEEDMAP});		
		if ($self->{FEEDALT}ne"NULL")
		{
			# Add all other matching keys
			my (@altMatch)=split($self->{HEADERSEP},$self->{FEEDALT});
			chomp (@altMatch);
			push (@matchList,@altMatch);
		}
		## SE Matching for ALN 7750 Edge Rt NE TYPE devices using only BT_LAG_ID 
		##-----------------------------------------------------------------------
		if( ${$UIIRecord10Hash{$myData}}[$UIIRecordHash{BT_SUPPLIER_ID}]eq"ALN" && $$arrSEData[$UIIRecordHash{BT_NE_TYPE}]eq"Edge Rt" && $$arrSEData[$UIIRecordHash{$matchList[2]}] !~ /^$/ && $$arrSEData[$UIIRecordHash{$matchList[1]}] =~ /^$/)
		{
			# Creating the TestExpression for ALN 7750 using BT_LAG_ID 
			# 21CNCE-66590: my $lagNumber = $$arrSEData[$UIIRecordHash{$matchList[2]}];
			# 21CNCE-66590: $testexpression = "lag-$lagNumber";	
			$testexpression = $$arrSEData[$UIIRecordHash{$matchList[0]}]; # 21CNCE-66590: Matching ports entries from UII Feed with entries from network			
			$flag = "IETF";	
		#	print("In the if for IETF ----divay\n");			
		}
		# For Alcatel 7750 VLANs for both port based SAP and LAG based SAP
		elsif( ${$UIIRecord10Hash{$myData}}[$UIIRecordHash{BT_SUPPLIER_ID}]eq"ALN" && $$arrSEData[$UIIRecordHash{BT_NE_TYPE}]eq"Edge Rt" && $$arrSEData[$UIIRecordHash{$matchList[1]}] !~ /^$/)
		{     
			if($classID !~ /7750_QoS/)
			{
		#		print("in elseif for 7750_Shaper or 7750_SAP ----divay \n ");
				# get vlan number from vlan ID
			#	$pLog->PrintInfo("in elseif for 7750_Shaper or 7750_SAP ----divay \n");
				my $vlanID = $$arrSEData[$UIIRecordHash{$matchList[1]}];
				my @vlanArr = split("::", $vlanID);
				my $vlanNum = $vlanArr[scalar(@vlanArr) - 1];			
				if($$arrSEData[$UIIRecordHash{$matchList[2]}] !~ /^$/ && $$arrSEData[$UIIRecordHash{MSE_TERM_MARKER}]!~/Yes/i) {   #56947
					## SE Matching for ALN 7750 Edge Rt devices using BT_LAG_ID + BT_VLAN_ID
					my $lagNumber = $$arrSEData[$UIIRecordHash{$matchList[2]}];
					$testexpression = "lag-$lagNumber"."."."$vlanNum";	
			#		print("test expression formed in else with lagid is : $testexpression");
				}
				else
				{   
					$testexpression = $$arrSEData[$UIIRecordHash{$matchList[0]}].".".$vlanNum;
					$pLog->PrintInfo("test expression formed is $testexpression") if $verbose == 1;
			#		print("test expression formed in else without lagid is : $testexpression");
					if($$arrSEData[$UIIRecordHash{MSE_TERM_MARKER}] =~ /Yes/i && ($$arrSEData[$UIIRecordHash{$matchList[0]}] =~ /^$/) || $$arrSEData[$UIIRecordHash{$matchList[1]}] =~ /^$/)
				{
					      $pLog->PrintWarning( "$func: Information incomplete as Either BT_SUPPLIER_PORT_ID or BT_VLAN_ID is null or BT_NE_USAGE is not having Multi Service Edge as its value");  
				}
				}#56947
				# Get CVLAN_ID if present, for matching
				# It will be in the format: /ethsvid=112/ethcvid=55
				
				my $cvlanID = "";
				
				if($CVLANID !~ /^$/) {
					my @scvlanArr = split("/",$CVLANID);
					if ($scvlanArr[2] !~ /^$/) {
							my @cvlanArr = split("=",$scvlanArr[2]);
							if (($cvlanArr[1] !~ /default/i) && ($cvlanArr[1] >= 0))
							{
								$cvlanID = $cvlanArr[1];
							}
						}
				}	
				# Add CVLAN_ID to the test expression
				if($cvlanID !~ /^$/){
					$testexpression .= ".".$cvlanID;
					}
				
			}
				
				else{
				$testexpression = $alnSAPMatchValue;
			}
		        
				$flag = "SAP";
				
				
			}			
		 
		elsif (${$UIIRecord10Hash{$myData}}[$UIIRecordHash{BT_SUPPLIER_ID}]eq"ALN" && $$arrSEData[$UIIRecordHash{BT_NE_TYPE}]eq"Edge Rt")
		{	
			$testexpression = $$arrSEData[$UIIRecordHash{$matchList[0]}];
		} 
		print MATCHPROC "Current Element: $currentHost\n" if $verbose == 1; 
		print MATCHPROC "Current UII Line: @$arrSEData\n" if $verbose == 1; 
		print MATCHPROC "Current Testexpression: $testexpression\n" if $verbose == 1;
		print MATCHPROC "Current UII Data: $UIIdata$testexpression\n" if $verbose != 1; 
		$pLog->PrintInfo( "$func: Current UII Data - $UIIdata$testexpression") if $verbose == 1; 
		$$testExp = $testexpression;
		if( $testexpression && $testexpression !~ /^(\s+)$/ )
		{   #$pLog->PrintInfo("Test expression is not null");
			if($classID =~ /7750_QoS/i)#56947
			{
				#Aug 25 CR: Ignoring Alcatel MSC and IEA sub-elements of family 7750_QoS : Rajani K
				if( $$arrSEData[$UIIRecordHash{BT_NE_USAGE}] eq "Multi Service Core" || $$arrSEData[$UIIRecordHash{BT_NE_USAGE}] eq "Infra Edge Agg")
				{
					#$pLog->PrintInfo("$func: Following '7750_QoS' subelement of usage $UIIRecordHash{BT_NE_USAGE} is ignored from matching:@$arrSEData.\n") ;			
					$pLog->PrintDebug("$func: Following '7750_QoS' subelement of usage $$arrSEData[$UIIRecordHash{BT_NE_USAGE}] is ignored from matching:@$arrSEData.\n") ;
					return "FAIL";
				}
				my $rtnVal;
				#loop through subelement.dat to find the match
				($currentmatchcount,$matchedSEnames) = findMatch($self,\%subelementSplitHash,\%subelementHash,\%UniqueMatchHash,$flag,$ProvisoMap,$currentHost,$testexpression,$classID,$matchCallCnt);
				if($currentmatchcount > 0)
				{						
					print MATCHPROC "[Match found]: Following '7750_QoS' subelements matched succesfully with UIIData:@$arrSEData.\n" ;						
					$pLog->PrintInfo( "$func: [Match found] - Following '7750_QoS' subelements matched succesfully with UIIData:@$arrSEData.") if $verbose == 1;	
					foreach my $entry (@{$matchedSEnames}){
						$pLog->PrintDebug( "$entry") ;
						print MATCHPROC "$entry\n" ;
						delete $subelementHash{$currentHost}{$entry};
						delete $subelementSplitHash{$currentHost}{$entry};
					}
					return \@{$matchedSEnames};
				}
				else
				{
					# RelAQ 21CNCE-70998 : Store the test expression of matching failed interfaces
					$portdownResidueHash{$myData}{$count} = $testexpression;
					return "FAIL";
				}
			}
			else
			{
				my $rtnVal;
				#loop through subelement.dat to find the match
				($currentmatchcount,$matchedSEnames) = findMatch($self,\%subelementSplitHash,\%subelementHash,\%UniqueMatchHash,$flag,$ProvisoMap,$currentHost,$testexpression,$classID,$matchCallCnt);
				if ((scalar keys %subeltInvariantHash) > 0)
				{
					$pLog->PrintInfo( "$func: Found data in subelement_invariant.dat.However it is not considered for matching!");
				}
				if ($currentmatchcount==1)
				{
					$rtnVal = ${$matchedSEnames}[0];
					$alnSAPMatchValue = $subelementSplitHash{$currentHost}{$rtnVal}{$ProvisoMap} if($classID =~ /7750_SAP/);
					delete $subelementHash{$currentHost}{$rtnVal};
					delete $subelementSplitHash{$currentHost}{$rtnVal};					 
					print MATCHPROC "Subelement,$rtnVal,matched succesfully with UIIData:@$arrSEData.\n" if $verbose == 1;						
					$pLog->PrintInfo( "$func: Subelement,$rtnVal,matched succesfully with UIIData:@$arrSEData.") if $verbose == 1;			
					print MATCHPROC "[Match found]: Matches with subelement $rtnVal" if $verbose != 1;						
					$pLog->PrintInfo( "$func: [Match found] - Matches with subelement $rtnVal") if $verbose == 1;
               		if($$arrSEData[$UIIRecordHash{MSE_TERM_MARKER}] !~ /Yes/i && $classID =~ /7750_Shaper/i) #56947
					{
					  $pLog->PrintInfo( "$func: Subelement,$rtnVal,matched succesfully with UIIData:@$arrSEData. but rejecting the record as the uii feed is not having MSE_TERM_MARKER property as yes for this shaper record") if $verbose == 1;
					  return "FAIL";
					}
					else{	
				  return \@{$matchedSEnames};
				  }  #56947
				}
				else
				{								
					#RelAQ 21CNCE-70998 : Store the test expression of matching failed interfaces
					 $portdownResidueHash{$myData}{$count} = $testexpression;
					return "FAIL";
				}
			}
		}
		#no testexpression.Match Fail.
		return "FAIL";
    }
 }
#------------------------------------End of AlcatelPreSyncSEMatching--------------------------------------------#
#-------------------------------------------------------------------------------------------------
# AlcatelIETFPreSyncSEMatching
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -------------------
# Description  : Performs the lag matching process for ALCATEL devices olny for IETF
# Input        : current UII 20I record line,family of device,BT_MATCH_1,current UII line count
# Return       : returns matched subelement name and which file indicator (se.dat or se_inv.dat) 
#				 incase of match else FAIL.
#Author        : Edwin Liong
#Date          : 15th August 2014
#-------------------------------------------------------------------------------------------------
sub AlcatelIETFPreSyncSEMatching
{
    my ($self, $arrSEData, $classID,$ProvisoMap,$count,$testExp)=@_;
    my $pLog=$self->{PLOG};
	my $verbose = $self->{LOGFILEVERBOSE};
    my $rtnCode="FAIL";
    my $func="AlcatelIETFPreSyncSEMatching";
    my $currentDevice="";
    my @matchList;
    my $currentHost="";
    my $mysnmpprop=$self->{"SNMPSWITCH"};
    $currentDevice=$$arrSEData[$UIIRecordHash{$self->{IPADDPROP}}];
    $currentHost=$$arrSEData[$UIIRecordHash{$self->{HOSTNAMEPROP}}];
	my $currNEID = $$arrSEData[$UIIRecordHash{BT_NE_ID}];
	my $PortID= $$arrSEData[$UIIRecordHash{BT_PORT_ID}];
	my $suppPortID = $$arrSEData[$UIIRecordHash{BT_SUPPLIER_PORT_ID}];
	my $VLANID = $$arrSEData[$UIIRecordHash{BT_VLAN_ID}];
	my $CVLANID = $$arrSEData[$UIIRecordHash{BT_CVLAN_ID}];
	my $serviceID = $$arrSEData[$UIIRecordHash{BT_SERVICE_ID}];
    my $myData = $currentHost."|_|".$currentDevice;
	my $currentmatchcount = 0;
	my $matchedSEnames;
	my $testexpression = " ";
	my $matchCallCnt = 1;
	my $UIIdata = $myData.'|_|'.$currNEID.'|_|'.$PortID.'|_|'.$suppPortID.'|_|'.$VLANID.'|_|'.$CVLANID.'|_|'.$serviceID.'|_|';
	
	#Read the feedmap entries from config file into an array
	if ($self->{FEEDMAP} ne "NULL")
	{
		@matchList=();
		# Create the default matchkey array  
		push(@matchList,$self->{FEEDMAP});		
		if ($self->{FEEDALT}ne"NULL")
		{
			# Add all other matching keys
			my (@altMatch)=split($self->{HEADERSEP},$self->{FEEDALT});
			chomp (@altMatch);
			push (@matchList,@altMatch);
		}
		
		## SE Matching for ALN 7750 Edge Rt NE TYPE devices using only BT_LAG_ID 
		##-----------------------------------------------------------------------
		
		if( ${$UIIRecord10Hash{$myData}}[$UIIRecordHash{BT_SUPPLIER_ID}]eq"ALN" && 
			$$arrSEData[$UIIRecordHash{BT_NE_TYPE}]eq"Edge Rt" && 
			$$arrSEData[$UIIRecordHash{$matchList[2]}] !~ /^$/ && 
			$$arrSEData[$UIIRecordHash{$matchList[1]}] =~ /^$/)
		{
			my $lagNumber = $$arrSEData[$UIIRecordHash{$matchList[2]}];
			$testexpression = "lag-$lagNumber";	
		} else {
			return "FAIL";
		}
		
		print MATCHPROC "Current Element: $currentHost\n" if $verbose == 1;
		print MATCHPROC "Current UII Line: @$arrSEData\n" if $verbose == 1;
		print MATCHPROC "Current Testexpression: $testexpression\n" if $verbose == 1;
		print MATCHPROC "Current UII Data: $UIIdata$testexpression\n" if $verbose != 1;
		$pLog->PrintInfo( "$func: Current UII Data - $UIIdata$testexpression") if $verbose != 1;
		$$testExp = $testexpression;
		my $rtnVal;
		
		#loop through subelement.dat to find the match
		($currentmatchcount,$matchedSEnames) = findMatch($self,\%subelementSplitHash,\%subelementHash,\%UniqueMatchHash,"IETF",$ProvisoMap,$currentHost,$testexpression,$classID,$matchCallCnt);
		
		if ((scalar keys %subeltInvariantHash) > 0)
		{
			$pLog->PrintInfo( "$func: Found data in subelement_invariant.dat.However it is not considered for matching!");
		}
		
		if ($currentmatchcount==1) {
			$rtnVal = ${$matchedSEnames}[0];
			delete $subelementHash{$currentHost}{$rtnVal};
			delete $subelementSplitHash{$currentHost}{$rtnVal};					 
			print MATCHPROC "Subelement,$rtnVal,matched succesfully with UIIData:@$arrSEData.\n" if $verbose == 1;						
			$pLog->PrintInfo( "$func: Subelement,$rtnVal,matched succesfully with UIIData:@$arrSEData.") if $verbose == 1;			
			print MATCHPROC "[Match found]: Matches with subelement $rtnVal" if $verbose != 1;						
			$pLog->PrintInfo( "$func: [Match found] - Matches with subelement $rtnVal") if $verbose != 1;
			
			return \@{$matchedSEnames};
		}
		
		return "FAIL";
    }
 }
#------------------------------------End of AlcatelIETFPreSyncSEMatching--------------------------------------------#
#--------------------------------------------------------------------------------------------
# findMatch
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
# Description  : Loop through subelement.dat or subelement_invariant.dat hash to 
#				 find the matching record.
# Input        : references to all the discoveryfile hashes,flag to indicate IETF or SAP,
#				 BT_MATCH_1,currenthost,testexpression,family and a flag indicating whether
#                a partial match or exact match.
# Return       : number of matches found and matched senames array reference
#Author        : Vivek Venudasan
#Date          : 11th May 2010
#---------------------------------------------------------------------------------------------
sub findMatch
{
	my ($self,$MatchValHash,$CompleteFileHash,$UniqueMatchesHash,$flag,$ProvisoMap,$currentHost,$testexpression,$classID)=@_;
	my $seIETFProp = "AP_ifType";
	my $seIETFPropVal = "ieee8023adLag";
	my $seAlcatelIDProp = "AlcatelID";
	my $verbose = $self->{LOGFILEVERBOSE};
	my $matchCount = 0;
	my @matchedSENames;
	my $matchExpression;
	$matchExpression = "^$testexpression".'$' ;
	foreach my $sedatkey (keys %{${$CompleteFileHash}{$currentHost}})
	{
		#for IETF devices
		if (defined ($flag) && $flag eq "IETF"){
			#21CNCE-66590: if (($$MatchValHash{$currentHost}{$sedatkey}{$ProvisoMap} =~ /$matchExpression/) && ($$MatchValHash{$currentHost}{$sedatkey}{$seIETFProp} eq $seIETFPropVal) && ($$MatchValHash{$currentHost}{$sedatkey}{"STATE"} eq "on" )){
			if (($$MatchValHash{$currentHost}{$sedatkey}{$ProvisoMap} =~ /$matchExpression/) && ($$MatchValHash{$currentHost}{$sedatkey}{"STATE"} eq "on" )){
					print MATCHPROC "Matches with: $sedatkey\n" if $verbose == 1;						
					$matchedSENames[$matchCount] = $sedatkey;
					$matchCount+=1;
					print MATCHPROC "Current Matchcount: $matchCount\n" if $verbose == 1;
					$$CompleteFileHash {$currentHost}{$sedatkey} =~ s#(\s+)$##;
					$$UniqueMatchesHash{$currentHost}{$sedatkey}=$$CompleteFileHash {$currentHost}{$sedatkey};
			}
		}
		#for VLANS 
		elsif (defined ($flag) && $flag eq "SAP"){
#		print("value of BT_MATCH_1 is $$MatchValHash{$currentHost}{$sedatkey}{$ProvisoMap} and the value for the test expression is $testexpression");
			if (($$MatchValHash{$currentHost}{$sedatkey}{$ProvisoMap} =~ /$matchExpression/) && ($$MatchValHash{$currentHost}{$sedatkey}{$seAlcatelIDProp} eq $classID) && ($$MatchValHash{$currentHost}{$sedatkey}{"STATE"} eq "on" )){
			#if($$MatchValHash{$currentHost}{$sedatkey}{$seAlcatelIDProp} =~ /7750_Shaper/i)
			#{
			#print("It is a $$MatchValHash{$currentHost}{$sedatkey}{$seAlcatelIDProp} VLAN record");
			#}
					print MATCHPROC "Matches with: $sedatkey\n" if $verbose == 1;
					$matchedSENames[$matchCount] = $sedatkey;
					$matchCount+=1;
					print MATCHPROC "Current Matchcount: $matchCount\n" if $verbose == 1;
					$$CompleteFileHash {$currentHost}{$sedatkey} =~ s#(\s+)$##;
					$$UniqueMatchesHash{$currentHost}{$sedatkey}=$$CompleteFileHash {$currentHost}{$sedatkey};
			}
		}
		#for others
		else{
			if (($$MatchValHash{$currentHost}{$sedatkey}{$ProvisoMap} =~ /$matchExpression/) && ($$MatchValHash{$currentHost}{$sedatkey}{"STATE"} eq "on" )){
		#	print("value of BT_MATCH_1 is $$MatchValHash{$currentHost}{$sedatkey}{$ProvisoMap} and the value for the test expression is $testexpression");
					print MATCHPROC "Matches with: $sedatkey\n" if $verbose == 1;
					$matchedSENames[$matchCount] = $sedatkey;
					$matchCount+=1;
					print MATCHPROC "Current Matchcount:$matchCount\n" if $verbose == 1;
					$$CompleteFileHash {$currentHost}{$sedatkey} =~ s#(\s+)$##;
					$$UniqueMatchesHash{$currentHost}{$sedatkey}=$$CompleteFileHash {$currentHost}{$sedatkey};		
			}
		}
		if (($matchCount == 1) && ($classID !~ /7750_QoS/)){
			return $matchCount,\@matchedSENames;
		}
	}
	return $matchCount,\@matchedSENames;	
}
#------------------------------------------End of findMatch-------------------------------------------------#
#===========================================================================================================
# Name 				: preSyncSEFERMatching
# Author 			: Amarnath Peddi
# Description 		: This method finds a match in the sub-element.dat 
# Input 			: Path of the Profile Directory
# Output 			: Returns SUCCESS or FAIL
# Calling Routines  : This sub-routine calls no sub-routines
#============================================================================================================
sub preSyncSEFERMatching
{
    my ($self, $arrSEData, $classID,$poidHashRef)=@_;
	my $entry;
    my $pLog=$self->{PLOG};
	my $verbose = $self->{LOGFILEVERBOSE};
    my $rtnCode="FAIL";
    my $func="PreSyncSEFERMatching";
    my $currentDevice="";
    my (@matchList);
    my $testexpression;
    my $currentHost="";
    my $position=1;
    my $mysnmpprop=$self->{"SNMPSWITCH"};
    $currentDevice=$$arrSEData[$UIIRecordHash{$self->{IPADDPROP}}];
    $currentHost=$$arrSEData[$UIIRecordHash{$self->{HOSTNAMEPROP}}];
	my $currNEID = $$arrSEData[$UIIRecordHash{BT_NE_ID}];
	my $PortID= $$arrSEData[$UIIRecordHash{BT_PORT_ID}];
	my $suppPortID = $$arrSEData[$UIIRecordHash{BT_SUPPLIER_PORT_ID}];
	my $VLANID = $$arrSEData[$UIIRecordHash{BT_VLAN_ID}];
    my $myData = $currentHost."|_|".$currentDevice;
	my $UIIdata = $myData.'|_|'.$currNEID.'|_|'.$PortID.'|_|'.$suppPortID.'|_|'.$VLANID.'|_|';
	my $flag = "";	
	if ($self->{FEEDMAP} ne "NULL")
	{
		@matchList=();
		# Create the default (BT_SUPPLIER_PORT_ID) matchkey array  
		push(@matchList,$self->{FEEDMAP});		
		if ($self->{FEEDALT}ne"NULL")
		{
			# Add all matching keys
			my (@altMatch)=split($self->{HEADERSEP},$self->{FEEDALT});
			chomp (@altMatch);
			push (@matchList,@altMatch);
		}
		#=======SE Matching for Cisco 6509 FER Edge Rt using Police ID (BT_BBASVLAN_RT_POLICY_ID)
		if ( ${$UIIRecord10Hash{$myData}}[$UIIRecordHash{BT_MODEL}] eq "CAT6500" && $$arrSEData[$UIIRecordHash{BT_NE_TYPE}] eq "VIRTUAL SW" && ${$UIIRecord10Hash{$myData}}[$UIIRecordHash{BT_NE_USAGE}] =~ /FER|FER-VS/ && $$arrSEData[$UIIRecordHash{$matchList[4]}] !~ /^$/ )
		{
			# SE Matching Test Expression is value of only BT_BBASVLAN_RT_POLICY_ID (taken from 'this' line of SE)
			# Here dbIndexList contain value like 200002343|_|CP-POLICER-POID22224444.WBMC-WBC-RT, but BT_BBASVLAN_RT_POLICY_ID 
			# field of UII feed will be only POID22224444. Additional value of ClassType (like WMBC-WBC-RT) are being added from 
			# configuration on fly to make testexpression and final data from DB (modified matchinfo file data) in same format
			$testexpression = "CP-POLICER-".$$arrSEData[$UIIRecordHash{$matchList[4]}].".".$classID;
		}else
		{
			print MATCHPROC "No testexpression is generated as POID (BT_BBASVLAN_RT_POLICY_ID) is unavailable!\n";
		}			
		print MATCHPROC "Current Element: $currentHost\n" if $verbose == 1;
		print MATCHPROC "Current UII Line: @$arrSEData\n" if $verbose == 1;
		print MATCHPROC "Current Testexpression: $testexpression\n" if $verbose == 1;	
		print MATCHPROC "Current UII Data: $UIIdata$testexpression\n" if $verbose != 1; 
		$pLog->PrintInfo( "$func: Current UII Data - $UIIdata$testexpression") if $verbose == 1; 			
		if( $testexpression && $testexpression =~ /\w+/ )
		{	
			$entry= ferPOIDMatching($self,$testexpression,$arrSEData,$poidHashRef);
			return $entry;
		}			    
	}
 }
#------------------------------------------End of preSyncSEFERMatching-----------------------------------------# 
#=====================================================================================================
# Name 				: ferPOIDMatching
# Author 			: Vivek Venudasan
# Description 		: 
# Input 			: 
# Output 			: 
#=====================================================================================================
sub ferPOIDMatching()
{
	my ($self,$testexpression,$arrSEData,$poidHashRef)=@_;
	my $currentmatchcount = 0;
	my $func="ferPOIDMatching";
	my $verbose = $self->{LOGFILEVERBOSE};
	my @matchedSENames=();;
	my @matchedinvariantSENames=();
	my $pLog=$self->{PLOG};
	my $matchedEntry;
	my $matchString;
	my $currentHost="";
	$currentHost=$$arrSEData[$UIIRecordHash{$self->{HOSTNAMEPROP}}];
	$matchString = "^$testexpression".'$' ;
	foreach my $sedatkey (keys %{$subelementSplitHash{$currentHost}})
	{	
		next unless(defined $subelementSplitHash{$currentHost}{$sedatkey}{"BT_MATCH_1"});
		if (exists $$poidHashRef{$testexpression}){
			if (($subelementSplitHash{$currentHost}{$sedatkey}{"BT_MATCH_1"} =~ /$matchString/) && ($subelementSplitHash{$currentHost}{$sedatkey}{"STATE"} eq "on") && ($subelementSplitHash{$currentHost}{$sedatkey}{"INVARIANT"} eq "$$poidHashRef{$testexpression}"))
			{
				$matchedSENames[$currentmatchcount] = $sedatkey;
				$currentmatchcount++;
				$UniqueMatchHash{$currentHost}{$sedatkey}=$subelementHash {$currentHost}{$sedatkey};
			}
		}
		else
		{
			if (($subelementSplitHash{$currentHost}{$sedatkey}{"BT_MATCH_1"} =~ /$matchString/) && ($subelementSplitHash{$currentHost}{$sedatkey}{"STATE"} eq "on" ))
			{
				$matchedSENames[$currentmatchcount] = $sedatkey;
				$currentmatchcount++;
				$UniqueMatchHash{$currentHost}{$sedatkey}=$subelementHash {$currentHost}{$sedatkey};
			}
		}
		if ($currentmatchcount == 1){
			$pLog->PrintInfo( "$func: Subelement,$sedatkey,matched succesfully with UIIData: @$arrSEData.") if $verbose == 1;		
			print MATCHPROC "Subelement,$sedatkey,matched succesfully with UIIData: @$arrSEData.\n" if $verbose == 1;			
			print MATCHPROC "[Match found]: Matches with subelement-$sedatkey\n" if $verbose != 1;						
			$pLog->PrintInfo( "$func: [Match found] - Matches with subelement $sedatkey.") if $verbose != 1;
			# delete $subelementHash{$currentHost}{$sedatkey};
			# delete $subelementSplitHash{$currentHost}{$sedatkey};
			return $sedatkey;
		}
	}
		
	if ($currentmatchcount == 0)
	{
		if ((scalar keys %seInvMatchValueHash) > 0)
		{
			foreach my $sedatkey (keys %{$seInvMatchValueHash{$currentHost}})
			{	
				next unless(defined $seInvMatchValueHash{$currentHost}{$sedatkey}{"BT_MATCH_1"});
				if (exists $$poidHashRef{$testexpression})
				{						
					if (($seInvMatchValueHash{$currentHost}{$sedatkey}{"BT_MATCH_1"} =~ /$matchString/) && ($seInvMatchValueHash{$currentHost}{$sedatkey}{"STATE"} eq "on" ) && ($seInvMatchValueHash{$currentHost}{$sedatkey}{"INVARIANT"} eq $$poidHashRef{$testexpression}))
					{
						$matchedinvariantSENames[$currentmatchcount] = $sedatkey;
						$currentmatchcount++;
						$UniqueSEInvMatchHash{$currentHost}{$sedatkey}=$subeltInvariantHash {$currentHost}{$sedatkey};
					}
				}
				else{
					if (($seInvMatchValueHash{$currentHost}{$sedatkey}{"BT_MATCH_1"} =~ /$matchString/) && ($seInvMatchValueHash{$currentHost}{$sedatkey}{"STATE"} eq "on" ))
					{
						$matchedinvariantSENames[$currentmatchcount] = $sedatkey;
						$currentmatchcount++;
						$UniqueSEInvMatchHash{$currentHost}{$sedatkey}=$subeltInvariantHash{$currentHost}{$sedatkey};
					}
				}
				if ($currentmatchcount == 1)
				{
					$pLog->PrintInfo( "$func: Subelement,$sedatkey,matched succesfully with UIIData: @$arrSEData.") if $verbose == 1;		
					print MATCHPROC "Subelement,$sedatkey,matched succesfully with UIIData: @$arrSEData.\n" if $verbose == 1;			
					print MATCHPROC "[Match found]: Matches with subelement-$sedatkey\n" if $verbose != 1;						
					$pLog->PrintInfo( "$func: [Match found] - Matches with subelement $sedatkey.") if $verbose != 1;
					# delete $subeltInvariantHash{$currentHost}{$sedatkey};
					# delete $seInvMatchValueHash{$currentHost}{$sedatkey};
					return $sedatkey;
				}
			}				
			if ($currentmatchcount == 0) 
			{
				return "FAIL";
			}
		}
		return "FAIL";	
	}
}
#------------------------------------------End of ferPOIDMatching---------------------------------------------# 
#=====================================================================================================
# Name 				: findGenericMatch
# Author 			: Amarnath Peddi
# Description 		: This method finds a match in the sub-element.dat and sub-invariant.dat with the UII Record
# Input 			: Path of the Profile Directory
# Output 			: Returns SUCCESS or FAIL
# Calling Routines  : This sub-routine calls no sub-routines
#=====================================================================================================
sub findGenericMatch()
{
	my ($self,$testexpression,$arrSEData,$msiFlag)=@_;
	my $currentmatchcount = 0;
	my $func="findGenericMatch";
	my $verbose = $self->{LOGFILEVERBOSE};
	my @matchedSENames;
	my @matchedinvariantSENames;
	my $pLog=$self->{PLOG};
	my $matchedEntry;
    @matchedSENames=();
    @matchedinvariantSENames =();
	my $matchString;
	my $currentHost="";
	$currentHost=$$arrSEData[$UIIRecordHash{$self->{HOSTNAMEPROP}}];
	$matchString = "^$testexpression".'$' ;	
	foreach my $sedatkey (keys %{$subelementSplitHash{$currentHost}})
	{	
		next unless(defined $subelementSplitHash{$currentHost}{$sedatkey}{"BT_MATCH_1"});			
		if($msiFlag eq "MSI")
		{
			# 20140909 [YepChoon] CiscoVLAN Fixes : Added logic to exclude lag (InterfaceDescr=Port-channel<x>) 
			# and l2vlan (InterfaceDescr=unrouted VLAN <x>)
			my $ifDescr = $subelementSplitHash{$currentHost}{$sedatkey}{"InterfaceDescr"};
			if( $ifDescr =~ /^Port-channel/ || $ifDescr =~ /^unrouted VLAN/ )
			{
				#$pLog->PrintInfo( "$func: skip CAT6500 lag or l2vlan network inventory record for [$sedatkey]. | InterfaceDescr: $ifDescr") if $verbose == 1;
				next;
			}
			
			if (($subelementSplitHash{$currentHost}{$sedatkey}{"TrunkPort"} !~ /^(\s*)$/) && ($subelementSplitHash{$currentHost}{$sedatkey}{"STATE"} eq "on" ))
			{
				my ($vlan,$trunk)=split(":",$subelementSplitHash{$currentHost}{$sedatkey}{"TrunkPort"});
				my @trunkPort=split(",",$trunk);
				# $pLog->PrintInfo( "$func: BEA and MSI");
				foreach my $portId (@trunkPort)
				{
					my $completePortId = "";
					#if($portId =~/^TG(.+)/i)
					#{
					#	$completePortId = "TenGigabitEthernet$1";
					#}
					#elsif($portId =~/^G(.+)/i)
					#{
					#	$portId = $1;
					#	$pLog->PrintInfo( "$func: Not Ten Gig !!! 3rd condition");	
					#	if ($subelementSplitHash{$currentHost}{$sedatkey}{"BT_MATCH_1"} =~ /FortyGigabitEthernet/)
					#	{
					#	$pLog->PrintInfo( "$func: $subelementSplitHash{$currentHost}{$sedatkey}{BT_MATCH_1} !!! 4th condition");	
					#	$completePortId = "FortyGigabitEthernet$portId";
					#	}
					#	else
					#	{
					#	$pLog->PrintInfo( "$func: Simple Gigabit !!! 5th condition");	
					#	$completePortId = "GigabitEthernet$portId";
					#	}
					#}			
					#my @bt_Match_1_Values = split(/\d/,$subelementSplitHash{$currentHost}{$sedatkey}{BT_MATCH_1});
					my @bt_Match_1_Values = split(/\d/,$testexpression);
					$completePortId = $bt_Match_1_Values[0];
					$portId =~ /G(.+)/i;
					$completePortId = $completePortId.$1;
					#$pLog->PrintInfo( "$func: $completePortId | TestExpression: $matchString") if $verbose == 1;
					my $match1=$completePortId.".".$vlan;						
					if (( $match1 =~ /$matchString/))
					{	
						$pLog->PrintInfo( "$func: trunkport: $trunk | match1: $match1 | TestExpression: $matchString") if $verbose == 1;
						$matchedSENames[$currentmatchcount] = $sedatkey;
						$currentmatchcount++;
						$UniqueMatchHash{$currentHost}{$sedatkey}=$subelementHash{$currentHost}{$sedatkey};
						last;
					}						
				}					
			}			
		}
		else
		{	
			if (($subelementSplitHash{$currentHost}{$sedatkey}{"BT_MATCH_1"} =~ /$matchString/) && ($subelementSplitHash{$currentHost}{$sedatkey}{"STATE"} eq "on" ))
			{
				$matchedSENames[$currentmatchcount] = $sedatkey;
				$currentmatchcount++;
				$UniqueMatchHash{$currentHost}{$sedatkey}=$subelementHash {$currentHost}{$sedatkey};
			}
		}
		if ($currentmatchcount == 1)
		{
			$pLog->PrintInfo( "$func: Subelement,$sedatkey,matched succesfully with UIIData: @$arrSEData.") if $verbose == 1;		
			print MATCHPROC "Subelement,$sedatkey,matched succesfully with UIIData: @$arrSEData.\n" if $verbose == 1;			
			print MATCHPROC "[Match found]: Matches with subelement-$sedatkey\n" if $verbose != 1;						
			$pLog->PrintInfo( "$func: [Match found] - Matches with subelement $sedatkey.") if $verbose == 1;
			delete $subelementHash{$currentHost}{$sedatkey};
			delete $subelementSplitHash{$currentHost}{$sedatkey};		
			return $sedatkey;
		}
	}		
	if ($currentmatchcount == 0) 
	{
		if ((scalar keys %seInvMatchValueHash) > 0)
		{
			foreach my $sedatkey (keys %{$seInvMatchValueHash{$currentHost}})
			{	
				next unless(defined $seInvMatchValueHash{$currentHost}{$sedatkey}{"BT_MATCH_1"});
				if (($seInvMatchValueHash{$currentHost}{$sedatkey}{"BT_MATCH_1"} =~ /$matchString/) && ($seInvMatchValueHash{$currentHost}{$sedatkey}{"STATE"} eq "on" ))
				{
					$matchedinvariantSENames[$currentmatchcount] = $sedatkey;
					$currentmatchcount++;
					$UniqueSEInvMatchHash{$currentHost}{$sedatkey}=$subeltInvariantHash {$currentHost}{$sedatkey};
				}
				if ($currentmatchcount == 1){
					$pLog->PrintInfo( "$func: Subelement,$sedatkey,matched succesfully with UIIData: @$arrSEData.") if $verbose == 1;		
					print MATCHPROC "Subelement,$sedatkey,matched succesfully with UIIData: @$arrSEData.\n" if $verbose == 1;			
					print MATCHPROC "[Match found]: Matches with subelement-$sedatkey\n" if $verbose != 1;						
					$pLog->PrintInfo( "$func: [Match found] - Matches with subelement $sedatkey.") if $verbose == 1;
					delete $subeltInvariantHash{$currentHost}{$sedatkey};
					delete $seInvMatchValueHash{$currentHost}{$sedatkey};
					return $sedatkey;
				}
			}				
			if ($currentmatchcount == 0) 
			{
				return "FAIL";
			}
		}
		return "FAIL";
	}
}
#------------------------------------------End of findGenericMatch---------------------------------------------# 
#---------------------------------------------------------------------------------
# probeDestUpdate
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Description  : Creates a new property 'probeDest' from the 'ownerCustomTag'property
#				 to the matched se line
# Input        : CurrentHostname,currentSubeltname,subelementhash 
# Return       : None
# Author       : Bijay Kumar Sahoo
# Date         : March 10 2011
#----------------------------------------------------------------------------------
sub probeDestUpdate
{
    my ($self,$Host,$seName,$UniqueMatchesHash)=@_;
	my $pLog=$self->{PLOG};
    my $rtnCode="FAIL";
	$$UniqueMatchesHash {$Host}{$seName} =~ /ownerCustomTag\|_\|(.*?)\|_\|/i ;
	my $ownerCustomTag = $1;
	$ownerCustomTag =~ s#(\s+)$##;
	my (@srsDest)=split("_" ,$ownerCustomTag);
	if (scalar(@srsDest)<3)
	{
		return;
	}
	return if (($srsDest[0] =~ m/^(\s*)$/)||($srsDest[1] =~ m/^(\s*)$/));
	my $currSeLine = $$UniqueMatchesHash {$Host}{$seName};
	$currSeLine.= "probeDest|_|$srsDest[1]|_|";
	$$UniqueMatchesHash{$Host}{$seName} = $currSeLine;
}	
#------------------------------------------End of UpdateSSID---------------------------------------------------# 
#-------------------------------------------------------------------------------
# UpdateMPLSType
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Description  : Updates MPLS PORT TYPE to the required QoS records whose data are not 
#				  avaialble in UII Feed.
# Input        : key of UIIRecord10Hash,CurrentHostname,currentSubeltname,
#				 BT_PORT_MPLS_TYPE,QoSFamily and subelementhash 
# Return       : None
# Author       : Vivek Venudasan
# Date         : 17th May 2010
#-------------------------------------------------------------------------------
sub UpdateMPLSType
{   
    my ($self,$key,$Host, $seName,$MPLSType,$QoSFamily,$UniqueMatchesHash)=@_;
    my $verbose = $self->{LOGFILEVERBOSE};
	my $subelename;
	my $line;
	my $pLog=$self->{PLOG};
    my $rtnCode="FAIL";
	my $func="UpdateMPLSType";
	my $btSupplier = ${ $UIIRecord10Hash{$key} }[$UIIRecordHash{BT_SUPPLIER_ID}];
	my $btNEType= ${ $UIIRecord10Hash{$key} }[$UIIRecordHash{BT_NE_TYPE}];
	my $btNEUsage = ${ $UIIRecord10Hash{$key} }[$UIIRecordHash{BT_NE_USAGE}];	
	if (($btSupplier eq "ALN" && $btNEType eq "Edge Rt" && ($btNEUsage eq "Edge Ethernet Switch" || $btNEUsage eq "Multi Service Edge" || $btNEUsage eq "Infra Edge Agg" || $btNEUsage eq "Multi Service Core" ||$btNEUsage eq "Flexible Build EEA" || $btNEUsage eq "Ethernet Edge Router"))|| ($btSupplier eq "CIS" && $btNEType eq "Core Rt" && ($btNEUsage eq "STD" || $btNEUsage eq "Edge Rt" ))||	(($btSupplier eq "LUC" || $btSupplier eq "SIE" || $btSupplier eq "JUN") && ($btNEType eq "Edge Rt" ||$btNEType eq "Core Rt") && ($btNEUsage eq "STD" || $btNEUsage eq "PE CO (Voice)")))
	{
		
#		$$UniqueMatchesHash {$Host}{$seName} =~ /BT_MATCH_1\|_\|(.*?)\|_\|/i ;

		$UniqueMatchHash {$Host}{$seName} =~ /BT_MATCH_1\|_\|(.*?)\|_\|/i ;
		my $BTMATCHVal = $1;
		
		#49924
		$UniqueMatchHash {$Host}{$seName} =~ /BT_LAG_ID\|_\|(.*?)\|_\|/i ;
		my $BTLAGID = $1;
		$subelename=$LagMPLSUpdateHash{$BTLAGID};
		#$pLog->PrintInfo("value of subelement name is $subelename");
		#$pLog->PrintInfo("updating unique match hash for MPLS TYPE for lag :|$LagMPLSUpdateHash{$BTLAGID}|");
		$line = $UniqueMatchHash {$Host}{$subelename};
		$pLog->PrintInfo("currently the unique matchhash is |$line|") if $verbose == 1;
		$line.="BT_PORT_MPLS_TYPE|_|$MPLSType|_|";
		$UniqueMatchHash {$Host}{$subelename} = $line;
		$pLog->PrintInfo("Updated Unique match hash is |$UniqueMatchHash{$Host}{$subelename}|") if $verbose == 1;
		if($BTLAGID !~ /no-lag/i)
		{
			if(! exists $LagInfoHash{$BTLAGID})
			{			
				$LagInfoHash{$BTLAGID} = 1;
				foreach my $subeltkey (keys %{${$UniqueMatchesHash}{$Host}})
				{				
					my $eachline = $$UniqueMatchesHash{$Host}{$subeltkey};			
					if($eachline =~ /InterfaceDescr\|_\|$BTLAGID\|_\|/ && $eachline =~ /$QoSFamily/ )
					{ 
						$eachline =~ s#(\s+)$##;
						if ($eachline !~ /BT_PORT_MPLS_TYPE/){
							$eachline .= "BT_PORT_MPLS_TYPE|_|$MPLSType|_|";
						}
						$$UniqueMatchesHash{$Host}{$subeltkey} = $eachline;
						$pLog->PrintInfo("Unique match hash after updating MPLS for QOS on lags is :|$$UniqueMatchesHash{$Host}{$subeltkey}|") if $verbose == 1;
					}				
				}
			}
			else{
				$pLog->PrintInfo("This Lag <$BTLAGID> is already handled! Exiting function!");
			}
		}
		else 
		{
			foreach my $subeltkey (keys %{${$UniqueMatchesHash}{$Host}})
			{    my $eachlinenolag = $$UniqueMatchesHash{$Host}{$subeltkey};
				if($eachlinenolag =~ /InterfaceDescr\|_\|$BTMATCHVal\|_\|/ && $eachlinenolag =~ /$QoSFamily/ ){
					$eachlinenolag =~ s#(\s+)$##;
					if ($eachlinenolag !~ /BT_PORT_MPLS_TYPE/)
					{
						$eachlinenolag .= "BT_PORT_MPLS_TYPE|_|$MPLSType|_|";
					}
					$$UniqueMatchesHash{$Host}{$subeltkey} = $eachlinenolag;
				}
			}
		}
	}
}
#------------------------------------------End of UpdateMPLSType---------------------------------------------------# 
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Description  : Updates SSID to the required QoS records whose data are not 
#				  avaialble in UII Feed.
# Input        : key of UIIRecord10Hash,CurrentHostname,currentSubeltname,
#				 BT_SS_ID,QoSFamily and subelementhash 
# Return       : None
# Author       : Vivek Venudasan
# Date         : 17th May 2010
#----------------------------------------------------------------------------------
sub UpdateSSID
{
    my ($self,$key,$seline,$Host, $seName,$SSID,$QoSFamily,$UniqueMatchesHash)=@_;
	my $pLog=$self->{PLOG};
	my $verbose = $self->{LOGFILEVERBOSE};
	my $func = "UpdateSSID";
    my $rtnCode="FAIL";
	my $btPortID = "";
	my $btSupplier = ${ $UIIRecord10Hash{$key} }[$UIIRecordHash{BT_SUPPLIER_ID}];
	my $btNEType= ${ $UIIRecord10Hash{$key} }[$UIIRecordHash{BT_NE_TYPE}];
	my $btNEUsage = ${ $UIIRecord10Hash{$key} }[$UIIRecordHash{BT_NE_USAGE}];	
	if (($btSupplier eq "ALN" && $btNEType eq "Edge Rt" && ($btNEUsage eq "Edge Ethernet Switch" || $btNEUsage eq "Multi Service Edge" || $btNEUsage eq "Infra Edge Agg" || $btNEUsage eq "Multi Service Core" ||$btNEUsage eq "Flexible Build EEA" || $btNEUsage eq "Ethernet Edge Router"))|| ($btSupplier eq "CIS" && $btNEType eq "Core Rt" && ($btNEUsage eq "STD" || $btNEUsage eq "Edge Rt" ))||	(($btSupplier eq "LUC" || $btSupplier eq "SIE" || $btSupplier eq "JUN") && ($btNEType eq "Edge Rt" ||$btNEType eq "Core Rt") && ($btNEUsage eq "STD" || $btNEUsage eq "PE CO (Voice)"))){
		
#49924 Updated $UniqueMatchesHash to UniqueMatchHash			
		$UniqueMatchHash {$Host}{$seName} =~ /BT_MATCH_1\|_\|(.*?)\|_\|/i ;
#49924 
		my $BTMATCHVal = $1;
#49924		
		#$UniqueMatchHash {$Host}{$seName} =~ /AP_ifSpeed\|_\|(.*?)\|_\|/i ;
		#my $ifSpeed = $1;
		$UniqueMatchHash {$Host}{$seName} =~ /BT_LAG_ID\|_\|(.*?)\|_\|/i ;
		my $LagID = $1;
		$UniqueMatchHash {$Host}{$seName} =~ /AP_ifHighSpeed\|_\|(.*?)\|_\|/i ;
		my $ifHighSpeed = $1;
#49924
		if (${ $UIIRecord20Hash{$key}{$seline} }[$UIIRecordHash{BT_SS_ID}] !~ /^\s*$/)
		{
			#BS 21CNCE-23418 Changes - Update properties DisplaySpeed, BT_ZEND_LOC_1141, BT_ZEND_SNE, BT_ZEND_TP
			#my $displaySpeed = $$subelementSplitHash{$Host}{$seName}{DisplaySpeed};
#49924 Updated $UniqueMatchesHash to UniqueMatchHash			
			$UniqueMatchHash {$Host}{$seName} =~ /DisplaySpeed\|_\|(.*?)\|_\|/i ;
#49924 				
			my $displaySpeed = $1;
			my $btZENDLoc = ${ $UIIRecord20Hash{$key}{$seline} }[$UIIRecordHash{BT_ZEND_LOC_1141}];
			my $btZENDSne = ${ $UIIRecord20Hash{$key}{$seline} }[$UIIRecordHash{BT_ZEND_SNE}];
			my $btZENDTp = ${ $UIIRecord20Hash{$key}{$seline} }[$UIIRecordHash{BT_ZEND_TP}];
			$btPortID = ${ $UIIRecord20Hash{$key}{$seline} }[$UIIRecordHash{BT_PORT_ID}];
			if ($btZENDLoc =~ /^\s*$/){
				$btZENDLoc = 'NULL';
			}
			if ($btZENDSne =~ /^\s*$/){
				$btZENDSne = 'NULL';
			}
			if ($btZENDTp =~ /^\s*$/){
				$btZENDTp = 'NULL';
			}
						
			foreach my $subeltkey (keys %{${$UniqueMatchesHash}{$Host}}){
				my $eachline = $$UniqueMatchesHash{$Host}{$subeltkey};
				if ($eachline =~ /InterfaceDescr\|_\|$BTMATCHVal\|_\|/ && $eachline =~ /$QoSFamily/ ){
					$eachline =~ s#(\s+)$##;
					if ($eachline !~ /BT_SS_ID/){
						$eachline .= "BT_SS_ID|_|$SSID|_|";
						$eachline .= "DisplaySpeed|_|$displaySpeed|_|";
						$eachline .= "BT_ZEND_LOC_1141|_|$btZENDLoc|_|";
						$eachline .= "BT_ZEND_SNE|_|$btZENDSne|_|";
						$eachline .= "BT_ZEND_TP|_|$btZENDTp|_|";
						$eachline .= "BT_PORT_ID|_|$btPortID|_|";
#49924						
						$eachline .= "BT_LAG_ID|_|$LagID|_|";
						$eachline .= "AP_ifHighSpeed|_|$ifHighSpeed|_|" if ($LagID =~ /no-lag/);
#49924						
					}
					$$UniqueMatchesHash{$Host}{$subeltkey} = $eachline;
					$pLog->PrintInfo( "$func: qos line $eachline") if $verbose == 1;
				}
			}
		}
		else
		{
				$btPortID = ${ $UIIRecord20Hash{$key}{$seline} }[$UIIRecordHash{BT_PORT_ID}];
				foreach my $subeltkey (keys %{${$UniqueMatchesHash}{$Host}}){
					my $eachline = $$UniqueMatchesHash{$Host}{$subeltkey};
					if ($eachline =~ /InterfaceDescr\|_\|$BTMATCHVal\|_\|/ && $eachline =~ /$QoSFamily/ ){
						$eachline =~ s#(\s+)$##;
						$eachline .= "BT_PORT_ID|_|$btPortID|_|";
#49924					
						$eachline .= "BT_LAG_ID|_|$LagID|_|";	
						$eachline .= "AP_ifHighSpeed|_|$ifHighSpeed|_|" if ($LagID =~ /no-lag/);
#49924	
					}
					$$UniqueMatchesHash{$Host}{$subeltkey} = $eachline;
				}
		}
		
	}
}	
#------------------------------------------End of UpdateSSID---------------------------------------------------# 
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Description  : Updates BT_LAG_ID for LAGs and Insert AP_ifHighSpeed value for all QoS that are on LAGs 
# Input        : lagName, if Speed, Complefilehash, UniqueMatchHash and QoSFamily Name
# Return       : None
# Author       : Deepa Chandran
# Date         : 22th August 2012
#----------------------------------------------------------------------------------
sub UpdateLagIdandBandwidth
{
    my ($self,$eltkey,$subeltkey,$lagName,$CompleteFileHash,$UniqueMatchHash,$QoSFamily,$ifHighSpeed)=@_;
	my $pLog=$self->{PLOG};
	my $func = "UpdateLagIdandBandwidth";
	my $verbose = $self->{LOGFILEVERBOSE};
	#############Inserting BT_LAG_ID property for LAGs
	my $eachline = $$UniqueMatchHash{$eltkey}{$subeltkey};
    $eachline =~ s#(\s+)$##;
	$eachline .= "BT_LAG_ID|_|$lagName|_|";
	$$UniqueMatchHash{$eltkey}{$subeltkey} = $eachline;
	#######################################
	#############Insert BT_LAG_ID and  AP_ifSpeed for QoS
	$$UniqueMatchHash{$eltkey}{$subeltkey} =~ /BT_MATCH_1\|_\|(.*?)\|_\|/i ;
	my $BTMATCHVal = $1;
	#$pLog->PrintInfo("Lag name is $lagName");
	
	$LagMPLSUpdateHash{$lagName} = $subeltkey;
	foreach my $key (keys %LagMPLSUpdateHash)
	{ #key : Bundle-EtherXX or aeXX 
	  #value : Lag subelement Name
	 $pLog->PrintInfo("value of the hash key is |$key| and value corresponding to the key is $LagMPLSUpdateHash{$key}") if $verbose == 1;
	}
	#$pLog->PrintInfo("value of lag name is $lagName and LAG subelement name is $LagMPLSUpdateHash{$lagName}");
	foreach my $subelt (keys %{${$CompleteFileHash}{$eltkey}})
	{
		my $eachline = $$CompleteFileHash{$eltkey}{$subelt};
		if ($eachline =~ /InterfaceDescr\|_\|$BTMATCHVal\|_\|/ && $eachline =~ /$QoSFamily/)
		{
			$eachline =~ s#(\s+)$##;
			$eachline .= "BT_LAG_ID|_|$lagName|_|";
			$eachline .= "AP_ifHighSpeed|_|$ifHighSpeed|_|";
			#$eachline .= "BT_PORT_MPLS_TYPE|_|$";
			$$CompleteFileHash{$eltkey}{$subelt} = $eachline;
			$pLog->PrintInfo( "$func: Updated the lagID and APifspeed:|$$CompleteFileHash{$eltkey}{$subelt}|") if $verbose == 1;
		}
	}
	#######################################	

				
}	
#------------------------------------------End of UpdateLagIdandBandwidth---------------------------------------------------#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Description  : Updates  bandwidth values
#				  
# Input        : 
# Return       : None
# Author       : Vivek Venudasan
# Date         : 17th May 2010
#----------------------------------------------------------------------------------
sub updateBBASVLANBW
{
    my ($self,$key,$Host,$seName,$BT_TOTAL_WBC_ASSURED_RATE_BW,$BT_TOTAL_WBC_BEST_EFFORT_BW,$BT_BBASVLAN_RT_BANDWIDTH,$APID,$UniqueMatchesHash,$subelementSplitHash)=@_;
	my $pLog=$self->{PLOG};
    my $rtnCode="FAIL";	
	if ($APID !~ /^\s*$/ )
	{
		foreach my $subeltkey (keys %{${$UniqueMatchesHash}{$Host}}){
			my $eachline = $$UniqueMatchesHash{$Host}{$subeltkey};
			# my $label = $$subelementSplitHash{$Host}{$subeltkey}{"LABEL"};
			if (($eachline =~ /APID\|_\|$APID\|_\|/ )){
				$eachline =~ s#(\s+)$##;
				if ($eachline !~ /BT_TOTAL_WBC_ASSURED_RATE_BW/){
					$eachline .= "BT_TOTAL_WBC_ASSURED_RATE_BW|_|$BT_TOTAL_WBC_ASSURED_RATE_BW|_|";
				}
				if ($eachline !~ /BT_TOTAL_WBC_BEST_EFFORT_BW/){
					$eachline .= "BT_TOTAL_WBC_BEST_EFFORT_BW|_|$BT_TOTAL_WBC_BEST_EFFORT_BW|_|";
				}
				if ($eachline !~ /BT_BBASVLAN_RT_BANDWIDTH/){
					$eachline .= "BT_BBASVLAN_RT_BANDWIDTH|_|$BT_BBASVLAN_RT_BANDWIDTH|_|";
				}
				$$UniqueMatchesHash{$Host}{$subeltkey} = $eachline;
			}
		}
	}	
}	
#------------------------------------------End of updateBBASVLANBW---------------------------------------------------# 
#-------------------------------------------------------------------------------------------------
# IPFilterPreSyncSEMatching
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -------------------
# Description  : Performs the matching process for ALCATEL IPFilter sub-elemnets.
# Input        : current UII 20I record line.
# Return       : None.
# Author        : G Anil Kumar
# Date          : 07th June 2012.
#-------------------------------------------------------------------------------------------------
sub IPFilterPreSyncSEMatching
{
    my ($self, $arrSEData,$MatchValHash,$CompleteFileHash,$UniqueMatchesHash,$ProvisoMap,$selines)=@_;
    my $pLog=$self->{PLOG};
    my $func="IPFilterPreSyncSEMatching";
    my @matchList;
    my $currentHost="";
	my  $currentDevice="";
    $currentDevice=$$arrSEData[$UIIRecordHash{$self->{IPADDPROP}}];
    $currentHost=$$arrSEData[$UIIRecordHash{$self->{HOSTNAMEPROP}}];
    my $myData = $currentHost."|_|".$currentDevice;
	my $testexpression = " ";
	my $currentLine;
	
	#initialise matchList
	$matchList[0]="BT_CHANNEL_ID";
	$matchList[1]="BT_CHANNEL_NAME";
	$matchList[2]="BT_CHANNEL_GROUP_IP_ADDRESS";
	$matchList[3]="BT_IP_FILTER_ID";
	$matchList[4]="BT_SUPPLIER_PORT_ID";
	$matchList[5]="BT_VLAN_ID";
	$matchList[6]="BT_SERVICE_ID";
	
	## SE Matching for ALN 7750 Edge Rt NE TYPE devices(IP Filter sub-elemenst) 
	##-----------------------------------------------------------------------
	$pLog->PrintDebug( "$func: BT_SUPPLIER_ID -> ${$UIIRecord10Hash{$myData}}[$UIIRecordHash{BT_SUPPLIER_ID}]");
	$pLog->PrintDebug( "$func: BT_NE_TYPE -> $$arrSEData[$UIIRecordHash{BT_NE_TYPE}]");
	$pLog->PrintDebug( "$func: BT_CHANNEL_ID -> $$arrSEData[$UIIRecordHash{$matchList[0]}]");
	$pLog->PrintDebug( "$func: BT_CHANNEL_NAME -> $$arrSEData[$UIIRecordHash{$matchList[1]}]");
	$pLog->PrintDebug( "$func: BT_CHANNEL_GROUP_IP_ADDRESS -> $$arrSEData[$UIIRecordHash{$matchList[2]}]");
	$pLog->PrintDebug( "$func: BT_IP_FILTER_ID -> $$arrSEData[$UIIRecordHash{$matchList[3]}]");
	
	
	if( ${$UIIRecord10Hash{$myData}}[$UIIRecordHash{BT_SUPPLIER_ID}] eq "ALN" && $$arrSEData[$UIIRecordHash{BT_NE_TYPE}] eq "Edge Rt" )
	{
		if( $$arrSEData[$UIIRecordHash{$matchList[0]}] !~ /^$/ && $$arrSEData[$UIIRecordHash{$matchList[1]}] !~ /^$/ && $$arrSEData[$UIIRecordHash{$matchList[2]}] !~ /^$/ && $$arrSEData[$UIIRecordHash{$matchList[3]}] !~ /^$/)
		{
			# Creating the TestExpression for ALN 7750 IPFilter 
			$testexpression = $$arrSEData[$UIIRecordHash{$matchList[3]}]."_".$$arrSEData[$UIIRecordHash{$matchList[2]}];	
			$pLog->PrintDebug( "$func: testexpression $testexpression");
		}
	}
	
	#Finding match for IPFilter se with testexpression formed using BT_IP_FILTER_ID &BT_CHANNEL_GROUP_IP_ADDRESS
	foreach my $sedatkey (keys %{${$CompleteFileHash}{$currentHost}})
	{
		if (($$MatchValHash{$currentHost}{$sedatkey}{$ProvisoMap} =~ /$testexpression/) && ($$MatchValHash{$currentHost}{$sedatkey}{"STATE"} eq "on" ))
		{						
			$$CompleteFileHash {$currentHost}{$sedatkey} =~ s#(\s+)$##;
			$currentLine = $$CompleteFileHash {$currentHost}{$sedatkey};
			#Adding IPFilter specific properties to matched Sub-elements.
			foreach my $ipFilterProp (@matchList){
				$currentLine .= "$ipFilterProp|_|$$arrSEData[$UIIRecordHash{$ipFilterProp}]|_|";
			}
			$$UniqueMatchesHash{$currentHost}{$sedatkey} = $currentLine;
			delete $$CompleteFileHash {$currentHost}{$sedatkey};
			delete $$MatchValHash{$currentHost}{$sedatkey};
			my @tempArr = @{$UIIRecord20Hash{$myData}{$selines}};
			$pLog->PrintDebug( "$func: Successful match for IP Filter $testexpression");
			last;
		}
	}

 }
#------------------------------------End of AlcatelPreSyncSEMatching--------------------------------------------#

#--------------------------------------------------------------------------------------------
# createFile
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Description  : To write back the data from the datastructures to a file
# Input        : The required hash  and the path to the file.
# Return       : None
# Author       : Vivek Venudasan
# Date         : 17th May 2010
#----------------------------------------------------------------------------------------------
sub createFile
{
    my ($UniqueMatchesHash,$filepath)=@_;	
	open (FH,">$filepath");
	print FH "# type = se\n";
	print FH "# col = invariant elt.name name date instance label state fam.name seprp.name:name seprp.value:name\n";
	print FH "# filter = \n";	
	foreach my $eltkey (keys %{$UniqueMatchesHash}){
		 foreach my $subeltkey (keys %{${$UniqueMatchesHash}{$eltkey}}){
			 $$UniqueMatchesHash{$eltkey}{$subeltkey} =~ s#(\s+)$##;
			 print FH $$UniqueMatchesHash{$eltkey}{$subeltkey},"\n";
		}
	}
	if (-e $filepath){
		return 'SUCCESS'
	}
	else{
		return 'FAIL'
	}
}
#------------------------------------------End of createFile---------------------------------------------------# 
#--------------------------------------------------------------------------------------------
# createResidueLogs
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Description  : To write the inventory residue/network Residue data to a file.
# Input        : The required hash,the path to the file and an indicator to mention whether 
#				 an inventory residue or network residue.
# Return       : None
# Author       : Vivek Venudasan
# Date         : 14th June 2010
#----------------------------------------------------------------------------------------------
sub createResidueLogs
{
    my ($RequiredHash,$ReferenceHash,$filepath,$indicator)=@_;	
	if ($indicator == 1){
		if (! -e $filepath){
			open (FH,">$filepath");
			print FH "# This file lists all the UII subelement records which are not matched.\n";
			print FH "# Hence the following UII subelements will NOT be present in the database.\n";
			print FH "# The format of this file is exactly the same as that of the UII feed file provided.\n";
			close FH;
		}
		open (FH,">>$filepath");
		foreach my $eltkey (keys %{$RequiredHash}){
			foreach my $subeltkey (keys %{${$RequiredHash}{$eltkey}}){
				my $eachline = join('Ì',@{$$RequiredHash{$eltkey}{$subeltkey}});
				print FH $eachline,"\n";
			}
		}
		close FH;
	}
	elsif($indicator == 2){
		if (! -e $filepath){
			open (FH,">$filepath");
			print FH "# This file lists all those subelements which are present in the network but not listed in the UII source feed file.\n";
			print FH "# The format of this file is exactly the same as that of the subelement.dat file created after discovery.\n";
			print FH "# type = se\n";
			print FH "# col = invariant elt.name name date instance label state fam.name seprp.name:name seprp.value:name\n";
			print FH "# filter = \n";
		}		
		open (FH,">>$filepath");
		foreach my $eltkey (keys %{$RequiredHash}){
			foreach my $subeltkey (keys %{${$RequiredHash}{$eltkey}}){
				 $$RequiredHash{$eltkey}{$subeltkey} =~ s#(\s+)$##;
				 print FH $$RequiredHash{$eltkey}{$subeltkey},"\n";
			}
		}
		close FH;
	}
	else{
		open (FH,">>$filepath");
		foreach my $eltkey (keys %{$RequiredHash}){
			foreach my $subeltkey (keys %{${$RequiredHash}{$eltkey}}){
				 $$RequiredHash{$eltkey}{$subeltkey} =~ s#(\s+)$##;
				 print FH $$RequiredHash{$eltkey}{$subeltkey},"\n" if (!exists $$ReferenceHash{$eltkey}{$subeltkey});
			}
		}
		close FH;
	}
}
#------------------------------------------End of createResidueLogs---------------------------------------------------# 

# RelAQ 21CNCE-70998
#--------------------------------------------------------------------------------------------
# createFailedInterfaceFile
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Description  : To write the matching failed interfaces to a file.
# Input        : Inventory Residue hash reference
# Return       : None
# Author       : Rajani K
# Date         : 21th Sep 2014
#----------------------------------------------------------------------------------------------
sub createFailedInterfaceFile
{
	my ($self,$RequiredHash)=@_;	
	my $pLog=$self->{PLOG};
	my $func = "createFailedInterfaceFile";

	my $failedSubelementsFile = $self->{"THISLOADDIR"}."/".$self->{"THISLOADINFO"}."/Interface_Failure_Record.dat";
	my $currentTime = time;

	$pLog->PrintDebug( "$func: Writing  Failed interfaces to Interface_Failure_Record.dat file");
	if (! -e $failedSubelementsFile)
	{
		open (INTERFACEFH, ">$failedSubelementsFile"); 
		print INTERFACEFH "# This file lists all the UII subelement records which are not matched.\n";
		print INTERFACEFH "# The format is IP Address|_|NE ID|_|BT_MODEL|_|Port ID|_|LAG ID|_|VLAN ID|_|CVLAN_ID|_|Service ID|_|First Failure Time|_|Last Retry Time|_|Retry Counter|_|Testexpression\n";
		close INTERFACEFH;
	}

	open (INTERFACEFH, ">>$failedSubelementsFile") || $pLog->PrintInfo( "$func: Unable to open file $failedSubelementsFile!");
	my $eachline;
	foreach my $eltkey (keys %{$RequiredHash})
	{
		foreach my $subeltkey (keys %{${$RequiredHash}{$eltkey}})
		{
			my $testexpression = "";
			$testexpression = $portdownResidueHash{$eltkey}{$subeltkey} if ( defined $portdownResidueHash{$eltkey}{$subeltkey} ) ;
			if ($testexpression !~ /^$/ && ( ${${$RequiredHash}{$eltkey}{$subeltkey}}[$UIIRecordHash{$self->{TRANSTYPEPROP}}] ne "D"))
			{
				chomp($testexpression);
				$eachline = "${${$RequiredHash}{$eltkey}{$subeltkey}}[$UIIRecordHash{BT_IP_ADDRESS}]|_|${${$RequiredHash}{$eltkey}{$subeltkey}}[$UIIRecordHash{BT_NE_ID}]|_|${${$RequiredHash}{$eltkey}{$subeltkey}}[$UIIRecordHash{BT_SUPPLIER_PORT_ID}]|_|${${$RequiredHash}{$eltkey}{$subeltkey}}[$UIIRecordHash{BT_LAG_ID}]|_|${${$RequiredHash}{$eltkey}{$subeltkey}}[$UIIRecordHash{BT_VLAN_ID}]|_|${${$RequiredHash}{$eltkey}{$subeltkey}}[$UIIRecordHash{BT_CVLAN_ID}]|_|${${$RequiredHash}{$eltkey}{$subeltkey}}[$UIIRecordHash{BT_SERVICE_ID}]|_|$currentTime|_|$currentTime|_|0|_|$testexpression";
				print INTERFACEFH "$eachline\n";
			}
		}
	}
	close INTERFACEFH;
}

return 1;
#-------------------------------------------------------------END-------------------------------------------------------------#


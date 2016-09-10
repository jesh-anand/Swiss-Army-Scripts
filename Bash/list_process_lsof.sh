# Prajesh Ananthan - 2015
#!/bin/bash

divider===============================
divider=$divider$divider
yellowtext="\033[33m"
bold="\033[1m"
normal="\033[0m"

username="btwnpmt01"
logdate=$(date +"%Y/%m/%d %H:%M:%S")
process=$(ps -U btwnpmt01 | wc -l)
files=$(lsof | grep -c btwnpmt01)
wlprocess=$(ps -U btwnpmt01 | grep -c weblogic)
wlfiles=$(lsof | grep btwnpmt01 | grep -c weblogic)

echo -e $bold"Quick System Report Of Process Count For "$yellowtext"btwnpmt01"$normal
printf "$logdate |\tUsername:\t\t%s\n" $username
printf "$logdate |\tTotal Process Count:\t%s\n" $process
printf "$logdate |\tTotal File Count:\t%s\n" $files
printf "$logdate |\tWeblogic Process:\t%s\n" $wlprocess
printf "$logdate |\tWeblogic File Count:\t%s\n" $wlfiles
printf "$divider%s\n"
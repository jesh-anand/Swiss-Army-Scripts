#!/bin/sh
echo "Going to download csv files from NH21 Server."
var=$(date '+%Y_%m_%d')
echo "Going to process of $var date files"
scp pvuser@10.213.247.243:/apps/YUKON_FEED/ycwearn/IL2S/prajesh/ECI_*.tar.gz /home/pvuser/prajesh
echo "File downloaded successfully...."
echo "Downloaded file Name : $FileName"
#done

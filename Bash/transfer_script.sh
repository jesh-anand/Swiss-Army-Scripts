#!/bin/sh
echo "Going to download csv files from NH21 Server."
scp /home/pvuser/prajesh /apps/YUKON_FEED/ycwearn/IL2S/prajesh/ECI_*.tar.gz pvuser@10.213.247.243:/apps/NPM/NPMCollector/data/npm-feed-output/custom
scp /home/pvuser/prajesh /apps/YUKON_FEED/ycwearn/IL2S/prajesh/Huawei_*.tar.gz pvuser@10.213.247.243:/apps/NPM/NPMCollector/data/npm-feed-output/custom
echo "File downloaded successfully...."
echo "Downloaded file Name : $FileName"
#done

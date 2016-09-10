#!/bin/bash
if kill -0 `ps -ef | grep -v grep | grep NPMCollector | awk '{print $2}'`;
then
	echo "Collector is already running!"
else
	nohup ./start_yukon.sh &
fi

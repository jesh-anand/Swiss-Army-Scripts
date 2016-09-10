#!/bin/bash
if kill -0 `ps -ef | grep -v grep | grep NPMCollector | awk '{print $2}'`;
then
	echo "Collector is running!"
else
	echo "Collector is not running!"
fi

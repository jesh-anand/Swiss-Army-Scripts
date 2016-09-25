#!/bin/sh

# Initialization
CONFIG=/apps/svmp_loader/conf
LIB=/apps/svmp_loader/lib
LOG=/apps/svmp_loader/log

PID=`ps -ef | grep SVMP_LOADER | grep java | awk '{print $2}'`

if [ -n "$PID" ]; then 
	echo "SVMP LOADER job is running."
else
	java -Dname=SVMP_LOADER -DlogFilename=${LOG}/svmp_loader.log -classpath ${CONFIG}/:${LIB}/svmp-loader.jar:${LIB}/log4j-1.2.17.jar:${LIB}/ojdbc6.jar:${LIB}/javax.mail.jar -Xms128m -Xmx2048m -Dlog4j.configuration=file:${CONFIG}/log4j.xml com.bt.svmp.SVMPLoader ${CONFIG}/loader.conf
fi

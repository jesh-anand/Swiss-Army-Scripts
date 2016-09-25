#!/bin/bash

export APP_NAME=UIIPathFinderParser
export BASE_PATH=/apps/svmp_parser/

cd $BASE_PATH

LOCKFILE=$BASE_PATH/$APP_NAME.lck

if [ -e ${LOCKFILE} ] && kill -0 `cat ${LOCKFILE}`; then
    echo "$APP_NAME already running"
    exit
fi

PID=$$	
echo ${PID} > ${LOCKFILE}
/usr/bin/perl ${BASE_PATH}src/UIIPathFinderParser.pl ${BASE_PATH}conf/UIIPathFinderParser.conf
# rm $LOCKFILE

#!/bin/sh

# Initialization

APP_NAME=UIISTAGING_COMPLETE
BASE_PATH=/apps/channel/UII_STAGING
CONFIG=/apps/channel/UII_STAGING/conf
LIB=/apps/channel/UII_STAGING/lib
LOG=/apps/channel/UII_STAGING/log

usage()
{
    cat <<__END_USAGE

Usage: $0 [ options ] [record level]

    Options:
        -i                      - Input File where contain IP addresses separated by newline.
        -o                      - Output UII FEED Filename with full path
                                  Attention! Will override existing file if exist.
                                  
        -e                      - Element to generate
        -m                      - Filter by Model
        -s                      - Filter by Supplier
        -u                      - Filter by Usage
                                  
        Where:
            record level        PORT | LAG | VLAN
                                - Generate all level if do not specify
        
        Ex1: $0 -i /apps/channel/input/abc.dat -o /apps/channel/output/abc.dat "VLAN|_|PORT"
        Ex2: $0 -i /apps/channel/input/elements.dat -o /apps/channel/output/uii.dat
        Ex3: $0 -i /apps/channel/input/abc.dat
        Ex4: $0 -e 10.92.68.65|_|10.92.68.67
        Ex5: $0 -e 10.92.68.65

__END_USAGE

    exit 1
}

DEFINE_OPTS=""

while getopts "i:o:e:m:s:u:" i
do
    case $i in
    i) DEFINE_OPTS="$DEFINE_OPTS -Dinput.filename=${OPTARG}";;
    o) DEFINE_OPTS="$DEFINE_OPTS -Doutput.filename=${OPTARG}";;
    e) DEFINE_OPTS="$DEFINE_OPTS -Delement=${OPTARG}";;
    m) DEFINE_OPTS="$DEFINE_OPTS -Dmodel=${OPTARG// /^}";;
    s) DEFINE_OPTS="$DEFINE_OPTS -Dsupplier.id=${OPTARG// /^}";;
    u) DEFINE_OPTS="$DEFINE_OPTS -Dusage=${OPTARG// /^}";;
    *)usage; exit 1;;
    esac
done

shift `expr ${OPTIND} - 1`

cd $BASE_PATH

LOCKFILE=$BASE_PATH/lock/$APP_NAME.lck

if [ -e ${LOCKFILE} ] && kill -0 `cat ${LOCKFILE}`; then
    echo "$APP_NAME already running"
    exit
fi

PID=$$
echo ${PID} > ${LOCKFILE}

	java $DEFINE_OPTS -Dname=UIISTG -DlogFilename=${LOG}/uiistg.log -classpath ${CONFIG}/:${LIB}/* -Xms128m -Xmx2048m -Dlog4j.configuration=file:${CONFIG}/log4j.xml com.bt.reporting.nh21.uiistg.CompleteFeedController "$@" ${CONFIG}/uiistag.config

exit $?

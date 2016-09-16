#!/bin/bash

#
# Uses a keytab to auth to kerberos and transfer the file to HDFS
# author : 607980248
# date   : 19-11-2015
#

KEYTAB=/home/pvuser/harish/ModelA_Test/ADBaselineAlarmDataExtract/conf/SV064871.keytab
PRINCIPAL=SV064871@IUSER.IROOT.ADIDOM.COM
HTTPFS="http://haas-1a.nat.bt.com:14000/webhdfs/v1"

KINIT=/usr/bin/kinit
CURL=/usr/bin/curl

function die {
  echo "ERROR: $1"
  exit 1 
}

SOURCE_FILE=$1
[ -z "$SOURCE_FILE" ] && die "Please specify the file to be transfer as first argument!"

TARGET_DIR=$2
[ -z "$TARGET_DIR" ] && die "Please specify the destination file path in HDFS as second argument!"

[ -f "$KEYTAB" ] || die "keytab file $KEYTAB does not exist!"
[ -x "$KINIT" ] || die "kinit binary $KINIT does not exist or is not executable!"
[ -x "$CURL" ] || die "curl command $CURL does not exist or is not executable!"

FILEBASENAME=`basename $SOURCE_FILE`

$KINIT -k -t "$KEYTAB" "$PRINCIPAL" || die "Failed to authenticate to kerberos using keytab $KEYTAB as $PRINCIPAL"

$CURL -f -X PUT -i --negotiate -u : "${HTTPFS}${TARGET_DIR}?op=MKDIRS&permission=1775" || die "Failed to create target dir ${TARGET_DIR} in HDFS"
$CURL -f -H "Content-Type: application/octet-stream" -X PUT -T "$SOURCE_FILE" -i --negotiate -u : "${HTTPFS}${TARGET_DIR}/${FILEBASENAME}?op=CREATE&overwrite=true&data=true" || die "Failed to create ${TARGET_DIR}/${FILEBASENAME}"

echo "${TARGET_DIR}/${FILEBASENAME} created!"

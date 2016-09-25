#!/bin/sh
# Initialization

if [ -z "$1" ]
  then
    echo "Please specify record count to generate."
    exit 0;
fi
/usr/bin/perl /apps/channel/svmp_parser/src/generateUIIFeed.pl $1

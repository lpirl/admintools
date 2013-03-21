#!/bin/bash

# This script adds files from your file system to the fsroot directory
# and preserves the path.

cd `dirname $0`
SRC=$1
FSROOT="./fsroot/"

if [ "$1" == "" -o "$1" == "-h" -o "$1" == "--help" ]
then
	echo "please provide file to add as parameter"
	exit 1
fi

if [ ! -e "$SRC" ]
then
	echo "file not found"
	exit 2
fi

if [ ! -r "$SRC" ]
then
        echo "cannot read: permission denied"
        exit 2
fi

TGT="$FSROOT$SRC"
mkdir -p "$(dirname $TGT)"
ln -sf $SRC $TGT
chmod -R 500 $FSROOT

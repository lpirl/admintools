#!/bin/bash
# Use this script to provide an FILEutable in a chroot.
# ----------------------------------------------------------------------------
# Based on a script found at nixCraft <http://www.cyberciti.biz/tips/>
# ------------------------------------------------------------------------------

if [ $# -lt 2 ]; then
  echo "Syntax : $0 <path to chrooot> <file 1> [<file 2> […]]"
  exit 1
fi

BASE="$1"
FILE="$2"
CP_CMD="/usr/bin/rsync"
CP_ARGS="-RLa --ignore-errors"

if [ ! -x "$CP_CMD" ]
then
	echo "Copy command not found. I need to be able to run $CP_CMD"
	exit 1
fi
CP="$CP_CMD $CP_ARGS"

if [ ! -d $BASE ]
then
	echo "Chroot not found…"
	exit 1
fi

FILES="${*:2}"

echo "Copying files to $BASE..."
$CP $FILES $BASE

for FILE in $FILES
do
	if [ -x $FILE ]
	then
		echo "Collecting required shared files for $FILE..."

		SHAREDS="$(ldd $FILE | awk '{ print $3 }' |egrep -v ^'\(')"

		echo "Copying shared files/libs to $BASE..."

		$CP $SHAREDS $BASE

		# copy /lib/ld-linux* or /lib64/ld-linux* to $BASE
		# get ld-linux full file location 
		LD="$(ldd $FILE | grep 'ld-linux' | awk '{ print $1}')"

		if [ ! -f $BASE$LD ];
		then
		  echo "Copying $LD $BASE..."
		  $CP $LD $BASE
		fi
		exit 1
	fi
done

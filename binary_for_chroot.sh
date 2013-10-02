#!/bin/bash
# Use this script to provide an executable in a chroot.
# ----------------------------------------------------------------------------
# Based on a script found at nixCraft <http://www.cyberciti.biz/tips/>
# ------------------------------------------------------------------------------

if [ $# -lt 2 ]; then
  echo "Syntax : $0 /path/to/chroot /path/to/executable"
  exit 1
fi

BASE="$1"
EXEC="$2"
CP_CMD="/usr/bin/rsync"
CP_ARGS="-RLa"

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

if [ ! -x $EXEC ]
then
	echo "Executable not found…"
	exit 1
fi

echo "Copying executable to $BASE..."
$CP $EXEC $BASE

# iggy ld-linux* file as it is not shared one
FILES="$(ldd $EXEC | awk '{ print $3 }' |egrep -v ^'\(')"

echo "Copying shared files/libs to $BASE..."

$CP $FILES $BASE

# copy /lib/ld-linux* or /lib64/ld-linux* to $BASE/$sldlsubdir
# get ld-linux full file location 
sldl="$(ldd $EXEC | grep 'ld-linux' | awk '{ print $1}')"

if [ ! -f $BASE$sldl ];
then
  echo "Copying $sldl $BASE$sldlsubdir..."
  $CP $sldl $BASE
fi

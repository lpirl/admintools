#!/bin/bash

# Use this script to add additional cursors to your X session.

command -v xinput >/dev/null 2>&1 || {
	echo >&2 "This script requires the command 'xinput'. Bye.";
	exit 1;
}

mymaster=`date +%s`
function extract_id {
	echo $1 | awk -F "id=" '{ print $2 }'|awk -F " " '{ print $1 }'
}
function extract_master_id {
	echo $1 | cut -d "(" -f 2|cut -d")" -f1
}
eval set `xinput list |egrep 'slave  pointer|floating'|xargs -I line echo "\"line\""`
echo "select source device:"
select SOURCE in "$@";
do
	SOURCE_ID=$(extract_id "$SOURCE")
	REVERT_TARGET_ID=$(extract_master_id "$SOURCE")

	xinput create-master $mymaster
	TARGET=`xinput list|grep $mymaster|grep "master pointer"`
	TARGET_ID=$(extract_id "$TARGET")
	echo "created master $TARGET_ID"

	xinput reattach $SOURCE_ID $TARGET_ID
	break
done
if [ "$TARGET_ID" != "" ]
then
	echo
	echo "hit ENTER to remove cursor..."
	read
	xinput reattach $SOURCE_ID $REVERT_TARGET_ID 2> /dev/null # this is dirty
	echo "deleting master $TARGET_ID ..."
	xinput remove-master $TARGET_ID
fi

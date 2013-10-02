#!/bin/bash
#
# Use this script to check if all mount points are mounted (unique sources).
#

if [ $# -eq 0 ]; then
  echo "Test if all mounts are present, all from different devices."
  echo "Syntax: $0 [mount point 1] [mount point 2] …"
  echo "For example: $0 / /path/to/2nd/mountpoint"
  echo "would test if /path/to/mountpoint is mounted"
  exit 1
fi

ARGS="${*:1}"
FOUND_LIST=$(df ${ARGS[@]} | tail -n +2 | cut -d" " -f1 | sort -u)
FOUND_N=$(echo "$FOUND_LIST" | wc -l)
if [ $FOUND_N -ne $# ]
then
	echo "ERROR: not all disks mounted"
	FOUND_ONELINE=$(echo $FOUND_LIST | sed ':a;N;$!ba;s/\n/, /g')
	echo "Searched for $# unique mount points, found $FOUND_N ($FOUND_ONELINE)."
	exit 1
fi

#!/bin/bash
# Check if two locations in filesystem have roughly the same size.
#
# This check becomes handy, once you provide a maximum deviation
# and, for example, do not backup a gone source (ie. on a failing
# disk) to your backup target.

if [ $# -lt 2 ]; then
  echo "Example: $0 /path/a /path/b/ [maximum deviation percent]"
  exit 1
fi

if [ $# -lt 3 ]; then
	MAX_DEVIATION=0
else
	MAX_DEVIATION="$3"
fi

A=$(du -xs $1 | cut -f1)
B=$(du -xs $2 | cut -f1)

DEVIATION=$(python -c "print int(100*max($A, $B)/float(min($A, $B)))")

if [ $DEVIATION -gt $MAX_DEVIATION ]
then
	echo "ERROR: size differs too much: $DEVIATION% (max $MAX_DEVIATION%)"
	echo "$A	$1"
	echo "$B	$2"
	exit 1
fi

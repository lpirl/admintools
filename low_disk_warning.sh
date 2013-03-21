#!/bin/bash

# This scripts sends a mail to root when the used disk space exceeds
# a certain limit.
#
# Put a call to this script in your crontab to receive mails
# automatically when your disk space gets critically low.
#
# usage:
# $ ./low_disk_waring.sh <device> <max_percent_used>
# example:
# $ ./low_disk_waring.sh /dev/sda1 90

if [ "$1" = "" ]
then
	echo "please provide device as 1st argument. Like so:"
	echo "$0 /dev/sda1 90"
	exit 1
fi

if ! [[ "$2" =~ ^[0-9]+$ ]] ;
then
	echo "please provide the maximum fill percentage as 2nd argument. Like so:"
	echo "$0 /dev/sda1 90"
	exit 1
fi

CURRENT=$(df / | grep "$1" | awk '{ print $5}' | sed 's/%//g')
THRESHOLD=$2

if [ "$CURRENT" -gt "$THRESHOLD" ] ; then
    mail -s "$(hostname -f) Disk Space Alert" root << EOF
Your root partition remaining free space is critically low!
Used: $CURRENT%
EOF
fi

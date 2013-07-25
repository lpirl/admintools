#!/bin/bash

# This scripts sends an email to root when the used disk space exceeds
# a certain limit.
#
# Put a call to this script in your crontab to receive mails
# automatically when your disk space gets critically low.
#
# usage:
# $ ./disk_space_alert.sh <device> <max_percent_used>
# example:
# $ ./disk_space_alert.sh /dev/sda1 90

if [ "$1" = "" ]
then
	echo "please provide device as 1st argument. Example:"
	echo "$0 /dev/sda1 90"
	exit 1
fi

if ! [[ "$2" =~ ^[0-9]+$ ]] ;
then
	echo "please provide the maximum percentage of disk space used as 2nd argument. Example:"
	echo "$0 /dev/sda1 90"
	exit 1
fi

DF_LINE=$(df | grep "$1")
PERCENT_USED=$(echo $DF_LINE | awk '{ print $5}' | sed 's/%//g')
PERCENT_MAX=$2
MOUNTPOINT=$(echo $DF_LINE | awk '{ print $6}' | sed 's/%//g')
HOSTNAME=$(hostname -f)

if [ "$PERCENT_USED" -gt "$PERCENT_MAX" ] ; then
    mail -s "$HOSTNAME disk space alert" root << EOF
Dear Sir or Madam,

the remaining free disk space on device $1 mounted on $MOUNTPOINT is
critically low! Used: $PERCENT_USED%

Sincerely yours,

$(readlink -f "$0")
EOF
fi

#!/bin/bash

# This scripts sends an email to root when the used disk space exceeds
# a certain limit on any disk mounted from /dev/….
#
# Put a call to this script in your crontab to receive mails
# automatically when your disk space gets critically low.
#
# usage:
# $ ./disk_space_alert.sh <max_percent_used>
# example:
# $ ./disk_space_alert.sh 90

cd "$(dirname $0)"

if ! [[ "$1" =~ ^[0-9]+$ ]] ;
then
	echo "please provide the maximum allowed percentage of disk space used. Example:"
	echo "$0 90"
	exit 1
fi

df -h | grep '^/dev' | cut -d" " -f1 | sort -u | \
	xargs -I{} -P$(nproc) ./disk_space_alert.sh {} $1

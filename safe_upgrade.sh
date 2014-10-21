#!/bin/bash

#
# Script waits for the machine to reach the Internet and performs an
# aptitude update and safe-upgrade in a screen session in case the is
# user interaction required
#
# (I'd not advice to cron this on mission critical systems)
#

# lower priority
(renice 15 $$ || true) > /dev/null
(ionice -c3 -p $$ || true) > /dev/null

# make sure only one instance runs at a time
PIDFILE=/var/lock/$(basename $0)_$(whoami).lock
if [ -e $PIDFILE ]; then
	PID=`cat $PIDFILE`
	if kill -0 &>1 > /dev/null $PID; then
		echo "Already running"
		exit 1
	else
		echo "deleting stale pidfile…"
		rm $PIDFILE
	fi
fi
trap "rm -f ${PIDFILE}; exit" INT TERM EXIT
echo $$ > $PIDFILE

# check dependencies
type ping > /dev/null || exit 1
type aptitude > /dev/null || exit 1
type screen > /dev/null || exit 1
type bash > /dev/null || exit 1

# wait until online
while true; do ping -c1 8.8.8.8 > /dev/null && break; done

CMD=""

for O in update safe-upgrade autoclean
do
	CMD+="/usr/bin/aptitude -y $O;"
done

screen -dmS upgrade bash -xc "$CMD"

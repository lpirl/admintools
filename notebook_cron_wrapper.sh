#!/bin/bash

# The following script can be used to wrap cron jobs, in order to defer
# their execution until the system is on-line and on AC.
#
# Example crontab entry:
# 0 10 * * * ~/notebook_cron_wrapper.sh ~/backup_server.sh 192.168.1.2

PING_REFERENCE=8.8.8.8
PING_TIMEOUT=30
AC_REFERENCE="/sys/class/power_supply/AC/online"
RETRY_TIMEOUT=60

function is_online() {
	ping ${PING_REFERENCE} -c 1 -i .2 -t ${PING_TIMEOUT} > /dev/null 2>&1
	if [ $? -eq 0 ]
	then

		echo 1
	else
		echo 0
	fi
}

function is_on_ac() {
	echo `cat $AC_REFERENCE`
}

while [ $(is_online) -ne 1 ] || [ $(is_on_ac) -ne 1 ]
do
	sleep ${RETRY_TIMEOUT}
done
args="${*:2}"
$1 "${args[@]}"

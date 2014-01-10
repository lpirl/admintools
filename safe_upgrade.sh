#!/bin/bash

#
# Script waits for the machine to reach the Internet and performs an
# aptitude update and safe-upgrade in a screen session in case the is
# user interaction required
#
# (I'd not advice to cron this on mission critical systems)
#

renice 15 $$
ionice -c3 -p $$

while true; do ping -c1 8.8.8.8 > /dev/null && break; done

CMD=""

for O in update safe-upgrade autoclean
do
	CMD+="/usr/bin/aptitude -y $O;"
done

screen -dmS upgrade bash -xc "$CMD"

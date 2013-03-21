#!/bin/bash

# Script passes arguments to the 'vserver' command for every vserver
# in parallel.
#
# You should *not* do this if the requested actions require user
# interaction.
#
# For example, to update all apt's (w/o Super Cow Powers):
# $ ./vserver_all_parallel.sh exec aptitude update

cd `dirname $0`
SERVERS=`./vservers.sh`

for SRV in $SERVERS
do
	CMD="vserver $SRV $@"
	(($CMD | sed "s/^/$SRV: /" ) 2>&1 | sed "s/^/$SRV_err: /") &
done
wait

#!/bin/bash

# Script passes arguments to the 'vserver' command for every vserver.
#
# For example, to get all uptimes, you'd do:
# $ ./vserver_all.sh exec uptime

cd `dirname $0`
SERVERS=`./vservers.sh`

for SRV in $SERVERS
do
	CMD="vserver $SRV $@"
	echo
	echo "###################################"
	echo "# $CMD"
	echo "###################################"
	$CMD
done

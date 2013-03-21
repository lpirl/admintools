#!/bin/bash

# This script shows the IP addresses of all existing vservers.

VSERVERS=`find /etc/vservers -mindepth 1 -maxdepth 1 -type d -name '[^\.]*'`

for VS in $VSERVERS
do
	echo "### $(basename $VS) ###"
	find $VS -type f -name 'ip' -exec cat {} \;
done

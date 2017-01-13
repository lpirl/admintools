#!/bin/bash

# This script for NetworkManager, is intended to turn off/on WiFi when
# the Ethernet interface connects/disconnects.
#
# Create a link to this file in /etc/NetworkManager/dispatcher.d/

MASTER_INTERFACE="eth0"

case "$2" in
	up)
		if [ "$1" = "$MASTER_INTERFACE" ]; then
			nmcli nm wifi off
		fi
		;;

	down)
		if [ "$1" = "$MASTER_INTERFACE" ]; then
			nmcli nm wifi on
		fi
		;;

	pre-up)
		;;

	post-down)
		;;

	*)
		echo $"Usage: $0 {up|down|pre-up|post-down}"
		exit 1
esac

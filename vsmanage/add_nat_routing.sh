#!/bin/bash

# This scripts adds NAT rules to 'iptables' for all vservers.
#
# In addition to the standard configuration files in
# /etc/vservers/<name>/interfaces, this script searches for the files
# /etc/vservers/*/interfaces/*/listenports
# The specified ports will be NATed from outside the server to the
# corresponding vserver.
#
# These files have the following format (per line):
# <transport protocol>:<portnum>
#
# Here is an example for serving DNS and HTTP:
# udp:53
# tcp:80
#
# You probably have to adjust the subnet to match your configuration.
#
# You have to flush the NAT table in beforehand manually
# (iptables -t nat --flush).

echo 1 > /proc/sys/net/ipv4/ip_forward

echo
echo "outbound"
echo "========"
EXTIP=`/sbin/ifconfig eth0 | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}'`
CMD="iptables "
CMD+="-t nat "
CMD+="-A POSTROUTING "
CMD+="-s 10.10.1.1/24 "
CMD+="! -d 10.10.1.1/24 "
CMD+="-j SNAT "
CMD+="--to-source $EXTIP"
echo $CMD
$CMD

echo
echo "inbound"
echo "======="
PORTFILES=`find /etc/vservers -type f -name 'listenports'`
for PORTFILE in $PORTFILES
do
	IP=$(cat "$(dirname $PORTFILE)/ip")
	SUBNET=$(cat "$(dirname $PORTFILE)/prefix")
	SOURCE="$IP/$SUBNET"
	for PORT in $(grep -v "^#" "$PORTFILE")
	do
		PORTPROTO=$(echo $PORT | cut -d: -f1 )
		PORTNUM=$(echo $PORT | cut -d: -f2 )
		CMD="iptables "
		CMD+="-t nat "
		CMD+="-A PREROUTING "
#		CMD+="! -s $SOURCE "
		CMD+="-m $PORTPROTO "
		CMD+="-p $PORTPROTO "
		CMD+="--dport $PORTNUM "
		CMD+="-j DNAT "
		CMD+="--to-destination $IP:$PORTNUM "
		echo "\$ $CMD"
		$CMD
	done
done

echo
echo "All done! New routing table for nat:"
echo "===================================="
iptables -t nat -L

echo
echo "If you see redundant rules, you may use 'iptables -t nat --flush' and re-run the script"

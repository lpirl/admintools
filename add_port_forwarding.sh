#!/bin/bash

# This script add an iptables rule to forward a local port to another
# destination.
#
# Syntax: ./add_port_fowarding.sh <local_port> <remote_ip> <remote_port>

HELP="Syntax: $0 <local_port> <remote_ip> <remote_port>
Example to provide SSH access to 192.168.1.100 locally on port 2200:
$0 2200 192.168.1.100 22"

if ! [[ "$1" =~ ^[0-9]+$ ]] ;
then
	echo "please provide the port to forward as 1st argument."
	echo "$HELP"
	exit 1
fi

if ! [[ "$2" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] ;
then
	echo "please provide the IP address to forward to as 2nd argument."
	echo "$HELP"
	exit 1
fi

if ! [[ "$3" =~ ^[0-9]+$ ]] ;
then
	echo "please the port to forward to as 3rd argument."
	echo "$HELP"
	exit 1
fi

echo 1 > /proc/sys/net/ipv4/ip_forward

EXTIP=`/sbin/ifconfig eth0 | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}'`

echo
echo "outbound"
echo "========"
CMD="iptables "
CMD+="-t nat "
CMD+="-A POSTROUTING "
CMD+="-p tcp "
CMD+="--dport $3 "
CMD+="-j MASQUERADE"
echo $CMD
$CMD

echo
echo "inbound"
echo "======="
CMD="iptables "
CMD+="-t nat "
CMD+="-A PREROUTING "
CMD+="-p tcp "
CMD+="--dport $1 "
CMD+="-j DNAT "
CMD+="--to-destination $2:$3 "
echo $CMD
$CMD

echo
echo "All done! New routing table for nat:"
echo "===================================="
iptables -t nat -L

echo
echo "If you see redundant rules, you may use 'iptables -t nat --flush' and re-run the script"

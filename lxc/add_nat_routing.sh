#!/bin/bash

# This scripts adds IPv4 NAT rules to 'iptables' for all lxc containers.
#
# In addition to the standard configuration file
# /var/lib/lxc/<name>/config, this script searches for the file
# /var/lib/lxc/<name>/listenports
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
# You probably have to adjust the variable GUESTIF to match your
# configuration.
#
# You have to flush the NAT table in beforehand manually
# (iptables -t nat --flush).

#
# <config>
#

GATEWAYIF="lxc-nat-br"

#
# </config>
#

cd $(dirname $0)

EXTIF=`ip route | grep "^default" | cut -d" " -f5`
EXTIP=`ip route | grep -v "^default" | grep eth0 | awk '{print $9}'`

GUEST_SUBNET=`ip route | grep $GATEWAYIF | cut -d" " -f1`

echo 1 > /proc/sys/net/ipv4/ip_forward

echo
echo "outbound"
echo "========"

CMD="iptables "
CMD+="-t nat "
CMD+="-A POSTROUTING  "
CMD+="-s $GUEST_SUBNET "
CMD+="! -d $GUEST_SUBNET "
CMD+="-j SNAT "
CMD+="--to-source $EXTIP"
echo $CMD
$CMD

echo
echo "inbound"
echo "======="
CONFIG_FILES=`./lxc_configs.sh`
for CONFIG_FILE in $CONFIG_FILES
do
	PORTFILE="$(dirname $CONFIG_FILE)/listenports"
	CONTAINER="$(basename $(dirname $CONFIG_FILE))"
	IP=`./lxc_config_value.sh $CONTAINER lxc.network.ipv4 | cut -d/ -f1`
	for PORT in $(grep -v "^#" "$PORTFILE")
	do
		PORTPROTO=$(echo $PORT | cut -d: -f1 )
		PORTNUM=$(echo $PORT | cut -d: -f2 )
		CMD="iptables "
		CMD+="-t nat "
		CMD+="-A PREROUTING "
		CMD+="-m $PORTPROTO "
		CMD+="-p $PORTPROTO "
		CMD+="! -s $GUEST_SUBNET "
		CMD+="--dport $PORTNUM "
		CMD+="-j DNAT "
		CMD+="--to-destination $IP:$PORTNUM "
		echo "\$ $CMD"
		$CMD
	done
done

echo
echo "done."
echo
echo "You can check the routing tables calling:"
echo "	$ iptables -L && iptables -t nat -L"
echo
echo "If you see redundant rules, you can clear the routing tables" \
	"(BE CAREFUL!) via:"
echo "	$ iptables -t nat --flush && iptables --flush"
echo "and re-run this script"

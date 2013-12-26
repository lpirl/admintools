#!/bin/bash

# Helper script that receives a configuration value from a lxc container
# configurations

HELP="Syntax: $0 <name> <configuration key>"

if [[ "$1" = "" ]] ;
then
	echo "please provide the name of the container as 1st argument"
	echo "$HELP"
	exit 1
fi

if [[ "$2" = "" ]] ;
then
	echo "please provide the configuration key 2nd argument"
	echo "$HELP"
	exit 1
fi

cd $(dirname $0)

echo $(egrep "^$2 *=" /var/lib/lxc/$1/config | cut -d= -f2 | tr -cd [:graph:])

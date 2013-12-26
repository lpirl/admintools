#!/bin/bash

# Helper script that receives all values from all lxc container
# configurations for a specific key

HELP="Syntax: $0 <configuration key>"

if [[ "$1" = "" ]] ;
then
	echo "please provide the configuration key you want to receive the values for."
	echo "$HELP"
	exit 1
fi

cd $(dirname $0)

echo $(./lxc_names.sh | xargs -I {} sh -c "./lxc_config_value.sh {} $1")

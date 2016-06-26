#!/bin/bash

# This script outputs the status of the power supply units in case it
# assumes a failure of such.
#
# It is intended to be run regularly by cron, so that it will trigger an
# email being send to the admin accordingly.

type ipmitool > /dev/null || (echo "please install ipmitool"; exit 1)

OUTPUT=`ipmitool sdr type "Power Supply"`

(echo $OUTPUT | egrep -i "fail|lost|error" > /dev/null) && echo "$OUTPUT"

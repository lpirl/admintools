#!/bin/bash

# This script performs an 'aptitude update' and 'aptitude safe-upgade'
# on all vservers.

cd `dirname $0`

echo "################"
echo "# $(hostname)"
echo "################"
aptitude update
aptitude safe-upgrade

./vserver_all_parallel.sh exec aptitude update
./vserver_all.sh exec aptitude safe-upgrade

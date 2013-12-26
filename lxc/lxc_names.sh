#!/bin/bash

# Helper script that lists file system roots of all lxc containers.

cd $(dirname $0)

echo $(find /var/lib/lxc -mindepth 1 -maxdepth 1 -type d -name '[^\.]*' \
    -exec basename {} \;)

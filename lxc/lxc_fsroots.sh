#!/bin/bash

# Helper script that lists file system roots of all lxc containers.

cd $(dirname $0)

echo $(./lxc_config_values.sh lxc.rootfs)

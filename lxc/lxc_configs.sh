#!/bin/bash

# Helper script that lists existing lxc container configurations.

echo $(find /var/lib/lxc -mindepth 2 -maxdepth 2 -name config)

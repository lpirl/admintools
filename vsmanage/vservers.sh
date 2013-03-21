#!/bin/bash

# Helper script that lists existing vservers.

echo $(find /etc/vservers -mindepth 1 -maxdepth 1 -type d -name '[^\.]*' -exec basename {} \;)

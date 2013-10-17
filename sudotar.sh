#!/bin/bash

# This script is wraps the tar command, so that you can read and write
# as different users.
#
# For example, you tar /var/lib as root but write the resulting
# archive to /mnt/net/192.168.1.1/home/someusers as someuser.

cd $(dirname "$0")

if [ $# -lt 5 ]; then
  echo "Syntax : $0 <read user> <write user> <target archive> [<tar arg1> [<tar arg2> […]]]"
  echo  "The tar arguments MUST start with a hyphen and" \
        "MUST NOT include the -f/--file argument."
  exit 1
fi

READ_USER="$1"
WRITE_USER="$2"
OUT_FILE="$3"
TAR_ARGS="${*:4}"

READ_PROMPT="Password for %p@%h for reading as $READ_USER: "
WRITE_PROMPT="Password for %p@%h for writing as $WRITE_USER: "

sudo -u "$READ_USER" -p "$READ_PROMPT" \
    tar -f- $TAR_ARGS | \
sudo -u "$WRITE_USER" -p "$WRITE_PROMPT" \
    tee "$OUT_FILE" > /dev/null

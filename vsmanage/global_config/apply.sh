#!/bin/bash

# This script copies all files in ./fsroot/ to all vservers,
# preserving the path.

cd `dirname $0`
ROOTS=`find /var/lib/vservers -mindepth 1 -maxdepth 1 -type d -name '[^\.]*'`

for FILE in `cd ./fsroot/ && find ./ -not -type d -not -name '.gitkeep'; cd ..`
do
	for VSROOT in $ROOTS
	do
		SOURCE=${FILE:1}
		TARGET="$VSROOT$SOURCE"
		mkdir -p "$(dirname $TARGET)"
		cp -Lv "$SOURCE" "$TARGET"
	done
done

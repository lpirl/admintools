#!/bin/bash

# Script removes empty directories in ./fsroot/

cd `dirname $0`
find ./fsroot -mindepth 1 -depth -type d -empty -exec rmdir {} \;

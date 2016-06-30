#!/bin/bash
dpkg -l 2>/dev/null | grep "^rc" | cut -d " " -f3

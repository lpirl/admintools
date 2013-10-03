#!/usr/bin/env python3
# encoding: utf-8

# Use this script to ensure a certain shell for an user group.

import sys
from grp import getgrnam
from pwd import getpwnam
from subprocess import call
from os.path import isdir

argv = sys.argv
if len(argv) < 3:
	print("Usage: %s <group name> <home>" % argv[0])
	print("In <home>, %u will be expanded to the user name.")
	exit(1)

group_name, home = argv[1:3]

try:
	users = getgrnam(group_name).gr_mem
except KeyError:
	print("ERROR: group '%s' not found" % group_name)
	exit(1)

for user in users:
	user_home = home.replace("%u", user)
	if not isdir(user_home):
		print("WARNING: home directory '%s' for %s does not exist!" % (
			user_home, user))
	pw = getpwnam(user)
	if pw.pw_dir != user_home:
		print("Setting home to '%s' for %s" % (user_home, user))
		call(['usermod', '-d', user_home, user])

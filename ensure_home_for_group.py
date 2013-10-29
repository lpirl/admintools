#!/usr/bin/env python3
# encoding: utf-8

# This script ensures that a home directory is set for an user group.

import sys
from grp import getgrnam
from pwd import getpwnam, getpwall
from subprocess import call
from os.path import isdir

argv = sys.argv
if len(argv) < 3:
	print("Usage: %s <group name> <home>" % argv[0])
	print("In <home>, %u will be expanded to the user name.")
	exit(1)

group_name, home = argv[1:3]

try:
	group = getgrnam(group_name)
except KeyError:
	print("ERROR: group '%s' not found" % group_name)
	exit(1)

group_users = group.gr_mem
primary_group_users = [u.pw_name for u in getpwall()
							if u.pw_gid == group.gr_gid]
users = group_users + primary_group_users

for user in users:
	user_home = home.replace("%u", user)
	if not isdir(user_home):
		print("WARNING: home directory '%s' for %s does not exist!" % (
			user_home, user))
	pw = getpwnam(user)
	if pw.pw_dir != user_home:
		print("Setting home to '%s' for %s" % (user_home, user))
		call(['usermod', '-d', user_home, user])

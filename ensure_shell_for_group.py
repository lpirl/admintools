#!/usr/bin/env python3
# encoding: utf-8

# Use this script to ensure a certain shell for an user group.

import sys, grp, pwd
from subprocess import call
from os import access, X_OK
from os.path import isfile

argv = sys.argv
if len(argv) < 3:
	print("Usage: %s <group name> <shell>" % argv[0])
	exit(1)

group_name, shell = argv[1:3]

try:
	users = grp.getgrnam(group_name).gr_mem
except KeyError:
	print("ERROR: group '%s' not found" % group_name)
	exit(1)

if not isfile(shell) or not access(shell, X_OK):
	print("ERROR: this is not a valid shell: %s" % shell)
	exit(1)

for user in users:
	pw = pwd.getpwnam(user)
	if pw.pw_shell != shell:
		print("Setting shell to '%s' for %s" % (shell, user))
		call(['chsh', '-s', shell, user])

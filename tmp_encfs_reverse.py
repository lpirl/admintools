#!/usr/bin/env python3

"""
Mounts directories into a common temporary directory using
`encfs --reverse`.

This can e.g. be useful to sync parts of a file system to a remote site
encrypted.
"""

import sys
import argparse
import logging
from subprocess import check_call, DEVNULL, Popen, PIPE
from tempfile import mkdtemp
import os
from os.path import isdir, basename, dirname, join as path_join, sep

if __name__ != '__main__':
  raise NotImplementedError(
    "Sorry, there is nothing to include - this is a CLI tool."
  )

parser = argparse.ArgumentParser(description=__doc__)

parser.add_argument('-d', '--debug', action='store_true', default=False,
                    help='turn on debug messages')
parser.add_argument('encfs_conf', help='ENCFS XML configuration file',
                    nargs="?")
parser.add_argument('-p', '--encfs_password_file',
                    help='a file containing the ENCFS password ' +
                         '(only the first line will be read)')
parser.add_argument('paths_file', nargs="?",
                    help='a file containing paths to mount encrypted ' +
                         '(one per line, # comments allowed)')
parser.add_argument('-u', '--umount', type=str,
                    help='formerly returned path to unmount ' +
                         '(conflicts with most options)')


# display help per default
args = parser.parse_args()

# set up logger
logging.getLogger().name = ""
if args.debug:
  logging.getLogger().setLevel(logging.DEBUG)

#
# umount
#
if args.umount:

  if args.encfs_conf or args.encfs_password_file or args.paths_file:
    parser.error("-u/--umount needs to be the only argument (except debug)")

  def umount_and_rmdir(path):
    logging.debug("unmounting and deleting '%s'", path)
    check_call(["umount", path])
    os.rmdir(path)

  encfs_umount_path = args.umount.rstrip(sep)
  umount_and_rmdir(encfs_umount_path)

  basepath = dirname(encfs_umount_path)

  plain_umount_basedir = path_join(basepath, 'plain')
  for basedirname, subdirnames, _ in os.walk(plain_umount_basedir):
    for subdirname in subdirnames:
      umount_and_rmdir(path_join(basedirname, subdirname))

  for path in (plain_umount_basedir, basepath):
    logging.debug("removing '%s'", path)
    os.rmdir(path)

  exit(0)

else:
  if not (args.encfs_conf and args.paths_file):
    parser.error("when not unmounting, <encfs_conf> and <paths_file> " +
                 "are required")

#
# read paths to mount
#

to_mount = {}
with open(args.paths_file) as paths_file:
  for line in paths_file:
    line = line.strip()
    line = line.rstrip(sep)
    logging.debug("processing line '%s'", line)
    if line.startswith("#"):
      continue
    if not line:
      continue
    if not isdir(line):
      raise IOError("'%s': no such directory" % line)
    dir_basename = basename(line)
    if dir_basename in to_mount:
      raise RuntimeError("Sorry, multiple directories with the same name" +
                         ("(%s) are not supported at " % dir_basename) +
                         "at the moment")
    to_mount[dir_basename] = line
logging.debug("Planned mounts are %s", to_mount)

#
# bind mount
#

basepath = mkdtemp(prefix="%s-" % basename(sys.argv[0]))
logging.debug("temp dir is '%s'", basepath)

plain_basepath = path_join(basepath, "plain")
os.mkdir(plain_basepath)


for dir_basename, from_path in to_mount.items():
  to_path = path_join(plain_basepath, dir_basename)
  os.mkdir(to_path)
  mount_args = ("mount", "-o", "bind", from_path, to_path)
  logging.debug("running `%s`", " ".join(mount_args))
  check_call(mount_args)


#
# encfs mount
#

encfs_basepath = path_join(basepath, "encfs")
os.mkdir(encfs_basepath)

encfs_args = ["encfs", "--reverse",]
encfs_stdin = DEVNULL

password = None
if args.encfs_password_file:
  encfs_stdin = PIPE
  with open(args.encfs_password_file) as encfs_password_file:
    password = encfs_password_file.readline().strip()
  encfs_args.append("--stdinpass")

encfs_args.extend((plain_basepath, encfs_basepath))

logging.debug("setting ENCFS6_CONFIG to %s", args.encfs_conf)
os.environ['ENCFS6_CONFIG'] = args.encfs_conf

logging.debug("invoking `%s`" % " ".join(encfs_args))
enfs_process = Popen(encfs_args, stdin=encfs_stdin)

if args.encfs_password_file:
  logging.debug("piping password into encfs")
  enfs_process.communicate(password.encode("utf-8"))

#
# all done
#
print(encfs_basepath)

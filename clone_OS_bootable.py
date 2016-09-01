#!/usr/bin/env python3

"""
This scripts is intended to regularly create a bootalbe backup of the
operating system.

A reasonably sized USB-key will do the job too. This way, you can do a
relatively fast, manual failover in case your boot medium fails.

         #          The backup MUST reside on a separate device
        # #         (partition is not enough)
       #   #        since we have to update Grub.
      #  #  #
     #   #   #
    #    #    #
   #           #
  #      #      #
 #               #
# # # # # # # # # #

Put a call to this script in your crontab to create backups regularly,
(But remember: flash drives wear out earlier the more being written on).
"""

import sys
import argparse
from logging import DEBUG, INFO, ERROR, getLogger, info, debug, error
from os import rmdir, sync
from os.path import basename, dirname, join, isdir
from subprocess import (run as subprocess_run, DEVNULL, PIPE,
                        CalledProcessError)
from tempfile import mkdtemp, _get_candidate_names
from re import sub, search
from fileinput import FileInput

RSYNC_OPTS = (
  "--archive",
  "--verbose",
  "--delete-during",
  "--one-file-system",
  "--inplace",
  "--exclude=/proc/*",
  "--exclude=/dev/*",
  "--exclude=/tmp/*",
  "--exclude=/sys/*",
  "--exclude=/run/*",
  "--exclude=/home/*",
  "--exclude=/var/cache/*",
  "--exclude=/var/lock/*",
  "--exclude=/var/log/*",
  "--exclude=/var/mail/*",
  "--exclude=/var/spool/*",
)

CHROOT_BINDS = (
  "proc",
  "sys",
  "dev",
)

PARTITION_NUMBER_PATTERN = r'[0-9]+$'

class Cleaner(object):

  def __init__(self):
    self._jobs = []

  def add_job(self, func, *args, **kwargs):
    self._jobs.append((func, args, kwargs))

  def do_jobs(self):
    # in reverse order:
    while self._jobs:
      func, args, kwargs = self._jobs.pop()
      debug("cleanup: func=%s.%s, args=%r, kwargs=%r", func.__module__,
           func.__name__, args, kwargs)
      func(*args, **kwargs)

def run(call_args, *args, **kwargs):

  # enforce non-zero exit codes to raise an exception
  kwargs["check"] = True

  if getLogger().level <= DEBUG:
    kwargs.setdefault("stdout", sys.stdout)
    kwargs.setdefault("stderr", sys.stderr)
  else:
    kwargs.setdefault("stdout", DEVNULL)
    kwargs.setdefault("stderr", DEVNULL)

  # subprocess.Popen needs an indexable type as 1st arg
  # try to convert to tuple if required
  if not hasattr(call_args, "__getitem__"):
    call_args = tuple(call_args)

  debug("running with args: %s and kwargs: %s:", args, kwargs)
  debug("$ %s", ' '.join(call_args))

  return subprocess_run(call_args, *args, **kwargs)

  raise ProgrammingError("We should never get here.")

def dirs_differ(a, b):
  if isdir(a) != isdir(b):
    return True
  try:
    run(("diff", "-qr", a, b))
  except CalledProcessError as diff_exception:
    if diff_exception.returncode == 1:
      return True
    raise diff_exception
  return False

def grub_is_installed(device_path):
  try:
    run(
      (
        " | ".join((
          "sudo dd if='%s' bs=512 count=1 2>/dev/null" % device_path,
          "strings",
          "grep -q GRUB"
        )),
      ),
      shell=True
    )
  except CalledProcessError as exception:
    if exception.returncode == 1:
      return False
    else:
      raise exception
  return True

def get_device_by_mount_point(mount_point):
  df_result = run(
    (
      " | ".join((
        "df --no-sync --output=source '%s'" % mount_point,
        "grep /dev/"
      )),
    ),
    shell=True, stdout=PIPE
  )
  device = df_result.stdout.decode().strip()
  assert device.startswith("/dev/")
  return device

def get_partition_number_by_device(device_path):
  partition_number_match = search(PARTITION_NUMBER_PATTERN,
                                       device_path)
  assert bool(partition_number_match) is True
  partition_number = partition_number_match.group(0)
  assert partition_number.isdecimal()
  return partition_number

def get_device_by_partition(partition_device_path):
  device = sub(PARTITION_NUMBER_PATTERN, '', partition_device_path)
  assert device.startswith("/dev/")
  return device

def get_uuid_by_partition(partition_device_path):
  lsblk_result = run(
    ("lsblk", "--noheadings", "--output", "UUID", partition_device_path),
    stdout=PIPE
  )
  uuid = lsblk_result.stdout.decode().strip()
  assert len(uuid) == 36
  return uuid

def _main(cleaner):
  parser = argparse.ArgumentParser(
    description="Creates a bootable copy of the current file system root (/)."
  )

  parser.add_argument('-d', '--debug', action='store_true', default=False,
                      help='turn on debug messages')
  parser.add_argument('-v', '--verbose', action='store_true', default=False,
                      help='turn on verbose messages')
  parser.add_argument('-q', '--quiet', action='store_true', default=False,
                      help='suppress everything except errors')
  parser.add_argument('-m', '--mount_option', action='append',
                      dest="mount_options",
                      help='options for mounting file system to backup to')
  parser.add_argument('-r', '--rsync_option', action='append',
                      dest="rsync_options",
                      help='options to pass to rsync for copying files')
  parser.add_argument('-i', '--include', action='append',
                      help='paths to include in backup (see man 1 rsync)')
  parser.add_argument('-e', '--exclude', action='append',
                      help='paths to exclude from backup (see man 1 rsync)')
  parser.add_argument('dest_uuid',
                      help='UUID of the file system to backup to')

  cli_args = parser.parse_args()

  getLogger().name = ""
  if cli_args.debug:
    getLogger().setLevel(DEBUG)
  if cli_args.verbose:
    getLogger().setLevel(INFO)
  if cli_args.quiet:
    getLogger().setLevel(ERROR)
  debug("logging set up")

  # last job (i.e. first job submitted) is always to sync disks
  cleaner.add_job(sync)

  tempfile_delim = "__"
  tempfile_prefix = basename(sys.argv[0]) + tempfile_delim

  src_base_dir = "/"

  debug("determining source partition")
  src_partition = get_device_by_mount_point(src_base_dir)
  src_uuid = get_uuid_by_partition(src_partition)
  info("source partition: %s (%s)", src_partition, src_uuid)

  debug("creating temporary directory as mount point for target file system")
  dest_base_dir = mkdtemp(prefix=tempfile_prefix,
                          suffix=tempfile_delim + "mount")
  cleaner.add_job(rmdir, dest_base_dir)

  info("mounting target file system to: '%s'", dest_base_dir)
  mount_args = ["mount"]
  if hasattr(cli_args, "mount_options"):
    mount_args.append("-o")
    mount_args.append(','.join(cli_args.mount_options))
  mount_args.append("UUID=%s" % cli_args.dest_uuid)
  mount_args.append(dest_base_dir)
  mount_exit_code = run(mount_args)
  cleaner.add_job(run, ("umount", "--lazy", dest_base_dir))

  # shortcuts to get src/dest directory paths
  src_path = lambda sub: join(src_base_dir, sub)
  dest_path = lambda sub: join(dest_base_dir, sub)

  debug("determining target partition and device")
  dest_partition = get_device_by_mount_point(dest_base_dir)
  dest_partition_number = get_partition_number_by_device(dest_partition)
  dest_device = get_device_by_partition(dest_partition)
  info("target partition/device: %s on %s", dest_partition, dest_device)

  debug("checking whether grub needs to be updated")
  update_grub = dirs_differ(src_path("boot"), dest_path("boot"))
  info("Grub needs to be updated: %r", update_grub)

  info("copying contents of '%s' to '%s'", src_base_dir, dest_base_dir)
  # join with empty last part -> path ends with a separator
  run(("rsync",) + RSYNC_OPTS + (join(src_base_dir, ""), dest_base_dir))

  debug("mounting %s to target root", CHROOT_BINDS)
  for bind in CHROOT_BINDS:
    run(("mount", "--bind", src_path(bind), dest_path(bind)))
    cleaner.add_job(run, ("umount", "--lazy", dest_path(bind)))

  chroot_run = lambda args: run(("chroot", dest_base_dir) + args)

  info("update fstab in target file system")
  debug("replacing any: '%s' with '%s'", src_partition, dest_partition)
  debug("replacing any: '%s' with '%s'", src_uuid, cli_args.dest_uuid)
  with FileInput(dest_path("etc/fstab"), inplace=True) as fstab_fp:
    for line in fstab_fp:
      line = line.replace(src_partition, dest_partition)
      line = line.replace(src_uuid, cli_args.dest_uuid)
      sys.stdout.write(line)
      # TODO: add nofail
      # TODO: warn if nothing replaced

  debug("check bootable flag on partition %s", dest_partition)
  sfdisk_result= run(("sfdisk",  "--activate", dest_device), stdout=PIPE)
  dest_partition_set_bootable = dest_partition in sfdisk_result.stdout.decode()

  if not dest_partition_set_bootable:
    info("set bootable flag on partition %s", dest_partition)
    run(("sfdisk",  "--activate", dest_device, dest_partition_number))

  if update_grub:
    info("update Grub configuration in target file system")
    chroot_run(("update-grub",))

  if not grub_is_installed(dest_device):
    info("installing Grub on %s", dest_device)
    chroot_run(("grub-install", dest_device))
  else:
    info("Grub already installed on %s", dest_device)

if __name__ == '__main__':

  cleaner = Cleaner()
  abnormal_termination = False
  try:
    _main(cleaner)
  except Exception as exception:
    error("abnormal termination (see error at end of output)")
    abnormal_termination = True
    raise exception
  finally:
    info("running cleanup jobs")
    cleaner.do_jobs()

  if abnormal_termination:
    exit(1)
  else:
    info("success - please verify your backup (!)")

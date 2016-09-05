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
from os import rmdir, sync, umask, remove
from os.path import basename, dirname, join, isdir
from subprocess import (run as subprocess_run, DEVNULL, PIPE,
                        CalledProcessError)
from tempfile import mkstemp, mkdtemp, _get_candidate_names
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
CRYPTSETUP_PATH_TEMPLATE = "/dev/mapper/%s"
DEVICE_BY_PATH_TEMPLATE = "/dev/disk/by-uuid/%s"

TEMPFILE_DELIM = "__"
TEMPFILE_PREFIX = basename(sys.argv[0]) + TEMPFILE_DELIM

class Cleaner(object):

  def __init__(self):
    self._jobs = []

  def add_job(self, func, *args, **kwargs):
    self._jobs.append((func, args, kwargs))

  def do_all_jobs(self):
    while self._jobs:
      self.do_one_job()

  def do_one_job(self):
    # in reverse order:
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

  debug("running '%s' with args: %s and kwargs: %s:",
        " ".join(call_args), args, kwargs)

  return subprocess_run(call_args, *args, **kwargs)

def dirs_differ(dir_a, dir_b):
  if isdir(dir_a) != isdir(dir_b):
    return True
  try:
    run(("diff", "-qr", dir_a, dir_b))
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

class FileSystem(object):
  """
  Provides all required information about a file system (see assert
  statements at the end of __init__) and does everything to get them.
  """

  @staticmethod
  def get_partition_by_uuid(uuid):
    lsblk_result = run(("blkid", "-U", uuid),
                       stdout=PIPE)
    partition = lsblk_result.stdout.decode().strip()
    assert partition.startswith("/dev/")
    return partition

  @staticmethod
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

  @staticmethod
  def get_uuid_by_device(partition_device_path):
    lsblk_result = run(
      ("blkid", "-o", "value", "-s", "UUID", partition_device_path),
      stdout=PIPE
    )
    uuid = lsblk_result.stdout.decode().strip()
    assert len(uuid) == 36
    return uuid

  def __init__(self, cleaner, mountpoint=None, uuid=None,
                     mount_options=None, password=None, password_file=None):

    if (mountpoint and uuid) or (not mountpoint and not uuid):
      ArgumentError("Either `mountpoint` or `uuid` is required.")

    self.cleaner = cleaner
    self.mount_options = mount_options

    # set device path _and_ uuid from mountpoint _xor_ uuid:
    if mountpoint:
      self.mountpoint = mountpoint
      debug("loading file system: %s", self.mountpoint)
      self.partition_device_path = self.get_device_by_mount_point(
        self.mountpoint
      )
      self.uuid_on_partition = self.get_uuid_by_device(
        self.partition_device_path
      )
    elif uuid:
      self.uuid_on_partition = uuid
      debug("loading file system information for UUID: %s", uuid)
      self.partition_device_path = self.get_partition_by_uuid(uuid)

    debug("device is: %s", self.partition_device_path)
    debug("UUID is: %s", self.uuid_on_partition)

    if self.is_luks():
      debug("partition is LUKS encrypted")
      self._init_password_file(password, password_file)
      self.filesystem_device_path = (CRYPTSETUP_PATH_TEMPLATE %
                                     self.uuid_on_partition)
      self._luks_open()
      debug("actual device for file system is: %s",
            self.filesystem_device_path)
      self.filesystem_uuid = self.get_uuid_by_device(
        self.filesystem_device_path
      )
      debug("actual file system UUID is: %s", self.filesystem_uuid)
    else:
      debug("partition is not LUKS encrypted")
      if password or password_file:
        error("You specified a LUKS password but the target does "
              "not seem to be a LUKS encrypted partition!?")
        exit(2)
      self.filesystem_device_path = self.partition_device_path
      self.filesystem_uuid = self.uuid_on_partition

    if not mountpoint:
      self._mount()

    # at the end of the day, this is what we need in any case:
    #   (at least to generate attributes we need in any case)
    #   (assuming "context aware" asserts happened earlier)
    assert self.partition_device_path
    assert self.uuid_on_partition
    assert self.filesystem_device_path
    assert self.filesystem_uuid
    assert self.mountpoint

  def _init_password_file(self, password, password_file):
    if password_file:
      self.password_file = password_file
      return
    if not password:
      error("Please specify either a password or a password file!")
      exit(4)
    self.cleaner.add_job(umask, umask(0o177))
    self.password_file = mkstemp(prefix=TEMPFILE_PREFIX,
                                 suffix=TEMPFILE_DELIM + "password")[1]
    # restore the system's default umask right away:
    self.cleaner.do_one_job()
    self.cleaner.add_job(remove, self.password_file)
    debug("writing password temporarily to '%s'", self.password_file)
    with open(self.password_file, "w") as password_filep:
      password_filep.write(password)

  def is_luks(self):
    result = run(("file", "-ELs", self.partition_device_path),
                 stdout=PIPE)
    return "LUKS encrypted" in result.stdout.decode().strip()

  def _luks_open(self):
    debug("opening LUKS")
    try:
      run(("cryptsetup", "luksOpen", "--key-file", self.password_file,
           self.partition_device_path, self.uuid_on_partition))
    except CalledProcessError as cryptsetup_exception:
      if cryptsetup_exception.returncode == 2:
        error("could not open LUKS device: wrong passphrase")
        exit(3)
      raise cryptsetup_exception
    else:
      self.cleaner.add_job(
        run, ("cryptsetup", "luksClose", self.uuid_on_partition)
      )

  def _mount(self):

    debug("creating temporary directory to mount: %s", self.filesystem_uuid)
    self.mountpoint = mkdtemp(prefix=TEMPFILE_PREFIX,
                              suffix=TEMPFILE_DELIM + "mount")
    self.cleaner.add_job(rmdir, self.mountpoint)
    info("mounting '%s' to '%s'", self.filesystem_uuid, self.mountpoint)
    mount_args = ["mount"]
    if self.mount_options:
      mount_args.append("-o")
      mount_args.append(','.join(self.mount_options))
    mount_args.append("UUID=%s" % self.filesystem_uuid)
    mount_args.append(self.mountpoint)
    mount_exit_code = run(mount_args)
    self.cleaner.add_job(run, ("umount", "--lazy", self.mountpoint))

  def path(self, *bits):
    """
    Return path relative to mountpoint
    """
    return join(self.mountpoint, *bits)

  @property
  def partition_number(self):
    partition_number_match = search(PARTITION_NUMBER_PATTERN,
                                         self.partition_device_path)
    assert bool(partition_number_match) is True
    partition_number = partition_number_match.group(0)
    assert partition_number.isdecimal()
    debug("partition number is: %s", partition_number)
    return partition_number

  @property
  def device_path(self):
    device = sub(PARTITION_NUMBER_PATTERN, '', self.partition_device_path)
    assert device.startswith("/dev/")
    return device

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
  password_group = parser.add_mutually_exclusive_group()
  password_group.add_argument('-p', '--password', help=('password for '
                              'decryption if the UUID points to a LUKS '
                              'encrypted partition'))
  password_group.add_argument('-f', '--password-file', help=('file '
                              'containing a LUKS password as first line '
                              '(see -p)'))
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

  src_fs = FileSystem(cleaner, mountpoint="/")
  dest_fs = FileSystem(cleaner, uuid=cli_args.dest_uuid,
                       password=cli_args.password,
                       password_file=cli_args.password_file,
                       mount_options=cli_args.mount_options)

  debug("checking whether grub needs to be updated")
  update_grub = dirs_differ(src_fs.path("boot"), dest_fs.path("boot"))
  info("Grub needs to be updated: %r", update_grub)

  info("copying contents of '%s' to '%s'",
       src_fs.mountpoint, dest_fs.mountpoint)
  # …path("") -> path ends with a separator
  run(("echo", "rsync",) + RSYNC_OPTS +
      (src_fs.path(""), dest_fs.mountpoint))

  debug("mounting %s to target root", CHROOT_BINDS)
  for bind in CHROOT_BINDS:
    run(("mount", "--bind", src_fs.path(bind), dest_fs.path(bind)))
    cleaner.add_job(run, ("umount", "--lazy", dest_fs.path(bind)))

  chroot_run = lambda args: run(("chroot", dest_fs.mountpoint) + args)

  info("update fstab in target file system")
  debug("replacing any: '%s' with '%s'",
        src_fs.filesystem_device_path, dest_fs.filesystem_device_path)
  debug("replacing any: '%s' with '%s'",
        src_fs.filesystem_uuid, dest_fs.filesystem_uuid)
  with FileInput(dest_fs.path("etc/fstab"), inplace=True) as fstab_fp:
    for line in fstab_fp:
      line = line.replace(
        src_fs.filesystem_device_path, dest_fs.filesystem_device_path
      )
      line = line.replace(
        src_fs.filesystem_uuid, dest_fs.filesystem_uuid
      )
      sys.stdout.write(line)
      # TODO: add nofail
      # TODO: warn if nothing replaced

  debug("check bootable flag on partition %s",
        dest_fs.partition_device_path)
  sfdisk_result= run(("sfdisk", "--activate", dest_fs.device_path),
                     stdout=PIPE)
  if dest_fs.partition_device_path not in sfdisk_result.stdout.decode():
    info("set bootable flag on partition %s",
         dest_fs.partition_device_path)
    run(("sfdisk",  "--activate", dest_fs.device_path,
         dest_fs.partition_number))

  if update_grub:
    info("update Grub configuration in target file system")
    chroot_run(("update-grub",))

  if not grub_is_installed(dest_fs.device_path):
    info("installing Grub on %s", dest_fs.device_path)
    chroot_run(("grub-install", dest_fs.device_path))
  else:
    info("Grub already installed on %s", dest_fs.device_path)

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
    cleaner.do_all_jobs()

  if abnormal_termination:
    exit(1)
  else:
    info("success - please verify your backup (!)")

#!/usr/bin/env python3

"""
This script is intended for desktop Linux, to temporarily configure
them for real-time applications (such as audio applications).
"""

import argparse
import logging
from sys import argv
from abc import ABCMeta
from os import getuid, uname as get_uname, path
from shutil import which
from subprocess import call, check_output

if __name__ != '__main__':
  raise NotImplementedError(
    "This is module should be called directly from command line."
  )

parser = argparse.ArgumentParser(
  description="""Configures your Linux for real-time applications.

This is currently tested for recent Debian and Fedora systems.
""",
  formatter_class=argparse.ArgumentDefaultsHelpFormatter
)

parser.add_argument('-d', '--debug', action='store_true', default=False,
                    help='Turn on debug messages?')
parser.add_argument('-v', '--verbose', action='store_true', default=False,
                    help='Turn on verbose messages?')

parser.add_argument('-s', '--simulate', action='store_true',
                    default=False,
                    help='Simulate and just print actions?')

parser.add_argument('on_or_off', choices = ['on', 'off'],
                    help='Activate or deactivate.')

cli_args = parser.parse_args()

# set up logger
logging.getLogger().name = ""
if cli_args.debug:
  logging.getLogger().setLevel(logging.DEBUG)
if cli_args.verbose:
  logging.getLogger().setLevel(logging.INFO)

actions = []

#
# action definitions
#

class ActionBase(metaclass=ABCMeta):

  def activate(self):
    pass

  def deactivate(self):
    pass

  def execute_safely(self, function, *args, **kwargs):
    """
    Method prints what would be done if simulating or
    does it otherwise.
    """
    def as_pretty_string():
      return "%s.%s(%s, %s)" % (
        function.__module__,
        function.__name__,
        ', '.join((repr(arg) for arg in args)),
        ', '.join(( "%s=%s" % (repr(k), repr(v))
              for k, v in kwargs.items())),
      )

    if cli_args.simulate:
      print("simulating - would execute: %s" % (
        as_pretty_string()
      ))
      return
    else:
      logging.debug("executing " + as_pretty_string())
      return function(*args, **kwargs)

  def service(self, name, action):

    if not hasattr(ActionBase, "_available_services_cache"):
      ActionBase._available_services_cache = []
      output = check_output(("systemctl", "list-unit-files"),
                            universal_newlines=True)
      for line in output.split("\n")[1:-3]:
        service_name = path.splitext(line.split(" ")[0])[0]
        if service_name != "":
          ActionBase._available_services_cache.append(service_name)
      logging.debug("found services %r" %
                    ActionBase._available_services_cache)

    if name not in ActionBase._available_services_cache:
      logging.info("service '%s' does not seem to exist" % name)
      return

    self.execute_safely(call, (which("systemctl"), action, name))

  def service_start(self, name):
    self.service(name, "start")

  def service_stop(self, name):
    self.service(name, "stop")

class CheckForRealTimeKernel(ActionBase):

  def activate(self):

    SYS_RT_FILE = "/sys/kernel/realtime"
    if path.isfile(SYS_RT_FILE):
      with open(SYS_RT_FILE) as sys_rt:
        if sys_rt.readline() == "1":
          logging.debug("found %s with '1' in it" % SYS_RT_FILE)
          return

    uname = get_uname()
    if uname.release.endswith("+rt"):
      logging.debug("found +rt in kernel release")
      return
    if " RT " in uname.version:
      logging.debug("found RT in kernel version")
      return
    if " PREEMPT " in uname.version:
      logging.debug("found PREEMT in kernel version")
      return

    logging.error("You don't seem to be using a real-time kernel.")
actions.append(CheckForRealTimeKernel)

class Cron(ActionBase):
  def activate(self):
    self.service_stop("cron")
    self.service_stop("crond")
  def deactivate(self):
    self.service_start("cron")
    self.service_start("crond")
actions.append(Cron)

class Tlp(ActionBase):
  def activate(self):
    self.service_stop("tlp")
  def deactivate(self):
    self.service_start("tlp")
actions.append(Tlp)

#
# execution of actions
#

if getuid():
  logging.warn("You'll probably have to run this as root (sudo) "
               "but I'll continue and try.")

if cli_args.on_or_off == "on":
  for Action in actions:
    logging.info("activating %s" % Action.__name__)
    Action().activate()
else:
  for Action in actions:
    logging.info("deactivating %s" % Action.__name__)
    Action().deactivate()

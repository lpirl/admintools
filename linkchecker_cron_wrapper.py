#!/usr/bin/env python3

"""
This wrapper around linkchecker suppresses all output except erroneous
links found.

Additionally some verbosity is removed from the output.
"""

import sys
from subprocess import check_output, DEVNULL, CalledProcessError

args = list(sys.argv)
args[0] = "linkchecker"

try:
  check_output(
    args,
    universal_newlines=True,
    stdin=sys.stdin,
    stderr=DEVNULL,
  )
except CalledProcessError as e:
  lines = e.output.splitlines()
  printing = False
  for line in lines:
    if line.startswith("Start checking "):
      printing = True
      print("Erroneous links found:")
      continue
    if line.startswith("Statistics:"):
      break
    if not printing:
      continue
    print(line)

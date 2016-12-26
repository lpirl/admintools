#!/usr/bin/env python3

"""
This is a template for simple Python 3 CLI applications.
(Replace this with your description)
"""

import argparse
from logging import getLogger, DEBUG, INFO, debug, info
from subprocess import check_output

if __name__ != '__main__':
  raise NotImplementedError(
    "Sorry, there is nothing to include - this is a CLI tool."
  )

parser = argparse.ArgumentParser(
  description=__doc__,
  formatter_class=argparse.ArgumentDefaultsHelpFormatter
)

parser.add_argument('-d', '--debug', action='store_true', default=False,
                    help='turn on debug messages')
parser.add_argument('-v', '--verbose', action='store_true', default=False,
                    help='turn on verbose messages')
# argument taking a list:
#parser.add_argument('-i', '--ignore', nargs='*', default=[],
#                    help='list of settings modules to ignore')
# argument taking a list:
#parser.add_argument('on_or_off', choices = ['on', 'off'], nargs='?',
#                    help='activate or deactivate')

args = parser.parse_args()

# set up logger
logger = getLogger()
logger.name = ""
if args.debug:
  logger.setLevel(DEBUG)
if args.verbose:
  logger.setLevel(INFO)


output = check_output(("echo", "Hello World"), universal_newlines=True)
print(output.strip())

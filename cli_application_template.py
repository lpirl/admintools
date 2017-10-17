#!/usr/bin/env python3

"""
This is a template for simple Python 3 CLI applications.
Replace this with your description.
"""

import argparse
from logging import getLogger, DEBUG, INFO, debug, info
from subprocess import check_output



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



def main():
  cleaner = Cleaner()
  abnormal_termination = False
  try:
    caught_main(cleaner)
  except Exception as exception:
    error("abnormal termination (see error at end of output)")
    abnormal_termination = True
    raise exception
  finally:
    debug("running cleanup jobs")
    cleaner.do_all_jobs()

  if abnormal_termination:
    exit(1)
  else:
    debug("success - bye")



def caught_main(cleaner):

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
  #parser.add_argument('on_or_off', choices=('on', 'off'), nargs='?',
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

if __name__ == '__main__':
  main()

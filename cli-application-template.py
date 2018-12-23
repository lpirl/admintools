#!/bin/sh
''':'
exec python3 -OO "$0" "$@"
'''
# The above is a little hack to use arguments in the shebang.

__doc__ = """
This is a template for simple Python 3 CLI applications.
Replace this with your description.
"""

import argparse
from logging import getLogger, DEBUG, INFO, debug, info, error
from subprocess import check_output



class Cleaner:
  '''
  A sort of a job queue that holds jobs which should be run (in order)
  before the program exits.
  '''

  def __init__(self):
    ''' initializes instance variables '''
    self._jobs = []

  def add_job(self, func, *args, **kwargs):
    ''' add a job to the queue '''
    self._jobs.append((func, args, kwargs))

  def do_all_jobs(self):
    ''' do (and remove) all the jobs in (from) the queue '''
    while self._jobs:
      self.do_one_job()

  def do_one_job(self):
    ''' do and remove one job from the queue '''
    # in reverse order:
    func, args, kwargs = self._jobs.pop()
    debug("cleanup: func=%s.%s, args=%r, kwargs=%r", func.__module__,
          func.__name__, args, kwargs)
    func(*args, **kwargs)



def caught_main(cleaner):
  '''
  Actual main procedure.

  Uncaught exceptions will be handled in calling procedure.
  '''

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
  if args.verbose:
    logger.setLevel(INFO)
  if args.debug:
    logger.setLevel(DEBUG)


  output = check_output(("echo", "Hello World"), universal_newlines=True)
  print(output.strip())



def main():
  '''
  Wrapper around actual main procedure.

  Will hold back uncaught exceptions of the (actual) main procedure,
  will run clean up jobs, and will raise the held exception afterwards.
  '''

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



if __name__ == '__main__':
  main()

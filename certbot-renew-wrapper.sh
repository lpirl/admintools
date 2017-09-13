#!/bin/bash

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

for p in apache2 nginx; do type $p > /dev/null 2>&1 && service $p stop; done

# Sep 17: temporarily ignore Python's DependencyWarning since it
# currently causes an email every time this script is called as Cron
# job on Debian 9.1 with certbot from sid
timeout -s KILL 30m \
  certbot --standalone --quiet renew 2>&1 \
  | grep -v DependencyWarning

exit_code=$?

# also concerning the note from Sep 17 above:
# since grep does not match a line upon successful execution (certbot is
# quiet), we have to ignore exit code 1. However, if an error occurs,
# grep matches a line and exits with code zero, so we have to make that
# an error.
exit_code=$((exit_code-1))

for p in apache2 nginx; do type $p > /dev/null 2>&1 && service $p start; done

exit $exit_code

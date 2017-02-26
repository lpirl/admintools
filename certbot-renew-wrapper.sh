#!/bin/bash

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

for p in apache2 nginx; do type $p > /dev/null 2>&1 && service $p stop; done

timeout -s KILL 30m certbot --standalone --quiet renew
exit_code=$?

for p in apache2 nginx; do type $p > /dev/null 2>&1 && service $p start; done

exit $exit_code

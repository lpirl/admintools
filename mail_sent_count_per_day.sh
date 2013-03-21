#/bin/bash

# This script prints the number of mails that were sent per day.
#
# Therefore, it requires to read the logs created by the Postfix MTA.

LOGDIR="/var/log/"
LOGFILES="mail.log*"

SENTS=$(find "$LOGDIR" -iname "$LOGFILES" | xargs -I% sh -c 'zcat % || cat %' | grep sent | grep -v "relay=local")

DATES=$(echo "$SENTS" | cut -c1-6 | sort -u)

echo "$DATES" | while read DATE; do
	echo -n "${DATE}: "
	echo "$SENTS" | grep -c "$DATE"
done

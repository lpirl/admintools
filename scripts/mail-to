#!/usr/bin/python2.7
# -*- coding: UTF-8 -*-

# This script takes an email from stdin and delivers it to
# the addresses provided as command line arguments.
# It forces the "To:" header to be set.

# Why?
# When using /etc/aliases to redirect local mail to an mailing list for
# example, some mailing list servers will complaint about the unset "To:"
# header (Mailman will mumble something about an implicit destination).
# You normally don't want to configure every single local sender
# (apticron, rkhunter, web apps, …) to send to a specific address since
# it is inflexible and sometimes even not possible.

import sys
import email
from smtplib import SMTP

if len(sys.argv) < 2:
   print "Please provide at least one email address to send to. Example:"
   print "$ %s you@example.com" % sys.arv[0]
   exit(1)

recipients = sys.argv[1:]

message = email.message_from_file(sys.stdin)
message.add_header("To", ', '.join(recipients))

smtp = SMTP('localhost')
smtp.sendmail(
   message.get("From", "unknown"),
   recipients,
   message.as_string()
)

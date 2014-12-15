#!/bin/bash

#######################################################################
#
# functions
#

function show_help {
	echo "Helper to back up to an SFTP site."
	echo
	echo "Usage:"
	echo "	$(basename $0) [options] <target host> <target directory>"
	echo
	echo "Options:"
	echo "	-p	port at target host (default: 22)"
	echo "	-u	user at target host (default: current user)"
	echo "	-b	backup directory (for rsync's --backup, default: none)"
	echo "	-c	clear the backup directory prior copy (USE WITH CARE, default: no)"
	echo "	-s	source directory (default: '/')"
	echo "	-t	retry timeout (default: 60)"
	echo "	-d	dry run: don't manipulate data (default: no)"
	echo "	-n	no retry if target host is not available (default: retry)"
	echo
	echo "Good luck."
}

######################################################################
#
# functions
#

function errormsg_help_exit {
	echo "ERROR: $*"
	echo
	show_help
	exit 1
}

function run_safely {
	if [ $DRY_RUN -eq 1 ]
	then
		echo "would run '$*'"
	else
		sh -c "$*"
	fi
}

function lftp_do {
	OPTS="set net:reconnect-interval-base 10;"
	OPTS+="set net:max-retries 1;"
	OPTS+="set net:timeout 10;"
	lftp -p $TARGET_PORT -u $TARGET_USER, -e "$OPTS $1" sftp://${TARGET_HOST}
}



#######################################################################
#
# bash & process setup
#

# make us low priority
renice 10 $$
# even for IO:
ionice -c3 -p$$

# exit on any error:
set -e
set -o pipefail


#######################################################################
#
# parse CLI options
#

# argument index for getopts to start parsing
OPTIND=1

# defaults:
SOURCE="/"										# -s
TARGET_USER=$(whoami)							# -u
TARGET_PORT=22									# -p
HISTORY_DIR=""									# -b
CLEAN_HISTORY_DIR=0								# -c
RETRY_TIMEOUT=60								# -t
DRY_RUN=0										# -d
NO_RETRY=0										# -n
PIDFILE=/var/lock/$(basename $0)_$(whoami).lock
RSYNC_OPTS=""

while getopts "h?u:p:b:s:cdn" opt; do
	case "$opt" in
	h|\?)
		show_help
		exit 0
		;;
	s)	if [ "$OPTARG" = "" ] && [ -d "$OPTARG" ]
		then
			errormsg_help_exit "$OPTARG is not a valid source directory."
			show_help
			exit 1
		fi
		SOURCE=$OPTARG
		;;
	u)	if [ "$OPTARG" = "" ]
		then
			errormsg_help_exit "$OPTARG is not a valid user."
			show_help
			exit 1
		fi
		TARGET_USER=$OPTARG
		;;
	p)	if ! [[ "$OPTARG"  =~ ^[0-9]+$ ]]
		then
			errormsg_help_exit "$OPTARG is not a valid port."
			show_help
			exit 1
		fi
		TARGET_PORT=$OPTARG
		;;
	b)	if [ "$OPTARG" = "" ]
		then
			errormsg_help_exit "$OPTARG is not a valid backup directory."
			show_help
			exit 1
		fi
		HISTORY_DIR=$OPTARG
		RSYNC_OPTS="--backup --backup-dir=$HISTORY_DIR"
		;;
	c)	CLEAN_HISTORY_DIR=1
		;;
	d)	DRY_RUN=1
		;;
	n)	NO_RETRY=1
		;;
	t)	if ! [[ "$OPTARG"  =~ ^[0-9]+$ ]]
		then
			errormsg_help_exit "$OPTARG is not a valid retry timeout."
			show_help
			exit 1
		fi
		RETRY_TIMEOUT=$OPTARG
		;;
	esac
done

shift $((OPTIND-1))
[ "$1" = "--" ] && shift

if [ "$1" = "" ]
then
	errormsg_help_exit "Provide the destination host 1st argument."
	show_help
	exit 1
fi
TARGET_HOST="$1"

if [ "$2" = "" ]
then
	errormsg_help_exit "Provide the destination directory as 2nd argument."
	show_help
	exit 1
fi
TARGET_DIR="$2"




#######################################################################
#
# check dependencies
#
type lftp > /dev/null || exit 1
type rsync > /dev/null || exit 1

#######################################################################
#
# make sure only one instance runs at a time
#
if [ -e $PIDFILE ]; then
	PID=`cat $PIDFILE`
	if kill -0 &>1 > /dev/null $PID; then
		echo "Already running"
		exit 1
	else
		echo "deleting stale pidfile…"
		rm $PIDFILE
	fi
fi
trap "rm -f ${PIDFILE}; exit" INT TERM EXIT
echo $$ > $PIDFILE


#######################################################################
#
# wait until the target host is reachable
#
function is_online() {
	lftp_do "ls; quit" > /dev/null
	echo $?
}

while [ $NO_RETRY -eq 0 ] && [ $(is_online) -ne 0 ]
do
	echo "sleeping ${RETRY_TIMEOUT}…"
	sleep ${RETRY_TIMEOUT}
done


#######################################################################
#
# assemble default rsync command
#
RSYNC="run_safely rsync --rsh='ssh -p $TARGET_PORT' --verbose --verbose"


#######################################################################
#
# clean the history
#
if [ $CLEAN_HISTORY_DIR -eq 1 ]
then
	EMPTY_DIR=$(mktemp -d)

	# just to be sure…
	[ "$EMPTY_DIR" = "" ] && exit

	$RSYNC \
		--archive \
		--delete \
			"${EMPTY_DIR}/" "${TARGET_USER}@${TARGET_HOST}:${HISTORY_DIR}"
	rmdir "${EMPTY_DIR}/"
fi

#######################################################################
#
# copy
#
RSYNC_OPTS+= --progress
RSYNC_OPTS+= --human-readable
RSYNC_OPTS+= --one-file-system
RSYNC_OPTS+= --archive
RSYNC_OPTS+= --delete-during
RSYNC_OPTS+= --delete-excluded
RSYNC_OPTS+= --exclude=/tmp
RSYNC_OPTS+= --exclude=\"*\\[nb\\]/*\"
RSYNC_OPTS+= --exclude=\"*/.cache/*\"
RSYNC_OPTS+= --exclude=\"*/Cache/*\"
RSYNC_OPTS+= --exclude=\"*/cache/*\"

if [ "$(uname -o)" != "Cygwin" ]
then
	RSYNC_OPTS+= --xattrs
	RSYNC_OPTS+= --acls
fi

$RSYNC \
	$RSYNC_OPTS \
		"${SOURCE}" \
		"${TARGET_USER}@${TARGET_HOST}:${TARGET_DIR}"

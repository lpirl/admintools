#!/bin/bash

#######################################################################
#
# help
#

function show_help {
	echo "Helper to back up to an SFTP site."
	echo
	echo "Usage:"
	echo "	$(basename $0) [options] <target host> <target directory>"
	echo
	echo "Options:"
	echo "	-p	port at target host (default: 22)"
	echo "	-u	user at target host (default: hostname)"
	echo "	-b	backup directory (for rsync's --backup, default: none)"
	echo "	-c	clear the backup directory prior copy (USE WITH CARE, default: no)"
	echo "	-s	source directory (default: '/')"
	echo "	-t	retry timeout (default: 60)"
	echo "	-d	dry run: don't manipulate data (default: no)"
	echo "	-n	no retry if target host is not available (default: retry)"
	echo "	-o	extra options to pass to rsync"
	echo "	-v	be verbose (default: print errors only)"
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
		echo "would run: $*" 1>&2
	else
		sh -c "$*"
	fi
}


#######################################################################
#
# bash setup
#

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
SOURCE="/"											# -s
TARGET_USER=$(hostname)					# -u
TARGET_PORT=22									# -p
HISTORY_DIR=""									# -b
CLEAN_HISTORY_DIR=0							# -c
RETRY_TIMEOUT=60								# -t
DRY_RUN=0												# -d
VERBOSE=0												# -v
STDOUT=/dev/null
NO_RETRY=0											# -n
PIDFILE_NAME=$(basename $0)_$(whoami).lock
RSYNC_OPTS=""

while getopts "h?u:p:b:s:o:cdnv" opt; do
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
	o)	RSYNC_OPTS+=" $OPTARG "
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
	v)	VERBOSE=1
		STDOUT=/dev/tty
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
# priorities
#

# make us low priority
renice 10 $$ &> $STDOUT
# even for IO:
ionice -c3 -p$$ &> $STDOUT


#######################################################################
#
# check dependencies
#
type rsync > $STDOUT || exit 1

#######################################################################
#
# make sure only one instance runs at a time
#
if [ -d /var/lock ]
then
	PIDFILE=/var/lock/$PIDFILE_NAME
else
	PIDFILE=/tmp/$PIDFILE_NAME
fi
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
	OPTS=`[ $VERBOSE -eq 1 ] && echo "" || echo "-q"`
	run_safely "echo 'ls' | \
		sftp $OPTS -P $TARGET_PORT  '${TARGET_USER}@${TARGET_HOST}' > /dev/null"
	echo $?
}

while [ $NO_RETRY -eq 0 ] && [ $(is_online) -ne 0 ]
do
	echo "sleeping ${RETRY_TIMEOUT}…"
	sleep ${RETRY_TIMEOUT}
done


#######################################################################
#
# assemble rsync command
#

if [ $VERBOSE -eq 1 ]
then
	RSYNC_OPTS+=' --verbose --verbose --progress'
	SSH_OPTS=""
else
	RSYNC_OPTS+=' --quiet'
	SSH_OPTS="-q"
fi
RSYNC="run_safely rsync --rsh='ssh $SSH_OPTS -p $TARGET_PORT'"


#######################################################################
#
# clean the history
#
if [ $CLEAN_HISTORY_DIR -eq 1 ]
then
	if [ "$HISTORY_DIR" = "" ]
	then
		echo "cannot clear the backup (-c) without a backup directory (-b)"
		exit 1
	fi
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
RSYNC_OPTS+=' --human-readable'
RSYNC_OPTS+=' --one-file-system'
RSYNC_OPTS+=' --archive'
RSYNC_OPTS+=' --fake-super'
RSYNC_OPTS+=' --delete-during'
RSYNC_OPTS+=' --delete-excluded'
RSYNC_OPTS+=' --checksum'
RSYNC_OPTS+=' --exclude=/tmp'
RSYNC_OPTS+=' --exclude="*\\[nb\\]/*"'
RSYNC_OPTS+=' --exclude="*/.cache/*"'
RSYNC_OPTS+=' --exclude="*/Cache/*"'
RSYNC_OPTS+=' --exclude="*/cache/*"'

if [ "$(uname -o)" != "Cygwin" ]
then
	RSYNC_OPTS+=" --xattrs"
	RSYNC_OPTS+=" --acls"
fi

$RSYNC \
	$RSYNC_OPTS \
		"${SOURCE}" \
		"${TARGET_USER}@${TARGET_HOST}:${TARGET_DIR}"

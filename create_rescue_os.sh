#!/bin/bash

# This scripts is intended to regularly create a bootalbe backup of the
# operating system.
#
# Even a USB-key is suitable to backup to. This way, you can do a
# relatively fast, manual failover in case your boot medium fails.
#
# !!! The backup must reside on a separate partition !!!
#
# Prior initial execution, make sure to create the separate partition
# of sufficient size (with i.e. fdisk) with preferably the same file
# system as you use for your root partition.
#
# IMPORTANT:
# Try booting into your rescue OS (obviously). If you experience fsck
# is stopping your boot process and asking for giving the root password
# or Ctrl-D because a device is missing, make the corresponding file
# systems of the fstype "auto" or add "nofail" as a mount option in your
# original fstab.
#
# After initial execution, check if you can boot the backup.
#
# usage: ./create_rescue_os.sh <target_UUID>
#
# Put a call to this script in your crontab to create backups regularly,
# (But remember: USB-keys die earlier the more often you write to them.)

#
# functions
#
function error {
	args="${*:1}"
	echo "ERROR:" ${args[@]}
	echo "exiting"
	exit 1
}

function var_detect_check { # name
	VALUE=$(eval "echo \$${1}")
	echo "${1}=${VALUE}"
	if [ "${VALUE}" = "" ]
	then
	        error "could not detect '${1}'. ${2}"
	fi
}

function bincheck { # name
	BIN=$(eval "whereis -b ${1} | cut -d' ' -f2")
	if [ ! -x $BIN ]
	then
	        error "dependency '${1}' not found!"
	fi
	echo -n $BIN
}

#
# check dependencies
#
RSYNC=$(bincheck rsync)
MOUNT=$(bincheck mount)
UMOUNT=$(bincheck umount)
UPDATE_GRUB=$(bincheck update-grub)
GRUB_INSTALL=$(bincheck grub-install)

#
# collect information
#
if [ "$1" = "" ]
then
	error 	"Argument missing! " \
			"Please provide the UUID of the target partition" \
			"as first argument."
fi

TARGET_UUID="$1"
var_detect_check TARGET_UUID

MOUNTPOINT=$( grep -v "^#" /etc/fstab | grep $TARGET_UUID | awk '{print $2}')
var_detect_check MOUNTPOINT "The UUID must be specified in /etc/fstab."

DEVICE=$(blkid | grep $TARGET_UUID | cut -d: -f1 | sed 's/[0-9]*$//g')
var_detect_check DEVICE

$MOUNT $MOUNTPOINT

#
# check if target is mounted
#
if [ $(df "/" "${MOUNTPOINT}" | sort -u | wc -l) -ne 3 ]
then
	error "target could not to be mounted"
fi

#
# check if we must update grub after copying data
#
if [ "$(ls /boot | md5sum)" = "$(ls $MOUNTPOINT/boot | md5sum)" ]
then
	UPDATE_BOOTLOADER=false
else
	UPDATE_BOOTLOADER=true
fi

#
# copy data
#
$RSYNC \
	--archive \
	--verbose \
	--delete-during \
	--rsync-path='nice -n19 rsync' \
	--one-file-system \
	--exclude=/proc/* \
	--exclude=/dev/* \
	--exclude=/tmp/* \
	--exclude=/sys/* \
	--exclude=/run/* \
	--exclude=/home/* \
	--exclude=/var/cache/* \
	--exclude=/var/lock/* \
	--exclude=/var/log/* \
	--exclude=/var/mail/* \
	--exclude=/var/spool/* \
		/ /boot "${MOUNTPOINT}"

#
# set up chroot
#
BINDS="dev proc sys tmp"
CHROOT="chroot ${MOUNTPOINT}"

for BIND in $BINDS
do
	$MOUNT --bind /$BIND $MOUNTPOINT/$BIND
done

#
# update grub
#
if [ $UPDATE_BOOTLOADER = true ]
then
	# actually update grub
	$CHROOT $UPDATE_GRUB
	$CHROOT $GRUB_INSTALL $DEVICE
fi

#
# tear down chroot
#
for BIND in $BINDS
do
	$UMOUNT -l $MOUNTPOINT/$BIND
done

echo "unmounting…"

$UMOUNT -l $MOUNTPOINT

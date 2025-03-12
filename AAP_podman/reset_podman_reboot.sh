#!/bin/bash

# Delete the podman files in /tmp that shouldn't survive after a reboot
# and which will prevent podman to work properly.

# Delete also the ansible /tmp files/directories
# and which may prevent AAP to work properly

#================================================================================
# Check if root user

ID=`id -u`
if [[ $ID -ne 0 ]]; then
	echo "You need to be root to run this tool. Exiting..."
	echo
	exit 1
fi


#================================================================================
# Delete all the pause.pid file found in /tmp
# It must be run as root after rebooting the VM.
# Podman refuses to work if an old pause.pid file exists

echo; echo "####################################################################"
echo "Deleting pause.pid files"
for i in `find /tmp -name pause.pid`; do
  echo $i
  rm -f $i
done

#================================================================================
# Delete ansible /tmp files

echo; echo "####################################################################"
echo "Deleting temporary /tmp ansible directories"
TmpAnsibleDir=`ls -d /tmp/ansible.*` 
TmpContainers=`ls -d $TmpAnsibleDir/containers 2>/dev/null` 
TmpLibpodTmp=`ls -d $TmpAnsibleDir/libpod/tmp 2>/dev/null` 

if [[ " $TmpContainers" != " " ]]; then 
	ls -d $TmpContainers
	rm -rf $TmpContainers
fi

if [[ " $TmpLibpodTmp" != " " ]]; then 
	ls -d $TmpLibpodTmp
	rm -rf $TmpLibpodTmp
fi

echo

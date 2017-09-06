#!/bin/bash

###########################################################################
# reset_juju_demo.bash 
#
# Goal: reset the VMs used by the juju demo
#   - jdmaas/jdjuju    : reverted to the $SnapShotName snapshot level
#   - jdvm01 -> JDVM10 : just stopped as they'll be reloaded by the demo
#
# Author : Fabrice MOYEN
#
# Date : June 27, 2017
#
###########################################################################


SnapshotName="DEMO16.04.2"

option_n=0
while getopts "nh" option
do
  case $option in
    n  )
      option_n=1
    ;;
    h  )
      echo
      echo "USAGE:"
      echo "$0 [-n]"
      echo "    -n (optional): if you don't want to start jdmaas/jdjuju VMs after reset (for backup purpose)"
      echo
      exit 1
    ;;
    \? ) echo "Unknown option: -$OPTARG" >&2; exit 1;;
    :  ) echo "Missing option argument for -$OPTARG" >&2; exit 1;;
    *  ) echo "Unimplemented option: -$OPTARG" >&2; exit 1;;
  esac
done

echo
echo

echo "Stopping jdmaas/jdjuju Virtual Machines..."
for i in jdmaas jdjuju
do
  virsh destroy $i >/dev/null 2>&1
done

virsh list | egrep 'jdmaas|jdjuju' >/dev/null 2>&1
check=`echo $?`
while [ $check -eq 0 ]
do
  echo "   --> Waiting for jdmaas/jdjuju VMs to stop"
  sleep 10
  virsh list | egrep 'jdmaas|jdjuju' >/dev/null 2>&1
  check=`echo $?`
done

echo "Stopping jdvm01 -> jdvm10 Virtual Machines..."
for i in `seq -w 1 10`
do
  virsh destroy jdvm$i > /dev/null 2>&1
done

echo "Reverting the jdmaas/jdjuju Virtual Machines to the snapshot $SnapshotName..."
virsh snapshot-revert jdmaas --snapshotname $SnapshotName
virsh snapshot-revert jdjuju --snapshotname $SnapshotName

if [ $option_n == 0 ]
then
  echo "Starting jdmaas/jdjuju Virtual Machines..."
  for i in jdmaas jdjuju
  do
    virsh start $i
  done

  echo
  echo "Wait for 1 or 2 min and everything should be OK and ready."
  sleep  60
else
  echo "Warning: jdmaas/jdjuju Virtual Machines NOT STARTED..."
  echo "The demo is not available (but ready for backup)"
fi
echo
echo "Bye"
echo

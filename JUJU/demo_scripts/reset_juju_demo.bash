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

echo
echo

SnapshotName="DEMO16.04.2"

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

echo "Starting jdmaas/jdjuju Virtual Machines..."
for i in jdmaas jdjuju
do
  virsh start $i
done

echo
echo "Wait for 1 or 2 min and everything should be OK and ready."
echo "Bye"
echo

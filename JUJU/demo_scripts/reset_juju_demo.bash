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
ListVMsDisk="\
/VMDisks/jujudemo/7ec45cf8-2ee7-412c-b2bb-a2308c0815e7-0.img \
/VMDisks/jujudemo/d3c3a8e3-750d-4f67-afac-5ba2f72b9af1-0.img \
/VMDisks/jujudemo/8514629e-384c-476b-89a4-e7b53c2339d8-0.img \
/VMDisks/jujudemo/ebc033cb-8634-4a2a-ae29-635244622d59-0.img \
/VMDisks/jujudemo/1dda4b79-f1f9-44a0-8d55-d431d1b0d8bb-0.img \
/VMDisks/jujudemo/6c0cf58b-dd88-43ee-b91d-453df0a9b379-0.img \
/VMDisks/jujudemo/04ab1cc5-7ab2-440f-bacc-7e0cfd9deece-0.img \
/VMDisks/jujudemo/9698d649-a5ee-4168-b743-ab90df570bda-0.img \
/VMDisks/jujudemo/334b401b-bf93-4800-9ba1-b3dba4aa84e6-0.img \
/VMDisks/jujudemo/255a8e6e-8b42-4670-8ae0-3bb105689787-0.img"

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

echo "Recreating the jdvm01 -> jdvm10 disks..."
for i in $ListVMsDisk
do
  qemu-img create -f qcow2 $i 50G
done

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

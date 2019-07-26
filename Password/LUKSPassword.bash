#!/bin/bash

Accounts="fabrice root"
Today=`date +%Y-%m-%d`

#####################################################################################
# Check if root
#

if [ `whoami` != "root" ]
then
  echo
  echo "You're not root. You need to execute this script as root"
  echo "Think of sudo command..."
  echo "Exiting"
  exit 0
fi

#####################################################################################
# MAIN
#

VolumeList=""

echo
echo "##########################################################"
echo "--> LIST OF ENCRYPTED LUKS VOLUMES"
for i in `blkid | grep -i crypto_luks | awk -F: '{print $1}'`
do
  echo
  echo $i
  echo "-----------------------"
  VolumeList+=" $i"
  lsblk $i
  echo
  echo "Used password key slots:"
  cryptsetup luksDump $i |grep BLED | grep ENABLED
done

echo
echo "##########################################################"
echo "--> CHANGING PASSWORD"
OldPassword=""
NewPassword=""
Slot=0

read -p "     Key password slot: ($Slot by default): " Slot
if [ "$Slot" == "" ]; then Slot=0; fi

echo
echo "changing Key Password Slot $Slot with..."
echo "-------------------------------------"

for i in $VolumeList
do
  echo
  echo "cryptsetup luksChangeKey $i -S $Slot"
  cryptsetup luksChangeKey $i -S 0
done

echo 
echo "All done... Exiting"

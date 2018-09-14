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

echo
for i in $Accounts
do
   echo "$i account"
   echo "----------------------"
   chage -d $Today $i
   chage -W 15 $i
   chage -M 90 $i
   chage --list $i
   echo
done

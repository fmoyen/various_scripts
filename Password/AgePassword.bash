#!/bin/bash

Accounts=""

if [ "$1" == "" ]; then
  Accounts="fabrice root"
else
  Accounts=$*
fi

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
   echo "######################################"
   echo "$i account"
   echo "----------------------"
   echo "Before:"
   chage --list $i
   echo
done

   echo -e "OK to change the age of the passwords [Y/n] ? : \c"
   read OKToChange
   echo

   if [ "$OKToChange" == "" ] || [ "$OKToChange" == "y" ] || [ "$OKToChange" == "Y" ]
   then
     echo; echo "Changing..."; echo
     for i in $Accounts
     do
       echo "######################################"
       echo "$i account"
       echo "----------------------"
       echo "Now:"
       chage -d $Today $i
       chage -W 15 $i
       chage -M 90 $i
       chage --list $i
       echo
     done
   else 
     echo "######################################"
     echo "Doing nothing. Exiting..."
     echo
   fi

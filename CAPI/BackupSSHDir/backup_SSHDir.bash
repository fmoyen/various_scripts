#!/bin/bash

###################################################################################################################################
# Date: 2021/03
# Author: Fabrice MOYEN
# Objective: Backup the /etc/ssh directory



###################################################################################################################################
# Parameters
#
Today=$(date +%Y-%m-%d-%H%M%S)
WhoAmI=`who am i| awk '{print $1}'` # "whoami" not working because of sudo
OS_ID=`cat /etc/os-release | grep "^ID=" | awk -F"=" '{print $2}' | sed 's/"//g'`
Script=`realpath $0`
ScriptDir=`dirname $Script`
eval OutputDir=~$WhoAmI/CAPI/SSHDirOutput # generic $HOME is not OK to use as this script is run with sudo (so $HOME=/root)
OutputFile="${OutputDir}/$(hostname | tr '[:lower:]' '[:upper:]')_${OS_ID}_${Today}_SSHDir.tar.gz"


###################################################################################################################################
# Functions
#

function usage
{
  echo
  echo "`basename $0` Usage:"
  echo "-------------------------"
  echo
  echo "  + script to be run on the system you want to backup the /etc/ssh directory"
  echo
  echo "  + You need to be root to use the script (sudo)"
  echo
  echo "  + Objective: Backup the /etc/ssh directory"
  echo
  echo "  + -h / -? / --help: shows this usage info"
  echo
  echo "This Tool Output File will be: $OutputFile"
  echo
  exit 0
}


###################################################################################################################################
# When parameters are given when launching the script
#

if [ $# -gt 0 ]
then
  WhatToDo=$1
  if [ "$WhatToDo" == "-h" ] || [ "$WhatToDo" == "-?" ] || [ "$WhatToDo" == "--help" ]; then
    usage
  fi
fi


###################################################################################################################################
# Check if root
#

if [ `whoami` != "root" ]
then
  echo
  echo "You're not root. You need to execute this script with root privileges"
  echo "Think of sudo command..."
  echo "Exiting"
  exit 0
fi


###################################################################################################################################
# MAIN
#

mkdir -p $OutputDir

echo; echo "------------------------------------------------------------------------------------------------------------------------------"
CMD="cd /etc/ssh && tar cvzf $OutputFile ."
echo $CMD
echo
eval $CMD
echo; echo "------------------------------------------------------------------------------------------------------------------------------"; echo

chown -Rh $WhoAmI:$WhoAmI $OutputDir

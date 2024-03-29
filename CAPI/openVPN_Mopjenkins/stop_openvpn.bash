#!/bin/bash

# Stop openVPN keys
# Author: Fabrice MOYEN
# Date: 2022/01/17

script=`realpath $0`
scriptPath=`dirname $script`
VPNPrefix="mopjenkins_13012023_"

primaryKey=`cd $scriptPath/${VPNPrefix}1;ls *.key`
primaryKey=`echo $primaryKey | sed "s/.key//g"`
backupKey=`cd $scriptPath/${VPNPrefix}2;ls *.key`
backupKey=`echo $backupKey | sed "s/.key//g"`

keysRunning=""
keysNotRunning=""
for key in $primaryKey $backupKey
do
	ps -ef | grep -v grep | grep $key > /dev/null
	running=`echo $?`

	if [ $running -ne 0 ]
	then
		keysNotRunning="$keysNotRunning $key"
	else
		keysRunning="$keysRunning $key"
	fi
done
echo
echo "------------------------------------------------"
echo "Key(s) running =$keysRunning"
echo "Key(s) NOT running =$keysNotRunning"

if [ "X$keysRunning" = "X" ]
then
	echo
	echo "------------------------------------------------"
	echo "No openVPN key running. Exiting..."
else
	for key in $keysRunning
	do
		openvpnPID=`pgrep -f $key`
		echo
		echo "------------------------------------------------"
		echo "Killing running openVPN key $key ..."
		sudo kill $openvpnPID
        	if [ $? -eq 0 ]
		then
			echo "   -> done !"
		else
			echo
			echo "------------------------------------------------"
			echo "Failed to stop the openVPN key: $key"
			echo "Exiting..."
			exit 1
		fi
	done
fi

echo

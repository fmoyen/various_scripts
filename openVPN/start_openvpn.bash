#!/bin/bash

# Start openVPN keys and monitor everything is going well
# Use the second key if the first one fails
# Author: Fabrice MOYEN
# Date: 2019/02/06

script=`realpath $0`
scriptPath=`dirname $script`
VPNPrefix="moyen"
primaryKeyDir=${scriptPath}/current
backupKeyDir=${primaryKeyDir}/BackupKey

primaryKey=`cd $primaryKeyDir;ls *.key`
primaryKey=`echo $primaryKey | sed "s/.key//g"`
backupKey=`cd $backupKeyDir;ls *.key`
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
	echo "Starting openVPN $primaryKey"
	cd $primaryKeyDir; sudo nohup ./start_openvpn.sh & 2>/dev/null
	echo "------------------------------------------------"
	echo "... Waiting 30s so we have time to connect ..."
	echo "... and see if we need to start $backupKey ..."
	sleep 30 # waiting for the first key to try and connect

	# Checking if first key is connected and if no trying the second one
	ps -ef | grep -v grep | grep $primaryKey > /dev/null
        running=`echo $?`

        if [ $running -ne 0 ]
	then
		echo
		echo "------------------------------------------------"
		echo "$primaryKey failed. Trying to start openVPN $backupKey"
		cd $backupKeyDir; sudo nohup ./start_openvpn.sh & 2>/dev/null
		sleep 30 # waiting for the backup key to try and connect
		ps -ef | grep -v grep | grep $backupKey > /dev/null
        	backupActive=`echo $?`
		if [ $backupActive -eq 0 ]
		then
			echo
			echo "------------------------------------------------"
			echo "$backupKey running. Exiting..."
		else
			echo
			echo "------------------------------------------------"
			echo "$backupKey FAILED !!! Needs repair..."
			echo "Exiting..."
			exit 1
		fi
		
	else
		echo
		echo "------------------------------------------------"
		echo "$primaryKey running. Exiting..."
	fi
else
	echo
	echo "------------------------------------------------"
	echo "openvpn is running. Good -> Exiting"
fi

echo
pingTest=`ping -c 1 10.7.19.254 | grep "packets transmitted"`
echo "ping test ONN719 -> $pingTest"

echo

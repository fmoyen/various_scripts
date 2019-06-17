#!/bin/bash

# Start openVPN keys and monitor everything is going well
# Use the second key if the first one fails
# Author: Fabrice MOYEN
# Date: 2019/02/06

script=`realpath $0`
scriptPath=`dirname $script`

# Variables
VPNPrefix="moyen"
primaryKeyDir=${scriptPath}/current
backupKeyDir=${primaryKeyDir}/BackupKey
IPTest="10.7.19.254"

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
	echo "  First deleting old $primaryKeyDir/nohup.out"
	sudo rm -f $primaryKeyDir/nohup.out
	cd $primaryKeyDir; sudo nohup ./start_openvpn.sh & 2>/dev/null

	echo "------------------------------------------------"
	echo "... Giving a max of 30s to connect ..."
	echo "... and see if we need to start $backupKey ..."
	Delay=0
	while [ $Delay -ne 30 ]
	do
		if sudo grep "Initialization Sequence Completed" $primaryKeyDir/nohup.out >/dev/null 2>&1
		then
			Delay=30
		else
			((Delay++))
		fi
		sleep 1
	done
			
	# Checking if first key is connected and if no trying the second one
	if ! ping -c1 $IPTest >/dev/null
	then
		echo
		echo "------------------------------------------------"
		echo "Cannot access to $IPTest..."
		echo "  --> $primaryKey failed. Trying to start openVPN $backupKey"
		echo "  First deleting old $backupKeyDir/nohup.out"
		sudo rm -f $backupKeyDir/nohup.out
		cd $backupKeyDir; sudo nohup ./start_openvpn.sh & 2>/dev/null

		Delay=0
		while [ $Delay -ne 30 ]
		do
			if sudo grep "Initialization Sequence Completed" $backupKeyDir/nohup.out >/dev/null 2>&1
			then
				Delay=30
			else
				((Delay++))
			fi
			sleep 1
		done

		if ping -c1 $IPTest >/dev/null
		then
			echo
			echo "------------------------------------------------"
			echo "$IPTest is responding"
			echo "  --> $backupKey running. Exiting..."
		else
			echo
			echo "------------------------------------------------"
			echo "Cannot access to $IPTest..."
			echo "  --> $backupKey FAILED !!! Needs repair..."
			echo "Exiting..."
			exit 1
		fi
		
	else
		echo
		echo "------------------------------------------------"
		echo "$IPTest is responding"
		echo "  --> $primaryKey running. Exiting..."
	fi
else
	echo
	echo "------------------------------------------------"
	echo "openvpn is running. Good -> Exiting"
fi

echo
pingTest=`ping -c 1 $IPTest | grep "packets transmitted"`
echo "ping test $IPTest -> $pingTest"

echo

#!/bin/bash

# Start openVPN in order to connect to Power Build executor nodes
# Author: Fabrice MOYEN
# Date: 2022/01/17

# Otherwise, openvpn command is not found
. /etc/environment

script=`realpath $0`
scriptPath=`dirname $script`
VPNPrefix="mopjenkins_13012023_"

ps -ef | grep -v grep | grep $VPNPrefix > /dev/null
running=`echo $?`

if [ $running -ne 0 ]
then
        echo "------------------------------------------------"
	echo "Starting openVPN ${VPNPrefix}1"
        echo "  First deleting old ${VPNPrefix}1/nohup.out"
        sudo rm -f $scriptPath/${VPNPrefix}1/nohup.out

	cd $scriptPath/${VPNPrefix}1; nohup ./start_openvpn_bfs.sh &
        echo "------------------------------------------------"
        echo "... Waiting 30s so we have time to connect ..."
        echo "... and see if we need to start ${VPNPrefix}2 ..."

	sleep 30 # waiting for the first key to try and connect

	# Checking if first key is connected and if not trying the second one
	ps -ef | grep -v grep | grep $VPNPrefix > /dev/null
        running=`echo $?`

        if [ $running -ne 0 ]
	then
		echo
        	echo "------------------------------------------------"
		echo "${VPNPrefix}1 failed. Trying to start openVPN ${VPNPrefix}2"
        	echo "  First deleting old ${VPNPrefix}2/nohup.out"
        	sudo rm -f $scriptPath/${VPNPrefix}2/nohup.out
		cd $scriptPath/${VPNPrefix}2; nohup ./start_openvpn_bfs.sh &
		sleep 5
		ps -ef | grep -v grep | grep $VPNPrefix
	fi
else
	echo "openvpn is still running. Good -> Exiting"
fi


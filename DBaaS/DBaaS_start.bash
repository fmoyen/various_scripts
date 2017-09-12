#!/bin/bash

#KVM=abaca
KVM=10.3.44.200

echo 
echo -e "Are you sure you want to START the DBaaS demo (Y/[N]) ?: \c"
read a

case $a in
  Y) 
  echo "Starting the DBaaS demo"
  ;;
  *)
  echo "Exiting WITHOUT starting the DBaaS demo"
  exit 0
  ;;
esac

for VM in DBaaSceph33703 DBaaSceph33704 DBaaSceph33705 DBaaSswift33706 DBaaSswift33707 DBaaSswift33708 DBaaScompute33710 DBaaSclient33720 DBaaScontroller33702
do

  echo
  echo "##########################################################"
  echo "-> Starting $VM"
  LastDigitIP=`echo $VM | grep -o '..$'`
  VMIP="10.3.37.`echo $((10#$LastDigitIP))`"
  if [ $VM == "DBaaScontroller33702" ]
  then
    ControllerIP=$VMIP
  fi

  ssh root@$KVM virsh start $VM

  echo -e "   Waiting for $VM to start (pinging)\c"
  ping -c 1 $VMIP > /dev/null 2>&1
  PingResult=`echo $?`
  while [ $PingResult -ne 0 ]
  do  
    echo -e ".\c"
    ping -c 1 $VMIP > /dev/null 2>&1
    PingResult=`echo $?`
  done
done

echo;echo
echo "##########################################################"
echo "-> Please wait few minutes for the openstack containers to start on the Controller"
echo
echo "Press ENTER to use \"watch -d -n1 lxc-ls -f\" on the controller and check when every container is up"
echo -e "or CTRL-C to exit : \c"
read a

ssh -t root@$ControllerIP watch -d -n1 lxc-ls -f
echo
echo "Bye !"

#!/bin/bash

#KVM=abaca
KVM=10.3.44.200

echo 
echo -e "Are you sure you want to STOP the DBaaS demo (Y/[N]) ?: \c"
read a

case $a in
  Y) 
  echo "Stopping the DBaaS demo"
  ;;
  *)
  echo "Exiting WITHOUT stopping the DBaaS demo"
  exit 0
  ;;
esac

for VM in DBaaScontroller33702 DBaaScompute33710 DBaaSswift33708 DBaaSswift33707 DBaaSswift33706 DBaaSceph33705 DBaaSceph33704 DBaaSceph33703
do

  echo
  echo "##########################################################"
  echo "-> Stopping $VM"
  LastDigitIP=`echo $VM | grep -o '..$'`
  VMIP="10.3.37.`echo $((10#$LastDigitIP))`"

  ssh -t ibmadmin@$VMIP sudo halt

  echo -e "   Waiting for $VM to stop (virsh list)\c"
  ssh root@$KVM virsh list | grep $VM > /dev/null 2>&1
  VirshResult=`echo $?`
  while [ $VirshResult -eq 0 ]
  do  
    echo -e ".\c"
    ssh root@$KVM virsh list | grep $VM > /dev/null 2>&1
    VirshResult=`echo $?`
  done
done

echo;echo
echo "##########################################################"
echo
ssh root@$KVM virsh list -all | grep -i dbaas
echo "Bye !"

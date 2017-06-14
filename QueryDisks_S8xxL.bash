#!/bin/bash

echo

for i in `seq 1 12`
do 
  tempo=`iprconfig -c show-config | grep "RAID 0 Array  " | head -1 | awk '{print $1}'`
  Code=`iprconfig -c query-location  $tempo | awk -F"-D" '{print $1}'`
  Location="$Code-D$i"
  Device=`iprconfig -c query-array $Code-D$i | awk -F/dev/ '{print $2}'`
  if [ X$Device != "X" ]
  then
    Raid=`iprconfig -c show-details $Device | grep "RAID Level" | awk -F: '{print $2}'`
    sgDevice=`iprconfig -c query-device $Location | awk -F/dev/ '{print $2}'`
    IPR=`iprconfig -c show-alt-config | grep -w $sgDevice | cut -c 44-59`
    IPR=`udevadm info --attribute-walk --name=/dev/$Device  | grep model | awk -F== '{print $2}'`
    Serial=`iprconfig -c show-details $Device | grep "Serial Number" | awk -F: '{print $2}'`
  else
    Raid=""
    sgDevice=""
    IPR=""
    Serial=""
  fi
  echo -e "$Location \t$sgDevice\t$Device\t$Raid \t$IPR\t$Serial" 
done
echo

#!/bin/bash

if [ $# -eq 1 ]; then
   File=$1
else
   File="File"
fi

if  ! ls -d $File >/dev/null 2>&1; then
  echo "$File not found... Exiting"
  exit 1
fi

DateLastBoot=`who -b | awk '{print $3 " " $4}'`
EpochLastBoot=`date -d "$DateLastBoot" +%s`

EpochFile=`stat --format=%Y $File`
DateFile=`date --date @$EpochFile`

echo;echo "======================================================="
echo "Last boot:"
#echo $DateLastBoot
echo "`date --date @$EpochLastBoot`"
echo "($EpochLastBoot)"

echo;echo "======================================================="
echo "$File last modification:"
echo $DateFile
echo "($EpochFile)"

echo;echo "======================================================="
if [ $EpochFile -lt $EpochLastBoot ]; then
   echo "$File modified BEFORE last boot"
elif [ $EpochFile -gt $EpochLastBoot ]; then
   echo "$File modified AFTER last boot"
else
   echo "$File modified AT last boot"
fi

echo

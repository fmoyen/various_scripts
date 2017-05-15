#/bin/bash

if [ `whoami` != "root" ]
then
  echo
  echo "You need to be root to run this script"
  echo "think about SUDO command"
  echo 
  exit 1
fi


tempfile=/tmp/arcconf_getconfig.txt
arcconf getconfig 1 > $tempfile

for i in `seq 0 11`
do 
  echo "Device #$i"
  WWN=`awk "BEGIN{RS=ORS="\n\n";FS=OFS="\n"}/Device #$i/ {print;exit}" $tempfile | grep "World-wide name" | awk -F: '{print $2}'`
  TotalSize=`awk "BEGIN{RS=ORS="\n\n";FS=OFS="\n"}/Device #$i/ {print;exit}" $tempfile | grep "Total Size"| awk -F: '{print $2}'`
  echo -e "   World-wide name : \c"
  echo $WWN
  echo -e "   Device name     : \c"
  echo "/dev/`ls -la /dev/disk/by-id | grep -i  $WWN | awk -F/ '{print $NF}'`"
  echo -e "   Total size      : \c"
  echo $TotalSize
  
done

rm $tempfile

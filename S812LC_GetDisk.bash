#/bin/bash

tempfile=/tmp/arcconf_getconfig.txt
arcconf getconfig 1 > $tempfile

for i in `seq 0 11`
do 
  echo
  echo "Device #$i"
  WWN=`awk "BEGIN{RS=ORS="\n\n";FS=OFS="\n"}/Device #$i/ {print;exit}" $tempfile | grep "World-wide name"`
  echo -e "   \c"
  echo $WWN
  WWNID=`echo $WWN | awk -F: '{print $2}'`
  echo -e "   Device name     : \c"
  ls -la /dev/disk/by-id | grep -i  $WWNID | awk '{print $11}'
done

rm $tempfile

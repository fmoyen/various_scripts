#!/bin/bash

BORG_REPO=/DemoBackup/BORG_BACKUP_REPO

if [ `whoami` != "root" ]
then
  echo
  echo "You need to be root to run this script"
  echo "think about SUDO command"
  echo 
  exit 1
fi

option_p=0

while getopts ":p:h" option
do
  case $option in
    p  )
      DEMOPATH=$OPTARG
      option_p=1
    ;;
    h  )
        echo
        echo "usage: "
        echo "   $0 -p /you_path/to_the/demo"
        echo "   (The Borg Backup PREFIX will be the basename of the directory, so \"demo\" in the above example)"
        echo
        exit 2
    ;;
    \? ) echo "Unknown option: -$OPTARG" >&2; exit 1;;
    :  ) echo "Missing option argument for -$OPTARG" >&2; exit 1;;
    *  ) echo "Unimplemented option: -$OPTARG" >&2; exit 1;;
  esac
done

if [ $option_p == 0 ]
then
  echo "Missing option: -p"
  exit 3
fi

if [ ! -d $DEMOPATH ]
then 
  echo
  echo "$DEMOPATH directory does not exist"
  echo 
  echo "Exiting"
  exit 4
fi

TODAY=$(date +%Y-%m-%d)
PREFIXE=`basename $DEMOPATH`

time borg create --verbose --stats --progress -x --compression zlib $BORG_REPO::$PREFIXE-$TODAY $DEMOPATH
#borg prune --verbose --list $BORG_REPO  --prefix='$PREFIXE-' --keep-daily=7 --keep-weekly=4 --keep-monthly=6

#!/bin/bash

BORG_REPO=/DemoBackup/BORG_BACKUP_REPO
DEFAULT_EXCLUDE_FILE="BORG_exclude_file.txt"

if [ `whoami` != "root" ]
then
  echo
  echo "You need to be root to run this script"
  echo "think about SUDO command"
  echo 
  exit 1
fi

option_p=0
option_e=0
BORG_OPTION=""

while getopts ":p:he:" option
do
  case $option in
    p  )
      DEMO_PATH=$OPTARG
      option_p=1
    ;;
    e  )
      EXCLUDE_FILE=$OPTARG
      if [ -f $EXCLUDE_FILE ]
      then
        BORG_OPTION="$BORG_OPTION --exclude-from $EXCLUDE_FILE"
        option_e=1
      else
        echo 
        echo "file $EXCLUDE_FILE does not exist..."
        echo
        echo "Exiting"
        exit 5
      fi
    ;;
    h  )
        echo
        echo "Usage: "
        echo "------ "
        echo "   $0 -p /path/to_the/demo [-e /path/to_your/exclude_file]"
        echo
        echo "      -p (Mandatory) : provide the path to your demo (the directory you want to backup)"
        echo
        echo "      -e (Optional)  : provide the path to the text file containing the list of paths & files to exclude from your backup." 
        echo "      if -e option is not specified, it will use the following exclude file (if existing) : /path/to_the/demo/$DEFAULT_EXCLUDE_FILE"
        echo
        echo "Exclude file example:"
        echo "---------------------"
        echo "*/directory_you_dont_want_to_backup"
        echo "*/dummy_file.doc"
        echo "*/test/personalfile.*"
        echo
        echo "Notes: "
        echo "------ "
        echo "   The Borg Backup PREFIX will be the basename of the directory, so \"demo\" in the above example"
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

if [ $option_e == 0 ]
then
  # No exclude file provided, using the default one if existing
  if [ -f $DEMO_PATH/$DEFAULT_EXCLUDE_FILE ]
  then
    echo "Using default option \"--exclude-from $DEMO_PATH/$DEFAULT_EXCLUDE_FILE\""
    BORG_OPTION="$BORG_OPTION --exclude-from $DEMO_PATH/$DEFAULT_EXCLUDE_FILE"
  fi
fi

if [ ! -d $DEMO_PATH ]
then 
  echo
  echo "$DEMO_PATH directory does not exist"
  echo 
  echo "Exiting"
  exit 4
fi

TODAY=$(date +%Y-%m-%d)
PREFIXE=`basename $DEMO_PATH`

echo 
echo "Borg Command:"
echo "-------------"
echo "borg create --verbose --stats --progress -x --compression zlib $BORG_OPTION $BORG_REPO::$PREFIXE-$TODAY $DEMO_PATH"
echo
borg create --verbose --stats --progress -x --compression zlib $BORG_OPTION $BORG_REPO::$PREFIXE-$TODAY $DEMO_PATH
#borg prune --verbose --list $BORG_REPO  --prefix='$PREFIXE-' --keep-daily=7 --keep-weekly=4 --keep-monthly=6

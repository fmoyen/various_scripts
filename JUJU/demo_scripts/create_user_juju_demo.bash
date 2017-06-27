#!/bin/bash

###########################################################################
# create_user_juju_demo.bash
#
# Goal: create a user (MAAS/JUJU GUI) for running the demo
#
# Author : Fabrice MOYEN
#
# Date : June 27, 2017
#
###########################################################################


AdminUser=userdemo
APIKey="GFyUbnt3fJ3Yxj3aHt:7B38UsEX6djgqT6xfF:6PQvZC5SLtccPgY6BcWW8NA9jCYbHaky"
IPjdmaas=10.3.44.20

option_u=0
option_p=0
while getopts ":u:p:h" option
do
  case $option in
    u  )
      User=$OPTARG
      option_u=1
    ;;
    p  )
      Password=$OPTARG
      option_p=1
    ;;
    h  )
      echo
      echo "USAGE:"
      echo "$0 -u <username> -p <password>"
      echo
      exit 1
    ;;
    \? ) echo "Unknown option: -$OPTARG" >&2; exit 1;;
    :  ) echo "Missing option argument for -$OPTARG" >&2; exit 1;;
    *  ) echo "Unimplemented option: -$OPTARG" >&2; exit 1;;
  esac
done

if [ $option_u == 0 ]
then
  echo "Missing option: -u"
  exit 2
fi

if [ $option_p == 0 ]
then
  echo "Missing option: -p"
  exit 2
fi

###########################################################################
# Create User for the Maas Gui

echo "
maas login $AdminUser http://localhost:5240/MAAS/api/2.0 $APIKey 
maas userdemo users create username=$User email=$User@ibm.com password=$Password is_superuser=1
" > /tmp/jujudemo_create_user_maas.sh

ssh $AdminUser@$IPjdmaas 'bash -s' < /tmp/jujudemo_create_user_maas.sh

rm /tmp/jujudemo_create_user_maas.sh

###########################################################################
# Create User for the Juju Gui

echo "
juju add-user $User
juju models
juju grant $User admin default
juju change-user-password $User <<EOF
$Password
$Password
EOF
" > /tmp/jujudemo_create_user_juju.sh

ssh $AdminUser@$IPjdmaas 'bash -s' < /tmp/jujudemo_create_user_juju.sh

rm /tmp/jujudemo_create_user_juju.sh

echo
echo "Bye"
echo

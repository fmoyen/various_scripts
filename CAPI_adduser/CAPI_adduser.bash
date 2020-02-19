#!/bin/bash

UsersFile=./CAPI_users.txt

# STEPS:
#  - check if root
#  - check /home/capiteam mounted
#  - check if /home/capiteam/$Name exists if remote
#  - check if /home/$Name exists if local
#  - check if $Name, $ID, $GID exist
#  - create user or group
#  - set password if user
#  - configure sudo with or w/o password


n=0
while read Line
do

  User=($Line)

  if [ ${User[0]} = "#" ]; then 
    n=$((n+1))
    continue
  fi

  echo
  echo "====================================================================================="
  echo "User $n"
  echo "-------"
  Name=${User[0]}; echo "NAME= $Name"
  ID=${User[1]}; echo "ID= $ID"
  GID=${User[2]}; echo "GID= $GID"
  Local=${User[4]}; echo "Capiteam or local= $Local"

  if [ $ID != "XXXX" ]; then
    echo;echo "/etc/passwd:"
    echo "------------"
    grep $Name /etc/passwd; NameRC=$?
    grep $ID /etc/passwd; IDRC=$?
  fi
  echo;echo "/etc/group:"
  echo "-----------"
  grep $GID /etc/group; GIDRC=$?

  echo

  if [ $ID != "XXXX" ]; then
    if [ $NameRC -ne 0 ] && [ $IDRC -ne 0 ] && [ $GIDRC -ne 0 ]; then
      echo "  --> OK to create User $Name"
    else
      echo "  --> Cannot Create User $Name. Please check"
    fi
  else
    if [ $GIDRC -ne 0 ]; then
      echo "  --> OK to create Group $Name"
    else
      echo "  --> Cannot Create Group $Name. Please check"
    fi
  fi

  n=$((n+1))
done < $UsersFile

echo

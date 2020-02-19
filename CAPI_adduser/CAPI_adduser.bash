#!/bin/bash

UsersFile=./CAPI_users.txt

n=0
while read Line
do
  User=($Line)
  if [ ${User[0]} != "#" ]; then
    echo "User $n"
    echo "-------"
    Name=${User[0]}; echo "NAME= $Name"
    ID=${User[1]}; echo "ID= $ID"
    GID=${User[2]}; echo "GID= $GID"
    Local=${User[4]}; echo "Capiteam or local= $Local"

    grep $Name /etc/passwd
    grep $ID /etc/passwd
    grep $GID /etc/group
  fi

  echo
  n=$((n+1))
done < $UsersFile

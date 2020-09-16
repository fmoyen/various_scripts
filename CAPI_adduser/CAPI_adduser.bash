#!/bin/bash

UsersFile=./CAPI_users.txt

# STEPS WE SHOULD DO:
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
  echo "-------"; echo
  Name=${User[0]}; echo -e "NAME= $Name \t\c"
  ID=${User[1]}; echo -e "ID= $ID \t\c"
  GID=${User[2]}; echo "GID= $GID"
  Local=${User[4]}; echo "Capiteam or local= $Local"
  MoreGroup=${User[5]}; echo "Additional group= $MoreGroup"
  AdduserOptions="--group"
  AddgroupOptions=""
  if [[ $Local == "capiteam" ]]; then
    Homedir=/home/$Local/$Name
    AdduserOptions="$AdduserOptions --no-create-home"
  elif [[ $Local == "local" ]]; then
    Homedir=/home/$Name
  else
    echo "$Local case not known by script. Aborting..."
    exit 1
  fi

  # Test if we can create User/Group
  if [ $ID != "XXXX" ]; then
    echo;echo "/etc/passwd:"
    echo "------------"
    grep $Name /etc/passwd; NameRC=$?; [ $NameRC -ne 0 ] && echo "$Name non-existent"
    grep $ID /etc/passwd; IDRC=$?; [ $IDRC -ne 0 ] && echo "$ID non-existent"
  fi
  echo;echo "/etc/group:"
  echo "-----------"
  grep $Name /etc/group; GNameRC=$?; [ $GNameRC -ne 0 ] && echo "$Name non-existent"
  grep $GID /etc/group; GIDRC=$?; [ $GIDRC -ne 0 ] && echo "$GID non-existent"


  # We create User/Group
  echo; echo "Actions:"
  echo "--------"
  if [ $ID != "XXXX" ]; then
    if [ $NameRC -ne 0 ] && [ $IDRC -ne 0 ] && [ $GIDRC -ne 0 ] && [ $GNameRC -ne 0 ]; then
      echo "--> OK to create User $Name with Group $Name"
      CMD="adduser $AdduserOptions --home $Homedir --uid=$ID --gid=$GID $Name"
      echo "Command: $CMD" 
      if [ $MoreGroup != "XXXX" ]; then
        echo;echo "--> OK to add group $MoreGroup to the User $Name"
        CMD="usermod -aG $MoreGroup $Name"
        echo "Command: $CMD" 
      fi
    else
      echo "--> Cannot Create User $Name. Please check"
    fi
  else
    if [ $GIDRC -ne 0 ]; then
      echo "--> OK to create Group $Name"
      CMD="groupadd $AddgroupOptions --gid=$GID $Name"
      echo "Command: $CMD" 
    else
      echo "--> Cannot Create Group $Name. Please check"
    fi
  fi


  n=$((n+1))
done < $UsersFile

echo

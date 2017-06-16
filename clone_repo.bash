#!/bin/bash
#
# Fabrice MOYEN
# Sync (clone) some repositories into local directory

##############################################
# VARIABLES

# repo file where to find the Repository IDs we want to sync
REPO=/etc/yum.repos.d/ovirt-4.1-dependencies.repo

# Target directory where to sync the Repository IDs
TARGET_DIR=/root/oVirt41_full_offline/ovirt-4.1-dependencies

##############################################
# PREPARATION

# Get all Repository IDs described in the $REPO repo file
#REPOIDs=`cat $REPO | awk '/\[/ {print substr($1,2,length($0)-2)}'`

# Get only Repository IDs described in the $REPO repo file which are ENABLED
REPOIDs_enabled=`cat $REPO | awk 'BEGIN{RS=ORS="\n\n";FS=OFS="\n"}/enabled=1/' | awk '/\[/ {print substr($1,2,length($0)-2)}'`

# Create a list of Repository IDs (separator=",")
LIST_REPOIDs=""

#for i in $REPOIDs
for i in $REPOIDs_enabled
do
  if [ "X$LIST_REPOIDs" == "X" ]
  then
     LIST_REPOIDs="$i"
  else
     LIST_REPOIDs="$LIST_REPOIDs,$i"
  fi
done

##############################################
# EXECUTION

echo "List of Repository IDs that we're going to sync:"
echo $LIST_REPOIDs
echo
#reposync -l -a ppc64le -c $REPO -r $LIST_REPOIDs -d -p $TARGET_DIR
reposync -l -a ppc64le -r $LIST_REPOIDs -d -p $TARGET_DIR

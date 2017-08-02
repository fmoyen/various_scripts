#!/bin/bash

Timestamp=`date +%Y%m%d`
BackupDir="/backup"
Retention=90
RemoteBackup="ibmadmin@lnxrepo:/BACKUPS/oVirt/PSLCoVirt"

mkdir -p $BackupDir/OLD
find $BackupDir -maxdepth 1 -type f -name "engine-backup*" -exec mv {} $BackupDir/OLD \;
find $BackupDir/OLD  -type f -name "engine-backup*" -mtime +$Retention -delete

engine-backup --mode=backup --scope=all --file=$BackupDir/engine-backup-all-$Timestamp.backup.gz --log=$BackupDir/engine-backup-all-$Timestamp.log

cd $BackupDir; rsync -av --delete . $RemoteBackup

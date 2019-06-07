#!/bin/bash

createContainerAndBackup () {
    az storage container create -n $i-$BACKUP_NAME --account-key $DESTINATION_KEY --account-name $DESTINATION_NAME
    SOURCE_SAS=$(az storage $azCommand generate-sas -n $1 --account-key $SOURCE_KEY --account-name $SOURCE_NAME --https-only --permissions dlrw --expiry $end -otsv)
    DESTINATION_SAS=$(az storage container generate-sas -n $1-$BACKUP_NAME --account-key $DESTINATION_KEY --account-name $DESTINATION_NAME --https-only --permissions dlrw --expiry $end -otsv)
    azcopy cp "https://$SOURCE_NAME.$endpoint/$1?$SOURCE_SAS" "https://$DESTINATION_NAME.blob.core.windows.net/$1-$BACKUP_NAME?$DESTINATION_SAS" --recursive=true
}

BACKUP_NAME="backup-`date +%Y-%m-%d-%H-%M`"
end=`date -d "30 minutes" '+%Y-%m-%dT%H:%M:%SZ'`

# get all source containers
containers=($(az storage container list --account-key $SOURCE_KEY --account-name $SOURCE_NAME -o json | jq -r '.[].name'))
endpoint="blob.core.windows.net"
azCommand="container"

# create all destination containers and copy
for i in "${containers[@]}"
do
    createContainerAndBackup $i
done

# get all source shares
shares=($(az storage share list --account-key $SOURCE_KEY --account-name $SOURCE_NAME -o json | jq -r '.[].name'))
endpoint="file.core.windows.net"
azCommand="share"
# create all destination containers and copy
# unfortunately, recursively copying from file-share to file-share doesn't work. 
# See https://github.com/Azure/azure-storage-azcopy/issues/248#issuecomment-481204287
# instead we'll just backup to a blob container
for i in "${shares[@]}"
do
    createContainerAndBackup $i
done

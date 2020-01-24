#!/bin/bash

createContainerAndBackup () {
    az storage container create -n $i-$BACKUP_NAME --account-key $DESTINATION_KEY --account-name $DESTINATION_NAME
    SOURCE_SAS=$(az storage $azCommand generate-sas -n $1 --account-key $SOURCE_KEY --account-name $SOURCE_NAME --https-only --permissions dlrw --expiry $end -otsv)
    DESTINATION_SAS=$(az storage container generate-sas -n $1-$BACKUP_NAME --account-key $DESTINATION_KEY --account-name $DESTINATION_NAME --https-only --permissions dlrw --expiry $end -otsv)
    azcopy cp "https://$SOURCE_NAME.$endpoint/$1?$SOURCE_SAS" "https://$DESTINATION_NAME.blob.core.windows.net/$1-$BACKUP_NAME?$DESTINATION_SAS" --recursive=true
}

rotateBackUp () {
    if [[ -z "${BACKUP_RETENTION_COUNT}" ]]; then
        echo "retention not set, skipping backup rotation for $1"
    else
        # tail -n +X starts from Xth line, so add 1
        BACKUP_RETENTION_COUNT=$((BACKUP_RETENTION_COUNT+1))
        rotateContainers=($(az storage container list --account-key $DESTINATION_KEY --account-name $DESTINATION_NAME -o json | jq -r --arg STARTSWITH "$1-$DISCRIMINATOR" 'sort_by(.name) | reverse | .[].name | select(startswith($STARTSWITH))' | tail -n +${BACKUP_RETENTION_COUNT}))
        for k in "${rotateContainers[@]}"
        do
            echo "deleting $k ..."
            az storage container delete --name $k --account-key $DESTINATION_KEY --account-name $DESTINATION_NAME 
        done
    fi
}

[[ -z "${BACKUP_NAME_DISCRIMINATOR}" ]] && DISCRIMINATOR='backup-' || DISCRIMINATOR="backup-${BACKUP_NAME_DISCRIMINATOR}-"

BACKUP_NAME="${DISCRIMINATOR}`date +%Y-%m-%d-%H-%M`"
end=`date -d "30 minutes" '+%Y-%m-%dT%H:%M:%SZ'`

# get all source containers
containers=($(az storage container list --account-key $SOURCE_KEY --account-name $SOURCE_NAME -o json | jq -r '.[].name'))
endpoint="blob.core.windows.net"
azCommand="container"

# create all destination containers and copy
for i in "${containers[@]}"
do
    createContainerAndBackup $i
    rotateBackUp $i
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
    rotateBackUp $i
done
